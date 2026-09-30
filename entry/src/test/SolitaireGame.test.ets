import { describe, it, expect } from '@ohos/hypium';
import {
  GameSnapshot,
  PlayingCard,
  RandomByteSource,
  SolitaireGame,
  SUIT_CLUBS,
  SUIT_DIAMONDS,
  SUIT_HEARTS,
  SUIT_SPADES
} from '../main/ets/model/SolitaireGame';
import { GameStateCodec } from '../main/ets/model/GameStateCodec';
import { classicDealTargets, triangularSweepSpeed } from '../main/ets/model/NewGameAnimation';
import {
  keepVictoryLaunchOnScreen,
  isVictoryStampDue,
  selectVictoryFoundation,
  stepVictoryFlight,
  VictoryFlight,
  VICTORY_BOUNCE_RESTITUTION,
  VICTORY_TIMER_MS,
  victoryPlaybackRate,
  victoryRangeFromByte,
  victoryTimeToBottom
} from '../main/ets/model/VictoryAnimation';

/** Full-period deterministic bytes for host tests; production still uses platform crypto. */
class TestRandomByteSource implements RandomByteSource {
  private value: number = 17;

  nextByte(): number {
    this.value = (this.value * 73 + 41) % 256;
    return this.value;
  }
}

function createTestGame(): SolitaireGame {
  return new SolitaireGame(new TestRandomByteSource());
}

export default function solitaireGameTest() {
  describe('SolitaireGame', () => {
    it('deals a complete Klondike game', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.newGame();

      let tableauCards: number = 0;
      for (let index: number = 0; index < game.tableau.length; index++) {
        tableauCards += game.tableau[index].length;
        expect(game.tableau[index].length).assertEqual(index + 1);
        expect(game.tableau[index][index].faceUp).assertTrue();
      }
      expect(tableauCards).assertEqual(28);
      expect(game.stock.length).assertEqual(24);
      expect(game.waste.length).assertEqual(0);
    });

    it('creates a fresh shuffle for each new game', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.newGame();
      const firstDeal: number[] = [];
      for (let pileIndex: number = 0; pileIndex < game.tableau.length; pileIndex++) {
        for (let cardIndex: number = 0; cardIndex < game.tableau[pileIndex].length; cardIndex++) {
          firstDeal.push(game.tableau[pileIndex][cardIndex].id);
        }
      }
      for (let stockIndex: number = 0; stockIndex < game.stock.length; stockIndex++) {
        firstDeal.push(game.stock[stockIndex].id);
      }

      game.newGame();
      const secondDeal: number[] = [];
      for (let pileIndex: number = 0; pileIndex < game.tableau.length; pileIndex++) {
        for (let cardIndex: number = 0; cardIndex < game.tableau[pileIndex].length; cardIndex++) {
          secondDeal.push(game.tableau[pileIndex][cardIndex].id);
        }
      }
      for (let stockIndex: number = 0; stockIndex < game.stock.length; stockIndex++) {
        secondDeal.push(game.stock[stockIndex].id);
      }

      let dealsMatch: boolean = true;
      for (let index: number = 0; index < firstDeal.length; index++) {
        if (firstDeal[index] !== secondDeal[index]) {
          dealsMatch = false;
          break;
        }
      }
      expect(dealsMatch).assertFalse();
    });

    it('undoes a stock draw', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.newGame();
      const originalTopId: number = game.stock[game.stock.length - 1].id;

      expect(game.drawFromStock()).assertTrue();
      expect(game.stock.length).assertEqual(23);
      expect(game.waste[0].id).assertEqual(originalTopId);
      expect(game.undo()).assertTrue();
      expect(game.stock.length).assertEqual(24);
      expect(game.waste.length).assertEqual(0);
    });

    it('draws up to three cards as one undoable stock action', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.stock = [
        new PlayingCard(2, SUIT_HEARTS, 3),
        new PlayingCard(1, SUIT_DIAMONDS, 2),
        new PlayingCard(0, SUIT_CLUBS, 1)
      ];
      game.waste = [];
      game.foundations = [[], [], [], []];
      game.tableau = [[], [], [], [], [], [], []];

      expect(game.drawFromStock(3)).assertTrue();
      expect(game.stock.length).assertEqual(0);
      expect(game.waste.length).assertEqual(3);
      expect(game.waste[0].id).assertEqual(0);
      expect(game.waste[1].id).assertEqual(1);
      expect(game.waste[2].id).assertEqual(2);
      expect(game.undo()).assertTrue();
      expect(game.stock.length).assertEqual(3);
      expect(game.waste.length).assertEqual(0);

      game.stock.pop();
      expect(game.drawFromStock(3)).assertTrue();
      expect(game.stock.length).assertEqual(0);
      expect(game.waste.length).assertEqual(2);
    });

    it('limits waste resets and restores the reset count with undo', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.setWasteResetLimit(3);
      game.stock = [new PlayingCard(0, SUIT_CLUBS, 1)];
      game.waste = [];
      game.foundations = [[], [], [], []];
      game.tableau = [[], [], [], [], [], [], []];

      for (let resetIndex: number = 0; resetIndex < 3; resetIndex++) {
        expect(game.drawFromStock()).assertTrue();
        expect(game.drawFromStock()).assertTrue();
      }
      expect(game.wasteResetsUsed).assertEqual(3);
      expect(game.wasteResetsRemaining()).assertEqual(0);
      expect(game.drawFromStock()).assertTrue();
      expect(game.drawFromStock()).assertFalse();
      expect(game.undo()).assertTrue();
      expect(game.wasteResetsUsed).assertEqual(3);
      expect(game.stock.length).assertEqual(1);
      expect(game.waste.length).assertEqual(0);
      expect(game.undo()).assertTrue();
      expect(game.wasteResetsUsed).assertEqual(2);
      expect(game.stock.length).assertEqual(0);
      expect(game.waste.length).assertEqual(1);
    });

    it('persists the waste reset count in a saved snapshot', 0, () => {
      const source: SolitaireGame = createTestGame();
      source.newGame();
      source.setWasteResetLimit(3);
      while (source.stock.length > 0) {
        expect(source.drawFromStock()).assertTrue();
      }
      expect(source.drawFromStock()).assertTrue();

      const restored: SolitaireGame = createTestGame();
      expect(restored.restore(GameStateCodec.decode(GameStateCodec.encodeGame(source)) as GameSnapshot))
        .assertTrue();
      expect(restored.wasteResetsUsed).assertEqual(1);
    });

    it('exposes the preceding three-card waste window after its top moves', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.stock = [
        new PlayingCard(5, SUIT_CLUBS, 1),
        new PlayingCard(4, SUIT_HEARTS, 5),
        new PlayingCard(3, SUIT_SPADES, 6),
        new PlayingCard(2, SUIT_DIAMONDS, 7),
        new PlayingCard(1, SUIT_HEARTS, 8),
        new PlayingCard(0, SUIT_CLUBS, 9)
      ];
      game.waste = [];
      game.foundations = [[], [], [], []];
      game.tableau = [[], [], [], [], [], [], []];

      expect(game.drawFromStock(3)).assertTrue();
      expect(game.drawFromStock(3)).assertTrue();
      expect(game.waste[3].id).assertEqual(3);
      expect(game.waste[4].id).assertEqual(4);
      expect(game.waste[5].id).assertEqual(5);
      expect(game.moveWasteToFoundation(0)).assertTrue();
      expect(game.waste[2].id).assertEqual(2);
      expect(game.waste[3].id).assertEqual(3);
      expect(game.waste[4].id).assertEqual(4);
    });

    it('does not undo a completed game', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.stock = [];
      game.waste = [new PlayingCard(SUIT_SPADES * 13 + 12, SUIT_SPADES, 13, true)];
      game.foundations = [[], [], [], []];
      for (let suit: number = SUIT_CLUBS; suit <= SUIT_SPADES; suit++) {
        const lastRank: number = suit === SUIT_SPADES ? 12 : 13;
        for (let rank: number = 1; rank <= lastRank; rank++) {
          game.foundations[suit].push(new PlayingCard(suit * 13 + rank - 1, suit, rank, true));
        }
      }
      game.tableau = [[], [], [], [], [], [], []];

      expect(game.moveWasteToFoundation(SUIT_SPADES)).assertTrue();
      expect(game.isWon()).assertTrue();
      expect(game.canUndo()).assertFalse();
      expect(game.undo()).assertFalse();
      expect(game.isWon()).assertTrue();
    });

    it('round-trips a saved board without restoring undo history', 0, () => {
      const source: SolitaireGame = createTestGame();
      source.newGame();
      expect(source.drawFromStock()).assertTrue();
      const snapshot: GameSnapshot = source.snapshot();
      const topWasteId: number = snapshot.waste[snapshot.waste.length - 1].id;

      const restored: SolitaireGame = createTestGame();
      expect(restored.restore(snapshot)).assertTrue();
      expect(restored.stock.length).assertEqual(23);
      expect(restored.waste.length).assertEqual(1);
      expect(restored.waste[0].id).assertEqual(topWasteId);
      expect(restored.canUndo()).assertFalse();

      snapshot.waste[0].faceUp = false;
      expect(restored.waste[0].faceUp).assertTrue();
    });

    it('rejects incomplete and duplicate saved decks', 0, () => {
      const source: SolitaireGame = createTestGame();
      source.newGame();

      const incomplete: GameSnapshot = source.snapshot();
      incomplete.stock.pop();
      expect(createTestGame().restore(incomplete)).assertFalse();

      const duplicate: GameSnapshot = source.snapshot();
      duplicate.stock[0] = duplicate.stock[1];
      expect(createTestGame().restore(duplicate)).assertFalse();
    });

    it('versions saved game JSON and rejects incompatible or corrupt data', 0, () => {
      const source: SolitaireGame = createTestGame();
      source.newGame();
      const copiedEncoding: string = GameStateCodec.encode(source.snapshot());
      const liveEncoding: string = GameStateCodec.encodeGame(source);
      expect(liveEncoding).assertEqual(copiedEncoding);
      const decoded: GameSnapshot | null = GameStateCodec.decode(liveEncoding);
      expect(decoded === null).assertFalse();
      expect(GameStateCodec.decode('{"version":2,"game":{}}') === null).assertTrue();
      expect(GameStateCodec.decode('not-json') === null).assertTrue();
    });

    it('builds the classic 28-card deal schedule', 0, () => {
      const targets = classicDealTargets();
      expect(targets.length).assertEqual(28);
      expect(targets[0].pileIndex).assertEqual(0);
      expect(targets[6].pileIndex).assertEqual(6);
      expect(targets[7].pileIndex).assertEqual(1);
      expect(targets[27].pileIndex).assertEqual(6);
      expect(targets[27].cardIndex).assertEqual(6);
    });

    it('keeps triangular sweep speeds inside their approved bounds', 0, () => {
      expect(triangularSweepSpeed(0, 0)).assertEqual(1000);
      expect(triangularSweepSpeed(255, 255)).assertEqual(2800);
      expect(triangularSweepSpeed(0, 255)).assertEqual(1900);
    });

    it('selects only non-empty victory foundations', 0, () => {
      const sizes: number[] = [0, 13, 0, 13];
      expect(selectVictoryFoundation(sizes, 0)).assertEqual(1);
      expect(selectVictoryFoundation(sizes, 255)).assertEqual(3);
      expect(selectVictoryFoundation([0, 0, 0, 0], 128)).assertEqual(-1);
    });

    it('launches all 52 victory cards without selecting an empty pile', 0, () => {
      const sizes: number[] = [13, 13, 13, 13];
      let launched: number = 0;
      while (selectVictoryFoundation(sizes, launched * 73 % 256) >= 0) {
        const foundationIndex: number = selectVictoryFoundation(sizes, launched * 73 % 256);
        expect(sizes[foundationIndex] > 0).assertTrue();
        sizes[foundationIndex]--;
        launched++;
      }
      expect(launched).assertEqual(52);
    });

    it('maps victory speeds to their approved ranges', 0, () => {
      expect(victoryRangeFromByte(0, 90, 240)).assertEqual(90);
      expect(victoryRangeFromByte(255, 90, 240)).assertEqual(240);
      expect(victoryRangeFromByte(128, 250, 375) > 250).assertTrue();
      expect(victoryRangeFromByte(128, 250, 375) < 375).assertTrue();
    });

    it('accelerates victory playback after five cards and caps the final five at four times', 0, () => {
      expect(victoryPlaybackRate(1)).assertEqual(1);
      expect(victoryPlaybackRate(5)).assertEqual(1);
      expect(victoryPlaybackRate(6) > 1).assertTrue();
      expect(victoryPlaybackRate(47) < 4).assertTrue();
      expect(victoryPlaybackRate(48)).assertEqual(4);
      expect(victoryPlaybackRate(52)).assertEqual(4);
    });

    it('raises stamp frequency with playback speed while preserving each physics step', 0, () => {
      expect(VICTORY_TIMER_MS).assertEqual(15);
      const baseline: VictoryFlight = new VictoryFlight(1, 100, 100, 120, -600);
      expect(isVictoryStampDue(baseline)).assertFalse();
      expect(isVictoryStampDue(baseline)).assertFalse();
      expect(isVictoryStampDue(baseline)).assertFalse();
      expect(isVictoryStampDue(baseline)).assertTrue();

      const accelerated: VictoryFlight = new VictoryFlight(1, 100, 100, 120, -600, 4);
      expect(isVictoryStampDue(accelerated)).assertTrue();
      expect(isVictoryStampDue(accelerated)).assertTrue();

      const baselineX: number = baseline.x;
      const acceleratedX: number = accelerated.x;
      stepVictoryFlight(baseline, 2000, 2000, 45, 67.5);
      stepVictoryFlight(accelerated, 2000, 2000, 45, 67.5);
      expect(Math.abs((baseline.x - baselineX) - (accelerated.x - acceleratedX)) < 0.001).assertTrue();
    });

    it('keeps a victory launch on-screen until its first bounce', 0, () => {
      const impactTime: number = victoryTimeToBottom(20, -600, 720, 67.5);
      const adjusted: number = keepVictoryLaunchOnScreen(310, 240, impactTime, 360, 45);
      expect(adjusted < 0).assertTrue();
      const impactX: number = 310 + adjusted * impactTime;
      expect(impactX >= 0).assertTrue();
      expect(impactX <= 315).assertTrue();

      const centered: number = keepVictoryLaunchOnScreen(150, 240, impactTime, 360, 45);
      const centeredImpactX: number = 150 + centered * impactTime;
      expect(centeredImpactX >= 0).assertTrue();
      expect(centeredImpactX <= 315).assertTrue();
    });

    it('reports only the first bottom bounce and applies restitution', 0, () => {
      const flight: VictoryFlight = new VictoryFlight(7, 100, 651.5, 120, 100);
      const firstResult = stepVictoryFlight(flight, 360, 720, 45, 67.5);
      expect(firstResult.firstBounce).assertTrue();
      expect(firstResult.exited).assertFalse();
      expect(flight.y).assertEqual(652.5);
      expect(flight.velocityY < 0).assertTrue();
      expect(Math.abs(flight.velocityY + 208 * VICTORY_BOUNCE_RESTITUTION) < 0.001).assertTrue();

      flight.y = 651.5;
      flight.velocityY = 100;
      const laterResult = stepVictoryFlight(flight, 360, 720, 45, 67.5);
      expect(laterResult.firstBounce).assertFalse();
    });

    it('waits for a complete horizontal exit', 0, () => {
      const visible: VictoryFlight = new VictoryFlight(8, -44, 100, 0, 0);
      expect(stepVictoryFlight(visible, 360, 720, 45, 67.5).exited).assertFalse();
      const exited: VictoryFlight = new VictoryFlight(9, -46, 100, 0, 0);
      expect(stepVictoryFlight(exited, 360, 720, 45, 67.5).exited).assertTrue();
    });

    it('moves an ace to any empty foundation', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.stock = [];
      game.waste = [new PlayingCard(1, SUIT_CLUBS, 1, true)];
      game.foundations = [[], [], [], []];
      game.tableau = [[], [], [], [], [], [], []];

      expect(game.moveWasteToFoundation(SUIT_HEARTS)).assertTrue();
      expect(game.foundations[SUIT_HEARTS].length).assertEqual(1);
      expect(game.foundations[SUIT_HEARTS][0].suit).assertEqual(SUIT_CLUBS);
    });

    it('continues a foundation with the suit chosen by its ace', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.stock = [];
      game.waste = [new PlayingCard(2, SUIT_DIAMONDS, 2, true)];
      game.foundations = [[], [new PlayingCard(1, SUIT_CLUBS, 1, true)], [], []];
      game.tableau = [[], [], [], [], [], [], []];

      expect(game.moveWasteToFoundation(1)).assertFalse();
      game.waste = [new PlayingCard(3, SUIT_CLUBS, 2, true)];
      expect(game.moveWasteToFoundation(1)).assertTrue();
      expect(game.foundations[1].length).assertEqual(2);
    });

    it('flips a tableau card exposed by a valid move', 0, () => {
      const game: SolitaireGame = createTestGame();
      const covered: PlayingCard = new PlayingCard(1, SUIT_CLUBS, 5, false);
      const moving: PlayingCard = new PlayingCard(2, SUIT_HEARTS, 4, true);
      const target: PlayingCard = new PlayingCard(3, SUIT_SPADES, 5, true);
      game.stock = [];
      game.waste = [];
      game.foundations = [[], [], [], []];
      game.tableau = [[covered, moving], [target], [], [], [], [], []];

      expect(game.moveTableauToTableau(0, 1, 1)).assertTrue();
      expect(game.tableau[0][0].faceUp).assertTrue();
      expect(game.tableau[1].length).assertEqual(2);
    });

    it('offers autocomplete only with empty stock and waste and all tableau cards revealed', 0, () => {
      const game: SolitaireGame = createTestGame();
      game.stock = [];
      game.waste = [];
      game.foundations = [[], [], [], []];
      game.tableau = [[new PlayingCard(1, SUIT_CLUBS, 1, true)], [], [], [], [], [], []];

      expect(game.canAutoComplete()).assertTrue();
      game.waste = [new PlayingCard(2, SUIT_HEARTS, 1, true)];
      expect(game.canAutoComplete()).assertFalse();
      game.waste = [];
      game.stock = [new PlayingCard(3, SUIT_SPADES, 1, false)];
      expect(game.canAutoComplete()).assertFalse();
      game.stock = [];
      game.tableau[0][0].faceUp = false;
      expect(game.canAutoComplete()).assertFalse();
    });

    it('prioritizes the lowest legal cards during autocomplete', 0, () => {
      const game: SolitaireGame = new SolitaireGame();
      game.stock = [];
      game.waste = [];
      game.foundations = [
        [new PlayingCard(10, SUIT_CLUBS, 1, true)],
        [], [], []
      ];
      game.tableau = [
        [new PlayingCard(2, SUIT_CLUBS, 2, true)],
        [new PlayingCard(3, SUIT_HEARTS, 1, true)],
        [], [], [], [], []
      ];

      const firstMove = game.nextAutoCompleteMove();
      expect(firstMove === null).assertFalse();
      if (firstMove !== null) {
        expect(firstMove.tableauIndex).assertEqual(1);
        expect(game.performAutoCompleteMove(firstMove)).assertTrue();
      }
      expect(game.foundations[1][0].suit).assertEqual(SUIT_HEARTS);

      const secondMove = game.nextAutoCompleteMove();
      expect(secondMove === null).assertFalse();
      if (secondMove !== null) {
        expect(secondMove.tableauIndex).assertEqual(0);
        expect(game.performAutoCompleteMove(secondMove)).assertTrue();
      }
      expect(game.foundations[0].length).assertEqual(2);
    });
  });
}

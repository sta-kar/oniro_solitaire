import { GameSnapshot, SolitaireGame } from './SolitaireGame';

/** Current durable game-state schema. Increment when the payload shape changes. */
export const SAVED_GAME_VERSION: number = 1;

/** Small versioned envelope stored as one Preferences string value. */
export class SavedGameEnvelope {
  version: number;
  game: GameSnapshot;

  constructor(version: number, game: GameSnapshot) {
    this.version = version;
    this.game = game;
  }
}

/** Pure serialization helpers kept separate from the Preferences lifecycle. */
export class GameStateCodec {
  static encode(snapshot: GameSnapshot): string {
    return JSON.stringify(new SavedGameEnvelope(SAVED_GAME_VERSION, snapshot));
  }

  /**
   * Serializes the live model synchronously, avoiding an otherwise redundant
   * 52-card clone before JSON.stringify consumes the data.
   */
  static encodeGame(game: SolitaireGame): string {
    return GameStateCodec.encode(new GameSnapshot(
      game.stock,
      game.waste,
      game.foundations,
      game.tableau,
      game.wasteResetsUsed
    ));
  }

  static decode(value: string): GameSnapshot | null {
    try {
      const envelope: SavedGameEnvelope = JSON.parse(value) as SavedGameEnvelope;
      if (envelope === null || envelope.version !== SAVED_GAME_VERSION || envelope.game === null) {
        return null;
      }
      return envelope.game;
    } catch (err) {
      return null;
    }
  }
}

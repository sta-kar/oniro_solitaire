import { cryptoFramework } from '@kit.CryptoArchitectureKit';

/**
 * Core model for a configurable draw-one/draw-three Klondike solitaire game.
 *
 * The model deliberately has no ArkUI dependencies. The page asks it to perform
 * moves, then replaces its @State arrays with the model's updated arrays.
 */

export const SUIT_CLUBS: number = 0;
export const SUIT_DIAMONDS: number = 1;
export const SUIT_HEARTS: number = 2;
export const SUIT_SPADES: number = 3;

export class PlayingCard {
  id: number;
  suit: number;
  rank: number;
  faceUp: boolean;

  constructor(id: number, suit: number, rank: number, faceUp: boolean = false) {
    this.id = id;
    this.suit = suit;
    this.rank = rank;
    this.faceUp = faceUp;
  }

  clone(): PlayingCard {
    return new PlayingCard(this.id, this.suit, this.rank, this.faceUp);
  }
}

export class GameSnapshot {
  stock: PlayingCard[];
  waste: PlayingCard[];
  foundations: PlayingCard[][];
  tableau: PlayingCard[][];
  wasteResetsUsed: number;

  constructor(
    stock: PlayingCard[],
    waste: PlayingCard[],
    foundations: PlayingCard[][],
    tableau: PlayingCard[][],
    wasteResetsUsed: number = 0
  ) {
    this.stock = stock;
    this.waste = waste;
    this.foundations = foundations;
    this.tableau = tableau;
    this.wasteResetsUsed = wasteResetsUsed;
  }
}

/** Injectable byte stream keeps platform crypto out of host-side unit tests. */
export interface RandomByteSource {
  nextByte(): number;
}

/** One deterministic tableau-to-foundation step in an autocomplete sequence. */
export class AutoCompleteMove {
  tableauIndex: number;
  foundationIndex: number;
  cardId: number;

  constructor(tableauIndex: number, foundationIndex: number, cardId: number) {
    this.tableauIndex = tableauIndex;
    this.foundationIndex = foundationIndex;
    this.cardId = cardId;
  }
}

export class SolitaireGame {
  stock: PlayingCard[] = [];
  waste: PlayingCard[] = [];
  foundations: PlayingCard[][] = [[], [], [], []];
  tableau: PlayingCard[][] = [[], [], [], [], [], [], []];
  wasteResetsUsed: number = 0;
  private history: GameSnapshot[] = [];
  private random: cryptoFramework.Random | null = null;
  private randomByteSource: RandomByteSource | null = null;
  private wasteResetLimit: number = 0;

  constructor(randomByteSource: RandomByteSource | null = null) {
    this.randomByteSource = randomByteSource;
    if (randomByteSource === null) {
      this.random = cryptoFramework.createRandom();
    }
  }

  /** Starts a freshly shuffled game and clears the undo history. */
  newGame(): void {
    const deck: PlayingCard[] = [];
    let id: number = 0;
    for (let suit: number = SUIT_CLUBS; suit <= SUIT_SPADES; suit++) {
      for (let rank: number = 1; rank <= 13; rank++) {
        deck.push(new PlayingCard(id, suit, rank));
        id++;
      }
    }

    for (let index: number = deck.length - 1; index > 0; index--) {
      const swapIndex: number = this.randomIndex(index + 1);
      const temporary: PlayingCard = deck[index];
      deck[index] = deck[swapIndex];
      deck[swapIndex] = temporary;
    }

    this.stock = [];
    this.waste = [];
    this.foundations = [[], [], [], []];
    this.tableau = [[], [], [], [], [], [], []];
    this.wasteResetsUsed = 0;
    this.history = [];

    for (let column: number = 0; column < 7; column++) {
      for (let row: number = 0; row <= column; row++) {
        const card: PlayingCard = deck.pop() as PlayingCard;
        card.faceUp = row === column;
        this.tableau[column].push(card);
      }
    }

    while (deck.length > 0) {
      const card: PlayingCard = deck.pop() as PlayingCard;
      card.faceUp = false;
      this.stock.push(card);
    }
  }

  /** Returns an isolated copy suitable for rendering or durable serialization. */
  snapshot(): GameSnapshot {
    return new GameSnapshot(
      this.clonePile(this.stock),
      this.clonePile(this.waste),
      this.clonePiles(this.foundations),
      this.clonePiles(this.tableau),
      this.wasteResetsUsed
    );
  }

  /** Sets the maximum number of waste recycles; zero means unlimited. */
  setWasteResetLimit(limit: number): void {
    this.wasteResetLimit = limit === 3 ? 3 : 0;
  }

  /** Returns the remaining recycles, or -1 when recycling is unlimited. */
  wasteResetsRemaining(): number {
    if (this.wasteResetLimit === 0) {
      return -1;
    }
    return Math.max(0, this.wasteResetLimit - this.wasteResetsUsed);
  }

  /**
   * Restores a complete, valid deck while deliberately starting a new undo
   * session. Persisted JSON objects are rebuilt as PlayingCard instances.
   */
  restore(snapshot: GameSnapshot): boolean {
    if (!this.isValidSnapshot(snapshot)) {
      return false;
    }
    this.stock = this.rebuildPile(snapshot.stock);
    this.waste = this.rebuildPile(snapshot.waste);
    this.foundations = this.rebuildPiles(snapshot.foundations);
    this.tableau = this.rebuildPiles(snapshot.tableau);
    this.wasteResetsUsed = Number.isInteger(snapshot.wasteResetsUsed) && snapshot.wasteResetsUsed >= 0 ?
      snapshot.wasteResetsUsed : 0;
    this.history = [];
    return true;
  }

  /** Returns an unbiased platform-random integer in [0, upperBound). */
  private randomIndex(upperBound: number): number {
    const acceptedRange: number = 256 - (256 % upperBound);
    let randomByte: number = this.nextRandomByte();
    while (randomByte >= acceptedRange) {
      randomByte = this.nextRandomByte();
    }
    return randomByte % upperBound;
  }

  private nextRandomByte(): number {
    if (this.randomByteSource !== null) {
      return this.randomByteSource.nextByte();
    }
    return (this.random as cryptoFramework.Random).generateRandomSync(1).data[0];
  }

  /** Draws one or three cards as one undoable action, or recycles an empty stock. */
  drawFromStock(drawCount: number = 1): boolean {
    if (this.stock.length === 0 && this.waste.length === 0) {
      return false;
    }
    if (this.stock.length === 0 && this.waste.length > 0 && this.wasteResetsRemaining() === 0) {
      return false;
    }
    this.rememberState();

    if (this.stock.length > 0) {
      const boundedDrawCount: number = drawCount === 3 ? 3 : 1;
      for (let index: number = 0; index < boundedDrawCount && this.stock.length > 0; index++) {
        const card: PlayingCard = this.stock.pop() as PlayingCard;
        card.faceUp = true;
        this.waste.push(card);
      }
      return true;
    }

    while (this.waste.length > 0) {
      const card: PlayingCard = this.waste.pop() as PlayingCard;
      card.faceUp = false;
      this.stock.push(card);
    }
    this.wasteResetsUsed++;
    return true;
  }

  moveWasteToTableau(tableauIndex: number): boolean {
    if (this.waste.length === 0) {
      return false;
    }
    const card: PlayingCard = this.waste[this.waste.length - 1];
    if (!this.canPlaceOnTableau(card, tableauIndex)) {
      return false;
    }
    this.rememberState();
    this.tableau[tableauIndex].push(this.waste.pop() as PlayingCard);
    return true;
  }

  moveWasteToFoundation(foundationIndex: number): boolean {
    if (this.waste.length === 0) {
      return false;
    }
    const card: PlayingCard = this.waste[this.waste.length - 1];
    if (!this.canPlaceOnFoundation(card, foundationIndex)) {
      return false;
    }
    this.rememberState();
    this.foundations[foundationIndex].push(this.waste.pop() as PlayingCard);
    return true;
  }

  moveTableauToTableau(sourceIndex: number, cardIndex: number, targetIndex: number): boolean {
    if (sourceIndex === targetIndex || !this.isValidTableauRun(sourceIndex, cardIndex)) {
      return false;
    }
    const card: PlayingCard = this.tableau[sourceIndex][cardIndex];
    if (!this.canPlaceOnTableau(card, targetIndex)) {
      return false;
    }
    this.rememberState();
    const movingCards: PlayingCard[] = this.tableau[sourceIndex].splice(cardIndex);
    this.tableau[targetIndex].push(...movingCards);
    this.flipExposedTableauCard(sourceIndex);
    return true;
  }

  moveTableauToFoundation(sourceIndex: number, cardIndex: number, foundationIndex: number): boolean {
    const pile: PlayingCard[] = this.tableau[sourceIndex];
    if (cardIndex !== pile.length - 1 || cardIndex < 0) {
      return false;
    }
    const card: PlayingCard = pile[cardIndex];
    if (!this.canPlaceOnFoundation(card, foundationIndex)) {
      return false;
    }
    this.rememberState();
    this.foundations[foundationIndex].push(pile.pop() as PlayingCard);
    this.flipExposedTableauCard(sourceIndex);
    return true;
  }

  moveFoundationToTableau(foundationIndex: number, tableauIndex: number): boolean {
    const pile: PlayingCard[] = this.foundations[foundationIndex];
    if (pile.length === 0) {
      return false;
    }
    const card: PlayingCard = pile[pile.length - 1];
    if (!this.canPlaceOnTableau(card, tableauIndex)) {
      return false;
    }
    this.rememberState();
    this.tableau[tableauIndex].push(pile.pop() as PlayingCard);
    return true;
  }

  /** Restores the latest action unless the current board is already complete. */
  undo(): boolean {
    if (this.isWon() || this.history.length === 0) {
      return false;
    }
    const snapshot: GameSnapshot = this.history.pop() as GameSnapshot;
    this.stock = this.clonePile(snapshot.stock);
    this.waste = this.clonePile(snapshot.waste);
    this.foundations = this.clonePiles(snapshot.foundations);
    this.tableau = this.clonePiles(snapshot.tableau);
    this.wasteResetsUsed = snapshot.wasteResetsUsed;
    return true;
  }

  canUndo(): boolean {
    return !this.isWon() && this.history.length > 0;
  }

  isWon(): boolean {
    for (let index: number = 0; index < this.foundations.length; index++) {
      if (this.foundations[index].length !== 13) {
        return false;
      }
    }
    return true;
  }

  /**
   * Reports whether every card left in play is exposed and there are no cards
   * in either draw pile. A completed game no longer needs autocomplete.
   */
  canAutoComplete(): boolean {
    if (this.stock.length > 0 || this.waste.length > 0 || this.isWon()) {
      return false;
    }
    for (let pileIndex: number = 0; pileIndex < this.tableau.length; pileIndex++) {
      const pile: PlayingCard[] = this.tableau[pileIndex];
      for (let cardIndex: number = 0; cardIndex < pile.length; cardIndex++) {
        if (!pile[cardIndex].faceUp) {
          return false;
        }
      }
    }
    return true;
  }

  /** Finds the lowest-rank legal exposed card, with left-to-right tie breaking. */
  nextAutoCompleteMove(): AutoCompleteMove | null {
    if (!this.canAutoComplete()) {
      return null;
    }
    let nextMove: AutoCompleteMove | null = null;
    let lowestRank: number = 14;
    for (let tableauIndex: number = 0; tableauIndex < this.tableau.length; tableauIndex++) {
      const pile: PlayingCard[] = this.tableau[tableauIndex];
      if (pile.length === 0) {
        continue;
      }
      const card: PlayingCard = pile[pile.length - 1];
      if (card.rank >= lowestRank) {
        continue;
      }
      for (let foundationIndex: number = 0; foundationIndex < this.foundations.length; foundationIndex++) {
        if (this.canPlaceOnFoundation(card, foundationIndex)) {
          nextMove = new AutoCompleteMove(tableauIndex, foundationIndex, card.id);
          lowestRank = card.rank;
          break;
        }
      }
    }
    return nextMove;
  }

  /** Applies a previously discovered autocomplete step through normal move rules. */
  performAutoCompleteMove(move: AutoCompleteMove): boolean {
    const pile: PlayingCard[] = this.tableau[move.tableauIndex];
    if (pile.length === 0 || pile[pile.length - 1].id !== move.cardId) {
      return false;
    }
    return this.moveTableauToFoundation(move.tableauIndex, pile.length - 1, move.foundationIndex);
  }

  private canPlaceOnTableau(card: PlayingCard, tableauIndex: number): boolean {
    const target: PlayingCard[] = this.tableau[tableauIndex];
    if (target.length === 0) {
      return card.rank === 13;
    }
    const topCard: PlayingCard = target[target.length - 1];
    return topCard.faceUp && topCard.rank === card.rank + 1 && this.isRed(topCard) !== this.isRed(card);
  }

  private canPlaceOnFoundation(card: PlayingCard, foundationIndex: number): boolean {
    const target: PlayingCard[] = this.foundations[foundationIndex];
    if (target.length === 0) {
      return card.rank === 1;
    }
    const topCard: PlayingCard = target[target.length - 1];
    return topCard.suit === card.suit && topCard.rank + 1 === card.rank;
  }

  private isValidTableauRun(sourceIndex: number, cardIndex: number): boolean {
    const pile: PlayingCard[] = this.tableau[sourceIndex];
    if (cardIndex < 0 || cardIndex >= pile.length || !pile[cardIndex].faceUp) {
      return false;
    }
    for (let index: number = cardIndex; index < pile.length - 1; index++) {
      const upper: PlayingCard = pile[index];
      const lower: PlayingCard = pile[index + 1];
      if (!lower.faceUp || upper.rank !== lower.rank + 1 || this.isRed(upper) === this.isRed(lower)) {
        return false;
      }
    }
    return true;
  }

  private isRed(card: PlayingCard): boolean {
    return card.suit === SUIT_DIAMONDS || card.suit === SUIT_HEARTS;
  }

  private flipExposedTableauCard(tableauIndex: number): void {
    const pile: PlayingCard[] = this.tableau[tableauIndex];
    if (pile.length > 0) {
      pile[pile.length - 1].faceUp = true;
    }
  }

  private rememberState(): void {
    this.history.push(new GameSnapshot(
      this.clonePile(this.stock),
      this.clonePile(this.waste),
      this.clonePiles(this.foundations),
      this.clonePiles(this.tableau),
      this.wasteResetsUsed
    ));
    if (this.history.length > 100) {
      this.history.shift();
    }
  }

  /** A saved game must contain one canonical copy of every physical card. */
  private isValidSnapshot(snapshot: GameSnapshot): boolean {
    if (snapshot === null || !Array.isArray(snapshot.stock) || !Array.isArray(snapshot.waste) ||
      !Array.isArray(snapshot.foundations) || snapshot.foundations.length !== 4 ||
      !Array.isArray(snapshot.tableau) || snapshot.tableau.length !== 7) {
      return false;
    }
    if (snapshot.wasteResetsUsed !== undefined &&
      (!Number.isInteger(snapshot.wasteResetsUsed) || snapshot.wasteResetsUsed < 0)) {
      return false;
    }

    const seen: boolean[] = new Array<boolean>(52).fill(false);
    let cardCount: number = 0;
    const piles: PlayingCard[][] = [snapshot.stock, snapshot.waste];
    piles.push(...snapshot.foundations);
    piles.push(...snapshot.tableau);
    for (const pile of piles) {
      if (!Array.isArray(pile)) {
        return false;
      }
      for (const card of pile) {
        if (card === null || !Number.isInteger(card.id) || card.id < 0 || card.id >= 52 ||
          !Number.isInteger(card.suit) || card.suit < SUIT_CLUBS || card.suit > SUIT_SPADES ||
          !Number.isInteger(card.rank) || card.rank < 1 || card.rank > 13 ||
          card.id !== card.suit * 13 + card.rank - 1 || typeof card.faceUp !== 'boolean' || seen[card.id]) {
          return false;
        }
        seen[card.id] = true;
        cardCount++;
      }
    }
    return cardCount === 52;
  }

  /** Rehydrates plain serialized card objects without relying on clone methods. */
  private rebuildPile(pile: PlayingCard[]): PlayingCard[] {
    return pile.map((card: PlayingCard) => new PlayingCard(card.id, card.suit, card.rank, card.faceUp));
  }

  private rebuildPiles(piles: PlayingCard[][]): PlayingCard[][] {
    return piles.map((pile: PlayingCard[]) => this.rebuildPile(pile));
  }

  private clonePile(pile: PlayingCard[]): PlayingCard[] {
    const result: PlayingCard[] = [];
    for (let index: number = 0; index < pile.length; index++) {
      result.push(pile[index].clone());
    }
    return result;
  }

  private clonePiles(piles: PlayingCard[][]): PlayingCard[][] {
    const result: PlayingCard[][] = [];
    for (let index: number = 0; index < piles.length; index++) {
      result.push(this.clonePile(piles[index]));
    }
    return result;
  }
}

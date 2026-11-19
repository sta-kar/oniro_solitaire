import { FrameCallback, UIContext } from '@kit.ArkUI';
import { PlayingCard } from '../model/SolitaireGame';

/** Unscaled fallback if ArkUI does not report completion for a packaged image. */
const CARD_HANDOFF_TIMEOUT_MS: number = 250;

/** Gives decoded artwork a frame to paint before a card view is replaced. */
export class ArtworkHandoffFrame extends FrameCallback {
  private complete: () => void;

  constructor(complete: () => void) {
    super();
    this.complete = complete;
  }

  onIdle(_timeLeftInNano: number): void {
    this.complete();
  }
}

function cardArtworkKey(card: PlayingCard): number {
  return card.id * 2 + (card.faceUp ? 1 : 0);
}

/** Tracks one incoming batch even when its images decode before motion ends. */
export class CardArtworkHandoff {
  private pending: Set<number> = new Set<number>();
  private timer: number = -1;
  private generation: number = 0;
  private onReady: (() => void) | undefined = undefined;

  expect(cards: PlayingCard[]): void {
    cards.forEach((card: PlayingCard) => this.pending.add(cardArtworkKey(card)));
  }

  decoded(context: UIContext, card: PlayingCard): void {
    if (this.pending.delete(cardArtworkKey(card))) {
      this.schedule(context);
    }
  }

  finish(context: UIContext, onReady: () => void): void {
    this.onReady = onReady;
    const generation: number = this.generation;
    this.timer = setTimeout(() => {
      if (generation === this.generation) {
        console.warn('[SolitaireArtwork] handoff timed out with ' + this.pending.size + ' images pending');
        this.complete(generation);
      }
    }, CARD_HANDOFF_TIMEOUT_MS);
    this.schedule(context);
  }

  cancel(): void {
    this.generation++;
    clearTimeout(this.timer);
    this.timer = -1;
    this.pending.clear();
    this.onReady = undefined;
  }

  private schedule(context: UIContext): void {
    if (this.pending.size === 0 && this.onReady !== undefined) {
      const generation: number = this.generation;
      context.postFrameCallback(new ArtworkHandoffFrame(() => this.complete(generation)));
    }
  }

  private complete(generation: number): void {
    if (generation === this.generation && this.onReady !== undefined) {
      const onReady: () => void = this.onReady;
      this.cancel();
      onReady();
    }
  }
}

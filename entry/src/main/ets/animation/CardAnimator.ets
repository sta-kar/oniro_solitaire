import { AnimatorResult, UIContext } from '@kit.ArkUI';

/** App-owned progress avoids RenderService's broken implicit finish delivery. */
export class CardAnimator {
  private animator: AnimatorResult | undefined = undefined;
  private timers: Set<number> = new Set<number>();
  private generation: number = 0;
  private animationGeneration: number = 0;

  /** Defers a launch/midpoint while keeping it cancellable with its owner. */
  after(delay: number, action: () => void): void {
    const generation: number = this.generation;
    const timer: number = setTimeout(() => {
      this.timers.delete(timer);
      if (generation === this.generation) {
        action();
      }
    }, delay);
    this.timers.add(timer);
  }

  /** Runs one finite motion; frames and completion use the same local clock. */
  play(
    context: UIContext,
    duration: number,
    curve: (fraction: number) => number,
    onFrame: (progress: number) => void,
    onFinish: () => void = () => {}
  ): void {
    this.stopAnimator();
    const generation: number = this.animationGeneration;
    if (duration <= 0) {
      this.after(0, () => {
        if (generation === this.animationGeneration) {
          onFrame(1);
          onFinish();
        }
      });
      return;
    }

    const animation: AnimatorResult = context.createAnimator({
      duration: duration,
      easing: 'linear',
      delay: 0,
      fill: 'forwards',
      direction: 'normal',
      iterations: 1,
      begin: 0,
      end: 1
    });
    this.animator = animation;
    animation.onFrame = (fraction: number): void => {
      if (generation === this.animationGeneration && this.animator === animation) {
        onFrame(curve(fraction));
      }
    };
    animation.onFinish = (): void => {
      if (generation !== this.animationGeneration || this.animator !== animation) {
        return;
      }
      // Destruction may emit another frame. Release captured UI callbacks first.
      animation.onFrame = (_fraction: number): void => {};
      animation.onFinish = (): void => {};
      this.animator = undefined;
      // Commit an exact endpoint before the owner swaps artwork/removes overlays.
      onFrame(1);
      onFinish();
    };
    onFrame(0);
    animation.play();
  }

  /** Invalidates old launches and callbacks before page/component teardown. */
  cancel(): void {
    this.generation++;
    this.timers.forEach((timer: number) => clearTimeout(timer));
    this.timers.clear();
    this.stopAnimator();
  }

  private stopAnimator(): void {
    this.animationGeneration++;
    const animation: AnimatorResult | undefined = this.animator;
    this.animator = undefined;
    if (animation !== undefined) {
      // The API can synchronously emit a final frame when cancelled.
      animation.onFrame = (_fraction: number): void => {};
      animation.onFinish = (): void => {};
      animation.cancel();
    }
  }
}

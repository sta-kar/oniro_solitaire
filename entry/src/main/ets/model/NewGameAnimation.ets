/** One tableau destination in the visible round-by-round Klondike deal. */
export class DealTarget {
  order: number;
  pileIndex: number;
  cardIndex: number;

  constructor(order: number, pileIndex: number, cardIndex: number) {
    this.order = order;
    this.pileIndex = pileIndex;
    this.cardIndex = cardIndex;
  }
}

/** Builds columns 0-6, then 1-6, continuing until the seventh top card. */
export function classicDealTargets(): DealTarget[] {
  const targets: DealTarget[] = [];
  for (let cardIndex: number = 0; cardIndex < 7; cardIndex++) {
    for (let pileIndex: number = cardIndex; pileIndex < 7; pileIndex++) {
      targets.push(new DealTarget(targets.length, pileIndex, cardIndex));
    }
  }
  return targets;
}

/** Maps two independent random bytes to a wide 1000-2800 vp/s triangular distribution. */
export function triangularSweepSpeed(firstByte: number, secondByte: number): number {
  const firstUnit: number = Math.max(0, Math.min(255, firstByte)) / 255;
  const secondUnit: number = Math.max(0, Math.min(255, secondByte)) / 255;
  return 1000 + (firstUnit + secondUnit) * 900;
}

/** Raw travel fraction on one uninterrupted flight-then-squeeze timeline. */
export function dealFlightFraction(progress: number, flightDuration: number, squeezeDuration: number): number {
  if (flightDuration <= 0) {
    return 1;
  }
  const elapsed: number = Math.max(0, progress) * (flightDuration + squeezeDuration);
  return Math.min(1, elapsed / flightDuration);
}

/** Keeps full card width throughout travel, then advances only the squeeze. */
export function dealSqueezeFraction(progress: number, flightDuration: number, squeezeDuration: number): number {
  if (squeezeDuration <= 0) {
    return 0;
  }
  const elapsed: number = Math.max(0, progress) * (flightDuration + squeezeDuration);
  return Math.max(0, Math.min(1, (elapsed - flightDuration) / squeezeDuration));
}

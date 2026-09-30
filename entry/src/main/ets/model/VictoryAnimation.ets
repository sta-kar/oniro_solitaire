/** Baseline physics/stamp cadence that defines the old-PC trail spacing. */
export const VICTORY_TICK_MS: number = 60;
export const VICTORY_TICK_SECONDS: number = VICTORY_TICK_MS / 1000;
export const VICTORY_MAX_PLAYBACK_RATE: number = 4;
/** Scheduler resolution required to stamp 4x flights at the original spacing. */
export const VICTORY_TIMER_MS: number = VICTORY_TICK_MS / VICTORY_MAX_PLAYBACK_RATE;
export const VICTORY_GRAVITY_VP_PER_SECOND_SQUARED: number = 1800;
export const VICTORY_BOUNCE_RESTITUTION: number = 0.72;
export const VICTORY_MIN_UPWARD_SPEED: number = 250;
export const VICTORY_MAX_UPWARD_SPEED: number = 375;
export const VICTORY_MIN_HORIZONTAL_SPEED: number = 90;
export const VICTORY_MAX_HORIZONTAL_SPEED: number = 240;
const VICTORY_TOTAL_CARDS: number = 52;
const VICTORY_BASELINE_CARD_COUNT: number = 5;
const VICTORY_MAX_SPEED_CARD_COUNT: number = 5;

/**
 * Returns the approved playback rate for a one-based launch number.
 * The first five cards retain the original pace, the middle cards accelerate
 * linearly, and the final five cards stay at four times the original pace.
 */
export function victoryPlaybackRate(cardNumber: number): number {
  const boundedCardNumber: number = Math.max(1, Math.min(VICTORY_TOTAL_CARDS, cardNumber));
  const maxSpeedStartsAt: number = VICTORY_TOTAL_CARDS - VICTORY_MAX_SPEED_CARD_COUNT + 1;
  if (boundedCardNumber <= VICTORY_BASELINE_CARD_COUNT) {
    return 1;
  }
  if (boundedCardNumber >= maxSpeedStartsAt) {
    return VICTORY_MAX_PLAYBACK_RATE;
  }
  const accelerationProgress: number =
    (boundedCardNumber - VICTORY_BASELINE_CARD_COUNT) /
    (maxSpeedStartsAt - VICTORY_BASELINE_CARD_COUNT);
  return 1 + accelerationProgress * (VICTORY_MAX_PLAYBACK_RATE - 1);
}

/** Mutable physics state for one card currently crossing the victory canvas. */
export class VictoryFlight {
  cardId: number;
  x: number;
  y: number;
  velocityX: number;
  velocityY: number;
  hasBounced: boolean;
  playbackRate: number;
  stampProgress: number;

  constructor(
    cardId: number,
    x: number,
    y: number,
    velocityX: number,
    velocityY: number,
    playbackRate: number = 1
  ) {
    this.cardId = cardId;
    this.x = x;
    this.y = y;
    this.velocityX = velocityX;
    this.velocityY = velocityY;
    this.hasBounced = false;
    this.playbackRate = playbackRate;
    this.stampProgress = 0;
  }
}

/**
 * Advances one flight's independent stamp clock on the shared 15 ms timer.
 * A 1x card becomes due every fourth timer tick; a 4x card is due every tick.
 */
export function isVictoryStampDue(flight: VictoryFlight): boolean {
  const playbackRate: number = Math.max(1, Math.min(VICTORY_MAX_PLAYBACK_RATE, flight.playbackRate));
  flight.stampProgress += playbackRate / VICTORY_MAX_PLAYBACK_RATE;
  if (flight.stampProgress < 1) {
    return false;
  }
  flight.stampProgress -= 1;
  return true;
}

/** Events produced by one deterministic victory physics step. */
export class VictoryStepResult {
  firstBounce: boolean;
  exited: boolean;

  constructor(firstBounce: boolean, exited: boolean) {
    this.firstBounce = firstBounce;
    this.exited = exited;
  }
}

/** Maps one random byte to an inclusive numeric range. */
export function victoryRangeFromByte(randomByte: number, minimum: number, maximum: number): number {
  const boundedByte: number = Math.max(0, Math.min(255, randomByte));
  return minimum + boundedByte / 255 * (maximum - minimum);
}

/** Chooses one currently non-empty foundation, returning -1 when none remain. */
export function selectVictoryFoundation(foundationSizes: number[], randomByte: number): number {
  const available: number[] = [];
  for (let index: number = 0; index < foundationSizes.length; index++) {
    if (foundationSizes[index] > 0) {
      available.push(index);
    }
  }
  if (available.length === 0) {
    return -1;
  }
  const boundedByte: number = Math.max(0, Math.min(255, randomByte));
  const availableIndex: number = Math.min(
    available.length - 1,
    Math.floor(boundedByte / 256 * available.length)
  );
  return available[availableIndex];
}

/** Calculates when the card's top edge reaches the bottom-aligned resting point. */
export function victoryTimeToBottom(
  y: number,
  velocityY: number,
  boardHeight: number,
  cardHeight: number
): number {
  const distance: number = Math.max(0, boardHeight - cardHeight - y);
  const discriminant: number = velocityY * velocityY +
    2 * VICTORY_GRAVITY_VP_PER_SECOND_SQUARED * distance;
  return (-velocityY + Math.sqrt(discriminant)) / VICTORY_GRAVITY_VP_PER_SECOND_SQUARED;
}

/**
 * Keeps a randomly directed launch on-screen through its first bottom impact.
 * If the sampled direction would leave too early, the same speed is reflected
 * toward the interior; a final clamp keeps the complete card inside the
 * viewport at the predicted impact instead of balancing it on an exit edge.
 */
export function keepVictoryLaunchOnScreen(
  x: number,
  velocityX: number,
  timeToBottom: number,
  boardWidth: number,
  cardWidth: number
): number {
  if (timeToBottom <= 0) {
    return velocityX;
  }
  const leftImpactBoundary: number = 0;
  const rightImpactBoundary: number = Math.max(0, boardWidth - cardWidth);
  const projectedX: number = x + velocityX * timeToBottom;
  if (projectedX >= leftImpactBoundary && projectedX <= rightImpactBoundary) {
    return velocityX;
  }
  const reflectedVelocity: number = -velocityX;
  const reflectedX: number = x + reflectedVelocity * timeToBottom;
  if (reflectedX >= leftImpactBoundary && reflectedX <= rightImpactBoundary) {
    return reflectedVelocity;
  }
  const minimumVelocity: number = (leftImpactBoundary - x) / timeToBottom;
  const maximumVelocity: number = (rightImpactBoundary - x) / timeToBottom;
  return Math.max(minimumVelocity, Math.min(maximumVelocity, reflectedVelocity));
}

/** Advances one 60 ms stamp step and reports first bounce and complete side exit. */
export function stepVictoryFlight(
  flight: VictoryFlight,
  boardWidth: number,
  boardHeight: number,
  cardWidth: number,
  cardHeight: number
): VictoryStepResult {
  flight.x += flight.velocityX * VICTORY_TICK_SECONDS;
  flight.y += flight.velocityY * VICTORY_TICK_SECONDS;
  flight.velocityY += VICTORY_GRAVITY_VP_PER_SECOND_SQUARED * VICTORY_TICK_SECONDS;

  let firstBounce: boolean = false;
  const floorY: number = boardHeight - cardHeight;
  if (flight.y >= floorY && flight.velocityY > 0) {
    flight.y = floorY;
    flight.velocityY = -flight.velocityY * VICTORY_BOUNCE_RESTITUTION;
    if (!flight.hasBounced) {
      flight.hasBounced = true;
      firstBounce = true;
    }
  }

  const exited: boolean = flight.x + cardWidth < 0 || flight.x > boardWidth;
  return new VictoryStepResult(firstBounce, exited);
}

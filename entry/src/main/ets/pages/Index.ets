import { curves } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { image } from '@kit.ImageKit';
import {
  AutoCompleteMove,
  GameSnapshot,
  PlayingCard,
  SolitaireGame
} from '../model/SolitaireGame';
import { GameStateCodec } from '../model/GameStateCodec';
import { classicDealTargets, DealTarget, triangularSweepSpeed } from '../model/NewGameAnimation';
import {
  keepVictoryLaunchOnScreen,
  isVictoryStampDue,
  selectVictoryFoundation,
  stepVictoryFlight,
  VictoryFlight,
  VICTORY_MAX_HORIZONTAL_SPEED,
  VICTORY_MAX_UPWARD_SPEED,
  VICTORY_MIN_HORIZONTAL_SPEED,
  VICTORY_MIN_UPWARD_SPEED,
  VICTORY_TIMER_MS,
  victoryPlaybackRate,
  victoryRangeFromByte,
  victoryTimeToBottom
} from '../model/VictoryAnimation';

const SOURCE_NONE: number = 0;
const SOURCE_WASTE: number = 1;
const SOURCE_FOUNDATION: number = 2;
const SOURCE_TABLEAU: number = 3;
/** Single tuning point for the approved short card-move animation. */
const MOVE_ANIMATION_DURATION_MS: number = 80;
/** A turn matches one existing card move and swaps artwork at its midpoint. */
const TURN_ANIMATION_DURATION_MS: number = MOVE_ANIMATION_DURATION_MS;
const TURN_HALF_DURATION_MS: number = TURN_ANIMATION_DURATION_MS / 2;
/** Quintic smoothstep: zero velocity and acceleration at both endpoints. */
const MOVE_ANIMATION_CURVE: ICurve = curves.customCurve((fraction: number): number => {
  const fractionSquared: number = fraction * fraction;
  const fractionCubed: number = fractionSquared * fraction;
  return fractionCubed * (fraction * (fraction * 6 - 15) + 10);
});
/** Interpolation progress that makes a 1-to-0 scale follow cos(pi * t / 2). */
const TURN_SQUEEZE_CURVE: ICurve = curves.customCurve((fraction: number): number =>
  1 - Math.cos(Math.PI * fraction / 2));
/** Interpolation progress that makes a 0-to-1 scale follow cos(pi * (1-t) / 2). */
const TURN_STRETCH_CURVE: ICurve = curves.customCurve((fraction: number): number =>
  Math.cos(Math.PI * (1 - fraction) / 2));
/** Exact 2:3 card geometry, anchored to the existing 45 px reference width. */
const CARD_REFERENCE_WIDTH: number = 45;
const CARD_REFERENCE_HEIGHT: number = 67.5;
const CARD_ASPECT_RATIO: number = CARD_REFERENCE_WIDTH / CARD_REFERENCE_HEIGHT;
const CARD_WIDTH_FRACTION: number = 0.132;
const BOARD_HORIZONTAL_PADDING: number = 20;
const DROP_HITBOX_SCALE: number = 1.5;
const DESTINATION_FOUNDATION: number = 1;
const DESTINATION_TABLEAU: number = 2;
const FOUNDATION_INDICES: number[] = [0, 1, 2, 3];
const TABLEAU_INDICES: number[] = [0, 1, 2, 3, 4, 5, 6];
const NEW_GAME_IDLE: number = 0;
const NEW_GAME_SWEEP: number = 1;
const NEW_GAME_STACK_ENTRY: number = 2;
const NEW_GAME_DEAL: number = 3;
const NEW_GAME_STOCK_FINISH: number = 4;
const STACK_ENTRY_DURATION_MS: number = 220;
const DEAL_CARD_DURATION_MS: number = 120;
const DEAL_CARD_INTERVAL_MS: number = 48;
const STOCK_FINISH_DURATION_MS: number = 160;
const LAYERED_DECK_CARD_COUNT: number = 5;
/** Single multiplier for the complete New Game sequence. */
const NEW_GAME_TIME_SCALE: number = 2;

/** Face artwork indexed by model suit, then by rank minus one. */
const CARD_FACE_IMAGES: Resource[][] = [
  [
    $r('app.media.playing_card_ace_of_clubs'),
    $r('app.media.playing_card_2_of_clubs'),
    $r('app.media.playing_card_3_of_clubs'),
    $r('app.media.playing_card_4_of_clubs'),
    $r('app.media.playing_card_5_of_clubs'),
    $r('app.media.playing_card_6_of_clubs'),
    $r('app.media.playing_card_7_of_clubs'),
    $r('app.media.playing_card_8_of_clubs'),
    $r('app.media.playing_card_9_of_clubs'),
    $r('app.media.playing_card_10_of_clubs'),
    $r('app.media.playing_card_jack_of_clubs'),
    $r('app.media.playing_card_queen_of_clubs'),
    $r('app.media.playing_card_king_of_clubs')
  ],
  [
    $r('app.media.playing_card_ace_of_diamonds'),
    $r('app.media.playing_card_2_of_diamonds'),
    $r('app.media.playing_card_3_of_diamonds'),
    $r('app.media.playing_card_4_of_diamonds'),
    $r('app.media.playing_card_5_of_diamonds'),
    $r('app.media.playing_card_6_of_diamonds'),
    $r('app.media.playing_card_7_of_diamonds'),
    $r('app.media.playing_card_8_of_diamonds'),
    $r('app.media.playing_card_9_of_diamonds'),
    $r('app.media.playing_card_10_of_diamonds'),
    $r('app.media.playing_card_jack_of_diamonds'),
    $r('app.media.playing_card_queen_of_diamonds'),
    $r('app.media.playing_card_king_of_diamonds')
  ],
  [
    $r('app.media.playing_card_ace_of_hearts'),
    $r('app.media.playing_card_2_of_hearts'),
    $r('app.media.playing_card_3_of_hearts'),
    $r('app.media.playing_card_4_of_hearts'),
    $r('app.media.playing_card_5_of_hearts'),
    $r('app.media.playing_card_6_of_hearts'),
    $r('app.media.playing_card_7_of_hearts'),
    $r('app.media.playing_card_8_of_hearts'),
    $r('app.media.playing_card_9_of_hearts'),
    $r('app.media.playing_card_10_of_hearts'),
    $r('app.media.playing_card_jack_of_hearts'),
    $r('app.media.playing_card_queen_of_hearts'),
    $r('app.media.playing_card_king_of_hearts')
  ],
  [
    $r('app.media.playing_card_ace_of_spades'),
    $r('app.media.playing_card_2_of_spades'),
    $r('app.media.playing_card_3_of_spades'),
    $r('app.media.playing_card_4_of_spades'),
    $r('app.media.playing_card_5_of_spades'),
    $r('app.media.playing_card_6_of_spades'),
    $r('app.media.playing_card_7_of_spades'),
    $r('app.media.playing_card_8_of_spades'),
    $r('app.media.playing_card_9_of_spades'),
    $r('app.media.playing_card_10_of_spades'),
    $r('app.media.playing_card_jack_of_spades'),
    $r('app.media.playing_card_queen_of_spades'),
    $r('app.media.playing_card_king_of_spades')
  ]
];
/** Approved sparse face artwork, indexed by model suit and rank minus one. */
const SIMPLE_CARD_FACE_IMAGES: Resource[][] = [
  [
    $r('app.media.playing_card_simple_ace_of_clubs'),
    $r('app.media.playing_card_simple_2_of_clubs'),
    $r('app.media.playing_card_simple_3_of_clubs'),
    $r('app.media.playing_card_simple_4_of_clubs'),
    $r('app.media.playing_card_simple_5_of_clubs'),
    $r('app.media.playing_card_simple_6_of_clubs'),
    $r('app.media.playing_card_simple_7_of_clubs'),
    $r('app.media.playing_card_simple_8_of_clubs'),
    $r('app.media.playing_card_simple_9_of_clubs'),
    $r('app.media.playing_card_simple_10_of_clubs'),
    $r('app.media.playing_card_simple_jack_of_clubs'),
    $r('app.media.playing_card_simple_queen_of_clubs'),
    $r('app.media.playing_card_simple_king_of_clubs')
  ],
  [
    $r('app.media.playing_card_simple_ace_of_diamonds'),
    $r('app.media.playing_card_simple_2_of_diamonds'),
    $r('app.media.playing_card_simple_3_of_diamonds'),
    $r('app.media.playing_card_simple_4_of_diamonds'),
    $r('app.media.playing_card_simple_5_of_diamonds'),
    $r('app.media.playing_card_simple_6_of_diamonds'),
    $r('app.media.playing_card_simple_7_of_diamonds'),
    $r('app.media.playing_card_simple_8_of_diamonds'),
    $r('app.media.playing_card_simple_9_of_diamonds'),
    $r('app.media.playing_card_simple_10_of_diamonds'),
    $r('app.media.playing_card_simple_jack_of_diamonds'),
    $r('app.media.playing_card_simple_queen_of_diamonds'),
    $r('app.media.playing_card_simple_king_of_diamonds')
  ],
  [
    $r('app.media.playing_card_simple_ace_of_hearts'),
    $r('app.media.playing_card_simple_2_of_hearts'),
    $r('app.media.playing_card_simple_3_of_hearts'),
    $r('app.media.playing_card_simple_4_of_hearts'),
    $r('app.media.playing_card_simple_5_of_hearts'),
    $r('app.media.playing_card_simple_6_of_hearts'),
    $r('app.media.playing_card_simple_7_of_hearts'),
    $r('app.media.playing_card_simple_8_of_hearts'),
    $r('app.media.playing_card_simple_9_of_hearts'),
    $r('app.media.playing_card_simple_10_of_hearts'),
    $r('app.media.playing_card_simple_jack_of_hearts'),
    $r('app.media.playing_card_simple_queen_of_hearts'),
    $r('app.media.playing_card_simple_king_of_hearts')
  ],
  [
    $r('app.media.playing_card_simple_ace_of_spades'),
    $r('app.media.playing_card_simple_2_of_spades'),
    $r('app.media.playing_card_simple_3_of_spades'),
    $r('app.media.playing_card_simple_4_of_spades'),
    $r('app.media.playing_card_simple_5_of_spades'),
    $r('app.media.playing_card_simple_6_of_spades'),
    $r('app.media.playing_card_simple_7_of_spades'),
    $r('app.media.playing_card_simple_8_of_spades'),
    $r('app.media.playing_card_simple_9_of_spades'),
    $r('app.media.playing_card_simple_10_of_spades'),
    $r('app.media.playing_card_simple_jack_of_spades'),
    $r('app.media.playing_card_simple_queen_of_spades'),
    $r('app.media.playing_card_simple_king_of_spades')
  ]
];
/** Concrete packaged card backs; Random is a persisted mode, not an image. */
const CARD_BACK_IMAGES: Resource[] = [
  $r('app.media.playing_card_card_back'),
  $r('app.media.playing_card_back_oniro'),
  $r('app.media.playing_card_back_emerald'),
  $r('app.media.playing_card_back_prism'),
  $r('app.media.playing_card_back_eclipse')
];
const CARD_BACK_LABELS: string[] = ['Default', 'Oniro', 'Emerald', 'Prism', 'Eclipse', 'Random'];
const DEFAULT_CARD_BACK_INDEX: number = 0;
const RANDOM_CARD_BACK_INDEX: number = CARD_BACK_IMAGES.length;
const CARD_BACK_PREFERENCES_NAME: string = 'solitaire_settings';
const CARD_BACK_PREFERENCE_KEY: string = 'card_back';
const ACTIVE_CARD_BACK_PREFERENCE_KEY: string = 'active_card_back';
const TABLE_BACKGROUND_PREFERENCE_KEY: string = 'table_background';
const TABLE_BACKGROUND_SOLID: number = 0;
const TABLE_BACKGROUND_SUITS: number = 1;
const CARD_FRONT_PREFERENCE_KEY: string = 'card_front';
const ACTIVE_GAME_PREFERENCE_KEY: string = 'active_game_v1';
const DRAW_COUNT_PREFERENCE_KEY: string = 'draw_count';
const WASTE_RESET_LIMIT_PREFERENCE_KEY: string = 'waste_reset_limit';
const CARD_FRONT_DETAILED: number = 0;
const CARD_FRONT_SIMPLE: number = 1;
const DRAW_COUNT_ONE: number = 1;
const DRAW_COUNT_THREE: number = 3;
const WASTE_RESET_LIMIT_UNLIMITED: number = 0;
const WASTE_RESET_LIMIT_THREE: number = 3;
const VISIBLE_WASTE_CARD_COUNT: number = 3;
/** Horizontal reveal per waste card, relative to the responsive card width. */
const WASTE_FAN_OFFSET_FRACTION: number = 0.28;

/** Window-relative card placement captured from an ArkUI click event. */
class CardPlacement {
  x: number;
  y: number;

  constructor(x: number, y: number) {
    this.x = x;
    this.y = y;
  }
}

/** One expanded drag destination ordered by distance from its card center. */
class DropCandidate {
  destination: number;
  pileIndex: number;
  distanceSquared: number;

  constructor(destination: number, pileIndex: number, distanceSquared: number) {
    this.destination = destination;
    this.pileIndex = pileIndex;
    this.distanceSquared = distanceSquared;
  }
}

/** A face-down tableau card and its fixed position before a move exposes it. */
class CardReveal {
  card: PlayingCard;
  placement: CardPlacement;

  constructor(card: PlayingCard, placement: CardPlacement) {
    this.card = card;
    this.placement = placement;
  }
}

/** Object-wrapped callback, because V1 ArkUI does not allow Function @Props. */
class AnimationCompletion {
  finish: () => void;

  constructor(finish: () => void) {
    this.finish = finish;
  }
}

/** Keeps a dealing component mounted between its landing and final turn. */
class DealAnimationCompletion {
  land: () => void;
  finish: () => void;

  constructor(land: () => void, finish: () => void) {
    this.land = land;
    this.finish = finish;
  }
}

/** One current card and its independently timed vertical sweep. */
class SweepCardAnimation {
  card: PlayingCard;
  x: number;
  y: number;
  travelY: number;
  duration: number;
  zIndex: number;

  constructor(card: PlayingCard, x: number, y: number, travelY: number, duration: number, zIndex: number) {
    this.card = card;
    this.x = x;
    this.y = y;
    this.travelY = travelY;
    this.duration = duration;
    this.zIndex = zIndex;
  }
}

/** One retained waste card sliding from its old fan slot to its new slot. */
class WasteShiftAnimation {
  card: PlayingCard;
  x: number;
  y: number;
  travelX: number;

  constructor(card: PlayingCard, x: number, y: number, travelX: number) {
    this.card = card;
    this.x = x;
    this.y = y;
    this.travelX = travelX;
  }
}

/** One new tableau card, with both sides prepared for its landing turn. */
class DealCardAnimation {
  order: number;
  pileIndex: number;
  cardIndex: number;
  faceDownCard: PlayingCard;
  targetCard: PlayingCard;
  destinationX: number;
  destinationY: number;

  constructor(target: DealTarget, card: PlayingCard, destination: CardPlacement) {
    this.order = target.order;
    this.pileIndex = target.pileIndex;
    this.cardIndex = target.cardIndex;
    this.faceDownCard = card.clone();
    this.faceDownCard.faceUp = false;
    this.targetCard = card.clone();
    this.destinationX = destination.x;
    this.destinationY = destination.y;
  }
}

/** Resolves the packaged SVG without coupling the game model to UI resources. */
function cardImage(card: PlayingCard, cardBackIndex: number, cardFront: number): Resource {
  if (!card.faceUp) {
    return CARD_BACK_IMAGES[cardBackIndex];
  }
  const faceImages: Resource[][] = cardFront === CARD_FRONT_SIMPLE ? SIMPLE_CARD_FACE_IMAGES : CARD_FACE_IMAGES;
  return faceImages[card.suit][card.rank - 1];
}

/** Reactive visual for one playing card, including approved selection feedback. */
@Component
struct PlayingCardView {
  @Prop card: PlayingCard;
  @Prop cardBackIndex: number;
  @Prop cardFront: number;
  @Prop selected: boolean;

  build() {
    Stack() {
      Image(cardImage(this.card, this.cardBackIndex, this.cardFront))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .borderRadius(7)

      if (this.selected) {
        Stack()
          .width('100%')
          .height('100%')
          .borderRadius(7)
          .border({ width: 3, color: '#FFD54F' })
          .hitTestBehavior(HitTestMode.None)
      }
    }
    .width('100%')
    .aspectRatio(CARD_ASPECT_RATIO)
    .backgroundColor(this.card.faceUp ? '#FFFDF8' : '#235A96')
    .borderRadius(7)
    .shadow({
      radius: this.selected ? 9 : 4,
      color: this.selected ? '#99FFD54F' : '#44000000',
      offsetX: 0,
      offsetY: this.selected ? 0 : 2
    })
  }
}

/** Selection-free card visual used by the isolated turning overlay. */
@Component
struct AnimatedPlayingCardView {
  @Prop card: PlayingCard;
  @Prop cardBackIndex: number;
  @Prop cardFront: number;

  build() {
    Stack() {
      Image(cardImage(this.card, this.cardBackIndex, this.cardFront))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)
        .borderRadius(7)
    }
    .width('100%')
    .aspectRatio(CARD_ASPECT_RATIO)
    .backgroundColor(this.card.faceUp ? '#FFFDF8' : '#235A96')
    .borderRadius(7)
    .shadow({ radius: 4, color: '#44000000', offsetX: 0, offsetY: 2 })
  }
}

/** Owns one independently timed card in the simultaneous upward clear-out. */
@Component
struct SweepingCardView {
  @Prop item: SweepCardAnimation;
  @Prop cardBackIndex: number;
  @Prop cardFront: number;
  @Prop completion: AnimationCompletion;
  @State offsetY: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: this.item.duration,
        curve: Curve.Linear,
        onFinish: () => this.completion.finish()
      }, () => {
        this.offsetY = this.item.travelY;
      });
    }, 0);
  }

  build() {
    AnimatedPlayingCardView({
      card: this.item.card,
      cardBackIndex: this.cardBackIndex,
      cardFront: this.cardFront
    })
      .width('100%')
      .height('100%')
      .translate({ y: this.offsetY })
  }
}

/** Owns the horizontal movement of one retained card in the rolling waste window. */
@Component
struct SlidingWasteCardView {
  @Prop item: WasteShiftAnimation;
  @Prop cardBackIndex: number;
  @Prop cardFront: number;
  @Prop completion: AnimationCompletion;
  @State offsetX: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: MOVE_ANIMATION_DURATION_MS,
        curve: MOVE_ANIMATION_CURVE,
        onFinish: () => this.completion.finish()
      }, () => {
        this.offsetX = this.item.travelX;
      });
    }, 0);
  }

  build() {
    AnimatedPlayingCardView({
      card: this.item.card,
      cardBackIndex: this.cardBackIndex,
      cardFront: this.cardFront
    })
      .width('100%')
      .height('100%')
      .translate({ x: this.offsetX })
      .hitTestBehavior(HitTestMode.None)
  }
}

/** Launches one face-down card after its ordered cascade delay. */
@Component
struct DealingCardView {
  @Prop item: DealCardAnimation;
  @Prop cardBackIndex: number;
  @Prop cardFront: number;
  @Prop travelX: number;
  @Prop travelY: number;
  @Prop completion: DealAnimationCompletion;
  @State offsetX: number = 0;
  @State offsetY: number = 0;
  @State scaleX: number = 1;
  @State showTarget: boolean = false;
  @State hasLaunched: boolean = false;

  aboutToAppear(): void {
    const launchDelay: number = this.item.order * DEAL_CARD_INTERVAL_MS * NEW_GAME_TIME_SCALE;
    setTimeout(() => {
      // Delayed cards belong visually to the deck until their actual launch.
      // Commit visibility first so it does not fade as part of the flight.
      this.hasLaunched = true;
      setTimeout(() => {
        this.getUIContext().animateTo({
          duration: DEAL_CARD_DURATION_MS * NEW_GAME_TIME_SCALE,
          curve: MOVE_ANIMATION_CURVE,
          onFinish: () => this.finishFlight()
        }, () => {
          this.offsetX = this.travelX;
          this.offsetY = this.travelY;
        });
      }, 0);
    }, launchDelay);
  }

  private finishFlight(): void {
    this.completion.land();
    if (!this.item.targetCard.faceUp) {
      this.completion.finish();
      return;
    }
    // A new explicit animation must be dispatched after the completed travel
    // transaction releases this component's animatable properties.
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: TURN_HALF_DURATION_MS * NEW_GAME_TIME_SCALE,
        curve: TURN_SQUEEZE_CURVE,
        onFinish: () => {
          this.showTarget = true;
          setTimeout(() => {
            this.getUIContext().animateTo({
              duration: TURN_HALF_DURATION_MS * NEW_GAME_TIME_SCALE,
              curve: TURN_STRETCH_CURVE,
              onFinish: () => this.completion.finish()
            }, () => {
              this.scaleX = 1;
            });
          }, 0);
        }
      }, () => {
        this.scaleX = 0;
      });
    }, 0);
  }

  build() {
    Stack() {
      AnimatedPlayingCardView({
        card: this.item.faceDownCard,
        cardBackIndex: this.cardBackIndex,
        cardFront: this.cardFront
      })
        .opacity(this.showTarget ? 0 : 1)

      AnimatedPlayingCardView({
        card: this.item.targetCard,
        cardBackIndex: this.cardBackIndex,
        cardFront: this.cardFront
      })
        .opacity(this.showTarget ? 1 : 0)
    }
    .width('100%')
    .height('100%')
    .scale({ x: this.scaleX, y: 1 })
    .translate({ x: this.offsetX, y: this.offsetY })
    .opacity(this.hasLaunched ? 1 : 0)
  }
}

/** Locally owns the midpoint artwork swap so the board never rebuilds for it. */
@Component
struct TurningCardStack {
  @Prop initialCards: PlayingCard[];
  @Prop targetCards: PlayingCard[];
  @Prop cardBackIndex: number;
  @Prop cardFront: number;
  @Prop completion: AnimationCompletion;
  @State scaleX: number = 1;
  @State showTarget: boolean = false;

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: TURN_HALF_DURATION_MS,
        curve: TURN_SQUEEZE_CURVE,
        onFinish: () => {
          this.showTarget = true;
          // Commit the new artwork while the stack has zero horizontal width.
          setTimeout(() => {
            this.getUIContext().animateTo({
              duration: TURN_HALF_DURATION_MS,
              curve: TURN_STRETCH_CURVE,
              onFinish: () => this.completion.finish()
            }, () => {
              this.scaleX = 1;
            });
          }, 0);
        }
      }, () => {
        this.scaleX = 0;
      });
    }, 0);
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.initialCards, (card: PlayingCard, cardIndex: number) => {
        Stack() {
          AnimatedPlayingCardView({ card: card, cardBackIndex: this.cardBackIndex, cardFront: this.cardFront })
            .opacity(this.showTarget ? 0 : 1)

          AnimatedPlayingCardView({
            card: this.targetCards[cardIndex],
            cardBackIndex: this.cardBackIndex,
            cardFront: this.cardFront
          })
            .opacity(this.showTarget ? 1 : 0)
        }
        .width('100%')
        .position({ x: 0, y: 0 })
        .zIndex(cardIndex)
      }, (card: PlayingCard, _cardIndex: number) => `turning-${card.id}`)
    }
    .width('100%')
    .height('100%')
    .scale({ x: this.scaleX, y: 1 })
    .hitTestBehavior(HitTestMode.None)
  }
}

/** Runs quintic travel outside the child component that owns cosine turning. */
@Component
struct MovingTurningCardStack {
  @Prop initialCards: PlayingCard[];
  @Prop targetCards: PlayingCard[];
  @Prop cardBackIndex: number;
  @Prop cardFront: number;
  @Prop travelX: number;
  @Prop travelY: number;
  @Prop completion: AnimationCompletion;
  @State positionX: number = 0;
  @State positionY: number = 0;

  aboutToAppear(): void {
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: MOVE_ANIMATION_DURATION_MS,
        curve: MOVE_ANIMATION_CURVE
      }, () => {
        this.positionX = this.travelX;
        this.positionY = this.travelY;
      });
    }, 0);
  }

  build() {
    TurningCardStack({
      initialCards: this.initialCards,
      targetCards: this.targetCards,
      cardBackIndex: this.cardBackIndex,
      cardFront: this.cardFront,
      completion: this.completion
    })
      .width('100%')
      .height('100%')
      .position({ x: this.positionX, y: this.positionY })
  }
}

/** Main ArkUI page for the approved portrait solitaire experience. */
@Entry
@Component
struct Index {
  private game: SolitaireGame = new SolitaireGame();

  @State stock: PlayingCard[] = [];
  @State waste: PlayingCard[] = [];
  @State foundations: PlayingCard[][] = [[], [], [], []];
  @State tableau: PlayingCard[][] = [[], [], [], [], [], [], []];
  @State selectedSource: number = SOURCE_NONE;
  @State selectedPile: number = -1;
  @State selectedCard: number = -1;
  @State canUndo: boolean = false;
  @State canAutoComplete: boolean = false;
  @State won: boolean = false;
  @State movingCards: PlayingCard[] = [];
  @State movingTargetCards: PlayingCard[] = [];
  @State wasteShiftAnimations: WasteShiftAnimation[] = [];
  @State coveredWasteCards: WasteShiftAnimation[] = [];
  @State wasteTransitionGeneration: number = 0;
  @State movingCardX: number = 0;
  @State movingCardY: number = 0;
  @State movingCardDestinationX: number = 0;
  @State movingCardDestinationY: number = 0;
  @State movingCardsAligned: boolean = false;
  @State moveInProgress: boolean = false;
  @State boardWidth: number = 360;
  @State boardHeight: number = 720;
  @State selectedCardBack: number = DEFAULT_CARD_BACK_INDEX;
  @State activeCardBack: number = DEFAULT_CARD_BACK_INDEX;
  @State selectedTableBackground: number = TABLE_BACKGROUND_SOLID;
  @State selectedCardFront: number = CARD_FRONT_DETAILED;
  @State selectedDrawCount: number = DRAW_COUNT_ONE;
  @State selectedWasteResetLimit: number = WASTE_RESET_LIMIT_UNLIMITED;
  @State wasteResetsUsed: number = 0;
  @State settingsOpen: boolean = false;
  @State newGamePhase: number = NEW_GAME_IDLE;
  @State sweepAnimations: SweepCardAnimation[] = [];
  @State dealAnimations: DealCardAnimation[] = [];
  @State stagedDeckX: number = 0;
  @State stagedDeckY: number = 0;

  private selectedCardX: number = 0;
  private selectedCardY: number = 0;
  private boardX: number = 0;
  private boardY: number = 0;
  private stockPlacement: CardPlacement = new CardPlacement(0, 0);
  private wastePlacement: CardPlacement = new CardPlacement(0, 0);
  private foundationPlacements: Map<number, CardPlacement> = new Map<number, CardPlacement>();
  private tableauPlacements: Map<number, CardPlacement> = new Map<number, CardPlacement>();
  private tableauCardPlacements: Map<number, CardPlacement> = new Map<number, CardPlacement>();
  private continueAfterMovingTurn: boolean = false;
  private stockDrawSequenceActive: boolean = false;
  private stockDrawStepsRemaining: number = 0;
  private drawStepCompletionsRemaining: number = 0;
  private wasteMoveTransitionActive: boolean = false;
  private wasteMoveCompletionsRemaining: number = 0;
  private dragInProgress: boolean = false;
  private dragOriginX: number = 0;
  private dragOriginY: number = 0;
  private dragPointerOffsetX: number = 0;
  private dragPointerOffsetY: number = 0;
  private sweepCardsRemaining: number = 0;
  private dealFlightsRemaining: number = 0;
  private pendingCardBack: number = -1;
  private animationRandom: cryptoFramework.Random = cryptoFramework.createRandom();
  private cardBackRandom: cryptoFramework.Random = cryptoFramework.createRandom();
  private saveQueue: Promise<void> = Promise.resolve();
  private victoryContext: CanvasRenderingContext2D =
    new CanvasRenderingContext2D(new RenderingContextSettings(true));
  private victoryPixelMaps: Map<number, image.PixelMap> = new Map<number, image.PixelMap>();
  private victoryFlights: VictoryFlight[] = [];
  private victoryTimer: number = -1;
  private victoryGeneration: number = 0;
  private victoryCanvasReady: boolean = false;
  private victoryImagesReady: boolean = false;
  private victoryCardsLaunched: number = 0;

  aboutToAppear(): void {
    this.moveInProgress = true;
    this.loadTableBackgroundPreference();
    this.loadCardFrontPreference();
    this.initializeCardBackAndGame();
  }

  aboutToDisappear(): void {
    this.stopVictoryCelebration(false);
  }

  /** Prepares a fresh transparent drawing surface for a completed board. */
  private beginVictoryCelebration(): void {
    this.stopVictoryCelebration(false);
    this.victoryGeneration++;
    const generation: number = this.victoryGeneration;
    this.victoryCanvasReady = false;
    this.victoryImagesReady = false;
    this.victoryFlights = [];
    this.victoryCardsLaunched = 0;
    this.loadVictoryImages(generation);
  }

  /** Decodes the selected card family once so every trail stamp is inexpensive. */
  private async loadVictoryImages(generation: number): Promise<void> {
    const cards: PlayingCard[] = [];
    for (const pile of this.foundations) {
      for (const card of pile) {
        cards.push(card);
      }
    }
    const loads: Promise<void>[] = [];
    for (const card of cards) {
      loads.push(this.loadVictoryImage(card, generation));
    }
    try {
      await Promise.all(loads);
      if (generation !== this.victoryGeneration || !this.won) {
        return;
      }
      this.victoryImagesReady = true;
      this.tryStartVictoryCelebration();
    } catch (err) {
      console.error('[SolitaireVictory] card decode failed: ' + JSON.stringify(err));
    }
  }

  /** Decodes one packaged SVG into the PixelMap accepted by Canvas.drawImage. */
  private async loadVictoryImage(card: PlayingCard, generation: number): Promise<void> {
    const hostContext = this.getUIContext().getHostContext();
    if (hostContext === undefined) {
      throw new Error('Host context unavailable');
    }
    const resource: Resource = cardImage(card, this.activeCardBack, this.selectedCardFront);
    const content: Uint8Array = await hostContext.resourceManager.getMediaContent(resource.id);
    const source: image.ImageSource = image.createImageSource(
      content.buffer.slice(0, content.buffer.byteLength)
    );
    const pixelMap: image.PixelMap = await source.createPixelMap({
      desiredSize: {
        width: Math.round(CARD_REFERENCE_WIDTH * 4),
        height: Math.round(CARD_REFERENCE_HEIGHT * 4)
      },
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    await source.release();
    if (generation !== this.victoryGeneration || !this.won) {
      await pixelMap.release();
      return;
    }
    this.victoryPixelMaps.set(card.id, pixelMap);
  }

  /** Starts only after both Canvas and all card resources are ready and measured. */
  private tryStartVictoryCelebration(): void {
    if (!this.won || !this.victoryCanvasReady || !this.victoryImagesReady ||
      this.foundationPlacements.size < FOUNDATION_INDICES.length || this.victoryTimer >= 0) {
      return;
    }
    this.victoryContext.clearRect(0, 0, this.boardWidth, this.boardHeight);
    this.launchVictoryCard();
    this.victoryTimer = setInterval(() => this.tickVictoryCelebration(), VICTORY_TIMER_MS);
  }

  /** Removes one random foundation top and gives it an approved lively launch. */
  private launchVictoryCard(): void {
    const foundationSizes: number[] = this.foundations.map((pile: PlayingCard[]) => pile.length);
    const randomBytes: Uint8Array = this.animationRandom.generateRandomSync(4).data;
    const foundationIndex: number = selectVictoryFoundation(foundationSizes, randomBytes[0]);
    if (foundationIndex < 0) {
      return;
    }

    const pile: PlayingCard[] = this.foundations[foundationIndex];
    const card: PlayingCard = pile[pile.length - 1];
    const updatedFoundations: PlayingCard[][] = this.foundations.slice();
    updatedFoundations[foundationIndex] = pile.slice(0, pile.length - 1);
    this.foundations = updatedFoundations;

    const source: CardPlacement = this.boardPlacement(this.foundationPlacements.get(foundationIndex));
    const cardHeight: number = this.scaledCardHeight();
    const cardWidth: number = cardHeight * CARD_ASPECT_RATIO;
    const velocityY: number = -victoryRangeFromByte(
      randomBytes[1], VICTORY_MIN_UPWARD_SPEED, VICTORY_MAX_UPWARD_SPEED);
    const horizontalMagnitude: number = victoryRangeFromByte(
      randomBytes[2], VICTORY_MIN_HORIZONTAL_SPEED, VICTORY_MAX_HORIZONTAL_SPEED);
    const sampledVelocityX: number = randomBytes[3] < 128 ? -horizontalMagnitude : horizontalMagnitude;
    const timeToBottom: number = victoryTimeToBottom(
      source.y, velocityY, this.boardHeight, cardHeight);
    const velocityX: number = keepVictoryLaunchOnScreen(
      source.x, sampledVelocityX, timeToBottom, this.boardWidth, cardWidth);
    this.victoryCardsLaunched++;
    const flight: VictoryFlight = new VictoryFlight(
      card.id,
      source.x,
      source.y,
      velocityX,
      velocityY,
      victoryPlaybackRate(this.victoryCardsLaunched)
    );
    this.victoryFlights.push(flight);
    this.drawVictoryCard(flight);
  }

  /** Stamps each current position, then advances physics without clearing old pixels. */
  private tickVictoryCelebration(): void {
    if (!this.won) {
      this.stopVictoryCelebration(false);
      return;
    }
    const cardHeight: number = this.scaledCardHeight();
    const cardWidth: number = cardHeight * CARD_ASPECT_RATIO;
    let launchNext: boolean = false;
    const remainingFlights: VictoryFlight[] = [];
    for (const flight of this.victoryFlights) {
      if (!isVictoryStampDue(flight)) {
        remainingFlights.push(flight);
        continue;
      }
      this.drawVictoryCard(flight);
      const result = stepVictoryFlight(flight, this.boardWidth, this.boardHeight, cardWidth, cardHeight);
      if (result.firstBounce) {
        launchNext = true;
      }
      if (!result.exited) {
        remainingFlights.push(flight);
      }
    }
    this.victoryFlights = remainingFlights;
    if (launchNext) {
      this.launchVictoryCard();
    }
    if (this.victoryFlights.length === 0) {
      const foundationIndex: number = selectVictoryFoundation(
        this.foundations.map((pile: PlayingCard[]) => pile.length), 0);
      if (foundationIndex >= 0) {
        // A coarse fixed step must never strand remaining foundations even if
        // a flight crosses a side edge immediately before its first impact.
        this.launchVictoryCard();
      } else {
        this.stopVictoryTimer();
      }
    }
  }

  /** Draws the current card with the same understated shadow as board cards. */
  private drawVictoryCard(flight: VictoryFlight): void {
    const pixelMap: image.PixelMap | undefined = this.victoryPixelMaps.get(flight.cardId);
    if (pixelMap === undefined) {
      return;
    }
    const cardHeight: number = this.scaledCardHeight();
    const cardWidth: number = cardHeight * CARD_ASPECT_RATIO;
    this.victoryContext.shadowBlur = 4;
    this.victoryContext.shadowColor = '#44000000';
    this.victoryContext.shadowOffsetX = 0;
    this.victoryContext.shadowOffsetY = 2;
    this.victoryContext.drawImage(pixelMap, flight.x, flight.y, cardWidth, cardHeight);
  }

  private stopVictoryTimer(): void {
    if (this.victoryTimer >= 0) {
      clearInterval(this.victoryTimer);
      this.victoryTimer = -1;
    }
  }

  /** Cancels all transient work; optional clearing makes a victory tap instantaneous. */
  private stopVictoryCelebration(clearCanvas: boolean): void {
    this.stopVictoryTimer();
    this.victoryGeneration++;
    this.victoryFlights = [];
    this.victoryCardsLaunched = 0;
    this.victoryImagesReady = false;
    if (clearCanvas && this.victoryCanvasReady) {
      this.victoryContext.clearRect(0, 0, this.boardWidth, this.boardHeight);
    }
    this.victoryCanvasReady = false;
    this.victoryPixelMaps.forEach((pixelMap: image.PixelMap) => {
      pixelMap.release();
    });
    this.victoryPixelMaps.clear();
  }

  /** Loads the appearance mode before restoring or creating the board it belongs to. */
  private async initializeCardBackAndGame(): Promise<void> {
    await this.loadCardBackPreference();
    await this.loadDrawCountPreference();
    await this.loadWasteResetLimitPreference();
    await this.initializeGame();
  }

  /** Restores both the selected mode and the concrete back assigned to this game. */
  private async loadCardBackPreference(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      const storedValue = await store.get(CARD_BACK_PREFERENCE_KEY, DEFAULT_CARD_BACK_INDEX);
      const storedIndex: number = Number(storedValue);
      if (Number.isInteger(storedIndex) && storedIndex >= 0 && storedIndex < CARD_BACK_LABELS.length) {
        this.selectedCardBack = storedIndex;
      }
      if (this.selectedCardBack === RANDOM_CARD_BACK_INDEX) {
        const storedActiveValue = await store.get(ACTIVE_CARD_BACK_PREFERENCE_KEY, DEFAULT_CARD_BACK_INDEX);
        const storedActiveIndex: number = Number(storedActiveValue);
        if (Number.isInteger(storedActiveIndex) && storedActiveIndex >= 0 &&
          storedActiveIndex < CARD_BACK_IMAGES.length) {
          this.activeCardBack = storedActiveIndex;
        } else {
          this.activeCardBack = DEFAULT_CARD_BACK_INDEX;
        }
      } else {
        this.activeCardBack = this.selectedCardBack;
      }
    } catch (err) {
      console.error('[SolitaireSettings] load failed: ' + JSON.stringify(err));
    }
  }

  /** Concrete choices apply now; Random starts changing with the next new game. */
  private selectCardBack(cardBackIndex: number): void {
    if (cardBackIndex < 0 || cardBackIndex >= CARD_BACK_LABELS.length) {
      return;
    }
    this.selectedCardBack = cardBackIndex;
    if (cardBackIndex !== RANDOM_CARD_BACK_INDEX) {
      this.activeCardBack = cardBackIndex;
    }
    this.saveCardBackPreference(cardBackIndex, this.activeCardBack);
  }

  private async saveCardBackPreference(cardBackIndex: number, activeCardBackIndex: number): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      await store.put(CARD_BACK_PREFERENCE_KEY, cardBackIndex);
      await store.put(ACTIVE_CARD_BACK_PREFERENCE_KEY, activeCardBackIndex);
      await store.flush();
    } catch (err) {
      console.error('[SolitaireSettings] save failed: ' + JSON.stringify(err));
    }
  }

  /** Uses rejection sampling so every concrete back has exactly equal odds. */
  private randomCardBackIndex(): number {
    const acceptedByteCount: number = Math.floor(256 / CARD_BACK_IMAGES.length) * CARD_BACK_IMAGES.length;
    let randomByte: number = 255;
    while (randomByte >= acceptedByteCount) {
      randomByte = this.cardBackRandom.generateRandomSync(1).data[0];
    }
    return randomByte % CARD_BACK_IMAGES.length;
  }

  /** Prepares and persists a fresh back without changing the outgoing cards. */
  private prepareCardBackForNewGame(): void {
    if (this.selectedCardBack !== RANDOM_CARD_BACK_INDEX) {
      this.pendingCardBack = -1;
      return;
    }
    this.pendingCardBack = this.randomCardBackIndex();
    this.saveCardBackPreference(this.selectedCardBack, this.pendingCardBack);
  }

  /** Reveals the prepared back only in the empty interval between both decks. */
  private applyPendingCardBack(): void {
    if (this.pendingCardBack < 0 || this.pendingCardBack >= CARD_BACK_IMAGES.length) {
      return;
    }
    this.activeCardBack = this.pendingCardBack;
    this.pendingCardBack = -1;
  }

  /** Restores the approved Solid/Suits table choice, defaulting safely to Solid. */
  private async loadTableBackgroundPreference(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      const storedValue = await store.get(TABLE_BACKGROUND_PREFERENCE_KEY, TABLE_BACKGROUND_SOLID);
      const storedBackground: number = Number(storedValue);
      if (storedBackground === TABLE_BACKGROUND_SOLID || storedBackground === TABLE_BACKGROUND_SUITS) {
        this.selectedTableBackground = storedBackground;
      }
    } catch (err) {
      console.error('[SolitaireSettings] table background load failed: ' + JSON.stringify(err));
    }
  }

  /** Applies a table background immediately and persists it without dismissing settings. */
  private selectTableBackground(tableBackground: number): void {
    if (tableBackground !== TABLE_BACKGROUND_SOLID && tableBackground !== TABLE_BACKGROUND_SUITS) {
      return;
    }
    this.selectedTableBackground = tableBackground;
    this.saveTableBackgroundPreference(tableBackground);
  }

  private async saveTableBackgroundPreference(tableBackground: number): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      await store.put(TABLE_BACKGROUND_PREFERENCE_KEY, tableBackground);
      await store.flush();
    } catch (err) {
      console.error('[SolitaireSettings] table background save failed: ' + JSON.stringify(err));
    }
  }

  /** Restores the approved Detailed/Simple face choice, defaulting safely to Detailed. */
  private async loadCardFrontPreference(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      const storedValue = await store.get(CARD_FRONT_PREFERENCE_KEY, CARD_FRONT_DETAILED);
      const storedCardFront: number = Number(storedValue);
      if (storedCardFront === CARD_FRONT_DETAILED || storedCardFront === CARD_FRONT_SIMPLE) {
        this.selectedCardFront = storedCardFront;
      }
    } catch (err) {
      console.error('[SolitaireSettings] card front load failed: ' + JSON.stringify(err));
    }
  }

  /** Applies a card-front design immediately and persists it without dismissing settings. */
  private selectCardFront(cardFront: number): void {
    if (cardFront !== CARD_FRONT_DETAILED && cardFront !== CARD_FRONT_SIMPLE) {
      return;
    }
    this.selectedCardFront = cardFront;
    this.saveCardFrontPreference(cardFront);
  }

  private async saveCardFrontPreference(cardFront: number): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      await store.put(CARD_FRONT_PREFERENCE_KEY, cardFront);
      await store.flush();
    } catch (err) {
      console.error('[SolitaireSettings] card front save failed: ' + JSON.stringify(err));
    }
  }

  /** Restores the draw mode while retaining draw-one for absent or invalid data. */
  private async loadDrawCountPreference(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      const storedValue = await store.get(DRAW_COUNT_PREFERENCE_KEY, DRAW_COUNT_ONE);
      const storedDrawCount: number = Number(storedValue);
      if (storedDrawCount === DRAW_COUNT_ONE || storedDrawCount === DRAW_COUNT_THREE) {
        this.selectedDrawCount = storedDrawCount;
      }
    } catch (err) {
      console.error('[SolitaireSettings] draw count load failed: ' + JSON.stringify(err));
    }
  }

  /** Applies draw mode to the current board immediately and persists it. */
  private selectDrawCount(drawCount: number): void {
    if (drawCount !== DRAW_COUNT_ONE && drawCount !== DRAW_COUNT_THREE) {
      return;
    }
    this.selectedDrawCount = drawCount;
    this.saveDrawCountPreference(drawCount);
  }

  private async saveDrawCountPreference(drawCount: number): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      await store.put(DRAW_COUNT_PREFERENCE_KEY, drawCount);
      await store.flush();
    } catch (err) {
      console.error('[SolitaireSettings] draw count save failed: ' + JSON.stringify(err));
    }
  }

  /** Restores the unlimited or three-reset waste rule, defaulting to unlimited. */
  private async loadWasteResetLimitPreference(): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      const storedValue = await store.get(WASTE_RESET_LIMIT_PREFERENCE_KEY, WASTE_RESET_LIMIT_UNLIMITED);
      const storedLimit: number = Number(storedValue);
      if (storedLimit === WASTE_RESET_LIMIT_UNLIMITED || storedLimit === WASTE_RESET_LIMIT_THREE) {
        this.selectedWasteResetLimit = storedLimit;
      }
    } catch (err) {
      console.error('[SolitaireSettings] waste reset limit load failed: ' + JSON.stringify(err));
    }
  }

  /** Applies the waste rule immediately and persists it without dismissing settings. */
  private selectWasteResetLimit(limit: number): void {
    if (limit !== WASTE_RESET_LIMIT_UNLIMITED && limit !== WASTE_RESET_LIMIT_THREE) {
      return;
    }
    this.selectedWasteResetLimit = limit;
    this.game.setWasteResetLimit(limit);
    this.refreshPage();
    this.saveWasteResetLimitPreference(limit);
  }

  private async saveWasteResetLimitPreference(limit: number): Promise<void> {
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      await store.put(WASTE_RESET_LIMIT_PREFERENCE_KEY, limit);
      await store.flush();
    } catch (err) {
      console.error('[SolitaireSettings] waste reset limit save failed: ' + JSON.stringify(err));
    }
  }

  /** Restores the active board before enabling interaction; first launch deals immediately. */
  private async initializeGame(): Promise<void> {
    let restored: boolean = false;
    this.game.setWasteResetLimit(this.selectedWasteResetLimit);
    try {
      const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
      const storedValue = await store.get(ACTIVE_GAME_PREFERENCE_KEY, '');
      if (typeof storedValue === 'string' && storedValue.length > 0) {
        const snapshot: GameSnapshot | null = GameStateCodec.decode(storedValue);
        if (snapshot !== null) {
          restored = this.game.restore(snapshot);
        }
      }
    } catch (err) {
      console.error('[SolitaireGame] load failed: ' + JSON.stringify(err));
    }

    if (!restored) {
      this.prepareCardBackForNewGame();
      this.applyPendingCardBack();
      this.game.newGame();
      this.queueGameSave();
    }
    this.clearSelection();
    this.refreshPage();
    this.moveInProgress = false;
  }

  /** Serializes Preferences writes so an older flush can never win a race. */
  private queueGameSave(): void {
    const serializedSnapshot: string = GameStateCodec.encodeGame(this.game);
    this.saveQueue = this.saveQueue.then(async () => {
      try {
        const store = await preferences.getPreferences(getContext(this), CARD_BACK_PREFERENCES_NAME);
        await store.put(ACTIVE_GAME_PREFERENCE_KEY, serializedSnapshot);
        await store.flush();
      } catch (err) {
        console.error('[SolitaireGame] save failed: ' + JSON.stringify(err));
      }
    });
  }

  /** Creates one bounded random sweep using a UI-only crypto stream. */
  private createSweepAnimation(card: PlayingCard, placement: CardPlacement, zIndex: number): SweepCardAnimation {
    const randomBytes: Uint8Array = this.animationRandom.generateRandomSync(2).data;
    const speed: number = triangularSweepSpeed(randomBytes[0], randomBytes[1]);
    const travelY: number = -(this.boardHeight + this.scaledCardHeight());
    const duration: number = Math.round(Math.abs(travelY) * 1000 / speed * NEW_GAME_TIME_SCALE);
    return new SweepCardAnimation(card.clone(), placement.x, placement.y, travelY, duration, zIndex);
  }

  /** Adds every card in one aligned stock, waste, or foundation pile. */
  private appendAlignedSweepPile(
    animations: SweepCardAnimation[],
    pile: PlayingCard[],
    placement: CardPlacement,
    startingZIndex: number
  ): number {
    let zIndex: number = startingZIndex;
    for (const card of pile) {
      animations.push(this.createSweepAnimation(card, placement, zIndex));
      zIndex++;
    }
    return zIndex;
  }

  /** Captures all 52 physical cards before the rendered board is cleared. */
  private captureSweepAnimations(): SweepCardAnimation[] {
    const animations: SweepCardAnimation[] = [];
    let zIndex: number = 0;
    zIndex = this.appendAlignedSweepPile(
      animations, this.stock, this.boardPlacement(this.stockPlacement), zIndex);
    zIndex = this.appendAlignedSweepPile(
      animations, this.waste, this.boardPlacement(this.wastePlacement), zIndex);
    for (let foundationIndex: number = 0; foundationIndex < this.foundations.length; foundationIndex++) {
      zIndex = this.appendAlignedSweepPile(
        animations,
        this.foundations[foundationIndex],
        this.boardPlacement(this.foundationPlacements.get(foundationIndex)),
        zIndex
      );
    }
    for (let pileIndex: number = 0; pileIndex < this.tableau.length; pileIndex++) {
      const pile: PlayingCard[] = this.tableau[pileIndex];
      const pilePlacement: CardPlacement = this.boardPlacement(this.tableauPlacements.get(pileIndex));
      for (let cardIndex: number = 0; cardIndex < pile.length; cardIndex++) {
        const measuredPlacement: CardPlacement | undefined = this.tableauCardPlacements.get(pile[cardIndex].id);
        const placement: CardPlacement = measuredPlacement === undefined ?
          new CardPlacement(pilePlacement.x, pilePlacement.y + this.tableauOffset(pile, cardIndex)) :
          this.boardPlacement(measuredPlacement);
        animations.push(this.createSweepAnimation(pile[cardIndex], placement, zIndex));
        zIndex++;
      }
    }
    return animations;
  }

  /** Commits a new shuffle, optionally omitting the outgoing sweep after victory. */
  private startAnimatedNewGame(skipOutgoingSweep: boolean = false): void {
    const capturedCards: SweepCardAnimation[] = skipOutgoingSweep ? [] : this.captureSweepAnimations();
    this.moveInProgress = true;
    this.dragInProgress = false;
    this.clearSelection();
    this.movingCards = [];
    this.movingTargetCards = [];
    this.wasteShiftAnimations = [];
    this.coveredWasteCards = [];
    this.stockDrawSequenceActive = false;
    this.stockDrawStepsRemaining = 0;
    this.drawStepCompletionsRemaining = 0;
    this.wasteMoveTransitionActive = false;
    this.wasteMoveCompletionsRemaining = 0;
    this.settingsOpen = false;

    this.prepareCardBackForNewGame();
    this.game.newGame();
    this.game.setWasteResetLimit(this.selectedWasteResetLimit);
    this.queueGameSave();
    this.stock = [];
    this.waste = [];
    this.foundations = [[], [], [], []];
    this.tableau = [[], [], [], [], [], [], []];
    this.canUndo = false;
    this.canAutoComplete = false;
    this.won = false;
    this.wasteResetsUsed = 0;

    if (skipOutgoingSweep) {
      this.applyPendingCardBack();
      this.beginStackEntry();
      return;
    }

    this.newGamePhase = NEW_GAME_SWEEP;
    this.sweepCardsRemaining = capturedCards.length;
    this.sweepAnimations = capturedCards;
    if (capturedCards.length === 0) {
      this.finishSweep();
    }
  }

  private finishSweepCard(): void {
    this.sweepCardsRemaining--;
    if (this.sweepCardsRemaining <= 0 && this.newGamePhase === NEW_GAME_SWEEP) {
      this.finishSweep();
    }
  }

  /** Switches Random artwork after the old deck exits and before the new deck enters. */
  private finishSweep(): void {
    this.sweepAnimations = [];
    this.applyPendingCardBack();
    this.beginStackEntry();
  }

  /** Raises the replacement deck to the approved bottom-center staging point. */
  private beginStackEntry(): void {
    const cardWidth: number = this.scaledCardHeight() * CARD_ASPECT_RATIO;
    this.newGamePhase = NEW_GAME_STACK_ENTRY;
    this.stagedDeckX = Math.max((this.boardWidth - cardWidth) / 2, 0);
    this.stagedDeckY = this.boardHeight + this.scaledCardHeight();
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: STACK_ENTRY_DURATION_MS * NEW_GAME_TIME_SCALE,
        curve: MOVE_ANIMATION_CURVE,
        onFinish: () => this.beginDealing()
      }, () => {
        this.stagedDeckY = this.boardHeight * 2 / 3;
      });
    }, 0);
  }

  /** Builds all 28 flights from the committed model in round-by-round order. */
  private beginDealing(): void {
    this.newGamePhase = NEW_GAME_DEAL;
    const animations: DealCardAnimation[] = [];
    const targets: DealTarget[] = classicDealTargets();
    for (const target of targets) {
      const pile: PlayingCard[] = this.game.tableau[target.pileIndex];
      const base: CardPlacement = this.boardPlacement(this.tableauPlacements.get(target.pileIndex));
      const destination: CardPlacement = new CardPlacement(
        base.x,
        base.y + this.tableauOffset(pile, target.cardIndex)
      );
      const animation: DealCardAnimation = new DealCardAnimation(target, pile[target.cardIndex], destination);
      animations.push(animation);
    }
    this.dealFlightsRemaining = animations.length;
    this.dealAnimations = animations;
  }

  /**
   * Lands covered cards immediately. A face-up pile top stays solely in its
   * overlay until its turn completes, avoiding a card-back underlay.
   */
  private landDealCard(animation: DealCardAnimation): void {
    if (animation.targetCard.faceUp) {
      return;
    }
    this.appendRenderedDealCard(animation.pileIndex, animation.faceDownCard);
  }

  /** Reveals a top card if needed, removes its overlay, and counts completion. */
  private finishDealCard(animation: DealCardAnimation): void {
    if (animation.targetCard.faceUp) {
      this.appendRenderedDealCard(animation.pileIndex, animation.targetCard);
    }
    this.dealAnimations = this.dealAnimations.filter((item: DealCardAnimation) => item.order !== animation.order);
    this.dealFlightsRemaining--;
    this.tryFinishDealing();
  }

  private tryFinishDealing(): void {
    if (this.newGamePhase === NEW_GAME_DEAL && this.dealFlightsRemaining <= 0) {
      this.beginStockFinish();
    }
  }

  /** Sends the undealt 24-card remainder from staging to the stock slot. */
  private beginStockFinish(): void {
    this.newGamePhase = NEW_GAME_STOCK_FINISH;
    const stockDestination: CardPlacement = this.boardPlacement(this.stockPlacement);
    this.getUIContext().animateTo({
      duration: STOCK_FINISH_DURATION_MS * NEW_GAME_TIME_SCALE,
      curve: MOVE_ANIMATION_CURVE,
      onFinish: () => this.finishNewGameAnimation()
    }, () => {
      this.stagedDeckX = stockDestination.x;
      this.stagedDeckY = stockDestination.y;
    });
  }

  /** Replaces all temporary visuals with the canonical, already-saved model. */
  private finishNewGameAnimation(): void {
    this.sweepAnimations = [];
    this.dealAnimations = [];
    // Reconciliation preserves every already-correct dealt card and only adds
    // the stock cards that were represented by the temporary layered deck.
    this.refreshPage();
    this.newGamePhase = NEW_GAME_IDLE;
    this.moveInProgress = false;
  }

  /** Appends one landed deal card without copying unrelated piles or cards. */
  private appendRenderedDealCard(pileIndex: number, card: PlayingCard): void {
    const updatedTableau: PlayingCard[][] = this.tableau.slice();
    const updatedPile: PlayingCard[] = this.tableau[pileIndex].slice();
    updatedPile.push(card.clone());
    updatedTableau[pileIndex] = updatedPile;
    this.tableau = updatedTableau;
  }

  /** Adds existing render objects to a lookup so moves can retain card identity. */
  private addRenderedCards(pool: Map<number, PlayingCard>, pile: PlayingCard[]): void {
    for (const card of pile) {
      pool.set(card.id, card);
    }
  }

  /** Captures all current UI card objects before reconciling their pile locations. */
  private renderedCardPool(): Map<number, PlayingCard> {
    const pool: Map<number, PlayingCard> = new Map<number, PlayingCard>();
    this.addRenderedCards(pool, this.stock);
    this.addRenderedCards(pool, this.waste);
    for (const pile of this.foundations) {
      this.addRenderedCards(pool, pile);
    }
    for (const pile of this.tableau) {
      this.addRenderedCards(pool, pile);
    }
    return pool;
  }

  /** Returns true when a rendered pile already describes the model pile exactly. */
  private pilesMatch(rendered: PlayingCard[], model: PlayingCard[]): boolean {
    if (rendered.length !== model.length) {
      return false;
    }
    for (let index: number = 0; index < rendered.length; index++) {
      if (rendered[index].id !== model[index].id || rendered[index].faceUp !== model[index].faceUp) {
        return false;
      }
    }
    return true;
  }

  /** Reuses unchanged card objects and clones only cards whose visible side changed. */
  private reconcilePile(
    rendered: PlayingCard[],
    model: PlayingCard[],
    pool: Map<number, PlayingCard>
  ): PlayingCard[] {
    if (this.pilesMatch(rendered, model)) {
      return rendered;
    }
    return model.map((modelCard: PlayingCard) => {
      const existing: PlayingCard | undefined = pool.get(modelCard.id);
      if (existing !== undefined && existing.faceUp === modelCard.faceUp) {
        return existing;
      }
      return modelCard.clone();
    });
  }

  /** Preserves unchanged pile arrays so ArkUI can skip their nested ForEach work. */
  private reconcilePiles(
    rendered: PlayingCard[][],
    model: PlayingCard[][],
    pool: Map<number, PlayingCard>
  ): PlayingCard[][] {
    const result: PlayingCard[][] = rendered.slice();
    let changed: boolean = false;
    for (let index: number = 0; index < model.length; index++) {
      const nextPile: PlayingCard[] = this.reconcilePile(rendered[index], model[index], pool);
      if (nextPile !== rendered[index]) {
        result[index] = nextPile;
        changed = true;
      }
    }
    return changed ? result : rendered;
  }

  /** Reconciles model state into the UI while retaining stable cards and piles. */
  private refreshPage(): void {
    const pool: Map<number, PlayingCard> = this.renderedCardPool();
    const nextStock: PlayingCard[] = this.reconcilePile(this.stock, this.game.stock, pool);
    const nextWaste: PlayingCard[] = this.reconcilePile(this.waste, this.game.waste, pool);
    const nextFoundations: PlayingCard[][] = this.reconcilePiles(this.foundations, this.game.foundations, pool);
    const nextTableau: PlayingCard[][] = this.reconcilePiles(this.tableau, this.game.tableau, pool);

    if (nextStock !== this.stock) {
      this.stock = nextStock;
    }
    if (nextWaste !== this.waste) {
      this.waste = nextWaste;
    }
    if (nextFoundations !== this.foundations) {
      this.foundations = nextFoundations;
    }
    if (nextTableau !== this.tableau) {
      this.tableau = nextTableau;
    }

    if (this.wasteResetsUsed !== this.game.wasteResetsUsed) {
      this.wasteResetsUsed = this.game.wasteResetsUsed;
    }

    const nextCanUndo: boolean = this.game.canUndo();
    const nextCanAutoComplete: boolean = this.game.canAutoComplete();
    const nextWon: boolean = this.game.isWon();
    if (this.canUndo !== nextCanUndo) {
      this.canUndo = nextCanUndo;
    }
    if (this.canAutoComplete !== nextCanAutoComplete) {
      this.canAutoComplete = nextCanAutoComplete;
    }
    if (this.won !== nextWon) {
      this.won = nextWon;
      if (nextWon) {
        this.beginVictoryCelebration();
      }
    }
  }

  private clearSelection(): void {
    this.selectedSource = SOURCE_NONE;
    this.selectedPile = -1;
    this.selectedCard = -1;
  }

  /** Converts an ArkUI length reported by onAreaChange into a numeric vp value. */
  private numericLength(value: Length | undefined): number {
    return typeof value === 'number' ? value : 0;
  }

  /** Captures a component position in global coordinates during layout. */
  private placementFromArea(area: Area): CardPlacement {
    return new CardPlacement(
      this.numericLength(area.globalPosition.x),
      this.numericLength(area.globalPosition.y)
    );
  }

  /** Converts a captured global placement into coordinates inside the board Stack. */
  private boardPlacement(placement: CardPlacement | undefined): CardPlacement {
    if (placement === undefined) {
      return new CardPlacement(this.selectedCardX, this.selectedCardY);
    }
    return new CardPlacement(placement.x - this.boardX, placement.y - this.boardY);
  }

  /** Records the selected card's premeasured placement for a later move. */
  private rememberSelectedPlacement(placement: CardPlacement | undefined): void {
    const boardPlacement: CardPlacement = this.boardPlacement(placement);
    this.selectedCardX = boardPlacement.x;
    this.selectedCardY = boardPlacement.y;
  }

  /** Returns the final top-left position for a card appended to a tableau pile. */
  private tableauDestination(tableauIndex: number): CardPlacement {
    const placement: CardPlacement = this.boardPlacement(this.tableauPlacements.get(tableauIndex));
    placement.y += this.tableauOffset(this.tableau[tableauIndex], this.tableau[tableauIndex].length);
    return placement;
  }

  /** Returns the measured global placement of a draggable card source. */
  private dragSourcePlacement(source: number, pileIndex: number, cardIndex: number): CardPlacement | undefined {
    if (source === SOURCE_WASTE) {
      return this.wasteTopPlacement();
    }
    if (source === SOURCE_FOUNDATION) {
      return this.foundationPlacements.get(pileIndex);
    }
    if (source === SOURCE_TABLEAU) {
      const pile: PlayingCard[] = this.tableau[pileIndex];
      if (cardIndex >= 0 && cardIndex < pile.length) {
        return this.tableauCardPlacements.get(pile[cardIndex].id);
      }
    }
    return undefined;
  }

  /** Selects a movable source so drag and tap transfers share the same rules. */
  private selectDragSource(source: number, pileIndex: number, cardIndex: number): boolean {
    if (source === SOURCE_WASTE) {
      if (this.waste.length === 0 || cardIndex !== this.waste.length - 1) {
        return false;
      }
    } else if (source === SOURCE_FOUNDATION) {
      const pile: PlayingCard[] = this.foundations[pileIndex];
      if (pile.length === 0 || cardIndex !== pile.length - 1) {
        return false;
      }
    } else if (source === SOURCE_TABLEAU) {
      const pile: PlayingCard[] = this.tableau[pileIndex];
      if (cardIndex < 0 || cardIndex >= pile.length || !pile[cardIndex].faceUp) {
        return false;
      }
    } else {
      return false;
    }

    this.selectedSource = source;
    this.selectedPile = pileIndex;
    this.selectedCard = cardIndex;
    this.rememberSelectedPlacement(this.dragSourcePlacement(source, pileIndex, cardIndex));
    return true;
  }

  /** Starts an overlay that follows the pointer without changing the game model. */
  private onCardDragStart(
    source: number,
    pileIndex: number,
    cardIndex: number,
    event: GestureEvent
  ): void {
    if (this.moveInProgress || !this.selectDragSource(source, pileIndex, cardIndex)) {
      return;
    }

    const cards: PlayingCard[] = this.selectedCardsForMove();
    if (cards.length === 0) {
      return;
    }

    this.dragInProgress = true;
    this.moveInProgress = true;
    this.dragOriginX = this.selectedCardX;
    this.dragOriginY = this.selectedCardY;
    this.movingCards = cards;
    this.movingTargetCards = [];
    this.movingCardsAligned = false;

    if (event.fingerList.length > 0) {
      const finger: FingerInfo = event.fingerList[0];
      this.dragPointerOffsetX = finger.globalX - this.boardX - this.dragOriginX - event.offsetX;
      this.dragPointerOffsetY = finger.globalY - this.boardY - this.dragOriginY - event.offsetY;
    } else {
      this.dragPointerOffsetX = this.scaledCardHeight() * CARD_ASPECT_RATIO / 2;
      this.dragPointerOffsetY = this.scaledCardHeight() / 2;
    }
    this.updateCardDrag(event);
  }

  /** Keeps the moving overlay aligned with the cumulative pan offset. */
  private updateCardDrag(event: GestureEvent): void {
    if (!this.dragInProgress) {
      return;
    }
    this.movingCardX = this.dragOriginX + event.offsetX;
    this.movingCardY = this.dragOriginY + event.offsetY;
  }

  /** Returns the top card or empty slot placement used as a tableau target. */
  private tableauDropPlacement(tableauIndex: number): CardPlacement | undefined {
    const pile: PlayingCard[] = this.tableau[tableauIndex];
    if (pile.length === 0) {
      return this.tableauPlacements.get(tableauIndex);
    }
    return this.tableauCardPlacements.get(pile[pile.length - 1].id);
  }

  /** Measures a pointer inside a centered 1.5-card hitbox from its card center. */
  private dropDistanceSquared(
    pointX: number,
    pointY: number,
    placement: CardPlacement | undefined
  ): number | undefined {
    if (placement === undefined) {
      return undefined;
    }
    const cardHeight: number = this.scaledCardHeight();
    const cardWidth: number = cardHeight * CARD_ASPECT_RATIO;
    const centerX: number = placement.x + cardWidth / 2;
    const centerY: number = placement.y + cardHeight / 2;
    const deltaX: number = pointX - centerX;
    const deltaY: number = pointY - centerY;
    if (Math.abs(deltaX) > cardWidth * DROP_HITBOX_SCALE / 2 ||
      Math.abs(deltaY) > cardHeight * DROP_HITBOX_SCALE / 2) {
      return undefined;
    }
    return deltaX * deltaX + deltaY * deltaY;
  }

  /** Collects every in-range destination from nearest card center to farthest. */
  private dropCandidates(pointX: number, pointY: number): DropCandidate[] {
    const candidates: DropCandidate[] = [];
    for (let index: number = 0; index < this.foundations.length; index++) {
      const distanceSquared: number | undefined =
        this.dropDistanceSquared(pointX, pointY, this.foundationPlacements.get(index));
      if (distanceSquared !== undefined) {
        candidates.push(new DropCandidate(DESTINATION_FOUNDATION, index, distanceSquared));
      }
    }
    for (let index: number = 0; index < this.tableau.length; index++) {
      const distanceSquared: number | undefined =
        this.dropDistanceSquared(pointX, pointY, this.tableauDropPlacement(index));
      if (distanceSquared !== undefined) {
        candidates.push(new DropCandidate(DESTINATION_TABLEAU, index, distanceSquared));
      }
    }
    candidates.sort((left: DropCandidate, right: DropCandidate) => left.distanceSquared - right.distanceSquared);
    return candidates;
  }

  /** Applies the selected source to one foundation through the model. */
  private moveSelectedToFoundation(foundationIndex: number): boolean {
    if (this.selectedSource === SOURCE_WASTE) {
      return this.game.moveWasteToFoundation(foundationIndex);
    }
    if (this.selectedSource === SOURCE_TABLEAU) {
      return this.game.moveTableauToFoundation(this.selectedPile, this.selectedCard, foundationIndex);
    }
    return false;
  }

  /** Applies the selected source to one tableau through the model. */
  private moveSelectedToTableau(tableauIndex: number): boolean {
    if (this.selectedSource === SOURCE_WASTE) {
      return this.game.moveWasteToTableau(tableauIndex);
    }
    if (this.selectedSource === SOURCE_FOUNDATION) {
      return this.game.moveFoundationToTableau(this.selectedPile, tableauIndex);
    }
    if (this.selectedSource === SOURCE_TABLEAU) {
      return this.game.moveTableauToTableau(this.selectedPile, this.selectedCard, tableauIndex);
    }
    return false;
  }

  /** Returns a released drag to its source with the shared quintic curve. */
  private animateRejectedDrag(): void {
    this.dragInProgress = false;
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: MOVE_ANIMATION_DURATION_MS,
        curve: MOVE_ANIMATION_CURVE,
        onFinish: () => {
          this.movingCards = [];
          this.moveInProgress = false;
        }
      }, () => {
        this.movingCardX = this.selectedCardX;
        this.movingCardY = this.selectedCardY;
      });
    }, 0);
  }

  /** Attempts the drop, then animates to its legal destination or back home. */
  private onCardDragEnd(event: GestureEvent): void {
    if (!this.dragInProgress) {
      return;
    }
    this.updateCardDrag(event);

    const releasedPosition: CardPlacement = new CardPlacement(this.movingCardX, this.movingCardY);
    const pointX: number = this.boardX + releasedPosition.x + this.dragPointerOffsetX;
    const pointY: number = this.boardY + releasedPosition.y + this.dragPointerOffsetY;
    const movingCards: PlayingCard[] = this.movingCards;
    const reveal: CardReveal | undefined = this.selectedCardReveal();
    const candidates: DropCandidate[] = this.dropCandidates(pointX, pointY);

    for (const candidate of candidates) {
      if (candidate.destination === DESTINATION_FOUNDATION &&
        this.moveSelectedToFoundation(candidate.pileIndex)) {
        this.dragInProgress = false;
        this.animateSuccessfulMove(movingCards,
          this.boardPlacement(this.foundationPlacements.get(candidate.pileIndex)), false, reveal, releasedPosition);
        return;
      }
      if (candidate.destination === DESTINATION_TABLEAU && this.moveSelectedToTableau(candidate.pileIndex)) {
        this.dragInProgress = false;
        this.animateSuccessfulMove(movingCards,
          this.tableauDestination(candidate.pileIndex), false, reveal, releasedPosition);
        return;
      }
    }

    this.animateRejectedDrag();
  }

  /** Treats an interrupted drag as an invalid drop. */
  private onCardDragCancel(): void {
    if (this.dragInProgress) {
      this.animateRejectedDrag();
    }
  }

  /** Copies the currently selected card or tableau run before the model mutates. */
  private selectedCardsForMove(): PlayingCard[] {
    if (this.selectedSource === SOURCE_WASTE && this.waste.length > 0) {
      return [this.waste[this.waste.length - 1].clone()];
    }
    if (this.selectedSource === SOURCE_FOUNDATION && this.foundations[this.selectedPile].length > 0) {
      const pile: PlayingCard[] = this.foundations[this.selectedPile];
      return [pile[pile.length - 1].clone()];
    }
    if (this.selectedSource === SOURCE_TABLEAU) {
      return this.tableau[this.selectedPile].slice(this.selectedCard)
        .map((card: PlayingCard) => card.clone());
    }
    return [];
  }

  /** Captures the hidden card that a successful selected-tableau move exposes. */
  private selectedCardReveal(): CardReveal | undefined {
    if (this.selectedSource !== SOURCE_TABLEAU || this.selectedCard <= 0) {
      return undefined;
    }
    const card: PlayingCard = this.tableau[this.selectedPile][this.selectedCard - 1];
    if (card.faceUp) {
      return undefined;
    }
    return new CardReveal(
      card.clone(),
      this.boardPlacement(this.tableauCardPlacements.get(card.id))
    );
  }

  /** Keeps the source hidden while its visual copy slides to the destination. */
  private isMovingCard(cardId: number): boolean {
    return this.movingCards.some((card: PlayingCard) => card.id === cardId);
  }

  /** Keeps a retained waste card hidden while its overlay moves between fan slots. */
  private isWasteShiftingCard(cardId: number): boolean {
    return this.wasteShiftAnimations.some((animation: WasteShiftAnimation) => animation.card.id === cardId);
  }

  /** Clones overlay cards with the side that will appear after a turn. */
  private cardsShowingSide(cards: PlayingCard[], faceUp: boolean): PlayingCard[] {
    return cards.map((card: PlayingCard) => {
      const replacement: PlayingCard = card.clone();
      replacement.faceUp = faceUp;
      return replacement;
    });
  }

  /** Builds overlays only for retained cards whose visible waste slot changed. */
  private createWasteShiftAnimations(
    oldVisibleCards: PlayingCard[],
    newVisibleCards: PlayingCard[]
  ): WasteShiftAnimation[] {
    const animations: WasteShiftAnimation[] = [];
    const wasteOrigin: CardPlacement = this.boardPlacement(this.wastePlacement);
    const fanOffset: number = this.wasteFanOffset();
    for (let oldIndex: number = 0; oldIndex < oldVisibleCards.length; oldIndex++) {
      for (let newIndex: number = 0; newIndex < newVisibleCards.length; newIndex++) {
        if (oldVisibleCards[oldIndex].id === newVisibleCards[newIndex].id && oldIndex !== newIndex) {
          animations.push(new WasteShiftAnimation(
            oldVisibleCards[oldIndex].clone(),
            wasteOrigin.x + oldIndex * fanOffset,
            wasteOrigin.y,
            (newIndex - oldIndex) * fanOffset
          ));
          break;
        }
      }
    }
    return animations;
  }

  /** Keeps cards leaving the visible window underneath until a slide covers them. */
  private createCoveredWasteCards(
    oldVisibleCards: PlayingCard[],
    newVisibleCards: PlayingCard[]
  ): WasteShiftAnimation[] {
    const coveredCards: WasteShiftAnimation[] = [];
    const wasteOrigin: CardPlacement = this.boardPlacement(this.wastePlacement);
    const fanOffset: number = this.wasteFanOffset();
    for (let oldIndex: number = 0; oldIndex < oldVisibleCards.length; oldIndex++) {
      let remainsVisible: boolean = false;
      for (let newIndex: number = 0; newIndex < newVisibleCards.length; newIndex++) {
        if (oldVisibleCards[oldIndex].id === newVisibleCards[newIndex].id) {
          remainsVisible = true;
          break;
        }
      }
      if (!remainsVisible) {
        coveredCards.push(new WasteShiftAnimation(
          oldVisibleCards[oldIndex].clone(),
          wasteOrigin.x + oldIndex * fanOffset,
          wasteOrigin.y,
          0
        ));
      }
    }
    return coveredCards;
  }

  /** Prepares the rolling waste window while its top card moves elsewhere. */
  private prepareWasteMoveTransition(): void {
    const oldVisibleCards: PlayingCard[] = this.visibleWasteCards();
    const nextWaste: PlayingCard[] = this.waste.slice(0, Math.max(0, this.waste.length - 1));
    const newVisibleCards: PlayingCard[] =
      nextWaste.slice(Math.max(0, nextWaste.length - VISIBLE_WASTE_CARD_COUNT));
    const shifts: WasteShiftAnimation[] = this.createWasteShiftAnimations(oldVisibleCards, newVisibleCards);
    if (shifts.length === 0) {
      return;
    }

    this.wasteTransitionGeneration++;
    this.wasteMoveTransitionActive = true;
    this.wasteMoveCompletionsRemaining = shifts.length + 1;
    this.wasteShiftAnimations = shifts;
    this.coveredWasteCards = [];
    // The newly revealed third card is already underneath the retained cards.
    // It becomes visible continuously as their overlays slide to the right.
    this.waste = nextWaste;
  }

  /** Begins one visual draw step while the model already holds the final tap result. */
  private runNextStockDrawStep(): void {
    if (this.stockDrawStepsRemaining <= 0 || this.stock.length === 0) {
      this.finishStockDrawSequence();
      return;
    }

    const initialCard: PlayingCard = this.stock[this.stock.length - 1].clone();
    const targetCard: PlayingCard = initialCard.clone();
    targetCard.faceUp = true;
    const oldVisibleCards: PlayingCard[] = this.visibleWasteCards();
    const nextStock: PlayingCard[] = this.stock.slice(0, this.stock.length - 1);
    const nextWaste: PlayingCard[] = this.waste.slice();
    nextWaste.push(targetCard);
    const newVisibleCards: PlayingCard[] =
      nextWaste.slice(Math.max(0, nextWaste.length - VISIBLE_WASTE_CARD_COUNT));
    const shifts: WasteShiftAnimation[] = this.createWasteShiftAnimations(oldVisibleCards, newVisibleCards);
    const destination: CardPlacement = this.boardPlacement(this.wasteTopPlacement(nextWaste.length));

    this.wasteTransitionGeneration++;
    this.drawStepCompletionsRemaining = shifts.length + 1;
    this.wasteShiftAnimations = shifts;
    this.coveredWasteCards = this.createCoveredWasteCards(oldVisibleCards, newVisibleCards);
    this.movingCards = [initialCard];
    this.movingTargetCards = [targetCard];
    this.movingCardsAligned = true;
    this.continueAfterMovingTurn = false;
    this.movingCardX = this.boardPlacement(this.stockPlacement).x;
    this.movingCardY = this.boardPlacement(this.stockPlacement).y;
    this.movingCardDestinationX = destination.x;
    this.movingCardDestinationY = destination.y;
    this.stock = nextStock;
    this.waste = nextWaste;
  }

  /** Records one finished overlay and advances only after every card has landed. */
  private finishStockDrawAnimationPart(): void {
    this.drawStepCompletionsRemaining--;
    if (this.drawStepCompletionsRemaining > 0) {
      return;
    }

    this.movingCards = [];
    this.movingTargetCards = [];
    this.wasteShiftAnimations = [];
    this.coveredWasteCards = [];
    this.movingCardsAligned = false;
    this.stockDrawStepsRemaining--;
    if (this.stockDrawStepsRemaining > 0) {
      setTimeout(() => this.runNextStockDrawStep(), 0);
      return;
    }
    this.finishStockDrawSequence();
  }

  /** Reconciles the final model snapshot after the last single-card step. */
  private finishStockDrawSequence(): void {
    this.stockDrawSequenceActive = false;
    this.stockDrawStepsRemaining = 0;
    this.drawStepCompletionsRemaining = 0;
    this.movingCards = [];
    this.movingTargetCards = [];
    this.wasteShiftAnimations = [];
    this.coveredWasteCards = [];
    this.movingCardsAligned = false;
    this.refreshPage();
    this.moveInProgress = false;
  }

  /** Waits for the moving top and both waste reflow cards before reconciling. */
  private finishWasteMoveAnimationPart(): void {
    this.wasteMoveCompletionsRemaining--;
    if (this.wasteMoveCompletionsRemaining > 0) {
      return;
    }

    this.wasteMoveTransitionActive = false;
    this.wasteMoveCompletionsRemaining = 0;
    this.wasteShiftAnimations = [];
    this.coveredWasteCards = [];
    this.refreshPage();
    this.movingCards = [];
    this.moveInProgress = false;
  }

  /** Routes a retained-card landing to the active waste transition. */
  private finishWasteShiftAnimation(): void {
    if (this.stockDrawSequenceActive) {
      this.finishStockDrawAnimationPart();
    } else if (this.wasteMoveTransitionActive) {
      this.finishWasteMoveAnimationPart();
    }
  }

  /** Runs one to three consecutive single-card visuals for one stock tap. */
  private animateStockDraw(drawCount: number): void {
    this.queueGameSave();
    this.moveInProgress = true;
    this.stockDrawSequenceActive = true;
    this.stockDrawStepsRemaining = drawCount;
    this.runNextStockDrawStep();
  }

  /** Animates waste recycling while its aligned card stack turns. */
  private animateDrawPileTransfer(
    cards: PlayingCard[],
    source: CardPlacement,
    destination: CardPlacement,
    faceUp: boolean
  ): void {
    this.queueGameSave();
    this.moveInProgress = true;
    this.movingCards = cards;
    this.movingTargetCards = this.cardsShowingSide(cards, faceUp);
    this.movingCardsAligned = true;
    this.continueAfterMovingTurn = false;
    this.movingCardX = source.x;
    this.movingCardY = source.y;
    this.movingCardDestinationX = destination.x;
    this.movingCardDestinationY = destination.y;
    // Render the destination snapshot underneath and hide its moving card by ID.
    this.refreshPage();
  }

  /** Turns a newly exposed tableau card in place after the transfer lands. */
  private animateCardReveal(reveal: CardReveal, continueAutoComplete: boolean): void {
    this.movingCards = [reveal.card];
    this.movingTargetCards = this.cardsShowingSide([reveal.card], true);
    this.movingCardsAligned = true;
    this.continueAfterMovingTurn = continueAutoComplete;
    this.movingCardX = reveal.placement.x;
    this.movingCardY = reveal.placement.y;
    this.movingCardDestinationX = reveal.placement.x;
    this.movingCardDestinationY = reveal.placement.y;
    this.refreshPage();
  }

  /** Clears a finished turning overlay and resumes any queued autocomplete. */
  private finishMovingCardTurn(): void {
    if (this.stockDrawSequenceActive) {
      this.finishStockDrawAnimationPart();
      return;
    }
    const continueAutoComplete: boolean = this.continueAfterMovingTurn;
    this.movingCards = [];
    this.movingTargetCards = [];
    this.movingCardsAligned = false;
    this.continueAfterMovingTurn = false;
    this.moveInProgress = false;
    if (continueAutoComplete) {
      this.runNextAutoCompleteMove();
    }
  }

  /** Runs the approved straight-line ease-out move before revealing final state. */
  private animateSuccessfulMove(
    cards: PlayingCard[],
    destination: CardPlacement,
    continueAutoComplete: boolean = false,
    reveal: CardReveal | undefined = undefined,
    source: CardPlacement | undefined = undefined
  ): void {
    this.queueGameSave();
    if (this.selectedSource === SOURCE_WASTE) {
      this.prepareWasteMoveTransition();
    }
    const start: CardPlacement = source === undefined ?
      new CardPlacement(this.selectedCardX, this.selectedCardY) : source;
    this.moveInProgress = true;
    this.movingCards = cards;
    this.movingTargetCards = [];
    this.movingCardX = start.x;
    this.movingCardY = start.y;
    this.movingCardsAligned = false;
    this.clearSelection();

    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: MOVE_ANIMATION_DURATION_MS,
        curve: MOVE_ANIMATION_CURVE,
        onFinish: () => {
          if (this.wasteMoveTransitionActive) {
            this.finishWasteMoveAnimationPart();
            return;
          }
          if (reveal !== undefined) {
            this.animateCardReveal(reveal, continueAutoComplete);
            return;
          }
          this.refreshPage();
          this.movingCards = [];
          this.moveInProgress = false;
          if (continueAutoComplete) {
            this.runNextAutoCompleteMove();
          }
        }
      }, () => {
        this.movingCardX = destination.x;
        this.movingCardY = destination.y;
      });
    }, 0);
  }

  /** Clears selection only when the user taps non-interactive table felt. */
  private onBackgroundTapped(): void {
    if (!this.moveInProgress) {
      this.clearSelection();
    }
  }

  private onStockTapped(): void {
    if (this.moveInProgress) {
      return;
    }
    this.clearSelection();
    if (this.stock.length > 0) {
      const drawCount: number = Math.min(this.selectedDrawCount, this.stock.length);
      if (this.game.drawFromStock(this.selectedDrawCount)) {
        this.animateStockDraw(drawCount);
      }
      return;
    }
    if (this.waste.length > 0) {
      const cards: PlayingCard[] = this.waste.map((card: PlayingCard) => card.clone());
      if (this.game.drawFromStock()) {
        this.animateDrawPileTransfer(
          cards,
          this.boardPlacement(this.wasteTopPlacement()),
          this.boardPlacement(this.stockPlacement),
          false
        );
      }
    }
  }

  /** Formats the remaining recycle count shown on the stock when limited. */
  private wasteResetIndicator(): string {
    return `${Math.max(0, WASTE_RESET_LIMIT_THREE - this.wasteResetsUsed)} left`;
  }

  private onWasteTapped(): void {
    if (this.moveInProgress) {
      return;
    }
    if (this.waste.length === 0) {
      return;
    }
    if (this.selectedSource === SOURCE_WASTE) {
      this.clearSelection();
      return;
    }
    this.selectedSource = SOURCE_WASTE;
    this.selectedPile = 0;
    this.selectedCard = this.waste.length - 1;
    this.rememberSelectedPlacement(this.wasteTopPlacement());
  }

  private onFoundationTapped(foundationIndex: number): void {
    if (this.moveInProgress) {
      return;
    }
    const movingCards: PlayingCard[] = this.selectedCardsForMove();
    const reveal: CardReveal | undefined = this.selectedCardReveal();
    let moved: boolean = false;
    if (this.selectedSource === SOURCE_WASTE) {
      moved = this.game.moveWasteToFoundation(foundationIndex);
    } else if (this.selectedSource === SOURCE_TABLEAU) {
      moved = this.game.moveTableauToFoundation(this.selectedPile, this.selectedCard, foundationIndex);
    }

    if (moved) {
      this.animateSuccessfulMove(movingCards,
        this.boardPlacement(this.foundationPlacements.get(foundationIndex)), false, reveal);
      return;
    }

    const pile: PlayingCard[] = this.foundations[foundationIndex];
    if (pile.length === 0) {
      return;
    }
    if (this.selectedSource === SOURCE_FOUNDATION && this.selectedPile === foundationIndex) {
      this.clearSelection();
      return;
    }
    this.selectedSource = SOURCE_FOUNDATION;
    this.selectedPile = foundationIndex;
    this.selectedCard = pile.length - 1;
    this.rememberSelectedPlacement(this.foundationPlacements.get(foundationIndex));
  }

  private onTableauCardTapped(tableauIndex: number, cardIndex: number): void {
    if (this.moveInProgress) {
      return;
    }
    const card: PlayingCard = this.tableau[tableauIndex][cardIndex];
    if (!card.faceUp) {
      return;
    }

    const movingCards: PlayingCard[] = this.selectedCardsForMove();
    const reveal: CardReveal | undefined = this.selectedCardReveal();
    let moved: boolean = false;
    if (this.selectedSource === SOURCE_WASTE) {
      moved = this.game.moveWasteToTableau(tableauIndex);
    } else if (this.selectedSource === SOURCE_FOUNDATION) {
      moved = this.game.moveFoundationToTableau(this.selectedPile, tableauIndex);
    } else if (this.selectedSource === SOURCE_TABLEAU && this.selectedPile !== tableauIndex) {
      moved = this.game.moveTableauToTableau(this.selectedPile, this.selectedCard, tableauIndex);
    }

    if (moved) {
      this.animateSuccessfulMove(movingCards, this.tableauDestination(tableauIndex), false, reveal);
      return;
    }

    if (this.selectedSource === SOURCE_TABLEAU && this.selectedPile === tableauIndex &&
      this.selectedCard === cardIndex) {
      this.clearSelection();
      return;
    }
    this.selectedSource = SOURCE_TABLEAU;
    this.selectedPile = tableauIndex;
    this.selectedCard = cardIndex;
    this.rememberSelectedPlacement(this.tableauCardPlacements.get(card.id));
  }

  private onEmptyTableauTapped(tableauIndex: number): void {
    if (this.moveInProgress) {
      return;
    }
    const movingCards: PlayingCard[] = this.selectedCardsForMove();
    const reveal: CardReveal | undefined = this.selectedCardReveal();
    let moved: boolean = false;
    if (this.selectedSource === SOURCE_WASTE) {
      moved = this.game.moveWasteToTableau(tableauIndex);
    } else if (this.selectedSource === SOURCE_FOUNDATION) {
      moved = this.game.moveFoundationToTableau(this.selectedPile, tableauIndex);
    } else if (this.selectedSource === SOURCE_TABLEAU) {
      moved = this.game.moveTableauToTableau(this.selectedPile, this.selectedCard, tableauIndex);
    }
    if (moved) {
      this.animateSuccessfulMove(movingCards, this.tableauDestination(tableauIndex), false, reveal);
    }
  }

  private onNewGameTapped(): void {
    if (!this.moveInProgress) {
      this.startAnimatedNewGame();
    }
  }

  /** Instantly removes victory pixels and resumes New Game at deck entry. */
  private onVictoryTapped(): void {
    if (!this.won) {
      return;
    }
    this.stopVictoryCelebration(true);
    this.startAnimatedNewGame(true);
  }

  private undoMove(): void {
    if (this.moveInProgress) {
      return;
    }
    if (this.game.undo()) {
      this.queueGameSave();
      this.clearSelection();
      this.refreshPage();
    }
  }

  /** Starts the approved automatic finish when every remaining card is exposed. */
  private onAutoCompleteTapped(): void {
    if (this.moveInProgress || !this.game.canAutoComplete()) {
      return;
    }
    this.clearSelection();
    this.runNextAutoCompleteMove();
  }

  /** Moves and animates one legal card, then continues after the shared duration. */
  private runNextAutoCompleteMove(): void {
    const move: AutoCompleteMove | null = this.game.nextAutoCompleteMove();
    if (move === null) {
      this.refreshPage();
      return;
    }

    const pile: PlayingCard[] = this.tableau[move.tableauIndex];
    const card: PlayingCard = pile[pile.length - 1];
    this.rememberSelectedPlacement(this.tableauCardPlacements.get(card.id));
    if (!this.game.performAutoCompleteMove(move)) {
      this.refreshPage();
      return;
    }
    this.animateSuccessfulMove(
      [card.clone()],
      this.boardPlacement(this.foundationPlacements.get(move.foundationIndex)),
      true
    );
  }

  /** Total height required to render a moving card or tableau run. */
  private cardPileHeight(pile: PlayingCard[]): number {
    if (pile.length === 0) {
      return this.scaledCardHeight();
    }
    return this.tableauOffset(pile, pile.length - 1) + this.scaledCardHeight();
  }

  /** Height of the deepest rendered tableau pile. */
  private tableauContentHeight(): number {
    let contentHeight: number = this.scaledCardHeight();
    this.tableau.forEach((pile: PlayingCard[]) => {
      contentHeight = Math.max(contentHeight, this.cardPileHeight(pile));
    });
    return contentHeight;
  }

  /** Scales the approved 2:3 card to the width of one existing column. */
  private scaledCardHeight(): number {
    const contentWidth: number = Math.max(this.boardWidth - BOARD_HORIZONTAL_PADDING, 0);
    const cardWidth: number = contentWidth * CARD_WIDTH_FRACTION;
    return cardWidth / CARD_ASPECT_RATIO;
  }

  /** Responsive horizontal reveal between adjacent cards in the waste window. */
  private wasteFanOffset(): number {
    return this.scaledCardHeight() * CARD_ASPECT_RATIO * WASTE_FAN_OFFSET_FRACTION;
  }

  /** At most the three newest waste cards, ordered oldest to newest. */
  private visibleWasteCards(): PlayingCard[] {
    return this.waste.slice(Math.max(0, this.waste.length - VISIBLE_WASTE_CARD_COUNT));
  }

  /** Measured placement adjusted from the waste slot to its fanned playable top. */
  private wasteTopPlacement(wasteCardCount: number = this.waste.length): CardPlacement {
    const visibleCardCount: number = Math.min(wasteCardCount, VISIBLE_WASTE_CARD_COUNT);
    return new CardPlacement(
      this.wastePlacement.x + Math.max(0, visibleCardCount - 1) * this.wasteFanOffset(),
      this.wastePlacement.y
    );
  }

  /** Preserves the existing slight moving-card enlargement as an explicit centered scale. */
  private movingCardScale(): number {
    const stationaryWidth: number = this.scaledCardHeight() * CARD_ASPECT_RATIO;
    if (stationaryWidth <= 0) {
      return 1;
    }
    return this.boardWidth * CARD_WIDTH_FRACTION / stationaryWidth;
  }

  private tableauOffset(pile: PlayingCard[], cardIndex: number): number {
    let offset: number = 0;
    const scale: number = this.scaledCardHeight() / CARD_REFERENCE_HEIGHT;
    for (let index: number = 0; index < cardIndex; index++) {
      offset += (pile[index].faceUp ? 24 : 12) * scale;
    }
    return offset;
  }

  @Builder
  private emptyCardSlot(symbol: string) {
    Stack() {
      Text(symbol)
        .fontSize(24)
        .fontColor('#80FFFFFF')
    }
    .width('100%')
    .aspectRatio(CARD_ASPECT_RATIO)
    .borderRadius(7)
    .border({ width: 1, color: '#70FFFFFF', style: BorderStyle.Dashed })
  }

  @Builder
  private topArea() {
    Row({ space: 7 }) {
        Stack() {
          this.emptyCardSlot('↻')

          if (this.stock.length > 0) {
            PlayingCardView({
              card: this.stock[this.stock.length - 1],
              cardBackIndex: this.activeCardBack,
              cardFront: this.selectedCardFront,
              selected: false
            })
            .opacity(this.isMovingCard(this.stock[this.stock.length - 1].id) ? 0 : 1)
          }

          if (this.selectedWasteResetLimit === WASTE_RESET_LIMIT_THREE) {
            Text(this.wasteResetIndicator())
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0B5B36')
              .backgroundColor('#FFFDF8')
              .borderRadius(5)
              .padding({ top: 2, right: 4, bottom: 2, left: 4 })
              .position({ x: 2, y: this.scaledCardHeight() - 18 })
              .hitTestBehavior(HitTestMode.None)
          }
        }
        .width('13.2%')
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.stockPlacement = this.placementFromArea(newValue);
        })
        .onClick(() => this.onStockTapped())

        Stack({ alignContent: Alignment.TopStart }) {
          Stack() {
            this.emptyCardSlot('')
          }
          .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
          .height(this.scaledCardHeight())

          if (this.waste.length > 0) {
            ForEach(this.visibleWasteCards(), (card: PlayingCard, visibleIndex: number) => {
              if (card.id === this.waste[this.waste.length - 1].id) {
                PlayingCardView({
                  card: card,
                  cardBackIndex: this.activeCardBack,
                  cardFront: this.selectedCardFront,
                  selected: this.selectedSource === SOURCE_WASTE
                })
                  .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
                  .position({ x: visibleIndex * this.wasteFanOffset(), y: 0 })
                  .zIndex(visibleIndex)
                  .opacity(this.isMovingCard(card.id) || this.isWasteShiftingCard(card.id) ? 0 : 1)
                  .onClick(() => this.onWasteTapped())
                  .gesture(
                    PanGesture()
                      .onActionStart((event: GestureEvent) =>
                        this.onCardDragStart(SOURCE_WASTE, 0, this.waste.length - 1, event))
                      .onActionUpdate((event: GestureEvent) => this.updateCardDrag(event))
                      .onActionEnd((event: GestureEvent) => this.onCardDragEnd(event))
                      .onActionCancel(() => this.onCardDragCancel())
                  )
              } else {
                AnimatedPlayingCardView({
                  card: card,
                  cardBackIndex: this.activeCardBack,
                  cardFront: this.selectedCardFront
                })
                  .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
                  .position({ x: visibleIndex * this.wasteFanOffset(), y: 0 })
                  .zIndex(visibleIndex)
                  .opacity(this.isMovingCard(card.id) || this.isWasteShiftingCard(card.id) ? 0 : 1)
              }
            // A retained card changes position whenever the three-card window
            // advances. Include that visible slot so ArkUI rebuilds its offset.
            }, (card: PlayingCard, visibleIndex: number) => `waste-${visibleIndex}-${card.id}`)
          }
        }
        .width(this.scaledCardHeight() * CARD_ASPECT_RATIO + 2 * this.wasteFanOffset())
        .height(this.scaledCardHeight())
        .onAreaChange((_oldValue: Area, newValue: Area) => {
          this.wastePlacement = this.placementFromArea(newValue);
        })

        Blank()
          .onClick(() => this.onBackgroundTapped())

        ForEach(FOUNDATION_INDICES, (index: number) => {
          Stack() {
            this.emptyCardSlot('A')

            if (this.foundations[index].length > 0) {
              if (this.foundations[index].length > 1 &&
                this.isMovingCard(this.foundations[index][this.foundations[index].length - 1].id)) {
                AnimatedPlayingCardView({
                  card: this.foundations[index][this.foundations[index].length - 2],
                  cardBackIndex: this.activeCardBack,
                  cardFront: this.selectedCardFront
                })
              }

              PlayingCardView({
                card: this.foundations[index][this.foundations[index].length - 1],
                cardBackIndex: this.activeCardBack,
                cardFront: this.selectedCardFront,
                selected: this.selectedSource === SOURCE_FOUNDATION && this.selectedPile === index
              })
              .opacity(this.isMovingCard(
                this.foundations[index][this.foundations[index].length - 1].id) ? 0 : 1)
            }
          }
          .width('13.2%')
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            this.foundationPlacements.set(index, this.placementFromArea(newValue));
            this.tryStartVictoryCelebration();
          })
          .onClick(() => this.onFoundationTapped(index))
          .gesture(
              PanGesture()
                .onActionStart((event: GestureEvent) =>
                  this.onCardDragStart(SOURCE_FOUNDATION, index, this.foundations[index].length - 1, event))
              .onActionUpdate((event: GestureEvent) => this.updateCardDrag(event))
              .onActionEnd((event: GestureEvent) => this.onCardDragEnd(event))
              .onActionCancel(() => this.onCardDragCancel())
          )
        }, (index: number) => `foundation-${index}`)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
  }

  @Builder
  private tableauArea() {
    Column() {
      Row({ space: 5 }) {
        ForEach(TABLEAU_INDICES, (pileIndex: number) => {
          Column() {
            Stack({ alignContent: Alignment.TopStart }) {
              Stack() {
                this.emptyCardSlot('K')
              }
              .width('100%')
              .onClick(() => this.onEmptyTableauTapped(pileIndex))

              if (this.tableau[pileIndex].length > 0) {
                ForEach(this.tableau[pileIndex], (card: PlayingCard, cardIndex: number) => {
                  Stack() {
                    PlayingCardView({
                      card: card,
                      cardBackIndex: this.activeCardBack,
                      cardFront: this.selectedCardFront,
                      selected: this.selectedSource === SOURCE_TABLEAU && this.selectedPile === pileIndex &&
                        this.selectedCard === cardIndex
                    })
                  }
                  .width('100%')
                  .position({ x: 0, y: this.tableauOffset(this.tableau[pileIndex], cardIndex) })
                  .zIndex(cardIndex)
                  .opacity(this.isMovingCard(card.id) ? 0 : 1)
                  .onAreaChange((_oldValue: Area, newValue: Area) => {
                    this.tableauCardPlacements.set(card.id, this.placementFromArea(newValue));
                  })
                  .onClick(() => this.onTableauCardTapped(pileIndex, cardIndex))
                  .gesture(
                    PanGesture()
                      .onActionStart((event: GestureEvent) =>
                        this.onCardDragStart(SOURCE_TABLEAU, pileIndex, cardIndex, event))
                      .onActionUpdate((event: GestureEvent) => this.updateCardDrag(event))
                      .onActionEnd((event: GestureEvent) => this.onCardDragEnd(event))
                      .onActionCancel(() => this.onCardDragCancel())
                  )
                }, (card: PlayingCard, _cardIndex: number) =>
                  `${card.id}-${card.faceUp ? 'up' : 'down'}`)
              }
            }
            .width('100%')
            .height(this.cardPileHeight(this.tableau[pileIndex]))

            Column() {
            }
            .width('100%')
            .layoutWeight(1)
            .onClick(() => this.onBackgroundTapped())
          }
          .width('13.2%')
          .height('100%')
          .onAreaChange((_oldValue: Area, newValue: Area) => {
            this.tableauPlacements.set(pileIndex, this.placementFromArea(newValue));
          })
        }, (pileIndex: number) => `tableau-${pileIndex}`)
      }
      .width('100%')
      .height(this.tableauContentHeight())
      .alignItems(VerticalAlign.Top)

      Column() {
      }
      .width('100%')
      .layoutWeight(1)
      .onClick(() => this.onBackgroundTapped())
    }
    .width('100%')
    .layoutWeight(1)
  }

  /** Board-relative overlays for retained waste cards changing fan slots. */
  @Builder
  private wasteShiftOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.coveredWasteCards, (animation: WasteShiftAnimation, animationIndex: number) => {
        AnimatedPlayingCardView({
          card: animation.card,
          cardBackIndex: this.activeCardBack,
          cardFront: this.selectedCardFront
        })
          .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
          .height(this.scaledCardHeight())
          .position({ x: animation.x, y: animation.y })
          .zIndex(animationIndex)
          .hitTestBehavior(HitTestMode.None)
      }, (animation: WasteShiftAnimation, animationIndex: number) =>
        `waste-covered-${this.wasteTransitionGeneration}-${animationIndex}-${animation.card.id}`)

      ForEach(this.wasteShiftAnimations, (animation: WasteShiftAnimation, animationIndex: number) => {
        Stack() {
          SlidingWasteCardView({
            item: animation,
            cardBackIndex: this.activeCardBack,
            cardFront: this.selectedCardFront,
            completion: new AnimationCompletion(() => this.finishWasteShiftAnimation())
          })
        }
        .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
        .height(this.scaledCardHeight())
        .position({ x: animation.x, y: animation.y })
        .zIndex(this.coveredWasteCards.length + animationIndex)
      }, (animation: WasteShiftAnimation, animationIndex: number) =>
        `waste-shift-${this.wasteTransitionGeneration}-${animationIndex}-${animation.card.id}`)
    }
    .width('100%')
    .height('100%')
    .zIndex(999)
    .hitTestBehavior(HitTestMode.None)
  }

  /** Visual copy of the selected card or run while a successful move animates. */
  @Builder
  private movingTurningCard() {
    MovingTurningCardStack({
      initialCards: this.movingCards,
      targetCards: this.movingTargetCards,
      cardBackIndex: this.activeCardBack,
      cardFront: this.selectedCardFront,
      travelX: this.movingCardDestinationX - this.movingCardX,
      travelY: this.movingCardDestinationY - this.movingCardY,
      completion: new AnimationCompletion(() => this.finishMovingCardTurn())
    })
  }

  /** Visual copy of the selected card or run while a successful move animates. */
  @Builder
  private movingCardOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.movingTargetCards.length > 0) {
        if (this.stockDrawSequenceActive) {
          ForEach([this.wasteTransitionGeneration], (_generation: number) => {
            this.movingTurningCard()
          }, (generation: number) => `stock-draw-${generation}`)
        } else {
          this.movingTurningCard()
        }
      } else {
        ForEach(this.movingCards, (card: PlayingCard, cardIndex: number) => {
          Stack() {
            PlayingCardView({
              card: card,
              cardBackIndex: this.activeCardBack,
              cardFront: this.selectedCardFront,
              selected: false
            })
          }
          .width('100%')
          .position({ x: 0, y: this.tableauOffset(this.movingCards, cardIndex) })
          .zIndex(cardIndex)
        }, (card: PlayingCard, _cardIndex: number) => `moving-${card.id}`)
      }
    }
    .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
    .height(this.movingCardsAligned ? this.scaledCardHeight() : this.cardPileHeight(this.movingCards))
    .position({ x: this.movingCardX, y: this.movingCardY })
    .scale({ x: this.movingCardScale(), y: this.movingCardScale() })
    .zIndex(1000)
    .hitTestBehavior(HitTestMode.None)
  }

  /** Five subtly offset backs give the temporary deck readable thickness. */
  @Builder
  private layeredDeck() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach([0, 1, 2, 3, 4], (layerIndex: number) => {
        Image(CARD_BACK_IMAGES[this.activeCardBack])
          .width('100%')
          .height(this.scaledCardHeight())
          .objectFit(ImageFit.Fill)
          .borderRadius(7)
          .position({ x: 0, y: LAYERED_DECK_CARD_COUNT - 1 - layerIndex })
          .zIndex(layerIndex)
          .shadow({ radius: 4, color: '#44000000', offsetX: 0, offsetY: 2 })
      }, (layerIndex: number) => `deck-layer-${layerIndex}`)
    }
    .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
    .height(this.scaledCardHeight() + LAYERED_DECK_CARD_COUNT - 1)
  }

  /** All current cards depart independently while preserving their exact sources. */
  @Builder
  private sweepOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      ForEach(this.sweepAnimations, (animation: SweepCardAnimation) => {
        Stack() {
          SweepingCardView({
            item: animation,
            cardBackIndex: this.activeCardBack,
            cardFront: this.selectedCardFront,
            completion: new AnimationCompletion(() => this.finishSweepCard())
          })
        }
        .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
        .height(this.scaledCardHeight())
        .position({ x: animation.x, y: animation.y })
        .zIndex(animation.zIndex)
      }, (animation: SweepCardAnimation) => `sweep-${animation.card.id}`)
    }
    .width('100%')
    .height('100%')
    .zIndex(1100)
    .hitTestBehavior(HitTestMode.None)
  }

  /** Temporary deck, cascading flights, and landing turns for a fresh deal. */
  @Builder
  private newGameDealOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      Stack() {
        this.layeredDeck()
      }
      .position({ x: this.stagedDeckX, y: this.stagedDeckY })
      .zIndex(0)

      ForEach(this.dealAnimations, (animation: DealCardAnimation) => {
        Stack() {
          DealingCardView({
            item: animation,
            cardBackIndex: this.activeCardBack,
            cardFront: this.selectedCardFront,
            travelX: animation.destinationX - this.stagedDeckX,
            travelY: animation.destinationY - this.stagedDeckY,
            completion: new DealAnimationCompletion(
              () => this.landDealCard(animation),
              () => this.finishDealCard(animation)
            )
          })
        }
        .width(this.scaledCardHeight() * CARD_ASPECT_RATIO)
        .height(this.scaledCardHeight())
        .position({ x: this.stagedDeckX, y: this.stagedDeckY })
        // The deck renders first; launched flights then layer oldest-to-newest.
        .zIndex(animation.order + 1)
      }, (animation: DealCardAnimation) => `deal-${animation.order}`)
    }
    .width('100%')
    .height('100%')
    .zIndex(1100)
    .hitTestBehavior(HitTestMode.None)
  }

  /** Persistent no-redraw canvas plus the full-screen victory tap target. */
  @Builder
  private victoryOverlay() {
    Stack({ alignContent: Alignment.TopStart }) {
      Canvas(this.victoryContext)
        .width('100%')
        .height('100%')
        .hitTestBehavior(HitTestMode.None)
        .onReady(() => {
          this.victoryCanvasReady = true;
          this.tryStartVictoryCelebration();
        })
    }
    .width('100%')
    .height('100%')
    .zIndex(1500)
    .onClick(() => this.onVictoryTapped())
  }

  /** One tappable preview in the approved card-back settings grid. */
  @Builder
  private cardBackChoice(cardBackIndex: number) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (cardBackIndex === RANDOM_CARD_BACK_INDEX) {
          Stack({ alignContent: Alignment.Center }) {
            Text('?')
              .fontSize(32)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0B5B36')
              .hitTestBehavior(HitTestMode.None)
          }
          .width(54)
          .height(81)
          .backgroundColor('#FFFDF8')
          .border({ width: 2, color: '#0B5B36', style: BorderStyle.Dashed })
          .borderRadius(7)
        } else {
          Image(CARD_BACK_IMAGES[cardBackIndex])
            .width(54)
            .height(81)
            .objectFit(ImageFit.Fill)
            .borderRadius(7)
        }

        if (this.selectedCardBack === cardBackIndex) {
          Stack()
            .width(58)
            .height(85)
            .borderRadius(9)
            .border({ width: 3, color: '#FFD54F' })
            .hitTestBehavior(HitTestMode.None)

          Text('✓')
            .width(20)
            .height(20)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B5B36')
            .textAlign(TextAlign.Center)
            .backgroundColor('#FFD54F')
            .borderRadius(10)
            .position({ x: 43, y: -6 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width(64)
      .height(87)

      Text(CARD_BACK_LABELS[cardBackIndex])
        .fontSize(14)
        .fontWeight(this.selectedCardBack === cardBackIndex ? FontWeight.Medium : FontWeight.Normal)
        .fontColor('#173B2B')
    }
    .width(88)
    .onClick(() => this.selectCardBack(cardBackIndex))
  }

  /** One immediate, persisted Solid/Suits table-background choice. */
  @Builder
  private tableBackgroundChoice(tableBackground: number, label: string) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        if (tableBackground === TABLE_BACKGROUND_SUITS) {
          Image($r('app.media.suits_green_flat'))
            .width(112)
            .height(52)
            .objectFit(ImageFit.Cover)
            .borderRadius(8)
        } else {
          Stack()
            .width(112)
            .height(52)
            .backgroundColor('#0B6E3F')
            .borderRadius(8)
        }

        if (this.selectedTableBackground === tableBackground) {
          Stack()
            .width(116)
            .height(56)
            .borderRadius(10)
            .border({ width: 3, color: '#FFD54F' })
            .hitTestBehavior(HitTestMode.None)

          Text('✓')
            .width(20)
            .height(20)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B5B36')
            .textAlign(TextAlign.Center)
            .backgroundColor('#FFD54F')
            .borderRadius(10)
            .position({ x: 101, y: -7 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width(122)
      .height(60)

      Text(label)
        .fontSize(14)
        .fontWeight(this.selectedTableBackground === tableBackground ? FontWeight.Medium : FontWeight.Normal)
        .fontColor('#173B2B')
    }
    .width(132)
    .onClick(() => this.selectTableBackground(tableBackground))
  }

  /** One immediate, persisted Detailed/Simple card-front choice. */
  @Builder
  private cardFrontChoice(cardFront: number, label: string) {
    Column({ space: 6 }) {
      Stack({ alignContent: Alignment.Center }) {
        Image(cardFront === CARD_FRONT_SIMPLE ?
          $r('app.media.playing_card_simple_9_of_spades') :
          $r('app.media.playing_card_9_of_spades'))
          .width(54)
          .height(81)
          .objectFit(ImageFit.Fill)
          .borderRadius(7)

        if (this.selectedCardFront === cardFront) {
          Stack()
            .width(58)
            .height(85)
            .borderRadius(9)
            .border({ width: 3, color: '#FFD54F' })
            .hitTestBehavior(HitTestMode.None)

          Text('✓')
            .width(20)
            .height(20)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B5B36')
            .textAlign(TextAlign.Center)
            .backgroundColor('#FFD54F')
            .borderRadius(10)
            .position({ x: 43, y: -6 })
            .hitTestBehavior(HitTestMode.None)
        }
      }
      .width(64)
      .height(87)

      Text(label)
        .fontSize(14)
        .fontWeight(this.selectedCardFront === cardFront ? FontWeight.Medium : FontWeight.Normal)
        .fontColor('#173B2B')
    }
    .width(112)
    .onClick(() => this.selectCardFront(cardFront))
  }

  /** One compact draw-mode choice; the waste still shows three cards in either mode. */
  @Builder
  private drawCountChoice(drawCount: number, label: string) {
    Button(label)
      .width(120)
      .height(40)
      .fontSize(15)
      .fontWeight(this.selectedDrawCount === drawCount ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selectedDrawCount === drawCount ? '#0B5B36' : '#173B2B')
      .backgroundColor(this.selectedDrawCount === drawCount ? '#FFF3BF' : '#EEF3EF')
      .border({
        width: this.selectedDrawCount === drawCount ? 2 : 1,
        color: this.selectedDrawCount === drawCount ? '#FFD54F' : '#A8B8AE'
      })
      .onClick(() => this.selectDrawCount(drawCount))
  }

  /** One compact waste-recycle choice; the remaining count appears on the stock. */
  @Builder
  private wasteResetChoice(limit: number, label: string) {
    Button(label)
      .width(120)
      .height(40)
      .fontSize(15)
      .fontWeight(this.selectedWasteResetLimit === limit ? FontWeight.Medium : FontWeight.Normal)
      .fontColor(this.selectedWasteResetLimit === limit ? '#0B5B36' : '#173B2B')
      .backgroundColor(this.selectedWasteResetLimit === limit ? '#FFF3BF' : '#EEF3EF')
      .border({
        width: this.selectedWasteResetLimit === limit ? 2 : 1,
        color: this.selectedWasteResetLimit === limit ? '#FFD54F' : '#A8B8AE'
      })
      .onClick(() => this.selectWasteResetLimit(limit))
  }

  /** Centered settings surface; the full-screen sibling handles outside taps. */
  @Builder
  private settingsModal() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => {
          this.settingsOpen = false;
        })

      Scroll() {
        Column({ space: 14 }) {
          Text('Settings')
            .width('100%')
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#0B5B36')
            .textAlign(TextAlign.Start)

          Text('Draw')
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#173B2B')
            .textAlign(TextAlign.Start)

          Row({ space: 12 }) {
            this.drawCountChoice(DRAW_COUNT_ONE, '1 card')
            this.drawCountChoice(DRAW_COUNT_THREE, '3 cards')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Text('Waste resets')
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#173B2B')
            .textAlign(TextAlign.Start)

          Row({ space: 12 }) {
            this.wasteResetChoice(WASTE_RESET_LIMIT_THREE, '3 resets')
            this.wasteResetChoice(WASTE_RESET_LIMIT_UNLIMITED, 'Unlimited')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Text('Card back')
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#173B2B')
            .textAlign(TextAlign.Start)

          Row({ space: 8 }) {
            this.cardBackChoice(0)
            this.cardBackChoice(1)
            this.cardBackChoice(2)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Row({ space: 8 }) {
            this.cardBackChoice(3)
            this.cardBackChoice(4)
            this.cardBackChoice(RANDOM_CARD_BACK_INDEX)
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Text('Table background')
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#173B2B')
            .textAlign(TextAlign.Start)

          Row({ space: 10 }) {
            this.tableBackgroundChoice(TABLE_BACKGROUND_SOLID, 'Solid')
            this.tableBackgroundChoice(TABLE_BACKGROUND_SUITS, 'Suits')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          Text('Card front')
            .width('100%')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#173B2B')
            .textAlign(TextAlign.Start)

          Row({ space: 18 }) {
            this.cardFrontChoice(CARD_FRONT_DETAILED, 'Detailed')
            this.cardFrontChoice(CARD_FRONT_SIMPLE, 'Simple')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
        }
        .width('100%')
        .padding({ top: 20, right: 18, bottom: 20, left: 18 })
      }
      .width(320)
      .height('90%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
      .backgroundColor('#FFFDF8')
      .borderRadius(16)
      .shadow({ radius: 16, color: '#55000000', offsetX: 0, offsetY: 6 })
    }
    .width('100%')
    .height('100%')
    .zIndex(2000)
  }

  @Builder
  private bottomControls() {
    Column({ space: 10 }) {
      if (this.canAutoComplete) {
        Button('autocomplete')
          .width('100%')
          .height(48)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0B5B36')
          .backgroundColor('#FFFDF8')
          .onClick(() => this.onAutoCompleteTapped())
      }

      Row({ space: 10 }) {
        Button('New Game')
          .layoutWeight(1)
          .height(48)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#0B5B36')
          .backgroundColor('#FFFDF8')
          .onClick(() => this.onNewGameTapped())

        Button('Undo')
          .layoutWeight(1)
          .height(48)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canUndo ? '#0B5B36' : '#668070')
          .backgroundColor(this.canUndo ? '#FFFDF8' : '#BFD0C5')
          .enabled(this.canUndo)
          .onClick(() => this.undoMove())

        Button() {
          Image($r('app.media.settings_gear'))
            .width(32)
            .height(32)
            .objectFit(ImageFit.Contain)
        }
        .width(48)
        .height(48)
        .padding(0)
        .borderRadius(24)
        .backgroundColor('#FFFDF8')
        .onClick(() => {
          if (!this.moveInProgress) {
            this.settingsOpen = true;
          }
        })
      }
      .width('100%')
    }
    .width('100%')
    .visibility(this.won ? Visibility.Hidden : Visibility.Visible)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      if (this.selectedTableBackground === TABLE_BACKGROUND_SUITS) {
        Image($r('app.media.suits_green_flat'))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .hitTestBehavior(HitTestMode.None)
      }

      Column({ space: 12 }) {
        this.topArea()
        this.tableauArea()
        this.bottomControls()
      }
      .width('100%')
      .height('100%')
      .padding({ top: 18, right: 10, bottom: 14, left: 10 })

      if (this.won) {
        this.victoryOverlay()
      }

      if (this.wasteShiftAnimations.length > 0 || this.coveredWasteCards.length > 0) {
        this.wasteShiftOverlay()
      }

      if (this.movingCards.length > 0) {
        this.movingCardOverlay()
      }

      if (this.newGamePhase === NEW_GAME_SWEEP) {
        this.sweepOverlay()
      }

      if (this.newGamePhase === NEW_GAME_STACK_ENTRY || this.newGamePhase === NEW_GAME_DEAL ||
        this.newGamePhase === NEW_GAME_STOCK_FINISH) {
        this.newGameDealOverlay()
      }

      if (this.settingsOpen) {
        this.settingsModal()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0B6E3F')
    .onAreaChange((_oldValue: Area, newValue: Area) => {
      const boardPlacement: CardPlacement = this.placementFromArea(newValue);
      this.boardX = boardPlacement.x;
      this.boardY = boardPlacement.y;
      this.boardWidth = this.numericLength(newValue.width);
      this.boardHeight = this.numericLength(newValue.height);
      this.tryStartVictoryCelebration();
    })
  }
}

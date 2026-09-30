# Product specification

This document describes the current user-visible behavior of Solitaire. Dated
approvals and superseded alternatives are preserved in
[`history/2026-09-design-history.md`](history/2026-09-design-history.md).

## Game rules

- The game is portrait-oriented Klondike solitaire with a persisted draw-one or
  draw-three stock rule. Draw one remains the default.
- Tableau piles build downward in alternating colors.
- Empty tableau columns accept kings.
- Any ace may claim an empty foundation. That foundation then builds upward in
  the ace's suit.
- Drawing from an empty stock recycles the waste into a face-down stock.
- The **Waste resets** setting allows either 3 waste resets or unlimited resets.
  Unlimited is the default. In 3-reset mode, the stock shows the number of
  resets remaining and stops recycling after the third reset.
- Moving a tableau card exposes and automatically turns the next card.
- Completing all four foundations starts the classic victory cascade described
  below. Undo is disabled after completion, and tapping anywhere starts a new
  game.
- There is no scoring, timer, hint system, sound, or automatic move-to-foundation
  shortcut outside the explicit autocomplete flow.

## Interaction

- Tapping a non-empty stock draws one or up to three cards according to the
  current setting. Changing the setting applies immediately to the current game.
- A card or tableau run can be moved with two taps: select the source, then tap
  a destination.
- Waste tops, foundation tops, and face-up tableau cards or runs can also be
  dragged. The stock remains tap-only.
- Drag release targets use centered hitboxes that are 1.5 times the card width
  and height. Overlapping targets are considered nearest-first until the model
  accepts a legal move.
- Legal drags settle at the destination. Invalid or cancelled drags return to
  the source while keeping the source selected, allowing a destination tap to
  complete the move.
- Tapping the selected card again or tapping exposed table space clears the
  selection.
- The selected card has a 3 vp bright-gold outline and subtle glow without
  changing its measured size.
- Gameplay and settings input are locked while a move or New Game animation is
  running.

## Layout

The page has three stable vertical regions:

1. Stock, waste, foundations, and the fixed settings button.
2. A flexible seven-column tableau.
3. An optional full-width `autocomplete` button above the equal-width New Game
   and Undo buttons.

Cards retain an exact `2:3` aspect ratio. Column width is percentage-based so
all seven tableau piles remain visible on the reference 360-by-720 display.
Face-down and face-up overlap distances scale with card size.

New Game and Undo remain at the bottom. Undo is visibly disabled when the
session has no successful action to reverse.

## Movement and turns

- Successful transfers use a straight-line 80 ms slide with quintic smoothstep
  progress `6t^5 - 15t^4 + 10t^3`.
- Card turns use an 80 ms cosine-based horizontal squash: 40 ms to zero width,
  an artwork swap while hidden, then 40 ms back to full width.
- Stock draws turn and travel concurrently.
- When a draw advances a full three-card waste window, the two retained cards
  slide one fan slot left during the same 80 ms interval. The outgoing oldest
  visible card remains underneath until the next card covers it, then leaves
  the render tree without a visible disappearance.
- Draw-three is presented as up to three consecutive single-card draw
  animations. Input remains locked through the sequence, and the complete
  stock tap remains one Undo action.
- When the playable waste top moves to a tableau or foundation, retained waste
  cards slide one slot right during the same 80 ms transfer. The newly revealed
  third card is already underneath and is uncovered by that motion, so the
  three-card window never snaps after the move.
- Waste recycling moves the waste as one aligned stack while turning and
  travelling concurrently.
- A newly exposed tableau card turns after the preceding move lands.
- The waste always fans its three newest available cards slightly to the right,
  regardless of draw mode. Only the newest card is selectable. Removing it
  animates the visible window backward across the complete waste, so after
  drawing `A, B, C` and then `D, E, F`, moving `F` reveals `C, D, E`.

## New Game

Pressing New Game immediately creates and persists a fresh platform-random
shuffle, then presents a roughly 2.9-second sequence:

1. The current 52 cards leave through the top at independent speeds sampled
   from a bounded triangular distribution between 1000 and 2800 vp/s.
2. A five-layer card-back stack rises from below to the lower third.
3. The 28 tableau cards launch in classic deal order every 48 ms using
   overlapping 120 ms slides, giving each card time to clear the deck before
   the next launch.
4. Each tableau top turns face-up after landing.
5. The remaining 24-card stack moves to the stock slot.

This sequence runs only after the New Game button. Cold launch and restored
sessions display their board without the deal animation.

The current timing scale is 2x, so the complete sequence runs in roughly
5.8 seconds. Normal card moves retain their 80 ms duration.

When New Game starts from the victory cascade, all board cards, moving cards,
and stamped trail copies disappear immediately. That path skips the outgoing
card sweep, raises the replacement deck from below, and then runs the same
tableau deal, landing turns, and stock-finish phases. The normal New Game button
continues to run the complete sequence including its outgoing sweep.

## Victory cascade

The completed board remains visible while its bottom controls are hidden without
changing layout geometry. One randomly chosen non-empty foundation releases its
top card. Cards stay upright, launch upward with randomized horizontal motion,
fall under gravity, and bounce from the bottom with diminishing energy. The next
card launches when the preceding card reaches its first bottom bounce, so several
later flights may overlap.

The animation stamps each moving card and its normal shadow every 60 ms without
clearing earlier pixels, recreating the separated trails of classic framebuffer
animation. The approved physics use a 250-375 vp/s upward launch, 90-240 vp/s
horizontal motion, 1800 vp/s squared gravity, and 72% retained vertical speed on
each bounce. A direction that would leave the screen before the first bounce is
reflected toward the interior. Cards do not rotate or bounce from the side edges.

The first five launched cards play at the original 1x speed. Cards 6 through 47
accelerate progressively, and the final five cards play at 4x speed. Stamp
frequency increases with each card's playback speed, reaching one stamp every
15 ms at 4x. Every stamp still advances the original 60 ms physics step, keeping
the distance between trail copies and the trajectory shape unchanged.

After all 52 cards leave horizontally, the accumulated trails remain frozen.
The celebration is silent. A tap at any time removes the complete victory image
in one frame and begins the victory-specific New Game path above.

## Autocomplete

Autocomplete is offered only when the stock and waste are empty and every
tableau card is face-up. It moves one legal tableau top at a time to a
foundation, using the standard movement duration. Lower ranks have priority;
equal ranks resolve from left to right.

## Persistence

- The active board is saved after every successful action and restored at the
  next launch.
- Missing, malformed, or incompatible saved data produces and saves a fresh
  game without animation.
- Undo history, selection, active animations, and modal state are session-local.
  A restored board therefore starts with Undo disabled.

## Appearance settings

The gear button opens a centered modal over a dimmed board. Choices apply
immediately, remain open for comparison, and persist across launches.

- **Draw:** 1 card or 3 cards. Draw one is the fallback for a missing or invalid
  preference. The selected mode applies immediately; it does not change the
  always-three-card waste display.

- **Waste resets:** 3 resets or Unlimited. Unlimited is the fallback for a
  missing or invalid preference. The selected limit applies immediately to the
  current game, while the current reset count is saved with the active board
  and restored through relaunches and Undo.

- **Card back:** Default plus Oniro Orbit, Emerald Art Deco, Prism Mosaic,
  Solar Eclipse, and Random. Concrete choices apply immediately. Selecting
  Random keeps the current game's back, then uniformly chooses one of the five
  concrete backs for every subsequent new game. The assigned back survives an
  app relaunch for the duration of that game. During the New Game animation,
  outgoing cards retain the old back; the new back activates after the final
  old card leaves the screen and before the replacement deck rises into view.
- **Table background:** Solid or Suits. Solid is the fallback. Suits uses a flat,
  low-contrast composition of four oversized, edge-cropped suit silhouettes.
- **Card front:** Detailed or Simple. Detailed is the fallback; Simple uses an
  oversized upper-left rank, a compact suit beneath it, and one large centered
  suit.

Tapping outside the modal closes it. Preview selection outlines remain centered
around their images. The approved temporary Random preview is a cream card with
a dashed green border and centered green question mark. The settings surface is
vertically scrollable so every section remains reachable on smaller displays.

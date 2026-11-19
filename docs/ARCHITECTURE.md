# Code architecture

This document describes implementation responsibilities and data flow. See
[`PRODUCT.md`](PRODUCT.md) for user-visible behavior and
[`ASSETS.md`](ASSETS.md) for the visual resource contract.

## Game model

`entry/src/main/ets/model/SolitaireGame.ets` owns the mutable game state and
Klondike rules without depending on ArkUI. It creates and shuffles the deck,
deals the tableau and stock, validates moves, recycles waste, reveals tableau
cards, manages up to 100 undo snapshots, detects completion, and selects legal
autocomplete steps.

`drawFromStock(drawCount)` normalizes its input to one of the supported draw
sizes, transfers up to that many cards, and records the entire tap as one undo
snapshot. Recycling reverses the whole waste back into the stock and increments
the persisted `wasteResetsUsed` count. `setWasteResetLimit(3)` blocks recycling
after three resets; zero represents unlimited recycling.

Foundation positions are not tied to suit constants. The first ace placed in
an empty position establishes its suit. Autocomplete considers one tableau top
at a time, prioritizing the lowest legal rank and resolving equal ranks from
left to right.

Deck shuffling uses `cryptoFramework.createRandom()` from
`@kit.CryptoArchitectureKit`. Fisher-Yates indices are produced from random
bytes with rejection sampling to avoid modulo bias and repeated runtime
pseudorandom sequences.

`PlayingCard` is the canonical card object. `GameSnapshot` is a deep-clonable
serialization shape containing stock, waste, foundations, tableau, and the
current waste reset count. The model owns private undo history; snapshots do
not persist it. `undo()` and
`canUndo()` both reject a completed board, making a win irreversible even if a
caller bypasses the page controls.

## ArkUI page

`entry/src/main/ets/pages/Index.ets` owns rendering, measurements, gestures,
animation state, settings state, and the Preferences lifecycle. It translates
taps, pans, and autocomplete requests into model operations rather than
duplicating game rules.

Rendered arrays are isolated from the mutable model, but refreshes reconcile
them by card ID instead of deep-cloning the complete deck. Unchanged pile arrays
and card objects retain their identity; only changed pile membership or a
changed face creates new render data. For animated moves, the page keeps the
pre-move arrays visible, hides the moving source, and renders a temporary
board-relative overlay. When the animation completes, reconciliation applies
the model state.

Foundation and tableau `ForEach` containers use fixed pile-index keys. Tableau
cards use physical card ID plus visible side as their key. Adding or removing a
card therefore updates only that card, while turning a card recreates only its
own visual. Selection is passed to `PlayingCardView` as a boolean property so
cards do not all subscribe directly to the page's three selection fields.

Stock, waste, foundation, and tableau slots permanently render their empty
outline beneath card content. This makes a source slot visible as soon as its
stationary card is hidden for an overlay.

The waste renderer slices the last three cards from the complete waste on every
refresh and fans them oldest-to-newest. This rule is independent of draw size,
so removing the playable top naturally reveals the previous three-card window.
The measured waste origin plus the responsive fan offset supplies the true drag
and tap-move source position of the newest card. Waste render keys contain both
card identity and the current visible slot: advancing the rolling window then
rebuilds retained cards whose fan offsets changed instead of leaving them in
their former slots.

`PlayingCardView` resolves a model card through the selected detailed or simple
resource table. The model therefore remains independent of resources and
ArkUI. The card container owns geometry, hit testing, shadows, stacking, and
selection overlays. The card artwork loads from PNGs generated from the
packaged SVGs. The same artwork supplies Settings previews and victory images.

## Movement and interaction state

ArkUI `onAreaChange` callbacks capture board-relative source and destination
positions. Successful tap moves, drag settling, drag returns, and autocomplete
share the page's `MOVE_ANIMATION_DURATION_MS` and quintic smoothstep curve.

Finite card motion uses `entry/src/main/ets/animation/CardAnimator.ets` and
`UIContext.createAnimator`. Its local `onFrame` applies the existing easing
functions to active overlay transforms, and its local `onFinish` advances the
sequence. This bypasses the implicit-animation completion delays observed on
OpenHarmony 6.1.0.38. Runners commit exact endpoints, reject replaced
callbacks, and cancel deferred launches and animations on component teardown.
They detach callbacks before cancellation because Animator can emit a final
frame when cancelled. See [`APP_ANIMATION_WORKAROUND.md`](APP_ANIMATION_WORKAROUND.md)
for the implementation, measurements, and UI-thread tradeoff.

Drag release creates distance-sorted drop candidates from measured foundation
slots and tableau targets. The page asks the model to try each candidate in
order, so hit testing remains forgiving without reproducing rule logic.

Card turns are isolated components that animate horizontal scale to zero,
switch the resource while hidden, and restore scale. Stock travel and recycle
turns run concurrently; tableau reveals start after the preceding transfer.
Each turning card uses one visible `AnimatedPlayingCardView`. At the midpoint
its `card` prop changes from the initial side to the target side. The second
40 ms cosine half starts after the new side decodes and ArkUI reaches a frame
boundary. Stock draw and recycle overlays also wait for travel to finish.
See [`FLIP_VISIBILITY.md`](FLIP_VISIBILITY.md) for investigation and validation.

Stationary cards and gameplay overlays load their local card PNGs synchronously
when their views change. The sweep loads asynchronously while the board remains
visible. `CardArtworkHandoff` tracks the card and side of incoming views.
Transfers, waste shifts, flips, and the final New Game stock handoff keep
their current visual until the relevant destination images have decoded and
ArkUI reaches a frame boundary. A 250 ms fallback keeps play moving if an
image completion signal is missing. A tableau reveal leaves the newly exposed
card face-down while the preceding transfer settles.

A stock tap commits its complete one-card or three-card model mutation and
durable snapshot before animation begins. The page then advances its isolated
render arrays one card at a time. Each step moves and turns one stock card while
`WasteShiftAnimation` overlays slide retained waste cards from their old fan
slots to their new slots. A covered-card overlay keeps the outgoing oldest
visible waste card in its prior slot until a retained card slides over it.
Completion counting waits for the incoming card and all retained-card slides
before starting the next step. Every step increments a transition generation
used in ArkUI keys, forcing fresh moving/turning and sliding components instead
of reusing completed component state. Draw-three therefore shows three
consecutive 80 ms single-card draws without stalling while remaining one model
history entry and one persistence write.

Moving a waste top first advances the page's isolated waste array to its final
membership. The newly revealed third card renders at the back of the fan while
retained-card overlays hide their final copies and slide right from their old
slots. The selected top follows the normal destination overlay concurrently.
The page reconciles the complete model only after all three 80 ms motions have
finished, avoiding a post-move waste snap for both tableau and foundation moves.

Selection, moving overlays, covered-card, waste-shift and draw-sequence state,
transition generations, reveal state, autocomplete progress, modal state, and
interaction locks are page-local and intentionally non-durable.

## New Game animation

`entry/src/main/ets/model/NewGameAnimation.ets` contains deterministic helpers
for classic round-by-round deal targets and the bounded triangular sweep-speed
mapping. `Index.ets` owns the visual state machine:

1. `sweep`
2. `stack entry`
3. `deal`
4. `stock finish`

The page commits and queues persistence for the shuffled model before starting
the visual sequence. Closing the app during the sequence therefore restores a
complete new board rather than an intermediate animation state.

`startAnimatedNewGame(skipOutgoingSweep)` shares game creation, persistence,
transient-state reset, and card-back preparation between two visible paths.
Ordinary New Game captures the rendered board and enters `sweep`. A victory
tap first clears the canvas and all presentation state, then passes `true` so
the old board is not restored or captured. The pending Random back is applied
immediately and the state machine enters `stack entry`, preserving the deck
rise, deal, turns, and stock finish without an awkward sweep over stamped cards.

The sweep captures all currently rendered cards and derives independent
durations from a separate cryptographic random stream. The old board stays
visible while the hidden sweep copies decode their artwork. Once the copies
are ready and ArkUI reaches a frame boundary, the board is cleared and the
sweep starts. A bounded wait lets the sequence progress if a decode callback
is missing. Deal overlays target positions computed from the new model.
Landing callbacks build temporary
visible tableau arrays. The deck renders below every flight; delayed flights
remain invisible until launch, and launched cards then layer oldest-to-newest.
A face-up pile top is added to the temporary tableau only after its overlay
finishes turning, preventing a duplicate card back from showing beneath the
turn. Each dealing overlay runs travel and the first squeeze half on one
continuous Animator timeline, mapping progress with `dealFlightFraction` and
`dealSqueezeFraction`. At landing it stays full-width in its existing image
view, then shrinks without an Animator restart. The midpoint side swap and
expansion follow afterward. Each landing copies only its destination pile.
The landed overlay stays until its motion is complete and the tableau image
has decoded and had a frame to paint. This bridges the interval in which a
newly mounted stationary card could show its background before its artwork.
The stock finish follows motion completion. When the remaining stack reaches
the stock slot, reconciliation preserves the 28 tableau card visuals and
adds the model's stock cards. The staged deck stays until the stock image
is ready or the handoff reaches its fallback.

`NEW_GAME_TIME_SCALE` is the single sequence-wide timing multiplier and is set
to `2`. Normal movement, draw, recycle, and reveal timings are unchanged.

## Persistence

`SolitaireGame.snapshot()` returns a deep-cloned `GameSnapshot`.
`SolitaireGame.restore()` accepts only a complete canonical 52-card state with
valid piles, card identities, suits, ranks, and face flags. Restore rebuilds
real `PlayingCard` instances and clears undo history.

`entry/src/main/ets/model/GameStateCodec.ets` wraps the snapshot in a versioned
JSON envelope. Version `1` is stored under `active_game_v1` in the
`solitaire_settings` ArkData Preferences file.

Persistence serializes the live model synchronously. Because `JSON.stringify`
finishes before the model can mutate again, this preserves the same durable
snapshot semantics without first allocating a redundant 52-card clone.

Startup loads appearance and active-game values before enabling interaction.
Missing, incompatible, or malformed game data creates and saves a fresh board.
Successful model mutations enqueue serialized snapshots and flush them in
order, preventing an older asynchronous write from replacing newer state.

## Appearance settings

The same `solitaire_settings` Preferences file stores numeric appearance values:

| Key | Values | Fallback |
| --- | --- | --- |
| `card_back` | `0` Default, `1` Oniro, `2` Emerald, `3` Prism, `4` Eclipse, `5` Random | `0` |
| `active_card_back` | Concrete back `0` through `4` assigned to the current game | `0` |
| `table_background` | `0` Solid, `1` Suits | `0` |
| `card_front` | `0` Detailed, `1` Simple | `0` |
| `draw_count` | `1` Draw one, `3` Draw three | `1` |

The page separates the persisted card-back mode from the current game's
concrete back. A new game in Random mode uses rejection sampling over a
cryptographic byte to choose each of the five backs with equal probability,
then stores it as a non-reactive pending value and persists the assignment so
relaunching does not alter the ongoing game. The sweep-completion transition
applies that pending value after clearing the outgoing-card overlays and before
starting stack entry. Choosing Random mid-game retains the current concrete back.
Every stationary and animated card receives that reactive concrete value. The
table root always retains the solid green fallback and conditionally renders
the packaged Suits image with hit testing disabled. Reusing numeric value `1`
migrates the former Satin selection without changing the preference schema.

The settings UI is a page-local overlay. A full-screen dimming sibling
intercepts board input and closes the menu; the centered, vertically scrollable
modal is a later stack sibling so preview taps apply selections without
dismissing it. Draw-count and waste-reset-limit changes update page state
immediately and persist in the same Preferences file. The stock displays a
small remaining-reset label only while the three-reset limit is active.

The victory presentation likewise sits inside a full-screen input layer. Its
transparent Canvas decodes the active card-front PNG resources to PixelMaps and
repeatedly draws them without clearing, so old positions remain as permanent
trail stamps. Page-local foundation arrays are popped as cards launch while the
completed model remains unchanged. The model-level undo guard therefore keeps
completion irreversible independently of the visual sequence.

Victory physics live in `entry/src/main/ets/model/VictoryAnimation.ets` as
deterministic, ArkUI-independent helpers. A 60 ms timer advances the active
flights under fixed gravity and bottom restitution. The first-bounce result from
one flight triggers the next random non-empty foundation launch; later bounces
cannot trigger another launch. The timer stops only after no foundation cards or
active flights remain, leaving the uncleared canvas frozen. Generation checks,
timer cancellation, PixelMap release, and page-disappearance cleanup prevent
stale asynchronous decoding or ticks from surviving a cancelled celebration.
The launch projection keeps the complete card inside the horizontal viewport at
its predicted first impact. As a final invariant, an idle timer with foundations
remaining immediately launches another card, so fixed-step edge crossings can
never strand the sequence.

Each flight captures a playback rate derived from its one-based launch number.
Launches 1-5 use 1x, launches 6-47 linearly interpolate toward 4x, and launches
48-52 use 4x. A shared 15 ms scheduler advances an independent accumulator on
each flight. A 1x flight stamps every fourth scheduler tick, while a 4x flight
stamps every tick. Each due stamp advances exactly one original 60 ms physics
step, preserving trail spacing, bounce detection, and trajectory geometry.

## Verification

Model behavior is covered by `entry/src/test/SolitaireGame.test.ets`. Build,
install, launch, layout-dump, and screenshot commands are kept in the root
[`README.md`](../README.md) so the workflow has one authoritative location.
The [host suite](../scripts/tests/card-animator.test.cjs) covers animation
timing, cancellation, completion, and artwork readiness. The test command is
documented in [`APP_ANIMATION_WORKAROUND.md`](APP_ANIMATION_WORKAROUND.md).

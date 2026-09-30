# September 2026 design history

## 2026-09-07: limited waste resets

The user approved a new Settings entry named **Waste resets** with **3 resets**
and **Unlimited** choices. Unlimited remains the default for existing and new
games. A reset is counted only when an empty stock recycles a non-empty waste;
drawing cards from a non-empty stock does not consume a reset.

The current reset count is part of the game snapshot so it survives active-game
restoration and follows normal Undo behavior. Changing the limit applies to the
current board immediately. In the limited mode, the stock shows a compact
remaining-reset indicator and rejects recycling after the third reset.

---

## 2026-09-03: rendering optimization

The user approved optimizing rendering as much as possible after card flicker
was traced to pile-length-based `ForEach` keys. The implementation preserves
the approved gameplay, animation timing, per-move undo history, and per-move
persistence semantics while changing render identity and allocation behavior:

- foundation and tableau columns now have stable index-based identities;
- tableau cards retain physical ID-based identities, with face side included so
  a reveal rebuilds only the turning card;
- render refreshes reconcile and reuse unchanged pile and card objects instead
  of cloning all 52 cards;
- each New Game landing copies only its destination pile, and the final deal no
  longer forces a full-tableau remount;
- card views receive a computed selection boolean instead of linking every card
  to all three global selection fields; and
- synchronous persistence encoding reads the live model directly, avoiding a
  redundant full-deck clone while retaining the same serialized result.

Batching autocomplete into one undo step or one durable save was deliberately
not included because either would change user-visible recovery or undo
behavior and was not separately approved.

This archive preserves the original dated design, asset, generator, and
verification narratives as they existed when the current documentation was
consolidated on 2026-09-03. These records explain decisions and superseded
alternatives; they are not the authoritative description of current behavior.
See [`../README.md`](../README.md) for the current documentation index.

---

## Archived source: `DESIGN.md`

### Solitaire design

#### Approved product decisions

The user approved this design on 2026-09-01:

- The supplied `card-images` SVG faces and back are used in game without
  modifying their source files or changing the existing card size and shape.
- Cards use the user-approved exact `2:3` aspect ratio at every display size.
  Their width continues to follow the existing seven-column layout, while
  height and tableau overlap scale proportionally. This responsive rule keeps
  the reference 360-by-720 emulator at a nearly unchanged 45-by-67.5 footprint.
- The game is classic Klondike solitaire using draw-one stock rules.
- The app is portrait-oriented and uses a green felt play surface with
  traditional white red/black playing cards.
- Interaction uses two taps: select a face-up card or run, then tap its
  destination. Tapping the stock draws a card.
- On 2026-09-02, the user approved drag movement in addition to the existing
  two-tap interaction. Waste cards, foundation tops, and face-up tableau cards
  or runs follow the pointer. Releasing over a tableau pile or foundation asks
  the existing game model to validate the move; stock remains tap-only.
- The user approved reusing the existing quintic smoothstep movement for both
  drag outcomes. A legal release continues from the pointer position to the
  destination, while an invalid or cancelled release returns to the original
  position. Rejected drags preserve the existing invalid-destination behavior:
  the source stays selected so the player may finish with a destination tap.
- On 2026-09-02, the user approved destination release hitboxes that are 50%
  larger than a card in both width and height and remain centered on the target
  card or empty slot. When expanded hitboxes overlap, the nearest legal target
  in range wins; nearer illegal targets are skipped before the drag is rejected.
- A newly exposed tableau card turns face-up automatically.
- New Game and Undo are always located at the bottom of the screen.
- Completing all four foundations displays a simple `You won!` celebration.
- The initial version has no scoring, timer, hints, sound, or advanced
  animation beyond the approved direct card-move feedback.
- Every New Game action uses a fresh platform-random shuffle rather than a
  repeatable runtime pseudorandom sequence.
- On 2026-09-03, the user approved a button-only animated New Game sequence.
  All 52 current cards leave straight through the top at independent speeds
  sampled from a bounded 1400-2400 vp/s triangular distribution. Once the old
  board is clear, a five-layer card-back stack rises from below to the lower
  third of the screen. The 28 tableau cards launch from it every 32 ms in
  classic round order using overlapping 160 ms straight slides. Each tableau
  top turns face-up for 80 ms after landing, then the undealt 24-card stack
  slides to the stock slot. The complete sequence targets about 2.1 seconds.
- The New Game sequence never runs at cold launch or when restoring a saved
  session. Gameplay and settings actions remain locked until it finishes.
- The active board is persisted after every successful action and restored on
  the next launch. Undo history, selection, transient overlays, and modal state
  are intentionally session-local; a restored board therefore starts with
  Undo disabled.
- The app and bundle spelling is `Solitaire`, correcting the starter project's
  `Solitare` spelling.
- On 2026-09-02, the user approved changing every card family and the in-game
  layout from 45:68 to exact 2:3. The 45 px reference width is unchanged; the
  artwork and reference height are compressed vertically by about 0.735%.
- The permanent `Solitaire` heading is removed so the card area begins near the
  top of the screen.
- Empty foundation spaces use identical neutral `A` placeholders. Any ace may
  start any empty foundation, and that ace determines the suit built upward in
  that space.
- The `You won!` celebration appears in the middle of the screen rather than in
  the former heading row.
- Autocomplete is offered only after both stock and waste are empty and all
  tableau cards are face-up. Its lowercase `autocomplete` button spans the row
  immediately above New Game and Undo, and each automatic foundation move uses
  `MOVE_ANIMATION_DURATION_MS` before the next begins. Legal moves prioritize
  the lowest card rank, with equal ranks resolved from left to right.
- On 2026-09-02, the user approved 80 ms card turns to match the existing move
  duration. Each turn uses cosine-based horizontal scaling: 40 ms to squash to
  zero width, an artwork swap while hidden, and 40 ms to restore full width.
- A stock draw turns and travels to the waste concurrently. Recycling returns
  all drawn cards as one aligned stack, turning and travelling concurrently.
  A newly exposed tableau card turns in place after the preceding move lands.
- The waste renders its second-highest card beneath the top card. It remains
  visible when a new draw turns above it and when the current top card moves to
  a tableau or foundation destination.
- On 2026-09-02, the user approved adding a 48 vp rounded gear button to the
  right of slightly narrowed, equally sized New Game and Undo buttons.
- The gear opens a centered light Settings modal over a dimmed board. Its first
  section is Card back, presented as a compact 3+2 grid of card previews named
  Default, Oniro, Emerald, Prism, and Eclipse.
- The selected preview has a gold outline and checkmark. A choice applies
  immediately but deliberately leaves the modal open, and tapping outside the
  modal dismisses it.
- Card-back selection is retained across app closures. Missing or invalid
  stored values safely resolve to Default.
- On 2026-09-02, the user approved replacing the font-rendered gear with the
  reviewed 32 vp green SVG inside the existing 48 vp settings button.
- On 2026-09-02, the user approved the reviewed subtle green felt texture and
  then approved offering it alongside the original solid green table. The
  Settings modal includes a Table background section below Card back with
  labeled Solid and Felt previews. A choice applies immediately, leaves the
  modal open, and persists across launches; missing or invalid values resolve
  to Solid so existing users retain the previous appearance.
- On 2026-09-03, the user approved replacing Felt with a smoother Satin table
  surface. The approved texture retains the deep casino-green palette and a
  restrained diagonal sheen while removing visible fibers and weave. The
  Settings label is now Satin; the stored numeric choice remains unchanged so
  users who previously selected Felt migrate automatically to Satin.
- On 2026-09-03, the user approved Four Suits Mark (concept F) as the app icon.
  The launcher uses a deep-green field with a disciplined two-by-two club,
  diamond, heart, and spade mark. Warm white is used for three suits and muted
  red for the diamond. The launch window uses the same mark and field.
- On 2026-09-03, the user approved the Sparse card-front direction as the Simple
  deck. Every Simple face has one oversized upper-left rank and one large
  centered suit; number and court cards deliberately omit conventional pip
  counts and portrait artwork.
- The user subsequently approved repeating the suit in the upper index on every
  Simple card, including aces. After reviewing an interim same-height inline
  treatment, the user selected direction A, Traditional index: a prominent rank
  with a compact suit centered directly beneath it. Both remain in the exposed
  tableau band, while the large centered suit remains for an uncovered card. The
  user then requested that this index move slightly inward; its rank anchor is
  two SVG units lower and two units farther right to clear the rounded corner.
- Settings includes a Card front section below Table background. Detailed is
  the default and preserves the existing traditional deck; Simple selects the
  approved Sparse deck. A choice applies immediately, leaves Settings open,
  and persists across launches.

#### Layout

The page is divided vertically into three stable regions over the selected
solid-color or felt table surface:

1. The stock/waste/foundation row.
2. A flexible tableau area containing seven columns.
3. The bottom controls containing an optional full-width autocomplete button
   above the New Game, Undo, and fixed-size gear action row. New Game and Undo
   remain equally sized and share the remaining row width.

The win celebration is centered over these regions and does not reserve layout
space during normal play.

Card and column widths are percentage-based so all seven tableau columns remain
visible on the Oniro emulator's portrait display. Face-down and face-up cards
use different vertical offsets to keep deeper piles readable.

#### Interaction feedback

The selected card receives the user-approved 3 px bright-gold outline and a
subtle gold glow. The glow keeps the selected card noticeable when later cards
partially cover it in a tableau pile, without moving or resizing the card. The
outline is a sibling overlay rather than a container border, so its width never
reduces the SVG image. Unselected cards use only the border authored into each
SVG, avoiding a doubled edge.
Invalid destinations leave the card selected so the player can choose another
destination. Tapping the selected card again cancels the selection. Undo is
visibly disabled when no action is available.

Tapping exposed green table felt deselects the current card without changing
the game. Successful card transfers use the user-approved straight-line slide
with quintic smoothstep progress `6t^5 - 15t^4 + 10t^3`. This gives zero first
and second derivatives at both endpoints. The duration is defined once by
`MOVE_ANIMATION_DURATION_MS` in `Index.ets` so it can be tuned without changing
the animation implementation. The final board state is revealed when the slide
finishes.
During a drag, the selected card or tableau run is rendered in the same moving
overlay and directly follows the cumulative pan offset. On release, the pointer
position is compared with measured foundation slots and rendered tableau pile
top cards or empty slots. Each target uses a centered 1.5-card hitbox. In-range
targets are checked from nearest center to farthest until the model accepts a
move. The overlay then uses the shared duration and quintic curve to settle from
its release position to a legal destination or back to its measured source.
Stock transfers use the same 80 ms travel duration while a cosine-scaled turn
runs concurrently. Newly exposed tableau cards then use a separate in-place
80 ms turn so the reveal remains visible after the transferred card lands.


---

## Archived source: `CARD_ASSETS.md`

### Solitaire card assets

#### Approved direction

On 2026-09-01, the user approved creating a scalable vector card set based on
the visual style already used by the solitaire app. The user requested that the
Oniro logo from `favicon.ico` appear on every ace and that the card aspect ratio
match the cards rendered by the emulator. The user subsequently approved a
traditional playing-card treatment with conventional pip layouts and simple
mirrored vector drawings for the Jack, Queen, and King.

The source artwork remains in `card-images/` and is never rewritten by the app
integration. Copies of the 52 faces and the back are packaged as module media
resources so ArkUI can resolve them at runtime.

#### Geometry

- Every individual card uses an SVG `viewBox` of `0 0 45 67.5`, an exact `2:3`
  aspect ratio approved on 2026-09-02.
- The existing 45-unit width and artwork coordinate system are preserved. A
  scripted 0.735% vertical normalization changes the prior 68-unit height to
  67.5 units without altering paths by hand.
- The outer silhouette corresponds to the current 7 px radius at the reference
  size. The SVG uses a 1 px centered border around a rectangle inset by 0.5 px,
  with a 6.5 px path radius, producing a 7 px outer radius.
- `preserveAspectRatio="xMidYMid meet"` prevents distortion when a card is
  displayed in a differently sized container.

#### Visual system

- Face background: warm white `#FFFDF8`.
- Red suits and ranks: `#C62828`.
- Black suits and ranks: `#171717`.
- Back background: blue `#235A96`, with the existing pale diamond motif.
- Ranks, suit marks, pips, court illustrations, and the Oniro mark are SVG
  paths/shapes. Individual card files contain no embedded raster images and do
  not depend on installed fonts.
- All cards use mirrored rank-and-suit indices in the upper-left and
  lower-right corners. Following phone-legibility review, ranks use an em size
  of `12.0` (`10.4` for the two-character `10`) and corner suits use a `0.36`
  scale. The central pip sizes and layouts remain unchanged.
- Cards 2 through 10 use traditional pip counts and arrangements. Pips in the
  lower half are inverted in the conventional playing-card manner. The central
  pips were enlarged by 20% after visual review; ranks 9 and 10 use adjusted
  spacing to keep the larger marks distinct. Club symbols preserve the original
  three-circle geometry and stem. On 2026-09-02, the user requested removal of
  the remaining white renderer seam. All four overlapping primitives now live
  in one compound filled path, so the renderer rasterizes the club as one
  silhouette instead of compositing separately antialiased circles. The change
  applies to the canonical source, packaged gameplay assets, showcase, and
  generator.
- Spade symbols use a narrow, filled neck where the head meets the stem. The
  earlier contour revisited a single point at that junction, which the
  OpenHarmony SVG renderer displayed as a white notch on 180-degree-rotated
  pips. The simple replacement contour preserves the approved silhouette while
  rendering upright and inverted spades consistently.
- Jacks, Queens, and Kings use distinct two-way geometric portraits. Jacks have
  caps and swords, Queens have crowns and flowers, and Kings have crowns,
  beards, and swords. The court palette uses red, blue, gold, magenta, and warm
  skin tones while keeping the card's suit color visible. Court panels blend
  into the warm-white card face without a separate background or outline.
- Aces retain suit marks in both corners and place the full-color Oniro mark in
  the center, so both the suit and requested branding remain recognizable. The
  mark uses the original vector paths from the Eclipse Foundation Oniro logo
  published on Wikimedia Commons. Only the circular icon paths are embedded;
  the white page background and right-side `oniro` wordmark are omitted.

#### Oniro logo attribution

The ace icon is derived from
`https://upload.wikimedia.org/wikipedia/commons/9/91/Oniro_logo.svg`, authored by
the Eclipse Foundation and published under Creative Commons Attribution 3.0.
The card assets crop the circular icon from the full logo and omit the wordmark
to fit the playing-card layout.
- Shadows and selection highlights are intentionally excluded because those
  are interaction states owned by the app UI.

#### Files

- 52 standalone face SVGs named `<rank>_of_<suit>.svg`.
- One standalone back SVG named `card_back.svg`.
- Four shortlisted alternative back SVGs: `oniro_orbit_00_original.svg`,
  `emerald_deco_04_ivory.svg`, `prism_mosaic_02_ocean.svg`, and
  `solar_eclipse_04_red_giant.svg`.
- `all-cards.svg`, a scalable overview of the complete set.
- `all-cards.png`, a rasterized overview for convenient inspection only.

The standalone SVGs are the integration assets. The PNG is not intended to be
used for gameplay.

#### Simple card fronts

On 2026-09-03, the user approved the reviewed Sparse direction as an optional
Simple deck. Its 52 source SVGs live in `card-images-simple/`; packaged copies
use `playing_card_simple_<rank>_of_<suit>.svg` names. Every card keeps the exact
`45 x 67.5` viewport, warm-white face, existing border, approved red/black ink,
one prominent upper-left rank, a compact suit centered directly beneath that
rank, and one large centered suit. The ace, number cards, and courts all follow
the same sparse rule. This Traditional index occupies the band that remains
exposed beneath the next face-up tableau card, so both rank and suit stay
identifiable in a stack.

Ranks are converted to filled SVG paths by the generator. OpenHarmony ignored
SVG `<text>` elements during the first device integration pass, while the path
outlines rendered correctly. The final Simple deck therefore has no font or
SVG-text dependency. Clubs reuse the approved seam-free compound silhouette.

#### Generator behavior

`scripts/card-assets/generate-card-images.ps1` generates the complete main
asset folder: 52 faces, the traditional `card_back.svg`, and the four
shortlisted alternative backs. It delegates the alternatives to
`generate-card-back-variations.ps1 -SelectedOnly`, so their vector definitions
have one canonical implementation and the other 20 experiments are not added
to the main asset output.

#### In-game integration

`Index.ets` resolves face artwork through a resource table indexed by the game
model's suit and rank. A second parallel table holds the Simple deck, and the
persisted Card front setting chooses the active table. Face-down cards use one
of five packaged backs: the
traditional `card_back.svg` is Default, and the four shortlisted files are
named Oniro, Emerald, Prism, and Eclipse in the settings menu. The alternative
source SVGs are copied unchanged into app media resources with stable
`playing_card_back_*` names.
The SVG image is the only normal-state content of `PlayingCardView` and uses
`ImageFit.Fill` to occupy its already established card container.

The emulator expands nested SVG viewports instead of honoring their local size.
Each packaged ace therefore expresses the source file's authored 27-by-27
Oniro viewport as the geometrically equivalent group transform
`translate(9 20.5) scale(27/153)`. This compatibility normalization changes no
paths, colors, intended size, or placement and does not modify `card-images`.

Card columns remain `13.2%` wide. Their height is derived from that width using
the approved exact `2:3` ratio, and tableau overlap scales by the same factor.
On the reference 360-by-720 emulator this produces a nearly unchanged
45-by-67.5 card footprint; at unusual resolutions the complete card scales
without distortion. The SVG owns the normal card border. The selected state is
a separate 3 px gold overlay plus a container shadow, so selection does not
change the image's measured area. Stacking and hit areas remain owned by the
existing card container.

#### Vector rationale

SVG is a good fit for these cards. It keeps curves, symbols, and rank edges
crisp across device densities while allowing the app to retain a single source
asset per card. It also avoids maintaining separate bitmap density variants.

Vector assets do not by themselves guarantee a good layout: the app must keep
the `2:3` aspect ratio, avoid stretching, and allocate enough physical pixels
for the rank and suit to remain readable. Platform SVG support should also be
verified when the assets are integrated, but the card files deliberately use a
small, portable subset of SVG: rectangles, paths, circles, groups, and basic
transforms.

#### Integration verification

Verification used the project-mandated `oniro-app` workflow. After the 2:3
change, the debug HAP built successfully and lint reported no findings. All 87
standalone SVGs across the three source families have a `45 x 67.5` viewport.
The 49 non-ace gameplay SVGs match their `card-images` sources byte-for-byte;
the four packaged aces differ only by the equivalent nested-viewport
compatibility transform described above.

The updated app was launched and visually inspected on the current 360 x 720
emulator, as requested. Its layout dump reports the expected 45 px card width
and a device-rounded height of approximately 67 px. The seven-column board,
controls, card backs, faces, ace logo, borders, and tableau overlaps remain
visually intact.

The spade compatibility change was verified non-visually by parsing every
source and packaged SVG, confirming that the legacy self-touching path is
absent, confirming that the 12 non-ace source and packaged spade assets match
byte-for-byte, and building and linting the application successfully. The
packaged spade ace retains only its documented viewport compatibility
normalization. Per the user's request, final device-side visual verification is
left to the user.

On 2026-09-02, the user approved the larger corner indices and then promoted
the reviewed set to `card-images` and the packaged ArkUI media resources. The
promotion reapplied the renderer-safe spade normalization before synchronization.
Per the user's request, the updated indices were not visually checked on an
emulator; final device-side visual review remains with the user.

On 2026-09-03, all 52 Simple source SVGs and all 52 packaged copies were parsed
successfully, verified to contain no `<text>` elements, built into the signed
debug HAP, and inspected on the 360 x 720 emulator. Detailed was confirmed as
the clean-install default; switching to Simple updated every face immediately,
and Simple remained selected after stopping and relaunching the app.

The initial top-band suit addition was regenerated across all 52 Simple faces.
Each source file was verified to contain two suit transforms and no SVG text.
On the emulator, a Jack of clubs placed over a Queen of diamonds left the
Queen's rank and upper diamond visible while covering its center diamond,
confirming the intended stacked-card behavior.

The same-height inline revision was later rejected during visual review. The
user selected direction A, Traditional index, as its replacement. The generator
centers the compact upper suit beneath the measured rank outline, so placement
remains balanced for both `10` and single-character ranks. The index was then
moved two SVG units down and right so the rank does not overlap the rounded
corner. Emulator interaction is intentionally left to the user under the
project's interface-testing policy.


---

## Archived source: `CARD_ASSET_GENERATORS.md`

### Card asset generator preservation

#### Decision

The asset-generation scripts are stored permanently in `scripts/card-assets` instead of as hidden temporary files in the repository root. This keeps the tools discoverable, separates them from application code, and prevents routine cleanup of temporary dotfiles from removing them again.

#### Recovered files

The exact final script bodies were recovered from the local Codex session history on 2026-09-02:

- `generate-card-images.ps1`
- `polish-card-images.ps1`
- `generate-card-back-concepts.ps1`
- `generate-card-back-variations.ps1`

The `oniro-filtered.svg` input used by the historical card polish pass is preserved under `scripts/card-assets/sources`.

The scripts are independent design tooling. Restoring them did not change the application or any generated card asset.

On 2026-09-02, the user approved exact `2:3` card geometry across the app and
all three asset families. Each generator now emits a `45 x 67.5` viewport and
applies a uniform 0.735% vertical transform to the existing 45 x 68 authored
coordinate system. This keeps the visual change minimal and makes regeneration
the sole source of the geometry change.

#### Reproducibility boundary

The two card-back generators reproduce their SVG families and showcases
directly. The card-face generation was iterative: after its generator and
polish pass, several user-reviewed corrections were applied directly to the
SVG files. Those corrections include the official Wikimedia Oniro icon, the
transparent and unoutlined portrait panel, and closed club centers.
Consequently, the committed SVGs in `card-images` remain the canonical final
artwork. The polish script performs the approved 2:3 normalization in place,
rebuilds the showcase, and can synchronize packaged ArkUI resources without
discarding those refinements.

Usage and overwrite warnings are documented in `scripts/card-assets/README.md`.

#### Larger phone-readable corner indices

On 2026-09-02, the user approved increasing the corner rank size from `9.5`
to `12.0`, with the two-character `10` increasing from `8.2` to `10.4`. The
corner suit scale increases from `0.27` to `0.36`. Central pip sizes and layouts
remain unchanged because dense nine- and ten-pip cards already use the largest
spacing that fits comfortably.

The card generator also supports `-SourceCardDirectory` for design reviews.
This mode preserves the canonical ace, number-pip, court, card-back, and aspect
ratio artwork while regenerating only the corner indices into a different
output directory. It rejects identical source and output paths, preventing an
in-place review run from modifying the approved `card-images` set.

The generator emits the previously approved renderer-safe spade contour
directly. This ensures newly generated enlarged corner suits cannot reintroduce
the legacy self-touching head-to-stem junction; the polish pass remains an
idempotent compatibility safeguard for older generated inputs.

#### Simple deck generator

`generate-simple-card-images.ps1` reproduces the user-approved Sparse deck in
`card-images-simple` and synchronizes its 52 packaged
`playing_card_simple_*` resources. It converts each oversized rank to a filled
vector outline because OpenHarmony does not render SVG text reliably. The
resulting files use only rectangles, paths, and transforms and preserve the
approved exact `2:3` geometry. For the approved Traditional index, the generator
measures the final vector rank outline and centers a `0.32`-scale suit directly
beneath it. The rank uses a `20` em outline (`17` for `10`) and begins three SVG
units from the top and four units from the left (`4.5` for the narrower ace),
keeping the index clear of the rounded corner while retaining both elements in
the exposed tableau band and retaining the large center suit.

On 2026-09-03, the user approved replacing that Sparse composition with the
Modern Banner design while retaining the existing Simple setting and resource
names. Every card now uses a 17-unit full-width red or near-black top banner
clipped to the rounded face, a warm-white vector rank on the left, and a compact
warm-white suit on the right. The white body contains one centered 24-unit suit
outline rendered with a 1.6-unit stroke at 30% opacity. The `45 x 67.5`
geometry, `#FFFDF8` face, `#C9C7C2` border, `#C62828` red ink, `#171717` black
ink, and one-system treatment for number cards, aces, and court cards remain
approved constraints.

Later on 2026-09-03, the user approved retaining that banner exactly while
replacing the lower outlined suit with a side-by-side translucent rank and suit.
The filled rank is centered at `x=12` and uses a `27 em` vector outline, reduced
to `18 em` for the two-character `10`. The filled suit is 24 units tall and
centered at `x=33.5`. Both marks are centered at `y=42.5` and use the card's
red or near-black suit ink at exactly 50% opacity. The measured widest rank,
`Q`, ends before the widest suit begins, preserving a visible gap and the
approved card margins.

Device review on 2026-09-03 showed that the 24-unit lower suit left too little
right-side clearance and appeared to touch the card edge. The user approved
reducing it to 20 units and moving its center from `x=33.5` to `x=33`. The
large lower rank and the complete top banner remain unchanged.

#### Seam-free club silhouettes

On 2026-09-02, the user requested removal of the remaining white seams in club
symbols. The generator now emits each club as one compound path rather than
four overlapping SVG primitives. The polish script performs the same
idempotent conversion on canonical inputs, preserving every transform, scale,
fill color, card layout, and the approved exterior club geometry.


---

## Archived source: `CARD_BACK_CONCEPTS.md`

### Card-back concepts

#### Scope

On 2026-09-01, the user requested ten creative suggestions for new solitaire
card backs. The user explicitly granted creative freedom and required the work
to remain separate from the approved gameplay cards in `card-images/`.

All concept assets are stored in `card-back-concepts/`. No file in
`card-images/` was modified while producing this set.

#### Shared geometry

- Every standalone concept uses an SVG `viewBox` of `0 0 45 67.5`.
- The assets preserve the current card's exact 2:3 aspect ratio.
- The outer silhouette matches the existing rounded card geometry.
- Every design is native SVG and contains no embedded raster image.

#### Concepts

1. **Oniro Orbit** — multicolor orbital bands on deep purple.
2. **Midnight Constellation** — a spade constellation in a starry blue sky.
3. **Emerald Art Deco** — geometric gold fans and diamonds on emerald.
4. **Aurora Weave** — crossing cyan, magenta, violet, and gold ribbons.
5. **Porcelain Lattice** — cobalt lattice and floral geometry on warm white.
6. **Solar Eclipse** — a glowing crescent and radial marks on charcoal.
7. **Neon Circuit** — mirrored cyan and magenta circuit traces.
8. **Prism Mosaic** — faceted violet, blue, and magenta tessellation.
9. **Crimson Heraldry** — crown, shield, and spade in burgundy and gold.
10. **Ocean Waves** — minimal repeating waves with a central diamond.

#### Showcase

- `all-card-backs.svg` is the scalable overview.
- `all-card-backs.png` is the 1200 x 800 inspection render.

The concepts are proposals only and are not referenced by the app.


---

## Archived source: `CARD_BACK_VARIATIONS.md`

### Selected Card-Back Variations

#### Scope

The `card-back-variations` folder contains the four card-back families selected by the user for further exploration:

- Oniro Orbit
- Emerald Art Deco
- Prism Mosaic
- Solar Eclipse

The exploration originally contained six standalone choices per family, for 24 SVG files in total. The user subsequently moved four shortlisted designs into `card-images`: Oniro Orbit Original, Emerald Art Deco Ivory, Prism Mosaic Ocean, and Solar Eclipse Red Giant. The remaining 20 standalone experiments stay in `card-back-variations`. `all-variations.svg` and `all-variations.png` retain all 24 designs for comparison.

The `card-back-concepts` folder remains an unchanged source. No app resource or application source file was changed when the shortlisted card backs were moved.

The variation generator supports a `-SelectedOnly` mode used by the main card
asset generator. That mode writes only the four shortlisted backs and omits the
exploration showcase and the other variations.

#### Approved design direction

The user explicitly approved broad creative freedom for the five variations in each family. The variations explore changes in composition, color, density, geometry, and ornament while retaining the identifying idea of their family.

The user required the moon in every Solar Eclipse option, including the copied original design, to sit at the lower-right of the sun. Therefore, `solar_eclipse_00_original.svg` preserves the original concept but moves its moon from the upper-right to the lower-right. Solar Eclipse variations `01` through `05` use the same lower-right relationship.

After reviewing the first comparison sheet, the user requested substantially more background-color variety. Oniro Orbit keeps the purple original as its baseline, while variants `01` through `05` now use teal, cobalt, ember red, forest green, and amber backgrounds. The other families retain their characteristic emerald, multicolor prism, and astronomical palettes.

#### Technical format

- Standalone card backs are SVG vector graphics with an exact 2:3
  `0 0 45 67.5` view box.
- Rounded corners are clipped within the artwork and reinforced by a rounded border.
- The SVGs contain vector geometry only; no raster images are embedded.
- The PNG showcase is a convenience preview and is not a card asset.
- SVG IDs are uniquely scoped when cards are embedded in the showcase. This prevents gradients and clipping paths from one card from affecting another card with a similarly named definition.

#### Validation

All 25 SVG files—the 24 card backs across `card-images` and `card-back-variations`, plus the showcase—were rendered successfully with `rsvg-convert` before the shortlist was moved. The exact 2:3 view box and lack of raster embeds were checked across every standalone card. The comparison PNG was visually inspected at its native 1200 × 1120 resolution.


---

## Archived source: `APP_ICON.md`

### App icon

#### Approved design

On 2026-09-03, the user approved concept F, Four Suits Mark, as the production
Solitaire app icon. It presents exactly four suit symbols in a disciplined
two-by-two grid on deep green `#0B5B36`: club, diamond, heart, and spade. Club,
heart, and spade are warm white `#FFFDF8`; the diamond is muted red `#C62828`.
There is no text, card tile, gloss, shadow, bevel, gold, or decorative effect.

The concept was produced with the built-in image-generation tool using this
prompt:

```text
Use case: logo-brand
Asset type: square mobile app icon concept for a classic solitaire app
Primary request: "Four Suits Mark" — club, diamond, heart, and spade arranged as a disciplined two-by-two symbol grid directly on a deep-green field, without card tiles; simple enough to feel like a serious utility icon
Style/medium: strict flat vector-like graphic design, restrained geometric identity system, quiet and timeless
Composition/framing: full square canvas, equal optical weight and spacing, broad safe margin; do not draw an outer rounded-square container because the operating system supplies the mask
Color palette: deep green #0B5B36 background, warm off-white #FFFDF8 symbols, with only the diamond in muted red #C62828
Constraints: exactly four suit symbols and no other objects; no text, no cards, no tiles, no gradients, no gloss, no shadows, no bevels, no 3D, no gold, no crown, no sparkles, no light rays, no mockup, no device frame, no watermark
```

#### Packaging

`AppScope/resources/base/media/layered_image.json` and the equivalent entry
resource combine a solid 1024 px green `background.png` with the approved
transparent 1024 px mark in `foreground.png`. The operating system applies the
launcher mask. `startIcon.png` is a flattened 144 px derivative with transparent
rounded corners because the launch window does not apply that mask.

`scripts/card-assets/sources/app-icon-f-four-suits-mark.png` preserves the
approved generated source. `install-approved-app-icon.ps1` performs the
deterministic resize and packaging step from that PNG. The launcher and launch
window were both verified on the 360 x 720 Oniro emulator after a clean install.

---

## September 3 quick gameplay and appearance changes

The user approved using the Nine of Spades instead of the Ace of Spades in both
card-front settings previews.

The user added a sixth card-back setting named Random. They approved retaining
the current concrete back when Random is selected, choosing one of all five
concrete backs for each subsequent new game, and persisting that assignment for
the duration of the game. Random has a deliberately temporary custom preview;
the approved placeholder is a cream card with a dashed green border and a
centered green question mark. The user intends to replace it with final artwork
later.

The user also approved making wins irreversible: Undo is unavailable after the
four foundations are complete, and the entire win screen starts the standard
animated New Game flow when tapped.

The Random transition was subsequently refined after device review. Pressing
New Game must not restyle the outgoing cards. The prepared back now becomes
active only after every old card has left the screen and immediately before the
replacement deck begins its stack-entry animation.

On 2026-09-04, the user approved replacing Satin with the flat `Suits` table
background. It keeps the existing `#0B6E3F` field and reuses the Simple deck's
exact four suit paths as sparse, oversized, edge-cropped silhouettes in two
nearby greens. There is no simulated material, texture, gradient, lighting, or
shadow. The stored numeric value remains `1`, migrating existing Satin users
automatically while Solid remains the default.

The user then approved a persisted Draw setting with `1 card` and `3 cards`
choices, defaulting to draw one and applying immediately to the current game.
The centered Settings surface became vertically scrollable to accommodate the
new section. Draw mode controls the number transferred by a stock tap, while
the waste always fans its newest three available cards. The user explicitly
clarified that drawing `A, B, C` followed by `D, E, F` shows `D, E, F`, and
moving `F` must reveal `C, D, E`. Only the newest waste card is playable.

Device review exposed a keyed-rendering defect when the rolling waste window
advanced: disappearing cards were removed, but retained cards kept their prior
fan offsets and a new top could cover one of them. Waste keys now combine card
identity with the current visible slot, so all three positions update together.

The user approved smoothing the draw transition with the existing 80 ms move
timing. On each single-card step, the incoming stock card travels and turns into
the newest waste slot while the two retained cards slide left to their new fan
slots. Draw-three repeats that complete visual step up to three times in
sequence, locks input until all steps finish, and remains one Undo action.

Follow-up review clarified that continuity also applies when the playable card
leaves the waste for a tableau or foundation. Retained waste cards now slide
right as the selected card travels away, uncovering the newly visible third
card beneath them. During stock draws, the oldest outgoing visible card remains
rendered until the leftward slide covers it. Unique generation-based ArkUI keys
restart every incoming-card and retained-card component for each draw-three
step, fixing both snapped later steps and the draw-three interaction freeze.
The user explicitly rejected slowing emulator timing; all transitions remain
at the approved 80 ms because they are smooth on the physical device.

On 2026-09-07, the user approved redesigning Simple faces for simultaneous
draw-three waste and tableau readability. The Modern Banner was replaced by a
Clean Corner composition on the existing warm-white face. A compact rank sits
above a larger, suit-dominant symbol in an upper-left block centered at `x=6.5`;
the block stays within approximately 8.6 units of width and ends before `y=22`.
This keeps both identifiers inside the waste's increased 28% horizontal reveal
and the tableau's 24-unit face-up reveal. A single oversized rank is centered
at `x=22.5`, `y=44` in suit ink at 25% opacity. The design remains one-way,
with no mirrored lower-right index, and retains the approved red/black inks,
border, corner radius, exact 2:3 geometry, and stable Simple resource names.

---

## September 7 classic victory cascade

The user approved replacing the centered `You won!` text with an old-school
Solitaire victory cascade. A randomly selected non-empty foundation releases
its top card; it launches upward, moves horizontally, falls under gravity, and
bounces from the bottom with diminishing energy. The next card launches at the
preceding card's first bounce, permitting overlapping flights. Cards remain
upright and do not bounce from side edges.

The approved visual deliberately recreates a framebuffer that is not redrawn.
Each moving card and its normal shadow is stamped every 60 ms onto a transparent
canvas, and old stamps remain. The baseline motion uses 500-750 vp/s upward
speed, 90-240 vp/s horizontal speed, 1800 vp/s squared gravity, and 72% vertical
restitution. A sampled direction is reflected toward the interior when it would
leave before the first bounce. The live board remains behind the trail while the
bottom controls are hidden without changing layout geometry. The sequence is
silent, runs once, and freezes after every card has exited horizontally.

The user further approved making every victory-screen tap interrupt immediately.
All remaining board cards, active flights, and stamped copies disappear in one
frame. New Game then skips the outgoing sweep that normally slides cards off the
table, because that movement would conflict with the stamped image. The
replacement deck still rises from below and retains the complete tableau deal,
landing turns, and final stock movement. New Game invoked during ordinary play
continues to use the original complete sweep-and-deal sequence.

Real-device review found that the first implementation could stop after the
Kings and Queens. Its trajectory guard allowed a card to reach the exact side
exit boundary at its predicted first impact; the 60 ms discrete step could then
remove that card one frame before it reported the bounce that launches its
successor. The guard now keeps the complete card inside the viewport at impact,
and the timer independently restarts the chain whenever foundations remain but
no flight is active. This preserves the approved motion while making completion
unconditional.

---

## September 8 victory acceleration

The user approved retaining the existing 1x victory-cascade speed for the first
five cards, progressively accelerating cards 6 through 47, and holding the final
five cards at 4x. The acceleration is a linear per-launch ramp. Each card keeps
its assigned playback rate for its complete flight, while baseline-sized physics
substeps preserve bounce triggering and trajectory behavior at faster rates. The
user also approved halving the upward launch range from 500-750 vp/s to 250-375
vp/s, giving each card a gentler initial rise before its playback-rate scaling.
The user then approved increasing stamp frequency with playback rate so faster
cards retain the original distance between copies. A 15 ms shared scheduler and
per-flight cadence accumulator now produce 60 ms stamps at 1x and 15 ms stamps
at 4x, with intermediate rates scheduled independently.

---

## September 8 queen hairline refinement

The user approved adding a dark-brown, gently curved hairline with two small
side-swept sections beneath the Detailed queen's crown. The refinement keeps the
existing face, crown, palette, mirrored portrait geometry, and Simple deck
unchanged while making the queen's hair read continuously across her forehead.

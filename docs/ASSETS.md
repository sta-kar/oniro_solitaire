# Visual assets

This document defines the current visual asset contract. Generator commands and
reproducibility limits are documented in
[`../scripts/card-assets/README.md`](../scripts/card-assets/README.md). Design
exploration and dated approvals are preserved in
[`history/2026-09-design-history.md`](history/2026-09-design-history.md).

## Asset ownership

- `card-images/` contains the canonical Detailed deck: 52 faces, the Default
  back, four approved alternative backs, and showcase files.
- `card-images-simple/` contains the canonical 52-card Simple deck.
- `card-back-concepts/` and `card-back-variations/` contain non-production
  exploration and comparison sheets.
- `entry/src/main/resources/base/media/` contains the packaged ArkUI copies and
  table backgrounds used at runtime.
- `AppScope/resources/base/media/` and the equivalent entry media contain the
  launcher layers.
- `scripts/card-assets/sources/` preserves generator inputs that are not runtime
  resources.

The app never rewrites canonical artwork. Packaged resources are synchronized
copies or documented compatibility variants.

## Card geometry

- Every standalone card uses `viewBox="0 0 45 67.5"`, an exact `2:3` aspect
  ratio.
- The artwork preserves the original 45-by-68 coordinate system through a
  uniform vertical normalization of approximately 0.735%.
- The normal edge is a 1 px centered SVG border around a rectangle inset by
  0.5 px with a 6.5 px path radius, producing a 7 px outer radius at reference
  size.
- `preserveAspectRatio="xMidYMid meet"` prevents distortion.
- Runtime columns are `13.2%` wide; card height and tableau overlap derive from
  width so the complete board scales proportionally.

The SVG owns normal card appearance. ArkUI owns shadows, hit areas, stacking,
selection glow, and animation geometry.

## Detailed card fronts

The Detailed deck uses warm-white faces (`#FFFDF8`), red suits and ranks
(`#C62828`), and black suits and ranks (`#171717`). All visible content is vector
geometry; individual cards contain no embedded raster images and do not rely on
installed fonts.

- Ranks and suits appear in mirrored corners.
- Cards 2 through 10 use conventional pip counts and inverted lower pips.
- Jacks, Queens, and Kings use distinct mirrored geometric portraits.
- Queens use a parted, side-swept brown hairline beneath the crown so the hair
  reads continuously from forehead to the existing side and back silhouette.
- Club marks are compound filled paths so overlapping primitives cannot expose
  antialiasing seams.
- Spades use a renderer-safe filled neck between the head and stem.
- Aces retain their suit indices and use the circular Oniro mark as the center
  illustration.

Packaged Detailed faces use `playing_card_<rank>_of_<suit>.svg`. Non-ace files
match their canonical source. The four packaged aces apply an equivalent group
transform around the embedded Oniro paths because the OpenHarmony SVG renderer
does not honor the nested viewport size consistently.

## Simple card fronts

The Simple deck uses the approved Clean Corner design. It retains the Detailed
deck's geometry, warm-white face, subtle border, corner radius, and red/black
suit colors. Each card contains:

- one compact upper-left rank centered over a larger, suit-dominant symbol; and
- one oversized rank centered in the body using suit ink at 25% opacity.

Number cards deliberately omit conventional pip counts, and court cards omit
portraits. The corner index is centered at `x=6.5`, stays within approximately
8.6 units of width, and ends before `y=22`. It therefore fits inside both the
12.6-unit horizontal reveal of the draw-three waste and the 24-unit vertical
reveal between face-up tableau cards. The body rank uses a `32 em` outline,
reduced to `23 em` for `10`, and is centered at `x=22.5`, `y=44`. Aces and
court cards use the same composition as number cards. Rank glyphs are converted
to filled vector outlines because the OpenHarmony renderer does not render SVG
text reliably. Packaged files use `playing_card_simple_<rank>_of_<suit>.svg`.

## Card backs

The runtime card-back table contains five resources in this order:

| Index | Label | Canonical file | Packaged resource |
| --- | --- | --- | --- |
| `0` | Default | `card-images/card_back.svg` | `playing_card_card_back.svg` |
| `1` | Oniro Orbit | `card-images/oniro_orbit_00_original.svg` | `playing_card_back_oniro.svg` |
| `2` | Emerald Art Deco | `card-images/emerald_deco_04_ivory.svg` | `playing_card_back_emerald.svg` |
| `3` | Prism Mosaic | `card-images/prism_mosaic_02_ocean.svg` | `playing_card_back_prism.svg` |
| `4` | Solar Eclipse | `card-images/solar_eclipse_04_red_giant.svg` | `playing_card_back_eclipse.svg` |

Every stationary or animated face-down card resolves through this same table.

## Table backgrounds

Solid uses the page's deep green fallback. Suits uses
`entry/src/main/resources/base/media/suits_green_flat.png`, a 768 x 1536 flat
composition whose oversized, edge-cropped club, diamond, spade, and heart reuse
the Simple deck's exact vector paths. The two secondary greens introduce no
texture, lighting, gradients, or shadows. The older `satin_green_subtle.png` and
`felt_green_subtle.png` remain in the repository for historical continuity but
are not current Settings choices.

## App icon

The production icon is the Four Suits Mark: club, diamond, heart, and spade in a
two-by-two grid on deep green `#0B5B36`. Club, heart, and spade are warm white
`#FFFDF8`; the diamond is muted red `#C62828`. The design contains no text,
card tile, gloss, shadow, bevel, gradient, or decorative effect.

`background.png`, `foreground.png`, and `layered_image.json` provide the
1024 px launcher layers in both AppScope and entry resources. The operating
system supplies the launcher mask. `entry/src/main/resources/base/media/startIcon.png`
is the flattened 144 px launch-window derivative with transparent rounded
corners.

`scripts/card-assets/sources/app-icon-f-four-suits-mark.png` is the approved
generated source. `install-approved-app-icon.ps1` performs the deterministic
resize and packaging step.

## Oniro attribution

The ace icon is adapted from the Eclipse Foundation Oniro logo on
[Wikimedia Commons](https://commons.wikimedia.org/wiki/File:Oniro_logo.svg),
licensed [CC BY 3.0](https://creativecommons.org/licenses/by/3.0/).
The card artwork embeds only the circular icon paths and omits the page
background and right-side wordmark. See [`../NOTICE`](../NOTICE) for the
attribution that accompanies the public release.

## Validation expectations

- Parse every standalone SVG and confirm the `45 x 67.5` viewport.
- Confirm gameplay SVGs contain no embedded raster content and Simple faces
  contain no `<text>` elements.
- Render showcase SVGs with `rsvg-convert` when the artwork changes.
- Build the signed debug HAP after packaged resources change.
- Use device-side review for card readability, selected outlines, backs, table
  backgrounds, launcher masking, and launch-window presentation.

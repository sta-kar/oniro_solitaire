# Card asset generators

These PowerShell scripts generate or package the Solitaire card artwork and app
icon. Run them from the repository root. Current asset specifications are in
[`../../docs/ASSETS.md`](../../docs/ASSETS.md); recovery and design history are
in [`../../docs/history/2026-09-design-history.md`](../../docs/history/2026-09-design-history.md).

## Scripts

| Script | Purpose |
| --- | --- |
| `generate-card-images.ps1` | Generates the 52 Detailed faces, Default back, four approved alternative backs, and `all-cards.svg`. |
| `generate-simple-card-images.ps1` | Generates the 52 Simple faces and synchronizes `playing_card_simple_*` resources. |
| `polish-card-images.ps1` | Normalizes canonical Detailed inputs, applies renderer-safe suit fixes, rebuilds the showcase, and optionally synchronizes packaged resources. |
| `generate-card-back-concepts.ps1` | Generates the ten card-back concepts and `all-card-backs.svg`. |
| `generate-card-back-variations.ps1` | Generates selected originals, remaining variations, and `all-variations.svg`; `-SelectedOnly` emits only production backs. |
| `install-approved-app-icon.ps1` | Builds launcher layers and the launch-window icon from the approved source image. |

## Source of truth

The committed files in `card-images/` are the canonical final Detailed artwork.
The original creation process was iterative, and several reviewed refinements
were applied directly after initial generation. Running the main generator from
scratch does not supersede those committed files.

`polish-card-images.ps1` is safe for canonical Detailed inputs: it preserves the
reviewed artwork while applying idempotent geometry and renderer compatibility
normalizations. `card-images-simple/` is reproducible through
`generate-simple-card-images.ps1`. The two card-back generators reproduce their
families and showcases directly.

All card generators emit an exact `45 x 67.5` (`2:3`) viewport. Detailed artwork
retains the original 45-by-68 authored coordinates inside a uniform vertical
transform of approximately 0.735%.

## Overwrite safety

Generators overwrite matching names in their output directories. Use a scratch
directory for experiments and visual review.

`generate-card-images.ps1 -SourceCardDirectory` regenerates only scripted corner
indices while preserving other canonical artwork. Source and output directories
must be different; the script rejects identical resolved paths.

Do not treat a scratch generation as authoritative until it has been reviewed
and deliberately promoted to canonical and packaged locations.

## Common commands

Generate the Detailed deck into a scratch directory:

```powershell
& '.\scripts\card-assets\generate-card-images.ps1' `
  -OutputDirectory '.\scratch\card-images'
```

Regenerate only Detailed corner indices for review:

```powershell
& '.\scripts\card-assets\generate-card-images.ps1' `
  -SourceCardDirectory '.\card-images' `
  -OutputDirectory '.\scratch\large-index-preview'
```

Normalize a scratch Detailed set and create packaged copies:

```powershell
& '.\scripts\card-assets\polish-card-images.ps1' `
  -CardDirectory '.\scratch\card-images' `
  -LogoSvgPath '.\scripts\card-assets\sources\oniro-filtered.svg' `
  -PackagedMediaDirectory '.\scratch\packaged-media'
```

Regenerate the canonical Simple deck and packaged resources:

```powershell
& '.\scripts\card-assets\generate-simple-card-images.ps1'
```

Generate card-back explorations into scratch directories:

```powershell
& '.\scripts\card-assets\generate-card-back-concepts.ps1' `
  -OutputDirectory '.\scratch\card-back-concepts'

& '.\scripts\card-assets\generate-card-back-variations.ps1' `
  -OutputDirectory '.\scratch\card-back-variations'
```

The variation generator reads its four originals from the repository's
`card-back-concepts/` directory.

Install the approved app icon into AppScope and entry resources:

```powershell
& '.\scripts\card-assets\install-approved-app-icon.ps1'
```

## Implementation constraints

- Detailed rank indices use an em size of `12.0` (`10.4` for `10`) and a corner
  suit scale of `0.36`.
- Simple ranks are filled vector outlines rather than SVG text. The approved
  Clean Corner design centers a compact rank over a larger suit at `x=6.5`; the
  complete index stays within the waste's 12.6-unit horizontal reveal and ends
  before the tableau's `y=22` safety boundary. Its body centers a `32 em` rank
  (`23 em` for `10`) at `x=22.5`, `y=44` using suit ink at 25% opacity.
- Generated spades use the renderer-safe filled head-to-stem neck.
- Generated clubs use one compound filled path so antialiased overlaps cannot
  create white seams.
- `scripts/card-assets/sources/oniro-filtered.svg` is retained for compatibility
  with the historical polish stages; canonical aces use the reviewed official
  Oniro vector paths.

## Showcase rendering

The scripts create SVG showcases. Render PNG inspection sheets separately with
`rsvg-convert`:

```powershell
rsvg-convert.exe --width 1600 --height 970 `
  --output '.\scratch\card-images\all-cards.png' `
  '.\scratch\card-images\all-cards.svg'

rsvg-convert.exe --width 1200 --height 800 `
  --output '.\scratch\card-back-concepts\all-card-backs.png' `
  '.\scratch\card-back-concepts\all-card-backs.svg'

rsvg-convert.exe --width 1200 --height 1120 `
  --output '.\scratch\card-back-variations\all-variations.png' `
  '.\scratch\card-back-variations\all-variations.svg'
```

## Validation

After promoting generated assets:

1. Parse every changed SVG and verify the `0 0 45 67.5` view box.
2. Confirm no gameplay card embeds raster content.
3. Confirm Simple cards contain no `<text>` elements.
4. Render the relevant showcase and inspect it at native resolution.
5. Build the app and perform device-side review for readability and renderer
   artifacts.

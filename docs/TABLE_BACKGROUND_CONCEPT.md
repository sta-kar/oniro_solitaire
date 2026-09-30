# Table background concept

## Status

`artifacts/background-concepts/01_oversized_suits.svg` is the canonical vector
source for the approved Suits table background. Its 768 x 1536 PNG render is
packaged as `entry/src/main/resources/base/media/suits_green_flat.png`.

`artifacts/background-concepts/01_oversized_suits_board.svg` places production
card assets over the design for visual evaluation. It remains review-only.

## Approved direction

On 2026-09-04, the user approved exploring an oversized suit-watermark
background that follows the simple cards' flat vector language.

## Design

- The base remains the existing Solid green, `#0B6E3F`.
- Four oversized suit silhouettes reuse the exact club, diamond, spade, and
  heart paths from the Simple card faces.
- The marks use only two nearby greens, `#147747` and `#086138`.
- Each mark is cropped by a canvas edge, preventing the background from reading
  as a repeating wallpaper.
- There is no simulated fabric, noise, gradient, highlight, shadow, or other
  photographic surface treatment.
- The source is a scalable 768 x 1536 SVG. A PNG of the same size is generated
  for convenient review and eventual ArkUI packaging if the concept is
  approved.

## Rationale

The cards rely on large, simple silhouettes, a tightly limited palette, and
flat fills. Applying the same constraints to the table gives it visual
character without introducing fine detail that competes with ranks, suits,
empty-pile outlines, or card-back ornament.

## Integration

On 2026-09-04, the user approved replacing Satin with this design and approved
the settings label `Suits`. The existing persisted numeric value `1` is retained,
so users who selected Satin migrate automatically. Solid remains value `0` and
the fallback. The older Satin and Felt files remain unreferenced for historical
continuity.

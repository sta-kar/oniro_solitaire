# Documentation

The documentation is split between current project guidance and preserved
design history.

## Current documentation

- [`PRODUCT.md`](PRODUCT.md) defines the current gameplay, interaction, layout,
  animation, persistence, and appearance behavior.
- [`ARCHITECTURE.md`](ARCHITECTURE.md) describes implementation boundaries,
  state flow, persistence, and the ArkUI rendering approach.
- [`ANIMATION_CALLBACK_BUG.md`](ANIMATION_CALLBACK_BUG.md) records the isolated
  animation tests, RenderService PID mismatch, and remaining repair validation.
- [`APP_ANIMATION_WORKAROUND.md`](APP_ANIMATION_WORKAROUND.md) records the tested
  app-side Animator approach, probe timings, and host test command.
- [`FLIP_VISIBILITY.md`](FLIP_VISIBILITY.md) documents artwork readiness during
  flips, moves, and New Game, and summarizes visual verification.
- [`ASSETS.md`](ASSETS.md) documents the canonical visual assets, packaged
  resources, geometry, variants, and attribution.
- [`PUBLISHING.md`](PUBLISHING.md) records the public repository snapshot,
  license scope, and local signing setup.
- [`../scripts/card-assets/README.md`](../scripts/card-assets/README.md) is the
  operational guide for regenerating and validating visual assets.

## Historical documentation

- [`history/2026-09-design-history.md`](history/2026-09-design-history.md)
  preserves the dated approvals, discarded alternatives, generator recovery,
  verification notes, and asset exploration from the initial implementation.

Current behavior belongs in the current documentation. Future user-visible
design approvals should also be recorded in the history document with a date,
without turning the current specifications into a chronological log.

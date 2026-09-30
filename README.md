# Solitaire for Oniro

A portrait-oriented Klondike solitaire app built with ArkTS and ArkUI for
Oniro. It supports draw-one and draw-three stock rules, tap or drag movement,
undo, autocomplete, active-game persistence, an animated New Game deal, and
visual customization.

## Gameplay

- Tap the stock to draw one or up to three cards according to Settings. The
  waste always fans its newest three available cards; only its top is playable.
- Tap a face-up card or tableau run and then its destination, or drag it there.
- Build tableau piles downward with alternating colors; empty columns accept
  kings.
- Move any ace to any empty foundation, then build that foundation upward in
  the same suit.
- Use **Undo** to restore the state before the latest successful session action.
- Use **autocomplete** after the stock and waste are empty and all tableau cards
  are face-up.
- Open Settings to select the draw count, card back, table background, and
  card-front style.

The active board and appearance choices persist across launches. Pressing
**New Game** creates a fresh platform-random shuffle and plays the approved deal
sequence.

## Project structure

- `entry/src/main/ets/model/SolitaireGame.ets` owns game state and rules.
- `entry/src/main/ets/model/GameStateCodec.ets` validates persisted games.
- `entry/src/main/ets/model/NewGameAnimation.ets` contains deal timing helpers.
- `entry/src/main/ets/pages/Index.ets` owns ArkUI rendering and interaction.
- `entry/src/test/SolitaireGame.test.ets` contains model tests.
- [`docs/README.md`](docs/README.md) indexes product, architecture, asset, and
  historical documentation.

## Build

The project uses the Oniro CLI for build and device workflows:

```powershell
oniro-app sign . --bootstrap
oniro-app build . --product default --module entry --mode debug
```

The public source does not include signing credentials. The sign command creates
local development signing material and changes `build-profile.json5`; keep those
changes out of commits. See [`docs/PUBLISHING.md`](docs/PUBLISHING.md).

## Install and run

With the Oniro emulator connected at `[IP_ADDRESS]:55555`:

```powershell
oniro-app app apply . --device [IP_ADDRESS]:55555
oniro-app app launch . --device [IP_ADDRESS]:55555
```

Useful verification commands:

```powershell
oniro-app dump layout --bundle com.stakar.solitaire --device [IP_ADDRESS]:55555
oniro-app screenshot --device [IP_ADDRESS]:55555 -o .artifacts/solitaire.jpeg
```

## License

Project code and original artwork are licensed under the
[Apache License 2.0](LICENSE). The adapted Oniro icon on the ace cards is
attributed separately under CC BY 3.0 in [NOTICE](NOTICE) and
[`docs/ASSETS.md`](docs/ASSETS.md).

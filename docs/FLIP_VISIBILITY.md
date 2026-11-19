# Card visibility during animations

A card can appear blank when its view becomes visible before ArkUI draws its
image. Solitaire coordinates artwork readiness with the motion that hands a
card between views.

## Flips and regular gameplay

Each flipping card keeps one `AnimatedPlayingCardView`. The horizontal scale
shrinks to zero, the view swaps the image, and the second half starts after
the incoming side decodes and ArkUI reaches a frame boundary. The two
cosine-based motion halves retain their 40 ms base durations.

Stationary cards and gameplay overlays load their packaged PNGs synchronously.
Small local images suit this loading mode, which runs on the UI thread. The
New Game sweep loads its copies asynchronously while the board is still
visible. See the [OpenHarmony Image loading documentation](https://github.com/openharmony/docs/blob/OpenHarmony-6.1-Release/en/application-dev/reference/apis-arkui/arkui-ts/ts-basic-components-image.md#syncload8).

Stock draws, waste reflow, recycling, transfers, and tableau reveals keep the
overlay through motion completion and destination image readiness. A moving
flip waits for both travel and rotation. A newly exposed tableau card stays
face-down until the preceding transfer settles. `CardArtworkHandoff`
tracks each incoming card and side, then waits for a frame boundary. Its
250 ms fallback releases the handoff and logs the pending image count if a
completion callback stalls.
[`CardArtworkHandoff.ets`](../entry/src/main/ets/animation/CardArtworkHandoff.ets)

## New Game

The sweep leaves the current board visible while its hidden copies load. It
swaps to the sweep layer after image decoding and a frame boundary. A
one-second fallback allows the sweep to start if an image callback stalls.

Each face-up deal card uses a single timeline for travel and the first half
of its flip. At landing, travel is complete and the card is still
full-width. It then shrinks in place. After the motion, the overlay remains
until the stationary tableau image decodes and ArkUI reaches a frame
boundary. The remaining deck likewise stays visible while the final stock
image becomes ready.

## Investigation

The first change replaced the two opacity-switched flip views with one
persistent surface. Isolated probes displayed both sides and left the native
cause unresolved.

New Game diagnostics found two gaps:

- **Tableau landing.** In 19 of 21 covered-card handoffs, ArkUI reported that
  the stationary image decoded 6-13 ms after the flight overlay unmounted.
  All seven face-up handoffs also reported decoding after overlay removal.
- **Outgoing sweep.** The 52 moving copies decoded 53-151 ms after mounting.
  The last decode arrived 157 ms after the first copy mounted. The previous
  implementation cleared the board and started the sweep before these
  images were ready.

These results describe image and component events. The raw traces and probe
projects are local development artifacts.

## Verification

The deal and sweep were visually checked in a temporary 10x inspection build.
The current build uses normal speed. The 11 host tests passed, and the signed
build launched successfully on the test device. A bounded phone log capture
showed no matching image-load failures or handoff timeouts. In-motion visual
confirmation of the latest gameplay handoffs is pending.

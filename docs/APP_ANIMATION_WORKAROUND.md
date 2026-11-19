# App-side animation completion

Solitaire uses `UIContext.createAnimator` to drive finite card motion. Its
`onFrame` updates the animated transforms and its `onFinish` advances the
sequence. This bypasses the missing implicit-animation notifications observed
on an OpenHarmony 6.1.0.38 test device.
[Callback investigation](ANIMATION_CALLBACK_BUG.md)

## Probe results

A rectangle probe compared implicit motion with app-owned completion on the
same device.

| Operation | Configured duration | Observed completion |
| --- | ---: | ---: |
| Implicit animation with native easing | 80 ms | 1,004 ms |
| Implicit animation with custom quintic easing | 80 ms | 1,005 ms |
| Implicit motion with an app timer, native/custom easing | 80 ms | 82 / 82 ms |
| App-side Animator with quintic travel | 80 ms | 98 ms |
| App-side Animator with six cosine turn halves | 240 ms total | 286 ms |
| Repeat of the six app-side turn halves | 240 ms total | 293 ms |

The two six-half-turn sequences completed at
`[45, 94, 140, 188, 237, 286]` and `[52, 101, 146, 195, 244, 292]` ms.
The second total includes final bookkeeping. These measurements describe
callback timing on the test device. Display timing and full-game smoothness
require separate measurement.

Timer-driven three-turn sequences took 252-259 ms in the probe. They still
produced missing-agent and fallback warnings from the implicit animation
path. The app-side Animator supplies progress and completion from the same
source. It updates ArkTS state on the UI thread each active frame, so UI
work can affect its cadence.

Probe projects, traces, and raw logs are local development artifacts. The
measurements above summarize the results used for this implementation.

## Implementation

`CardAnimator.ets` owns the Animator and cancellable deferred actions.
Active overlays use it for waste
reflow, flips, and deal motion. The page also uses it for transfers, drag
returns, and deck travel. Moves target 80 ms and the two flip halves target
40 ms each. Artwork readiness can extend the handoff between stages. New Game
applies its own 2x timing scale.
[`CardAnimator.ets`](../entry/src/main/ets/animation/CardAnimator.ets)

The runner applies exact endpoints and invalidates obsolete callbacks.
It detaches callbacks before cancelling an Animator because cancellation can
emit a final frame. Zero-duration actions still complete asynchronously.
See the [OpenHarmony UIContext API](https://github.com/openharmony/docs/blob/OpenHarmony-6.1-Release/en/application-dev/reference/apis-arkui/arkts-apis-uicontext-uicontext.md#createanimator)
and [Animator lifecycle documentation](https://github.com/openharmony/docs/blob/OpenHarmony-6.1-Release/en/application-dev/reference/apis-arkui/js-apis-animator.md).

## Verification

The host suite covers endpoints, timing, cancellation, stale callbacks, and
artwork handoffs. It transpiles
the ArkTS helpers with the TypeScript module bundled in the OpenHarmony SDK
and uses simulated Animator, timer, and frame events.
[Host test source](../scripts/tests/card-animator.test.cjs)

From the repository root, replace `path-to-sdk-root` with the directory that
contains the OpenHarmony API version folders, then run:

```powershell
$sdkRoot = 'path-to-sdk-root'
$compiler = Join-Path $sdkRoot '23/ets/build-tools/ets-loader/node_modules/typescript/lib/typescript.js'
node scripts/tests/card-animator.test.cjs $compiler
```

All 11 host tests passed. ArkTS lint completed with zero errors, and the
release build installed and launched on the test device. See
[card visibility](FLIP_VISIBILITY.md) for the scope of visual verification.

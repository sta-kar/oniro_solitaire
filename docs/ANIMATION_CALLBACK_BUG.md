# RenderService animation completion investigation

On an OpenHarmony 6.1.0.38 test device, Solitaire received completion
callbacks for 40 ms implicit animations about one second after launch.
The evidence points to a RenderService application-agent registration
mismatch. The [app-side Animator workaround](APP_ANIMATION_WORKAROUND.md)
bypasses this dependency.

## Measurements

A Solitaire trace recorded 30 sequential half-turns. Each requested 40 ms
and completed after 1,001-1,007 ms. Six half-turns made each draw-three
action take about 6.2 seconds. The app's main thread used only a few
milliseconds of CPU in each one-second wait.

A separate rectangle probe reproduced the delay with native and custom
easing.

| Case | Requested duration | Completion with native/custom easing |
| --- | ---: | ---: |
| Translation | 80 ms | 1,006 / 1,005 ms |
| Scale | 40 ms | 1,004 / 1,003 ms |
| Position | 80 ms | 1,004 / 1,004 ms |
| Scale with logical completion | 40 ms | 1,003 / 1,005 ms |
| No property change | 40 ms | 41 / 42 ms |
| Translation with a 16 ms app heartbeat | 80 ms | 1,003 / 1,002 ms |

RenderService logged that it had no application agent for the probe's actual
PID. A separate trace of application-agent registration recorded a PID of
zero on fresh launches, even though the running processes had nonzero PIDs.

## Likely cause

The OpenHarmony 6.1 registration proxy sends a one-way IPC request with the
application agent and leaves the PID out of the payload. The server uses
`GetCallingPid()` as the registration key. Android Binder's documented
behavior for one-way requests explains the zero PID observed on this device.
[OpenHarmony registration proxy](https://github.com/openharmony/graphic_graphic_2d/blob/OpenHarmony-6.1-Release/rosen/modules/render_service_base/src/platform/ohos/rs_client_to_service_connection_proxy.cpp) ·
[OpenHarmony server stub](https://github.com/openharmony/graphic_graphic_2d/blob/OpenHarmony-6.1-Release/rosen/modules/render_service/main/render_server/transaction/zidl/rs_client_to_service_connection_stub.cpp) ·
[Binder caller information](https://source.android.com/docs/core/architecture/aidl/aidl-backends#caller_information)

RenderService later looks up the actual process PID to deliver the
notification. That lookup skips delivery if the agent is missing. The
client schedules a completion fallback after
`max(2 * estimated duration, 1000 ms)`, consistent with the recorded callback
times.
[RenderService lookup](https://github.com/openharmony/graphic_graphic_2d/blob/OpenHarmony-6.1-Release/rosen/modules/render_service/core/pipeline/main_thread/rs_main_thread.cpp) ·
[Implicit animation fallback](https://github.com/openharmony/graphic_graphic_2d/blob/OpenHarmony-6.1-Release/rosen/modules/render_service_client/core/animation/rs_implicit_animator.cpp)

The PID mismatch and missing-agent message were observed directly. The
source and Binder behavior support the causal explanation for the measured
device. A synchronous-registration probe stopped at symbol lookup before it
could test the proposed repair. Platform repair validation remains open.

Probe projects and raw traces are local development artifacts. The
measurements above summarize the observations used to select the workaround.

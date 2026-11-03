# Experimental Standoff2 chams work

**Incomplete and unverified.** This branch contains an experimental
RemoteCall controller and QuickLoader bridge. No chams or menu behavior has
been verified on an iPhone. Do not install it as a working chams build.

The intended effect is red behind walls and green when visible, including hands.
The material filter is derived from observed 1.1.0 game assets and includes
first-person hands as well as third-person models. It can miss other skins. Symbol resolution is
designed to use IL2CPP exports instead of hard-coded game offsets. The
experimental main-thread invocation helper is disconnected and is not tested
on an iPhone. A failed or indeterminate call must never be retried blindly.
The metadata helper can resolve classes and exact method parameter signatures
through exported functions. Bindings for relevant Unity APIs are experimental
and untested against a live game; caller-side process verification is required.
The SpringBoard target query is restricted to `com.axlebolt.standoff2`; the
PID alone is not a stable process identity and is not used to attach yet.

The game includes `SO2/Agents/OutlineHW` with `_OutlineColor`, `_ZTest`, and
`_StencilReadMask`; it is present in an event-mode shader bundle. Its runtime
availability and visual behavior outside that mode have not been verified. The
game's regular character shaders do not expose a configurable depth test.
OutlineHW is an outline shader, and full model fill has not been established.

The experimental menu uses a SpringBoard window and a native bridge, with a
mock backend test. Visibility and touch handling above the game have not been
established, and actual RemoteCall behavior is untested on a device.

The adapter, process identification, discovery, material changes, window and
teardown are prototypes that need integration and device validation. The host
tests do not exercise Cyanide's RemoteCall or the game.

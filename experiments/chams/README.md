# Experimental Standoff2 chams work

**Incomplete.** This branch does not provide a chams tweak, attach to the game,
or expose a new QuickLoader API. Do not install it as a working chams build.

The intended effect is red behind walls and green when visible, including hands.
The material filter is derived from observed 1.1.0 game assets and includes
first-person hands as well as third-person models. It can miss other skins. Symbol resolution is
designed to use IL2CPP exports instead of hard-coded game offsets. The
experimental main-thread invocation helper is disconnected and is not tested
on an iPhone. A failed or indeterminate call must never be retried blindly.
The metadata helper can resolve classes and method candidates through exported
functions, but caller-side process verification and overload signature checks
are required before those candidates may be invoked.

The game includes `SO2/Agents/OutlineHW` with `_OutlineColor`, `_ZTest`, and
`_StencilReadMask`; it is present in an event-mode shader bundle. Its runtime
availability and visual behavior outside that mode have not been verified. The
game's regular character shaders do not expose a configurable depth test.
OutlineHW is an outline shader, and full model fill has not been established.

The experimental menu implements the requested checkbox, center switch and
Exit behavior against a mock backend. It intentionally refuses to start when
the native bridge is missing. It uses a SpringBoard keyWindow, so visibility
and touch handling above the game are not established.

The game adapter, verified game session, runtime object/material discovery,
real reversible material changes, floating SpringBoard window, teardown and
device testing are still required. The host test exercises only the calling
convention; it does not exercise Cyanide's RemoteCall or the game.

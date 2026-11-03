#ifndef CY_CHAMS_WINDOW_H
#define CY_CHAMS_WINDOW_H
#include <stdbool.h>
#include <stdint.h>

typedef enum { CY_WINDOW_FAILED, CY_WINDOW_OK, CY_WINDOW_INDETERMINATE } CYWindowStatus;
typedef struct {
    uint64_t window, scene, generation;
    bool uncertain, expanded;
} CYChamsWindow;

// Experimental: only call on the serialized SpringBoard RemoteCall session.
// A returned window is retained until close. The caller must separately verify
// session liveness; generation alone does not prove a process remains alive.
// On a definite failure after allocation, call close if state.window is set.
// On an indeterminate result do not call close or issue further remote calls.
CYWindowStatus cy_chams_window_open(CYChamsWindow *state);
CYWindowStatus cy_chams_window_expand(CYChamsWindow *state, bool expanded);
CYWindowStatus cy_chams_window_close(CYChamsWindow *state);
#endif

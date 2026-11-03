#ifndef CY_CHAMS_TARGET_H
#define CY_CHAMS_TARGET_H
#include <stdint.h>

typedef enum { CY_TARGET_UNAVAILABLE, CY_TARGET_FOUND, CY_TARGET_INDETERMINATE } CYTargetStatus;
// Call only inside the existing, serialized SpringBoard session. A found PID
// must be checked again after attaching; it may exit or be reused at any time.
// This does not attach to, read from, or change the game process.
CYTargetStatus cy_chams_find_running_pid(int *pid);
#endif

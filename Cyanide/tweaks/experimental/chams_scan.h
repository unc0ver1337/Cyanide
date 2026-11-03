#ifndef CY_CHAMS_SCAN_H
#define CY_CHAMS_SCAN_H
#import "chams_apply.h"

// One discovery sweep, caller owns state and serializes the verified game
// session. On false, do not blindly retry; inspect metadata->poisoned and
// state->uncertain. This has not been exercised in a live game.
bool cy_chams_scan_once(CYChamsAdapter *adapter, CYMaterialState *state);
#endif

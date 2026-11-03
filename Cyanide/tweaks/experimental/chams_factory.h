#ifndef CY_CHAMS_FACTORY_H
#define CY_CHAMS_FACTORY_H
#import "chams_unity_bindings.h"
#import "chams_materials.h"

// Owned pinned GC handles. Destroy only after original renderers are restored.
typedef struct { uint64_t behind, visible, mode[CY_CHAMS_MODE_COUNT-1]; } CYChamsPasses;

// Experimental and disconnected: caller verifies process identity, runs on a
// serialized session, and must retain the metadata context through cleanup.
// On failure, nonzero handles still belong to the caller. If ctx is poisoned,
// no more target calls are safe. Live device rendering has not been verified.
bool cy_chams_make_passes(CYIL2CPPMetadata *ctx, const CYChamsUnityBindings *b,
                          const CYChamsStyle *style, CYChamsPasses *out);
bool cy_chams_destroy_passes(CYIL2CPPMetadata *ctx, const CYChamsUnityBindings *b,
                             CYChamsPasses *passes);
#endif

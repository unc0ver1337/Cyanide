#ifndef CY_CHAMS_APPLY_H
#define CY_CHAMS_APPLY_H
#import "chams_factory.h"

typedef struct {
    CYIL2CPPMetadata *metadata;
    const CYChamsUnityBindings *bindings;
    CYChamsPasses *passes;
} CYChamsAdapter;

// Owned result is the renderer's original material array. Caller supplies a
// pinned renderer handle and must confirm Unity object liveness and identity.
CYChange cy_chams_snapshot(CYChamsAdapter *adapter, uint64_t renderer, uint64_t *snapshot);
// Callbacks for CYMaterialOperations. The array is copied before modification;
// no raw writes to the managed heap are used. Not tested on an iPhone.
CYChange cy_chams_append(void *adapter, uint64_t renderer, uint64_t snapshot, const CYChamsStyle *style);
CYChange cy_chams_restore(void *adapter, uint64_t renderer, uint64_t snapshot);
void cy_chams_drop(void *adapter, uint64_t renderer, uint64_t snapshot, bool allow_remote);
#endif

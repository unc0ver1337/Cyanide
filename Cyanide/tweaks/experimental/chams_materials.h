#ifndef CY_CHAMS_MATERIALS_H
#define CY_CHAMS_MATERIALS_H
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Tokens are independently owned managed handles supplied by the eventual
// game adapter. A stable identity is distinct from each owned handle value.
// A snapshot preserves the complete original material array, not just its
// first material. It is never reused across game-process generations.
typedef enum { CY_CHANGE_OK, CY_CHANGE_FAILED, CY_CHANGE_UNKNOWN } CYChange;
typedef struct {
    float red[4];
    float green[4];
    // Unity CompareFunction: Always = 8; LessEqual = 4.
    int behind_ztest, visible_ztest;
    int behind_queue, visible_queue;
} CYChamsStyle;
typedef struct {
    void *context;
    CYChange (*append_overlay)(void *, uint64_t renderer, uint64_t snapshot,
                               const CYChamsStyle *style);
    CYChange (*restore)(void *, uint64_t renderer, uint64_t snapshot);
    // false forbids any remote calls; clear only local bookkeeping. Handles
    // may be zero when a caller supplies an invalid candidate.
    void (*drop)(void *, uint64_t renderer, uint64_t snapshot, bool allow_remote);
} CYMaterialOperations;

#define CY_MAX_CHAMS_RENDERERS 128
typedef struct { uint64_t identity, renderer, snapshot; } CYMaterialEntry;
typedef struct {
    uint64_t generation;
    CYMaterialEntry entries[CY_MAX_CHAMS_RENDERERS];
    size_t count;
    bool uncertain;
    CYChamsStyle style;
} CYMaterialState;

typedef enum { CY_MATERIAL_IGNORED, CY_MATERIAL_APPLIED, CY_MATERIAL_FAILED,
               CY_MATERIAL_UNCERTAIN, CY_MATERIAL_LIMIT } CYMaterialResult;
void cy_material_state_init(CYMaterialState *state, uint64_t generation);
// Takes ownership of renderer and snapshot on every return.
CYMaterialResult cy_material_consider(CYMaterialState *state,
                                      const CYMaterialOperations *ops,
                                      uint64_t identity, uint64_t renderer, uint64_t snapshot,
                                      const char *shader, const char *material);
// Restore every known change. False means restoration is not confirmed.
bool cy_material_restore_all(CYMaterialState *state, const CYMaterialOperations *ops);
// Called only after process death or verified generation change. Never sends
// old handles into a new process; adapter drops its local bookkeeping only.
void cy_material_forget_dead_process(CYMaterialState *state, const CYMaterialOperations *ops);
#endif

#include "chams_materials.h"
#include "chams_material_filter.h"
#include <string.h>

void cy_material_state_init(CYMaterialState *state, uint64_t generation) {
    if (!state) return;
    memset(state, 0, sizeof(*state));
    state->generation = generation;
    state->style.red[0] = state->style.red[3] = 1.0f;
    state->style.green[1] = state->style.green[3] = 1.0f;
    state->style.behind_ztest = 8;
    state->style.visible_ztest = 4;
    state->style.behind_queue = 3100;
    state->style.visible_queue = 3101;
}

CYMaterialResult cy_material_consider(CYMaterialState *s, const CYMaterialOperations *o,
                                      uint64_t identity, uint64_t renderer, uint64_t snapshot,
                                      const char *shader, const char *material) {
    if (!o || !o->drop) return CY_MATERIAL_FAILED;
    if (!s || !s->generation || !identity || !renderer || !snapshot || !o->append_overlay || !o->restore) {
        o->drop(o->context, renderer, snapshot, true);
        return CY_MATERIAL_FAILED;
    }
    if (s->uncertain) {
        o->drop(o->context, renderer, snapshot, true);
        return CY_MATERIAL_UNCERTAIN;
    }
    if (!cy_chams_is_agent_material(shader, material)) {
        o->drop(o->context, renderer, snapshot, true);
        return CY_MATERIAL_IGNORED;
    }
    for (size_t i = 0; i < s->count; ++i) {
        if (s->entries[i].identity == identity) {
            o->drop(o->context, renderer, snapshot, true);
            return CY_MATERIAL_IGNORED;
        }
    }
    if (s->count == CY_MAX_CHAMS_RENDERERS) {
        o->drop(o->context, renderer, snapshot, true);
        return CY_MATERIAL_LIMIT;
    }
    CYChange result = o->append_overlay(o->context, renderer, snapshot, &s->style);
    if (result == CY_CHANGE_FAILED) {
        o->drop(o->context, renderer, snapshot, true);
        return CY_MATERIAL_FAILED;
    }
    s->entries[s->count++] = (CYMaterialEntry){identity, renderer, snapshot};
    if (result != CY_CHANGE_OK) {
        s->uncertain = true;
        return CY_MATERIAL_UNCERTAIN;
    }
    return CY_MATERIAL_APPLIED;
}

bool cy_material_restore_all(CYMaterialState *s, const CYMaterialOperations *o) {
    if (!s || !o || !o->restore || !o->drop || s->uncertain) return false;
    while (s->count) {
        CYMaterialEntry entry = s->entries[s->count - 1];
        CYChange result = o->restore(o->context, entry.renderer, entry.snapshot);
        if (result != CY_CHANGE_OK) {
            // Even a known failure leaves a live modification in place. Retain
            // its snapshot and do not claim that chams were turned off.
            if (result != CY_CHANGE_FAILED) s->uncertain = true;
            return false;
        }
        o->drop(o->context, entry.renderer, entry.snapshot, true);
        --s->count;
    }
    return true;
}

void cy_material_forget_dead_process(CYMaterialState *s, const CYMaterialOperations *o) {
    if (!s || !o || !o->drop) return;
    while (s->count) {
        CYMaterialEntry entry = s->entries[--s->count];
        o->drop(o->context, entry.renderer, entry.snapshot, false);
    }
    s->generation = 0;
    s->uncertain = false;
}

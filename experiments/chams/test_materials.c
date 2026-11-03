#include "../../Cyanide/tweaks/experimental/chams_materials.h"
#include <assert.h>
#include <stdio.h>

typedef struct { int applies, restores, live_drops, dead_drops; CYChange next; } Fake;
static CYChange apply(void *ctx, uint64_t r, uint64_t snap, const CYChamsStyle *s) {
    Fake *f=ctx; assert(r && snap && s);
    assert(s->red[0]==1 && s->red[1]==0 && s->red[2]==0 && s->red[3]==1);
    assert(s->green[0]==0 && s->green[1]==1 && s->green[2]==0 && s->green[3]==1);
    assert(s->behind_ztest==8 && s->visible_ztest==4);
    assert(s->behind_queue < s->visible_queue);
    f->applies++; return f->next;
}
static CYChange restore(void *ctx, uint64_t r, uint64_t snap) {
    Fake *f=ctx; assert(r && snap); f->restores++; return f->next;
}
static void drop(void *ctx, uint64_t r, uint64_t snap, bool alive) {
    Fake *f=ctx; assert(r && snap); if (alive) f->live_drops++; else f->dead_drops++;
}
int main(void) {
    CYMaterialState s; Fake f={0};
    CYMaterialOperations o={&f,apply,restore,drop};
    cy_material_state_init(&s,7);
    assert(cy_material_consider(&s,&o,1,11,21,"SO2/Agents/CoreAgent","CT_TP_Diffuse")==CY_MATERIAL_APPLIED);
    assert(cy_material_consider(&s,&o,2,12,22,"SO2/MSO/Mso","CT_FP_PBR")==CY_MATERIAL_APPLIED);
    assert(cy_material_consider(&s,&o,1,13,23,"SO2/Agents/CoreAgent","CT_TP_Diffuse")==CY_MATERIAL_IGNORED);
    assert(f.applies==2 && f.live_drops==1 && s.count==2);
    assert(cy_material_restore_all(&s,&o));
    assert(f.restores==2 && f.live_drops==3 && s.count==0);
    f.next=CY_CHANGE_FAILED;
    assert(cy_material_consider(&s,&o,1,11,21,"SO2/Agents/CoreAgent","CT_TP_Diffuse")==CY_MATERIAL_FAILED);
    assert(s.count==0 && !s.uncertain);
    f.next=CY_CHANGE_UNKNOWN;
    assert(cy_material_consider(&s,&o,1,11,21,"SO2/Agents/CoreAgent","CT_TP_Diffuse")==CY_MATERIAL_UNCERTAIN);
    assert(s.count==1 && s.uncertain);
    assert(!cy_material_restore_all(&s,&o));
    assert(f.restores==2);
    cy_material_forget_dead_process(&s,&o);
    assert(f.dead_drops==1 && s.count==0 && s.generation==0);
    puts("Material ownership and recovery tests passed (mock adapter).");
    return 0;
}

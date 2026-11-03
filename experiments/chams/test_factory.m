#define RemoteCall_h
#define remote_objc_h
#import "remote_syntax_stubs.h"
#import "../../Cyanide/tweaks/experimental/chams_factory.h"
#import "../../Cyanide/tweaks/experimental/chams_factory.m"
#include <assert.h>
#include <stdio.h>

static uint64_t nextHandle=100;
static int red, green, other, always, visible, queue3100, queue3101, otherQueue, destroys, releases;
bool cy_metadata_handle_target(CYIL2CPPMetadata *c, uint64_t handle, uint64_t *object) {
    (void)c; *object=handle; return handle != 0;
}
bool cy_metadata_handle_free(CYIL2CPPMetadata *c, uint64_t handle) {
    (void)c; assert(handle); releases++; return true;
}
CYIL2CPPCallStatus cy_chams_new_string(CYIL2CPPMetadata *c, const char *s, CYIL2CPPRootedResult *out) {
    (void)c; assert(s); ++nextHandle; *out=(CYIL2CPPRootedResult){nextHandle,nextHandle,0}; return CY_IL2CPP_CALL_COMPLETED;
}
CYIL2CPPCallStatus cy_chams_new_object(CYIL2CPPMetadata *c, uint64_t klass, CYIL2CPPRootedResult *out) {
    (void)c; assert(klass==1); ++nextHandle; *out=(CYIL2CPPRootedResult){nextHandle,nextHandle,0}; return CY_IL2CPP_CALL_COMPLETED;
}
CYIL2CPPCallStatus cy_il2cpp_call_managed(RemoteCallSession *session, uint64_t invoke, uint64_t gc,
    uint64_t method, uint64_t instance, const CYIL2CPPArgument *args, size_t count,
    bool object, CYIL2CPPRootedResult *out) {
    (void)session; (void)invoke; (void)gc; memset(out,0,sizeof(*out));
    if (method==2) { assert(!instance && object && count==1); out->object=++nextHandle; out->gc_handle=nextHandle; }
    else if (method==3) { assert(instance && count==1 && args[0].reference); }
    else if (method==4) {
        assert(instance && count==2 && args[1].size==16);
        const float *v=args[1].bytes; if (v[0]==1 && v[1]==0) red++; else if (v[0]==0 && v[1]==1) green++; else other++;
    } else if (method==5) {
        assert(instance && count==2 && args[1].size==sizeof(int)); int v=*(const int *)args[1].bytes;
        if (v==8) always++; else if (v==4) visible++; else assert(0);
    } else if (method==6) {
        assert(instance && count==1); int v=*(const int *)args[0].bytes;
        if (v==3100) queue3100++; else if (v==3101) queue3101++; else if(v>=3102 && v<=3107) otherQueue++; else assert(0);
    } else if (method==7) { assert(!instance && count==1 && args[0].reference); destroys++; }
    else assert(0);
    return CY_IL2CPP_CALL_COMPLETED;
}
int main(void) {
    CYIL2CPPMetadata c={0}; c.session=(RemoteCallSession *)1; c.generation=1;
    CYChamsUnityBindings b={0}; b.material_class=1; b.shader_find=2; b.material_constructor=3;
    b.material_set_color=4; b.material_set_int=5; b.material_set_queue=6; b.object_destroy=7;
    CYMaterialState state; cy_material_state_init(&state,1); CYChamsStyle s=state.style;
    CYChamsPasses passes={0};
    assert(cy_chams_make_passes(&c,&b,&s,&passes));
    assert(passes.behind && passes.visible && passes.mode[5] && red==1 && green==1 && other==6 && always==6 && visible==2 && queue3100==1 && queue3101==1 && otherQueue==6 && releases==4);
    assert(cy_chams_destroy_passes(&c,&b,&passes) && !passes.behind && !passes.visible && destroys==8 && releases==12);
    puts("Material factory sequence passed (mock Unity calls)."); return 0;
}

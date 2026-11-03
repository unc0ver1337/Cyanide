#import "chams_apply.h"
#import "chams_alloc.h"
#import "il2cpp_managed_call.h"
#include <string.h>

static CYChange invoke(CYChamsAdapter *a, uint64_t method, uint64_t instance,
                        const CYIL2CPPArgument *args, size_t n, bool object,
                        CYIL2CPPRootedResult *out) {
    CYIL2CPPMetadata *c=a->metadata;
    CYIL2CPPCallStatus s=cy_il2cpp_call_managed(c->session,c->symbols.runtime_invoke,
                           c->symbols.gchandle_new,method,instance,args,n,object,out);
    if (s==CY_IL2CPP_CALL_INDETERMINATE) { c->poisoned=true; return CY_CHANGE_UNKNOWN; }
    if (s!=CY_IL2CPP_CALL_COMPLETED || out->exception) return CY_CHANGE_FAILED;
    if (object && out->object && !out->gc_handle) { c->poisoned=true; return CY_CHANGE_UNKNOWN; }
    return CY_CHANGE_OK;
}
static bool valid(CYChamsAdapter *a) {
    return a && a->metadata && !a->metadata->poisoned && a->metadata->generation && a->bindings && a->passes;
}
static bool object(CYChamsAdapter *a, uint64_t handle, uint64_t *value) {
    return handle && cy_metadata_handle_target(a->metadata,handle,value) && *value;
}
static bool free_handle(CYChamsAdapter *a, uint64_t handle) {
    return !handle || (!a->metadata->poisoned && cy_metadata_handle_free(a->metadata,handle));
}
CYChange cy_chams_snapshot(CYChamsAdapter *a, uint64_t renderer, uint64_t *snapshot) {
    if (snapshot) *snapshot=0;
    uint64_t r=0; CYIL2CPPRootedResult result={0};
    if (!valid(a) || !snapshot || !a->bindings->renderer_get_materials || !object(a,renderer,&r)) return CY_CHANGE_FAILED;
    CYChange status=invoke(a,a->bindings->renderer_get_materials,r,NULL,0,true,&result);
    *snapshot=result.gc_handle;
    if (status!=CY_CHANGE_OK) return status;
    return result.object && result.gc_handle ? CY_CHANGE_OK : CY_CHANGE_FAILED;
}
CYChange cy_chams_append(void *context, uint64_t renderer, uint64_t snapshot, const CYChamsStyle *style) {
    CYChamsAdapter *a=context; (void)style;
    if (!valid(a) || !a->bindings->array_get_length || !a->bindings->array_copy ||
        !a->bindings->array_set_value || !a->bindings->renderer_set_materials || !a->bindings->material_class)
        return CY_CHANGE_FAILED;
    uint64_t r=0, original=0, behind=0, front=0, replacement=0, boxed=0, array=0;
    int32_t count=0; CYIL2CPPRootedResult result={0}; CYChange status=CY_CHANGE_FAILED;
    if (!object(a,renderer,&r) || !object(a,snapshot,&original) ||
        !object(a,a->passes->behind,&behind) || !object(a,a->passes->visible,&front)) return CY_CHANGE_FAILED;
    status=invoke(a,a->bindings->array_get_length,original,NULL,0,true,&result);
    boxed=result.gc_handle;
    if (status!=CY_CHANGE_OK) goto done;
    if (!boxed || !cy_metadata_unbox(a->metadata,boxed,&count,sizeof(count))) { status=CY_CHANGE_FAILED; goto done; }
    if (count<1 || count>256) { status=CY_CHANGE_FAILED; goto done; }
    CYIL2CPPCallStatus allocated=cy_chams_new_array(a->metadata,a->bindings->material_class,(size_t)count+2,&result);
    replacement=result.gc_handle;
    if (allocated==CY_IL2CPP_CALL_INDETERMINATE) { status=CY_CHANGE_UNKNOWN; goto done; }
    if (allocated!=CY_IL2CPP_CALL_COMPLETED || !replacement || !object(a,replacement,&array)) { status=CY_CHANGE_FAILED; goto done; }
    CYIL2CPPArgument copyArgs[]={{.kind=CY_ARGUMENT_REFERENCE,.reference=original},
        {.kind=CY_ARGUMENT_REFERENCE,.reference=array}, {.kind=CY_ARGUMENT_VALUE,.bytes=&count,.size=sizeof(count)}};
    status=invoke(a,a->bindings->array_copy,0,copyArgs,3,false,&result);
    if (status!=CY_CHANGE_OK) goto done;
    int32_t index=count;
    CYIL2CPPArgument setArgs[]={{.kind=CY_ARGUMENT_REFERENCE,.reference=behind},
        {.kind=CY_ARGUMENT_VALUE,.bytes=&index,.size=sizeof(index)}};
    status=invoke(a,a->bindings->array_set_value,array,setArgs,2,false,&result);
    if (status!=CY_CHANGE_OK) goto done;
    index=count+1; setArgs[0].reference=front;
    status=invoke(a,a->bindings->array_set_value,array,setArgs,2,false,&result);
    if (status!=CY_CHANGE_OK) goto done;
    CYIL2CPPArgument arg={.kind=CY_ARGUMENT_REFERENCE,.reference=array};
    status=invoke(a,a->bindings->renderer_set_materials,r,&arg,1,false,&result);
    // An exception or transport failure after entering the setter cannot prove
    // the renderer stayed unchanged; quarantine its original snapshot.
    if (status!=CY_CHANGE_OK) status=CY_CHANGE_UNKNOWN;
done:
    if (status==CY_CHANGE_UNKNOWN || a->metadata->poisoned) return CY_CHANGE_UNKNOWN;
    if (!free_handle(a,replacement) || !free_handle(a,boxed)) return CY_CHANGE_UNKNOWN;
    return status;
}
CYChange cy_chams_restore(void *context, uint64_t renderer, uint64_t snapshot) {
    CYChamsAdapter *a=context; uint64_t r=0, original=0; CYIL2CPPRootedResult result={0};
    if (!valid(a) || !a->bindings->renderer_set_materials || !object(a,renderer,&r) || !object(a,snapshot,&original)) return CY_CHANGE_FAILED;
    CYIL2CPPArgument arg={.kind=CY_ARGUMENT_REFERENCE,.reference=original};
    CYChange status=invoke(a,a->bindings->renderer_set_materials,r,&arg,1,false,&result);
    return status==CY_CHANGE_OK ? status : CY_CHANGE_UNKNOWN;
}
void cy_chams_drop(void *context, uint64_t renderer, uint64_t snapshot, bool allow_remote) {
    CYChamsAdapter *a=context;
    if (!allow_remote || !valid(a)) return;
    if (!free_handle(a,snapshot)) return;
    (void)free_handle(a,renderer);
}

#import "chams_scan.h"
#import "il2cpp_managed_call.h"
#include <string.h>

typedef struct { CYChamsAdapter *adapter; bool ok; } Scan;
static uint64_t target(Scan *s,uint64_t handle) {
    uint64_t p=0;
    if (!s->ok || !handle || !cy_metadata_handle_target(s->adapter->metadata,handle,&p)) { s->ok=false; return 0; }
    return p;
}
static void drop(Scan *s,uint64_t *handle) {
    if (!*handle) return;
    if (s->adapter->metadata->poisoned) { s->ok=false; return; }
    if (!cy_metadata_handle_free(s->adapter->metadata,*handle)) s->ok=false;
    else *handle=0;
}
static uint64_t invoke_object(Scan *s,uint64_t method,uint64_t instance,const CYIL2CPPArgument *args,size_t count) {
    if (!s->ok || !method) { s->ok=false; return 0; }
    CYIL2CPPMetadata *c=s->adapter->metadata; CYIL2CPPRootedResult r={0};
    CYIL2CPPCallStatus st=cy_il2cpp_call_managed(c->session,c->symbols.runtime_invoke,c->symbols.gchandle_new,
                                                 method,instance,args,count,true,&r);
    if (st==CY_IL2CPP_CALL_INDETERMINATE || (r.object && !r.gc_handle)) c->poisoned=true;
    if (st!=CY_IL2CPP_CALL_COMPLETED || r.exception || (r.object && !r.gc_handle)) {
        if (r.gc_handle) drop(s,&r.gc_handle);
        s->ok=false; return 0;
    }
    return r.gc_handle;
}
static bool integer(Scan *s,uint64_t method,uint64_t instance,int32_t *value) {
    uint64_t boxed=invoke_object(s,method,instance,NULL,0);
    if (!boxed || !cy_metadata_unbox(s->adapter->metadata,boxed,value,sizeof(*value))) s->ok=false;
    drop(s,&boxed);return s->ok;
}
static uint64_t element(Scan *s,uint64_t array,int32_t i) {
    CYIL2CPPArgument arg={.kind=CY_ARGUMENT_VALUE,.bytes=&i,.size=sizeof(i)};
    return invoke_object(s,s->adapter->bindings->array_get_value,array,&arg,1);
}
static bool read_name(Scan *s,uint64_t object,char *name,size_t capacity) {
    uint64_t h=invoke_object(s,s->adapter->bindings->object_get_name,object,NULL,0);
    bool ok=h && cy_metadata_string_ascii(s->adapter->metadata,h,name,capacity);
    drop(s,&h); return ok && s->ok;
}
static bool scan_renderer(Scan *s,CYMaterialState *state,uint64_t *renderer) {
    const CYChamsUnityBindings *b=s->adapter->bindings; uint64_t r=target(s,*renderer);
    uint64_t mesh=0,snapshot=0,material=0,shader=0; int32_t submeshes=0,identity=0,count=0;
    char materialName[256]={0},shaderName[256]={0}; bool matchReady=false;
    if (!r) goto done;
    mesh=invoke_object(s,b->skinned_get_mesh,r,NULL,0);
    if (!s->ok || !mesh) goto done;
    uint64_t meshObject=target(s,mesh);
    if (!meshObject || !integer(s,b->mesh_get_submesh_count,meshObject,&submeshes)) goto done;
    if (submeshes!=1) goto done;
    if (!integer(s,b->object_get_instance_id,r,&identity) || !identity) goto done;
    CYChange status=cy_chams_snapshot(s->adapter,*renderer,&snapshot);
    if (status==CY_CHANGE_UNKNOWN) { s->ok=false; goto done; }
    if (status!=CY_CHANGE_OK || !snapshot) goto done;
    uint64_t array=target(s,snapshot);
    if (!array || !integer(s,b->array_get_length,array,&count)) goto done;
    if (count!=1) goto done;
    material=element(s,array,0);
    uint64_t mat=material ? target(s,material) : 0;
    if (!mat || !read_name(s,mat,materialName,sizeof(materialName))) goto done;
    shader=invoke_object(s,b->material_get_shader,mat,NULL,0);
    uint64_t sh=shader ? target(s,shader) : 0;
    if (!sh || !read_name(s,sh,shaderName,sizeof(shaderName))) goto done;
    matchReady=true;
done:
    drop(s,&shader);drop(s,&material);drop(s,&mesh);
    if (matchReady && s->ok) {
        CYMaterialOperations ops={s->adapter,cy_chams_append,cy_chams_restore,cy_chams_drop};
        CYMaterialResult result=cy_material_consider(state,&ops,(uint32_t)identity,*renderer,snapshot,shaderName,materialName);
        *renderer=0;snapshot=0;
        if (result==CY_MATERIAL_UNCERTAIN) s->adapter->metadata->poisoned=true;
        if (result==CY_MATERIAL_UNCERTAIN || result==CY_MATERIAL_FAILED || result==CY_MATERIAL_LIMIT) s->ok=false;
    }
    drop(s,&snapshot);
    return s->ok;
}
bool cy_chams_scan_once(CYChamsAdapter *adapter,CYMaterialState *state) {
    if (!adapter || !adapter->metadata || adapter->metadata->poisoned || !adapter->bindings || !state ||
        !state->generation || state->uncertain || state->generation!=adapter->metadata->generation) return false;
    const CYChamsUnityBindings *b=adapter->bindings;
    if (!b->skinned_renderer_class || !b->resources_find_all || !b->array_get_value || !b->array_get_length ||
        !b->skinned_get_mesh || !b->mesh_get_submesh_count || !b->object_get_instance_id ||
        !b->object_get_name || !b->material_get_shader) return false;
    Scan s={adapter,true};uint64_t type=0,array=0;
    if (!cy_metadata_type_handle(adapter->metadata,b->skinned_renderer_class,&type)) { s.ok=false; goto done; }
    uint64_t typeObject=target(&s,type);
    if (!typeObject) goto done;
    CYIL2CPPArgument arg={.kind=CY_ARGUMENT_REFERENCE,.reference=typeObject};
    array=invoke_object(&s,b->resources_find_all,0,&arg,1);
    uint64_t arrayObject=array ? target(&s,array) : 0; int32_t count=0;
    if (!arrayObject || !integer(&s,b->array_get_length,arrayObject,&count) || count<0 || count>4096) { s.ok=false; goto done; }
    for (int32_t i=0;i<count && s.ok;i++) {
        uint64_t renderer=element(&s,arrayObject,i);
        if (renderer) scan_renderer(&s,state,&renderer);
        drop(&s,&renderer);
    }
done:
    drop(&s,&array);drop(&s,&type);
    return s.ok && !adapter->metadata->poisoned;
}

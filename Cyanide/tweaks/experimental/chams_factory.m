#import "chams_factory.h"
#import "chams_alloc.h"
#import "il2cpp_managed_call.h"
#include <string.h>

static bool managed(CYIL2CPPMetadata *c, uint64_t method, uint64_t instance,
                    const CYIL2CPPArgument *args, size_t n, bool object,
                    CYIL2CPPRootedResult *result) {
    CYIL2CPPCallStatus status = cy_il2cpp_call_managed(c->session, c->symbols.runtime_invoke,
        c->symbols.gchandle_new, method, instance, args, n, object, result);
    if (status == CY_IL2CPP_CALL_INDETERMINATE) c->poisoned = true;
    return status == CY_IL2CPP_CALL_COMPLETED && !result->exception;
}
static bool target(CYIL2CPPMetadata *c, uint64_t handle, uint64_t *object) {
    return handle && cy_metadata_handle_target(c, handle, object) && *object;
}
static bool new_string(CYIL2CPPMetadata *c, const char *value, uint64_t *handle) {
    CYIL2CPPRootedResult result = {0};
    CYIL2CPPCallStatus status = cy_chams_new_string(c, value, &result);
    *handle = result.gc_handle;
    return status == CY_IL2CPP_CALL_COMPLETED && result.object && result.gc_handle;
}
static bool release_handle(CYIL2CPPMetadata *c, uint64_t *handle) {
    if (!*handle) return true;
    if (c->poisoned || !cy_metadata_handle_free(c, *handle)) return false;
    *handle = 0; return true;
}
static bool configure(CYIL2CPPMetadata *c, const CYChamsUnityBindings *b,
                      uint64_t material, uint64_t colorName, uint64_t depthName,
                      const float color[4], int depth, int queue) {
    uint64_t m = 0, col = 0, z = 0;
    CYIL2CPPRootedResult result = {0};
    if (!target(c, material, &m) || !target(c, colorName, &col) || !target(c, depthName, &z)) return false;
    CYIL2CPPArgument colorArgs[] = {{.kind=CY_ARGUMENT_REFERENCE, .reference=col},
                                    {.kind=CY_ARGUMENT_VALUE, .bytes=color, .size=sizeof(float)*4}};
    CYIL2CPPArgument depthArgs[] = {{.kind=CY_ARGUMENT_REFERENCE, .reference=z},
                                    {.kind=CY_ARGUMENT_VALUE, .bytes=&depth, .size=sizeof(depth)}};
    CYIL2CPPArgument queueArg = {.kind=CY_ARGUMENT_VALUE, .bytes=&queue, .size=sizeof(queue)};
    return managed(c,b->material_set_color,m,colorArgs,2,false,&result) &&
           managed(c,b->material_set_int,m,depthArgs,2,false,&result) &&
           managed(c,b->material_set_queue,m,&queueArg,1,false,&result);
}
static bool create_material(CYIL2CPPMetadata *c, const CYChamsUnityBindings *b,
                             uint64_t shader, uint64_t *out) {
    CYIL2CPPRootedResult result = {0}; uint64_t s = 0, m = 0;
    CYIL2CPPCallStatus status = cy_chams_new_object(c, b->material_class, &result);
    *out = result.gc_handle;
    if (status != CY_IL2CPP_CALL_COMPLETED || !result.object || !result.gc_handle ||
        !target(c, shader, &s) || !target(c, *out, &m)) return false;
    CYIL2CPPArgument arg = {.kind=CY_ARGUMENT_REFERENCE, .reference=s};
    return managed(c, b->material_constructor, m, &arg, 1, false, &result);
}
bool cy_chams_make_passes(CYIL2CPPMetadata *c, const CYChamsUnityBindings *b,
                          const CYChamsStyle *style, CYChamsPasses *out) {
    if (!out) return false;
    memset(out, 0, sizeof(*out));
    if (!c || c->poisoned || !b || !style || !b->material_class || !b->shader_find ||
        !b->material_constructor || !b->material_set_color || !b->material_set_int ||
        !b->material_set_queue || !b->object_destroy) return false;
    uint64_t shaderName=0, colorName=0, depthName=0, shader=0, nameObject=0;
    CYIL2CPPRootedResult result = {0}; bool ok = false;
    if (!new_string(c,"UI/Default",&shaderName) || !new_string(c,"_Color",&colorName) ||
        !new_string(c,"unity_GUIZTestMode",&depthName) || !target(c,shaderName,&nameObject)) goto done;
    CYIL2CPPArgument arg = {.kind=CY_ARGUMENT_REFERENCE,.reference=nameObject};
    if (!managed(c,b->shader_find,0,&arg,1,true,&result)) { shader=result.gc_handle; goto done; }
    shader=result.gc_handle;
    if (!result.object || !shader || !create_material(c,b,shader,&out->behind) ||
        !create_material(c,b,shader,&out->visible) ||
        !configure(c,b,out->behind,colorName,depthName,style->red,style->behind_ztest,style->behind_queue) ||
        !configure(c,b,out->visible,colorName,depthName,style->green,style->visible_ztest,style->visible_queue)) goto done;
    ok = true;
done:
    if (!release_handle(c,&shader) || !release_handle(c,&depthName) ||
        !release_handle(c,&colorName) || !release_handle(c,&shaderName)) ok = false;
    return ok;
}
bool cy_chams_destroy_passes(CYIL2CPPMetadata *c, const CYChamsUnityBindings *b,
                             CYChamsPasses *passes) {
    if (!c || c->poisoned || !b || !b->object_destroy || !passes) return false;
    uint64_t *handles[] = {&passes->visible, &passes->behind};
    for (unsigned i=0;i<2;i++) {
        if (!*handles[i]) continue;
        uint64_t object=0; CYIL2CPPRootedResult result={0};
        if (!target(c,*handles[i],&object)) return false;
        CYIL2CPPArgument arg={.kind=CY_ARGUMENT_REFERENCE,.reference=object};
        if (!managed(c,b->object_destroy,0,&arg,1,false,&result) || !release_handle(c,handles[i])) return false;
    }
    return true;
}

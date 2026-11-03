#import "chams_unity_bindings.h"
#include <stddef.h>
#include <string.h>

typedef struct { const char *name; size_t offset; } ClassSpec;
#define CLASS(member, value) {value, offsetof(CYChamsUnityBindings, member)}
static const ClassSpec kClasses[] = {
    CLASS(object_class, "Object"), CLASS(resources_class, "Resources"),
    CLASS(shader_class, "Shader"), CLASS(material_class, "Material"),
    CLASS(renderer_class, "Renderer"), CLASS(skinned_renderer_class, "SkinnedMeshRenderer"),
    CLASS(mesh_class, "Mesh"), CLASS(texture_class, "Texture2D"),
    CLASS(component_class, "Component"), CLASS(game_object_class, "GameObject")
};
#undef CLASS

typedef struct {
    size_t class_offset, method_offset;
    const char *name, *return_type;
    unsigned count;
    const char *types[2];
} MethodSpec;
#define METHOD(cls, field, method, result, n, a, b) \
    {offsetof(CYChamsUnityBindings, cls), offsetof(CYChamsUnityBindings, field), method, result, n, {a,b}}
static const MethodSpec kMethods[] = {
    METHOD(object_class, object_get_instance_id, "GetInstanceID", "System.Int32", 0, NULL, NULL),
    METHOD(object_class, object_get_name, "get_name", "System.String", 0, NULL, NULL),
    METHOD(object_class, object_is_alive, "op_Implicit", "System.Boolean", 1, "UnityEngine.Object", NULL),
    METHOD(resources_class, resources_find_all, "FindObjectsOfTypeAll", "UnityEngine.Object[]", 1, "System.Type", NULL),
    METHOD(shader_class, shader_find, "Find", "UnityEngine.Shader", 1, "System.String", NULL),
    METHOD(shader_class, shader_is_supported, "get_isSupported", "System.Boolean", 0, NULL, NULL),
    METHOD(material_class, material_constructor, ".ctor", "System.Void", 1, "UnityEngine.Shader", NULL),
    METHOD(material_class, material_get_shader, "get_shader", "UnityEngine.Shader", 0, NULL, NULL),
    METHOD(material_class, material_set_color, "SetColor", "System.Void", 2, "System.String", "UnityEngine.Color"),
    METHOD(material_class, material_set_int, "SetInt", "System.Void", 2, "System.String", "System.Int32"),
    METHOD(material_class, material_set_queue, "set_renderQueue", "System.Void", 1, "System.Int32", NULL),
    METHOD(material_class, material_set_texture, "SetTexture", "System.Void", 2, "System.String", "UnityEngine.Texture"),
    METHOD(renderer_class, renderer_get_materials, "get_sharedMaterials", "UnityEngine.Material[]", 0, NULL, NULL),
    METHOD(renderer_class, renderer_set_materials, "set_sharedMaterials", "System.Void", 1, "UnityEngine.Material[]", NULL),
    METHOD(skinned_renderer_class, skinned_get_mesh, "get_sharedMesh", "UnityEngine.Mesh", 0, NULL, NULL),
    METHOD(mesh_class, mesh_get_submesh_count, "get_subMeshCount", "System.Int32", 0, NULL, NULL),
    METHOD(texture_class, texture_get_white, "get_whiteTexture", "UnityEngine.Texture2D", 0, NULL, NULL),
    METHOD(component_class, component_get_game_object, "get_gameObject", "UnityEngine.GameObject", 0, NULL, NULL),
    METHOD(game_object_class, game_object_get_active, "get_activeInHierarchy", "System.Boolean", 0, NULL, NULL),
    METHOD(renderer_class, renderer_get_enabled, "get_enabled", "System.Boolean", 0, NULL, NULL)
};
#undef METHOD

bool cy_chams_find_unity_bindings(CYIL2CPPMetadata *ctx, CYChamsUnityBindings *out) {
    if (!out) return false;
    memset(out, 0, sizeof(*out));
    if (!ctx || ctx->poisoned) return false;
    CYChamsUnityBindings result = {0};
    for (size_t i = 0; i < sizeof(kClasses) / sizeof(kClasses[0]); ++i) {
        uint64_t value = 0;
        if (!cy_metadata_class(ctx, "UnityEngine.CoreModule", "UnityEngine", kClasses[i].name, &value))
            return false;
        *(uint64_t *)((char *)&result + kClasses[i].offset) = value;
    }
    for (size_t i = 0; i < sizeof(kMethods) / sizeof(kMethods[0]); ++i) {
        const MethodSpec *spec = &kMethods[i];
        uint64_t klass = *(uint64_t *)((char *)&result + spec->class_offset), value = 0;
        if (!cy_metadata_method_exact(ctx, klass, spec->name, spec->return_type, spec->types, spec->count, &value))
            return false;
        *(uint64_t *)((char *)&result + spec->method_offset) = value;
    }
    *out = result;
    return true;
}

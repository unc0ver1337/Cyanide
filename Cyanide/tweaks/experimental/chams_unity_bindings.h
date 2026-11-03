#ifndef CY_CHAMS_UNITY_BINDINGS_H
#define CY_CHAMS_UNITY_BINDINGS_H
#import "il2cpp_metadata.h"

typedef struct {
    uint64_t object_class, resources_class, shader_class, material_class;
    uint64_t renderer_class, skinned_renderer_class, mesh_class, texture_class;
    uint64_t component_class, game_object_class;
    uint64_t array_class, array_get_length, array_copy, array_set_value, array_get_value;
    uint64_t object_get_instance_id, object_get_name, object_is_alive, object_destroy;
    uint64_t resources_find_all, shader_find, shader_is_supported;
    uint64_t material_constructor, material_get_shader, material_set_color;
    uint64_t material_set_int, material_set_queue, material_set_texture;
    uint64_t renderer_get_materials, renderer_set_materials;
    uint64_t skinned_get_mesh, mesh_get_submesh_count, texture_get_white;
    uint64_t component_get_game_object, game_object_get_active, renderer_get_enabled;
} CYChamsUnityBindings;

// Resolve metadata only; no Unity method is invoked. A partial result is
// discarded. Caller verifies target identity and serializes the session.
bool cy_chams_find_unity_bindings(CYIL2CPPMetadata *ctx, CYChamsUnityBindings *out);
#endif

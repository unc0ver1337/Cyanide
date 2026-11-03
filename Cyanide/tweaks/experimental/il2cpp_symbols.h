#ifndef CY_IL2CPP_SYMBOLS_H
#define CY_IL2CPP_SYMBOLS_H
#import "../../TaskRop/RemoteCall.h"
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint64_t domain_get, domain_assembly_open, assembly_get_image;
    uint64_t class_from_name, class_get_method_from_name, class_get_type;
    uint64_t type_get_object, runtime_invoke, string_new, string_length, string_chars, object_new, object_unbox;
    uint64_t gchandle_new, gchandle_get_target, gchandle_free;
    uint64_t thread_current, thread_attach, thread_detach;
    uint64_t class_get_methods, method_get_name, method_get_param_count;
    uint64_t method_get_param, method_get_return_type, type_get_name, free;
    uint64_t array_new, array_length, array_object_header_size, gc_wbarrier_set_field;
} CYIL2CPPSymbols;

// The caller supplies a handle for the already-loaded UnityFramework. This
// does not attach to a process or execute an IL2CPP function. On indeterminate
// completion, the caller must not issue further calls or retry automatically.
bool cy_il2cpp_resolve_symbols(RemoteCallSession *session, uint64_t image_handle,
                               CYIL2CPPSymbols *out, bool *indeterminate);
#endif

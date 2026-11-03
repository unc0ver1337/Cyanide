#ifndef CY_IL2CPP_SYMBOLS_H
#define CY_IL2CPP_SYMBOLS_H
#import "../../TaskRop/RemoteCall.h"
#include <stdbool.h>
#include <stdint.h>

typedef struct {
    uint64_t domain_get, domain_assembly_open, assembly_get_image;
    uint64_t class_from_name, class_get_method_from_name, class_get_type;
    uint64_t type_get_object, runtime_invoke, string_new, object_unbox;
    uint64_t gchandle_new, gchandle_get_target, gchandle_free;
    uint64_t thread_current, thread_attach, thread_detach;
} CYIL2CPPSymbols;

// The caller supplies a handle for the already-loaded UnityFramework. This
// does not attach to a process or execute an IL2CPP function. On indeterminate
// completion, the caller must not issue further calls or retry automatically.
bool cy_il2cpp_resolve_symbols(RemoteCallSession *session, uint64_t image_handle,
                               CYIL2CPPSymbols *out, bool *indeterminate);
#endif

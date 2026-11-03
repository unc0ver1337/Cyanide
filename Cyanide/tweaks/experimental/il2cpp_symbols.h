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
} CYIL2CPPSymbols;

// Resolve only an already-loaded IL2CPP runtime. Does not attach to a process
// or execute any IL2CPP function. An incomplete table is always discarded.
bool cy_il2cpp_resolve_symbols(RemoteCallSession *session, CYIL2CPPSymbols *out);
#endif

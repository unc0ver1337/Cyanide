#ifndef CY_IL2CPP_MANAGED_CALL_H
#define CY_IL2CPP_MANAGED_CALL_H
#import "il2cpp_rooted_call.h"
#include <stddef.h>

typedef enum { CY_ARGUMENT_REFERENCE, CY_ARGUMENT_VALUE } CYIL2CPPArgumentKind;
typedef struct {
    CYIL2CPPArgumentKind kind;
    uint64_t reference;
    const void *bytes;
    size_t size;
} CYIL2CPPArgument;

// Object references must already be kept alive by the caller for the entire
// operation. Value arguments are copied from local bytes to remote memory.
// A returned nonzero gc_handle belongs to the caller, including on exception.
// In an indeterminate state, no further remote calls or cleanup are safe.
CYIL2CPPCallStatus cy_il2cpp_call_managed(RemoteCallSession *session,
                                          uint64_t runtime_invoke,
                                          uint64_t gc_handle_new,
                                          uint64_t method, uint64_t instance,
                                          const CYIL2CPPArgument *args, size_t count,
                                          bool object_result, CYIL2CPPRootedResult *out);
#endif

#ifndef CY_IL2CPP_ROOTED_CALL_H
#define CY_IL2CPP_ROOTED_CALL_H
#import "il2cpp_main_call.h"

typedef struct {
    uint64_t object;
    uint64_t gc_handle; // Unity 6 GCHandle is pointer-sized.
    uint64_t exception;
} CYIL2CPPRootedResult;

// Experimental, disconnected from QuickLoader. Calls an object-returning
// method and creates a GC handle in the same main-thread callback. Even a
// null object may produce a nonzero handle; caller must release that handle.
// On INDETERMINATE, caller must retain argument storage and make no further
// remote calls until the outstanding operation is resolved independently.
CYIL2CPPCallStatus cy_il2cpp_invoke_rooted_main(RemoteCallSession *session,
                                                uint64_t runtime_invoke,
                                                uint64_t gc_handle_new,
                                                uint64_t method,
                                                uint64_t instance,
                                                uint64_t parameters,
                                                CYIL2CPPRootedResult *out);
#endif

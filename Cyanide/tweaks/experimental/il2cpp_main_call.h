#ifndef CY_IL2CPP_MAIN_CALL_H
#define CY_IL2CPP_MAIN_CALL_H

#import "../../TaskRop/RemoteCall.h"
#include <stdint.h>

// Experimental building block. The caller owns session identity, argument
// storage, exception handling, and the lifetime of all managed objects.
typedef enum {
    CY_IL2CPP_CALL_FAILED = 0,
    CY_IL2CPP_CALL_COMPLETED = 1,
    // Main-thread dispatch began, but its completion cannot be established.
    // Do not free caller-owned argument storage or retry in this state.
    CY_IL2CPP_CALL_INDETERMINATE = 2
} CYIL2CPPCallStatus;

CYIL2CPPCallStatus cy_il2cpp_invoke_main(RemoteCallSession *session,
                                         uint64_t runtimeInvokeAddress,
                                         uint64_t method,
                                         uint64_t instance,
                                         uint64_t parameters,
                                         uint64_t exceptionOut,
                                         uint64_t *result);
#endif

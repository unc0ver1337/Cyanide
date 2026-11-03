#import "il2cpp_main_call.h"
#import "../remote_objc.h"

// NSInvocation copies arguments in setArgument:. The invocation is explicitly
// retained, and remains retained if a dispatched call has an unknown result.
// This file is deliberately not wired to QuickLoader or a process selector.
CYIL2CPPCallStatus cy_il2cpp_invoke_main(RemoteCallSession *session,
                                         uint64_t runtimeInvokeAddress,
                                         uint64_t method,
                                         uint64_t instance,
                                         uint64_t parameters,
                                         uint64_t exceptionOut,
                                         uint64_t *result) {
    if (result) *result = 0;
    if (!session || !runtimeInvokeAddress || !method || !exceptionOut || !result)
        return CY_IL2CPP_CALL_FAILED;

    uint64_t inv = 0, buffer = 0, types = 0;
    CYIL2CPPCallStatus status = CY_IL2CPP_CALL_FAILED;
    static const char encoding[] = "Q^v^v^v^v";
    types = r_session_dlsym_call(session, 100, "malloc", sizeof(encoding), 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    if (!types) goto cleanup;
    if (![session remoteWrite:types from:encoding size:sizeof(encoding)]) {
        status = CY_IL2CPP_CALL_INDETERMINATE;
        goto cleanup;
    }
    uint64_t signatureClass = r_session_class(session, "NSMethodSignature");
    if (!signatureClass) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    uint64_t sig = r_session_msg2(session, signatureClass, "signatureWithObjCTypes:", types, 0, 0, 0);
    if (!r_last_call_ok()) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    if (!sig) goto cleanup;
    uint64_t argCount = r_session_msg2(session, sig, "numberOfArguments", 0, 0, 0, 0);
    if (!r_last_call_ok()) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    if (argCount != 4) goto cleanup;
    uint64_t invocationClass = r_session_class(session, "NSInvocation");
    if (!invocationClass) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    inv = r_session_msg2(session, invocationClass, "invocationWithMethodSignature:", sig, 0, 0, 0);
    if (!r_last_call_ok()) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    if (!inv) goto cleanup;
    inv = r_session_msg2(session, inv, "retain", 0, 0, 0, 0);
    if (!r_last_call_ok()) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    if (!inv) goto cleanup;
    buffer = r_session_dlsym_call(session, 100, "malloc", sizeof(uint64_t), 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    if (!buffer) goto cleanup;
    uint64_t args[4] = { method, instance, parameters, exceptionOut };
    for (uint64_t index = 0; index < 4; ++index) {
        if (![session remoteWrite64:buffer value:args[index]]) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
        r_session_msg2(session, inv, "setArgument:atIndex:", buffer, index, 0, 0);
        if (!r_last_call_ok()) { status = CY_IL2CPP_CALL_INDETERMINATE; goto cleanup; }
    }
    r_session_msg2_main(session, inv, "invokeUsingIMP:", runtimeInvokeAddress, 0, 0, 0);
    if (r_last_main_sent()) status = CY_IL2CPP_CALL_INDETERMINATE;
    if (!r_last_main_ok()) {
        status = CY_IL2CPP_CALL_INDETERMINATE;
        goto cleanup;
    }
    if (![session remoteWrite64:buffer value:0]) goto cleanup;
    r_session_msg2(session, inv, "getReturnValue:", buffer, 0, 0, 0);
    if (!r_last_call_ok() || ![session remoteRead:buffer to:result size:sizeof(*result)]) goto cleanup;
    status = CY_IL2CPP_CALL_COMPLETED;
cleanup:
    // A dispatched invocation or result copy may still be running. Do not
    // issue cleanup IPC or release anything until its state is independently
    // resolved; the caller must also retain its parameter storage.
    if (status == CY_IL2CPP_CALL_INDETERMINATE) return status;
    if (types) { r_session_free(session, types); if (!r_last_call_ok()) return CY_IL2CPP_CALL_INDETERMINATE; }
    if (buffer) {
        r_session_dlsym_call(session, 100, "free", buffer, 0, 0, 0, 0, 0, 0, 0);
        if (!r_last_call_ok()) return CY_IL2CPP_CALL_INDETERMINATE;
    }
    if (inv) {
        r_session_msg2(session, inv, "release", 0, 0, 0, 0);
        if (!r_last_call_ok()) return CY_IL2CPP_CALL_INDETERMINATE;
    }
    return status;
}

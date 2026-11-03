#import "il2cpp_managed_call.h"
#import "../remote_objc.h"
#include <string.h>

typedef struct {
    __unsafe_unretained RemoteCallSession *session;
    uint64_t buffers[6];
    unsigned count;
    bool uncertain;
} ManagedCall;

static uint64_t copy_buffer(ManagedCall *c, const void *data, size_t length) {
    if (c->uncertain || !data || !length || c->count >= 6) return 0;
    uint64_t p = r_session_dlsym_call(c->session, 100, "malloc", length, 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { c->uncertain = true; return 0; }
    if (!p) return 0;
    c->buffers[c->count++] = p;
    if (![c->session remoteWrite:p from:data size:length]) { c->uncertain = true; return 0; }
    return p;
}

static bool free_buffers(ManagedCall *c) {
    if (c->uncertain) return false;
    while (c->count) {
        r_session_dlsym_call(c->session, 100, "free", c->buffers[--c->count],
                             0, 0, 0, 0, 0, 0, 0);
        if (!r_last_call_ok()) { c->uncertain = true; return false; }
    }
    return true;
}

CYIL2CPPCallStatus cy_il2cpp_call_managed(RemoteCallSession *session,
                                          uint64_t runtime_invoke,
                                          uint64_t gc_handle_new,
                                          uint64_t method, uint64_t instance,
                                          const CYIL2CPPArgument *args, size_t count,
                                          bool object_result, CYIL2CPPRootedResult *out) {
    if (out) memset(out, 0, sizeof(*out));
    if (!session || !runtime_invoke || !method || !out || count > 4 || (count && !args) ||
        (object_result && !gc_handle_new)) return CY_IL2CPP_CALL_FAILED;
    for (size_t i = 0; i < count; ++i) {
        if (args[i].kind != CY_ARGUMENT_REFERENCE && args[i].kind != CY_ARGUMENT_VALUE)
            return CY_IL2CPP_CALL_FAILED;
        if (args[i].kind == CY_ARGUMENT_VALUE && (!args[i].bytes || !args[i].size || args[i].size > 32))
            return CY_IL2CPP_CALL_FAILED;
    }
    ManagedCall c = {.session = session};
    uint64_t values[4] = {0}, remoteArgs = 0, exceptionSlot = 0, ignored = 0, zero = 0;
    CYIL2CPPCallStatus status = CY_IL2CPP_CALL_FAILED;
    for (size_t i = 0; i < count; ++i) {
        if (args[i].kind == CY_ARGUMENT_REFERENCE) values[i] = args[i].reference;
        else {
            values[i] = copy_buffer(&c, args[i].bytes, args[i].size);
            if (!values[i]) goto done;
        }
    }
    if (count) {
        remoteArgs = copy_buffer(&c, values, count * sizeof(values[0]));
        if (!remoteArgs) goto done;
    }
    if (object_result) {
        status = cy_il2cpp_invoke_rooted_main(session, runtime_invoke, gc_handle_new,
                                              method, instance, remoteArgs, out);
    } else {
        exceptionSlot = copy_buffer(&c, &zero, sizeof(zero));
        if (!exceptionSlot) goto done;
        status = cy_il2cpp_invoke_main(session, runtime_invoke, method, instance,
                                       remoteArgs, exceptionSlot, &ignored);
        if (status == CY_IL2CPP_CALL_COMPLETED &&
            ![session remoteRead:exceptionSlot to:&out->exception size:sizeof(out->exception)])
            status = CY_IL2CPP_CALL_INDETERMINATE;
    }
    if (status == CY_IL2CPP_CALL_INDETERMINATE) c.uncertain = true;
done:
    if (!free_buffers(&c)) return CY_IL2CPP_CALL_INDETERMINATE;
    return status;
}

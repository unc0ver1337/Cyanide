#import "il2cpp_rooted_call.h"
#import "../remote_objc.h"
#include <string.h>

typedef struct {
    __unsafe_unretained RemoteCallSession *session;
    uint64_t objects[32], buffers[16];
    unsigned object_count, buffer_count;
    uint64_t scratch;
    bool uncertain;
} RootCall;

static uint64_t send(RootCall *c, uint64_t target, const char *selector,
                     uint64_t a, uint64_t b) {
    if (!target || c->uncertain) return 0;
    uint64_t result = r_session_msg2(c->session, target, selector, a, b, 0, 0);
    if (!r_last_call_ok()) c->uncertain = true;
    return result;
}

static uint64_t alloc_buffer(RootCall *c, size_t size) {
    if (c->uncertain || c->buffer_count >= 16) return 0;
    uint64_t p = r_session_dlsym_call(c->session, 100, "malloc", size, 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { c->uncertain = true; return 0; }
    if (p) c->buffers[c->buffer_count++] = p;
    return p;
}

static bool write_bytes(RootCall *c, uint64_t addr, const void *bytes, size_t size) {
    if (c->uncertain || !addr || ![c->session remoteWrite:addr from:bytes size:size]) {
        c->uncertain = true;
        return false;
    }
    return true;
}

static uint64_t keep(RootCall *c, uint64_t obj) {
    if (!obj || c->uncertain || c->object_count >= 32) return 0;
    uint64_t retained = send(c, obj, "retain", 0, 0);
    if (retained && !c->uncertain) c->objects[c->object_count++] = retained;
    return retained;
}

static uint64_t create_invocation(RootCall *c, const char *encoding) {
    size_t size = strlen(encoding) + 1;
    uint64_t str = alloc_buffer(c, size);
    if (!str || !write_bytes(c, str, encoding, size)) return 0;
    uint64_t signatureClass = r_session_class(c->session, "NSMethodSignature");
    if (!signatureClass) { c->uncertain = true; return 0; }
    uint64_t signature = keep(c, send(c, signatureClass, "signatureWithObjCTypes:", str, 0));
    if (!signature) return 0;
    uint64_t invocationClass = r_session_class(c->session, "NSInvocation");
    if (!invocationClass) { c->uncertain = true; return 0; }
    return keep(c, send(c, invocationClass, "invocationWithMethodSignature:", signature, 0));
}

static bool set_arg(RootCall *c, uint64_t invocation, unsigned index, uint64_t value) {
    if (!write_bytes(c, c->scratch, &value, sizeof(value))) return false;
    send(c, invocation, "setArgument:atIndex:", c->scratch, index);
    return !c->uncertain;
}

static uint64_t make_step(RootCall *c, uint64_t target, const char *selector,
                          uint64_t a, uint64_t b, unsigned arguments) {
    if (!target || arguments < 1 || arguments > 2) return 0;
    uint64_t step = create_invocation(c, arguments == 1 ? "v@:^v" : "v@:^vQ");
    uint64_t sel = r_session_sel(c->session, selector);
    if (!step) return 0;
    if (!sel) { c->uncertain = true; return 0; }
    send(c, step, "setTarget:", target, 0);
    send(c, step, "setSelector:", sel, 0);
    if (c->uncertain || !set_arg(c, step, 2, a)) return 0;
    if (arguments == 2 && !set_arg(c, step, 3, b)) return 0;
    send(c, step, "retainArguments", 0, 0);
    return c->uncertain ? 0 : step;
}

static bool cleanup(RootCall *c) {
    if (c->uncertain) return false;
    while (c->object_count) {
        send(c, c->objects[--c->object_count], "release", 0, 0);
        if (c->uncertain) return false;
    }
    while (c->buffer_count) {
        r_session_dlsym_call(c->session, 100, "free", c->buffers[--c->buffer_count],
                             0, 0, 0, 0, 0, 0, 0);
        if (!r_last_call_ok()) { c->uncertain = true; return false; }
    }
    return true;
}

CYIL2CPPCallStatus cy_il2cpp_invoke_rooted_main(RemoteCallSession *session,
                                                uint64_t runtime_invoke,
                                                uint64_t gc_handle_new,
                                                uint64_t method,
                                                uint64_t instance,
                                                uint64_t parameters,
                                                CYIL2CPPRootedResult *out) {
    if (out) memset(out, 0, sizeof(*out));
    if (!session || !runtime_invoke || !gc_handle_new || !method || !out)
        return CY_IL2CPP_CALL_FAILED;
    RootCall c = {.session = session};
    uint64_t inner = 0, root = 0, sequence = 0;
    uint64_t objectSlot = 0, handleSlot = 0, exceptionSlot = 0, invokeSelector = 0;
    uint64_t zero = 0;
    CYIL2CPPCallStatus status = CY_IL2CPP_CALL_FAILED;
    c.scratch = alloc_buffer(&c, sizeof(uint64_t));
    objectSlot = alloc_buffer(&c, sizeof(uint64_t));
    handleSlot = alloc_buffer(&c, sizeof(uint64_t));
    exceptionSlot = alloc_buffer(&c, sizeof(uint64_t));
    if (!c.scratch || !objectSlot || !handleSlot || !exceptionSlot) goto done;
    if (!write_bytes(&c, objectSlot, &zero, sizeof(zero)) ||
        !write_bytes(&c, handleSlot, &zero, sizeof(zero)) ||
        !write_bytes(&c, exceptionSlot, &zero, sizeof(zero))) goto done;
    inner = create_invocation(&c, "Q^v^v^v^v");
    root = create_invocation(&c, "^v^vB");
    if (!inner || !root || !set_arg(&c, inner, 0, method) ||
        !set_arg(&c, inner, 1, instance) || !set_arg(&c, inner, 2, parameters) ||
        !set_arg(&c, inner, 3, exceptionSlot) || !set_arg(&c, root, 1, 1)) goto done;
    uint64_t arrayClass = r_session_class(session, "NSMutableArray");
    if (!arrayClass) { c.uncertain = true; goto done; }
    uint64_t array = send(&c, arrayClass, "alloc", 0, 0);
    sequence = array ? send(&c, array, "init", 0, 0) : 0;
    if (!sequence || c.uncertain || c.object_count >= 32) goto done;
    c.objects[c.object_count++] = sequence; // alloc/init returns an owned object.
    struct { uint64_t target; const char *selector; uint64_t a, b; unsigned n; } steps[] = {
        {inner, "invokeUsingIMP:", runtime_invoke, 0, 1},
        {inner, "getReturnValue:", objectSlot, 0, 1},
        {root, "setArgument:atIndex:", objectSlot, 0, 2},
        {root, "invokeUsingIMP:", gc_handle_new, 0, 1},
        {root, "getReturnValue:", handleSlot, 0, 1}
    };
    for (unsigned i = 0; i < sizeof(steps) / sizeof(steps[0]); ++i) {
        uint64_t item = make_step(&c, steps[i].target, steps[i].selector,
                                  steps[i].a, steps[i].b, steps[i].n);
        if (!item) goto done;
        send(&c, sequence, "addObject:", item, 0);
        if (c.uncertain) goto done;
    }
    invokeSelector = r_session_sel(session, "invoke");
    if (!invokeSelector) { c.uncertain = true; goto done; }
    r_session_msg2_main(session, sequence, "makeObjectsPerformSelector:", invokeSelector, 0, 0, 0);
    if (!r_last_main_ok()) {
        // Even pre-dispatch setup may have timed out during remote IPC.
        c.uncertain = true;
        goto done;
    }
    if (![session remoteRead:objectSlot to:&out->object size:sizeof(out->object)] ||
        ![session remoteRead:handleSlot to:&out->gc_handle size:sizeof(out->gc_handle)] ||
        ![session remoteRead:exceptionSlot to:&out->exception size:sizeof(out->exception)]) {
        c.uncertain = true;
        goto done;
    }
    status = CY_IL2CPP_CALL_COMPLETED;
done:
    if (!cleanup(&c)) return CY_IL2CPP_CALL_INDETERMINATE;
    return status;
}

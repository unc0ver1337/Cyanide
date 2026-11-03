#import "chams_alloc.h"
#import "../remote_objc.h"
#include <string.h>

static CYIL2CPPCallStatus allocate(CYIL2CPPMetadata *ctx, uint64_t fn,
                                   uint64_t first, uint64_t second, unsigned n,
                                   CYIL2CPPRootedResult *out) {
    if (out) memset(out, 0, sizeof(*out));
    if (!ctx || ctx->poisoned || !ctx->session || !ctx->generation ||
        !fn || !ctx->symbols.gchandle_new || !first || !out) return CY_IL2CPP_CALL_FAILED;
    CYIL2CPPCallStatus status = cy_il2cpp_alloc_rooted_main(ctx->session, fn,
                                ctx->symbols.gchandle_new, first, second, n, out);
    if (status == CY_IL2CPP_CALL_INDETERMINATE) ctx->poisoned = true;
    if (status == CY_IL2CPP_CALL_COMPLETED && out->object && !out->gc_handle) {
        // The object may already have moved or been collected. Never use it.
        ctx->poisoned = true;
        return CY_IL2CPP_CALL_INDETERMINATE;
    }
    return status;
}

CYIL2CPPCallStatus cy_chams_new_object(CYIL2CPPMetadata *ctx, uint64_t klass,
                                       CYIL2CPPRootedResult *out) {
    return allocate(ctx, ctx ? ctx->symbols.object_new : 0, klass, 0, 1, out);
}

CYIL2CPPCallStatus cy_chams_new_array(CYIL2CPPMetadata *ctx, uint64_t klass,
                                      size_t count, CYIL2CPPRootedResult *out) {
    if (count > 4096) { if (out) memset(out, 0, sizeof(*out)); return CY_IL2CPP_CALL_FAILED; }
    return allocate(ctx, ctx ? ctx->symbols.array_new : 0, klass, count, 2, out);
}

CYIL2CPPCallStatus cy_chams_new_string(CYIL2CPPMetadata *ctx, const char *utf8,
                                       CYIL2CPPRootedResult *out) {
    if (out) memset(out, 0, sizeof(*out));
    if (!ctx || ctx->poisoned || !ctx->session || !ctx->generation || !utf8 || !out ||
        !ctx->symbols.string_new || !ctx->symbols.gchandle_new) return CY_IL2CPP_CALL_FAILED;
    size_t length = strlen(utf8);
    if (length > 1024) return CY_IL2CPP_CALL_FAILED;
    uint64_t p = r_session_dlsym_call(ctx->session, 100, "malloc", length + 1, 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { ctx->poisoned = true; return CY_IL2CPP_CALL_INDETERMINATE; }
    if (!p) return CY_IL2CPP_CALL_FAILED;
    if (![ctx->session remoteWrite:p from:utf8 size:length + 1]) {
        ctx->poisoned = true; return CY_IL2CPP_CALL_INDETERMINATE;
    }
    CYIL2CPPCallStatus status = allocate(ctx, ctx->symbols.string_new, p, 0, 1, out);
    if (status == CY_IL2CPP_CALL_INDETERMINATE) return status;
    r_session_free(ctx->session, p);
    if (!r_last_call_ok()) { ctx->poisoned = true; return CY_IL2CPP_CALL_INDETERMINATE; }
    return status;
}

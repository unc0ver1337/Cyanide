#import "il2cpp_symbols.h"
#import "../remote_objc.h"
#include <stddef.h>
#include <string.h>

typedef struct { const char *name; size_t offset; } SymbolDescriptor;
#define CY_SYMBOL(member) {"il2cpp_" #member, offsetof(CYIL2CPPSymbols, member)}
static const SymbolDescriptor kSymbols[] = {
    CY_SYMBOL(domain_get), CY_SYMBOL(domain_assembly_open), CY_SYMBOL(assembly_get_image),
    CY_SYMBOL(class_from_name), CY_SYMBOL(class_get_method_from_name), CY_SYMBOL(class_get_type),
    CY_SYMBOL(type_get_object), CY_SYMBOL(runtime_invoke), CY_SYMBOL(string_new),
    CY_SYMBOL(object_unbox), CY_SYMBOL(gchandle_new), CY_SYMBOL(gchandle_get_target),
    CY_SYMBOL(gchandle_free), CY_SYMBOL(thread_current), CY_SYMBOL(thread_attach),
    CY_SYMBOL(thread_detach)
};
#undef CY_SYMBOL

bool cy_il2cpp_resolve_symbols(RemoteCallSession *session, uint64_t image_handle,
                               CYIL2CPPSymbols *out, bool *indeterminate) {
    if (!out || !indeterminate) return false;
    memset(out, 0, sizeof(*out));
    *indeterminate = false;
    if (!session || !image_handle) return false;
    CYIL2CPPSymbols resolved = {0};
    for (size_t i = 0; i < sizeof(kSymbols) / sizeof(kSymbols[0]); ++i) {
        size_t length = strlen(kSymbols[i].name) + 1;
        uint64_t name = r_session_dlsym_call(session, 100, "malloc", length,
                                             0, 0, 0, 0, 0, 0, 0);
        if (!r_last_call_ok()) { *indeterminate = true; return false; }
        if (!name) return false;
        if (![session remoteWrite:name from:kSymbols[i].name size:length]) {
            r_session_free(session, name);
            if (!r_last_call_ok()) *indeterminate = true;
            return false;
        }
        uint64_t address = r_session_dlsym_call(session, 100, "dlsym",
                                                image_handle, name,
                                                0, 0, 0, 0, 0, 0);
        bool completed = r_last_call_ok();
        if (!completed) {
            // dlsym may still be using the remote string. Retain it and stop.
            *indeterminate = true;
            return false;
        }
        r_session_free(session, name);
        if (!r_last_call_ok()) { *indeterminate = true; return false; }
        if (!address) return false;
        *(uint64_t *)((char *)&resolved + kSymbols[i].offset) = address;
    }
    *out = resolved;
    return true;
}

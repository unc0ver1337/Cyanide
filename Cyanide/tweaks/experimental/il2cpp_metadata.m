#import "il2cpp_metadata.h"
#import "../remote_objc.h"
#include <string.h>

static bool current_generation(CYIL2CPPMetadata *c) {
    if (!c || !c->session || c->poisoned || !c->generation) return false;
    __block uint64_t generation = 0;
    remote_call_with_session(c->session, ^{ generation = remote_call_current_process_generation(); });
    return generation == c->generation;
}

static bool call(CYIL2CPPMetadata *c, uint64_t pc, const char *name,
                 uint64_t a, uint64_t b, uint64_t d, uint64_t *out) {
    if (out) *out = 0;
    if (!out || !pc || !current_generation(c)) return false;
    __block uint64_t value = 0;
    __block bool completed = false;
    remote_call_with_session(c->session, ^{
        value = do_remote_call_stable_addr(100, pc, name, a, b, d, 0, 0, 0, 0, 0);
        completed = remote_call_last_call_ok();
    });
    if (!completed) { c->poisoned = true; return false; }
    *out = value;
    return true;
}

static uint64_t make_string(CYIL2CPPMetadata *c, const char *s) {
    if (!s || !current_generation(c)) return 0;
    size_t length = strlen(s);
    if (length > 255) return 0;
    uint64_t p = r_session_dlsym_call(c->session, 100, "malloc", length + 1, 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { c->poisoned = true; return 0; }
    if (!p) return 0;
    if (![c->session remoteWrite:p from:s size:length + 1]) {
        r_session_dlsym_call(c->session, 100, "free", p, 0, 0, 0, 0, 0, 0, 0);
        if (!r_last_call_ok()) c->poisoned = true;
        return 0;
    }
    return p;
}

static void free_string(CYIL2CPPMetadata *c, uint64_t p) {
    if (!p || !current_generation(c)) return;
    r_session_dlsym_call(c->session, 100, "free", p, 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) c->poisoned = true;
}

bool cy_metadata_open(CYIL2CPPMetadata *c, RemoteCallSession *session,
                      const CYIL2CPPSymbols *symbols) {
    if (!c) return false;
    memset(c, 0, sizeof(*c));
    if (!session || !symbols || !symbols->domain_get || !symbols->thread_current ||
        !symbols->thread_attach || !symbols->thread_detach) return false;
    c->session = session;
    c->symbols = *symbols;
    __block uint64_t generation = 0;
    remote_call_with_session(session, ^{ generation = remote_call_current_process_generation(); });
    c->generation = generation;
    if (!call(c, symbols->domain_get, "il2cpp_domain_get", 0, 0, 0, &c->domain) || !c->domain)
        return false;
    if (!call(c, symbols->thread_current, "il2cpp_thread_current", 0, 0, 0, &c->thread)) return false;
    if (!c->thread) {
        if (!call(c, symbols->thread_attach, "il2cpp_thread_attach", c->domain, 0, 0, &c->thread) || !c->thread)
            return false;
        c->attached_by_us = true;
    }
    return true;
}

bool cy_metadata_class(CYIL2CPPMetadata *c, const char *assembly,
                       const char *namespaze, const char *name, uint64_t *result) {
    if (result) *result = 0;
    if (!result || !assembly || !namespaze || !name || !current_generation(c)) return false;
    uint64_t a = 0, ns = 0, n = 0, image = 0, klass = 0, assembly_ptr = 0;
    bool ok = false;
    a = make_string(c, assembly);
    if (!a || !call(c, c->symbols.domain_assembly_open, "il2cpp_domain_assembly_open",
                    c->domain, a, 0, &assembly_ptr) || !assembly_ptr) goto done;
    if (!call(c, c->symbols.assembly_get_image, "il2cpp_assembly_get_image",
              assembly_ptr, 0, 0, &image) || !image) goto done;
    ns = make_string(c, namespaze); n = make_string(c, name);
    if (!ns || !n || !call(c, c->symbols.class_from_name, "il2cpp_class_from_name",
                           image, ns, n, &klass) || !klass) goto done;
    ok = true;
done:
    free_string(c, n); free_string(c, ns); free_string(c, a);
    if (!ok || c->poisoned) return false;
    *result = klass;
    return true;
}

bool cy_metadata_method_candidate(CYIL2CPPMetadata *c, uint64_t klass,
                                  const char *name, int argument_count, uint64_t *result) {
    if (result) *result = 0;
    if (!result || !klass || !name || argument_count < 0 || !current_generation(c)) return false;
    uint64_t remoteName = make_string(c, name), method = 0;
    if (!remoteName) return false;
    bool ok = call(c, c->symbols.class_get_method_from_name, "il2cpp_class_get_method_from_name",
                   klass, remoteName, (uint64_t)argument_count, &method);
    free_string(c, remoteName);
    if (!ok || c->poisoned || !method) return false;
    *result = method;
    return true;
}

bool cy_metadata_close(CYIL2CPPMetadata *c) {
    if (!c || !current_generation(c)) return false;
    uint64_t ignored = 0;
    if (c->attached_by_us &&
        !call(c, c->symbols.thread_detach, "il2cpp_thread_detach", c->thread, 0, 0, &ignored))
        return false;
    memset(c, 0, sizeof(*c));
    return true;
}

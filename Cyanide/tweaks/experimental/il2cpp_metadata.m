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
        // Lost memory access may mean the target/session is gone. Avoid IPC.
        c->poisoned = true;
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

static bool strings_equal(CYIL2CPPMetadata *c, uint64_t a, uint64_t b, bool *equal) {
    if (!a || !b || !equal || !current_generation(c)) return false;
    uint64_t value = r_session_dlsym_call(c->session, 100, "strcmp", a, b, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { c->poisoned = true; return false; }
    *equal = value == 0;
    return true;
}

static bool method_matches(CYIL2CPPMetadata *c, uint64_t method,
                           const uint64_t expected[4], unsigned count, bool *matches) {
    *matches = false;
    uint64_t actual = 0;
    if (!call(c, c->symbols.method_get_param_count, "il2cpp_method_get_param_count",
              method, 0, 0, &actual)) return false;
    if (actual != count) return true;
    for (unsigned i = 0; i < count; ++i) {
        uint64_t type = 0, name = 0, ignored = 0;
        bool equal = false;
        if (!call(c, c->symbols.method_get_param, "il2cpp_method_get_param",
                  method, i, 0, &type) || !type) return false;
        if (!call(c, c->symbols.type_get_name, "il2cpp_type_get_name",
                  type, 0, 0, &name) || !name) return false;
        bool compared = strings_equal(c, name, expected[i], &equal);
        // An unresolved remote call can still reference its arguments.
        if (c->poisoned) return false;
        if (!call(c, c->symbols.free, "il2cpp_free", name, 0, 0, &ignored)) return false;
        if (!compared) return false;
        if (!equal) return true;
    }
    *matches = true;
    return true;
}

bool cy_metadata_method_exact(CYIL2CPPMetadata *c, uint64_t klass, const char *name,
                              const char *const *types, unsigned count, uint64_t *result) {
    if (result) *result = 0;
    if (!result || !klass || !name || count > 4 || (count && !types) || !current_generation(c)) return false;
    uint64_t remoteName = 0, iterator = 0, expected[4] = {0}, found = 0;
    bool ok = false;
    remoteName = make_string(c, name);
    if (!remoteName) goto done;
    for (unsigned i = 0; i < count; ++i) {
        expected[i] = make_string(c, types[i]);
        if (!expected[i]) goto done;
    }
    iterator = r_session_dlsym_call(c->session, 100, "malloc", sizeof(uint64_t), 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) { c->poisoned = true; goto done; }
    if (!iterator) goto done;
    if (![c->session remoteWrite64:iterator value:0]) { c->poisoned = true; goto done; }
    // A fixed upper bound prevents corrupt metadata from causing an endless walk.
    for (unsigned i = 0; i < 2048; ++i) {
        uint64_t method = 0, remoteMethodName = 0;
        bool equal = false, matches = false;
        if (!call(c, c->symbols.class_get_methods, "il2cpp_class_get_methods",
                  klass, iterator, 0, &method)) goto done;
        if (!method) { ok = true; break; }
        if (!call(c, c->symbols.method_get_name, "il2cpp_method_get_name",
                  method, 0, 0, &remoteMethodName) || !remoteMethodName) goto done;
        if (!strings_equal(c, remoteMethodName, remoteName, &equal)) goto done;
        if (!equal) continue;
        if (!method_matches(c, method, expected, count, &matches)) goto done;
        if (matches) { found = method; ok = true; break; }
    }
done:
    free_string(c, iterator);
    for (unsigned i = 0; i < count; ++i) free_string(c, expected[i]);
    free_string(c, remoteName);
    if (!ok || c->poisoned || !found) return false;
    *result = found;
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

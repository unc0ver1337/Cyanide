#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#define RemoteCall_h
#define remote_objc_h
#import "remote_syntax_stubs.h"
#import "../../Cyanide/tweaks/experimental/il2cpp_main_call.m"
#import "../../Cyanide/tweaks/experimental/il2cpp_rooted_call.m"
#import "../../Cyanide/tweaks/experimental/il2cpp_managed_call.m"
#import "../../Cyanide/tweaks/experimental/il2cpp_metadata.m"
#import "../../Cyanide/tweaks/experimental/chams_alloc.m"

// Fake transport executes in this process on the main thread. It exercises
// the production sequence construction and cleanup, not the iOS bridge.
static bool lastOK = true, mainOK = true, mainSent = false, timeoutAfterDispatch = false;
static unsigned allocations = 0, frees = 0;
static uint64_t fakeException = 0;
static bool inspectArguments = false;
static uint64_t failFunction = 0;
static unsigned typeAllocations = 0, typeFrees = 0, releasedHandles = 0;

@interface TestSession : NSObject
@end
@implementation TestSession
- (BOOL)remoteWrite:(uint64_t)dst from:(const void *)src size:(uint64_t)size {
    if (!dst || !src) return NO; memcpy((void *)(uintptr_t)dst, src, (size_t)size); return YES;
}
- (BOOL)remoteWrite64:(uint64_t)dst value:(uint64_t)value {
    return [self remoteWrite:dst from:&value size:sizeof(value)];
}
- (BOOL)remoteRead:(uint64_t)src to:(void *)dst size:(uint64_t)size {
    if (!src || !dst) return NO; memcpy(dst, (void *)(uintptr_t)src, (size_t)size); return YES;
}
@end

uint64_t r_session_class(RemoteCallSession *s, const char *name) {
    (void)s; lastOK = true; return (uint64_t)(uintptr_t)objc_getClass(name);
}
uint64_t r_session_sel(RemoteCallSession *s, const char *name) {
    (void)s; lastOK = true;
    SEL selector = sel_registerName(name);
    uint64_t bits = 0;
    _Static_assert(sizeof(selector) == sizeof(bits), "selector width mismatch");
    memcpy(&bits, &selector, sizeof(bits));
    return bits;
}
uint64_t r_session_msg2(RemoteCallSession *s, uint64_t target, const char *name,
                        uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
    (void)s; lastOK = true;
    typedef uint64_t (*Send)(id, SEL, uint64_t, uint64_t, uint64_t, uint64_t);
    return ((Send)objc_msgSend)((__bridge id)(void *)(uintptr_t)target, sel_registerName(name), a, b, c, d);
}
uint64_t r_session_msg2_main(RemoteCallSession *s, uint64_t target, const char *name,
                             uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
    mainSent = true;
    uint64_t value = r_session_msg2(s, target, name, a, b, c, d);
    mainOK = !timeoutAfterDispatch;
    return value;
}
uint64_t r_session_dlsym_call(RemoteCallSession *s, int timeout, const char *name,
                              uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                              uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    (void)s; (void)timeout; (void)b; (void)c; (void)d; (void)e; (void)f; (void)g; (void)h;
    lastOK = true;
    if (!strcmp(name, "malloc")) { ++allocations; return (uint64_t)(uintptr_t)malloc((size_t)a); }
    if (!strcmp(name, "free")) { ++frees; free((void *)(uintptr_t)a); return 0; }
    if (!strcmp(name, "strcmp")) return (uint64_t)(int64_t)strcmp((char *)(uintptr_t)a, (char *)(uintptr_t)b);
    lastOK = false; return 0;
}
void r_session_free(RemoteCallSession *s, uint64_t p) {
    (void)r_session_dlsym_call(s, 100, "free", p, 0, 0, 0, 0, 0, 0, 0);
}
bool r_last_call_ok(void) { return lastOK; }
bool r_last_main_ok(void) { return mainOK; }
bool r_last_main_sent(void) { return mainSent; }
void remote_call_with_session(RemoteCallSession *s, void (^block)(void)) { (void)s; block(); }
uint64_t remote_call_current_process_generation(void) { return 42; }
bool remote_call_last_call_ok(void) { return lastOK; }
uint64_t do_remote_call_stable_addr(int timeout, uint64_t pc, const char *name,
                                    uint64_t a, uint64_t b, uint64_t c, uint64_t d,
                                    uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    (void)timeout; (void)name; (void)d; (void)e; (void)f; (void)g; (void)h;
    if (pc == failFunction) { lastOK = false; return 0; }
    lastOK = true;
    typedef uint64_t (*Fn)(uint64_t, uint64_t, uint64_t);
    return ((Fn)(uintptr_t)pc)(a,b,c);
}

typedef struct { const char *name, *returnType, *parameter; } FakeMethod;
static const FakeMethod methods[] = {
    {"SetColor", "System.Void", "System.Int32"},
    {"SetColor", "System.Boolean", "System.String"},
    {"SetColor", "System.Void", "System.String"}
};
static uint64_t fake_methods(uint64_t klass, uint64_t iter, uint64_t unused) {
    (void)unused; assert(klass == 0x123 && iter);
    uint64_t *index = (uint64_t *)(uintptr_t)iter;
    if (*index >= sizeof(methods)/sizeof(methods[0])) return 0;
    return (uint64_t)(uintptr_t)&methods[(*index)++];
}
static uint64_t fake_method_name(uint64_t method, uint64_t b, uint64_t c) {
    (void)b; (void)c; return (uint64_t)(uintptr_t)((const FakeMethod *)(uintptr_t)method)->name;
}
static uint64_t fake_count(uint64_t method, uint64_t b, uint64_t c) { (void)method; (void)b; (void)c; return 1; }
static uint64_t fake_parameter(uint64_t method, uint64_t index, uint64_t c) {
    (void)c; assert(index == 0); return (uint64_t)(uintptr_t)((const FakeMethod *)(uintptr_t)method)->parameter;
}
static uint64_t fake_return(uint64_t method, uint64_t b, uint64_t c) {
    (void)b; (void)c; return (uint64_t)(uintptr_t)((const FakeMethod *)(uintptr_t)method)->returnType;
}
static uint64_t fake_type_name(uint64_t type, uint64_t b, uint64_t c) {
    (void)b; (void)c; ++typeAllocations; return (uint64_t)(uintptr_t)strdup((char *)(uintptr_t)type);
}
static uint64_t fake_type_free(uint64_t type, uint64_t b, uint64_t c) {
    (void)b; (void)c; ++typeFrees; free((void *)(uintptr_t)type); return 0;
}
static uint64_t fake_target(uint64_t handle, uint64_t b, uint64_t c) { (void)b; (void)c; return handle; }
static uint64_t fake_unbox(uint64_t object, uint64_t b, uint64_t c) { (void)b; (void)c; return object; }
static uint64_t fake_handle_free(uint64_t handle, uint64_t b, uint64_t c) {
    (void)b; (void)c; assert(handle); ++releasedHandles; return 0;
}
#define PTR(fn) ((uint64_t)(uintptr_t)&fn)

static uintptr_t fake_invoke(uintptr_t method, uintptr_t object, uintptr_t params, uintptr_t exception) {
    assert([NSThread isMainThread] && method == 0x11);
    if (inspectArguments) {
        uint64_t *values = (uint64_t *)params;
        assert(values && values[0] == 0x44 && values[1]);
        const float *color = (const float *)(uintptr_t)values[1];
        assert(color[0] == 1 && color[1] == 0 && color[2] == 0 && color[3] == 1);
    } else assert(params == 0x33);
    *(uint64_t *)exception = fakeException;
    return object;
}
static uintptr_t fake_root(uintptr_t object, bool pinned) {
    assert([NSThread isMainThread] && pinned);
    return object ? UINT64_C(0x123456789a) : UINT64_C(0x123456789b);
}
static uintptr_t fake_alloc_one(uintptr_t klass) {
    assert([NSThread isMainThread] && klass == 0x55); return 0x22;
}
static uintptr_t fake_alloc_two(uintptr_t klass, uintptr_t size) {
    assert([NSThread isMainThread] && klass == 0x55 && size == 3); return 0x22;
}
static uintptr_t fake_alloc_string(const char *text) {
    assert([NSThread isMainThread] && !strcmp(text, "_Color")); return 0x22;
}
int main(void) {
    @autoreleasepool {
        TestSession *local = [TestSession new];
        RemoteCallSession *session = (RemoteCallSession *)local;
        CYIL2CPPRootedResult out = {0};
        uint64_t invoke = (uint64_t)(uintptr_t)&fake_invoke, root = (uint64_t)(uintptr_t)&fake_root;
        assert(cy_il2cpp_invoke_rooted_main(session, invoke, root, 0x11, 0x22, 0x33, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0x22 && out.gc_handle == UINT64_C(0x123456789a) && out.exception == 0);
        assert(allocations == frees);
        assert(cy_il2cpp_alloc_rooted_main(session, PTR(fake_alloc_one), root, 0x55, 0, 1, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0x22 && out.gc_handle == UINT64_C(0x123456789a) && out.exception == 0);
        assert(cy_il2cpp_alloc_rooted_main(session, PTR(fake_alloc_two), root, 0x55, 3, 2, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0x22 && out.gc_handle == UINT64_C(0x123456789a) && allocations == frees);
        assert(cy_il2cpp_alloc_rooted_main(session, PTR(fake_alloc_one), root, 0x55, 0, 3, &out) == CY_IL2CPP_CALL_FAILED);
        CYIL2CPPMetadata allocMetadata = {.session = session, .generation = 42};
        allocMetadata.symbols.gchandle_new = root;
        allocMetadata.symbols.object_new = PTR(fake_alloc_one);
        allocMetadata.symbols.array_new = PTR(fake_alloc_two);
        allocMetadata.symbols.string_new = PTR(fake_alloc_string);
        assert(cy_chams_new_object(&allocMetadata, 0x55, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0x22 && out.gc_handle == UINT64_C(0x123456789a));
        assert(cy_chams_new_array(&allocMetadata, 0x55, 3, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(cy_chams_new_array(&allocMetadata, 0x55, 4097, &out) == CY_IL2CPP_CALL_FAILED);
        assert(cy_chams_new_string(&allocMetadata, "_Color", &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0x22 && out.gc_handle == UINT64_C(0x123456789a) && allocations == frees);
        fakeException = 0x44;
        assert(cy_il2cpp_invoke_rooted_main(session, invoke, root, 0x11, 0, 0x33, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0 && out.gc_handle == 0 && out.exception == 0x44);
        assert(allocations == frees);
        float red[4] = {1,0,0,1};
        CYIL2CPPArgument args[2] = {
            {.kind = CY_ARGUMENT_REFERENCE, .reference = 0x44},
            {.kind = CY_ARGUMENT_VALUE, .bytes = red, .size = sizeof(red)}
        };
        inspectArguments = true; fakeException = 0;
        assert(cy_il2cpp_call_managed(session, invoke, root, 0x11, 0x22, args, 2, true, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0x22 && out.gc_handle == UINT64_C(0x123456789a) && out.exception == 0);
        assert(allocations == frees);
        fakeException = 0x44;
        assert(cy_il2cpp_call_managed(session, invoke, root, 0x11, 0x22, args, 2, false, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.gc_handle == 0 && out.exception == 0x44 && allocations == frees);
        args[1].size = 33;
        assert(cy_il2cpp_call_managed(session, invoke, root, 0x11, 0x22, args, 2, false, &out) == CY_IL2CPP_CALL_FAILED);
        assert(allocations == frees);
        args[1].size = sizeof(red); fakeException = 0;

        CYIL2CPPMetadata metadata = {.session = session, .generation = 42};
        metadata.symbols.class_get_methods = PTR(fake_methods);
        metadata.symbols.method_get_name = PTR(fake_method_name);
        metadata.symbols.method_get_param_count = PTR(fake_count);
        metadata.symbols.method_get_param = PTR(fake_parameter);
        metadata.symbols.method_get_return_type = PTR(fake_return);
        metadata.symbols.type_get_name = PTR(fake_type_name);
        metadata.symbols.free = PTR(fake_type_free);
        metadata.symbols.gchandle_get_target = PTR(fake_target);
        metadata.symbols.object_unbox = PTR(fake_unbox);
        metadata.symbols.gchandle_free = PTR(fake_handle_free);
        const char *types[] = {"System.String"};
        uint64_t method = 0;
        assert(cy_metadata_method_exact(&metadata, 0x123, "SetColor", "System.Void", types, 1, &method));
        assert(method == (uint64_t)(uintptr_t)&methods[2]);
        assert(typeAllocations == typeFrees && allocations == frees);
        assert(!cy_metadata_method_exact(&metadata, 0x123, "Missing", "System.Void", types, 1, &method));
        assert(method == 0 && typeAllocations == typeFrees && allocations == frees);
        uint32_t boxed = 0x76543210, unboxed = 0;
        assert(cy_metadata_unbox(&metadata, (uint64_t)(uintptr_t)&boxed, &unboxed, sizeof(unboxed)));
        assert(unboxed == boxed && cy_metadata_handle_free(&metadata, (uint64_t)(uintptr_t)&boxed));
        assert(releasedHandles == 1);

        failFunction = PTR(fake_method_name);
        unsigned previousMetadataFrees = frees;
        assert(!cy_metadata_method_exact(&metadata, 0x123, "SetColor", "System.Void", types, 1, &method));
        assert(metadata.poisoned && frees == previousMetadataFrees);
        failFunction = 0;
        timeoutAfterDispatch = true;
        unsigned previousFrees = frees;
        assert(cy_il2cpp_call_managed(session, invoke, root, 0x11, 0x22, args, 2, true, &out) == CY_IL2CPP_CALL_INDETERMINATE);
        assert(frees == previousFrees); // Pending target state must not be freed.
        puts("Rooted invocation construction and cleanup passed (local mock transport).");
    }
    return 0;
}

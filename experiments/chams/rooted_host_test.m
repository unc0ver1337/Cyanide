#import <Foundation/Foundation.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <assert.h>
#include <stdlib.h>
#include <string.h>
#define RemoteCall_h
#define remote_objc_h
#import "remote_syntax_stubs.h"
#import "../../Cyanide/tweaks/experimental/il2cpp_rooted_call.m"

// Fake transport executes in this process on the main thread. It exercises
// the production sequence construction and cleanup, not the iOS bridge.
static bool lastOK = true, mainOK = true, mainSent = false, timeoutAfterDispatch = false;
static unsigned allocations = 0, frees = 0;
static uint64_t fakeException = 0;

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
    lastOK = false; return 0;
}
bool r_last_call_ok(void) { return lastOK; }
bool r_last_main_ok(void) { return mainOK; }
bool r_last_main_sent(void) { return mainSent; }

static uintptr_t fake_invoke(uintptr_t method, uintptr_t object, uintptr_t params, uintptr_t exception) {
    assert([NSThread isMainThread] && method == 0x11 && params == 0x33);
    *(uint64_t *)exception = fakeException;
    return object;
}
static uintptr_t fake_root(uintptr_t object, bool pinned) {
    assert([NSThread isMainThread] && !pinned);
    return object ? UINT64_C(0x123456789a) : UINT64_C(0x123456789b);
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
        fakeException = 0x44;
        assert(cy_il2cpp_invoke_rooted_main(session, invoke, root, 0x11, 0, 0x33, &out) == CY_IL2CPP_CALL_COMPLETED);
        assert(out.object == 0 && out.gc_handle == UINT64_C(0x123456789b) && out.exception == 0x44);
        assert(allocations == frees);
        timeoutAfterDispatch = true;
        unsigned previousFrees = frees;
        assert(cy_il2cpp_invoke_rooted_main(session, invoke, root, 0x11, 0x22, 0x33, &out) == CY_IL2CPP_CALL_INDETERMINATE);
        assert(frees == previousFrees); // Pending target state must not be freed.
        puts("Rooted invocation construction and cleanup passed (local mock transport).");
    }
    return 0;
}

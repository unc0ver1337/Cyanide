#import <Foundation/Foundation.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

// Host-only proof of calling a four-argument C function through NSInvocation.
// No target process, game, or RemoteCall is involved.
@interface NSInvocation (CYInvokeUsingIMP)
- (void)invokeUsingIMP:(IMP)implementation;
@end

static uintptr_t combine(uintptr_t a, uintptr_t b, uintptr_t c, uintptr_t d) {
    if (![NSThread isMainThread]) return 0;
    return a + 3 * b + 5 * c + 7 * d;
}

static uintptr_t root_object(uintptr_t object, bool pinned) {
    if (![NSThread isMainThread] || !pinned || object != 268) return 0;
    return UINT64_C(0x123456789a);
}

static NSInvocation *step(id target, SEL selector, const void *arg0, const void *arg1) {
    NSMethodSignature *signature = [target methodSignatureForSelector:selector];
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:signature];
    inv.target = target;
    inv.selector = selector;
    if (arg0) [inv setArgument:(void *)arg0 atIndex:2];
    if (arg1) [inv setArgument:(void *)arg1 atIndex:3];
    [inv retainArguments];
    return inv;
}

int main(void) {
    @autoreleasepool {
        NSMethodSignature *sig = [NSMethodSignature signatureWithObjCTypes:"Q^v^v^v^v"];
        if (!sig || sig.numberOfArguments != 4) return 1;
        NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
        uintptr_t args[] = {11, 13, 17, 19};
        for (NSUInteger i = 0; i < 4; ++i) [inv setArgument:&args[i] atIndex:i];
        [inv invokeUsingIMP:(IMP)combine];
        uintptr_t result = 0;
        [inv getReturnValue:&result];
        uintptr_t expected = combine(args[0], args[1], args[2], args[3]);
        if (result != expected) {
            fprintf(stderr, "mismatch: %lu != %lu\n", (unsigned long)result,
                    (unsigned long)expected);
            return 2;
        }
        // A single main-thread callback must invoke the method, copy its
        // returned pointer, and root it before Unity can run another frame.
        NSMethodSignature *rootSig = [NSMethodSignature signatureWithObjCTypes:"^v^vB"];
        NSInvocation *root = [NSInvocation invocationWithMethodSignature:rootSig];
        bool pinned = true;
        [root setArgument:&pinned atIndex:1];
        uintptr_t object = 0;
        uintptr_t handle = 0;
        void *objectOut = &object, *objectIn = &object, *handleOut = &handle;
        NSUInteger firstArgument = 0;
        IMP invokeFunction = (IMP)combine, rootFunction = (IMP)root_object;
        NSArray<NSInvocation *> *sequence = @[
            step(inv, @selector(invokeUsingIMP:), &invokeFunction, NULL),
            step(inv, @selector(getReturnValue:), &objectOut, NULL),
            step(root, @selector(setArgument:atIndex:), &objectIn, &firstArgument),
            step(root, @selector(invokeUsingIMP:), &rootFunction, NULL),
            step(root, @selector(getReturnValue:), &handleOut, NULL)
        ];
        [sequence makeObjectsPerformSelector:@selector(invoke)];
        if (object != expected || handle != UINT64_C(0x123456789a)) {
            fprintf(stderr, "root sequence failed: %lu %lu\n", (unsigned long)object, (unsigned long)handle);
            return 3;
        }
        puts("Host invocation passed; this does not test RemoteCall or a game.");
    }
    return 0;
}

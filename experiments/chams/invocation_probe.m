#import <Foundation/Foundation.h>
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
        puts("Host invocation passed; this does not test RemoteCall or a game.");
    }
    return 0;
}

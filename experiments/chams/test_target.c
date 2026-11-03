#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define RemoteCall_h
#define remote_objc_h
#define R_TIMEOUT 5
static bool callOK = true, noHandle = false, failPid = false;
static int releaseCount = 0, freeCount = 0;
static void *scratchBlock;
static const uint64_t bundle = UINT64_C(0x100000101), predicateClass = UINT64_C(0x100000102);
static const uint64_t handleClass = UINT64_C(0x100000103), predicate = UINT64_C(0x100000104);
static const uint64_t handle = UINT64_C(0x100000105);
bool r_last_call_ok(void) { return callOK; }
bool r_is_objc_ptr(uint64_t value) { return value >= UINT64_C(0x100000000); }
bool remote_write(uint64_t dst, const void *src, uint64_t count) {
    if (!dst || !src) return false;
    memcpy((void *)(uintptr_t)dst, src, (size_t)count); return true;
}
uint64_t r_class(const char *name) {
    callOK = true;
    return !strcmp(name,"RBSProcessPredicate") ? predicateClass :
           !strcmp(name,"RBSProcessHandle") ? handleClass : 0;
}
uint64_t r_dlsym_call(int timeout, const char *name, uint64_t a, uint64_t b,
                      uint64_t c, uint64_t d, uint64_t e, uint64_t f, uint64_t g, uint64_t h) {
    (void)timeout; (void)d; (void)e; (void)f; (void)g; (void)h; callOK = true;
    if (!strcmp(name,"malloc")) { scratchBlock = malloc((size_t)a); return (uint64_t)(uintptr_t)scratchBlock; }
    if (!strcmp(name,"CFStringCreateWithCString")) {
        assert(a == 0 && c == 0x08000100 && !strcmp((char *)(uintptr_t)b,"com.axlebolt.standoff2"));
        return bundle;
    }
    if (!strcmp(name,"CFRelease")) { assert(a == bundle); ++releaseCount; return 0; }
    if (!strcmp(name,"free")) { assert((void *)(uintptr_t)a == scratchBlock); free(scratchBlock); scratchBlock = NULL; ++freeCount; return 0; }
    callOK = false; return 0;
}
uint64_t r_msg2(uint64_t target, const char *selector, uint64_t a, uint64_t b, uint64_t c, uint64_t d) {
    (void)b; (void)c; (void)d; callOK = true;
    if (!strcmp(selector,"predicateMatchingBundleIdentifier:")) { assert(target == predicateClass && a == bundle); return predicate; }
    if (!strcmp(selector,"handleForPredicate:error:")) { assert(target == handleClass && a == predicate); return noHandle ? 0 : handle; }
    if (!strcmp(selector,"retain")) return target;
    if (!strcmp(selector,"release")) { ++releaseCount; return 0; }
    if (!strcmp(selector,"rbs_pid")) { assert(target == handle); if (failPid) { callOK = false; return 0; } return 4321; }
    callOK = false; return 0;
}
#include "../../Cyanide/tweaks/experimental/chams_target.m"
int main(void) {
    int pid = -1;
    assert(cy_chams_find_running_pid(&pid) == CY_TARGET_FOUND && pid == 4321);
    assert(releaseCount == 3 && freeCount == 1);
    noHandle = true;
    assert(cy_chams_find_running_pid(&pid) == CY_TARGET_UNAVAILABLE && pid == 0);
    assert(releaseCount == 5 && freeCount == 2);
    noHandle = false; failPid = true;
    assert(cy_chams_find_running_pid(&pid) == CY_TARGET_INDETERMINATE && pid == 0);
    assert(releaseCount == 5 && freeCount == 2); // No IPC cleanup after timeout.
    free(scratchBlock); // Test-only local cleanup of the deliberately leaked buffer.
    puts("Bundle PID query passed (mock SpringBoard calls only).");
    return 0;
}

#import "chams_target.h"
#import "../remote_objc.h"
#import "../../TaskRop/RemoteCall.h"

CYTargetStatus cy_chams_find_running_pid(int *pid) {
    if (pid) *pid = 0;
    if (!pid) return CY_TARGET_UNAVAILABLE;
    static const char bundleID[] = "com.axlebolt.standoff2";
    uint64_t scratch = 0, bundle = 0, predicate = 0, handle = 0;
    CYTargetStatus status = CY_TARGET_UNAVAILABLE;
    int candidate = 0;
    scratch = r_dlsym_call(R_TIMEOUT, "malloc", sizeof(bundleID), 0, 0, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE;
    if (!scratch) return status;
    if (!remote_write(scratch, bundleID, sizeof(bundleID))) return CY_TARGET_INDETERMINATE;
    bundle = r_dlsym_call(R_TIMEOUT, "CFStringCreateWithCString", 0, scratch,
                          0x08000100, 0, 0, 0, 0, 0);
    if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE;
    if (!r_is_objc_ptr(bundle)) goto cleanup;
    uint64_t predicateClass = r_class("RBSProcessPredicate");
    if (!r_is_objc_ptr(predicateClass)) return CY_TARGET_INDETERMINATE;
    uint64_t handleClass = r_class("RBSProcessHandle");
    if (!r_is_objc_ptr(handleClass)) return CY_TARGET_INDETERMINATE;
    predicate = r_msg2(predicateClass, "predicateMatchingBundleIdentifier:", bundle, 0, 0, 0);
    if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE;
    if (!r_is_objc_ptr(predicate)) { predicate = 0; goto cleanup; }
    predicate = r_msg2(predicate, "retain", 0, 0, 0, 0);
    if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE;
    if (!r_is_objc_ptr(predicate)) { predicate = 0; goto cleanup; }
    handle = r_msg2(handleClass, "handleForPredicate:error:", predicate, 0, 0, 0);
    if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE;
    if (!r_is_objc_ptr(handle)) { handle = 0; goto cleanup; }
    handle = r_msg2(handle, "retain", 0, 0, 0, 0);
    if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE;
    if (!r_is_objc_ptr(handle)) { handle = 0; goto cleanup; }
    uint64_t value = r_msg2(handle, "rbs_pid", 0, 0, 0, 0);
    if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE;
    value &= 0xffffffffULL;
    if (value > 1 && value <= 0x7fffffffULL) { candidate = (int)value; status = CY_TARGET_FOUND; }
cleanup:
    if (handle) { r_msg2(handle, "release", 0, 0, 0, 0); if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE; }
    if (predicate) { r_msg2(predicate, "release", 0, 0, 0, 0); if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE; }
    if (bundle) { r_dlsym_call(R_TIMEOUT, "CFRelease", bundle, 0, 0, 0, 0, 0, 0, 0); if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE; }
    if (scratch) { r_dlsym_call(R_TIMEOUT, "free", scratch, 0, 0, 0, 0, 0, 0, 0); if (!r_last_call_ok()) return CY_TARGET_INDETERMINATE; }
    *pid = candidate;
    return status;
}

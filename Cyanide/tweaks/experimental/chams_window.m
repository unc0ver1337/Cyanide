#import "chams_window.h"
#import "../remote_objc.h"
#import "../../TaskRop/RemoteCall.h"
#include <string.h>

typedef struct { double x, y, width, height; } CYRect;

static bool current(CYChamsWindow *s) {
    return s && !s->uncertain && s->generation &&
           remote_call_current_process_generation() == s->generation;
}
static uint64_t send_main(CYChamsWindow *s, uint64_t target, const char *sel,
                          uint64_t a, uint64_t b) {
    if (!current(s) || !r_is_objc_ptr(target)) return 0;
    uint64_t value = r_msg2_main(target, sel, a, b, 0, 0);
    if (!r_last_main_ok()) s->uncertain = true;
    return value;
}
static bool send_raw(CYChamsWindow *s, uint64_t target, const char *sel,
                     const void *value, size_t size) {
    if (!current(s) || !r_is_objc_ptr(target)) return false;
    r_msg2_main_raw(target, sel, value, size, NULL, 0, NULL, 0, NULL, 0);
    if (!r_last_main_ok()) { s->uncertain = true; return false; }
    return true;
}
static bool layout(CYChamsWindow *s, bool expanded) {
    uint64_t space = send_main(s, s->scene, "coordinateSpace", 0, 0);
    if (!r_is_objc_ptr(space)) return false;
    CYRect bounds = {0};
    bool ok = r_msg2_main_struct_ret(space, "bounds", &bounds, sizeof(bounds),
                                     NULL, 0, NULL, 0, NULL, 0, NULL, 0);
    if (!ok) { s->uncertain = true; return false; }
    if (!(bounds.width >= 240 && bounds.width <= 2000 &&
          bounds.height >= 240 && bounds.height <= 2000)) return false;
    double width = expanded ? 300 : 64, height = expanded ? 340 : 44;
    CYRect frame = {bounds.x + (bounds.width - width) / 2,
                    bounds.y + (bounds.height - height) / 2, width, height};
    if (!send_raw(s, s->window, "setFrame:", &frame, sizeof(frame))) return false;
    s->expanded = expanded;
    return true;
}

CYWindowStatus cy_chams_window_open(CYChamsWindow *s) {
    if (!s || s->window || s->uncertain) return CY_WINDOW_FAILED;
    memset(s, 0, sizeof(*s));
    s->generation = remote_call_current_process_generation();
    if (!s->generation) return CY_WINDOW_FAILED;
    uint64_t appClass = r_class("UIApplication");
    if (!r_is_objc_ptr(appClass)) { s->uncertain = true; return CY_WINDOW_INDETERMINATE; }
    uint64_t app = send_main(s, appClass, "sharedApplication", 0, 0);
    uint64_t keyWindow = send_main(s, app, "keyWindow", 0, 0);
    s->scene = r_is_objc_ptr(keyWindow) ? send_main(s, keyWindow, "windowScene", 0, 0) : 0;
    if (!r_is_objc_ptr(s->scene) && !s->uncertain) {
        uint64_t scenes=send_main(s,app,"connectedScenes",0,0);
        uint64_t sceneArray=send_main(s,scenes,"allObjects",0,0);
        uint64_t sceneCount=send_main(s,sceneArray,"count",0,0);
        if (!s->uncertain && sceneCount>0 && sceneCount<64) {
            for (uint64_t i=0;i<sceneCount;i++) {
                uint64_t candidate=send_main(s,sceneArray,"objectAtIndex:",i,0);
                uint64_t active=send_main(s,candidate,"activationState",0,0);
                // Prefer an active scene; otherwise keep the first valid scene
                // as a fallback for SpringBoard while another app is frontmost.
                if (r_is_objc_ptr(candidate) && !r_is_objc_ptr(s->scene)) s->scene=candidate;
                if (r_is_objc_ptr(candidate) && active==0) { s->scene=candidate; break; }
                if (s->uncertain) break;
            }
        }
    }
    if (s->uncertain) return CY_WINDOW_INDETERMINATE;
    if (!r_is_objc_ptr(s->scene)) return CY_WINDOW_FAILED;
    uint64_t windowClass = r_class("UIWindow");
    if (!r_is_objc_ptr(windowClass)) { s->uncertain = true; return CY_WINDOW_INDETERMINATE; }
    s->window = send_main(s, windowClass, "alloc", 0, 0);
    if (s->uncertain) return CY_WINDOW_INDETERMINATE;
    if (!r_is_objc_ptr(s->window)) return CY_WINDOW_FAILED;
    uint64_t initialized = send_main(s, s->window, "initWithWindowScene:", s->scene, 0);
    if (s->uncertain) return CY_WINDOW_INDETERMINATE;
    if (!r_is_objc_ptr(initialized)) { s->window = 0; return CY_WINDOW_FAILED; }
    s->window = initialized;
    uint64_t colorClass = r_class("UIColor");
    if (!r_is_objc_ptr(colorClass)) { s->uncertain = true; return CY_WINDOW_INDETERMINATE; }
    uint64_t clear = send_main(s, colorClass, "clearColor", 0, 0);
    if (!r_is_objc_ptr(clear)) return s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_FAILED;
    send_main(s, s->window, "setBackgroundColor:", clear, 0);
    send_main(s, s->window, "setUserInteractionEnabled:", 1, 0);
    send_main(s, s->window, "setAutoresizingMask:", 18, 0); // flexible width | height
    double level = 999999.0;
    if (s->uncertain || !send_raw(s, s->window, "setWindowLevel:", &level, sizeof(level)) ||
        !layout(s, true)) return s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_FAILED;
    send_main(s, s->window, "setHidden:", 0, 0);
    return s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_OK;
}

CYWindowStatus cy_chams_window_expand(CYChamsWindow *s, bool expanded) {
    if (!current(s) || !r_is_objc_ptr(s->window))
        return s && s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_FAILED;
    if (s->expanded == expanded) return CY_WINDOW_OK;
    if (!layout(s, expanded)) return s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_FAILED;
    return CY_WINDOW_OK;
}

CYWindowStatus cy_chams_window_refresh(CYChamsWindow *s) {
    if (!current(s) || !r_is_objc_ptr(s->window))
        return s && s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_FAILED;
    if (!layout(s,s->expanded)) return s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_FAILED;
    return CY_WINDOW_OK;
}

CYWindowStatus cy_chams_window_close(CYChamsWindow *s) {
    if (!current(s) || !r_is_objc_ptr(s->window))
        return s && s->uncertain ? CY_WINDOW_INDETERMINATE : CY_WINDOW_FAILED;
    send_main(s, s->window, "setHidden:", 1, 0);
    if (s->uncertain) return CY_WINDOW_INDETERMINATE;
    send_main(s, s->window, "release", 0, 0);
    if (s->uncertain) return CY_WINDOW_INDETERMINATE;
    memset(s, 0, sizeof(*s));
    return CY_WINDOW_OK;
}

// Syntax-check substitutes only; not linked, shipped, or used by the app.
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#ifndef YES
typedef signed char BOOL;
#define YES ((BOOL)1)
#define NO ((BOOL)0)
#endif
@interface RemoteCallSession
- (BOOL)remoteWrite64:(uint64_t)dst value:(uint64_t)value;
- (BOOL)remoteWrite:(uint64_t)dst from:(const void *)src size:(uint64_t)size;
- (BOOL)remoteRead:(uint64_t)src to:(void *)dst size:(uint64_t)size;
@end
uint64_t r_session_alloc_str(RemoteCallSession *, const char *);
void r_session_free(RemoteCallSession *, uint64_t);
uint64_t r_session_class(RemoteCallSession *, const char *);
uint64_t r_session_sel(RemoteCallSession *, const char *);
uint64_t r_session_msg2(RemoteCallSession *, uint64_t, const char *, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t r_session_msg2_main(RemoteCallSession *, uint64_t, const char *, uint64_t, uint64_t, uint64_t, uint64_t);
uint64_t r_session_dlsym_call(RemoteCallSession *, int, const char *, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);
bool r_last_call_ok(void);
bool r_last_main_ok(void);
bool r_last_main_sent(void);
void remote_call_with_session(RemoteCallSession *, void (^)(void));
uint64_t remote_call_current_process_generation(void);
bool remote_call_last_call_ok(void);
uint64_t do_remote_call_stable_addr(int, uint64_t, const char *, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t, uint64_t);

#ifndef CY_CHAMS_ALLOC_H
#define CY_CHAMS_ALLOC_H
#import "il2cpp_metadata.h"
#import "il2cpp_rooted_call.h"

// Caller serializes the verified live game session. Any returned handle is
// owned by the caller, including if a later cleanup operation fails.
// On INDETERMINATE the metadata context is poisoned and no more IPC is safe.
CYIL2CPPCallStatus cy_chams_new_string(CYIL2CPPMetadata *ctx, const char *utf8,
                                        CYIL2CPPRootedResult *out);
CYIL2CPPCallStatus cy_chams_new_object(CYIL2CPPMetadata *ctx, uint64_t klass,
                                        CYIL2CPPRootedResult *out);
CYIL2CPPCallStatus cy_chams_new_array(CYIL2CPPMetadata *ctx, uint64_t element_class,
                                       size_t count, CYIL2CPPRootedResult *out);
#endif

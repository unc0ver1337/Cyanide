#ifndef CY_IL2CPP_METADATA_H
#define CY_IL2CPP_METADATA_H
#import "il2cpp_symbols.h"

// Caller owns and retains the session, serializes access, verifies the exact
// target process and its continued liveness, and keeps its RemoteCall session
// alive until close completes. The stored generation is a cache key; it does
// not independently prove that an already-attached process is still alive.
typedef struct {
    __unsafe_unretained RemoteCallSession *session;
    CYIL2CPPSymbols symbols;
    uint64_t generation, domain, thread;
    bool attached_by_us, poisoned;
} CYIL2CPPMetadata;

bool cy_metadata_open(CYIL2CPPMetadata *ctx, RemoteCallSession *session,
                      const CYIL2CPPSymbols *symbols);
bool cy_metadata_class(CYIL2CPPMetadata *ctx, const char *assembly,
                       const char *namespaze, const char *name, uint64_t *result);
// A name and arity can have multiple overloads. The caller must verify the
// full method signature before invoking this candidate.
bool cy_metadata_method_candidate(CYIL2CPPMetadata *ctx, uint64_t klass,
                                  const char *name, int argument_count,
                                  uint64_t *result);
// Finds an exact method name, return type and managed parameter types. At
// most four parameters are supported. Type names are fully qualified.
bool cy_metadata_method_exact(CYIL2CPPMetadata *ctx, uint64_t klass, const char *name,
                              const char *return_type, const char *const *parameter_types, unsigned count,
                              uint64_t *result);
bool cy_metadata_handle_target(CYIL2CPPMetadata *ctx, uint64_t handle, uint64_t *object);
bool cy_metadata_handle_free(CYIL2CPPMetadata *ctx, uint64_t handle);
// Names outside the conservative printable ASCII subset are rejected.
bool cy_metadata_string_ascii(CYIL2CPPMetadata *ctx, uint64_t handle, char *out, size_t capacity);
// Returns an owned pinned handle to the System.Type for the given class.
bool cy_metadata_type_handle(CYIL2CPPMetadata *ctx, uint64_t klass, uint64_t *handle);
// Caller must already know the exact boxed return type and its size.
bool cy_metadata_unbox(CYIL2CPPMetadata *ctx, uint64_t handle, void *out, size_t size);
bool cy_metadata_close(CYIL2CPPMetadata *ctx);
#endif

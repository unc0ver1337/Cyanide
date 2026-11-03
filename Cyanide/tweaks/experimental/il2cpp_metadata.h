#ifndef CY_IL2CPP_METADATA_H
#define CY_IL2CPP_METADATA_H
#import "il2cpp_symbols.h"

// Caller owns and retains the session, serializes access, verifies the exact
// target process, and keeps its RemoteCall session alive until close completes.
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
bool cy_metadata_close(CYIL2CPPMetadata *ctx);
#endif

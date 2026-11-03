#import "chams_controller.h"
#import "chams_target.h"
#import "chams_scan.h"
#import "il2cpp_symbols.h"
#import "../remote_objc.h"
#import "../../TaskRop/RemoteCall.h"
#import "../../kexploit/kutils.h"
#include <string.h>

@implementation CYChamsController {
    RemoteCallSession *_session;
    CYIL2CPPMetadata _metadata;
    CYChamsUnityBindings _bindings;
    CYChamsPasses _passes;
    CYChamsAdapter _adapter;
    CYMaterialState _materials;
    uint64_t _image;
    int _pid;
    BOOL _enabled, _quarantined;
}

// Find the already loaded framework, then obtain a NOLOAD handle. Never load a
// new image into the game. Completion failures quarantine the entire session.
- (uint64_t)loadedUnityFramework {
    uint64_t count=r_session_dlsym_call(_session,100,"_dyld_image_count",0,0,0,0,0,0,0,0);
    if (!r_last_call_ok()) { _quarantined=YES; return 0; }
    if (count>4096) return 0;
    for (uint64_t i=0;i<count;i++) {
        uint64_t name=r_session_dlsym_call(_session,100,"_dyld_get_image_name",i,0,0,0,0,0,0,0);
        if (!r_last_call_ok()) { _quarantined=YES; return 0; }
        if (!name) continue;
        char path[1024]={0}; size_t j=0;
        for (;j<sizeof(path)-1;j++) {
            if (![_session remoteRead:name+j to:&path[j] size:1]) { _quarantined=YES; return 0; }
            if (!path[j]) break;
        }
        if (j==sizeof(path)-1) continue;
        static const char suffix[]="/UnityFramework.framework/UnityFramework";
        size_t len=strlen(path), tail=sizeof(suffix)-1;
        if (len<tail || strcmp(path+len-tail,suffix)) continue;
        // Darwin RTLD_NOW | RTLD_NOLOAD.
        uint64_t image=r_session_dlsym_call(_session,100,"dlopen",name,0x12,0,0,0,0,0,0);
        if (!r_last_call_ok()) _quarantined=YES;
        return image;
    }
    return 0;
}

- (BOOL)targetStillMatches {
    int found=0;
    CYTargetStatus status=cy_chams_find_running_pid(&found);
    if (status==CY_TARGET_INDETERMINATE) _quarantined=YES;
    if (status!=CY_TARGET_FOUND || found!=_pid || _session.pid!=_pid || !_session.taskAddr) return NO;
    uint64_t proc=proc_find((pid_t)_pid);
    return proc && proc_task(proc)==_session.taskAddr;
}

- (BOOL)start {
    if (_session || _quarantined) return NO;
    int pid=0; CYTargetStatus status=cy_chams_find_running_pid(&pid);
    if (status==CY_TARGET_INDETERMINATE) _quarantined=YES;
    if (status!=CY_TARGET_FOUND) return NO;
    _pid=pid;
    _session=[[RemoteCallSession alloc] initWithProcess:@"Standoff2" useMigFilterBypass:NO
        firstExceptionTimeoutMS:10000 originalThreadOnly:NO expectedPID:pid];
    if (!_session || _session.pid!=pid) return NO;
    if (![self targetStillMatches]) return NO;
    _image=[self loadedUnityFramework];
    if (!_image || _quarantined) return NO;
    CYIL2CPPSymbols symbols={0}; bool uncertain=false;
    if (!cy_il2cpp_resolve_symbols(_session,_image,&symbols,&uncertain)) { if (uncertain) _quarantined=YES; return NO; }
    if (!cy_metadata_open(&_metadata,_session,&symbols) ||
        !cy_chams_find_unity_bindings(&_metadata,&_bindings)) return NO;
    _adapter=(CYChamsAdapter){&_metadata,&_bindings,&_passes};
    cy_material_state_init(&_materials,_metadata.generation);
    if (!cy_chams_make_passes(&_metadata,&_bindings,&_materials.style,&_passes)) return NO;
    return YES;
}

- (BOOL)refresh {
    if (!_enabled || _quarantined || _metadata.poisoned || ![self targetStillMatches]) return NO;
    BOOL ok=cy_chams_scan_once(&_adapter,&_materials);
    if (_metadata.poisoned || _materials.uncertain) _quarantined=YES;
    return ok;
}

- (BOOL)setEnabled:(BOOL)enabled {
    if (_quarantined) return NO;
    if (!enabled) {
        if (!_session) return YES;
        if (![self targetStillMatches] || _metadata.poisoned) return NO;
        CYMaterialOperations ops={&_adapter,cy_chams_append,cy_chams_restore,cy_chams_drop};
        if (!cy_material_restore_all(&_materials,&ops)) { if (_materials.uncertain) _quarantined=YES; return NO; }
        _enabled=NO; return YES;
    }
    if (!_session && ![self start]) { (void)[self stop]; return NO; }
    _enabled=YES;
    if (![self refresh]) { (void)[self setEnabled:NO]; return NO; }
    return YES;
}

- (BOOL)stop {
    if (!_session) return !_quarantined;
    if (_quarantined || _metadata.poisoned || ![self targetStillMatches]) return NO;
    if (_enabled && ![self setEnabled:NO]) return NO;
    if ((_passes.behind || _passes.visible) && !cy_chams_destroy_passes(&_metadata,&_bindings,&_passes)) return NO;
    if (_metadata.session && !cy_metadata_close(&_metadata)) return NO;
    if (_image) {
        r_session_dlsym_call(_session,100,"dlclose",_image,0,0,0,0,0,0,0);
        if (!r_last_call_ok()) { _quarantined=YES; return NO; }
        _image=0;
    }
    if ([_session destroyRemoteCall]!=0) return NO;
    _session=nil; _pid=0; _enabled=NO; return YES;
}
@end

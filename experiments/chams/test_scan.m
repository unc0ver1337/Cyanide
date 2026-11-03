#define RemoteCall_h
#define remote_objc_h
#import "remote_syntax_stubs.h"
#import "../../Cyanide/tweaks/experimental/chams_scan.m"
#include <assert.h>
#include <stdio.h>
static int accepted,freed;
bool cy_metadata_type_handle(CYIL2CPPMetadata *c,uint64_t k,uint64_t *h){(void)c;assert(k==1);*h=100;return true;}
bool cy_metadata_handle_target(CYIL2CPPMetadata *c,uint64_t h,uint64_t *o){(void)c;*o=h;return h!=0;}
bool cy_metadata_handle_free(CYIL2CPPMetadata *c,uint64_t h){(void)c;assert(h);freed++;return true;}
bool cy_metadata_unbox(CYIL2CPPMetadata *c,uint64_t h,void *out,size_t n){(void)c;assert(n==4);*(int32_t *)out=h==41?1000:1;return true;}
bool cy_metadata_string_ascii(CYIL2CPPMetadata *c,uint64_t h,char *out,size_t n){
    (void)c;const char *s=h==50?"CT_TP_Diffuse":"SO2/Agents/CoreAgent";assert(strlen(s)<n);strcpy(out,s);return true;
}
CYIL2CPPCallStatus cy_il2cpp_call_managed(RemoteCallSession *session,uint64_t invoke,uint64_t gc,uint64_t method,
    uint64_t instance,const CYIL2CPPArgument *args,size_t n,bool object,CYIL2CPPRootedResult *out){
    (void)session;(void)invoke;(void)gc;assert(object);uint64_t h=0;
    if(method==2){assert(!instance && n==1 && args[0].reference==100);h=200;}
    else if(method==3){assert(!n && (instance==200||instance==300));h=43;}
    else if(method==4){assert(n==1 && *(const int32_t *)args[0].bytes==0);h=instance==200?10:11;}
    else if(method==5){assert(instance==10);h=13;}
    else if(method==6){assert(instance==13);h=42;}
    else if(method==7){assert(instance==10);h=41;}
    else if(method==8){assert(instance==11||instance==12);h=instance==11?50:51;}
    else if(method==9){assert(instance==11);h=12;}
    else assert(0);
    *out=(CYIL2CPPRootedResult){h,h,0};return CY_IL2CPP_CALL_COMPLETED;
}
CYChange cy_chams_snapshot(CYChamsAdapter *a,uint64_t r,uint64_t *h){(void)a;assert(r==10);*h=300;return CY_CHANGE_OK;}
CYChange cy_chams_append(void *a,uint64_t r,uint64_t s,const CYChamsStyle *v){(void)a;(void)r;(void)s;(void)v;return CY_CHANGE_OK;}
CYChange cy_chams_restore(void *a,uint64_t r,uint64_t s){(void)a;(void)r;(void)s;return CY_CHANGE_OK;}
void cy_chams_drop(void *a,uint64_t r,uint64_t s,bool live){(void)a;(void)r;(void)s;(void)live;}
CYMaterialResult cy_material_consider(CYMaterialState *state,const CYMaterialOperations *ops,uint64_t id,uint64_t r,
                                      uint64_t snap,const char *shader,const char *material){
    (void)state;(void)ops;assert(id==1000 && r==10 && snap==300 && !strcmp(shader,"SO2/Agents/CoreAgent") && !strcmp(material,"CT_TP_Diffuse"));
    accepted++;return CY_MATERIAL_APPLIED;
}
int main(void){
    CYIL2CPPMetadata m={0};m.session=(RemoteCallSession *)1;m.generation=7;
    CYChamsUnityBindings b={0};b.skinned_renderer_class=1;b.resources_find_all=2;b.array_get_length=3;b.array_get_value=4;
    b.skinned_get_mesh=5;b.mesh_get_submesh_count=6;b.object_get_instance_id=7;b.object_get_name=8;b.material_get_shader=9;
    CYChamsPasses p={30,31};CYChamsAdapter a={&m,&b,&p};CYMaterialState state={0};state.generation=7;
    assert(cy_chams_scan_once(&a,&state) && accepted==1 && freed>0);
    puts("Renderer discovery and material identification passed (mock Unity calls).");return 0;
}

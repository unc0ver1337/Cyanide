#define RemoteCall_h
#define remote_objc_h
#import "remote_syntax_stubs.h"
#import "../../Cyanide/tweaks/experimental/chams_apply.m"
#include <assert.h>
#include <stdio.h>
static int sets, copies, restores, freed, failSetter;
bool cy_metadata_handle_target(CYIL2CPPMetadata *c,uint64_t h,uint64_t *o){(void)c;*o=h;return h!=0;}
bool cy_metadata_handle_free(CYIL2CPPMetadata *c,uint64_t h){(void)c;assert(h);freed++;return true;}
bool cy_metadata_unbox(CYIL2CPPMetadata *c,uint64_t h,void *out,size_t n){(void)c;assert(h==40 && n==4);*(int32_t *)out=1;return true;}
CYIL2CPPCallStatus cy_chams_new_array(CYIL2CPPMetadata *c,uint64_t k,size_t n,CYIL2CPPRootedResult *o){
    (void)c;assert(k==9 && n==3);*o=(CYIL2CPPRootedResult){50,50,0};return CY_IL2CPP_CALL_COMPLETED;
}
CYIL2CPPCallStatus cy_il2cpp_call_managed(RemoteCallSession *s,uint64_t invoke,uint64_t gc,uint64_t method,
    uint64_t instance,const CYIL2CPPArgument *args,size_t n,bool resultObject,CYIL2CPPRootedResult *out){
    (void)s;(void)invoke;(void)gc;memset(out,0,sizeof(*out));
    if(method==1){assert(instance==10 && !n && resultObject);out->object=20;out->gc_handle=20;}
    else if(method==2){assert(instance==20 && !n && resultObject);out->object=40;out->gc_handle=40;}
    else if(method==3){assert(!instance && n==3 && args[0].reference==20 && args[1].reference==50 && *(const int32_t *)args[2].bytes==1);copies++;}
    else if(method==4){assert(instance==50 && n==2);int32_t i=*(const int32_t *)args[1].bytes;assert((i==1 && args[0].reference==30)||(i==2 && args[0].reference==31));sets++;}
    else if(method==5){assert(instance==10 && n==1);if(failSetter){out->exception=1;}else if(args[0].reference==20)restores++;else assert(args[0].reference==50);}
    else assert(0);
    return CY_IL2CPP_CALL_COMPLETED;
}
int main(void){
    CYIL2CPPMetadata m={0};m.session=(RemoteCallSession *)1;m.generation=1;
    CYChamsUnityBindings b={0};b.renderer_get_materials=1;b.array_get_length=2;b.array_copy=3;b.array_set_value=4;b.renderer_set_materials=5;b.material_class=9;
    CYChamsPasses passes={30,31};CYChamsAdapter a={&m,&b,&passes};uint64_t snapshot=0;
    assert(cy_chams_snapshot(&a,10,&snapshot)==CY_CHANGE_OK && snapshot==20);
    assert(cy_chams_append(&a,10,snapshot,NULL)==CY_CHANGE_OK && copies==1 && sets==2 && freed==2);
    assert(cy_chams_restore(&a,10,snapshot)==CY_CHANGE_OK && restores==1);
    failSetter=1;assert(cy_chams_append(&a,10,snapshot,NULL)==CY_CHANGE_UNKNOWN && freed==2);
    cy_chams_drop(&a,10,snapshot,false);assert(freed==2);
    puts("Material copy, overlay and restore sequence passed (mock Unity calls).");return 0;
}

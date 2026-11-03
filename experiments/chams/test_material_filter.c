#include "../../Cyanide/tweaks/experimental/chams_material_filter.h"
#include <assert.h>
#include <stdio.h>

int main(void) {
    assert(cy_chams_is_agent_material("SO2/Agents/CoreAgent", "CT_TP_Diffuse"));
    assert(cy_chams_is_agent_material("SO2/Agents/MsoAgent", "T_TP_PBR (Instance)"));
    assert(cy_chams_is_agent_material("SO2/Agents/CoreAgent", "CT_Hammer_TP_BumpedDiffuse"));
    assert(cy_chams_is_agent_material("SO2/Agents/CoreAgent", "CT_FP_BumpedDiffuse"));
    assert(cy_chams_is_agent_material("SO2/MSO/Mso", "CT_FP_PBR"));
    assert(cy_chams_is_agent_material("SO2/Agents/CoreAgent", "CT_Hammer_FP_BumpedSpecular"));
    assert(!cy_chams_is_agent_material("SO2/MSO/Mso", "AKR_FP_PBR"));
    assert(!cy_chams_is_agent_material("SO2/Agents/CoreAgent", "World_Diffuse"));
    assert(!cy_chams_is_agent_material("UI/Default", "CT_TP_Diffuse"));
    assert(!cy_chams_is_agent_material(NULL, "CT_TP_Diffuse"));
    assert(!cy_chams_is_agent_material("SO2/Agents/CoreAgent", NULL));
    puts("Material filter passed; actual game rendering remains untested.");
    return 0;
}

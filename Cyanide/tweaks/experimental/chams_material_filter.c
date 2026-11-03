#include "chams_material_filter.h"
#include <string.h>

bool cy_chams_is_agent_material(const char *shader_name, const char *material_name) {
    if (!shader_name || !material_name) return false;
    if (strcmp(shader_name, "SO2/Agents/CoreAgent") != 0 &&
        strcmp(shader_name, "SO2/Agents/MsoAgent") != 0 &&
        strcmp(shader_name, "SO2/MSO/Mso") != 0) return false;
    return strstr(material_name, "_TP_") != NULL ||
           strstr(material_name, "_FP_") != NULL;
}

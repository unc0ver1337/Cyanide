#ifndef CY_CHAMS_MATERIAL_FILTER_H
#define CY_CHAMS_MATERIAL_FILTER_H

#include <stdbool.h>

// Identifies supported third-person agent materials observed in Standoff2
// 1.1.0. This is a conservative filter; false negatives are possible.
bool cy_chams_is_agent_material(const char *shader_name, const char *material_name);

#endif

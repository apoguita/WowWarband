#include "ScriptMgr.h"

// Module entry point. The name is generated from the source directory
// (modules/mod-warband) by modules/CMakeLists.txt, so it must stay Addmod_warbandScripts.
void AddSC_warband_unbound_loot();
void AddSC_warband_settings();
void AddSC_warband_gathering();
void AddSC_warband_commands();

void Addmod_warbandScripts()
{
    AddSC_warband_settings();
    AddSC_warband_gathering();
    AddSC_warband_commands();
    AddSC_warband_unbound_loot();
}

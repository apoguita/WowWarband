/*
 * WoW Warband open-world scaling control.
 *
 * The scaling itself is not Warband code: mod-zone-scaling presents open-world creatures, quest
 * rewards and loot at each character's own level inside the zones the server opts in. The Warband
 * panel gets a switch that flips the module's own ZoneScaling.Enable option, so overworld scaling
 * can be turned on and off while playing instead of editing a configuration file.
 *
 * Default off, deliberately. The module ships disabled (ZoneScaling.Enable = 0) and, with its
 * DefaultBehaviour = "off", even an enabled module changes nothing until an administrator opts a
 * zone in - so installing the module and flipping this switch is not enough to scale the world.
 * That matches the Warband's recorded decision to keep the open world unscaled unless asked.
 *
 * How a change reaches the module: the option is ordinary configuration that the module reads in
 * its own OnAfterConfigLoad. So a change here rewrites that one line in the installed
 * mod_zone_scaling.conf, reloads the configuration and re-runs the config hook - the same path
 * .reload config takes - and the module picks the new value up without a restart. Everything else
 * in the file, comments included, is left untouched.
 */

#include "Config.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "World.h"

#include <fstream>
#include <string>
#include <vector>

namespace
{
// Relative to the server's config directory, so the same build works wherever the server is
// installed. A missing file means mod-zone-scaling is not installed here at all.
char const* const ZoneScalingConfigFile = "modules/mod_zone_scaling.conf";

// The one option the panel is allowed to touch. Everything else stays in the module's own file.
char const* const KeyEnable = "ZoneScaling.Enable";

std::string ConfigFilePath()
{
    return sConfigMgr->GetConfigPath() + ZoneScalingConfigFile;
}

std::string Trim(std::string const& text)
{
    size_t const begin = text.find_first_not_of(" \t\r\n");

    if (begin == std::string::npos)
        return std::string();

    size_t const end = text.find_last_not_of(" \t\r\n");
    return text.substr(begin, end - begin + 1);
}

bool StartsWithKey(std::string const& line, std::string const& key)
{
    std::string const trimmed = Trim(line);
    return trimmed.compare(0, key.size(), key) == 0 &&
        (trimmed.size() == key.size() || trimmed[key.size()] == ' ' || trimmed[key.size()] == '=');
}
}

bool WarbandZoneScalingInstalled()
{
    std::ifstream file(ConfigFilePath());
    return file.good();
}

// The live value, read exactly the way the scaling module reads it.
bool GetWarbandZoneScalingEnabled()
{
    return sConfigMgr->GetOption<bool>(KeyEnable, false, false);
}

// Rewrites the one option in the installed scaling configuration and reloads it. Returns false
// when the file or the key is missing, so the caller reports a failure instead of pretending the
// change happened.
bool SetWarbandZoneScalingEnabled(bool enabled)
{
    std::string const path = ConfigFilePath();

    std::ifstream input(path, std::ios::binary);
    if (!input.good())
        return false;

    std::vector<std::string> lines;
    bool replaced = false;

    for (std::string line; std::getline(input, line); )
    {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();

        if (!replaced && StartsWithKey(line, KeyEnable))
        {
            line = std::string(KeyEnable) + " = " + (enabled ? "1" : "0");
            replaced = true;
        }

        lines.push_back(line);
    }

    input.close();

    if (!replaced)
        return false;

    // Binary mode plus explicit newlines: the file is written the way it was read, without the
    // Windows text-mode translation turning every line into a double newline.
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output.good())
        return false;

    for (std::string const& line : lines)
        output << line << '\n';

    output.close();

    // The reload that makes the written value take effect: the configuration is re-read from disk
    // and every module's config hook runs again, which is where mod-zone-scaling reads its values.
    sWorld->LoadConfigSettings(true);
    sScriptMgr->OnAfterConfigLoad(true);

    LOG_INFO("server.loading", "Warband world scaling: {} set to {}", KeyEnable, enabled ? 1 : 0);
    return true;
}

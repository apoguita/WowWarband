/*
 * WoW Warband AoE loot control.
 *
 * The looting itself is not Warband code: mod-aoe-loot merges the loot of every lootable corpse in
 * range into the window opened on one corpse, so a party that just cleared a pack picks everything
 * up from one window. The Warband panel gets the full set of switches and values the module reads,
 * so area looting can be tuned while playing instead of editing a configuration file:
 *
 *   AOELoot.Enable      master switch                     default off (seeded by Warband)
 *   AOELoot.Message     announce the module on login      module default on
 *   AOELoot.Group       allow area looting inside a group module default on
 *   AOELoot.Range       corpse search radius (5 to 100)   module default 55
 *   AOELoot.MaxCorpses  corpses merged per window (1-50)  module default 20
 *   AOELoot.MailEnable  mail an item when the bags are full  default off
 *
 * Default off, deliberately: the module ships enabled, so the Warband runtime seeds its
 * configuration with AOELoot.Enable = 0 and the base game's one-corpse window stays the default
 * until someone turns it on. The module also carries its own per-character switch
 * (.aoeloot on|off); this surface is the server-wide configuration over the whole feature.
 *
 * How a change reaches the module: every option is ordinary configuration that the module re-reads
 * in its own OnAfterConfigLoad. A change here rewrites that one line in the installed
 * mod_aoe_loot.conf (appending it when the shipped file has no such line - AOELoot.MaxCorpses is
 * read but not documented upstream), reloads the configuration and re-runs the config hook - the
 * same path .reload config takes - so the module picks the new value up without a restart.
 */

#include "Config.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "World.h"

#include <cstdio>
#include <fstream>
#include <string>
#include <vector>

namespace
{
// Relative to the server's config directory, so the same build works wherever the server is
// installed. A missing file means mod-aoe-loot is not installed here at all.
char const* const AoeLootConfigFile = "modules/mod_aoe_loot.conf";

// The options the panel is allowed to touch. Everything else stays in the module's own file.
char const* const KeyEnable = "AOELoot.Enable";
char const* const KeyMessage = "AOELoot.Message";
char const* const KeyGroup = "AOELoot.Group";
char const* const KeyRange = "AOELoot.Range";
char const* const KeyMaxCorpses = "AOELoot.MaxCorpses";
char const* const KeyMailEnable = "AOELoot.MailEnable";

std::string ConfigFilePath()
{
    return sConfigMgr->GetConfigPath() + AoeLootConfigFile;
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

// Rewrites one option in the installed looting configuration (appending it when the file has no
// such line) and reloads the configuration. Returns false when the file cannot be read or written.
bool WriteOption(std::string const& key, std::string const& value)
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

        if (!replaced && StartsWithKey(line, key))
        {
            line = key + " = " + value;
            replaced = true;
        }

        lines.push_back(line);
    }

    input.close();

    if (!replaced)
        lines.push_back(key + " = " + value);

    // Binary mode plus explicit newlines: the file is written the way it was read, without the
    // Windows text-mode translation turning every line into a double newline.
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output.good())
        return false;

    for (std::string const& line : lines)
        output << line << '\n';

    output.close();

    // The reload that makes the written value take effect: the configuration is re-read from disk
    // and every module's config hook runs again, which is where mod-aoe-loot reads its values.
    sWorld->LoadConfigSettings(true);
    sScriptMgr->OnAfterConfigLoad(true);

    LOG_INFO("server.loading", "Warband AoE loot: {} set to {}", key, value);
    return true;
}
}

bool WarbandAoeLootInstalled()
{
    std::ifstream file(ConfigFilePath());
    return file.good();
}

bool GetWarbandAoeLootEnabled()
{
    return sConfigMgr->GetOption<bool>(KeyEnable, false, false);
}

bool GetWarbandAoeLootMessageEnabled()
{
    return sConfigMgr->GetOption<bool>(KeyMessage, true, false);
}

bool GetWarbandAoeLootGroupEnabled()
{
    return sConfigMgr->GetOption<bool>(KeyGroup, true, false);
}

bool GetWarbandAoeLootMailEnabled()
{
    return sConfigMgr->GetOption<bool>(KeyMailEnable, false, false);
}

float GetWarbandAoeLootRange()
{
    return sConfigMgr->GetOption<float>(KeyRange, 55.0f, false);
}

uint32 GetWarbandAoeLootMaxCorpses()
{
    return sConfigMgr->GetOption<uint32>(KeyMaxCorpses, 20, false);
}

bool SetWarbandAoeLootEnabled(bool enabled)
{
    return WriteOption(KeyEnable, enabled ? "1" : "0");
}

bool SetWarbandAoeLootMessageEnabled(bool enabled)
{
    return WriteOption(KeyMessage, enabled ? "1" : "0");
}

bool SetWarbandAoeLootGroupEnabled(bool enabled)
{
    return WriteOption(KeyGroup, enabled ? "1" : "0");
}

bool SetWarbandAoeLootMailEnabled(bool enabled)
{
    return WriteOption(KeyMailEnable, enabled ? "1" : "0");
}

bool SetWarbandAoeLootRange(float range)
{
    if (range < 5.0f || range > 100.0f)
        return false;

    char value[16] = { 0 };
    std::snprintf(value, sizeof(value), "%.1f", range);
    return WriteOption(KeyRange, value);
}

bool SetWarbandAoeLootMaxCorpses(uint32 corpses)
{
    if (corpses < 1 || corpses > 50)
        return false;

    return WriteOption(KeyMaxCorpses, std::to_string(corpses));
}

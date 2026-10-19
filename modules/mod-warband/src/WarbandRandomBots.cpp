/*
 * WoW Warband random world bots control.
 *
 * The bots that populate the world are not Warband's: mod-playerbots logs its random bots in and
 * out on its own schedule, within a population range from its configuration, and they are
 * background ambience rather than something the Warband uses. On a single-player server a
 * five-character Warband plays better without them - the world is large, the random bots scatter,
 * and the player rarely sees anything worth seeing from them. This surface gives the panel a switch
 * and a population target:
 *
 *   .warband randombots              read the state
 *   .warband randombots on | off     turn the random bot population on or off
 *   .warband randombots set <1-500>  pin the target number of random bots online
 *
 * The default is the configured behaviour, unchanged: enabled, with whatever population the
 * playerbots configuration asks for. A change is applied at once - turning it off stops new logins
 * and logs out the random bots online right now (Warband followers are not random bots and are never
 * touched) - and it is also written into the playerbots configuration, so the next startup holds
 * the same state. Nothing else in that file is touched.
 *
 * How it works: mod-playerbots gates its whole random bot tick on
 * `sPlayerbotAIConfig.RandomBotAutologin`, and its population is the event value "bot_count", which
 * the manager re-rolls within [MinRandomBots, MaxRandomBots] whenever it is out of range or expired.
 * Both bounds are part of the module's public configuration, so a target pins the population by
 * collapsing the range onto it - every re-roll then lands on the target - and lowering the
 * population logs the excess online bots out through the same manager logout the playerbots module
 * uses for its own logouts. The module reads those three options in OnBeforeWorldInitialized, which
 * is why a written change takes effect at the next startup rather than while it runs.
 */

#include "Config.h"
#include "Log.h"
#include "Player.h"
#include "PlayerbotAIConfig.h"
#include "RandomPlayerbotMgr.h"

#include <algorithm>
#include <cstdint>
#include <fstream>
#include <string>
#include <vector>

namespace
{
bool randomBotsEnabled = true;
uint32 randomBotTarget = 500;
bool initialised = false;

constexpr uint32 RandomBotTargetMin = 1;
constexpr uint32 RandomBotTargetMax = 500;

// The installed playerbots configuration, relative to the server's config directory, and the three
// options this surface owns. Everything else in that file stays as the server owner wrote it.
char const* const PlayerbotsConfigFile = "modules/playerbots.conf";
char const* const KeyAutologin = "Playerbots.RandomBotAutologin";
char const* const KeyMinBots = "Playerbots.MinRandomBots";
char const* const KeyMaxBots = "Playerbots.MaxRandomBots";

std::string ConfigFilePath()
{
    return sConfigMgr->GetConfigPath() + PlayerbotsConfigFile;
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

// Rewrites one option in the installed playerbots configuration, appending it when the shipped file
// has no such line. Returns false when the file cannot be read or written. The rest of the file is
// copied through unchanged, including the line ending it was written with.
bool WriteOption(std::string const& key, std::string const& value)
{
    std::string const path = ConfigFilePath();

    std::ifstream input(path, std::ios::binary);
    if (!input.good())
        return false;

    std::vector<std::string> lines;
    bool replaced = false;
    bool crlf = false;

    for (std::string line; std::getline(input, line); )
    {
        if (!line.empty() && line.back() == '\r')
        {
            line.pop_back();
            crlf = true;
        }

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

    char const* const newline = crlf ? "\r\n" : "\n";

    for (std::string const& line : lines)
        output << line << newline;

    output.close();

    return true;
}

// Remembers the target in the two options the manager re-rolls its population inside. A restart
// then starts from the same number instead of the range the file had before.
void PersistTarget(uint32 target)
{
    std::string const value = std::to_string(target);

    if (!WriteOption(KeyMinBots, value) || !WriteOption(KeyMaxBots, value))
    {
        LOG_ERROR(
            "server.loading",
            "Warband random bots: could not write the target {} to {}, so the next startup keeps "
            "the previous population range",
            target,
            ConfigFilePath());
    }
}

uint32 CountOnlineRandomBots()
{
    uint32 online = 0;

    for (Player* bot : sRandomPlayerbotMgr.GetPlayers())
        if (bot && sRandomPlayerbotMgr.IsRandomBot(bot))
            ++online;

    return online;
}

// Logs out random bots until only `keep` remain online. Warband followers are not random bots -
// IsRandomBot() tests the random-account list and the manager's own set - so they are never
// touched.
void LogoutRandomBotsDownTo(uint32 keep)
{
    uint32 online = CountOnlineRandomBots();
    if (online <= keep)
        return;

    // GetPlayers() returns a copy, which is what makes logging out while walking it safe.
    for (Player* bot : sRandomPlayerbotMgr.GetPlayers())
    {
        if (online <= keep)
            break;

        if (!bot || !sRandomPlayerbotMgr.IsRandomBot(bot))
            continue;

        sRandomPlayerbotMgr.LogoutPlayerBot(bot->GetGUID());
        --online;
    }
}

// Pins the manager's population at the target by collapsing its own range onto it: the manager
// re-rolls "bot_count" inside [MinRandomBots, MaxRandomBots] whenever the value is out of range or
// has expired, and a range of one value always re-rolls to the target.
void ApplyRandomBotTarget(uint32 target)
{
    sPlayerbotAIConfig.MinRandomBots = target;
    sPlayerbotAIConfig.MaxRandomBots = target;

    LogoutRandomBotsDownTo(target);
    PersistTarget(target);
}
}

void InitWarbandRandomBots()
{
    // Once per process. Playerbots reads its configuration in OnBeforeWorldInitialized and does not
    // reload it on .reload config, so a reload must not re-seed the panel with values the running
    // manager no longer uses.
    if (initialised)
        return;

    initialised = true;

    // Read the configuration file, not sPlayerbotAIConfig: the playerbots module fills that struct
    // in OnBeforeWorldInitialized, which has not run yet when this is called from a config load.
    randomBotsEnabled = sConfigMgr->GetOption<bool>(KeyAutologin, true);

    int32 const configuredTarget = sConfigMgr->GetOption<int32>(KeyMaxBots, int32(RandomBotTargetMax));

    // The manager's own range is the configuration; the panel only ever pins a value inside the
    // range it can show and step through.
    uint32 const target = uint32(std::max<int32>(configuredTarget, 0));
    randomBotTarget = std::clamp<uint32>(target, RandomBotTargetMin, RandomBotTargetMax);

    LOG_INFO(
        "server.loading",
        "Warband random bots: {} with a target of {}",
        randomBotsEnabled ? "enabled" : "disabled",
        randomBotTarget);
}

bool GetWarbandRandomBotsEnabled()
{
    return randomBotsEnabled;
}

uint32 GetWarbandRandomBotsTarget()
{
    return randomBotTarget;
}

uint32 GetWarbandRandomBotsOnline()
{
    return CountOnlineRandomBots();
}

bool SetWarbandRandomBotsEnabled(bool enabled)
{
    randomBotsEnabled = enabled;
    sPlayerbotAIConfig.RandomBotAutologin = enabled;

    if (enabled)
        ApplyRandomBotTarget(randomBotTarget);
    else
        LogoutRandomBotsDownTo(0);

    // The state is remembered for the next startup, the same way the panel remembers a target; a
    // failed write still leaves the running server in the requested state.
    if (!WriteOption(KeyAutologin, enabled ? "1" : "0"))
    {
        LOG_ERROR(
            "server.loading",
            "Warband random bots: could not write {} to {}, so the next startup keeps the previous "
            "state",
            KeyAutologin,
            ConfigFilePath());
    }

    LOG_INFO(
        "server.loading",
        "Warband random bots {}: {} now online",
        enabled ? "enabled" : "disabled",
        CountOnlineRandomBots());
    return true;
}

bool SetWarbandRandomBotsTarget(uint32 target)
{
    if (target < RandomBotTargetMin || target > RandomBotTargetMax)
        return false;

    randomBotTarget = target;

    if (randomBotsEnabled)
        ApplyRandomBotTarget(target);
    else
        PersistTarget(target);

    return true;
}

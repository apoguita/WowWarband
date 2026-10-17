/*
 * WoW Warband auction house control.
 *
 * The market itself is not Warband code: mod-ah-bot-plus fills the auction houses and buys player
 * listings. What it has no user front end, so this file gives the Warband panel something to talk
 * to: it reports the bot's live settings, and it can change the handful of them that matter while
 * playing.
 *
 * How a change reaches the bot: its settings are ordinary config options
 * (AuctionHouseBot.EnableSeller and friends) that the bot reads in its own OnAfterConfigLoad. So a
 * change here rewrites that one line in the installed mod_ahbot.conf, reloads the configuration and
 * re-runs the config hook - the same path .reload config takes - and the bot picks the new value up
 * without a restart. Everything else in the file, comments included, is left untouched.
 *
 * Scope, deliberately small: on/off for the seller and the buyer, how many items a cycle lists, how
 * many listings a cycle considers buying, and the stock target per auction house. Prices, filters
 * and listing rules stay in the bot's own configuration file, because they are its business and a
 * panel would only hide them.
 */

#include "Config.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "World.h"

#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <string>
#include <vector>

namespace
{
// Relative to the server's config directory, so the same build works wherever the server is
// installed. A missing file means the auction bot is not installed here at all.
char const* const AuctionBotConfigFile = "modules/mod_ahbot.conf";

// The options the panel is allowed to touch. Everything else stays in the bot's own file.
char const* const KeySeller = "AuctionHouseBot.EnableSeller";
char const* const KeyBuyer = "AuctionHouseBot.Buyer.Enabled";
char const* const KeyItemsPerCycle = "AuctionHouseBot.ItemsPerCycle";
char const* const KeyBuyCandidates = "AuctionHouseBot.Buyer.BuyCandidatesPerBuyCycle";
char const* const KeyStockAlliance = "AuctionHouseBot.Alliance.MaxItems";
char const* const KeyStockHorde = "AuctionHouseBot.Horde.MaxItems";
char const* const KeyStockNeutral = "AuctionHouseBot.Neutral.MaxItems";

std::string ConfigFilePath()
{
    return sConfigMgr->GetConfigPath() + AuctionBotConfigFile;
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

bool WarbandAuctionBotInstalled()
{
    std::ifstream file(ConfigFilePath());
    return file.good();
}

// One setting, straight from the live configuration - the same value the bot itself reads.
bool GetWarbandAuctionBotSetting(std::string const& key, bool fallback)
{
    return sConfigMgr->GetOption<bool>(key, fallback, false);
}

uint32 GetWarbandAuctionBotNumber(std::string const& key, uint32 fallback)
{
    return sConfigMgr->GetOption<uint32>(key, fallback, false);
}

// Rewrites one option in the installed bot configuration. Returns false when the file or the key is
// missing; the caller then reports a failure instead of pretending the change happened.
bool SetWarbandAuctionBotSetting(std::string const& key, std::string const& value)
{
    std::string const path = ConfigFilePath();

    std::ifstream input(path, std::ios::binary);
    if (!input.good())
        return false;

    std::vector<std::string> lines;
    bool replaced = false;

    for (std::string line; std::getline(input, line); )
    {
        if (line.back() == '\r')
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
        return false;

    // Binary mode plus explicit newlines: the file is written the way it was read, without the
    // Windows text-mode translation turning every line into a double newline.
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output.good())
        return false;

    for (std::string const& line : lines)
        output << line << '\n';

    output.close();

    LOG_INFO("server.loading", "Warband auction house: {} set to {}", key, value);
    return true;
}

// The reload that makes a written setting take effect: the configuration is re-read from disk and
// every module's config hook runs again, which is where the auction bot reads its values.
void WarbandReloadAuctionBot()
{
    sWorld->LoadConfigSettings(true);
    sScriptMgr->OnAfterConfigLoad(true);
}

bool WarbandSetAuctionBotSeller(bool enabled)
{
    if (!SetWarbandAuctionBotSetting(KeySeller, enabled ? "true" : "false"))
        return false;

    WarbandReloadAuctionBot();
    return true;
}

bool WarbandSetAuctionBotBuyer(bool enabled)
{
    if (!SetWarbandAuctionBotSetting(KeyBuyer, enabled ? "true" : "false"))
        return false;

    WarbandReloadAuctionBot();
    return true;
}

bool WarbandSetAuctionBotItemsPerCycle(uint32 items)
{
    if (items < 10 || items > 5000)
        return false;

    if (!SetWarbandAuctionBotSetting(KeyItemsPerCycle, std::to_string(items)))
        return false;

    WarbandReloadAuctionBot();
    return true;
}

bool WarbandSetAuctionBotBuyCandidates(uint32 candidates)
{
    if (candidates < 1 || candidates > 50)
        return false;

    if (!SetWarbandAuctionBotSetting(KeyBuyCandidates, std::to_string(candidates)))
        return false;

    WarbandReloadAuctionBot();
    return true;
}

// Stock target per auction house: both the minimum and the maximum, so the bot holds a steady
// number of listings instead of drifting between two different targets.
bool WarbandSetAuctionBotStock(std::string const& house, uint32 items)
{
    if (items > 20000)
        return false;

    char const* maximum = nullptr;
    char const* minimum = nullptr;

    if (house == "alliance")
    {
        maximum = KeyStockAlliance;
        minimum = "AuctionHouseBot.Alliance.MinItems";
    }
    else if (house == "horde")
    {
        maximum = KeyStockHorde;
        minimum = "AuctionHouseBot.Horde.MinItems";
    }
    else if (house == "neutral")
    {
        maximum = KeyStockNeutral;
        minimum = "AuctionHouseBot.Neutral.MinItems";
    }
    else
    {
        return false;
    }

    std::string const value = std::to_string(items);

    // The maximum first: a minimum above the maximum would keep the bot listing forever.
    if (!SetWarbandAuctionBotSetting(maximum, value))
        return false;

    SetWarbandAuctionBotSetting(minimum, value);
    WarbandReloadAuctionBot();
    return true;
}

// Forces the bot to rebuild its item candidate lists and top the houses up now, instead of waiting
// for the next cycle.
void WarbandRefreshAuctionBot()
{
    WarbandReloadAuctionBot();
}

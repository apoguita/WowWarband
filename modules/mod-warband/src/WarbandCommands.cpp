/*
 * WoW Warband chat commands. Available at player permission level.
 *
 *   .warband xp                                  read the live XP multiplier
 *   .warband xp set <1-10>                       change it
 *   .warband catchup                             read the follower catch-up settings
 *   .warband catchup step <0-10>                 extra experience per level behind
 *   .warband catchup floor <1-100>               lowest multiplier while behind
 *   .warband catchup cap <0-100>                 highest multiplier, 0 for uncapped
 *   .warband catchup on | off                    enable or disable catch-up
 *   .warband gather                              copy the leader's gathering skills to the party
 *   .warband gather status                       report the state without applying it
 *   .warband gather on | off                     enable or disable the mirror
 *   .warband gather auto on | off                apply it automatically on join and login
 *   .warband binding                             read whether item binding is enforced
 *   .warband binding on | off                    on is the ordinary rule, off lets bound gear move
 *   .warband magicfind                             read the magic find multipliers
 *   .warband magicfind <tier> <multiplier>         x1 to x20 on one quality, by colour or quality
 *   .warband magicfind reset                       every multiplier back to x1
 *   .warband goldfind                              read the coin multiplier
 *   .warband goldfind <multiplier>                 x1 to x20 on looted coin
 *   .warband goldfind reset                        back to x1
 *   .warband trash                                 read the trash auto-sell state
 *   .warband trash on | off                        sell grey loot at pickup, or stop doing it
 *   .warband trash sell                            empty every party member's bags of grey loot
 *   .warband ah                                    read the auction bot's live settings
 *   .warband ah seller | buyer on | off            switch a side of the market on or off
 *   .warband ah items <10-5000>                    listings added per cycle
 *   .warband ah candidates <1-50>                  listings the buyer considers per cycle
 *   .warband ah stock <alliance|horde|neutral> <n> stock target for one auction house
 *   .warband ah repopulate                         rebuild the bot's item lists and top up now
 *   .warband instance                              read whether killed instance creatures stay dead
 *   .warband instance on | off                     keep killed instance creatures dead, or not
 *   .warband party                                 list the characters on this account for the
 *                                                  party roster: name, class, level, online, grouped
 *
 * Every reply is a single machine-readable line, which is how the Warband addon reads state:
 *   WARBAND_XP=3
 *   WARBAND_CATCHUP=enabled=1;step=0.10;floor=1.00;cap=0.00;applied=0
 *   WARBAND_GATHER=enabled=1;automatic=1;herbalism=450;mining=450;skinning=0;updated=2;applied=7
 *   WARBAND_BINDING=enforced=0
 *   WARBAND_MAGICFIND=green=2.00;blue=4.00;purple=6.00;orange=6.00;gold=6.00
 *   WARBAND_GOLDFIND=3.00
 *   WARBAND_TRASHSELL=enabled=1;sold=12;copper=3456;swept=0
 *   WARBAND_AHBOT=installed=1;seller=1;buyer=1;items=150;candidates=5;alliance=1200;horde=1200;neutral=200
 *   WARBAND_INSTANCE=enabled=1;kept=42
 *   WARBAND_PARTY=Name|class|level|online|grouped;…   (then an empty WARBAND_PARTY= to close the list)
 */

#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "DBCEnums.h"
#include "Group.h"
#include "ItemBinding.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "RBAC.h"
#include "ScriptMgr.h"

#include <cmath>
#include <cstdlib>
#include <cstring>
#include <string>

float GetWarbandXpRate();
bool SetWarbandXpRate(float rate);
bool GetWarbandCatchUpEnabled();
float GetWarbandCatchUpPerLevel();
float GetWarbandCatchUpFloor();
float GetWarbandCatchUpCap();
uint32 GetWarbandCatchUpApplications();
bool SetWarbandCatchUpEnabled(bool enabled);
bool SetWarbandCatchUpPerLevel(float value);
bool SetWarbandCatchUpFloor(float value);
bool SetWarbandCatchUpCap(float value);
bool GetWarbandGatherMirrorEnabled();
bool GetWarbandGatherAutomatic();
uint32 GetWarbandGatherApplications();
bool SetWarbandGatherMirrorEnabled(bool enabled);
bool SetWarbandGatherAutomatic(bool automatic);
uint32 MirrorGatheringToParty(Player* leader);
uint8 WarbandMagicFindTierCount();
char const* WarbandMagicFindTierKey(uint8 tier);
char const* WarbandMagicFindTierAlias(uint8 tier);
float WarbandMagicFindTierMultiplier(uint8 tier);
bool SetWarbandMagicFindTierMultiplier(uint8 tier, float multiplier);
void ResetWarbandMagicFindMultipliers();
float GetWarbandGoldFindMultiplier();
bool SetWarbandGoldFindMultiplier(float multiplier);
void ResetWarbandGoldFindMultiplier();
bool GetWarbandTrashSellEnabled();
bool SetWarbandTrashSellEnabled(bool enabled);
uint32 GetWarbandTrashSoldItems();
uint64 GetWarbandTrashSoldCopper();
uint32 WarbandSellTrashInParty(Player* leader);
bool WarbandAuctionBotInstalled();
bool GetWarbandAuctionBotSetting(std::string const& key, bool fallback);
uint32 GetWarbandAuctionBotNumber(std::string const& key, uint32 fallback);
bool WarbandSetAuctionBotSeller(bool enabled);
bool WarbandSetAuctionBotBuyer(bool enabled);
bool WarbandSetAuctionBotItemsPerCycle(uint32 items);
bool WarbandSetAuctionBotBuyCandidates(uint32 candidates);
bool WarbandSetAuctionBotStock(std::string const& house, uint32 items);
void WarbandRefreshAuctionBot();
bool GetWarbandInstanceNoRespawn();
bool SetWarbandInstanceNoRespawn(bool enabled);
uint32 GetWarbandInstanceKeptDead();

using namespace Acore::ChatCommands;

namespace
{
char const* const CatchUpUsage =
    "Usage: .warband catchup [step <0-10>] [floor <1-100>] [cap <0-100>] [on|off]";

char const* const GatherUsage =
    "Usage: .warband gather [status] [on|off] [auto on|off]";

char const* const BindingUsage =
    "Usage: .warband binding [on|off] - on is the ordinary rule, off lets bound gear move";

char const* const MagicFindUsage =
    "Usage: .warband magicfind [<green|blue|purple|orange|gold> <multiplier 1-20>] [reset]";

char const* const GoldFindUsage =
    "Usage: .warband goldfind [<multiplier 1-20>] [reset]";

char const* const TrashUsage =
    "Usage: .warband trash [on|off|sell] - sell sells the grey loot already in the party's bags";

char const* const AuctionHouseUsage =
    "Usage: .warband ah [seller|buyer on|off] [items <10-5000>] [candidates <1-50>]"
    " [stock <alliance|horde|neutral> <0-20000>] [repopulate]";

char const* const InstanceUsage =
    "Usage: .warband instance [on|off] - whether a creature killed inside a dungeon stays dead";

// Parses the single numeric argument that may follow a keyword.
bool ParseValue(char const* args, size_t keywordLength, float& value)
{
    if (args[keywordLength] != ' ')
        return false;

    char* end = nullptr;
    value = std::strtof(args + keywordLength + 1, &end);
    return end != args + keywordLength + 1 && (*end == '\0' || *end == ' ') && std::isfinite(value);
}

// "on" or "off", with the keyword already consumed.
bool ParseToggle(char const* text, bool& value)
{
    while (*text == ' ')
        ++text;

    if (strncmp(text, "on", 2) == 0 && (text[2] == '\0' || text[2] == ' '))
    {
        value = true;
        return true;
    }

    if (strncmp(text, "off", 3) == 0 && (text[3] == '\0' || text[3] == ' '))
    {
        value = false;
        return true;
    }

    return false;
}

// A whole number, with the keyword already consumed.
bool ParseCount(char const* text, uint32& value)
{
    while (*text == ' ')
        ++text;

    char* end = nullptr;
    unsigned long const parsed = std::strtoul(text, &end, 10);

    if (end == text || (*end != '\0' && *end != ' '))
        return false;

    value = static_cast<uint32>(parsed);
    return true;
}
}

class WarbandCommandScript final : public CommandScript
{
public:
    WarbandCommandScript() : CommandScript("WarbandCommandScript") { }

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable warbandCommandTable =
        {
            {"xp",      HandleXpCommand,      SEC_PLAYER, Console::No},
            {"catchup", HandleCatchUpCommand, SEC_PLAYER, Console::No},
            {"gather",  HandleGatherCommand,  SEC_PLAYER, Console::No},
            {"binding", HandleBindingCommand, SEC_PLAYER, Console::No},
            {"magicfind", HandleMagicFindCommand, SEC_PLAYER, Console::No},
            {"mf",        HandleMagicFindCommand, SEC_PLAYER, Console::No},
            {"goldfind", HandleGoldFindCommand,   SEC_PLAYER, Console::No},
            {"gf",       HandleGoldFindCommand,   SEC_PLAYER, Console::No},
            {"trash",    HandleTrashCommand,      SEC_PLAYER, Console::No},
            {"ah",       HandleAuctionHouseCommand, SEC_PLAYER, Console::No},
            {"instance", HandleInstanceCommand,   SEC_PLAYER, Console::No},
            {"party",    HandlePartyCommand,      SEC_PLAYER, Console::No},
        };

        static ChatCommandTable commandTable =
        {
            {"warband", warbandCommandTable},
        };

        return commandTable;
    }

private:
    static bool HandleXpCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (!*args)
        {
            SendRate(handler);
            return true;
        }

        if (strncmp(args, "set ", 4) != 0)
        {
            handler->SendSysMessage("Usage: .warband xp [set <1-10>]");
            return false;
        }

        char* end = nullptr;
        float const rate = std::strtof(args + 4, &end);
        if (end == args + 4 || *end != '\0' || !std::isfinite(rate) || std::floor(rate) != rate ||
            !SetWarbandXpRate(rate))
        {
            handler->SendSysMessage("XP multiplier must be a whole number from 1 to 10.");
            return false;
        }

        SendRate(handler);
        return true;
    }

    static bool HandleCatchUpCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (!*args)
        {
            SendCatchUp(handler);
            return true;
        }

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandCatchUpEnabled(true);
            SendCatchUp(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandCatchUpEnabled(false);
            SendCatchUp(handler);
            return true;
        }

        struct Keyword
        {
            char const* name;
            bool (*setter)(float);
        };

        static Keyword const keywords[] =
        {
            {"step",  SetWarbandCatchUpPerLevel},
            {"floor", SetWarbandCatchUpFloor},
            {"cap",   SetWarbandCatchUpCap},
        };

        for (Keyword const& keyword : keywords)
        {
            size_t const length = strlen(keyword.name);
            if (strncmp(args, keyword.name, length) != 0)
                continue;

            float value = 0.0f;
            if (!ParseValue(args, length, value) || !keyword.setter(value))
            {
                handler->SendSysMessage(CatchUpUsage);
                return false;
            }

            SendCatchUp(handler);
            return true;
        }

        handler->SendSysMessage(CatchUpUsage);
        return false;
    }

    // Binding policy. "on" is the ordinary game rule, where a bound item stays with its owner;
    // "off" is the Warband rule, where a bound item can be traded, mailed, auctioned and handed to
    // a companion. The value lives in the core (Item.h), because the core is what asks.
    static bool HandleBindingCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            WarbandSetItemBindingEnforced(true);
            SendBinding(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            WarbandSetItemBindingEnforced(false);
            SendBinding(handler);
            return true;
        }

        if (*args)
        {
            handler->SendSysMessage(BindingUsage);
            return false;
        }

        SendBinding(handler);
        return true;
    }

    static void SendBinding(ChatHandler* handler)
    {
        handler->PSendSysMessage("WARBAND_BINDING=enforced={}", WarbandIsItemBindingEnforced() ? 1 : 0);
    }

    static bool HandleGatherCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "auto on", 7) == 0 && (args[7] == '\0' || args[7] == ' '))
        {
            SetWarbandGatherAutomatic(true);
            SendGather(handler);
            return true;
        }

        if (strncmp(args, "auto off", 8) == 0 && (args[8] == '\0' || args[8] == ' '))
        {
            SetWarbandGatherAutomatic(false);
            SendGather(handler);
            return true;
        }

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandGatherMirrorEnabled(true);
            SendGather(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandGatherMirrorEnabled(false);
            SendGather(handler);
            return true;
        }

        if (strncmp(args, "status", 6) == 0 && (args[6] == '\0' || args[6] == ' '))
        {
            SendGather(handler);
            return true;
        }

        if (*args)
        {
            handler->SendSysMessage(GatherUsage);
            return false;
        }

        // No argument: apply the mirror to the party right now and report what happened.
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        SendGather(handler, MirrorGatheringToParty(player));
        return true;
    }

    static void SendRate(ChatHandler* handler)
    {
        handler->PSendSysMessage("WARBAND_XP={}", GetWarbandXpRate());
    }

    // Reports the party state and the leader's own gathering values, which are what followers
    // receive when the mirror is applied.
    static void SendGather(ChatHandler* handler, uint32 updated = 0)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;

        handler->PSendSysMessage(
            "WARBAND_GATHER=enabled={};automatic={};herbalism={};mining={};skinning={};updated={};applied={}",
            GetWarbandGatherMirrorEnabled() ? 1 : 0,
            GetWarbandGatherAutomatic() ? 1 : 0,
            player ? player->GetSkillValue(SKILL_HERBALISM) : 0,
            player ? player->GetSkillValue(SKILL_MINING) : 0,
            player ? player->GetSkillValue(SKILL_SKINNING) : 0,
            updated,
            GetWarbandGatherApplications());
    }

    static void SendCatchUp(ChatHandler* handler)
    {
        handler->PSendSysMessage(
            "WARBAND_CATCHUP=enabled={};step={:.2f};floor={:.2f};cap={:.2f};applied={}",
            GetWarbandCatchUpEnabled() ? 1 : 0,
            GetWarbandCatchUpPerLevel(),
            GetWarbandCatchUpFloor(),
            GetWarbandCatchUpCap(),
            GetWarbandCatchUpApplications());
    }

    // Magic find. "green" is ITEM_QUALITY_UNCOMMON and the ladder continues up to
    // "gold" for artifact; the quality names are accepted as aliases by the setter.
    static bool HandleMagicFindCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "reset", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            ResetWarbandMagicFindMultipliers();
            SendMagicFind(handler);
            return true;
        }

        if (!*args)
        {
            SendMagicFind(handler);
            return true;
        }

        char tierName[32] = { 0 };
        size_t const tierLength = strcspn(args, " ");
        if (tierLength == 0 || tierLength >= sizeof(tierName))
        {
            handler->SendSysMessage(MagicFindUsage);
            return false;
        }

        std::strncpy(tierName, args, tierLength);

        uint8 tier = WarbandMagicFindTierCount();
        for (uint8 i = 0; i < WarbandMagicFindTierCount(); ++i)
        {
            if (std::strcmp(tierName, WarbandMagicFindTierKey(i)) == 0 ||
                std::strcmp(tierName, WarbandMagicFindTierAlias(i)) == 0)
            {
                tier = i;
                break;
            }
        }

        if (tier == WarbandMagicFindTierCount())
        {
            handler->SendSysMessage(MagicFindUsage);
            return false;
        }

        char const* multiplierText = args + tierLength;
        while (*multiplierText == ' ')
            ++multiplierText;

        if (!*multiplierText)
        {
            handler->SendSysMessage(MagicFindUsage);
            return false;
        }

        char* end = nullptr;
        float const multiplier = std::strtof(multiplierText, &end);

        if (end == multiplierText || (*end != '\0' && *end != ' ') || !std::isfinite(multiplier) ||
            !SetWarbandMagicFindTierMultiplier(tier, multiplier))
        {
            handler->SendSysMessage(MagicFindUsage);
            return false;
        }

        SendMagicFind(handler);
        return true;
    }

    static void SendMagicFind(ChatHandler* handler)
    {
        std::string line = "WARBAND_MAGICFIND=";

        for (uint8 tier = 0; tier < WarbandMagicFindTierCount(); ++tier)
        {
            if (tier)
                line += ';';

            line += WarbandMagicFindTierKey(tier);
            line += '=';

            char value[16] = { 0 };
            std::snprintf(value, sizeof(value), "%.2f", WarbandMagicFindTierMultiplier(tier));
            line += value;
        }

        handler->SendSysMessage(line);
    }

    // Gold find: one multiplier on looted coin. The module owns the core's Rate.Drop.Money and
    // pushes the value in, so the change is live.
    static bool HandleGoldFindCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "reset", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            ResetWarbandGoldFindMultiplier();
            SendGoldFind(handler);
            return true;
        }

        if (!*args)
        {
            SendGoldFind(handler);
            return true;
        }

        char* end = nullptr;
        float const multiplier = std::strtof(args, &end);

        if (end == args || (*end != '\0' && *end != ' ') || !std::isfinite(multiplier) ||
            !SetWarbandGoldFindMultiplier(multiplier))
        {
            handler->SendSysMessage(GoldFindUsage);
            return false;
        }

        SendGoldFind(handler);
        return true;
    }

    static void SendGoldFind(ChatHandler* handler)
    {
        char value[16] = { 0 };
        std::snprintf(value, sizeof(value), "%.2f", GetWarbandGoldFindMultiplier());

        handler->SendSysMessage(std::string("WARBAND_GOLDFIND=") + value);
    }

    // Trash auto-sell. "sell" is the sweep: it walks the leader's bags and every follower's, which
    // is the only way to clear a follower that is already full, since a full character cannot loot
    // in the first place.
    static bool HandleTrashCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandTrashSellEnabled(true);
            SendTrashSell(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandTrashSellEnabled(false);
            SendTrashSell(handler);
            return true;
        }

        if (strncmp(args, "sell", 4) == 0 && (args[4] == '\0' || args[4] == ' '))
        {
            Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
            if (!player)
                return false;

            SendTrashSell(handler, WarbandSellTrashInParty(player));
            return true;
        }

        if (!*args)
        {
            SendTrashSell(handler);
            return true;
        }

        handler->SendSysMessage(TrashUsage);
        return false;
    }

    // "swept" is how many items this particular command sold; "sold" and "copper" are the running
    // totals for the session, so the page can show what the feature has done since the last start.
    static void SendTrashSell(ChatHandler* handler, uint32 swept = 0)
    {
        handler->PSendSysMessage(
            "WARBAND_TRASHSELL=enabled={};sold={};copper={};swept={}",
            GetWarbandTrashSellEnabled() ? 1 : 0,
            GetWarbandTrashSoldItems(),
            GetWarbandTrashSoldCopper(),
            swept);
    }

    // Auction house: the market itself is mod-ah-bot-plus, which has no user front end at all, so
    // this is the surface the panel talks to. Only the options that shape the market are offered;
    // prices and filters stay in the bot's own configuration file.
    static bool HandleAuctionHouseCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (!WarbandAuctionBotInstalled())
        {
            handler->PSendSysMessage("WARBAND_AHBOT=installed=0");
            return true;
        }

        if (!*args)
        {
            SendAuctionHouse(handler);
            return true;
        }

        if (strncmp(args, "seller", 6) == 0 && (args[6] == '\0' || args[6] == ' '))
        {
            bool enabled = false;
            if (!ParseToggle(args + 6, enabled) || !WarbandSetAuctionBotSeller(enabled))
            {
                handler->SendSysMessage(AuctionHouseUsage);
                return false;
            }

            SendAuctionHouse(handler);
            return true;
        }

        if (strncmp(args, "buyer", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            bool enabled = false;
            if (!ParseToggle(args + 5, enabled) || !WarbandSetAuctionBotBuyer(enabled))
            {
                handler->SendSysMessage(AuctionHouseUsage);
                return false;
            }

            SendAuctionHouse(handler);
            return true;
        }

        if (strncmp(args, "items", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            uint32 items = 0;
            if (!ParseCount(args + 5, items) || !WarbandSetAuctionBotItemsPerCycle(items))
            {
                handler->SendSysMessage(AuctionHouseUsage);
                return false;
            }

            SendAuctionHouse(handler);
            return true;
        }

        if (strncmp(args, "candidates", 10) == 0 && (args[10] == '\0' || args[10] == ' '))
        {
            uint32 candidates = 0;
            if (!ParseCount(args + 10, candidates) || !WarbandSetAuctionBotBuyCandidates(candidates))
            {
                handler->SendSysMessage(AuctionHouseUsage);
                return false;
            }

            SendAuctionHouse(handler);
            return true;
        }

        if (strncmp(args, "stock", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            char const* rest = args + 5;
            while (*rest == ' ')
                ++rest;

            std::string const house(rest, strcspn(rest, " "));

            uint32 items = 0;

            if (house.empty() || !ParseCount(rest + house.size(), items) ||
                !WarbandSetAuctionBotStock(house, items))
            {
                handler->SendSysMessage(AuctionHouseUsage);
                return false;
            }

            SendAuctionHouse(handler);
            return true;
        }

        if (strncmp(args, "repopulate", 10) == 0 && (args[10] == '\0' || args[10] == ' '))
        {
            WarbandRefreshAuctionBot();
            SendAuctionHouse(handler);
            return true;
        }

        handler->SendSysMessage(AuctionHouseUsage);
        return false;
    }

    static void SendAuctionHouse(ChatHandler* handler)
    {
        handler->PSendSysMessage(
            "WARBAND_AHBOT=installed=1;seller={};buyer={};items={};candidates={};alliance={};horde={};neutral={}",
            GetWarbandAuctionBotSetting("AuctionHouseBot.EnableSeller", false) ? 1 : 0,
            GetWarbandAuctionBotSetting("AuctionHouseBot.Buyer.Enabled", false) ? 1 : 0,
            GetWarbandAuctionBotNumber("AuctionHouseBot.ItemsPerCycle", 0),
            GetWarbandAuctionBotNumber("AuctionHouseBot.Buyer.BuyCandidatesPerBuyCycle", 0),
            GetWarbandAuctionBotNumber("AuctionHouseBot.Alliance.MaxItems", 0),
            GetWarbandAuctionBotNumber("AuctionHouseBot.Horde.MaxItems", 0),
            GetWarbandAuctionBotNumber("AuctionHouseBot.Neutral.MaxItems", 0));
    }

    // Instances stop restocking. The rule is applied at the moment a creature dies, so switching it
    // off leaves everything that is already dead where it is - an instance reset is what brings a
    // dungeon back.
    static bool HandleInstanceCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandInstanceNoRespawn(true);
            SendInstance(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandInstanceNoRespawn(false);
            SendInstance(handler);
            return true;
        }

        if (!*args)
        {
            SendInstance(handler);
            return true;
        }

        handler->SendSysMessage(InstanceUsage);
        return false;
    }

    static void SendInstance(ChatHandler* handler)
    {
        handler->PSendSysMessage(
            "WARBAND_INSTANCE=enabled={};kept={}",
            GetWarbandInstanceNoRespawn() ? 1 : 0,
            GetWarbandInstanceKeptDead());
    }

    // The party roster: every character on the account, with the state the panel needs to decide
    // whether to offer Invite or Dismiss. The client cannot ask for this list, which is why it is a
    // server command; the panel only sends the ordinary Playerbots commands afterwards.
    static bool HandlePartyCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (*args)
        {
            handler->SendSysMessage("Usage: .warband party - list the characters on this account");
            return false;
        }

        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        uint32 const accountId = handler->GetSession()->GetAccountId();

        QueryResult result = CharacterDatabase.Query(
            "SELECT guid, name, class, level FROM characters WHERE account = {} ORDER BY level DESC, name ASC",
            accountId);

        if (!result)
        {
            handler->PSendSysMessage("WARBAND_PARTY=");
            return true;
        }

        std::string chunk;

        do
        {
            Field* fields = result->Fetch();

            ObjectGuid const guid = ObjectGuid(uint64(fields[0].Get<uint32>()));
            std::string const name = fields[1].Get<std::string>();
            uint8 const playerClass = fields[2].Get<uint8>();
            uint8 const level = fields[3].Get<uint8>();

            Player* online = ObjectAccessor::FindConnectedPlayer(guid);
            bool const grouped = online && online->GetGroup() != nullptr;

            // name|class|level|online|grouped, and ';' between entries; an empty line closes the list.
            std::string entry = name + "|" + std::to_string(playerClass) + "|" + std::to_string(level)
                + "|" + (online ? "1" : "0") + "|" + (grouped ? "1" : "0");

            if (chunk.empty())
                chunk = entry;
            else
                chunk += ";" + entry;

            // Keep each reply short enough for the client to show in one line.
            if (chunk.size() > 160)
            {
                handler->PSendSysMessage("WARBAND_PARTY={}", chunk);
                chunk.clear();
            }
        } while (result->NextRow());

        if (!chunk.empty())
            handler->PSendSysMessage("WARBAND_PARTY={}", chunk);

        handler->PSendSysMessage("WARBAND_PARTY=");
        return true;
    }
};

void AddSC_warband_commands()
{
    new WarbandCommandScript();
}

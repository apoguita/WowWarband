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
 *
 * Every reply is a single machine-readable line, which is how the Warband addon reads state:
 *   WARBAND_XP=3
 *   WARBAND_CATCHUP=enabled=1;step=0.10;floor=1.00;cap=0.00;applied=0
 *   WARBAND_GATHER=enabled=1;automatic=1;herbalism=450;mining=450;skinning=0;updated=2;applied=7
 *   WARBAND_BINDING=enforced=0
 *   WARBAND_MAGICFIND=green=2.00;blue=4.00;purple=6.00;orange=6.00;gold=6.00
 *   WARBAND_GOLDFIND=3.00
 */

#include "Chat.h"
#include "CommandScript.h"
#include "DBCEnums.h"
#include "ItemBinding.h"
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

// Parses the single numeric argument that may follow a keyword.
bool ParseValue(char const* args, size_t keywordLength, float& value)
{
    if (args[keywordLength] != ' ')
        return false;

    char* end = nullptr;
    value = std::strtof(args + keywordLength + 1, &end);
    return end != args + keywordLength + 1 && (*end == '\0' || *end == ' ') && std::isfinite(value);
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
};

void AddSC_warband_commands()
{
    new WarbandCommandScript();
}

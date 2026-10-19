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
 *   .warband price                                 read the supplier multipliers and the floor
 *   .warband price <tier> <multiplier>             x1 to x20 on one quality, by colour or quality
 *   .warband price floor <copper>                  the lowest price a supplier charges
 *   .warband price apply                           write the prices onto the items
 *   .warband price reset                           the shipped rule: 2/3/4/5/6/7/8/9 and 10 copper
 *   .warband trash                                 read the trash auto-sell state
 *   .warband trash on | off                        sell grey loot at pickup, or stop doing it
 *   .warband trash sell                            empty every party member's bags of grey loot
 *   .warband instance                              read whether killed instance creatures stay dead
 *   .warband instance on | off                     keep killed instance creatures dead, or not
 *   .warband hearthstone                           read whether the hearthstone has a cooldown
 *   .warband hearthstone on | off                  clear its cooldown on use, or restore it
 *   .warband pets                                  read whether pets are kept happy
 *   .warband pets on | off                         keep every hunter pet at full happiness, or not
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
 *   WARBAND_SUPPLIER=poor=2.00;normal=3.00;uncommon=4.00;rare=5.00;epic=6.00;legendary=7.00;
 *                    artifact=8.00;heirloom=9.00;floor=10;items=3412;current=1
 *   WARBAND_TRASHSELL=enabled=1;sold=12;copper=3456;swept=0
 *   WARBAND_AHBOT=installed=1;seller=1;buyer=1;items=150;candidates=5;alliance=1200;horde=1200;neutral=200
 *   WARBAND_INSTANCE=enabled=1;kept=42
 *   WARBAND_PARTY=Name|class|level|online|grouped;…   (then an empty WARBAND_PARTY= to close the list)
 *   WARBAND_HEARTHSTONE=enabled=1;cleared=3
 *   WARBAND_PETS=enabled=1
 */

#include "Bag.h"
#include "Chat.h"
#include "CommandScript.h"
#include "DatabaseEnv.h"
#include "DBCEnums.h"
#include "Group.h"
#include "ItemBinding.h"
#include "ItemTemplate.h"
#include "ObjectAccessor.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "RBAC.h"
#include "ScriptMgr.h"
#include "WarbandTrade.h"

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
uint32 GetWarbandTrashSoldItems(Player* leader);
uint64 GetWarbandTrashSoldCopper(Player* leader);
uint32 WarbandSellTrashInParty(Player* leader);
bool WarbandZoneScalingInstalled();
bool GetWarbandZoneScalingEnabled();
bool SetWarbandZoneScalingEnabled(bool enabled);
bool WarbandAoeLootInstalled();
bool GetWarbandAoeLootEnabled();
bool GetWarbandAoeLootMessageEnabled();
bool GetWarbandAoeLootGroupEnabled();
bool GetWarbandAoeLootMailEnabled();
float GetWarbandAoeLootRange();
uint32 GetWarbandAoeLootMaxCorpses();
bool SetWarbandAoeLootEnabled(bool enabled);
bool SetWarbandAoeLootMessageEnabled(bool enabled);
bool SetWarbandAoeLootGroupEnabled(bool enabled);
bool SetWarbandAoeLootMailEnabled(bool enabled);
bool SetWarbandAoeLootRange(float range);
bool SetWarbandAoeLootMaxCorpses(uint32 corpses);
bool GetWarbandRandomBotsEnabled();
uint32 GetWarbandRandomBotsTarget();
uint32 GetWarbandRandomBotsOnline();
bool SetWarbandRandomBotsEnabled(bool enabled);
bool SetWarbandRandomBotsTarget(uint32 target);
bool GetWarbandInstanceNoRespawn();
bool SetWarbandInstanceNoRespawn(bool enabled);
uint32 GetWarbandInstanceKeptDead();
bool GetWarbandHearthstoneAlwaysReady();
bool SetWarbandHearthstoneAlwaysReady(bool enabled);
bool GetWarbandPetsAlwaysHappy();
bool SetWarbandPetsAlwaysHappy(bool enabled);
uint32 GetWarbandHearthstoneClears();
uint8 WarbandSupplierTierCount();
char const* WarbandSupplierTierKey(uint8 tier);
char const* WarbandSupplierTierAlias(uint8 tier);
float WarbandSupplierTierMultiplier(uint8 tier);
bool SetWarbandSupplierTierMultiplier(uint8 tier, float value);
uint32 WarbandSupplierFloor();
bool SetWarbandSupplierFloor(uint32 copper);
void ResetWarbandSupplierSettings();
uint32 WarbandSupplierCatalogueSize();
bool WarbandSupplierPricesAreCurrent();
uint32 ApplyWarbandSupplierPrices(std::string& note);

using namespace Acore::ChatCommands;

namespace
{
char const* const CatchUpUsage =
    "Usage: .warband catchup [step <0-10>] [floor <1-100>] [cap <0-100>] [on|off]";

char const* const GatherUsage =
    "Usage: .warband gather [status] [on|off] [auto on|off]";

char const* const BindingUsage =
    "Usage: .warband binding [on|off] - on is the ordinary rule, off lets bound gear move;"
    " .warband binding items lists each carried item's flags";

char const* const MagicFindUsage =
    "Usage: .warband magicfind [<green|blue|purple|orange|gold> <multiplier 1-20>] [reset]";

char const* const GoldFindUsage =
    "Usage: .warband goldfind [<multiplier 1-20>] [reset]";

char const* const PriceUsage =
    "Usage: .warband price [<poor|normal|uncommon|rare|epic|legendary|artifact|heirloom> <multiplier 1-20>]"
    " [floor <copper>] [apply] [reset]";

char const* const TrashUsage =
    "Usage: .warband trash [on|off|sell] - sell sells the grey loot already in the party's bags";

char const* const WorldScaleUsage =
    "Usage: .warband worldscale [on|off] - open-world scaling via mod-zone-scaling, off by default";

char const* const AoeLootUsage =
    "Usage: .warband aoeloot [on|off] [message|group|mail on|off] [range <5-100>] [corpses <1-50>]"
    " - area looting via mod-aoe-loot, off by default";

char const* const RandomBotsUsage =
    "Usage: .warband randombots [on|off] [set <1-500>]"
    " - turn the random world bot population off, or pin how many stay online";

char const* const InstanceUsage =
    "Usage: .warband instance [on|off] - whether a creature killed inside a dungeon stays dead";

char const* const HearthstoneUsage =
    "Usage: .warband hearthstone [on|off] - whether the hearthstone keeps its cooldown";

char const* const PetsUsage =
    "Usage: .warband pets [on|off] - whether every hunter pet is kept at full happiness";

char const* const TradeGoldUsage =
    "Usage: .warband trade - read the open trade;"
    " .warband trade gold <amount> - put that much of the companion's money into the open trade"
    " (1s, 50c, 2g, 1g20s5c)";

// Compact money: digits with an optional g, s or c after each part, for example "1s", "50c", "2g",
// "1g20s5c". A bare number is copper. Guarded against absurd amounts so a typo cannot ask a
// companion for more gold than the game can hold.
bool ParseMoneyText(char const* text, uint32& copper)
{
    constexpr uint32 MoneyLimit = 2000000000u;

    uint32 total = 0;
    bool any = false;

    while (*text)
    {
        while (*text == ' ')
            ++text;

        if (!*text)
            break;

        char* end = nullptr;
        unsigned long const value = std::strtoul(text, &end, 10);
        if (end == text)
            return false;

        uint32 multiplier = 1;

        if (*end == 'g' || *end == 'G')
            multiplier = 10000;
        else if (*end == 's' || *end == 'S')
            multiplier = 100;
        else if (*end == 'c' || *end == 'C')
            multiplier = 1;
        else if (*end != '\0' && *end != ' ')
            return false;

        if (value > MoneyLimit / multiplier || total > MoneyLimit - uint32(value) * multiplier)
            return false;

        total += uint32(value) * multiplier;
        any = true;

        text = *end ? end + 1 : end;
    }

    copper = total;
    return any;
}

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
            {"price",    HandlePriceCommand,      SEC_PLAYER, Console::No},
            {"prices",   HandlePriceCommand,      SEC_PLAYER, Console::No},
            {"trash",    HandleTrashCommand,      SEC_PLAYER, Console::No},
            {"worldscale", HandleWorldScaleCommand, SEC_PLAYER, Console::No},
            {"aoeloot",  HandleAoeLootCommand,    SEC_PLAYER, Console::No},
            {"randombots", HandleRandomBotsCommand, SEC_PLAYER, Console::No},
            {"trade",    HandleTradeCommand,      SEC_PLAYER, Console::No},
            {"instance", HandleInstanceCommand,   SEC_PLAYER, Console::No},
            {"hearthstone", HandleHearthstoneCommand, SEC_PLAYER, Console::No},
            {"pets",     HandlePetsCommand,       SEC_PLAYER, Console::No},
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

        if (strncmp(args, "items", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
            return SendBindingItems(handler);

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

    // Debug aid: the flags the client reads, one line per carried item. A refused trade shows
    // exactly which flag the item is missing.
    static bool SendBindingItems(ChatHandler* handler)
    {
        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        auto report = [&handler](Item* item)
        {
            if (!item)
                return;

            handler->PSendSysMessage("WARBAND_ITEM={} soul={} trade={} bag={} slot={}",
                item->GetEntry(), item->IsSoulBound() ? 1 : 0, item->IsBOPTradable() ? 1 : 0,
                static_cast<uint32>(item->GetBagSlot()), static_cast<uint32>(item->GetSlot()));
        };

        for (uint8 slot = EQUIPMENT_SLOT_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
            report(player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

        for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
        {
            report(player->GetItemByPos(INVENTORY_SLOT_BAG_0, bagSlot));

            if (Bag* bag = player->GetBagByPos(bagSlot))
                for (uint8 slot = 0; slot < bag->GetBagSize(); ++slot)
                    report(bag->GetItemByPos(slot));
        }

        handler->PSendSysMessage("WARBAND_BINDING=enforced={}", WarbandIsItemBindingEnforced() ? 1 : 0);
        return true;
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

        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;
        if (!player)
            return false;

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandTrashSellEnabled(true);
            SendTrashSell(handler, player);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandTrashSellEnabled(false);
            SendTrashSell(handler, player);
            return true;
        }

        if (strncmp(args, "sell", 4) == 0 && (args[4] == '\0' || args[4] == ' '))
        {
            SendTrashSell(handler, player, WarbandSellTrashInParty(player));
            return true;
        }

        if (!*args)
        {
            SendTrashSell(handler, player);
            return true;
        }

        handler->SendSysMessage(TrashUsage);
        return false;
    }

    // "swept" is how many items this particular command sold; "sold" and "copper" are this
    // Warband's totals since its leader logged in, so the page never shows another player's or a
    // random bot's transactions.
    static void SendTrashSell(ChatHandler* handler, Player* leader, uint32 swept = 0)
    {
        handler->PSendSysMessage(
            "WARBAND_TRASHSELL=enabled={};sold={};copper={};swept={}",
            GetWarbandTrashSellEnabled() ? 1 : 0,
            GetWarbandTrashSoldItems(leader),
            GetWarbandTrashSoldCopper(leader),
            swept);
    }

    // Open-world scaling: the scaling itself is mod-zone-scaling, which has no panel of its own.
    // This surface reports whether it is installed and flips its single enable option; everything
    // else - zones, direction, bands - stays in the module's own configuration file. Off unless
    // someone turns it on: the module ships disabled and, even enabled, only scales zones the
    // server has explicitly opted in.
    static bool HandleWorldScaleCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (!WarbandZoneScalingInstalled())
        {
            handler->PSendSysMessage("WARBAND_WORLDSCALE=installed=0");
            return true;
        }

        if (!*args)
        {
            SendWorldScale(handler);
            return true;
        }

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            if (!SetWarbandZoneScalingEnabled(true))
            {
                handler->SendSysMessage(WorldScaleUsage);
                return false;
            }

            SendWorldScale(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            if (!SetWarbandZoneScalingEnabled(false))
            {
                handler->SendSysMessage(WorldScaleUsage);
                return false;
            }

            SendWorldScale(handler);
            return true;
        }

        handler->SendSysMessage(WorldScaleUsage);
        return false;
    }

    static void SendWorldScale(ChatHandler* handler)
    {
        handler->PSendSysMessage(
            "WARBAND_WORLDSCALE=installed=1;enabled={}",
            GetWarbandZoneScalingEnabled() ? 1 : 0);
    }

    // Area looting: the looting itself is mod-aoe-loot, which has no Warband surface. This reports
    // whether it is installed and exposes the whole configuration the module reads: the master
    // switch, the login message, whether it also works in a group, the merge radius, how many
    // corpses one window may cover, and the mail fallback for a full bag. Off unless someone turns
    // it on, so the base game's one-corpse window stays the default.
    static bool HandleAoeLootCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (!WarbandAoeLootInstalled())
        {
            handler->PSendSysMessage("WARBAND_AOELOOT=installed=0");
            return true;
        }

        if (!*args)
        {
            SendAoeLoot(handler);
            return true;
        }

        bool value = false;

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            if (!SetWarbandAoeLootEnabled(true))
            {
                handler->SendSysMessage(AoeLootUsage);
                return false;
            }

            SendAoeLoot(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            if (!SetWarbandAoeLootEnabled(false))
            {
                handler->SendSysMessage(AoeLootUsage);
                return false;
            }

            SendAoeLoot(handler);
            return true;
        }

        if (strncmp(args, "message", 7) == 0 && (args[7] == '\0' || args[7] == ' '))
        {
            if (!ParseToggle(args + 7, value) || !SetWarbandAoeLootMessageEnabled(value))
            {
                handler->SendSysMessage(AoeLootUsage);
                return false;
            }

            SendAoeLoot(handler);
            return true;
        }

        if (strncmp(args, "group", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            if (!ParseToggle(args + 5, value) || !SetWarbandAoeLootGroupEnabled(value))
            {
                handler->SendSysMessage(AoeLootUsage);
                return false;
            }

            SendAoeLoot(handler);
            return true;
        }

        if (strncmp(args, "mail", 4) == 0 && (args[4] == '\0' || args[4] == ' '))
        {
            if (!ParseToggle(args + 4, value) || !SetWarbandAoeLootMailEnabled(value))
            {
                handler->SendSysMessage(AoeLootUsage);
                return false;
            }

            SendAoeLoot(handler);
            return true;
        }

        if (strncmp(args, "range", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            float range = 0.0f;
            if (!ParseValue(args, 5, range) || !SetWarbandAoeLootRange(range))
            {
                handler->SendSysMessage(AoeLootUsage);
                return false;
            }

            SendAoeLoot(handler);
            return true;
        }

        if (strncmp(args, "corpses", 7) == 0 && (args[7] == '\0' || args[7] == ' '))
        {
            uint32 corpses = 0;
            if (!ParseCount(args + 7, corpses) || !SetWarbandAoeLootMaxCorpses(corpses))
            {
                handler->SendSysMessage(AoeLootUsage);
                return false;
            }

            SendAoeLoot(handler);
            return true;
        }

        handler->SendSysMessage(AoeLootUsage);
        return false;
    }

    static void SendAoeLoot(ChatHandler* handler)
    {
        handler->PSendSysMessage(
            "WARBAND_AOELOOT=installed=1;enabled={};message={};group={};mail={};range={:.1f};corpses={}",
            GetWarbandAoeLootEnabled() ? 1 : 0,
            GetWarbandAoeLootMessageEnabled() ? 1 : 0,
            GetWarbandAoeLootGroupEnabled() ? 1 : 0,
            GetWarbandAoeLootMailEnabled() ? 1 : 0,
            GetWarbandAoeLootRange(),
            GetWarbandAoeLootMaxCorpses());
    }

    // Random world bots: the bots the playerbots module logs in and out by itself are ambience, not
    // Warband. On a single-player server a five-character Warband plays better without them - the
    // world is large, the random bots scatter, and nothing they do is seen. This is the switch and
    // the population target; the default is the configured behaviour, unchanged.
    static bool HandleRandomBotsCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (!*args)
        {
            SendRandomBots(handler);
            return true;
        }

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandRandomBotsEnabled(true);
            SendRandomBots(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandRandomBotsEnabled(false);
            SendRandomBots(handler);
            return true;
        }

        if (strncmp(args, "set", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            uint32 target = 0;
            if (!ParseCount(args + 3, target) || !SetWarbandRandomBotsTarget(target))
            {
                handler->SendSysMessage(RandomBotsUsage);
                return false;
            }

            SendRandomBots(handler);
            return true;
        }

        handler->SendSysMessage(RandomBotsUsage);
        return false;
    }

    static void SendRandomBots(ChatHandler* handler)
    {
        handler->PSendSysMessage(
            "WARBAND_RANDOMBOTS=enabled={};target={};online={}",
            GetWarbandRandomBotsEnabled() ? 1 : 0,
            GetWarbandRandomBotsTarget(),
            GetWarbandRandomBotsOnline());
    }

    // The open trade, from the player's side: who it is with, what that companion's side holds and
    // what they carry. `.warband trade gold <amount>` then puts money of theirs into the window,
    // which is the one step the bot answers by whisper today and which nobody should have to
    // remember. The trade itself stays a trade: the core moves the coin on accept.
    static bool HandleTradeCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        Player* player = handler->GetSession() ? handler->GetSession()->GetPlayer() : nullptr;

        if (!*args)
        {
            SendTrade(handler, player);
            return true;
        }

        if (strncmp(args, "gold", 4) == 0 && (args[4] == '\0' || args[4] == ' '))
        {
            char const* rest = args + 4;
            while (*rest == ' ')
                ++rest;

            uint32 copper = 0;
            if (!*rest || !ParseMoneyText(rest, copper) || !player)
            {
                handler->SendSysMessage(TradeGoldUsage);
                return false;
            }

            Player* partner = nullptr;

            switch (WarbandFillTradeGold(player, copper, partner))
            {
                case WarbandTradeGold::Ok:
                    handler->PSendSysMessage(
                        "WARBAND_TRADEGOLD=ok=1;partner={};amount={};purse={}",
                        partner->GetName(),
                        copper,
                        partner->GetMoney());
                    return true;
                case WarbandTradeGold::NoTrade:
                    handler->PSendSysMessage("WARBAND_TRADEGOLD=ok=0;reason=notrade");
                    return true;
                case WarbandTradeGold::NotCompanion:
                    handler->PSendSysMessage(
                        "WARBAND_TRADEGOLD=ok=0;reason=notcompanion;partner={}",
                        partner ? partner->GetName() : "");
                    return true;
                case WarbandTradeGold::NoFunds:
                    handler->PSendSysMessage(
                        "WARBAND_TRADEGOLD=ok=0;reason=nofunds;partner={};purse={}",
                        partner ? partner->GetName() : "",
                        partner ? partner->GetMoney() : 0);
                    return true;
            }

            handler->SendSysMessage(TradeGoldUsage);
            return false;
        }

        handler->SendSysMessage(TradeGoldUsage);
        return false;
    }

    static void SendTrade(ChatHandler* handler, Player* player)
    {
        Player* partner = nullptr;
        uint32 tradeMoney = 0;
        uint32 purse = 0;

        if (!WarbandTradeState(player, partner, tradeMoney, purse))
        {
            handler->PSendSysMessage("WARBAND_TRADE=open=0");
            return;
        }

        handler->PSendSysMessage(
            "WARBAND_TRADE=open=1;partner={};purse={};inTrade={}",
            partner->GetName(),
            purse,
            tradeMoney);
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

    // Hearthstone and pets: two convenience switches, each off the same pattern as the rest.
    static bool HandleHearthstoneCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandHearthstoneAlwaysReady(true);
            SendHearthstone(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandHearthstoneAlwaysReady(false);
            SendHearthstone(handler);
            return true;
        }

        if (!*args)
        {
            SendHearthstone(handler);
            return true;
        }

        handler->SendSysMessage(HearthstoneUsage);
        return false;
    }

    static void SendHearthstone(ChatHandler* handler)
    {
        handler->PSendSysMessage(
            "WARBAND_HEARTHSTONE=enabled={};cleared={}",
            GetWarbandHearthstoneAlwaysReady() ? 1 : 0,
            GetWarbandHearthstoneClears());
    }

    static bool HandlePetsCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (strncmp(args, "on", 2) == 0 && (args[2] == '\0' || args[2] == ' '))
        {
            SetWarbandPetsAlwaysHappy(true);
            SendPets(handler);
            return true;
        }

        if (strncmp(args, "off", 3) == 0 && (args[3] == '\0' || args[3] == ' '))
        {
            SetWarbandPetsAlwaysHappy(false);
            SendPets(handler);
            return true;
        }

        if (!*args)
        {
            SendPets(handler);
            return true;
        }

        handler->SendSysMessage(PetsUsage);
        return false;
    }

    static void SendPets(ChatHandler* handler)
    {
        handler->PSendSysMessage("WARBAND_PETS=enabled={}", GetWarbandPetsAlwaysHappy() ? 1 : 0);
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
    // Supplier prices: one multiplier per quality plus a floor. The values are saved in the world
    // database, and "apply" writes them onto the catalogue items, which is why the new prices are
    // visible after a restart rather than immediately.
    static bool HandlePriceCommand(ChatHandler* handler, char const* args)
    {
        while (*args == ' ')
            ++args;

        if (!*args)
        {
            SendPrice(handler);
            return true;
        }

        if (strncmp(args, "apply", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            std::string note;
            uint32 const priced = ApplyWarbandSupplierPrices(note);

            if (priced)
            {
                handler->PSendSysMessage(
                    "Priced {} items. Restart the worldserver to see the new prices.", priced);
            }
            else
            {
                handler->PSendSysMessage("Prices not applied: {}.", note);
            }

            SendPrice(handler);
            return priced != 0;
        }

        if (strncmp(args, "reset", 5) == 0 && (args[5] == '\0' || args[5] == ' '))
        {
            ResetWarbandSupplierSettings();
            handler->SendSysMessage(
                "Back to 2/3/4/5/6/7/8/9 by quality and 10 copper floor. Apply to write them onto the items.");
            SendPrice(handler);
            return true;
        }

        if (strncmp(args, "floor", 5) == 0 && args[5] == ' ')
        {
            char const* valueText = args + 5;
            while (*valueText == ' ')
                ++valueText;

            char* end = nullptr;
            long const parsed = std::strtol(valueText, &end, 10);

            if (end == valueText || (*end != '\0' && *end != ' ') || parsed < 0 ||
                !SetWarbandSupplierFloor(uint32(parsed)))
            {
                handler->SendSysMessage(PriceUsage);
                return false;
            }

            SendPrice(handler);
            return true;
        }

        char tierName[32] = { 0 };
        size_t const tierLength = strcspn(args, " ");
        if (tierLength == 0 || tierLength >= sizeof(tierName))
        {
            handler->SendSysMessage(PriceUsage);
            return false;
        }

        std::strncpy(tierName, args, tierLength);

        uint8 tier = WarbandSupplierTierCount();
        for (uint8 i = 0; i < WarbandSupplierTierCount(); ++i)
        {
            if (std::strcmp(tierName, WarbandSupplierTierKey(i)) == 0 ||
                std::strcmp(tierName, WarbandSupplierTierAlias(i)) == 0)
            {
                tier = i;
                break;
            }
        }

        if (tier == WarbandSupplierTierCount())
        {
            handler->SendSysMessage(PriceUsage);
            return false;
        }

        char const* multiplierText = args + tierLength;
        while (*multiplierText == ' ')
            ++multiplierText;

        if (!*multiplierText)
        {
            handler->SendSysMessage(PriceUsage);
            return false;
        }

        char* end = nullptr;
        float const multiplier = std::strtof(multiplierText, &end);

        if (end == multiplierText || (*end != '\0' && *end != ' ') || !std::isfinite(multiplier) ||
            !SetWarbandSupplierTierMultiplier(tier, multiplier))
        {
            handler->SendSysMessage(PriceUsage);
            return false;
        }

        SendPrice(handler);
        return true;
    }

    static void SendPrice(ChatHandler* handler)
    {
        std::string line = "WARBAND_SUPPLIER=";

        for (uint8 tier = 0; tier < WarbandSupplierTierCount(); ++tier)
        {
            if (tier)
                line += ';';

            line += WarbandSupplierTierKey(tier);
            line += '=';

            char value[16] = { 0 };
            std::snprintf(value, sizeof(value), "%.2f", WarbandSupplierTierMultiplier(tier));
            line += value;
        }

        char tail[96] = { 0 };
        std::snprintf(tail, sizeof(tail), ";floor=%u;items=%u;current=%d",
            WarbandSupplierFloor(),
            WarbandSupplierCatalogueSize(),
            WarbandSupplierPricesAreCurrent() ? 1 : 0);
        line += tail;

        handler->SendSysMessage(line);
    }
};

void AddSC_warband_commands()
{
    new WarbandCommandScript();
}

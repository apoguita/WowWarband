/*
 * WoW Warband magic find.
 *
 * The same mechanism the core already has as Rate.Drop.Item.*, but scoped to the Warband and
 * switchable while playing. A multiplier applies to the drop chance of the rows that drop an item of
 * that quality:
 *
 *     new chance = min(chance * multiplier, 100)
 *
 * The shipped defaults are x2 greens, x4 blues, x6 epic and above, so a 3% legendary row becomes 18%
 * and a 55% blue becomes guaranteed. Nothing else changes: no rows added or removed, no extra rolls,
 * no extra items, no duplicates, no table edits. Poor and normal are never touched, so the junk
 * distribution stays exactly as the game ships it.
 *
 * The hook is GlobalScript::OnItemRoll, which hands over the row's chance by reference, once per row
 * per loot generation, for ungrouped and grouped rows alike (LootMgr.cpp:315 and :1276). It runs
 * before the core's own Rate.Drop.Item.* multiplier, so the two compose, and before the >= 100
 * shortcut, so a multiplier can legitimately turn a row into a guaranteed drop.
 *
 * Scope: the Warband's own loot - the character being played or a follower piloted for one. Random
 * bots keep the untouched tables and the core rates stay as configured.
 *
 * Two shapes a multiplier cannot reach, because there is no chance number to multiply:
 *
 *   - rows with Chance = 0 inside a group (the game picks one of them at random instead of rolling);
 *   - reference rows, whose quality lives on the rows inside the referenced table, which are
 *     multiplied normally.
 */

#include "Config.h"
#include "ItemTemplate.h"
#include "LootMgr.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WarbandPlayerRoles.h"

#include <algorithm>
#include <array>
#include <cmath>

namespace
{
// ITEM_QUALITY_UNCOMMON .. ITEM_QUALITY_ARTIFACT. Poor and normal stay out on purpose.
constexpr uint8 MagicFindTierCount = 5;
constexpr uint8 FirstMagicFindQuality = ITEM_QUALITY_UNCOMMON;
constexpr float MinMagicFindMultiplier = 1.0f;
constexpr float MaxMagicFindMultiplier = 20.0f;

std::array<float, MagicFindTierCount> magicFindMultipliers = { 2.0f, 4.0f, 6.0f, 6.0f, 6.0f };

// The panel and the reply line speak in colours; the command also accepts the quality names.
std::array<char const*, MagicFindTierCount> const magicFindTierKeys = { "green", "blue", "purple", "orange", "gold" };
std::array<char const*, MagicFindTierCount> const magicFindTierAliases =
{
    "uncommon", "rare", "epic", "legendary", "artifact"
};

std::array<char const*, MagicFindTierCount> const magicFindConfigNames =
{
    "Warband.MagicFind.Green",
    "Warband.MagicFind.Blue",
    "Warband.MagicFind.Purple",
    "Warband.MagicFind.Orange",
    "Warband.MagicFind.Gold"
};

// The Warband whose loot this is: the player being played, or a follower piloted for one.
bool IsWarbandLootOwner(Player const* player)
{
    if (!player)
        return false;

    if (WarbandFollowerMaster(const_cast<Player*>(player)))
        return true;

    WorldSession const* session = player->GetSession();
    return session && !session->IsHeadless();
}
}

uint8 WarbandMagicFindTierCount()
{
    return MagicFindTierCount;
}

char const* WarbandMagicFindTierKey(uint8 tier)
{
    if (tier >= MagicFindTierCount)
        return "";

    return magicFindTierKeys[tier];
}

char const* WarbandMagicFindTierAlias(uint8 tier)
{
    if (tier >= MagicFindTierCount)
        return "";

    return magicFindTierAliases[tier];
}

float WarbandMagicFindTierMultiplier(uint8 tier)
{
    if (tier >= MagicFindTierCount)
        return 1.0f;

    return magicFindMultipliers[tier];
}

bool SetWarbandMagicFindTierMultiplier(uint8 tier, float multiplier)
{
    if (tier >= MagicFindTierCount || !std::isfinite(multiplier) ||
        multiplier < MinMagicFindMultiplier || multiplier > MaxMagicFindMultiplier)
    {
        return false;
    }

    magicFindMultipliers[tier] = multiplier;
    return true;
}

void ResetWarbandMagicFindMultipliers()
{
    magicFindMultipliers.fill(1.0f);
}

class WarbandMagicFind final : public GlobalScript, public WorldScript
{
public:
    WarbandMagicFind() : GlobalScript("WarbandMagicFind", { GLOBALHOOK_ON_ITEM_ROLL }),
        WorldScript("WarbandMagicFind") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        for (uint8 tier = 0; tier < MagicFindTierCount; ++tier)
        {
            float const configured = sConfigMgr->GetOption<float>(magicFindConfigNames[tier], 1.0f);

            if (!std::isfinite(configured) ||
                configured < MinMagicFindMultiplier || configured > MaxMagicFindMultiplier)
            {
                LOG_ERROR(
                    "server.loading",
                    "Warband: {} ({}) must be between {} and {}, using 1.0",
                    magicFindConfigNames[tier],
                    magicFindTierKeys[tier],
                    MinMagicFindMultiplier,
                    MaxMagicFindMultiplier);
                magicFindMultipliers[tier] = 1.0f;
                continue;
            }

            magicFindMultipliers[tier] = configured;
        }

        LOG_INFO(
            "server.loading",
            "Warband magic find: green x{}, blue x{}, purple x{}, orange x{}, gold x{}",
            magicFindMultipliers[0], magicFindMultipliers[1], magicFindMultipliers[2], magicFindMultipliers[3],
            magicFindMultipliers[4]);
    }

    // Called once per loot row with the row's chance by reference. Returning false would drop the row
    // outright; this only rescales the odds.
    bool OnItemRoll(Player const* player, LootStoreItem const* item, float& chance,
        Loot& /*loot*/, LootStore const& /*store*/) override
    {
        if (!item || item->reference || !IsWarbandLootOwner(player))
            return true;

        ItemTemplate const* proto = sObjectMgr->GetItemTemplate(item->itemid);
        if (!proto || proto->Quality < FirstMagicFindQuality ||
            proto->Quality >= FirstMagicFindQuality + MagicFindTierCount)
            return true;

        float const multiplier = magicFindMultipliers[proto->Quality - FirstMagicFindQuality];
        if (multiplier == 1.0f)
            return true;

        chance = std::min(chance * multiplier, 100.0f);
        return true;
    }
};

void AddSC_warband_magicfind()
{
    new WarbandMagicFind();
}

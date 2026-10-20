/*
 * WoW Warband gold find.
 *
 * The companion of the magic find feature, and simpler: the core already multiplies looted coin by
 * Rate.Drop.Money inside Loot::generateMoneyLoot (LootMgr.cpp:808), which covers the money on
 * creatures, chests, mines and containers. This module owns that rate so the panel can change it
 * while playing instead of editing worldserver.conf and reloading.
 *
 * Scope, stated plainly: Rate.Drop.Money is a world rate, so it applies to every coin pile the loot
 * system generates, for every player. On this single-player server that is the same thing as "the
 * Warband's gold"; the difference from the magic find feature, which is scoped by the hook that
 * carries the looter, is that this one has no per-player hook to hang on. The rate a script sets
 * wins over the value in worldserver.conf, and this module re-applies it whenever the configuration
 * is loaded or reloaded.
 *
 * What it does not touch: gold from vendoring, quest rewards, mail or the auction house. Those are
 * separate paths and separate rates (Rate.RewardQuestMoney, Rate.RewardBonusMoney for quests).
 */

#include "Config.h"
#include "ScriptMgr.h"
#include "WarbandPersistence.h"
#include "World.h"

#include <cmath>

namespace
{
constexpr float MinGoldFindMultiplier = 1.0f;
constexpr float MaxGoldFindMultiplier = 20.0f;
constexpr float DefaultGoldFindMultiplier = 3.0f;

float goldFindMultiplier = DefaultGoldFindMultiplier;

// Pushes the value into the world rate the loot system reads. Calling it again is harmless.
void ApplyGoldFind()
{
    sWorld->setRate(RATE_DROP_MONEY, goldFindMultiplier);
}
}

float GetWarbandGoldFindMultiplier()
{
    return goldFindMultiplier;
}

bool SetWarbandGoldFindMultiplier(float multiplier)
{
    if (!std::isfinite(multiplier) || multiplier < MinGoldFindMultiplier ||
        multiplier > MaxGoldFindMultiplier)
    {
        return false;
    }

    goldFindMultiplier = multiplier;
    ApplyGoldFind();
    WarbandSettingSet("goldfind.multiplier", multiplier);
    return true;
}

void ResetWarbandGoldFindMultiplier()
{
    goldFindMultiplier = 1.0f;
    ApplyGoldFind();
    WarbandSettingSet("goldfind.multiplier", 1.0);
}

class WarbandGoldFind final : public WorldScript
{
public:
    WarbandGoldFind() : WorldScript("WarbandGoldFind") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        float configured = sConfigMgr->GetOption<float>("Warband.GoldFind.Multiplier", DefaultGoldFindMultiplier);

        if (!std::isfinite(configured) || configured < MinGoldFindMultiplier ||
            configured > MaxGoldFindMultiplier)
        {
            LOG_ERROR(
                "server.loading",
                "Warband: Warband.GoldFind.Multiplier ({}) must be between {} and {}, using 1.0",
                configured,
                MinGoldFindMultiplier,
                MaxGoldFindMultiplier);
            configured = 1.0f;
        }

        // A saved value wins over the configuration default, so a change made in game survives the
        // restart; only a value inside the accepted range is taken.
        float const saved = float(WarbandSettingGet("goldfind.multiplier", configured));
        if (std::isfinite(saved) && saved >= MinGoldFindMultiplier && saved <= MaxGoldFindMultiplier)
            configured = saved;

        goldFindMultiplier = configured;
        ApplyGoldFind();

        LOG_INFO("server.loading", "Warband gold find: looted coin x{}", goldFindMultiplier);
    }
};

void AddSC_warband_goldfind()
{
    new WarbandGoldFind();
}

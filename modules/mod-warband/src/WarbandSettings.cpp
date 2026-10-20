/*
 * WoW Warband server settings.
 *
 * Two multipliers apply to experience:
 *
 *   1. the server-wide Warband XP multiplier, adjustable live with `.warband xp`;
 *   2. the follower catch-up multiplier, which applies only to a bot piloted for a real player
 *      and grows with how far behind its leader it is.
 *
 * Both are applied in OnPlayerGiveXP, which the core calls before the amount is granted and
 * which receives every experience gain: kills, quests, exploration and battlegrounds. Bots are
 * ordinary Player objects, so the same hook covers them.
 *
 * Catch-up is deliberately linear and lives entirely in this module: there is no core change and
 * no edit to Playerbots. The bot's leader comes from PlayerbotAI::GetMaster(), and only a bot
 * whose master is a real (non-headless) session counts, so the random bots that populate the
 * world are never affected.
 */

#include "Config.h"
#include "ItemBinding.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WarbandPersistence.h"
#include "WarbandPlayerRoles.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <string>

// The random world bots are a playerbots concern; the module owns the switch behind them so the
// panel can turn the population off and pin its size. This reads the configured behaviour once,
// which is what the panel reports when nothing has been changed.
void InitWarbandRandomBots();

namespace
{
constexpr float DefaultXpRate = 2.0f;
constexpr float MinimumXpRate = 1.0f;
constexpr float MaximumXpRate = 10.0f;

constexpr float DefaultCatchUpPerLevel = 0.10f;
constexpr float MaximumCatchUpPerLevel = 10.0f;
constexpr float MaximumCatchUpMultiplier = 100.0f;

float xpRate = DefaultXpRate;

bool catchUpEnabled = true;
float catchUpPerLevel = DefaultCatchUpPerLevel;
float catchUpFloor = 1.0f;
float catchUpCap = 0.0f;

bool catchUpDebug = false;
uint32 catchUpApplications = 0;
std::chrono::steady_clock::time_point lastCatchUpLog = std::chrono::steady_clock::now();

// Counts every application, so `.warband catchup` can report how often the bonus has been
// granted and the feature is verifiable without reading logs. When debugging is on it also logs
// a sample, at most once per second.
void CountCatchUp(Player* follower, Player* master, uint32 gap, float multiplier, uint32 before,
    uint32 after)
{
    ++catchUpApplications;

    if (!catchUpDebug)
        return;

    std::chrono::steady_clock::time_point const now = std::chrono::steady_clock::now();
    if (now - lastCatchUpLog < std::chrono::seconds(1))
        return;

    lastCatchUpLog = now;
    LOG_INFO("module",
        "Warband catch-up: {} level {} is {} behind {} level {} -> x{:.2f} ({} -> {} XP)",
        follower->GetName(), follower->GetLevel(), gap, master->GetName(), master->GetLevel(),
        multiplier, before, after);
}
}

float GetWarbandXpRate()
{
    return xpRate;
}

bool SetWarbandXpRate(float rate)
{
    if (rate < MinimumXpRate || rate > MaximumXpRate || std::floor(rate) != rate)
        return false;

    xpRate = rate;
    WarbandSettingSet("xp.rate", rate);
    return true;
}

bool GetWarbandCatchUpEnabled()
{
    return catchUpEnabled;
}

float GetWarbandCatchUpPerLevel()
{
    return catchUpPerLevel;
}

float GetWarbandCatchUpFloor()
{
    return catchUpFloor;
}

float GetWarbandCatchUpCap()
{
    return catchUpCap;
}

uint32 GetWarbandCatchUpApplications()
{
    return catchUpApplications;
}

bool SetWarbandCatchUpEnabled(bool enabled)
{
    catchUpEnabled = enabled;
    WarbandSettingSet("catchup.enabled", enabled ? 1.0 : 0.0);
    return true;
}

bool SetWarbandCatchUpPerLevel(float value)
{
    if (!std::isfinite(value) || value < 0.0f || value > MaximumCatchUpPerLevel)
        return false;

    catchUpPerLevel = value;
    WarbandSettingSet("catchup.perlevel", value);
    return true;
}

bool SetWarbandCatchUpFloor(float value)
{
    if (!std::isfinite(value) || value < 1.0f || value > MaximumCatchUpMultiplier)
        return false;

    catchUpFloor = value;
    WarbandSettingSet("catchup.floor", value);
    return true;
}

bool SetWarbandCatchUpCap(float value)
{
    // 0 means "no cap".
    if (!std::isfinite(value) || value < 0.0f || value > MaximumCatchUpMultiplier)
        return false;

    catchUpCap = value;
    WarbandSettingSet("catchup.cap", value);
    return true;
}

// The multiplier a follower receives for being `gap` levels behind. Kept as a pure function so
// the curve can be reasoned about, and tested, without a running server.
float WarbandCatchUpMultiplier(uint32 gap, float perLevel, float floorValue, float cap)
{
    if (gap == 0)
        return 1.0f;

    float multiplier = 1.0f + (perLevel * float(gap));
    multiplier = std::max(multiplier, floorValue);

    if (cap > 0.0f)
        multiplier = std::min(multiplier, cap);

    return multiplier;
}

float WarbandCatchUpMultiplier(uint32 gap)
{
    return WarbandCatchUpMultiplier(gap, catchUpPerLevel, catchUpFloor, catchUpCap);
}

class WarbandSettings final : public PlayerScript, public WorldScript
{
public:
    WarbandSettings() : PlayerScript("WarbandSettings"), WorldScript("WarbandSettings") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        float configuredRate = sConfigMgr->GetOption<float>("Warband.XP.Rate", DefaultXpRate);
        if (configuredRate < MinimumXpRate || configuredRate > MaximumXpRate ||
            std::floor(configuredRate) != configuredRate)
        {
            LOG_ERROR(
                "server.loading",
                "Warband.XP.Rate ({}) must be a whole number in range 1..10. Using default value ({}).",
                configuredRate,
                DefaultXpRate);
            configuredRate = DefaultXpRate;
        }

        xpRate = configuredRate;

        // A saved value wins over the configuration default, so a change made in game survives a
        // restart. Only a value the setter would also accept is taken.
        float const savedRate = float(WarbandSettingGet("xp.rate", configuredRate));
        if (savedRate >= MinimumXpRate && savedRate <= MaximumXpRate &&
            std::floor(savedRate) == savedRate)
        {
            xpRate = savedRate;
        }

        catchUpEnabled = sConfigMgr->GetOption<bool>("Warband.CatchUp.Enabled", true);
        catchUpDebug = sConfigMgr->GetOption<bool>("Warband.CatchUp.Debug", false);

        float configuredStep = sConfigMgr->GetOption<float>("Warband.CatchUp.PerLevel", DefaultCatchUpPerLevel);
        if (!std::isfinite(configuredStep) || configuredStep < 0.0f || configuredStep > MaximumCatchUpPerLevel)
        {
            LOG_ERROR(
                "server.loading",
                "Warband.CatchUp.PerLevel ({}) must be between 0 and {}. Using default value ({}).",
                configuredStep,
                MaximumCatchUpPerLevel,
                DefaultCatchUpPerLevel);
            configuredStep = DefaultCatchUpPerLevel;
        }

        catchUpPerLevel = configuredStep;

        float configuredFloor = sConfigMgr->GetOption<float>("Warband.CatchUp.MinMultiplier", 1.0f);
        if (!std::isfinite(configuredFloor) || configuredFloor < 1.0f || configuredFloor > MaximumCatchUpMultiplier)
        {
            LOG_ERROR(
                "server.loading",
                "Warband.CatchUp.MinMultiplier ({}) must be between 1 and {}. Using 1.",
                configuredFloor,
                MaximumCatchUpMultiplier);
            configuredFloor = 1.0f;
        }

        catchUpFloor = configuredFloor;

        float configuredCap = sConfigMgr->GetOption<float>("Warband.CatchUp.MaxMultiplier", 0.0f);
        if (!std::isfinite(configuredCap) || configuredCap < 0.0f || configuredCap > MaximumCatchUpMultiplier)
        {
            LOG_ERROR(
                "server.loading",
                "Warband.CatchUp.MaxMultiplier ({}) must be between 0 and {}; 0 disables the cap. Using 0.",
                configuredCap,
                MaximumCatchUpMultiplier);
            configuredCap = 0.0f;
        }

        catchUpCap = configuredCap;

        // Saved values win over the configuration defaults, clamped to the accepted ranges.
        catchUpEnabled = WarbandSettingGet("catchup.enabled", catchUpEnabled ? 1.0 : 0.0) != 0.0;
        catchUpDebug = WarbandSettingGet("catchup.debug", catchUpDebug ? 1.0 : 0.0) != 0.0;
        catchUpPerLevel = std::clamp(
            float(WarbandSettingGet("catchup.perlevel", catchUpPerLevel)), 0.0f, MaximumCatchUpPerLevel);
        catchUpFloor = std::clamp(
            float(WarbandSettingGet("catchup.floor", catchUpFloor)), 1.0f, MaximumCatchUpMultiplier);
        catchUpCap = std::clamp(
            float(WarbandSettingGet("catchup.cap", catchUpCap)), 0.0f, MaximumCatchUpMultiplier);

        // The binding policy lives in the core, because the core is what asks whether an item may
        // move; the module owns the setting behind it and pushes it in. Default is the Warband rule:
        // binding does not restrict gear.
        bool const bindingDefault = sConfigMgr->GetOption<bool>("Warband.Binding.Enforced", false);
        WarbandSetItemBindingEnforced(
            WarbandSettingGet("binding.enforced", bindingDefault ? 1.0 : 0.0) != 0.0);

        LOG_INFO("server.loading", "Warband XP multiplier set to {}x", xpRate);
        LOG_INFO(
            "server.loading",
            "Warband catch-up {}: +{} per level behind, floor {}, cap {}",
            catchUpEnabled ? "enabled" : "disabled",
            catchUpPerLevel,
            catchUpFloor,
            catchUpCap > 0.0f ? std::to_string(catchUpCap) : std::string("uncapped"));
        LOG_INFO(
            "server.loading",
            "Warband item binding {}",
            WarbandIsItemBindingEnforced()
                ? "enforced: bound items stay put"
                : "not enforced: bound items can be traded, mailed and sold");

        // The random bots that roam the world are ambient, not Warband. The module reports the
        // configured state so the panel and `.warband randombots` start where the playerbots
        // configuration says they should.
        InitWarbandRandomBots();
    }

    void OnPlayerGiveXP(Player* player, uint32& amount, Unit* /*victim*/, uint8 /*xpSource*/) override
    {
        if (!player || !amount)
            return;

        amount = uint32(float(amount) * xpRate);

        if (!catchUpEnabled)
            return;

        Player* master = WarbandFollowerMaster(player);
        if (!master)
            return;

        uint32 const followerLevel = player->GetLevel();
        uint32 const masterLevel = master->GetLevel();
        if (masterLevel <= followerLevel)
            return;

        float const multiplier = WarbandCatchUpMultiplier(masterLevel - followerLevel);
        if (multiplier <= 1.0f)
            return;

        uint32 const before = amount;
        amount = uint32(float(amount) * multiplier);

        CountCatchUp(player, master, masterLevel - followerLevel, multiplier, before, amount);
    }
};

void AddSC_warband_settings()
{
    new WarbandSettings();
}

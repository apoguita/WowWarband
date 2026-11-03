/*
 * WoW Warband out-of-combat regeneration.
 *
 * Two multipliers, one on the mana a character regenerates while out of combat and one on the health,
 * because a party of five standing around between pulls should be ready for the next one in seconds
 * rather than in half a minute. Defaults are x4 for mana and x2 for health; both are configurable
 * from the Warband panel, both persist through WarbandPersistence, and both are applied live - there
 * is nothing to reload and no restart to forget.
 *
 * Where the two halves of the core compute this:
 *
 *  - mana: Player::Regenerate(POWER_MANA) reads UNIT_FIELD_POWER_REGEN_FLAT_MODIFIER for the "not
 *    under the five second rule" case and the INTERRUPTED field for the other. Only what was computed
 *    while the player is out of combat reaches the hook, so the multiplier cannot touch a fight, and
 *    the five second rule still applies to its own reduced figure.
 *  - health: Player::RegenerateHealth() computes the out-of-combat amount, then adds the "always"
 *    bonuses. The hook is called between the two, so what is multiplied is the out-of-combat part
 *    alone.
 *
 * The hook is PLAYERHOOK_ON_MODIFY_OUT_OF_COMBAT_REGEN, which this module asked the core for; the
 * Warband policy is to implement features here, so the core change is the two call sites and the hook
 * itself, nothing behavioural. Everything on top - the values, their bounds, their defaults and their
 * storage - lives here.
 *
 * Scope: every player, companions included, and no creature. A multiplier of x1 is a no-op, so a
 * server that has never touched the setting regenerates exactly as AzerothCore ships.
 */

#include "Config.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WarbandPersistence.h"

#include <cmath>

namespace
{
constexpr float MinRegenMultiplier = 1.0f;
constexpr float MaxRegenMultiplier = 20.0f;

constexpr float DefaultManaRegenMultiplier = 4.0f;
constexpr float DefaultHealthRegenMultiplier = 2.0f;

float manaRegenMultiplier = DefaultManaRegenMultiplier;
float healthRegenMultiplier = DefaultHealthRegenMultiplier;

char const* const ManaSettingKey = "regen.mana";
char const* const HealthSettingKey = "regen.health";

bool ValidMultiplier(float multiplier)
{
    return std::isfinite(multiplier) && multiplier >= MinRegenMultiplier &&
        multiplier <= MaxRegenMultiplier;
}

// A saved row wins over the configuration file, and a value outside the accepted range is ignored on
// both sides of that sentence: a hand-edited table entry must not be able to stop regeneration.
float ResolveMultiplier(char const* key, float configured)
{
    float const saved = float(WarbandSettingGet(key, configured));

    return ValidMultiplier(saved) ? saved : configured;
}
}

float GetWarbandManaRegenMultiplier()
{
    return manaRegenMultiplier;
}

float GetWarbandHealthRegenMultiplier()
{
    return healthRegenMultiplier;
}

bool SetWarbandManaRegenMultiplier(float multiplier)
{
    if (!ValidMultiplier(multiplier))
    {
        return false;
    }

    manaRegenMultiplier = multiplier;
    WarbandSettingSet(ManaSettingKey, multiplier);
    return true;
}

bool SetWarbandHealthRegenMultiplier(float multiplier)
{
    if (!ValidMultiplier(multiplier))
    {
        return false;
    }

    healthRegenMultiplier = multiplier;
    WarbandSettingSet(HealthSettingKey, multiplier);
    return true;
}

// Back to what the configuration file ships: x4 mana, x2 health. Not x1 - the shipped default is the
// default, and the point of the reset button is to undo a player's experiments, not to turn the
// feature off.
void ResetWarbandRegenMultipliers()
{
    SetWarbandManaRegenMultiplier(DefaultManaRegenMultiplier);
    SetWarbandHealthRegenMultiplier(DefaultHealthRegenMultiplier);
}

class WarbandRegen final : public PlayerScript
{
public:
    WarbandRegen() : PlayerScript("WarbandRegen", { PLAYERHOOK_ON_MODIFY_OUT_OF_COMBAT_REGEN }) { }

    void OnPlayerModifyOutOfCombatRegen(Player* player, Powers power, float& amount) override
    {
        if (!player || amount <= 0.0f)
        {
            return;
        }

        if (power == POWER_MANA)
        {
            amount *= manaRegenMultiplier;
        }
        else if (power == POWER_HEALTH)
        {
            amount *= healthRegenMultiplier;
        }
    }
};

class WarbandRegenConfig final : public WorldScript
{
public:
    WarbandRegenConfig() : WorldScript("WarbandRegenConfig") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        float configuredMana = sConfigMgr->GetOption<float>("Warband.Regen.Mana", DefaultManaRegenMultiplier);
        if (!ValidMultiplier(configuredMana))
        {
            LOG_ERROR("server.loading",
                "Warband: Warband.Regen.Mana ({}) must be between {} and {}, using {}",
                configuredMana, MinRegenMultiplier, MaxRegenMultiplier, DefaultManaRegenMultiplier);
            configuredMana = DefaultManaRegenMultiplier;
        }

        float configuredHealth =
            sConfigMgr->GetOption<float>("Warband.Regen.Health", DefaultHealthRegenMultiplier);
        if (!ValidMultiplier(configuredHealth))
        {
            LOG_ERROR("server.loading",
                "Warband: Warband.Regen.Health ({}) must be between {} and {}, using {}",
                configuredHealth, MinRegenMultiplier, MaxRegenMultiplier, DefaultHealthRegenMultiplier);
            configuredHealth = DefaultHealthRegenMultiplier;
        }

        manaRegenMultiplier = ResolveMultiplier(ManaSettingKey, configuredMana);
        healthRegenMultiplier = ResolveMultiplier(HealthSettingKey, configuredHealth);

        LOG_INFO("server.loading", "Warband regeneration: out of combat mana x{}, health x{}",
            manaRegenMultiplier, healthRegenMultiplier);
    }
};

void AddSC_warband_regen()
{
    new WarbandRegen();
    new WarbandRegenConfig();
}

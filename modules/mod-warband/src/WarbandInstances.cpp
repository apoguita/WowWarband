/*
 * WoW Warband: instances stop restocking.
 *
 * A five-member Warband fights its way through a dungeon slowly, and the base game keeps putting the
 * cleared trash back. This module makes "dead" mean dead for the run: when a creature dies inside a
 * dungeon or raid, its respawn is pushed out of reach and the new time is saved to the character
 * database, so the corridor stays cleared even if the instance unloads and is loaded again later.
 *
 * What it deliberately does not do: nothing about instance resets. An explicit reset - the client's
 * "Reset all instances", a GM reset, or the daily reset hour - still deletes the saved respawn
 * times and brings the whole dungeon back. That is what a reset is for.
 *
 * Scope, stated plainly: dungeons and raids only, and only creatures killed by the party. Open
 * world respawns are untouched. A creature or instance that must keep respawning can be named in
 * the NeverAdjust lists.
 *
 * The mechanism mirrors mod-dead-means-dead (see .agents/reference), minus its multiplier model:
 * the effect here is binary. The reference sets the delay at death and never re-applies it, because
 * the respawn time it writes is a database row anyway; that row is what survives an unload.
 */

#include "Config.h"
#include "Creature.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "ScriptMgr.h"

#include <cstdlib>
#include <string>
#include <vector>

namespace
{
// Ten years. SetRespawnTime(0) would mean "respawn immediately", so a long delay is how "never"
// is expressed.
constexpr uint32 FarFutureRespawnDelay = 315360000;

bool noRespawnEnabled = true;
uint32 keptDead = 0;

std::vector<uint32> neverCreatureIds;
std::vector<uint32> neverInstanceIds;

bool InList(uint32 value, std::vector<uint32> const& list)
{
    for (uint32 const listed : list)
    {
        if (listed == value)
        {
            return true;
        }
    }

    return false;
}

// Space-separated creature or map ids, as written in the configuration.
std::vector<uint32> ParseIds(std::string const& text)
{
    std::vector<uint32> ids;

    char const* cursor = text.c_str();

    while (*cursor)
    {
        while (*cursor == ' ' || *cursor == '\t')
        {
            ++cursor;
        }

        if (!*cursor)
        {
            break;
        }

        char* end = nullptr;
        unsigned long const parsed = std::strtoul(cursor, &end, 10);

        if (end == cursor)
        {
            break;
        }

        ids.push_back(static_cast<uint32>(parsed));
        cursor = end;
    }

    return ids;
}

// A kill counts as the party's kill when a player did it, or when something a player controls did
// it - a follower's pet, a totem, a guardian.
bool KilledByParty(Unit* killer)
{
    if (!killer)
    {
        return false;
    }

    if (killer->ToPlayer())
    {
        return true;
    }

    Unit* owner = killer->GetCharmerOrOwner();

    return owner && owner->ToPlayer();
}
}

bool GetWarbandInstanceNoRespawn()
{
    return noRespawnEnabled;
}

bool SetWarbandInstanceNoRespawn(bool enabled)
{
    noRespawnEnabled = enabled;
    return true;
}

uint32 GetWarbandInstanceKeptDead()
{
    return keptDead;
}

class WarbandInstances final : public UnitScript, public WorldScript
{
public:
    WarbandInstances() : UnitScript("WarbandInstances"), WorldScript("WarbandInstances") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        noRespawnEnabled = sConfigMgr->GetOption<bool>("Warband.Instances.NoRespawn", true);
        neverCreatureIds = ParseIds(sConfigMgr->GetOption<std::string>(
            "Warband.Instances.NeverAdjust.CreatureID", ""));
        neverInstanceIds = ParseIds(sConfigMgr->GetOption<std::string>(
            "Warband.Instances.NeverAdjust.InstanceID", ""));

        LOG_INFO(
            "server.loading",
            "Warband instances stop restocking: {} (never-adjust lists: {} creature(s), {} instance(s))",
            noRespawnEnabled ? "enabled" : "disabled",
            uint32(neverCreatureIds.size()),
            uint32(neverInstanceIds.size()));
    }

    void OnUnitDeath(Unit* unit, Unit* killer) override
    {
        if (!noRespawnEnabled)
        {
            return;
        }

        Creature* creature = unit ? unit->ToCreature() : nullptr;
        if (!creature)
        {
            return;
        }

        Map* map = creature->GetMap();
        if (!map || (!map->IsDungeon() && !map->IsRaid()))
        {
            return;
        }

        if (InList(map->GetId(), neverInstanceIds) || InList(creature->GetEntry(), neverCreatureIds))
        {
            return;
        }

        // Open-world kills are not this feature's business, and a kill nothing in the party made is
        // left to the ordinary timers.
        if (!KilledByParty(killer))
        {
            return;
        }

        creature->SetRespawnDelay(FarFutureRespawnDelay);
        creature->SetRespawnTime(FarFutureRespawnDelay);

        // This is the part that survives an instance unload: the row in `creature_respawn`.
        creature->SaveRespawnTime();

        ++keptDead;
    }
};

void AddSC_warband_instances()
{
    new WarbandInstances();
}

/*
 * WoW Warband: the Dungeon Finder travels the party, it never queues.
 *
 * A Warband is one player and the companions following them, so a queue has nobody to match with
 * and would wait forever - which is exactly what the finder does today. What the finder does have
 * is everything a travel menu needs: the dungeon list its client draws, the entrance coordinates
 * of every dungeon, and the server's own rules for who may enter which one. So the pick becomes the
 * order to travel: select a dungeon, press Find Group, and the whole party stands at that dungeon.
 *
 * The work happens in the join hook, which the core calls from LFGMgr::JoinLfg after the packet is
 * parsed and before the queue is touched. Refusing the join keeps the queue out of the picture -
 * nothing is queued, no role check starts, no proposal is created - so the teleport is the whole
 * answer to the click.
 *
 * What is kept from the retail finder on purpose:
 *
 *  - Player::TeleportTo runs its own checks before anybody moves: level, attunement, difficulty
 *    availability, "you must be in a raid group" for a raid, and the hourly instance limit. A
 *    refusal therefore arrives in the game's own words, and travel is no shortcut past them.
 *  - The destination is the finder's own entrance row, the same one the retail teleport uses, so
 *    every dungeon that can be queued for can be travelled to.
 *  - Getting back out is the retail way as well: the entry point is recorded before the jump, so
 *    the instance's exit portal returns the party to where it came from.
 *
 * A Random pick becomes one dungeon out of the pool the finder would have picked from - the same
 * client list group, minus everything the finder would not let this character enter - so the
 * random boxes lead somewhere this party can actually fight.
 */

#include "DBCStores.h"
#include "Group.h"
#include "LFGMgr.h"
#include "Log.h"
#include "Map.h"
#include "Player.h"
#include "Random.h"
#include "ScriptMgr.h"
#include "WorldSession.h"

#include <set>
#include <string>
#include <vector>

namespace
{
// The finder's copy of a dungeon, entrance included. The coordinates come from
// `lfg_dungeon_template`, or from the map's entrance areatrigger when the table has no row; a
// dungeon with neither cannot be travelled to and is left alone.
bool HasEntrance(lfg::LFGDungeonData const* dungeon)
{
    return dungeon && dungeon->map != 0 &&
        !(dungeon->x == 0.0f && dungeon->y == 0.0f && dungeon->z == 0.0f);
}

// The dungeons one Random box stands for: every dungeon of that box's own group in the client's
// list, except the ones the finder would have refused this character - level, expansion,
// attunement, instance lock - which is the same list the retail match would have drawn from.
uint32 PickFromRandomPool(Player* player, lfg::LFGDungeonData const* random)
{
    if (!random)
    {
        return 0;
    }

    sLFGMgr->InitializeLockedDungeons(player, player->GetGroup());
    lfg::LfgLockMap const& locked = sLFGMgr->GetLockedDungeons(player->GetGUID());

    std::vector<uint32> pool;

    for (LFGDungeonEntry const* entry : sLFGDungeonStore)
    {
        if (entry->TypeID != lfg::LFG_TYPE_DUNGEON && entry->TypeID != lfg::LFG_TYPE_HEROIC)
        {
            continue;
        }

        if (uint8(entry->GroupID) != random->group)
        {
            continue;
        }

        if (locked.find(entry->Entry()) != locked.end())
        {
            continue;
        }

        if (!HasEntrance(sLFGMgr->GetLFGDungeon(entry->ID)))
        {
            continue;
        }

        pool.push_back(entry->ID);
    }

    if (pool.empty())
    {
        return 0;
    }

    return pool[urand(0, uint32(pool.size()) - 1)];
}

// The destination for one click: a box that names a dungeon names that dungeon, a Random box is
// widened into the dungeon it stands for. Several boxes ticked means any of them is acceptable,
// which is what queueing for several would have meant, so one is drawn at random.
uint32 ChooseDungeon(Player* player, std::set<uint32> const& picked)
{
    std::vector<uint32> candidates;

    for (uint32 const id : picked)
    {
        LFGDungeonEntry const* entry = sLFGDungeonStore.LookupEntry(id);
        if (!entry)
        {
            continue;
        }

        if (entry->TypeID == lfg::LFG_TYPE_RANDOM)
        {
            if (uint32 const resolved = PickFromRandomPool(player, sLFGMgr->GetLFGDungeon(id)))
            {
                candidates.push_back(resolved);
            }

            continue;
        }

        candidates.push_back(id);
    }

    if (candidates.empty())
    {
        return 0;
    }

    return candidates[urand(0, uint32(candidates.size()) - 1)];
}

// The entry carries the difficulty it stands for - normal, heroic, or one of the raid sizes - so
// the party's setting follows it before the jump, the way a heroic pick lands in a heroic
// instance. Instance saves are keyed by map and difficulty, so this chooses which copy of the
// dungeon is entered; it does not reset anything that is already saved.
void MatchDifficulty(Player* player, lfg::LFGDungeonData const* dungeon)
{
    MapEntry const* entry = sMapStore.LookupEntry(dungeon->map);
    bool const raid = entry && entry->IsRaid();
    Difficulty const wanted = dungeon->difficulty;
    uint32 const knownDifficulties = raid ? MAX_RAID_DIFFICULTY : MAX_DUNGEON_DIFFICULTY;

    // An entry carrying a difficulty this build does not have is left to the group's own setting;
    // PlayerCannotEnter reports an unavailable difficulty better than a guess here would.
    if (uint32(wanted) >= knownDifficulties)
    {
        return;
    }

    if (Group* group = player->GetGroup())
    {
        if (raid ? group->GetRaidDifficulty() == wanted : group->GetDungeonDifficulty() == wanted)
        {
            return;
        }

        if (raid)
        {
            group->SetRaidDifficulty(wanted);
        }
        else
        {
            group->SetDungeonDifficulty(wanted);
        }

        return;
    }

    if (raid)
    {
        player->SetRaidDifficulty(wanted);
        player->SendRaidDifficulty(false);
    }
    else
    {
        player->SetDungeonDifficulty(wanted);
        player->SendDungeonDifficulty(false);
    }
}

// The companions travel too: a Warband split over two maps is not a Warband. Only members already
// in the world are moved - a member still loading has no map to leave from - and the player goes
// first so the instance the party shares is the one their own click opened.
void Travel(Player* player, uint32 dungeonId)
{
    lfg::LFGDungeonData const* dungeon = sLFGMgr->GetLFGDungeon(dungeonId);
    if (!HasEntrance(dungeon))
    {
        player->GetSession()->SendAreaTriggerMessage("The Dungeon Finder has no way into that dungeon.");
        return;
    }

    MatchDifficulty(player, dungeon);

    uint32 const map = dungeon->map;
    float const x = dungeon->x;
    float const y = dungeon->y;
    float const z = dungeon->z;
    float const o = dungeon->o;

    std::vector<Player*> followers;

    if (Group* group = player->GetGroup())
    {
        for (GroupReference* ref = group->GetFirstMember(); ref != nullptr; ref = ref->next())
        {
            Player* member = ref->GetSource();
            if (member && member != player && member->IsInWorld() && !member->IsBeingTeleported())
            {
                followers.push_back(member);
            }
        }
    }

    // Where the instance's exit portal puts each traveller back. Recorded before the jump, and
    // only from solid ground, exactly as the finder's own teleport does it.
    if (!player->GetMap()->IsDungeon() || player->GetEntryPoint().GetMapId() == MAPID_INVALID)
    {
        player->SetEntryPoint();
    }

    if (!player->TeleportTo(map, x, y, z, o, 0, nullptr, map == player->GetMapId()))
    {
        player->GetSession()->SendAreaTriggerMessage("You cannot travel to that dungeon right now.");
        return;
    }

    LOG_INFO("module", "Warband dungeon finder: {} travels to {} (map {}, {} party member(s) follow)",
        player->GetName(), dungeon->name, map, uint32(followers.size()));

    for (Player* follower : followers)
    {
        if (!follower->IsAlive())
        {
            LOG_INFO("module", "Warband dungeon finder: {} stays behind, dead", follower->GetName());
            continue;
        }

        if (!follower->GetMap()->IsDungeon() || follower->GetEntryPoint().GetMapId() == MAPID_INVALID)
        {
            follower->SetEntryPoint();
        }

        if (!follower->TeleportTo(map, x, y, z, o, 0, nullptr, map == follower->GetMapId()))
        {
            LOG_INFO("module", "Warband dungeon finder: {} could not follow to map {}",
                follower->GetName(), map);
        }
    }
}
}

class WarbandDungeonFinder final : public PlayerScript
{
public:
    WarbandDungeonFinder() : PlayerScript("WarbandDungeonFinder", { PLAYERHOOK_CAN_JOIN_LFG }) { }

    // Reads the pick and answers it with the teleport. Returning false is what makes the finder a
    // travel menu rather than a queue: the core stops before any queue, role check or proposal is
    // created, and the click has already been answered.
    bool OnPlayerCanJoinLfg(Player* player, uint8 /*roles*/, std::set<uint32>& picked,
        std::string const& /*comment*/) override
    {
        if (!player || picked.empty())
        {
            return true;
        }

        // Queueing from a battleground was never allowed here (JoinBGAndLFG.Enable is off), and a
        // teleport is a way out of the match, so it is refused in the same terms.
        if (player->InBattleground())
        {
            player->GetSession()->SendAreaTriggerMessage(
                "The Dungeon Finder does not travel out of a battleground.");
            return false;
        }

        if (!player->IsAlive())
        {
            player->GetSession()->SendAreaTriggerMessage("You cannot travel to a dungeon while dead.");
            return false;
        }

        if (player->IsInCombat())
        {
            player->GetSession()->SendAreaTriggerMessage("You cannot travel from combat.");
            return false;
        }

        uint32 const dungeonId = ChooseDungeon(player, picked);
        if (!dungeonId)
        {
            player->GetSession()->SendAreaTriggerMessage(
                "The Dungeon Finder has nowhere to send you for that pick.");
            return false;
        }

        Travel(player, dungeonId);
        return false;
    }
};

void AddSC_warband_dungeonfinder()
{
    new WarbandDungeonFinder();
}

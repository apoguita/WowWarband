/*
 * WoW Warband follower gathering.
 *
 * The leader keeps the crafting professions; followers only need to gather for the party. That is
 * enough, because Playerbots already harvests: LootAction casts the mining and herbalism spells on
 * nodes and the skinning spell on corpses whenever the bot has the matching skill, and a node's
 * lock is checked against the bot's skill value. So giving a follower the leader's gathering skill
 * values is what makes it able to work the same nodes.
 *
 * The mirror runs on four occasions:
 *
 *   - the leader logs in,
 *   - a follower joins the group, which is the trigger that matters most, because followers
 *     normally join after the leader is already in the world,
 *   - OnPlayerUpdateSkill fires, which is every point a gathering skill gains while playing,
 *   - OnPlayerSetSkill fires, which is a trained rank, .setskill, or a profession being unlearned.
 *
 * The last two are what keeps the party in step mid game: a leader that grows from 100 to 125 takes
 * its followers with it, without anyone re-inviting anybody. A plain gain can never teach a new rank
 * spell, so that path copies values only and leaves the spell copy to the SetSkill hook, which keeps
 * it off the hot path.
 *
 * The mirror is a floor, never a ceiling. It only ever raises a follower, so a party member that was
 * trained further - or that was the character the player logged in as last session - keeps its own
 * gathering progress. Whoever the player is playing pushes their values out to the rest, and nobody
 * is ever dragged back down for having been the follower while someone else was the leader.
 *
 * Both hooks run on the map thread of the player whose skill changed, and a write only ever goes to a
 * follower on the same map, which is the same thread. That is the rule the whole file follows: it
 * never touches a player another thread owns.
 *
 * Only the skill line values and their rank spells are copied. Recipes are deliberately not: the
 * leader is the crafter, and copying every recipe to every follower would bloat their spell maps
 * and their update packets for no benefit. A gathering profession has no recipes anyway - only the
 * Apprentice..Master rank spells and the tracking spells.
 */

#include "Config.h"
#include "DBCStores.h"
#include "Group.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WarbandPlayerRoles.h"

#include <algorithm>
#include <array>
#include <string>

namespace
{
// Herbalism and Mining cover nodes, Skinning covers corpses. Nothing else is gathering.
constexpr std::array<uint16, 3> GatheringSkills = { SKILL_HERBALISM, SKILL_MINING, SKILL_SKINNING };

bool gatherMirrorEnabled = true;
bool gatherMirrorAutomatic = true;
uint32 gatherMirrorUpdatedFollowers = 0;
uint32 gatherMirrorApplications = 0;

// The skill hooks fire for every skill in the game, weapon skills included, so this filter comes
// first in both of them.
bool IsGatheringSkill(uint32 skillId)
{
    for (uint16 const gatheringSkill : GatheringSkills)
        if (gatheringSkill == skillId)
            return true;

    return false;
}

// Copies the rank spells the leader knows for one skill line. For a gathering profession these are
// a handful of spells: the rank that raises the cap plus the tracking spell.
void CopySkillLineSpells(Player* leader, Player* follower, uint16 skillId)
{
    for (SkillLineAbilityEntry const* ability : sSkillLineAbilityStore)
    {
        if (!ability || ability->SkillLine != skillId || !ability->Spell)
            continue;

        if (!leader->HasSpell(ability->Spell) || follower->HasSpell(ability->Spell))
            continue;

        follower->learnSpell(ability->Spell, false);
    }
}

// Copies the leader's gathering skills to one follower. Returns true when the follower changed.
//
// The rule is a floor, never a ceiling: the mirror only ever raises a follower, and only for the
// three gathering skills the leader actually has. A follower that is ahead - because it was trained
// further, or because it was the character the player logged in as in an earlier session - keeps
// what it has. That is what makes swapping which party member the player plays safe: nobody loses
// gathering progress for having been the follower while someone else was the leader.
bool MirrorGathering(Player* leader, Player* follower, bool copyRankSpells)
{
    if (!leader || !follower || leader == follower)
        return false;

    // Same map means the same map thread, which is what makes these writes safe.
    if (follower->GetMap() != leader->GetMap())
        return false;

    bool changed = false;

    for (uint16 const skillId : GatheringSkills)
    {
        if (!leader->HasSkill(skillId))
            continue;

        // What the leader actually shows: the effective value, capped at the leader's own maximum,
        // so a gathering enchant on the leader's gloves does not push a follower past its cap.
        uint16 const leaderMax = leader->GetPureMaxSkillValue(skillId);
        uint16 const source = std::min<uint16>(leader->GetSkillValue(skillId), leaderMax);

        // What the follower actually stores, which is what a write would replace.
        uint16 const stored = follower->GetPureSkillValue(skillId);
        uint16 const storedMax = follower->GetPureMaxSkillValue(skillId);

        uint16 const newValue = std::max(source, stored);
        uint16 const newMax = std::max(leaderMax, storedMax);

        if (newValue != stored || newMax != storedMax)
        {
            // A raised cap is the leader's rank, so the leader's step describes it too. Otherwise the
            // follower keeps its own tier.
            uint16 const step = leaderMax > storedMax ? leader->GetSkillStep(skillId) : follower->GetSkillStep(skillId);
            follower->SetSkill(skillId, step, newValue, newMax);
            changed = true;
        }

        if (copyRankSpells)
            CopySkillLineSpells(leader, follower, skillId);
    }

    if (changed)
    {
        ++gatherMirrorUpdatedFollowers;
        ++gatherMirrorApplications;
    }

    return changed;
}

// Mirrors the leader's gathering skills to every follower in the party. Returns how many changed.
uint32 MirrorParty(Player* leader, bool copyRankSpells)
{
    if (!gatherMirrorEnabled || !leader)
        return 0;

    Group* group = leader->GetGroup();
    if (!group)
        return 0;

    uint32 updated = 0;
    for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
    {
        Player* member = ref->GetSource();
        if (!member || member == leader)
            continue;

        // Map first: this is the cheap check, and it keeps the bot lookup off players that could
        // not be written to anyway.
        if (member->GetMap() != leader->GetMap())
            continue;

        if (!WarbandFollowerMaster(member))
            continue;

        if (MirrorGathering(leader, member, copyRankSpells))
            ++updated;
    }

    return updated;
}

// A gathering skill changed on one player. A leader takes the whole party with it; a follower that
// gained a point on its own keeps that point, and is raised to its leader if it is still behind.
void MirrorAfterSkillChange(Player* changed, uint32 skillId, bool copyRankSpells)
{
    if (!gatherMirrorEnabled || !gatherMirrorAutomatic || !changed)
        return;

    if (!IsGatheringSkill(skillId))
        return;

    if (Player* leader = WarbandFollowerMaster(changed))
    {
        MirrorGathering(leader, changed, copyRankSpells);
        return;
    }

    MirrorParty(changed, copyRankSpells);
}
}

bool GetWarbandGatherMirrorEnabled()
{
    return gatherMirrorEnabled;
}

bool GetWarbandGatherAutomatic()
{
    return gatherMirrorAutomatic;
}

uint32 GetWarbandGatherApplications()
{
    return gatherMirrorApplications;
}

bool SetWarbandGatherMirrorEnabled(bool enabled)
{
    gatherMirrorEnabled = enabled;
    return true;
}

bool SetWarbandGatherAutomatic(bool automatic)
{
    gatherMirrorAutomatic = automatic;
    return true;
}

// The on demand mirror used by .warband gather: values and rank spells, applied right now.
uint32 MirrorGatheringToParty(Player* leader)
{
    return MirrorParty(leader, true);
}

class WarbandGathering final : public PlayerScript, public GroupScript, public WorldScript
{
public:
    WarbandGathering() : PlayerScript("WarbandGathering"), GroupScript("WarbandGathering"),
        WorldScript("WarbandGathering") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        gatherMirrorEnabled = sConfigMgr->GetOption<bool>("Warband.Gather.Enabled", true);
        gatherMirrorAutomatic = sConfigMgr->GetOption<bool>("Warband.Gather.Automatic", true);

        LOG_INFO(
            "server.loading",
            "Warband follower gathering: {} (automatic on login, join and skill change: {})",
            gatherMirrorEnabled ? "enabled" : "disabled",
            gatherMirrorAutomatic ? "yes" : "no");
    }

    // A real player logging in gets its current followers matched straight away.
    void OnPlayerLogin(Player* player) override
    {
        if (!gatherMirrorAutomatic || !player)
            return;

        WorldSession* session = player->GetSession();
        if (!session || session->IsHeadless())
            return;

        MirrorGatheringToParty(player);
    }

    // Followers usually join after the leader is already in the world, so this is the trigger that
    // matters most: the moment a follower is added to the group it gets the leader's skills.
    void OnAddMember(Group* group, ObjectGuid guid) override
    {
        if (!gatherMirrorAutomatic || !group)
            return;

        Player* added = ObjectAccessor::FindConnectedPlayer(guid);
        if (!added || !WarbandFollowerMaster(added))
            return;

        Player* leader = ObjectAccessor::FindConnectedPlayer(group->GetLeaderGUID());
        if (!leader)
            return;

        MirrorGathering(leader, added, true);
    }

    // A skill gained a point while playing: the leader working a node, or a follower doing it on its
    // own. No rank spell can arrive this way, so the spell copy is skipped.
    void OnPlayerUpdateSkill(Player* player, uint32 skillId, uint32 /*value*/, uint32 /*max*/,
        uint32 /*step*/, uint32 /*newValue*/) override
    {
        MirrorAfterSkillChange(player, skillId, false);
    }

    // A skill was written wholesale: a rank trained, .setskill used, or a profession unlearned.
    // This is also how the mirror writes to a follower, and those events must not feed back into
    // another mirror, which is what the follower check below is for.
    void OnPlayerSetSkill(Player* player, uint32 skillId, uint32 /*value*/, uint32 /*max*/,
        uint32 /*step*/, uint32 /*newValue*/) override
    {
        if (!IsGatheringSkill(skillId))
            return;

        if (WarbandFollowerMaster(player))
            return;

        MirrorAfterSkillChange(player, skillId, true);
    }
};

void AddSC_warband_gathering()
{
    new WarbandGathering();
}

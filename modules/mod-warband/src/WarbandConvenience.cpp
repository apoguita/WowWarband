/*
 * WoW Warband convenience pair: a hearthstone without a cooldown, and pets that stay happy.
 *
 * Hearthstone. The core puts the cooldown on spell 8690 and its "There's No Place Like Home" twin
 * 39937 when the item is used. This file clears both the moment the hearthstone cast turns into a
 * teleport, and once on login, so the item is ready again immediately. The mechanism is the one
 * mod-no-hearthstone-cooldown uses (see .agents/reference); it is a few lines, which is why it lives
 * here instead of a dependency.
 *
 * Pets. A hunter pet's happiness is the POWER_HAPPINESS power, three steps of HAPPINESS_LEVEL_SIZE;
 * the core drains it on a timer in Pet::Update (LoseHappiness) and knocks a step off whenever the
 * pet dies. A follower cannot be told to feed its pet, so with a Warband the pet slides into
 * "unhappy" (damage penalty, StatSystem.cpp) and stays there. Keeping the power topped up is what a
 * player with a pet would do by hand. It covers every pet on the server, the leader's included,
 * because a happy pet is never a balance lever in a single-player party.
 */

#include "Config.h"
#include "Creature.h"
#include "DBCStores.h"
#include "Log.h"
#include "Pet.h"
#include "Player.h"
#include "QuestDef.h"
#include "ScriptMgr.h"
#include "WarbandPersistence.h"

#include <algorithm>

namespace
{
// WoWhead: spell=8690 is the Hearthstone, spell=39937 is the TBC "There's No Place Like Home" twin
// that some clients use for the same item.
constexpr uint32 HearthstoneSpell = 8690;
constexpr uint32 NoPlaceLikeHomeSpell = 39937;

bool hearthstoneAlwaysReady = true;
bool petsAlwaysHappy = true;
uint32 hearthstoneClears = 0;

// Quest scaling. Quests present at the highest multiple of Warband.Quests.ScaleStep already
// reached by the character, so a quest never slides into the gray band as the character levels.
// The core's quest-query packet shows that level (Warband deviation in GossipDef.cpp); this hook
// makes the awarded experience match what the player was shown. 0 disables the feature.
uint32 warbandQuestScaleStep = 5;
uint32 warbandQuestXpCorrections = 0;
}

bool GetWarbandHearthstoneAlwaysReady()
{
    return hearthstoneAlwaysReady;
}

bool SetWarbandHearthstoneAlwaysReady(bool enabled)
{
    hearthstoneAlwaysReady = enabled;
    WarbandSettingSet("convenience.hearthstone", enabled ? 1.0 : 0.0);
    return true;
}

bool GetWarbandPetsAlwaysHappy()
{
    return petsAlwaysHappy;
}

bool SetWarbandPetsAlwaysHappy(bool enabled)
{
    petsAlwaysHappy = enabled;
    WarbandSettingSet("convenience.pets", enabled ? 1.0 : 0.0);
    return true;
}

uint32 GetWarbandHearthstoneClears()
{
    return hearthstoneClears;
}

class WarbandConvenience final : public PlayerScript, public AllCreatureScript, public WorldScript
{
public:
    WarbandConvenience() :
        PlayerScript("WarbandConvenience",
            { PLAYERHOOK_ON_BEFORE_TELEPORT, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_QUEST_COMPUTE_EXP }),
        AllCreatureScript("WarbandConvenience"),
        WorldScript("WarbandConvenience") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        hearthstoneAlwaysReady = sConfigMgr->GetOption<bool>("Warband.Hearthstone.AlwaysReady", true);
        petsAlwaysHappy = sConfigMgr->GetOption<bool>("Warband.Pets.AlwaysHappy", true);
        warbandQuestScaleStep = sConfigMgr->GetOption<uint32>("Warband.Quests.ScaleStep", 5);
        if (warbandQuestScaleStep > 20)
            warbandQuestScaleStep = 20;

        // Saved values win over the configuration defaults.
        hearthstoneAlwaysReady =
            WarbandSettingGet("convenience.hearthstone", hearthstoneAlwaysReady ? 1.0 : 0.0) != 0.0;
        petsAlwaysHappy = WarbandSettingGet("convenience.pets", petsAlwaysHappy ? 1.0 : 0.0) != 0.0;

        LOG_INFO(
            "server.loading",
            "Warband convenience: hearthstone always ready {}, pets always happy {}, quest scale step {}",
            hearthstoneAlwaysReady ? "yes" : "no",
            petsAlwaysHappy ? "yes" : "no",
            warbandQuestScaleStep);
    }

    // The hearthstone's cast finishes into a teleport; that is the moment its cooldown starts, so
    // that is the moment to clear it.
    bool OnPlayerBeforeTeleport(Player* player, uint32 /*mapid*/, float /*x*/, float /*y*/,
        float /*z*/, float /*orientation*/, uint32 /*options*/, Unit* /*target*/) override
    {
        ClearHearthstone(player);
        return true;
    }

    // A hearthstone used before the module loaded keeps its old cooldown until the next login.
    void OnPlayerLogin(Player* player) override
    {
        ClearHearthstone(player);
    }

    // Quest experience must match the level the client was shown for the quest (see the Warband
    // deviation in GossipDef.cpp): price the quest at its presented level and keep the ratio, so
    // quest rates and auras that already multiplied the amount survive untouched.
    void OnPlayerQuestComputeXP(Player* player, Quest const* quest, uint32& xpValue) override
    {
        if (!warbandQuestScaleStep || !player || !quest || !xpValue)
            return;

        int32 const questLevel = quest->GetQuestLevel();
        if (questLevel <= 0 || questLevel >= 255)
            return;

        uint32 const reached =
            (uint32(player->GetLevel()) / warbandQuestScaleStep) * warbandQuestScaleStep;
        if (reached <= uint32(questLevel))
            return;

        uint32 const before = QuestXpAt(questLevel, player->GetLevel(), quest->GetXPId());
        uint32 const after = QuestXpAt(int32(reached), player->GetLevel(), quest->GetXPId());
        if (!before || !after)
            return;

        xpValue = uint32(std::min<uint64>(uint64(xpValue) * after / before, UINT32_MAX));
        ++warbandQuestXpCorrections;
    }

    // Pets: top the happiness power up whenever it has drained, instead of waiting for a feed that
    // no follower will ever perform.
    void OnAllCreatureUpdate(Creature* creature, uint32 /*diff*/) override
    {
        if (!petsAlwaysHappy || !creature)
            return;

        Pet* pet = creature->ToPet();
        if (!pet || pet->getPetType() != HUNTER_PET)
            return;

        uint32 const maxHappiness = pet->GetMaxPower(POWER_HAPPINESS);
        if (maxHappiness == 0 || pet->GetPower(POWER_HAPPINESS) >= maxHappiness)
            return;

        pet->SetPower(POWER_HAPPINESS, maxHappiness);
    }

private:
    // Quest::XPValue's arithmetic with the quest level under our control, so the presented level
    // can be priced exactly like the core prices a quest of that level. Keep in sync with
    // QuestDef.cpp::Quest::XPValue if the core formula ever changes.
    static uint32 QuestXpAt(int32 questLevel, uint8 playerLevel, uint32 xpId)
    {
        QuestXPEntry const* xpentry = sQuestXPStore.LookupEntry(questLevel);
        if (!xpentry || xpId >= 10)
            return 0;

        int32 diffFactor = 2 * (questLevel - int32(playerLevel)) + 20;
        if (diffFactor < 1)
            diffFactor = 1;
        else if (diffFactor > 10)
            diffFactor = 10;

        uint32 xp = diffFactor * xpentry->Exp[xpId] / 10;
        if (xp <= 100)
        {
            xp = 5 * ((xp + 2) / 5);
        }
        else if (xp <= 500)
        {
            xp = 10 * ((xp + 5) / 10);
        }
        else if (xp <= 1000)
        {
            xp = 25 * ((xp + 12) / 25);
        }
        else
        {
            xp = 50 * ((xp + 25) / 50);
        }

        return xp;
    }

    static void ClearHearthstone(Player* player)
    {
        if (!hearthstoneAlwaysReady || !player)
            return;

        // Only when the hearthstone is what is being cast: clearing cooldowns on every teleport
        // would be a blunt instrument on a server with portals and summons.
        if (!player->FindCurrentSpellBySpellId(HearthstoneSpell))
            return;

        player->RemoveSpellCooldown(HearthstoneSpell, true);
        player->RemoveSpellCooldown(NoPlaceLikeHomeSpell, true);
        player->SendClearCooldown(HearthstoneSpell, player);
        player->SendClearCooldown(NoPlaceLikeHomeSpell, player);

        ++hearthstoneClears;
    }
};

void AddSC_warband_convenience()
{
    new WarbandConvenience();
}

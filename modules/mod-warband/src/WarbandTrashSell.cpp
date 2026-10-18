/*
 * WoW Warband trash auto-sell.
 *
 * The point is bag space, not money. A Warband of five characters loots five times as much junk,
 * and a follower's bags cannot be opened and emptied by hand the way the leader's can, so grey
 * loot is sold the moment it is picked up: the vendor price is credited to the leader's purse and
 * the item is destroyed before it has a chance to accumulate. The leader is the only purse the
 * player can see, so routing the copper there makes the feature honest: the panel reports what the
 * party's own junk actually paid, and the party's coin stays in one place instead of filling bags
 * of followers nobody can open.
 *
 * Where it hangs: PlayerScript::OnPlayerLootItem, which the core raises at the end of the ordinary
 * pickup path (Player.cpp, after StoreNewItem and SendNewItem) for every Player, followers
 * included. The item is already in the bags at that point, so an item that fits is sold
 * immediately, and a bag that is already full still refuses the pickup - which is what
 * .warband trash sell is for. The sweep pays the leader as well, whoever held the item.
 *
 * The counters are per Warband, keyed by the leader's GUID and reset when that leader logs in, so
 * the panel never mixes the party's sales with random bots looting somewhere else in the world.
 *
 * What is never sold: quest-class items, items that start a quest, and anything an accepted quest
 * still needs. A grey with no vendor price is left alone rather than deleted for nothing, and an
 * item whose price cannot be credited (gold cap) stays in the bag instead of disappearing.
 *
 * Not copied from the module that inspired this (mod-junk-to-gold-plus): its "keep grey armour and
 * weapons that beat what is equipped" rule, which never fires for vendor trash here, and its
 * function-local static config reads, which make a config reload invisible. This file reads the
 * configuration in OnAfterConfigLoad like the rest of the module.
 */

#include "Bag.h"
#include "Config.h"
#include "Group.h"
#include "Item.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WarbandPlayerRoles.h"

#include <algorithm>
#include <unordered_map>
#include <utility>
#include <vector>

// Provided by WarbandAoeLoot.cpp: the looting module's own on/off state.
bool WarbandAoeLootInstalled();
bool GetWarbandAoeLootEnabled();

namespace
{
bool trashSellEnabled = true;

// One Warband's ledger: what its own grey sales paid since the leader logged in.
struct TrashLedger
{
    uint32 items = 0;
    uint64 copper = 0;
};

// Keyed by the leader's GUID. The panel only ever asks for the character running the command, so
// a random bot's ledger (or another Warband's) never shows up there.
std::unordered_map<ObjectGuid, TrashLedger> warbandLedgers;

// The player whose purse receives the vendor price: the leader for a follower's sale, the looter
// otherwise. A real player is the Warband's leader; a follower is its master.
Player* WarbandTrashPayee(Player* looter)
{
    if (!looter)
        return nullptr;

    Player* master = WarbandFollowerMaster(looter);
    return master ? master : looter;
}

// A grey item is sellable when nothing about it is worth keeping: it is not quest-bound, no active
// quest wants it, and a vendor would actually pay for it. A worthless grey is left in the bags,
// because destroying it would be a silent deletion rather than a sale.
bool IsSellableTrash(Player* player, ItemTemplate const* proto)
{
    if (!player || !proto)
        return false;

    if (proto->Quality != ITEM_QUALITY_POOR)
        return false;

    if (proto->Class == ITEM_CLASS_QUEST || proto->StartQuest != 0)
        return false;

    if (proto->SellPrice == 0)
        return false;

    return !player->HasQuestForItem(proto->ItemId);
}
}

bool GetWarbandTrashSellEnabled()
{
    return trashSellEnabled;
}

bool SetWarbandTrashSellEnabled(bool enabled)
{
    trashSellEnabled = enabled;
    return true;
}

uint32 GetWarbandTrashSoldItems(Player* leader)
{
    if (!leader)
        return 0;

    auto it = warbandLedgers.find(leader->GetGUID());
    return it == warbandLedgers.end() ? 0 : it->second.items;
}

uint64 GetWarbandTrashSoldCopper(Player* leader)
{
    if (!leader)
        return 0;

    auto it = warbandLedgers.find(leader->GetGUID());
    return it == warbandLedgers.end() ? 0 : it->second.copper;
}

// Sells one item from the holder's bags, paying the vendor price to the Warband's leader. Returns
// the copper paid, or zero when the item is not trash, or when the payment was refused and the
// item was left where it is.
uint64 WarbandSellTrash(Player* holder, Item* item)
{
    if (!holder || !item)
        return 0;

    ItemTemplate const* proto = item->GetTemplate();
    if (!IsSellableTrash(holder, proto))
        return 0;

    Player* payee = WarbandTrashPayee(holder);
    if (!payee)
        return 0;

    uint32 const count = std::max<uint32>(item->GetCount(), 1);
    uint64 const copper = uint64(proto->SellPrice) * uint64(count);

    // Positions are read before the item goes away; DestroyItem then removes it from that exact
    // slot and the update is flushed to the client.
    uint8 const bagSlot = item->GetBagSlot();
    uint8 const slot = item->GetSlot();

    // A refused credit (gold cap) must not delete the item: sell only what the purse accepted.
    if (!payee->ModifyMoney(int32(copper)))
        return 0;

    holder->DestroyItem(bagSlot, slot, true);

    TrashLedger& ledger = warbandLedgers[payee->GetGUID()];
    ++ledger.items;
    ledger.copper += copper;

    return copper;
}

// Sweeps one character's bags, backpack and equipped bags alike, paying the Warband's leader for
// every sale. Positions are collected first so that destroying an item cannot disturb the walk,
// and then sold one by one; removing an item from a bag does not shift its neighbours, so the
// collected positions stay valid.
uint32 WarbandSellTrashInBags(Player* holder)
{
    if (!holder)
        return 0;

    std::vector<std::pair<uint8, uint8>> positions;

    for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
    {
        Item* item = holder->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (item && IsSellableTrash(holder, item->GetTemplate()))
            positions.emplace_back(INVENTORY_SLOT_BAG_0, slot);
    }

    for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
    {
        Bag* bag = holder->GetBagByPos(bagSlot);
        if (!bag)
            continue;

        for (uint8 slot = 0; slot < bag->GetBagSize(); ++slot)
        {
            Item* item = bag->GetItemByPos(slot);
            if (item && IsSellableTrash(holder, item->GetTemplate()))
                positions.emplace_back(bagSlot, slot);
        }
    }

    uint32 sold = 0;
    for (std::pair<uint8, uint8> const& position : positions)
    {
        Item* item = holder->GetItemByPos(position.first, position.second);
        if (item && WarbandSellTrash(holder, item))
            ++sold;
    }

    return sold;
}

// The leader plus every follower in its party. Same map only, for the same reason the gathering
// mirror checks it: those writes belong to the map thread that owns the character.
uint32 WarbandSellTrashInParty(Player* leader)
{
    if (!leader)
        return 0;

    uint32 sold = WarbandSellTrashInBags(leader);

    Group* group = leader->GetGroup();
    if (!group)
        return sold;

    for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
    {
        Player* member = ref->GetSource();
        if (!member || member == leader)
            continue;

        if (member->GetMap() != leader->GetMap())
            continue;

        if (WarbandFollowerMaster(member) != leader)
            continue;

        sold += WarbandSellTrashInBags(member);
    }

    return sold;
}

class WarbandTrashSell final : public PlayerScript, public WorldScript
{
public:
    WarbandTrashSell() : PlayerScript(
                             "WarbandTrashSell",
                             { PLAYERHOOK_ON_LOOT_ITEM, PLAYERHOOK_ON_LOGIN, PLAYERHOOK_ON_AFTER_CREATURE_LOOT }),
        WorldScript("WarbandTrashSell") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        trashSellEnabled = sConfigMgr->GetOption<bool>("Warband.TrashSell.Enabled", true);

        LOG_INFO("server.loading", "Warband trash sell: {}", trashSellEnabled ? "enabled" : "disabled");
    }

    // Raised from the core pickup path for the character doing the looting: the real player, or a
    // follower clearing the corpse it killed. Both are the point of the feature.
    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootGuid*/) override
    {
        if (!trashSellEnabled)
            return;

        WarbandSellTrash(player, item);
    }

    // mod-aoe-loot merges nearby corpses' loot and stores the chosen item on its own path, which
    // does not raise OnPlayerLootItem - so a grey taken from a merged window would sit in the bags
    // until the next sweep. When area looting is enabled, sweep the bags once after that store,
    // which sells exactly the same grey to the same leader purse. When it is off, the ordinary
    // pickup hook above already does the work and this does nothing.
    void OnPlayerAfterCreatureLoot(Player* player) override
    {
        if (!trashSellEnabled || !WarbandAoeLootInstalled() || !GetWarbandAoeLootEnabled())
            return;

        WarbandSellTrashInBags(player);
    }

    // A Warband's ledger belongs to one play session: the leader's panel starts at zero on login.
    void OnPlayerLogin(Player* player) override
    {
        if (player)
            warbandLedgers.erase(player->GetGUID());
    }
};

void AddSC_warband_trashsell()
{
    new WarbandTrashSell();
}

/*
 * WoW Warband trash auto-sell.
 *
 * The point is bag space, not money. A Warband of five characters loots five times as much junk,
 * and a follower's bags cannot be opened and emptied by hand the way the leader's can, so grey
 * loot is sold the moment it is picked up: the vendor price is credited to whoever looted it, and
 * the item is destroyed before it has a chance to accumulate. Nobody has to care which purse the
 * copper lands in, because the copper is not the feature.
 *
 * Where it hangs: PlayerScript::OnPlayerLootItem, which the core raises at the end of the ordinary
 * pickup path (Player.cpp, after StoreNewItem and SendNewItem) for every Player, followers
 * included. The item is already in the bags at that point, so an item that fits is sold
 * immediately, and a bag that is already full still refuses the pickup - which is what
 * .warband trash sell is for.
 *
 * What is never sold: quest-class items, items that start a quest, and anything an accepted quest
 * still needs. A grey with no vendor price is left alone rather than deleted for nothing.
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
#include <utility>
#include <vector>

namespace
{
bool trashSellEnabled = true;

// Session counters, reported by .warband trash and shown on the panel page.
uint32 trashSoldItems = 0;
uint64 trashSoldCopper = 0;

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

uint32 GetWarbandTrashSoldItems()
{
    return trashSoldItems;
}

uint64 GetWarbandTrashSoldCopper()
{
    return trashSoldCopper;
}

// Sells one item, paying its vendor price to the character holding it. Returns the copper paid, or
// zero when the item is not trash and was left alone.
uint64 WarbandSellTrash(Player* player, Item* item)
{
    if (!player || !item)
        return 0;

    ItemTemplate const* proto = item->GetTemplate();
    if (!IsSellableTrash(player, proto))
        return 0;

    uint32 const count = std::max<uint32>(item->GetCount(), 1);
    uint64 const copper = uint64(proto->SellPrice) * uint64(count);

    // Positions are read before the item goes away; DestroyItem then removes it from that exact
    // slot and the update is flushed to the client.
    uint8 const bagSlot = item->GetBagSlot();
    uint8 const slot = item->GetSlot();

    player->ModifyMoney(int32(copper));
    player->DestroyItem(bagSlot, slot, true);

    ++trashSoldItems;
    trashSoldCopper += copper;

    return copper;
}

// Sweeps one character's bags, backpack and equipped bags alike. Positions are collected first so
// that destroying an item cannot disturb the walk, and then sold one by one; removing an item from
// a bag does not shift its neighbours, so the collected positions stay valid.
uint32 WarbandSellTrashInBags(Player* player)
{
    if (!player)
        return 0;

    std::vector<std::pair<uint8, uint8>> positions;

    for (uint8 slot = INVENTORY_SLOT_ITEM_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
    {
        Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
        if (item && IsSellableTrash(player, item->GetTemplate()))
            positions.emplace_back(INVENTORY_SLOT_BAG_0, slot);
    }

    for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
    {
        Bag* bag = player->GetBagByPos(bagSlot);
        if (!bag)
            continue;

        for (uint8 slot = 0; slot < bag->GetBagSize(); ++slot)
        {
            Item* item = bag->GetItemByPos(slot);
            if (item && IsSellableTrash(player, item->GetTemplate()))
                positions.emplace_back(bagSlot, slot);
        }
    }

    uint32 sold = 0;
    for (std::pair<uint8, uint8> const& position : positions)
    {
        Item* item = player->GetItemByPos(position.first, position.second);
        if (item && WarbandSellTrash(player, item))
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

        if (!WarbandFollowerMaster(member))
            continue;

        sold += WarbandSellTrashInBags(member);
    }

    return sold;
}

class WarbandTrashSell final : public PlayerScript, public WorldScript
{
public:
    WarbandTrashSell() : PlayerScript("WarbandTrashSell", { PLAYERHOOK_ON_LOOT_ITEM }),
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
};

void AddSC_warband_trashsell()
{
    new WarbandTrashSell();
}

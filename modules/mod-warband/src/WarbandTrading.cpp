/*
 * WoW Warband bound gear sharing - the client side of it.
 *
 * The rule itself lives in the core: `WarbandIsItemBindingEnforced()` in Item.cpp gates the two
 * questions the server asks before an item moves - `Item::CanBeTraded()` and
 * `Item::IsBindedNotWith()`. With the rule off, which is the Warband default, a bound item is
 * movable server side through every path: trade, mail, auction, guild bank and the MultiBot
 * inventory transfer.
 *
 * What the core cannot decide is what the client already believes. The client greys out items it
 * thinks are bound, and it decides that from the same tradeable flag the game uses for the two hour
 * loot-trade window. This module sets that flag on the bound items a Warband member is carrying, so
 * the trade window offers them the way it offers any other item, and the panel's toggle still
 * governs everything: with binding enforced, nothing here does anything.
 *
 * The grant is transient by design. It is never written to item_soulbound_trade_data, the core
 * strips the flag again on the next login, and the next grant re-applies it.
 */

#include "Bag.h"
#include "Group.h"
#include "ItemBinding.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WarbandPlayerRoles.h"

namespace
{
// True when both players belong to the same Warband: a leader and its own follower, or two
// followers of the same leader. Random bots, and anyone else's followers, are never a pair.
bool IsWarbandPair(Player* first, Player* second)
{
    if (!first || !second || first == second)
        return false;

    Player* firstMaster = WarbandFollowerMaster(first);
    Player* secondMaster = WarbandFollowerMaster(second);

    if (firstMaster && firstMaster == second)
        return true;

    if (secondMaster && secondMaster == first)
        return true;

    return firstMaster && firstMaster == secondMaster;
}

// The leader a follower follows, or the player itself when it is the leader being played.
Player* WarbandOwner(Player* player)
{
    if (Player* master = WarbandFollowerMaster(player))
        return master;

    return player;
}

// Everyone in this player's Warband: the leader being played plus the followers in its group. A
// bound item carried by any of them may be handed to any other, which is the whole rule.
void CollectWarband(Player* leader, Group* group, AllowedLooterSet& allowed)
{
    allowed.insert(leader->GetGUID());

    for (GroupReference* ref = group->GetFirstMember(); ref; ref = ref->next())
    {
        Player* member = ref->GetSource();
        if (!member || member == leader)
            continue;

        if (WarbandOwner(member) == leader)
            allowed.insert(member->GetGUID());
    }
}

// The set to grant, or false when there is nobody to share with. A lone player - a random bot, or a
// real player whose companions have not joined yet - is left completely alone, which is also what
// keeps this off the loot path of the hundreds of random bots in the world.
bool BuildWarbandSet(Player* player, AllowedLooterSet& allowed)
{
    if (!player)
        return false;

    Player* leader = WarbandOwner(player);
    Group* group = leader->GetGroup();
    if (!group)
        return false;

    CollectWarband(leader, group, allowed);
    return allowed.size() > 1;
}

void GrantTradeOnItem(Item* item, AllowedLooterSet& allowed)
{
    if (!item || !item->IsSoulBound())
        return;

    item->SetSoulboundTradeable(allowed);
}

// Opens the trade window on every bound item this player is carrying. Only the bags and the
// equipped slots matter: nothing in the bank can be dragged into a trade window, and nothing in the
// bank can be handed to a follower either.
void GrantTradeOnCarriedItems(Player* owner, AllowedLooterSet& allowed)
{
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        GrantTradeOnItem(owner->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), allowed);

    for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
    {
        GrantTradeOnItem(owner->GetItemByPos(INVENTORY_SLOT_BAG_0, bagSlot), allowed);

        if (Bag* bag = owner->GetBagByPos(bagSlot))
            for (uint8 slot = 0; slot < bag->GetBagSize(); ++slot)
                GrantTradeOnItem(bag->GetItemByPos(slot), allowed);
    }
}

void GrantWarbandTradeOnCarriedItems(Player* player)
{
    // With binding enforced there is nothing to keep in step: the client already treats a bound item
    // as bound, because that is what it is.
    if (WarbandIsItemBindingEnforced())
        return;

    AllowedLooterSet allowed;
    if (!BuildWarbandSet(player, allowed))
        return;

    GrantTradeOnCarriedItems(player, allowed);
}

void GrantWarbandTradeOnItem(Player* player, Item* item)
{
    if (WarbandIsItemBindingEnforced())
        return;

    AllowedLooterSet allowed;
    if (!BuildWarbandSet(player, allowed))
        return;

    GrantTradeOnItem(item, allowed);
}
}

class WarbandTrading final : public PlayerScript
{
public:
    WarbandTrading() : PlayerScript("WarbandTrading") { }

    // Items already carried when the character logs in: a piece looted in an earlier session is
    // just as shareable as one looted a minute ago.
    void OnPlayerLogin(Player* player) override
    {
        GrantWarbandTradeOnCarriedItems(player);
    }

    // A new piece, and a piece that changed hands. Loot, creation, quest rewards, mail, a trade
    // completing and a follower's own pickups all pass through one of these two.
    void OnPlayerStoreNewItem(Player* player, Item* item, uint32 /*count*/) override
    {
        GrantWarbandTradeOnItem(player, item);
    }

    void OnPlayerAfterMoveItemToInventory(Player* player, Item* item, bool /*update*/) override
    {
        GrantWarbandTradeOnItem(player, item);
    }

    // Opening a trade names the exact pair, so the allowed set is narrowed to the two players
    // involved for the duration, and both directions are granted so a follower can hand a piece
    // back just as easily.
    bool OnPlayerCanInitTrade(Player* player, Player* target) override
    {
        if (!WarbandIsItemBindingEnforced() && IsWarbandPair(player, target) &&
            player->GetMap() == target->GetMap())
        {
            AllowedLooterSet allowed;
            allowed.insert(player->GetGUID());
            allowed.insert(target->GetGUID());

            GrantTradeOnCarriedItems(player, allowed);
            GrantTradeOnCarriedItems(target, allowed);
        }

        // Never refuse a trade here: this is a grant, not a gate, and the core keeps its own checks.
        return true;
    }
};

void AddSC_warband_trading()
{
    new WarbandTrading();
}

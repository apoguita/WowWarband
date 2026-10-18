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
 * thinks are bound, and it refuses a soulbound item in the trade window before any tradeable flag
 * is considered. So while binding is unenforced this module removes the soulbound bit itself from
 * the bound items a player is carrying (the client only offers trade for items it thinks are
 * unbound) and also sets the tradeable flag, which keeps the other paths in step. The panel's
 * toggle still governs everything: with binding enforced, nothing here does anything and items keep
 * their ordinary binding.
 *
 * The grant is not scoped to a party. The played character's carried items are granted at login
 * and when a piece arrives, and a trade window is granted on both sides the moment it opens, so a
 * bound piece can be handed to a follower, an alt outside the group or any other character: the
 * Warband has no rule that needs a recipient. Random bots are skipped on the loot path, because
 * they loot constantly and never offer bound gear of their own - that keeps this off the hundreds
 * of bots' loot path - but a trade window opened with a real player grants both sides.
 *
 * The grant is transient by design. It is never written to item_soulbound_trade_data, the core
 * strips the flag again on the next login, and the next grant re-applies it.
 */

#include "Bag.h"
#include "ItemBinding.h"
#include "Log.h"
#include "Player.h"
#include "ScriptMgr.h"
#include "WarbandPlayerRoles.h"

namespace
{
// The grant is for the character being played: a real player with a session, not a bot. Random
// bots use it too through the trade window, where the pair is explicit, but their endless loot is
// not walked.
bool IsPlayedCharacter(Player* player)
{
    return player && !sPlayerbotsMgr.GetPlayerbotAI(player);
}

// Grants the trade on one item. Returns true when the item was soulbound and has now been
// unbound for the client.
//
// The 2h tradeable flag (ITEM_FIELD_FLAG_BOP_TRADEABLE) is not enough for this client: a soulbound
// item is refused in the trade window before the flag is considered (observed in game, 18 October
// 2026). So while binding is unenforced the soulbound bit itself is removed from the carried item -
// the client only offers trade for items it thinks are unbound. The tradeable flag is set as well,
// which keeps the other paths (mail, auction, the trade finalize checks) in step with the same
// state. With binding enforced none of this runs and items keep their ordinary binding.
bool GrantTradeOnItem(Item* item, AllowedLooterSet& allowed)
{
    if (!item || !item->IsSoulBound())
        return false;

    item->SetBinding(false);
    item->SetSoulboundTradeable(allowed);
    return true;
}

// Opens the trade, mail and auction windows on every bound item this player is carrying. Only the
// bags and the equipped slots matter: nothing in the bank can be dragged into a trade window, and
// nothing in the bank can be handed to another character either. Returns how many items now carry
// the flag.
uint32 GrantTradeOnCarriedItems(Player* owner, AllowedLooterSet& allowed)
{
    if (!owner)
        return 0;

    uint32 granted = 0;

    for (uint8 slot = EQUIPMENT_SLOT_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        if (GrantTradeOnItem(owner->GetItemByPos(INVENTORY_SLOT_BAG_0, slot), allowed))
            ++granted;

    for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
    {
        if (GrantTradeOnItem(owner->GetItemByPos(INVENTORY_SLOT_BAG_0, bagSlot), allowed))
            ++granted;

        if (Bag* bag = owner->GetBagByPos(bagSlot))
            for (uint8 slot = 0; slot < bag->GetBagSize(); ++slot)
                if (GrantTradeOnItem(bag->GetItemByPos(slot), allowed))
                    ++granted;
    }

    return granted;
}

void GrantWarbandTradeOnCarriedItems(Player* player)
{
    // With binding enforced there is nothing to keep in step: the client already treats a bound item
    // as bound, because that is what it is.
    if (WarbandIsItemBindingEnforced() || !IsPlayedCharacter(player))
        return;

    AllowedLooterSet allowed;
    allowed.insert(player->GetGUID());

    uint32 const granted = GrantTradeOnCarriedItems(player, allowed);

    if (granted)
        LOG_INFO("server.loading", "Warband trading: granted {} carried item(s) at login ({})", granted,
            player->GetName());
}

void GrantWarbandTradeOnItem(Player* player, Item* item)
{
    if (WarbandIsItemBindingEnforced() || !IsPlayedCharacter(player))
        return;

    AllowedLooterSet allowed;
    allowed.insert(player->GetGUID());

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

    // Opening a trade names the exact pair, so both sides are granted unconditionally: a bound
    // piece can be handed to a follower, an alt outside the group or any other character. The core
    // keeps its own checks - distance, bags, items being looted right now.
    bool OnPlayerCanInitTrade(Player* player, Player* target) override
    {
        if (!WarbandIsItemBindingEnforced() && player && target)
        {
            AllowedLooterSet allowed;
            allowed.insert(player->GetGUID());
            allowed.insert(target->GetGUID());

            uint32 const first = GrantTradeOnCarriedItems(player, allowed);
            uint32 const second = GrantTradeOnCarriedItems(target, allowed);

            LOG_INFO("server.loading", "Warband trading: trade {} <-> {}: granted {} / {} item(s)",
                player->GetName(), target->GetName(), first, second);
        }

        // Never refuse a trade here: this is a grant, not a gate, and the core keeps its own checks.
        return true;
    }
};

void AddSC_warband_trading()
{
    new WarbandTrading();
}

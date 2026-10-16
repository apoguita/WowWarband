#include "Bag.h"
#include "Item.h"
#include "Player.h"
#include "ScriptMgr.h"

namespace
{
void UnbindItem(Player* player, Item* item)
{
    if (!item || !item->IsSoulBound())
        return;

    item->SetBinding(false);
    item->SetState(ITEM_CHANGED, player);
}

void UnbindBagContents(Player* player, uint8 bagSlot)
{
    if (Bag* bag = player->GetBagByPos(bagSlot))
        for (uint8 slot = 0; slot < bag->GetBagSize(); ++slot)
            UnbindItem(player, bag->GetItemByPos(slot));
}

void UnbindStoredItems(Player* player)
{
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        UnbindItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

    for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
    {
        UnbindItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, bagSlot));
        UnbindBagContents(player, bagSlot);
    }

    for (uint8 slot = BANK_SLOT_ITEM_START; slot < BANK_SLOT_ITEM_END; ++slot)
        UnbindItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

    for (uint8 bagSlot = BANK_SLOT_BAG_START; bagSlot < BANK_SLOT_BAG_END; ++bagSlot)
    {
        UnbindItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, bagSlot));
        UnbindBagContents(player, bagSlot);
    }

    for (uint8 slot = KEYRING_SLOT_START; slot < KEYRING_SLOT_END; ++slot)
        UnbindItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

    for (uint8 slot = CURRENCYTOKEN_SLOT_START; slot < CURRENCYTOKEN_SLOT_END; ++slot)
        UnbindItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));
}
} // namespace

class WarbandUnboundLoot final : public PlayerScript
{
public:
    WarbandUnboundLoot() : PlayerScript("WarbandUnboundLoot") { }

    void OnPlayerLogin(Player* player) override
    {
        UnbindStoredItems(player);
    }

    void OnPlayerStoreNewItem(Player* player, Item* item, uint32 /*count*/) override
    {
        UnbindItem(player, item);
    }

    void OnPlayerAfterMoveItemToInventory(Player* player, Item* item, bool /*update*/) override
    {
        UnbindItem(player, item);
    }

    void OnPlayerAfterTakeItemFromMail(Player* player, Item* item, uint32 /*count*/) override
    {
        UnbindItem(player, item);
    }

    void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
    {
        UnbindItem(player, item);
    }

    void OnPlayerLootItem(Player* player, Item* item, uint32 /*count*/, ObjectGuid /*lootGuid*/) override
    {
        UnbindItem(player, item);
    }

    void OnPlayerCreateItem(Player* player, Item* item, uint32 /*count*/) override
    {
        UnbindItem(player, item);
    }

    void OnPlayerQuestRewardItem(Player* player, Item* item, uint32 /*count*/) override
    {
        UnbindItem(player, item);
    }

    void OnPlayerGroupRollRewardItem(Player* player, Item* item, uint32 /*count*/, RollVote /*voteType*/, Roll* /*roll*/) override
    {
        UnbindItem(player, item);
    }
};

void AddSC_warband_unbound_loot()
{
    new WarbandUnboundLoot();
}

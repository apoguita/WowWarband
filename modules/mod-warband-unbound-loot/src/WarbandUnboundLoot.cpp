#include "Bag.h"
#include "Item.h"
#include "Player.h"
#include "ScriptMgr.h"

namespace
{
bool IsQuestTemplateItem(Item const* item)
{
    if (ItemTemplate const* itemTemplate = item->GetTemplate())
        return itemTemplate->Bonding == BIND_QUEST_ITEM || itemTemplate->Bonding == BIND_QUEST_ITEM1;

    return false;
}

void UnbindOrdinaryItem(Player* player, Item* item)
{
    if (!item || !item->IsSoulBound() || IsQuestTemplateItem(item))
        return;

    item->SetBinding(false);
    item->SetState(ITEM_CHANGED, player);
}

void UnbindBagContents(Player* player, uint8 bagSlot)
{
    if (Bag* bag = player->GetBagByPos(bagSlot))
        for (uint8 slot = 0; slot < bag->GetBagSize(); ++slot)
            UnbindOrdinaryItem(player, bag->GetItemByPos(slot));
}

void UnbindStoredItems(Player* player)
{
    for (uint8 slot = EQUIPMENT_SLOT_START; slot < INVENTORY_SLOT_ITEM_END; ++slot)
        UnbindOrdinaryItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

    for (uint8 bagSlot = INVENTORY_SLOT_BAG_START; bagSlot < INVENTORY_SLOT_BAG_END; ++bagSlot)
    {
        UnbindOrdinaryItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, bagSlot));
        UnbindBagContents(player, bagSlot);
    }

    for (uint8 slot = BANK_SLOT_ITEM_START; slot < BANK_SLOT_ITEM_END; ++slot)
        UnbindOrdinaryItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

    for (uint8 bagSlot = BANK_SLOT_BAG_START; bagSlot < BANK_SLOT_BAG_END; ++bagSlot)
    {
        UnbindOrdinaryItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, bagSlot));
        UnbindBagContents(player, bagSlot);
    }

    for (uint8 slot = KEYRING_SLOT_START; slot < KEYRING_SLOT_END; ++slot)
        UnbindOrdinaryItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));

    for (uint8 slot = CURRENCYTOKEN_SLOT_START; slot < CURRENCYTOKEN_SLOT_END; ++slot)
        UnbindOrdinaryItem(player, player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot));
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
        UnbindOrdinaryItem(player, item);
    }

    void OnPlayerAfterMoveItemToInventory(Player* player, Item* item, bool /*update*/) override
    {
        UnbindOrdinaryItem(player, item);
    }

    void OnPlayerAfterTakeItemFromMail(Player* player, Item* item, uint32 /*count*/) override
    {
        UnbindOrdinaryItem(player, item);
    }

    void OnPlayerEquip(Player* player, Item* item, uint8 /*bag*/, uint8 /*slot*/, bool /*update*/) override
    {
        UnbindOrdinaryItem(player, item);
    }
};

void AddSC_warband_unbound_loot()
{
    new WarbandUnboundLoot();
}

# mod-warband-unbound-loot

`mod-warband-unbound-loot` is the migration half of WoW Warband's binding-free
item policy. It clears existing soulbound flags from a character's stored items
when that character logs in, including inventory, bank, keyring, and currency
slots. It also clears an item after loot, creation, a quest reward, a group-roll
reward, mail retrieval, movement, or equipping.

The policy itself is enforced by the in-house core changes in `Item.h` and
`Item.cpp`: new binding requests do not set the soulbound flag, and normal item
transfer no longer rejects an item because it is soulbound or has a binding
enchant.

The core item layer cannot tell a Warband transfer from another transfer, so the
rule applies to every character on this single-player realm. It is not suitable
unchanged for a realm with unrelated human players.

## What remains separate from binding

The binding-free rule deliberately does not alter:

- unique-item limits, key ownership, inventory-space rules, or equipment
  requirements; or
- quest rewards, progression, party eligibility, or automated distribution.

The client may still display an item's original Bind on Pickup/Equip/Use text
because those template labels come from client item data. This implementation
changes the server rules: those labels do not cause binding or block transfer.

Quest-use handling, reward delivery, and the item-routing interface remain
separate Warband work. They must not reintroduce binding restrictions.

## Activation

The module is discovered by the AzerothCore module build system because it has a
`src/` directory. It has no runtime configuration and makes no database changes.

The binding policy also changes core item code, so that part requires rebuilding
the shared `game` library and `worldserver`, then restarting the server. The
current `RelWithDebInfo` build completed successfully with the module as its own
DLL. The runtime was not started, so activation still needs a startup check.

After activation, changes confined to this module can be built with
`Build-WarbandModules.bat mod-warband-unbound-loot`; edits to the core item rules
still require a core/server rebuild.

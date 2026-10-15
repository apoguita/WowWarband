# mod-warband-unbound-loot

`mod-warband-unbound-loot` is a small AzerothCore server module for the WoW
Warband prototype. It removes the soulbound flag from ordinary items after they
are acquired, moved into inventory, or equipped. This lets a leader route normal
Bind on Pickup and Bind on Equip gear to a companion without changing item
templates or client files.

## Deliberate scope

The module covers the normal item-instance soulbound flag for existing and newly
received equipment. It does not change:

- quest-template items (`BIND_QUEST_ITEM` and `BIND_QUEST_ITEM1`);
- bindings caused by permanent or temporary enchants;
- unique-item limits, key ownership, inventory-space rules, or equipment
  requirements; or
- quest rewards, progression, party eligibility, or automated distribution.

Bind-on-use is also outside this module's immediate guarantee: the core applies
that flag directly in its item-use handler after the generic inventory hooks
have run. A complete Bind-on-use change needs a small core hook or patch and
must be evaluated separately.

This is a technical prototype, not a settled Warband loot policy. In particular,
quest-item transfer and broader progression consequences remain open design
questions.

## Activation

The module is discovered by the AzerothCore module build system because it has a
`src/` directory. It has no runtime configuration and makes no database changes.
It takes effect only after the server has been reconfigured, rebuilt, and
restarted with the module included. Those operational steps are intentionally
not performed by this change.

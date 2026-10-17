/*
 * Warband item binding policy - the project's one core change.
 *
 * Warband is a single-player party game: a bound item is bound to the party, not to one character,
 * so binding is not treated as a barrier to moving gear. The two questions the core asks before an
 * item moves both consult this policy:
 *
 *   Item::CanBeTraded()     - may this item be moved at all?
 *   Item::IsBindedNotWith() - may it move to this player?
 *
 * Both are defined in Item.cpp, which reads the flag below. Nothing else in the core changed.
 *
 * It defaults to the ordinary game rule, so a build without the Warband module behaves exactly as
 * AzerothCore does. The module sets it from Warband.Binding.Enforced when it loads its configuration
 * and again whenever the panel's Item binding page toggles it.
 *
 * This lives in its own header on purpose: putting it in Item.h would recompile every translation
 * unit that includes Item.h for a two-line change.
 */

#ifndef WARBAND_ITEM_BINDING_H
#define WARBAND_ITEM_BINDING_H

// True while binding restricts item movement, which is the ordinary game rule. False is the Warband
// rule: a soulbound item can be traded, mailed, auctioned, stored in a guild bank and handed to a
// companion like any other item, and an enchant that would bind it does not stop it either. The item
// keeps its own soulbound flag either way; only the answer to "may it move" changes.
[[nodiscard]] bool WarbandIsItemBindingEnforced();

// Set by the Warband module from Warband.Binding.Enforced and by .warband binding on | off.
void WarbandSetItemBindingEnforced(bool enforced);

#endif

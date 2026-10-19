/*
 * WoW Warband trade helpers shared by the module's trade surface.
 *
 * The trade window itself is the core's: a Warband follower fills its side by accepting what the
 * player puts there. What the core does not offer is a way to say "the companion is paying this
 * much" without whispering the bot twice, so this pair of functions does exactly that and nothing
 * more: it reads the trade the player already has open, and it writes the companion's side of it
 * through the same TradeData the core uses.
 */

#ifndef MOD_WARBAND_TRADE_H
#define MOD_WARBAND_TRADE_H

#include "Player.h"

// Why a fill did or did not happen, so the caller can say something useful instead of failing
// silently.
enum class WarbandTradeGold
{
    Ok,
    NoTrade,         // the player has no trade open, or the partner is no longer in one
    NotCompanion,    // the partner is another real player, whose purse is not ours to touch
    NoFunds,         // the companion does not carry that much
};

// Puts `copper` of the open trade's companion into their side of the trade. `partner` is set to the
// other side of the trade whenever there is one, so the caller can report who it was.
WarbandTradeGold WarbandFillTradeGold(Player* player, uint32 copper, Player*& partner);

// Reports the open trade: who it is with, what that companion's side currently holds, and what the
// companion is carrying. Returns false when no trade is open.
bool WarbandTradeState(Player* player, Player*& partner, uint32& tradeMoney, uint32& purse);

#endif

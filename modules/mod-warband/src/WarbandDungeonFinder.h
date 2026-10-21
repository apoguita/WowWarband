/*
 * WoW Warband destinations: every place the party can be sent, and the jump to any of them.
 *
 * The Dungeon Finder window cannot be the complete list. Its entries come from the client's own
 * LFGDungeons.dbc, which carries a level window per dungeon, and the client draws only the entries
 * whose window contains the character's level - so at 80 the classic dungeons are simply not drawn,
 * and no packet the server can send adds one back. Widening those windows would mean repacking the
 * client's archives, which is a client asset this repository does not own.
 *
 * So the list is the server's: every entry of the finder's dungeon table that has an entrance,
 * with its level window kept as information rather than used as a filter. Nothing is hidden,
 * greyed or dropped, and the choice belongs to the player.
 */

#ifndef MOD_WARBAND_DUNGEONFINDER_H
#define MOD_WARBAND_DUNGEONFINDER_H

#include "Player.h"

#include <string>
#include <vector>

// One destination. `kind` is the DBC's LfgType (lfg::LFG_TYPE_DUNGEON/RAID/HEROIC); `difficulty`
// is the DBC's Difficulty, which is what tells a 10-man raid entry from its 25-man sibling.
struct WarbandDestination
{
    uint32 id;
    uint32 map;
    uint8 kind;
    uint8 difficulty;
    uint8 minLevel;
    uint8 maxLevel;
    std::string name;
};

// Why a travel did or did not happen, so the caller can answer in words instead of failing
// silently.
enum class WarbandTravelResult
{
    Ok,
    UnknownDungeon,  // no such entry, or the finder has no entrance for it
    Dead,
    InCombat,
    InBattleground,
    Refused,         // the core's own teleport checks said no, in the game's own words
};

// Every destination, ordered the way a player reads a travel menu: dungeons by level, then heroics,
// then raids, and by name inside each group. Built fresh on each call, so it always reflects the
// data the running server actually has.
std::vector<WarbandDestination> WarbandDestinations();

// Travels the player and their party to `dungeonId` - the DBC entry id, not the 24-bit Entry()
// the finder mixes into its pick. The difficulty the party enters is the one the entry names.
WarbandTravelResult WarbandTravelTo(Player* player, uint32 dungeonId);

#endif

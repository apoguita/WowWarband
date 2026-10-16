/*
 * Shared helpers for deciding who is who in a Warband party.
 *
 * A follower is a bot piloted for a real player. That distinction matters everywhere: the random
 * bots that populate the world are Player objects too, and they must never be treated as Warband
 * followers by the XP, catch-up or gathering code.
 */

#ifndef WARBAND_PLAYER_ROLES_H
#define WARBAND_PLAYER_ROLES_H

#include "Player.h"
#include "PlayerbotAI.h"
#include "PlayerbotMgr.h"
#include "WorldSession.h"

// The leader a follower follows, or nullptr when this is not a Warband follower: not a bot, a bot
// with no master, a bot following another bot, or a bot whose master has no real client session.
inline Player* WarbandFollowerMaster(Player* player)
{
    if (!player)
        return nullptr;

    PlayerbotAI* botAI = sPlayerbotsMgr.GetPlayerbotAI(player);
    if (!botAI)
        return nullptr;

    Player* master = botAI->GetMaster();
    if (!master || master == player)
        return nullptr;

    WorldSession* session = master->GetSession();
    if (!session || session->IsHeadless())
        return nullptr;

    return master;
}

#endif

/*
 * WoW Warband: phase management.
 *
 * mod-progression decides a phase exactly once, at startup. It reads `Progression.Phase` in
 * OnAfterConfigLoad and sets the expansion, the level cap and its own rules there; it applies the
 * `phase_NN/sql` files in OnAfterDatabasesLoaded; and it registers its phase scripts while the
 * scripts load. Three things follow, and they shape everything below:
 *
 *   - the core exposes no way to write a config value, so a running process cannot be told a new
 *     phase;
 *   - `MaxPlayerLevel` and `Expansion` size ObjectMgr's tables when those tables are loaded, so
 *     they cannot move in place either;
 *   - applying the phase SQL alone would leave a dozen caches stale, which is a state that matches
 *     no phase at all.
 *
 * So this module owns the decision and the paperwork, not the switch:
 *
 *   - the requested phase is a Warband setting, saved in `warband_setting`, so it survives a
 *     restart and does not depend on anybody editing a file correctly;
 *   - changing it writes `Progression.Phase` — and the `Progression.Reset` the change needs — into
 *     mod-progression's own file, in place, leaving the rest of that file alone;
 *   - the change takes effect on the next world start, and the panel says so instead of implying a
 *     live switch;
 *   - the restart that applies a reset clears the flag again, so the phase SQL does not re-run on
 *     every start.
 *
 * Which reset is needed is decided from `updates`: a phase's SQL is recorded there, and moving the
 * phase *down* requires deleting those rows so the lower phases re-insert the content locks that
 * the higher phases had removed. Moving up needs nothing, because the missing phase files are
 * simply absent from `updates` and get applied on the next start.
 */

#include "Chat.h"
#include "Config.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "StringFormat.h"
#include "World.h"
#include "WarbandPersistence.h"

#include <algorithm>
#include <array>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <string>
#include <vector>

namespace
{
constexpr uint8 PhaseMinimum = 0;
constexpr uint8 PhaseMaximum = 18;

// What a server that has never been told otherwise runs: the last vanilla phase.
constexpr uint8 PhaseDefault = 6;

char const* const PhaseConfigFileDefault = "configs/modules/mod_progression.conf";

struct PhaseInfo
{
    char const* name;
    char const* unlocks;
};

// Mirrors the list mod-progression ships in its own README and configuration, so the panel speaks
// the same language as the module. Content is grouped per phase, not per patch day.
constexpr std::array<PhaseInfo, 19> PhaseTable =
{{
    { "Phase 0", "Leveling & dungeons" },
    { "Phase 1", "Maraudon, Molten Core, Onyxia's Lair" },
    { "Phase 2", "Dire Maul, Azuregos, Lord Kazzak, Alterac Valley, Warsong Gulch" },
    { "Phase 3", "Blackwing Lair, Darkmoon Faire, Arathi Basin" },
    { "Phase 4", "Zul'Gurub, Dragons of Nightmare" },
    { "Phase 5", "Ahn'Qiraj, Stranglethorn Fishing Extravaganza" },
    { "Phase 6", "Naxxramas, Scourge Invasion" },
    { "Phase 7", "Blood Elf, Draenei, Outland leveling & dungeons, Jewelcrafting, Eye of the Storm" },
    { "Phase 8", "Karazhan, Gruul's Lair, Magtheridon's Lair, Arena Season 1" },
    { "Phase 9", "Serpentshrine Cavern, The Eye, Ogri'la, Sha'tari Skyguard, Arena Season 2" },
    { "Phase 10", "Battle for Mount Hyjal, Black Temple, Arena Season 3" },
    { "Phase 11", "Zul'Aman" },
    { "Phase 12", "Isle of Quel'Danas, Magister's Terrace, Sunwell Plateau, Arena Season 4" },
    { "Phase 13", "Death Knight, WotLK leveling & dungeons, Strand of the Ancients" },
    { "Phase 14", "Naxxramas, Eye of Eternity, Obsidian Sanctum, Vault of Archavon, Arena Season 5" },
    { "Phase 15", "Ulduar, Isle of Conquest, Arena Season 6" },
    { "Phase 16", "Trial of the Crusader, Trial of the Champion, Argent Tournament, Onyxia, Season 7" },
    { "Phase 17", "Forge of Souls, Pit of Saron, Halls of Reflection, Icecrown Citadel, Season 8" },
    { "Phase 18", "Ruby Sanctum" },
}};

// The phase this process started with: what mod-progression read from its file.
uint8 effectivePhase = PhaseDefault;

// What `updates` says was actually applied.
uint8 databasePhase = PhaseMinimum;

// What the next start should use, saved across restarts.
uint8 requestedPhase = PhaseDefault;

// True while a change that needs `Progression.Reset` is waiting for its restart.
bool resetPending = false;

std::string phaseConfigFile = PhaseConfigFileDefault;

bool IsAssignmentOf(std::string const& line, char const* key)
{
    std::string::size_type const start = line.find_first_not_of(" \t");
    if (start == std::string::npos)
        return false;

    std::size_t const keyLength = std::strlen(key);
    if (line.compare(start, keyLength, key) != 0)
        return false;

    std::string::size_type const next = line.find_first_not_of(" \t", start + keyLength);
    return next != std::string::npos && line[next] == '=';
}

bool ReadLines(std::string const& path, std::vector<std::string>& lines, std::string& error)
{
    std::ifstream input(path, std::ios::binary);
    if (!input)
    {
        error = Acore::StringFormat("{} cannot be opened for reading", path);
        return false;
    }

    std::string line;
    while (std::getline(input, line))
    {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();

        lines.push_back(line);
    }

    return true;
}

bool WriteLines(std::string const& path, std::vector<std::string> const& lines, std::string& error)
{
    std::ofstream output(path, std::ios::binary | std::ios::trunc);
    if (!output)
    {
        error = Acore::StringFormat("{} cannot be opened for writing", path);
        return false;
    }

    for (std::string const& line : lines)
        output << line << '\n';

    output.flush();
    if (!output)
    {
        error = Acore::StringFormat("{} could not be written completely", path);
        return false;
    }

    return true;
}
}

// True when moving to `target` must re-apply the phase SQL: the higher phases already deleted their
// own content locks from `disables`, so only a reset puts the lower phase's locks back.
bool WarbandPhaseNeedsReset(uint8 target, uint8 reflected)
{
    return target < reflected;
}

std::string WarbandPhaseName(uint8 phase)
{
    if (phase > PhaseMaximum)
        return "unknown phase";

    return PhaseTable[phase].name;
}

std::string WarbandPhaseUnlocks(uint8 phase)
{
    if (phase > PhaseMaximum)
        return "";

    return PhaseTable[phase].unlocks;
}

uint8 WarbandPhaseEffective()
{
    return effectivePhase;
}

uint8 WarbandPhaseDatabase()
{
    return databasePhase;
}

uint8 WarbandPhaseRequested()
{
    return requestedPhase;
}

bool WarbandPhaseResetPending()
{
    return resetPending;
}

bool WarbandPhaseChangePending()
{
    return requestedPhase != effectivePhase || resetPending;
}

// Reads the phase the database actually reflects out of `updates`, where mod-progression records
// one row per applied phase file. There is no prepared statement for this in the core's enums and
// the module cannot add one, so it is one plain query at startup.
uint8 WarbandPhaseReadDatabasePhase()
{
    QueryResult result = WorldDatabase.Query(
        "SELECT `name` FROM `updates` WHERE `name` LIKE 'phase_%' ORDER BY `name` DESC LIMIT 1");
    if (!result)
        return PhaseMinimum;

    std::string const name = result->Fetch()[0].Get<std::string>();

    // "phase_06-creature.sql" -> 6
    std::string::size_type const underscore = name.find('_');
    if (underscore == std::string::npos || underscore + 2 >= name.size())
        return PhaseMinimum;

    char digits[3] = { name[underscore + 1], name[underscore + 2], '\0' };
    int const parsed = std::atoi(digits);
    return uint8(std::clamp(parsed, int(PhaseMinimum), int(PhaseMaximum)));
}

// Writes the phase and the reset flag into mod-progression's file, in place: every other line, and
// the file's own comments, are left exactly as they are.
bool WarbandPhaseWriteConfig(uint8 phase, bool reset, std::string& error)
{
    std::vector<std::string> lines;
    if (!ReadLines(phaseConfigFile, lines, error))
        return false;

    std::string const phaseLine = Acore::StringFormat("Progression.Phase = {}", uint32(phase));
    std::string const resetLine = Acore::StringFormat("Progression.Reset = {}", reset ? 1 : 0);

    bool wrotePhase = false;
    bool wroteReset = false;

    for (std::string& line : lines)
    {
        if (IsAssignmentOf(line, "Progression.Phase"))
        {
            line = phaseLine;
            wrotePhase = true;
        }
        else if (IsAssignmentOf(line, "Progression.Reset"))
        {
            line = resetLine;
            wroteReset = true;
        }
    }

    if (!wrotePhase || !wroteReset)
    {
        lines.emplace_back();
        lines.emplace_back("# Set by Warband phase management - see .warband phase");

        if (!wrotePhase)
            lines.push_back(phaseLine);

        if (!wroteReset)
            lines.push_back(resetLine);
    }

    return WriteLines(phaseConfigFile, lines, error);
}

// Applies a GM's choice: validate it, work out whether it needs a reset, save it and write the
// file the next start reads. Nothing here touches the running world.
bool WarbandPhaseSet(uint8 target, std::string const& actor, std::string& error)
{
    if (target > PhaseMaximum)
    {
        error = Acore::StringFormat(
            "A phase must be between {} and {}.", uint32(PhaseMinimum), uint32(PhaseMaximum));
        return false;
    }

    bool const reset = WarbandPhaseNeedsReset(target, databasePhase);
    if (!WarbandPhaseWriteConfig(target, reset, error))
        return false;

    requestedPhase = target;
    resetPending = reset;

    WarbandSettingSet("phase.requested", double(target));
    WarbandSettingSet("phase.resetPending", reset ? 1.0 : 0.0);

    LOG_INFO("module",
        "Warband phase: {} requested {} ({}) - the world is on {} and the database reflects {}{}",
        actor, uint32(target), WarbandPhaseName(target), uint32(effectivePhase),
        uint32(databasePhase), reset ? "; the next start re-applies the phase SQL" : "");

    return true;
}

void WarbandPhaseSendStatus(ChatHandler* handler)
{
    if (!handler)
        return;

    // One line, like every other Warband page. The phase list itself lives in the addon, so opening
    // the page does not scroll the player's chat with nineteen rows.
    handler->PSendSysMessage(
        "WARBAND_PHASE=effective={} db={} requested={} pending={} reset={} cap={} expansion={}",
        uint32(effectivePhase), uint32(databasePhase), uint32(requestedPhase),
        WarbandPhaseChangePending() ? 1 : 0, resetPending ? 1 : 0,
        sWorld->getIntConfig(CONFIG_MAX_PLAYER_LEVEL), sWorld->getIntConfig(CONFIG_EXPANSION));
}

namespace
{
class WarbandPhase final : public WorldScript
{
public:
    WarbandPhase() : WorldScript("WarbandPhase") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        phaseConfigFile = sConfigMgr->GetOption<std::string>(
            "Warband.Progression.ConfigFile", PhaseConfigFileDefault);

        uint8 configured = sConfigMgr->GetOption<uint8>("Warband.Progression.Phase", PhaseDefault);
        if (configured > PhaseMaximum)
        {
            LOG_ERROR("server.loading",
                "Warband.Progression.Phase ({}) must be between {} and {}. Using {}.",
                uint32(configured), uint32(PhaseMinimum), uint32(PhaseMaximum),
                uint32(PhaseDefault));
            configured = PhaseDefault;
        }

        // What mod-progression read for this process. It is the truth about the running world, no
        // matter what the saved request says.
        effectivePhase = sConfigMgr->GetOption<uint8>("Progression.Phase", PhaseMaximum);

        int const saved = int(WarbandSettingGet("phase.requested", double(configured)));
        requestedPhase = uint8(std::clamp(saved, int(PhaseMinimum), int(PhaseMaximum)));
        resetPending = WarbandSettingGet("phase.resetPending", 0.0) != 0.0;

        LOG_INFO("server.loading",
            "Warband phase: world on {}, requested {}, reset pending {}",
            uint32(effectivePhase), uint32(requestedPhase), resetPending ? "yes" : "no");
    }

    // Runs once the databases are up, which is when `updates` can be read and when the module's own
    // phase SQL has already been applied.
    void OnStartup() override
    {
        databasePhase = WarbandPhaseReadDatabasePhase();

        bool const phaseFileReset = sConfigMgr->GetOption<bool>("Progression.Reset", false);

        if (requestedPhase != effectivePhase)
        {
            // The saved request never reached the file, or the file was edited around it. Put the
            // file back in step so the next start honours the request.
            std::string error;
            bool const reset = WarbandPhaseNeedsReset(requestedPhase, databasePhase);
            if (WarbandPhaseWriteConfig(requestedPhase, reset, error))
            {
                resetPending = reset;
                WarbandSettingSet("phase.resetPending", reset ? 1.0 : 0.0);
                LOG_INFO("module",
                    "Warband phase: {} written to {} (world is still on {}); restart to apply",
                    uint32(requestedPhase), phaseConfigFile, uint32(effectivePhase));
            }
            else
            {
                LOG_ERROR("module", "Warband phase: {}", error);
            }
        }
        else if (phaseFileReset && databasePhase == effectivePhase)
        {
            // This start ran the reset that the request needed. Clear it so the phase SQL does not
            // run again on every start.
            std::string error;
            if (WarbandPhaseWriteConfig(effectivePhase, false, error))
            {
                resetPending = false;
                WarbandSettingSet("phase.resetPending", 0.0);
                LOG_INFO("module",
                    "Warband phase: reset applied on phase {}; Progression.Reset cleared in {}",
                    uint32(effectivePhase), phaseConfigFile);
            }
            else
            {
                LOG_ERROR("module", "Warband phase: {}", error);
            }
        }

        if (databasePhase != effectivePhase)
        {
            LOG_WARN("module",
                "Warband phase: the database reflects phase {} while the world runs phase {}; "
                "a restart with Progression.Reset = 1 brings them back together",
                uint32(databasePhase), uint32(effectivePhase));
        }

        LOG_INFO("module",
            "Warband phase: world {}, database {}, requested {}, change pending {}",
            uint32(effectivePhase), uint32(databasePhase), uint32(requestedPhase),
            WarbandPhaseChangePending() ? "yes" : "no");
    }
};
}

void AddSC_warband_phase()
{
    new WarbandPhase();
}

/*
 * WoW Warband settings that survive a restart.
 *
 * Every switch and value the panel exposes used to live in memory only: it was read from
 * mod_warband.conf at startup and thrown away when the process ended, so a change made in game was
 * forgotten by the next restart. This is the one place that remembers them.
 *
 *     warband_setting(setting VARCHAR(48) PRIMARY KEY, value DOUBLE)
 *
 * The rule everywhere is the same: the configuration file supplies the *default*, and a saved row
 * wins over it. Deleting a row (or using the reset button) returns that setting to the shipped
 * default. Nothing here holds state that is not a plain number, which keeps the table readable and
 * the load path trivial.
 *
 * The table is created on first use, so a world that has never seen this module still works.
 */
#pragma once

#include <string>

// Reads a saved value, or `fallback` when the setting has never been saved.
double WarbandSettingGet(std::string const& key, double fallback);

// True when the setting has ever been saved, so callers can tell "saved as 0" from "never set".
bool WarbandSettingHas(std::string const& key);

// Saves a value immediately. Called from every setter, so the panel and the commands persist
// themselves at the moment they change something.
void WarbandSettingSet(std::string const& key, double value);

// True once the table exists and the saved values are in memory.
bool WarbandSettingsReady();

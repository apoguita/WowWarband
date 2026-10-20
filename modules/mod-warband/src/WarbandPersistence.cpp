/*
 * WoW Warband settings that survive a restart. See WarbandPersistence.h for the contract.
 */

#include "DatabaseEnv.h"
#include "Log.h"
#include "QueryResult.h"
#include "WarbandPersistence.h"

#include <string>
#include <unordered_map>

namespace
{
std::unordered_map<std::string, double> settingStore;
bool storeLoaded = false;

// Loaded on first use rather than at a particular startup hook, so the order in which the module's
// scripts run cannot leave a feature reading a default when a saved value exists.
void EnsureLoaded()
{
    if (storeLoaded)
    {
        return;
    }

    storeLoaded = true;

    WorldDatabase.DirectExecute(
        "CREATE TABLE IF NOT EXISTS `warband_setting` ("
        "`setting` VARCHAR(48) NOT NULL, "
        "`value` DOUBLE NOT NULL DEFAULT 0, "
        "PRIMARY KEY (`setting`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

    QueryResult result = WorldDatabase.Query("SELECT `setting`, `value` FROM `warband_setting`");
    if (!result)
    {
        return;
    }

    do
    {
        Field* fields = result->Fetch();
        settingStore[fields[0].Get<std::string>()] = fields[1].Get<double>();
    } while (result->NextRow());

    LOG_INFO("server.loading", "Warband: {} saved setting(s) loaded", settingStore.size());
}
}

bool WarbandSettingsReady()
{
    EnsureLoaded();
    return true;
}

double WarbandSettingGet(std::string const& key, double fallback)
{
    EnsureLoaded();

    auto const itr = settingStore.find(key);
    return itr == settingStore.end() ? fallback : itr->second;
}

bool WarbandSettingHas(std::string const& key)
{
    EnsureLoaded();
    return settingStore.find(key) != settingStore.end();
}

void WarbandSettingSet(std::string const& key, double value)
{
    EnsureLoaded();

    settingStore[key] = value;

    WorldDatabase.DirectExecute(
        "INSERT INTO `warband_setting` (`setting`, `value`) VALUES ('{}', {}) "
        "ON DUPLICATE KEY UPDATE `value` = {}",
        key, value, value);
}

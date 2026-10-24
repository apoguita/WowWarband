/*
 * WoW Warband supplier prices.
 *
 * The supplier merchants stock the game's craftables, materials, reagents and recipes without
 * limit. This file owns the numbers that decide what they charge and what they pay:
 *
 *     pay    = max(floor, original sell price * multiplier[quality])     // the merchant price
 *     charge = pay + material cost
 *
 * One multiplier per item quality (poor .. heirloom) and a copper floor. Both live in the world
 * database, so a value set from the panel or from the command survives a restart, and there is
 * exactly one copy of them: the panel, the command and this file all read the same rows.
 *
 * Why the prices are written onto the items instead of being scaled at runtime: the core charges
 * `item_template.BuyPrice` (Player::BuyItemFromVendorSlot) and pays `item_template.SellPrice`, and
 * no hook can change either one per quality. The only price hook in that path,
 * OnPlayerGetReputationPriceDiscount, is per vendor and knows nothing about the item being priced,
 * so it cannot carry one multiplier per quality and cannot express a floor. The item templates are
 * read once at startup and there is no runtime reload, so an applied price becomes visible after
 * the worldserver restarts - the panel states that on the page.
 *
 * Two numbers, not one: what a merchant pays stays the merchant price, and what it charges is that
 * price plus the cost of the item's materials. The material cost is computed once by
 * tools/warband-suppliers.py from the crafting recipes (a material that is itself crafted costs its
 * own charge, a gathered one costs its merchant price) and stored in
 * `warband_supplier_price.material_cost`; 0 means the item has no recipe and charges exactly the
 * merchant price. That gap between the two numbers is what stops buying from the merchants and
 * selling straight back from paying more than the purchase cost once the Warband gold multiplier is
 * applied to the payout - the multiplier is in the sale path, not here, so it needs no special case.
 *
 * `warband_supplier_price` keeps each catalogue item's ORIGINAL price. Every apply starts from it,
 * so pressing Apply twice never compounds a multiplier and Restore defaults is exact. Items that
 * are not in that table are never touched by this file.
 */

#include "Config.h"
#include "DatabaseEnv.h"
#include "ItemTemplate.h"
#include "Log.h"
#include "ScriptMgr.h"
#include "WarbandPersistence.h"

#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <string>
#include <vector>

namespace
{
    // ITEM_QUALITY_POOR .. ITEM_QUALITY_HEIRLOOM, in the order the game numbers them.
    constexpr uint8 TierCount = 8;
    constexpr float MinMultiplier = 1.0f;
    constexpr float MaxMultiplier = 20.0f;
    constexpr uint32 MinFloor = 1;
    constexpr uint32 MaxFloor = 1000000;

    // The shipped rule: poor 2, normal 3, uncommon 4, rare 5, epic 6, legendary 7, artifact 8,
    // heirloom 9, with a ten copper floor.
    constexpr std::array<float, TierCount> DefaultMultipliers = { 2.0f, 1.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f };
    constexpr uint32 DefaultFloor = 10;

    constexpr std::array<char const*, TierCount> TierKeys =
    {
        "poor", "normal", "uncommon", "rare", "epic", "legendary", "artifact", "heirloom"
    };

    // The same tiers by the colour a player knows them by, accepted wherever a tier is named.
    constexpr std::array<char const*, TierCount> TierAliases =
    {
        "gray", "white", "green", "blue", "purple", "orange", "gold", "heirloom"
    };

    constexpr std::array<char const*, TierCount> ConfigNames =
    {
        "Warband.Suppliers.Multiplier.Poor",
        "Warband.Suppliers.Multiplier.Normal",
        "Warband.Suppliers.Multiplier.Uncommon",
        "Warband.Suppliers.Multiplier.Rare",
        "Warband.Suppliers.Multiplier.Epic",
        "Warband.Suppliers.Multiplier.Legendary",
        "Warband.Suppliers.Multiplier.Artifact",
        "Warband.Suppliers.Multiplier.Heirloom"
    };

    char const* const FloorConfigName = "Warband.Suppliers.Floor";

    std::array<float, TierCount> confMultipliers = DefaultMultipliers;
    uint32 confFloor = DefaultFloor;

    // The values in force. Editing one of these is what the panel and the command do.
    std::array<float, TierCount> multipliers = DefaultMultipliers;
    uint32 floorPrice = DefaultFloor;

    // What the last apply wrote, so the panel can say whether the prices match the values above.
    std::array<float, TierCount> appliedMultipliers = DefaultMultipliers;
    uint32 appliedFloor = DefaultFloor;
    uint32 appliedItems = 0;
    bool appliedKnown = false;

    bool IsValidMultiplier(float value)
    {
        return std::isfinite(value) && value >= MinMultiplier && value <= MaxMultiplier;
    }

    bool IsValidFloor(uint32 value)
    {
        return value >= MinFloor && value <= MaxFloor;
    }

    void SaveSetting(std::string const& key, double value)
    {
        // One table for every Warband setting; the "supplier." prefix keeps these names clear.
        WarbandSettingSet("supplier." + key, value);
    }

    // One row of the catalogue: the two prices the apply writes onto the item.
    struct PricedItem
    {
        uint32 entry;
        uint32 charge;      // what the merchant charges: the merchant price plus the material cost
        uint32 pay;         // what a merchant pays: the merchant price
    };

    // The original prices live in their own table, because that is a catalogue, not a setting.
    void EnsurePriceTable()
    {
        WorldDatabase.DirectExecute(
            "CREATE TABLE IF NOT EXISTS `warband_supplier_price` ("
            "`entry` INT UNSIGNED NOT NULL, "
            "`quality` TINYINT UNSIGNED NOT NULL DEFAULT 0, "
            "`base_buy` INT UNSIGNED NOT NULL DEFAULT 0, "
            "`base_sell` INT UNSIGNED NOT NULL DEFAULT 0, "
            "`material_cost` INT UNSIGNED NOT NULL DEFAULT 0, "
            "PRIMARY KEY (`entry`)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4");

        // A world that installed the catalogue before the material cost existed keeps its rows; the
        // column is added here so the module does not depend on which SQL update has run yet.
        QueryResult column = WorldDatabase.Query(
            "SELECT COUNT(*) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = DATABASE() "
            "AND TABLE_NAME = 'warband_supplier_price' AND COLUMN_NAME = 'material_cost'");

        if (column && column->Fetch()[0].Get<uint32>() == 0)
        {
            WorldDatabase.DirectExecute(
                "ALTER TABLE `warband_supplier_price` ADD COLUMN `material_cost` INT UNSIGNED NOT NULL DEFAULT 0");
        }
    }

    void ReadConfig()
    {
        for (uint8 tier = 0; tier < TierCount; ++tier)
        {
            float const configured = sConfigMgr->GetOption<float>(ConfigNames[tier], DefaultMultipliers[tier]);

            if (!IsValidMultiplier(configured))
            {
                LOG_ERROR(
                    "server.loading",
                    "Warband suppliers: {} ({}) must be between {} and {}, using {}",
                    ConfigNames[tier],
                    TierKeys[tier],
                    MinMultiplier,
                    MaxMultiplier,
                    DefaultMultipliers[tier]);
                confMultipliers[tier] = DefaultMultipliers[tier];
                continue;
            }

            confMultipliers[tier] = configured;
        }

        uint32 const configuredFloor = sConfigMgr->GetOption<uint32>(FloorConfigName, DefaultFloor);
        if (!IsValidFloor(configuredFloor))
        {
            LOG_ERROR(
                "server.loading",
                "Warband suppliers: {} must be between {} and {} copper, using {}",
                FloorConfigName,
                MinFloor,
                MaxFloor,
                DefaultFloor);
            confFloor = DefaultFloor;
        }
        else
        {
            confFloor = configuredFloor;
        }
    }

    // Reads the saved values through the shared Warband settings store, seeding anything absent with
    // the configured default. A value saved by an earlier session always wins over the config file,
    // so the panel is the source of truth.
    void LoadSettings()
    {
        multipliers = confMultipliers;
        floorPrice = confFloor;

        for (uint8 tier = 0; tier < TierCount; ++tier)
        {
            float const saved = float(WarbandSettingGet(
                std::string("supplier.mult.") + std::to_string(tier), double(multipliers[tier])));

            if (IsValidMultiplier(saved))
            {
                multipliers[tier] = saved;
            }
            else
            {
                SaveSetting(std::string("mult.") + std::to_string(tier), double(multipliers[tier]));
            }
        }

        uint32 const savedFloor = uint32(std::llround(
            WarbandSettingGet("supplier.floor", double(floorPrice))));

        if (IsValidFloor(savedFloor))
        {
            floorPrice = savedFloor;
        }
        else
        {
            SaveSetting("floor", double(floorPrice));
        }

        // What the last apply wrote, so the panel can say whether the prices match the values above.
        appliedKnown = WarbandSettingHas("supplier.applied.items");
        appliedFloor = uint32(std::llround(
            WarbandSettingGet("supplier.applied.floor", double(appliedFloor))));
        appliedItems = uint32(std::llround(
            WarbandSettingGet("supplier.applied.items", double(appliedItems))));

        for (uint8 tier = 0; tier < TierCount; ++tier)
        {
            appliedMultipliers[tier] = float(WarbandSettingGet(
                std::string("supplier.applied.mult.") + std::to_string(tier),
                double(appliedMultipliers[tier])));
        }
    }

    uint32 CountCatalogue()
    {
        QueryResult result = WorldDatabase.Query("SELECT COUNT(*) FROM `warband_supplier_price`");
        if (!result)
        {
            return 0;
        }

        return result->Fetch()[0].Get<uint32>();
    }
}

uint8 WarbandSupplierTierCount()
{
    return TierCount;
}

char const* WarbandSupplierTierKey(uint8 tier)
{
    return tier < TierCount ? TierKeys[tier] : "";
}

char const* WarbandSupplierTierAlias(uint8 tier)
{
    return tier < TierCount ? TierAliases[tier] : "";
}

float WarbandSupplierTierMultiplier(uint8 tier)
{
    return tier < TierCount ? multipliers[tier] : 1.0f;
}

bool SetWarbandSupplierTierMultiplier(uint8 tier, float value)
{
    if (tier >= TierCount || !IsValidMultiplier(value))
    {
        return false;
    }

    multipliers[tier] = value;
    SaveSetting(std::string("mult.") + std::to_string(tier), double(value));

    return true;
}

uint32 WarbandSupplierFloor()
{
    return floorPrice;
}

bool SetWarbandSupplierFloor(uint32 value)
{
    if (!IsValidFloor(value))
    {
        return false;
    }

    floorPrice = value;
    SaveSetting("floor", double(value));

    return true;
}

void ResetWarbandSupplierSettings()
{
    multipliers = DefaultMultipliers;
    floorPrice = DefaultFloor;

    for (uint8 tier = 0; tier < TierCount; ++tier)
    {
        SaveSetting(std::string("mult.") + std::to_string(tier), double(multipliers[tier]));
    }

    SaveSetting("floor", double(floorPrice));
}

uint32 WarbandSupplierCatalogueSize()
{
    return CountCatalogue();
}

bool WarbandSupplierPricesAreCurrent()
{
    if (!appliedKnown)
    {
        return false;
    }

    if (appliedFloor != floorPrice || appliedItems != WarbandSupplierCatalogueSize())
    {
        return false;
    }

    for (uint8 tier = 0; tier < TierCount; ++tier)
    {
        if (appliedMultipliers[tier] != multipliers[tier])
        {
            return false;
        }
    }

    return true;
}

// Writes each catalogue item's two prices: what the merchant charges, which is the merchant price
// plus the material cost, and what it pays, the merchant price. The material cost comes from the
// row, the merchant price from the original sell price, never from the item's current price, so the
// operation can be repeated safely. Returns the number of items priced; zero means nothing was
// written and `note` says why.
uint32 ApplyWarbandSupplierPrices(std::string& note)
{
    note.clear();

    QueryResult result = WorldDatabase.Query(
        "SELECT `entry`, `quality`, `base_sell`, `material_cost` FROM `warband_supplier_price`");
    if (!result)
    {
        note = "no catalogue is installed yet";
        return 0;
    }

    std::vector<PricedItem> prices;
    prices.reserve(4096);

    do
    {
        Field* fields = result->Fetch();

        uint32 const entry = fields[0].Get<uint32>();
        uint8 const quality = fields[1].Get<uint8>();
        uint32 const baseSell = fields[2].Get<uint32>();
        uint32 const materialCost = fields[3].Get<uint32>();

        float const multiplier = quality < TierCount ? multipliers[quality] : multipliers[uint8(ITEM_QUALITY_NORMAL)];
        uint64 const scaled = uint64(std::llround(double(baseSell) * double(multiplier)));
        uint64 const pay = std::max<uint64>(floorPrice, scaled);
        uint64 const charge = pay + materialCost;

        prices.push_back({ entry, uint32(charge), uint32(pay) });
    } while (result->NextRow());

    if (prices.empty())
    {
        note = "the catalogue is empty";
        return 0;
    }

    // One statement per chunk keeps the round trips down without building a megabyte of SQL.
    constexpr size_t ChunkSize = 400;

    for (size_t start = 0; start < prices.size(); start += ChunkSize)
    {
        size_t const end = std::min(prices.size(), start + ChunkSize);

        std::string buyCase;
        std::string sellCase;
        std::string entries;

        for (size_t index = start; index < end; ++index)
        {
            std::string const entry = std::to_string(prices[index].entry);
            buyCase += " WHEN " + entry + " THEN " + std::to_string(prices[index].charge);
            sellCase += " WHEN " + entry + " THEN " + std::to_string(prices[index].pay);

            if (index != start)
            {
                entries += ',';
            }

            entries += entry;
        }

        std::string const sql =
            "UPDATE `item_template` SET "
            "`BuyPrice` = CASE `entry`" + buyCase + " ELSE `BuyPrice` END, "
            "`SellPrice` = CASE `entry`" + sellCase + " ELSE `SellPrice` END "
            "WHERE `entry` IN (" + entries + ")";

        WorldDatabase.DirectExecute(sql);
    }

    appliedMultipliers = multipliers;
    appliedFloor = floorPrice;
    appliedItems = uint32(prices.size());
    appliedKnown = true;

    for (uint8 tier = 0; tier < TierCount; ++tier)
    {
        SaveSetting(std::string("applied.mult.") + std::to_string(tier), double(multipliers[tier]));
    }

    SaveSetting("applied.floor", double(floorPrice));
    SaveSetting("applied.items", double(appliedItems));

    LOG_INFO(
        "server.loading",
        "Warband suppliers: priced {} items, charging the merchant price (floor {} copper, original * "
        "multiplier) plus the material cost, and paying the merchant price",
        appliedItems,
        floorPrice);

    return appliedItems;
}

class WarbandSupplierSettings final : public WorldScript
{
public:
    WarbandSupplierSettings() : WorldScript("WarbandSupplierSettings") { }

    void OnAfterConfigLoad(bool /*reload*/) override
    {
        ReadConfig();
        EnsurePriceTable();
        LoadSettings();

        LOG_INFO(
            "server.loading",
            "Warband suppliers: poor x{}, normal x{}, uncommon x{}, rare x{}, epic x{}, legendary x{}, "
            "artifact x{}, heirloom x{}, floor {} copper, {} items catalogued",
            multipliers[0], multipliers[1], multipliers[2], multipliers[3],
            multipliers[4], multipliers[5], multipliers[6], multipliers[7],
            floorPrice,
            WarbandSupplierCatalogueSize());

        if (!WarbandSupplierPricesAreCurrent())
        {
            LOG_INFO("server.loading", "Warband suppliers: saved prices differ from these values, apply to update them");
        }
    }
};

void AddSC_warband_suppliers()
{
    new WarbandSupplierSettings();
}


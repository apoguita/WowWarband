-- Revert of 2026_10_20_03_warband_bot_prices.sql: the bot family back to the shipped catalogue's
-- own prices (Field Repair Bots at 3 gold from their item data, Jeeves and MOLL-E at the floor).
UPDATE `item_template` SET `BuyPrice` = 30000, `SellPrice` = 30000 WHERE `entry` IN (18232, 34113);
UPDATE `item_template` SET `BuyPrice` = 5625,  `SellPrice` = 5625  WHERE `entry` = 40769;
UPDATE `item_template` SET `BuyPrice` = 10,    `SellPrice` = 10    WHERE `entry` IN (40768, 49040);

UPDATE `warband_supplier_price` SET `base_buy` = 40000, `base_sell` = 10000 WHERE `entry` IN (18232, 34113);
UPDATE `warband_supplier_price` SET `base_buy` = 7500,  `base_sell` = 1875  WHERE `entry` = 40769;
UPDATE `warband_supplier_price` SET `base_buy` = 0,     `base_sell` = 0     WHERE `entry` IN (40768, 49040);

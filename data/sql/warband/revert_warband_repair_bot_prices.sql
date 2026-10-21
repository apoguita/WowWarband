-- Revert of 2026_10_20_05_warband_repair_bot_prices.sql: back to the prices from
-- 2026_10_20_03_warband_bot_prices.sql (bots about 25 silver). Reverting further to the shipped
-- catalogue is that file's own revert.
INSERT INTO `warband_supplier_price` (`entry`, `quality`, `base_buy`, `base_sell`) VALUES
  (18232, 1, 2500, 833),
  (34113, 1, 2500, 833)
ON DUPLICATE KEY UPDATE `base_buy` = VALUES(`base_buy`), `base_sell` = VALUES(`base_sell`);

UPDATE `item_template` SET `BuyPrice` = 2499, `SellPrice` = 2499 WHERE `entry` IN (18232, 34113);

-- Field Repair Bots at their old one-gold price.
--
-- The supplier prices every item as max(floor, base_sell * multiplier[quality]). Normal quality is
-- x3, so exactly 10000 copper cannot be expressed from an integer base_sell; 3333 * 3 = 9999, one
-- copper under a gold, and that is what both bots cost. Storing 3333 keeps a later
-- .warband price apply stable instead of snapping back to an earlier value.
--
-- Jeeves stays at 1000 gold from 2026_10_20_03_warband_bot_prices.sql.

INSERT INTO `warband_supplier_price` (`entry`, `quality`, `base_buy`, `base_sell`) VALUES
  (18232, 1, 10000, 3333),
  (34113, 1, 10000, 3333)
ON DUPLICATE KEY UPDATE `base_buy` = VALUES(`base_buy`), `base_sell` = VALUES(`base_sell`);

UPDATE `item_template` SET `BuyPrice` = 9999, `SellPrice` = 9999 WHERE `entry` IN (18232, 34113);

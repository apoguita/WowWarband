-- Warband supplier prices for the engineering bot family, as requested 18 October 2026.
--
-- Jeeves costs 1000 gold. The two portable repair bots (Field Repair Bot 74A and 110G) cost about
-- 25 silver each, so they can be bought and consumed. MOLL-E and the Scrapbot Construction Kit are
-- restored to the prices the shipped catalogue produced (they were not part of the request).
--
-- base_sell is stored as price / multiplier[quality], because the module prices every catalogue
-- item as max(floor, base_sell * multiplier): Normal x3, Rare x5, Epic x6. The item template gets
-- the same number the module would write on .warband price apply, so repeated applies are stable.
--
--   Jeeves                     49040  Epic   1000g = 10000000c -> base_sell 1666667 (price 10000002c)
--   Field Repair Bot 74A       18232  Normal   25s =    2500c -> base_sell     833 (price     2499c)
--   Field Repair Bot 110G      34113  Normal   25s =    2500c -> base_sell     833 (price     2499c)
--   Scrapbot Construction Kit  40769  Normal  restored          -> base_sell    1875 (price     5625c)
--   MOLL-E                     40768  Rare    restored          -> base_sell       0 (price       10c)

INSERT INTO `warband_supplier_price` (`entry`, `quality`, `base_buy`, `base_sell`) VALUES
  (49040, 4, 10000000, 1666667),
  (18232, 1, 2500, 833),
  (34113, 1, 2500, 833),
  (40769, 1, 7500, 1875),
  (40768, 3, 0, 0)
ON DUPLICATE KEY UPDATE `base_buy` = VALUES(`base_buy`), `base_sell` = VALUES(`base_sell`);

UPDATE `item_template` SET `BuyPrice` = 10000002, `SellPrice` = 10000002 WHERE `entry` = 49040;
UPDATE `item_template` SET `BuyPrice` = 2499,     `SellPrice` = 2499     WHERE `entry` IN (18232, 34113);
UPDATE `item_template` SET `BuyPrice` = 5625,     `SellPrice` = 5625     WHERE `entry` = 40769;
UPDATE `item_template` SET `BuyPrice` = 10,       `SellPrice` = 10       WHERE `entry` = 40768;

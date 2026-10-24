-- Warband suppliers: back to a single price per item - BuyPrice = the shipped price, and no
-- material cost is remembered. Generated; safe to apply twice.
START TRANSACTION;

UPDATE `item_template` AS `i`
  JOIN `warband_supplier_price` AS `p` ON `p`.`entry` = `i`.`entry`
  SET `i`.`BuyPrice` = `p`.`base_buy`;
UPDATE `warband_supplier_price` SET `material_cost` = 0;

COMMIT;

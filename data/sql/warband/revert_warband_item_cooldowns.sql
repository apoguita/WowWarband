-- Reverts the Warband item cooldown changes in
-- data/sql/updates/pending_db_world/2026_10_20_00_warband_item_cooldowns.sql
--
-- Kept outside the updater's directory: the server applies everything under pending_db_world on its
-- own, and a reverse would undo it every start.

-- Jeeves back to the shipped one hour.
UPDATE `item_template` SET `spellcooldown_1` = 3600000 WHERE `entry` = 49040;

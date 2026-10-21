-- Warband: item cooldowns the project changes, shipped as a pending world update so any clone that
-- starts the server once gets them (Updates.EnableDatabases in worldserver.conf applies this file).
--
-- Jeeves (49040) is a portable vendor, bank and repair bot. The shipped data gives its on-use spell
-- a one-hour cooldown, which is a long wait for a five-character Warband that banks and repairs on
-- the move; it drops to three minutes here.
--
-- The cooldown lives on the ITEM, not on the spell: item_template.spellcooldown_1 is the item-level
-- cooldown for spell 67826, and that spell carries no recovery time of its own. Item templates are
-- read once at worldserver startup (there is no runtime item reload), so the new value applies from
-- the next start.
--
-- Idempotent: a plain UPDATE, so re-applying the file is harmless.

UPDATE `item_template` SET `spellcooldown_1` = 180000 WHERE `entry` = 49040;

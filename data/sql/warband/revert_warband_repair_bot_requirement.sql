-- Revert of 2026_10_20_04_warband_repair_bot_requirement.sql: the shipped Engineering gate.
UPDATE `item_template` SET `RequiredSkillRank` = 300 WHERE `entry` = 18232;

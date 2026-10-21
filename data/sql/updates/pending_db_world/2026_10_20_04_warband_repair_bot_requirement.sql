-- Field Repair Bot 74A: lower the profession requirement from Engineering 300 to Engineering 1.
--
-- The summonable repair bots are Warband convenience items; their shipped profession gate (300
-- Engineering, 325 for the 110G, 450 for Jeeves) belongs to an era when the recipe was the only way
-- to obtain them. The Warband suppliers sell them finished, so the gate only stops a character from
-- using something it already bought. Only the requirement rank changes; the Engineering skill line
-- stays attached, so the tooltip still reads "Requires Engineering (1)".

UPDATE `item_template` SET `RequiredSkillRank` = 1 WHERE `entry` = 18232;

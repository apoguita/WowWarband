-- Split the supplier Glyphs page into Major and Minor glyphs, each grouped by class.
-- Minor status comes from Spell.dbc apply-glyph effects and GlyphProperties.dbc slot flags.
START TRANSACTION;

-- Replace the old mixed class lists with the major-only stock lists.
-- Add minor stock holders. INSERT IGNORE keeps their templates safe to reapply.
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910434;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910434, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910434;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910434;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910434, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910435;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910435, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910435;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910435;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910435, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910436;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910436, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910436;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910436;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910436, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910437;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910437, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910437;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910437;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910437, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910438;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910438, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910438;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910438;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910438, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910439;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910439, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910439;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910439;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910439, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910440;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910440, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910440;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910440;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910440, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910441;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910441, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910441;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910441;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910441, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910442;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910442, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910442;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910442;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910442, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910443;
INSERT IGNORE INTO `creature_template` (`entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, `name`, `subname`, `IconName`, `gossip_menu_id`, `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`) SELECT 910443, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`, `KillCredit1`, `KillCredit2`, 'Warband Supplier stock', '', NULL, 0, `minlevel`, `maxlevel`, `exp`, `faction`, 128, `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`, `rank`, `dmgschool`, `DamageModifier`, `BaseAttackTime`, `RangeAttackTime`, `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`, `dynamicflags`, `family`, `type`, `type_flags`, `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`, `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`, `HealthModifier`, `ManaModifier`, `ArmorModifier`, `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`, `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild` FROM `creature_template` WHERE `entry` = 8671;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910443;
DELETE FROM `creature_template_model` WHERE `CreatureID` = 910443;
INSERT INTO `creature_template_model` (`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`) SELECT 910443, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild` FROM `creature_template_model` WHERE `CreatureID` = 8671;

-- Rebuild category menus and text.
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (90179, 90183, 90184);
DELETE FROM `gossip_menu` WHERE `MenuID` IN (90183, 90184);
DELETE FROM `npc_text` WHERE `ID` IN (100120, 100121);
INSERT INTO `npc_text` (`ID`, `text0_0`, `text0_1`, `Probability0`, `VerifiedBuild`) VALUES
(100120, 'Major Glyphs.', 'Major Glyphs.', 1, 1),
(100121, 'Minor Glyphs.', 'Minor Glyphs.', 1, 1);
DELETE FROM `gossip_menu` WHERE `MenuID` IN (90183, 90184);
INSERT INTO `gossip_menu` (`MenuID`, `TextID`) VALUES (90183, 100120), (90184, 100121);
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (90179, 90183, 90184);
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`) VALUES
(90179, 0, 0, 'Major Glyphs', 0, 1, 1, 90183, 0, 0, 0, '', 0, 1),
(90179, 1, 0, 'Minor Glyphs', 0, 1, 1, 90184, 0, 0, 0, '', 0, 1);
DELETE FROM `gossip_menu_option` WHERE `MenuID` IN (90179, 90183, 90184);
INSERT INTO `gossip_menu_option` (`MenuID`, `OptionID`, `OptionIcon`, `OptionText`, `OptionBroadcastTextID`, `OptionType`, `OptionNpcFlag`, `ActionMenuID`, `ActionPoiID`, `BoxCoded`, `BoxMoney`, `BoxText`, `BoxBroadcastTextID`, `VerifiedBuild`) VALUES
(90183, 0, 1, 'Death Knight', 0, 3, 128, 910386, 0, 0, 0, '', 0, 1),
(90183, 1, 1, 'Druid', 0, 3, 128, 910387, 0, 0, 0, '', 0, 1),
(90183, 2, 1, 'Hunter', 0, 3, 128, 910388, 0, 0, 0, '', 0, 1),
(90183, 3, 1, 'Mage', 0, 3, 128, 910389, 0, 0, 0, '', 0, 1),
(90183, 4, 1, 'Paladin', 0, 3, 128, 910390, 0, 0, 0, '', 0, 1),
(90183, 5, 1, 'Priest', 0, 3, 128, 910391, 0, 0, 0, '', 0, 1),
(90183, 6, 1, 'Rogue', 0, 3, 128, 910392, 0, 0, 0, '', 0, 1),
(90183, 7, 1, 'Shaman', 0, 3, 128, 910393, 0, 0, 0, '', 0, 1),
(90183, 8, 1, 'Warlock', 0, 3, 128, 910394, 0, 0, 0, '', 0, 1),
(90183, 9, 1, 'Warrior', 0, 3, 128, 910395, 0, 0, 0, '', 0, 1),
(90184, 0, 1, 'Death Knight', 0, 3, 128, 910434, 0, 0, 0, '', 0, 1),
(90184, 1, 1, 'Druid', 0, 3, 128, 910435, 0, 0, 0, '', 0, 1),
(90184, 2, 1, 'Hunter', 0, 3, 128, 910436, 0, 0, 0, '', 0, 1),
(90184, 3, 1, 'Mage', 0, 3, 128, 910437, 0, 0, 0, '', 0, 1),
(90184, 4, 1, 'Paladin', 0, 3, 128, 910438, 0, 0, 0, '', 0, 1),
(90184, 5, 1, 'Priest', 0, 3, 128, 910439, 0, 0, 0, '', 0, 1),
(90184, 6, 1, 'Rogue', 0, 3, 128, 910440, 0, 0, 0, '', 0, 1),
(90184, 7, 1, 'Shaman', 0, 3, 128, 910441, 0, 0, 0, '', 0, 1),
(90184, 8, 1, 'Warlock', 0, 3, 128, 910442, 0, 0, 0, '', 0, 1),
(90184, 9, 1, 'Warrior', 0, 3, 128, 910443, 0, 0, 0, '', 0, 1);

-- Remove any previous minor rows from the old class lists, then restore major stock.
DELETE FROM `npc_vendor` WHERE `entry` BETWEEN 910386 AND 910395;
DELETE FROM `npc_vendor` WHERE `entry` BETWEEN 910434 AND 910443;
DELETE FROM `npc_vendor` WHERE `entry` = 910386;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910386, 0, 43533, 0, 0, 0),
(910386, 1, 43534, 0, 0, 0),
(910386, 2, 43536, 0, 0, 0),
(910386, 3, 43537, 0, 0, 0),
(910386, 4, 43538, 0, 0, 0),
(910386, 5, 43541, 0, 0, 0),
(910386, 6, 43542, 0, 0, 0),
(910386, 7, 43543, 0, 0, 0),
(910386, 8, 43545, 0, 0, 0),
(910386, 9, 43546, 0, 0, 0),
(910386, 10, 43547, 0, 0, 0),
(910386, 11, 43548, 0, 0, 0),
(910386, 12, 43549, 0, 0, 0),
(910386, 13, 43550, 0, 0, 0),
(910386, 14, 43551, 0, 0, 0),
(910386, 15, 43552, 0, 0, 0),
(910386, 16, 43553, 0, 0, 0),
(910386, 17, 43554, 0, 0, 0),
(910386, 18, 43825, 0, 0, 0),
(910386, 19, 43826, 0, 0, 0),
(910386, 20, 43827, 0, 0, 0),
(910386, 21, 44432, 0, 0, 0),
(910386, 22, 45799, 0, 0, 0),
(910386, 23, 45800, 0, 0, 0),
(910386, 24, 45803, 0, 0, 0),
(910386, 25, 45804, 0, 0, 0),
(910386, 26, 45805, 0, 0, 0),
(910386, 27, 45806, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910434;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910434, 0, 43535, 0, 0, 0),
(910434, 1, 43539, 0, 0, 0),
(910434, 2, 43544, 0, 0, 0),
(910434, 3, 43671, 0, 0, 0),
(910434, 4, 43672, 0, 0, 0),
(910434, 5, 43673, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910387;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910387, 0, 40896, 0, 0, 0),
(910387, 1, 40897, 0, 0, 0),
(910387, 2, 40899, 0, 0, 0),
(910387, 3, 40900, 0, 0, 0),
(910387, 4, 40901, 0, 0, 0),
(910387, 5, 40902, 0, 0, 0),
(910387, 6, 40903, 0, 0, 0),
(910387, 7, 40906, 0, 0, 0),
(910387, 8, 40908, 0, 0, 0),
(910387, 9, 40909, 0, 0, 0),
(910387, 10, 40912, 0, 0, 0),
(910387, 11, 40913, 0, 0, 0),
(910387, 12, 40914, 0, 0, 0),
(910387, 13, 40915, 0, 0, 0),
(910387, 14, 40916, 0, 0, 0),
(910387, 15, 40919, 0, 0, 0),
(910387, 16, 40920, 0, 0, 0),
(910387, 17, 40921, 0, 0, 0),
(910387, 18, 40922, 0, 0, 0),
(910387, 19, 40923, 0, 0, 0),
(910387, 20, 40924, 0, 0, 0),
(910387, 21, 44928, 0, 0, 0),
(910387, 22, 45601, 0, 0, 0),
(910387, 23, 45602, 0, 0, 0),
(910387, 24, 45603, 0, 0, 0),
(910387, 25, 45604, 0, 0, 0),
(910387, 26, 45622, 0, 0, 0),
(910387, 27, 45623, 0, 0, 0),
(910387, 28, 46372, 0, 0, 0),
(910387, 29, 48720, 0, 0, 0),
(910387, 30, 50125, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910435;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910435, 0, 43316, 0, 0, 0),
(910435, 1, 43331, 0, 0, 0),
(910435, 2, 43332, 0, 0, 0),
(910435, 3, 43334, 0, 0, 0),
(910435, 4, 43335, 0, 0, 0),
(910435, 5, 43674, 0, 0, 0),
(910435, 6, 44922, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910388;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910388, 0, 42897, 0, 0, 0),
(910388, 1, 42898, 0, 0, 0),
(910388, 2, 42899, 0, 0, 0),
(910388, 3, 42900, 0, 0, 0),
(910388, 4, 42901, 0, 0, 0),
(910388, 5, 42902, 0, 0, 0),
(910388, 6, 42903, 0, 0, 0),
(910388, 7, 42904, 0, 0, 0),
(910388, 8, 42905, 0, 0, 0),
(910388, 9, 42906, 0, 0, 0),
(910388, 10, 42907, 0, 0, 0),
(910388, 11, 42908, 0, 0, 0),
(910388, 12, 42909, 0, 0, 0),
(910388, 13, 42910, 0, 0, 0),
(910388, 14, 42911, 0, 0, 0),
(910388, 15, 42912, 0, 0, 0),
(910388, 16, 42913, 0, 0, 0),
(910388, 17, 42914, 0, 0, 0),
(910388, 18, 42915, 0, 0, 0),
(910388, 19, 42916, 0, 0, 0),
(910388, 20, 42917, 0, 0, 0),
(910388, 21, 45625, 0, 0, 0),
(910388, 22, 45731, 0, 0, 0),
(910388, 23, 45732, 0, 0, 0),
(910388, 24, 45733, 0, 0, 0),
(910388, 25, 45734, 0, 0, 0),
(910388, 26, 45735, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910436;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910436, 0, 43338, 0, 0, 0),
(910436, 1, 43350, 0, 0, 0),
(910436, 2, 43351, 0, 0, 0),
(910436, 3, 43354, 0, 0, 0),
(910436, 4, 43355, 0, 0, 0),
(910436, 5, 43356, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910389;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910389, 0, 42734, 0, 0, 0),
(910389, 1, 42735, 0, 0, 0),
(910389, 2, 42736, 0, 0, 0),
(910389, 3, 42737, 0, 0, 0),
(910389, 4, 42738, 0, 0, 0),
(910389, 5, 42739, 0, 0, 0),
(910389, 6, 42740, 0, 0, 0),
(910389, 7, 42741, 0, 0, 0),
(910389, 8, 42742, 0, 0, 0),
(910389, 9, 42743, 0, 0, 0),
(910389, 10, 42744, 0, 0, 0),
(910389, 11, 42745, 0, 0, 0),
(910389, 12, 42746, 0, 0, 0),
(910389, 13, 42747, 0, 0, 0),
(910389, 14, 42748, 0, 0, 0),
(910389, 15, 42749, 0, 0, 0),
(910389, 16, 42750, 0, 0, 0),
(910389, 17, 42751, 0, 0, 0),
(910389, 18, 42752, 0, 0, 0),
(910389, 19, 42753, 0, 0, 0),
(910389, 20, 42754, 0, 0, 0),
(910389, 21, 44684, 0, 0, 0),
(910389, 22, 44955, 0, 0, 0),
(910389, 23, 45736, 0, 0, 0),
(910389, 24, 45737, 0, 0, 0),
(910389, 25, 45738, 0, 0, 0),
(910389, 26, 45739, 0, 0, 0),
(910389, 27, 45740, 0, 0, 0),
(910389, 28, 50045, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910437;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910437, 0, 43339, 0, 0, 0),
(910437, 1, 43357, 0, 0, 0),
(910437, 2, 43359, 0, 0, 0),
(910437, 3, 43360, 0, 0, 0),
(910437, 4, 43361, 0, 0, 0),
(910437, 5, 43362, 0, 0, 0),
(910437, 6, 43364, 0, 0, 0),
(910437, 7, 44920, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910390;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910390, 0, 41092, 0, 0, 0),
(910390, 1, 41094, 0, 0, 0),
(910390, 2, 41095, 0, 0, 0),
(910390, 3, 41096, 0, 0, 0),
(910390, 4, 41097, 0, 0, 0),
(910390, 5, 41098, 0, 0, 0),
(910390, 6, 41099, 0, 0, 0),
(910390, 7, 41100, 0, 0, 0),
(910390, 8, 41101, 0, 0, 0),
(910390, 9, 41102, 0, 0, 0),
(910390, 10, 41103, 0, 0, 0),
(910390, 11, 41104, 0, 0, 0),
(910390, 12, 41105, 0, 0, 0),
(910390, 13, 41106, 0, 0, 0),
(910390, 14, 41107, 0, 0, 0),
(910390, 15, 41108, 0, 0, 0),
(910390, 16, 41109, 0, 0, 0),
(910390, 17, 41110, 0, 0, 0),
(910390, 18, 43867, 0, 0, 0),
(910390, 19, 43868, 0, 0, 0),
(910390, 20, 43869, 0, 0, 0),
(910390, 21, 45741, 0, 0, 0),
(910390, 22, 45742, 0, 0, 0),
(910390, 23, 45743, 0, 0, 0),
(910390, 24, 45744, 0, 0, 0),
(910390, 25, 45745, 0, 0, 0),
(910390, 26, 45746, 0, 0, 0),
(910390, 27, 45747, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910438;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910438, 0, 43340, 0, 0, 0),
(910438, 1, 43365, 0, 0, 0),
(910438, 2, 43366, 0, 0, 0),
(910438, 3, 43367, 0, 0, 0),
(910438, 4, 43368, 0, 0, 0),
(910438, 5, 43369, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910391;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910391, 0, 42396, 0, 0, 0),
(910391, 1, 42397, 0, 0, 0),
(910391, 2, 42398, 0, 0, 0),
(910391, 3, 42399, 0, 0, 0),
(910391, 4, 42400, 0, 0, 0),
(910391, 5, 42401, 0, 0, 0),
(910391, 6, 42402, 0, 0, 0),
(910391, 7, 42403, 0, 0, 0),
(910391, 8, 42404, 0, 0, 0),
(910391, 9, 42405, 0, 0, 0),
(910391, 10, 42406, 0, 0, 0),
(910391, 11, 42407, 0, 0, 0),
(910391, 12, 42408, 0, 0, 0),
(910391, 13, 42409, 0, 0, 0),
(910391, 14, 42410, 0, 0, 0),
(910391, 15, 42411, 0, 0, 0),
(910391, 16, 42412, 0, 0, 0),
(910391, 17, 42414, 0, 0, 0),
(910391, 18, 42415, 0, 0, 0),
(910391, 19, 42416, 0, 0, 0),
(910391, 20, 42417, 0, 0, 0),
(910391, 21, 45753, 0, 0, 0),
(910391, 22, 45755, 0, 0, 0),
(910391, 23, 45756, 0, 0, 0),
(910391, 24, 45757, 0, 0, 0),
(910391, 25, 45758, 0, 0, 0),
(910391, 26, 45760, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910439;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910439, 0, 43342, 0, 0, 0),
(910439, 1, 43370, 0, 0, 0),
(910439, 2, 43371, 0, 0, 0),
(910439, 3, 43372, 0, 0, 0),
(910439, 4, 43373, 0, 0, 0),
(910439, 5, 43374, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910392;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910392, 0, 42954, 0, 0, 0),
(910392, 1, 42955, 0, 0, 0),
(910392, 2, 42956, 0, 0, 0),
(910392, 3, 42957, 0, 0, 0),
(910392, 4, 42958, 0, 0, 0),
(910392, 5, 42959, 0, 0, 0),
(910392, 6, 42960, 0, 0, 0),
(910392, 7, 42961, 0, 0, 0),
(910392, 8, 42962, 0, 0, 0),
(910392, 9, 42963, 0, 0, 0),
(910392, 10, 42964, 0, 0, 0),
(910392, 11, 42965, 0, 0, 0),
(910392, 12, 42966, 0, 0, 0),
(910392, 13, 42967, 0, 0, 0),
(910392, 14, 42968, 0, 0, 0),
(910392, 15, 42969, 0, 0, 0),
(910392, 16, 42970, 0, 0, 0),
(910392, 17, 42971, 0, 0, 0),
(910392, 18, 42972, 0, 0, 0),
(910392, 19, 42973, 0, 0, 0),
(910392, 20, 42974, 0, 0, 0),
(910392, 21, 45761, 0, 0, 0),
(910392, 22, 45762, 0, 0, 0),
(910392, 23, 45764, 0, 0, 0),
(910392, 24, 45766, 0, 0, 0),
(910392, 25, 45767, 0, 0, 0),
(910392, 26, 45768, 0, 0, 0),
(910392, 27, 45769, 0, 0, 0),
(910392, 28, 45908, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910440;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910440, 0, 43343, 0, 0, 0),
(910440, 1, 43376, 0, 0, 0),
(910440, 2, 43377, 0, 0, 0),
(910440, 3, 43378, 0, 0, 0),
(910440, 4, 43379, 0, 0, 0),
(910440, 5, 43380, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910393;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910393, 0, 41517, 0, 0, 0),
(910393, 1, 41518, 0, 0, 0),
(910393, 2, 41524, 0, 0, 0),
(910393, 3, 41526, 0, 0, 0),
(910393, 4, 41527, 0, 0, 0),
(910393, 5, 41529, 0, 0, 0),
(910393, 6, 41530, 0, 0, 0),
(910393, 7, 41531, 0, 0, 0),
(910393, 8, 41532, 0, 0, 0),
(910393, 9, 41533, 0, 0, 0),
(910393, 10, 41534, 0, 0, 0),
(910393, 11, 41535, 0, 0, 0),
(910393, 12, 41536, 0, 0, 0),
(910393, 13, 41537, 0, 0, 0),
(910393, 14, 41538, 0, 0, 0),
(910393, 15, 41539, 0, 0, 0),
(910393, 16, 41540, 0, 0, 0),
(910393, 17, 41541, 0, 0, 0),
(910393, 18, 41542, 0, 0, 0),
(910393, 19, 41547, 0, 0, 0),
(910393, 20, 41552, 0, 0, 0),
(910393, 21, 45770, 0, 0, 0),
(910393, 22, 45771, 0, 0, 0),
(910393, 23, 45772, 0, 0, 0),
(910393, 24, 45775, 0, 0, 0),
(910393, 25, 45776, 0, 0, 0),
(910393, 26, 45777, 0, 0, 0),
(910393, 27, 45778, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910441;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910441, 0, 43344, 0, 0, 0),
(910441, 1, 43381, 0, 0, 0),
(910441, 2, 43385, 0, 0, 0),
(910441, 3, 43386, 0, 0, 0),
(910441, 4, 43388, 0, 0, 0),
(910441, 5, 43725, 0, 0, 0),
(910441, 6, 44923, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910394;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910394, 0, 42453, 0, 0, 0),
(910394, 1, 42454, 0, 0, 0),
(910394, 2, 42455, 0, 0, 0),
(910394, 3, 42456, 0, 0, 0),
(910394, 4, 42457, 0, 0, 0),
(910394, 5, 42458, 0, 0, 0),
(910394, 6, 42459, 0, 0, 0),
(910394, 7, 42460, 0, 0, 0),
(910394, 8, 42461, 0, 0, 0),
(910394, 9, 42462, 0, 0, 0),
(910394, 10, 42463, 0, 0, 0),
(910394, 11, 42464, 0, 0, 0),
(910394, 12, 42465, 0, 0, 0),
(910394, 13, 42466, 0, 0, 0),
(910394, 14, 42467, 0, 0, 0),
(910394, 15, 42468, 0, 0, 0),
(910394, 16, 42469, 0, 0, 0),
(910394, 17, 42470, 0, 0, 0),
(910394, 18, 42471, 0, 0, 0),
(910394, 19, 42472, 0, 0, 0),
(910394, 20, 42473, 0, 0, 0),
(910394, 21, 45779, 0, 0, 0),
(910394, 22, 45780, 0, 0, 0),
(910394, 23, 45781, 0, 0, 0),
(910394, 24, 45782, 0, 0, 0),
(910394, 25, 45783, 0, 0, 0),
(910394, 26, 45785, 0, 0, 0),
(910394, 27, 45789, 0, 0, 0),
(910394, 28, 50077, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910442;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910442, 0, 43389, 0, 0, 0),
(910442, 1, 43390, 0, 0, 0),
(910442, 2, 43391, 0, 0, 0),
(910442, 3, 43392, 0, 0, 0),
(910442, 4, 43393, 0, 0, 0),
(910442, 5, 43394, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910395;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910395, 0, 43412, 0, 0, 0),
(910395, 1, 43413, 0, 0, 0),
(910395, 2, 43414, 0, 0, 0),
(910395, 3, 43415, 0, 0, 0),
(910395, 4, 43416, 0, 0, 0),
(910395, 5, 43417, 0, 0, 0),
(910395, 6, 43418, 0, 0, 0),
(910395, 7, 43419, 0, 0, 0),
(910395, 8, 43420, 0, 0, 0),
(910395, 9, 43421, 0, 0, 0),
(910395, 10, 43422, 0, 0, 0),
(910395, 11, 43423, 0, 0, 0),
(910395, 12, 43424, 0, 0, 0),
(910395, 13, 43425, 0, 0, 0),
(910395, 14, 43426, 0, 0, 0),
(910395, 15, 43427, 0, 0, 0),
(910395, 16, 43428, 0, 0, 0),
(910395, 17, 43429, 0, 0, 0),
(910395, 18, 43430, 0, 0, 0),
(910395, 19, 43431, 0, 0, 0),
(910395, 20, 43432, 0, 0, 0),
(910395, 21, 45790, 0, 0, 0),
(910395, 22, 45792, 0, 0, 0),
(910395, 23, 45793, 0, 0, 0),
(910395, 24, 45794, 0, 0, 0),
(910395, 25, 45795, 0, 0, 0),
(910395, 26, 45797, 0, 0, 0);
DELETE FROM `npc_vendor` WHERE `entry` = 910443;
INSERT INTO `npc_vendor` (`entry`, `slot`, `item`, `maxcount`, `incrtime`, `ExtendedCost`) VALUES
(910443, 0, 43395, 0, 0, 0),
(910443, 1, 43396, 0, 0, 0),
(910443, 2, 43397, 0, 0, 0),
(910443, 3, 43398, 0, 0, 0),
(910443, 4, 43399, 0, 0, 0),
(910443, 5, 43400, 0, 0, 0),
(910443, 6, 49084, 0, 0, 0);

-- Fresh installs use the tracked x1 normal-quality default instead of the old generated x3 value.
UPDATE `item_template` AS `item`
INNER JOIN `warband_supplier_price` AS `original`
    ON `original`.`entry` = `item`.`entry` SET `item`.`BuyPrice` = `original`.`base_sell`,
    `item`.`SellPrice` = `original`.`base_sell`
WHERE `original`.`quality` = 1
AND NOT EXISTS (SELECT 1 FROM `warband_setting` WHERE `setting` = 'supplier.mult.1');

COMMIT;

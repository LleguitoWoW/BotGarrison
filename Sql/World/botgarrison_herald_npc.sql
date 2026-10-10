-- ============================================================
--  BotGarrison Herald (goblin pregonero)  entry 900101
--  Base: WORLD
--  Modelo en creature_template_model (AzerothCore moderno)
--  CreatureDisplayID 7052 = mismo que Gazlowe (goblin real)
-- ============================================================

DELETE FROM `creature_template_model` WHERE `CreatureID` = 900101;
DELETE FROM `creature_template` WHERE `entry` = 900101;

INSERT INTO `creature_template` (
  `entry`, `difficulty_entry_1`, `difficulty_entry_2`, `difficulty_entry_3`,
  `KillCredit1`, `KillCredit2`,
  `name`, `subname`, `IconName`, `gossip_menu_id`,
  `minlevel`, `maxlevel`, `exp`, `faction`, `npcflag`,
  `speed_walk`, `speed_run`, `speed_swim`, `speed_flight`, `detection_range`,
  `rank`, `dmgschool`, `BaseAttackTime`, `RangeAttackTime`,
  `BaseVariance`, `RangeVariance`, `unit_class`, `unit_flags`, `unit_flags2`,
  `dynamicflags`, `family`, `type`, `type_flags`,
  `lootid`, `pickpocketloot`, `skinloot`, `PetSpellDataId`, `VehicleId`,
  `mingold`, `maxgold`, `AIName`, `MovementType`, `HoverHeight`,
  `HealthModifier`, `ManaModifier`, `ArmorModifier`, `DamageModifier`,
  `ExperienceModifier`, `RacialLeader`, `movementId`, `RegenHealth`,
  `CreatureImmunitiesId`, `flags_extra`, `ScriptName`, `VerifiedBuild`
) VALUES (
  900101, 0, 0, 0,
  0, 0,
  'Grex Ragatinta', 'Explorador', '', 0,
  80, 80, 2, 35, 1,
  1, 1.14286, 1, 1, 20,
  0, 0, 2000, 2000,
  1, 1, 1, 0, 2048,
  0, 0, 7, 0,
  0, 0, 0, 0, 0,
  0, 0, '', 0, 1,
  1, 1, 1, 1,
  1, 0, 0, 1,
  0, 2, '', 0
);

-- 7052 = display de Gazlowe (goblin). Alternativas: 7109, 7108, 7337
INSERT INTO `creature_template_model`
(`CreatureID`, `Idx`, `CreatureDisplayID`, `DisplayScale`, `Probability`, `VerifiedBuild`)
VALUES
(900101, 0, 7052, 1, 1, 0);

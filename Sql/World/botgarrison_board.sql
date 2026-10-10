-- ============================================================
--  BotGarrison — Tablón de Misiones (GameObject)
--  Base de datos: WORLD
--  displayId 222 = The Map of Zul'Aman
-- ============================================================

DELETE FROM `gameobject_template` WHERE `entry` = 900100;
INSERT INTO `gameobject_template`
(`entry`,`type`,`displayId`,`name`,`IconName`,`castBarCaption`,`unk1`,`size`,
 `Data0`,`Data1`,`Data2`,`Data3`,`Data4`,`Data5`,`Data6`,`Data7`,`Data8`,`Data9`,
 `Data10`,`Data11`,`Data12`,`Data13`,`Data14`,`Data15`,`Data16`,`Data17`,`Data18`,`Data19`,
 `Data20`,`Data21`,`Data22`,`Data23`,`AIName`,`ScriptName`,`VerifiedBuild`)
VALUES
(900100, 10, 222, 'Mapa de Misiones', '', '', '', 1.0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
 0, 0, 0, 0, '', '', 0);

-- Spawn en juego (GM): .gobject add 900100

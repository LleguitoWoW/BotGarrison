-- ============================================================
--  Texto de gossip del goblin Grex (explicacion del mod)
--  Base: WORLD — npc_text ID 900101
--  Compatible AzerothCore (columnas em0_x, no EmoteDelay)
-- ============================================================

DELETE FROM `npc_text` WHERE `ID` = 900101;

INSERT INTO `npc_text` (
  `ID`,
  `text0_0`,
  `text0_1`,
  `BroadcastTextID0`,
  `lang0`,
  `Probability0`,
  `em0_0`, `em0_1`, `em0_2`, `em0_3`, `em0_4`, `em0_5`
) VALUES (
  900101,
  'Psst. Ese mapa de ahi al lado no es decoracion.$B$BEs el Mapa de Misiones de Companeros.$B$BSirve para enviar a tus alters / playerbots de mision mientras tu haces otras cosas.$B$BComo funciona:$B1) Reune a tus bots (grupo o logueados).$B2) Interactua con el mapa.$B3) Elige una mision segun nivel, roles y equipo.$B4) Tus companeros parten un rato; al terminar, reclama el resultado en el mapa.$B$BSi tienen exito obtienes oro, objetos y experiencia (mas para los bots).$BEl equipo de los bots y el tuyo influyen en el exito.$BCada mision completada entra en cooldown de lista antes de volver a salir.$B$BYo solo anuncio el negocio. El trabajo lo hacen tus muchachos.',
  'Psst. Ese mapa de ahi al lado no es decoracion.$B$BEs el Mapa de Misiones de Companeros.$B$BSirve para enviar a tus alters / playerbots de mision mientras tu haces otras cosas.$B$BComo funciona:$B1) Reune a tus bots (grupo o logueados).$B2) Interactua con el mapa.$B3) Elige una mision segun nivel, roles y equipo.$B4) Tus companeros parten un rato; al terminar, reclama el resultado en el mapa.$B$BSi tienen exito obtienes oro, objetos y experiencia (mas para los bots).$BEl equipo de los bots y el tuyo influyen en el exito.$BCada mision completada entra en cooldown de lista antes de volver a salir.$B$BYo solo anuncio el negocio. El trabajo lo hacen tus muchachos.',
  0,
  0,
  1,
  0, 0, 0, 0, 0, 0
);

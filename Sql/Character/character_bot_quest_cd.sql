-- ============================================================
--  BotGarrison — CD de lista por mision (15 min al completar)
--  Base de datos: CHARACTERS
-- ============================================================

CREATE TABLE IF NOT EXISTS `character_bot_quest_cd` (
  `player_guid` INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `quest_id`    INT UNSIGNED NOT NULL,
  `expiry`      INT UNSIGNED NOT NULL COMMENT 'unix timestamp',
  PRIMARY KEY (`player_guid`, `quest_id`),
  KEY `idx_expiry` (`expiry`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

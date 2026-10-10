-- ============================================================
--  BotGarrison — Persistencia de misiones activas
--  Base de datos: CHARACTERS
-- ============================================================

CREATE TABLE IF NOT EXISTS `character_bot_missions` (
  `player_guid`  INT UNSIGNED NOT NULL COMMENT 'characters.guid',
  `quest_id`     INT UNSIGNED NOT NULL DEFAULT 0,
  `quest_name`   VARCHAR(64)  NOT NULL DEFAULT '',
  `difficulty`   VARCHAR(16)  NOT NULL DEFAULT 'NORMAL',
  `start_time`   INT UNSIGNED NOT NULL DEFAULT 0,
  `duration`     INT UNSIGNED NOT NULL DEFAULT 300,
  `end_time`     INT UNSIGNED NOT NULL DEFAULT 0,
  `gold_min`     INT UNSIGNED NOT NULL DEFAULT 100,
  `gold_max`     INT UNSIGNED NOT NULL DEFAULT 500,
  `bot_guids`    TEXT         NULL COMMENT 'lista de guidLow separados por coma',
  `bot_names`    TEXT         NULL,
  `power`        FLOAT        NOT NULL DEFAULT 0,
  `chance`       FLOAT        NOT NULL DEFAULT 0,
  PRIMARY KEY (`player_guid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

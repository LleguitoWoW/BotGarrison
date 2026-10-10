# BotGarrison

**ES** · Sistema de misiones de compañeros para **AzerothCore** + **Playerbots** (altbots).  
**EN** · Companion mission system for **AzerothCore** + **Playerbots** (altbots).

Estilo *Garrison missions*: envías a tus alters/bots a misiones mientras haces otras cosas y reclamas oro, objetos y XP al terminar.  
*Garrison-style* missions: send your alts/bots on missions while you do other things, then claim gold, items, and XP.

Sin addon de cliente — GameObject (mapa) + scripts **Eluna (Lua)**.  
No client addon required — GameObject (map) + **Eluna (Lua)** scripts.

---

## ¿Para qué sirve? · What is it for?

| ES | EN |
|----|----|
| Dar utilidad a los playerbots cuando no los usas en combate | Give playerbots a use when not in combat |
| Progresión pasiva (oro, loot, XP) con riesgo de fallo | Passive progress (gold, loot, XP) with failure risk |
| Punto de interés en ciudad sin UI custom | City landmark without a custom UI |

---

## Componentes · Components

| Pieza · Piece | Entry / file | Descripción · Description |
|---------------|--------------|---------------------------|
| **Tablón / Map** | GO `900100` | Ver misiones, enviar bots, reclamar · View missions, send bots, claim |
| **Herald (goblin)** | NPC `900101` | Anuncia el sistema y explica el mod · Announces the system and explains the mod |
| **BotGarrison_Server.lua** | `lua_scripts/` | Lógica principal · Core logic |
| **BotGarrison_Herald.lua** | `lua_scripts/` | Frases + gossip del goblin · Goblin lines + gossip |
| SQL **world** | `sql/` | Plantillas GO/NPC + `npc_text` · GO/NPC templates + `npc_text` |
| SQL **characters** | `sql/` | Misión activa + CD de lista · Active mission + list CD |

---

## Cómo se juega · How to play

1. Ten **altbots** disponibles (logueados / en grupo). · Have **altbots** available (logged in / in group).  
2. (Opcional) Habla con **Grex** para leer la explicación en su gossip. · (Optional) Talk to **Grex** for the explanation in his gossip.  
3. Interactúa con el **mapa** (GO `900100`). · Interact with the **map** (GO `900100`).  
4. Elige una misión. · Choose a mission.  
5. Si cumples requisitos, **envías** a los bots. · If requirements are met, **send** the bots.  
6. Los bots “parten” (park / teleport). · Bots “leave” (park / teleport).  
7. Cuando acaba el tiempo, **reclama** en el mapa. · When the timer ends, **claim** on the map.  
8. Éxito o fallo según probabilidad; en éxito: oro, ítem y XP. · Success or fail by chance; on success: gold, item, and XP.

### Menú del mapa · Map menu

- Ver misiones disponibles · Available missions  
- Ver misiones en **cooldown de lista** · Missions on **list cooldown**  
- Contador si hay misión en curso · Timer if a mission is running  
- Reclamar / cancelar · Claim / cancel  

---

## Reglas · Rules

### Éxito · Success

- **Poder de grupo** = GS medio de los bots + bonus de **capitán** (GS del jugador).  
  **Group power** = average bot GS + **captain** bonus (player GS).  
- La dificultad modifica la probabilidad. · Difficulty affects the chance.  
- Equipo muy bajo puede **topar** el éxito (p. ej. 40 %). · Very low gear can **cap** success (e.g. 40%).  
- Algunas misiones piden roles (tank / heal / dps). · Some missions require roles (tank / heal / dps).

### Recompensas (éxito) · Rewards (success)

- **Oro** escalado al nivel · **Gold** scaled by level  
- **Objeto** aleatorio · Random **item**  
- **XP** (más para los bots que para el jugador) · **XP** (more for bots than for the player)

### Cooldowns

- **Lista (~15 min):** tras completar/fallar, esa misión no vuelve al tablón hasta que expire (`character_bot_quest_cd`).  
  **List CD (~15 min):** after complete/fail, that mission stays off the board until it expires.  
- **Fallo:** tiempo de recuperación del destacamento según dificultad.  
  **Fail:** recovery time for the squad by difficulty.

### Rotación · Rotation

No se muestran todas las misiones a la vez; hay un subconjunto por nivel y CDs.  
Not all missions are shown at once; a subset is offered by level and CDs.

---

## Instalación · Installation

### 1. Base de datos · Database

**WORLD**

```sql
SOURCE sql/botgarrison_board.sql;
SOURCE sql/botgarrison_herald_npc.sql;
SOURCE sql/botgarrison_herald_gossip_text.sql;
```

> El modelo del NPC va en `creature_template_model` (no `modelid1`).  
> NPC model is in `creature_template_model` (not `modelid1`).

**CHARACTERS**

```sql
SOURCE sql/character_bot_missions.sql;
SOURCE sql/character_bot_quest_cd.sql;
```

### 2. Lua

Copia a `lua_scripts` del worldserver · Copy into the worldserver `lua_scripts` folder:

- `BotGarrison_Server.lua`
- `BotGarrison_Herald.lua`

Reinicia el worldserver o recarga Eluna. · Restart worldserver or reload Eluna.

### 3. Spawns

```text
.gobject add 900100
.npc add 900101
```

Ajusta con `.gobject turn` / `.gobject move` / `.npc move`.  
Tablón por defecto: mapa Zul'Aman (`displayId 222`).

---

## Requisitos · Requirements

- **AzerothCore** (WotLK 3.3.5)  
- **mod-eluna** (ALE)  
- **Playerbots** (altbots)  
- APIs Eluna de playerbots (`GetAltBots` / park, etc. — adapta si tu fork usa otros nombres).  
  Playerbots Eluna APIs (`GetAltBots` / park, etc. — adapt if your fork differs).

---

## Archivos · Files

| Archivo · File | Base | Uso · Purpose |
|----------------|------|----------------|
| `sql/botgarrison_board.sql` | world | GO 900100 |
| `sql/botgarrison_board_UPDATE_only.sql` | world | Solo aspecto del GO · GO look only |
| `sql/botgarrison_herald_npc.sql` | world | NPC 900101 + model |
| `sql/botgarrison_herald_gossip_text.sql` | world | Gossip `npc_text` 900101 |
| `sql/character_bot_missions.sql` | characters | Active mission |
| `sql/character_bot_quest_cd.sql` | characters | List CD |
| `lua_scripts/BotGarrison_Server.lua` | — | Core |
| `lua_scripts/BotGarrison_Herald.lua` | — | Herald |

---

## Personalización · Customization

| Qué · What | Dónde · Where |
|------------|----------------|
| Frases del goblin · Goblin lines | `LINES` in `BotGarrison_Herald.lua` |
| Texto del gossip · Gossip body | `npc_text` ID **900101** / SQL gossip |
| Intervalo de anuncios · Yell interval | `INTERVAL_MS` in Herald |
| Misiones, oro, XP, slots | `QUESTS` + `CFG` in `BotGarrison_Server.lua` |

```text
.reload npc_text
```

---

## Flujo técnico · Technical flow

1. Jugador abre el GO → gossip Eluna. · Player opens GO → Eluna gossip.  
2. Al aceptar: bots, poder/chance, save en memoria + BD, park. · On accept: bots, power/chance, save memory + DB, park.  
3. Timer → misión **lista**. · Timer → mission **ready**.  
4. Reclamar → roll, rewards, CD de lista, recall bots. · Claim → roll, rewards, list CD, recall bots.  
5. Logout: la misión puede restaurarse desde BD. · Logout: mission can be restored from DB.

---

## Notas · Notes

- El herald usa **SAY** + gesto de hablar (`ONESHOT_TALK`). Otros emotes en modelos goblin suelen fallar.  
  Herald uses **SAY** + talk gesture (`ONESHOT_TALK`). Other emotes on goblin models often fail.  
- CD de lista: por personaje y por id de misión, persistente.  
  List CD: per character and mission id, persistent.  
- Los SQL de plantilla **no** incluyen coordenadas de spawn; las colocas tú.  
  Template SQL does **not** include spawn coords; you place them.

---

## Origen · Origin

Evolución de la idea de **BotQuest** (misiones para NPCBots), adaptada a **Playerbots** y a un flujo nativo tipo garrison con mapa en ciudad, sin addon obligatorio.

Evolution of the **BotQuest** idea (missions for NPCBots), adapted to **Playerbots** and a native garrison-style city map flow, with no required addon.

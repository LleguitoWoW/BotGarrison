# BotGarrison — Companion Missions / Misiones de Compañeros

**English** · [Español](#español)

**Version / Versión:** client / cliente `v2.2` · server / servidor `v0.9.0`

---

# English

Garrison-style missions for altbots/playerbots (AzerothCore 3.3.5 + Eluna + AIO).
You send your companions out from the **Mission Board**, they stay away for the mission time,
and come back with gold, an item and experience, or empty-handed if the mission fails.

## Files

| File | Where it goes |
|---|---|
| `BotGarrison_Server.lua` | server `lua_scripts` folder |
| `BotGarrison.lua` + `BotGarrison.toc` | client `Interface\AddOns\BotGarrison\` |

## What's new

### Dedicated board panel
Clicking the board no longer opens the text gossip menu. It opens the addon panel, which has three views:

- **Board (no mission):** party summary (companions, T/H/D, average GS, captain, power), a list of
  offers with difficulty, duration and success chance in colour, and details for the selected mission
  (description, reward and requirements). **Send companions** button and a **Bloqueadas (n)** button
  with a tooltip listing missions on cooldown.
- **Mission in progress / ready:** timer, progress bar, party and estimated reward.
  **Claim** and **Cancel** buttons (cancel asks for confirmation).
- **No mission and away from the board:** a notice telling you to go to the board.

The mission button that used to sit on the character window has been removed. The minimap icon
pulses green when a mission finishes.

### Send only from the board (configurable)
By default you can only pick and send missions **next to the board**: if you walk away, the panel
returns to the notice screen on its own and the server rejects the send. This can be changed in
`CFG` (see [Configuration](#configuration)).

### My Diary ("Mi Diario")
The **Mi Diario** button (or `/bg diario`) is a log of the missions you claim.

- Summary: total missions, successes, failures, success rate and total gold earned.
- Each entry: name, difficulty, date and time, party members, success or failure,
  gold and item received (coloured by quality).
- Keeps the latest 200 entries, newest first. **Borrar diario** button with confirmation.
- **No database involved.** The server sends each result and the addon stores it on the client
  (`SavedVariablesPerCharacter`), so it survives restarts and is separate for each character.
  Cancelled missions are not logged.

### Companions salute when leaving
When a mission starts, each companion stops, turns to face you, **salutes**, and then goes to the
parking spot. They also salute when they come back.

### Horn when the time is up
The mission-complete sound plays when the mission **time ends** (also if it ended while you were
offline), not when you claim it.

### Real gear score and difficulty tuning
- The panel's **GS** is computed by the server (not by your GS addon): by default it adds up the item level of
  each companion's equipped gear, the same scale as GearScore. `GS_SOURCE = "api"` uses the core's value instead.
- Difficulty is adjustable in `CFG`: `SUCCESS_OFFSET`, `DIFFICULTY_ADJUST`, `POWER_MULT`, plus the base chances.
  The "undergeared" cap can be tuned or turned off (`UNDERGEARED_ENABLED`).

### Role detection by talents
Tank / healer / DPS are detected from each companion's **talents**, no longer from their class
(a Shadow priest or Elemental shaman counts as DPS). If the spec can't be told, they count as DPS
(`UNKNOWN_SPEC_ROLE`), and you can force a role per bot with `BOT_ROLE_OVERRIDE`.
The server console shows each bot's role and how it was detected (`rol=DPS/talentos`).

### Role icons in the party card
The party card shows **Tank, Healer and DPS icons with the count underneath**; hover for a tooltip.

### Departure effect
After the salute, each companion gathers arcane energy, fades out and then leaves, instead of just vanishing.
Configurable (`DEPART_FX*`); disable with `DEPART_FX = false`. Nothing special happens on return.

### Reward by mail when bags are full
If your bags are full when you claim, the item is **sent to your mailbox** (and you're told in chat)
instead of being lost. Turn it off with `MAIL_REWARD_IF_BAGS_FULL = false`.

### Other fixes
- The panel now receives data from the server (the server was missing the whole AIO part).
- Claiming no longer leaves the panel stuck or "resurrects" the mission.
- Per-function error log in the server console: `[BotGarrison] ERROR en <function>: ...`.
- Visual redesign: cards, progress bar, dialog header and rearranged buttons.

## Usage

| Command | Action |
|---|---|
| `/bg`, `/botgarrison`, `/companeros` | Open/close the panel |
| `/bg diario` | Open/close My Diary |
| `/bg debug` | Toggle dumping server data to chat |

Normal flow: click the board → pick a mission → **Send companions** → wait (the minimap icon
pulses when done) → **Claim** (from the panel).

## Configuration

At the top of `CFG` in `BotGarrison_Server.lua`:

| Option | Default | Effect |
|---|---|---|
| `USE_PANEL` | `true` | `true`: the board opens the panel. `false`: classic gossip menu. |
| `PANEL_REMOTE_BOARD` | `false` | `true`: pick and send missions from anywhere via `/bg` or the minimap. |
| `BOARD_RANGE` | `12` | Max yards from the board when `PANEL_REMOTE_BOARD = false`. |
| `SALUTE_FACE_PLAYER` | `true` | Companions turn to face you before saluting. If they don't salute, set it to `false`. |
| `DIARY_ENABLED` | `true` | Sends every resolved mission to the addon's diary. |
| `GS_SOURCE` | `"items"` | `"items"`: gear score = sum of the item level of equipped gear (real, same scale as GearScore). `"api"`: use the core's GS. |
| `GS_API_SCALE` | `1` | Multiplier for the core's GS. Some cores return an *average* ilvl (values like 37): use ~17 to convert it. |
| `GS_ESTIMATE_FROM_ITEMS` | `true` | Allows reading the equipped items. |
| `MIN_GS_PER_LEVEL` | `15` | Minimum GS expected per level. Below it the party counts as "undergeared". |
| `UNDERGEARED_MAX_SUCCESS` | `0.40` | Success cap for undergeared parties. |
| `UNDERGEARED_ENABLED` | `true` | `false` removes the "undergeared" penalty and cap entirely. |
| `UNKNOWN_SPEC_ROLE` | `"DPS"` | Role when the spec can't be detected from talents. `"CLASS"` = guess by class (old behaviour). |
| `BOT_ROLE_OVERRIDE` | `{}` | Force a bot's role: `{ ["Name"] = "DPS" }` (`TANK`/`HEAL`/`DPS`). |
| `DEPART_FX` | `true` | Departure effect (charge, fade, leave). |
| `DEPART_FX_CHARGE` / `DEPART_FX_BURST` | `{12042}` / `{}` | Visual spell IDs cast on the bot while charging / just before leaving. |
| `DEPART_FX_FADE` | `66` | Fade-out aura (`nil` = no fade). |
| `DEPART_FX_CHARGE_AT`, `_FADE_AT`, `_TELEPORT_AT` | `2400`, `3300`, `4500` | Timings in ms from pressing Send. |
| `MAIL_REWARD_IF_BAGS_FULL` | `true` | Mail the item when bags are full. |
| `SUCCESS_OFFSET` | `0.0` | Added to every mission's chance. `-0.10` = stricter, `+0.10` = easier. |
| `DIFFICULTY_ADJUST` | all `0.0` | Extra offset per difficulty (`EASY/NORMAL/HARD/ELITE`). |
| `POWER_MULT` | `1.0` | Multiplies the party's total power (<1 stricter, >1 more flexible). |
| `BASE_SUCCESS`, `POWER_PER_POINT`, `MAX_SUCCESS`, `MIN_SUCCESS` | see file | Base chance per difficulty, gain per power point, and global limits. |

> **GS note:** the "GS" shown by the panel is computed by the server, not by your GS addon. The server console prints
> `[BotGarrison] GS bots …` with each value, its source (`items`, `gs-api`, `neutral`) and the core's raw value (`api=`).

## Install / update

1. **Server:** replace `BotGarrison_Server.lua` and run `.reload eluna`.
2. **Client:** replace `BotGarrison.lua` and `BotGarrison.toc`.
3. **Quit the game and log in again** the first time you install the `.toc` with My Diary:
   `/reload` is not enough for the client to pick up the saved variables. Until then the diary
   works but is lost on logout.

## Notes

- If a player doesn't have the addon, with `USE_PANEL = true` they won't see anything when clicking the board.
- My Diary starts empty: it doesn't include missions claimed before it was installed.
- The diary lives on the client: switching computers or deleting the `WTF` folder loses it.

---

# Español

Misiones estilo Garrison para altbots/playerbots (AzerothCore 3.3.5 + Eluna + AIO).
Envías a tus compañeros desde el **Tablón de Misiones**, esperan el tiempo de la misión y vuelven
con oro, un objeto y experiencia, o con las manos vacías si la misión falla.

[English](#english)

## Archivos

| Archivo | Dónde va |
|---|---|
| `BotGarrison_Server.lua` | `lua_scripts` del servidor |
| `BotGarrison.lua` + `BotGarrison.toc` | `Interface\AddOns\BotGarrison\` del cliente |

## Novedades

### Panel propio para el tablón
Al pulsar el tablón ya no sale el menú de texto, sino el panel del addon con tres vistas:

- **Tablón (sin misión):** resumen del destacamento (compañeros, T/H/D, GS medio, capitán, poder),
  lista de ofertas con dificultad, duración y % de éxito en color, y detalle de la misión elegida
  (descripción, recompensa y requisitos). Botón **Enviar compañeros** y botón **Bloqueadas (n)**
  con las misiones en cooldown.
- **Misión en curso / lista:** temporizador, barra de progreso, destacamento y recompensa estimada.
  Botones **Reclamar** y **Cancelar** (con confirmación).
- **Sin misión y lejos del tablón:** aviso para acercarse al tablón.

El botón de misión que estaba en la ventana de personaje se ha eliminado. El icono del minimapa
parpadea en verde cuando una misión termina.

### Enviar solo desde el tablón (configurable)
Por defecto solo se puede elegir y enviar misiones **junto al tablón**: si te alejas, el panel
vuelve solo a la pantalla de aviso y el servidor rechaza el envío. Se puede cambiar en `CFG`
(ver [Configuración](#configuración)).

### Mi Diario
Botón **Mi Diario** (o `/bg diario`): registro de las misiones que reclamas.

- Resumen: misiones totales, éxitos, fallidas, % de éxito y oro total ganado.
- Cada entrada: nombre, dificultad, fecha y hora, compañeros del grupo, éxito o fallo,
  oro y objeto recibido (con el color de su calidad).
- Guarda las últimas 200 entradas, de la más reciente a la más antigua. Botón **Borrar diario**
  con confirmación.
- **No usa la base de datos.** El servidor envía cada resultado y el addon lo guarda en el
  cliente (`SavedVariablesPerCharacter`), por lo que sobrevive a reinicios y es independiente
  para cada personaje. Las misiones canceladas no se registran.

### Saludo de los compañeros al partir
Al enviar la misión, cada compañero se para, se gira hacia ti, **saluda** y después se va al
aparcamiento. También saludan al volver.

### Cuerno al terminar el tiempo
El sonido de misión completada suena cuando **termina el tiempo** de la misión (también si
terminó mientras estabas desconectado), no al reclamarla.

### GearScore real y ajuste de dificultad
- El **GS** del panel lo calcula el servidor (no tu addon de GS): por defecto suma el nivel de objeto del equipo
  puesto de cada compañero, la misma escala que el GearScore. `GS_SOURCE = "api"` usa el valor del core.
- La dificultad se ajusta en `CFG`: `SUCCESS_OFFSET`, `DIFFICULTY_ADJUST`, `POWER_MULT` y los % base.
  El tope de "equipo bajo" se puede ajustar o desactivar (`UNDERGEARED_ENABLED`).

### Detección de roles por talentos
Tank / healer / DPS se detectan por los **talentos** de cada compañero, ya no por su clase
(un sacerdote Sombras o un chamán Elemental cuenta como DPS). Si no se puede saber la rama, cuenta como DPS
(`UNKNOWN_SPEC_ROLE`), y puedes forzar el rol de un bot con `BOT_ROLE_OVERRIDE`.
La consola del servidor muestra el rol de cada bot y cómo se detectó (`rol=DPS/talentos`).

### Iconos de rol en el destacamento
La tarjeta del destacamento muestra los iconos de **Tank, Sanador y DPS con el número debajo**; con el ratón encima sale un tooltip.

### Efecto de partida
Tras el saludo, cada compañero se carga de energía arcana, se desvanece y entonces se va, en vez de desaparecer sin más.
Configurable (`DEPART_FX*`); se desactiva con `DEPART_FX = false`. Al volver no hay efecto especial.

### Recompensa por correo si las mochilas están llenas
Si al reclamar tus mochilas están llenas, el objeto **se envía a tu buzón** (y te avisa en el chat)
en lugar de perderse. Se desactiva con `MAIL_REWARD_IF_BAGS_FULL = false`.

### Otros arreglos
- El panel ahora recibe los datos del servidor (antes faltaba toda la parte AIO del servidor).
- Reclamar ya no deja el panel atascado ni "resucita" la misión.
- Registro de errores por función en la consola del servidor: `[BotGarrison] ERROR en <función>: ...`.
- Rediseño visual: tarjetas, barra de progreso, cabecera de diálogo y botones reorganizados.

## Uso

| Comando | Acción |
|---|---|
| `/bg`, `/botgarrison`, `/companeros` | Abrir/cerrar el panel |
| `/bg diario` | Abrir/cerrar Mi Diario |
| `/bg debug` | Activar/desactivar el volcado de datos del servidor en el chat |

Flujo normal: pulsa el tablón → elige una misión → **Enviar compañeros** → espera (el icono del
minimapa parpadea al terminar) → **Reclamar** (desde el panel).

## Configuración

Al inicio de `CFG` en `BotGarrison_Server.lua`:

| Opción | Defecto | Efecto |
|---|---|---|
| `USE_PANEL` | `true` | `true`: el tablón abre el panel. `false`: menú de gossip clásico. |
| `PANEL_REMOTE_BOARD` | `false` | `true`: se puede elegir y enviar desde cualquier sitio con `/bg` o el minimapa. |
| `BOARD_RANGE` | `12` | Yardas máximas al tablón si `PANEL_REMOTE_BOARD = false`. |
| `SALUTE_FACE_PLAYER` | `true` | Los compañeros se giran hacia ti antes de saludar. Si no saludan, ponlo en `false`. |
| `DIARY_ENABLED` | `true` | Envía cada misión resuelta al diario del addon. |
| `GS_SOURCE` | `"items"` | `"items"`: GS = suma del nivel de objeto del equipo puesto (real, misma escala que GearScore). `"api"`: usa el GS del core. |
| `GS_API_SCALE` | `1` | Multiplicador del GS del core. Algunos cores devuelven un ilvl *medio* (valores como 37): usa ~17 para convertirlo. |
| `GS_ESTIMATE_FROM_ITEMS` | `true` | Permite leer los objetos equipados. |
| `MIN_GS_PER_LEVEL` | `15` | GS mínimo esperado por nivel. Por debajo, el grupo cuenta como "equipo bajo". |
| `UNDERGEARED_MAX_SUCCESS` | `0.40` | Tope de éxito para grupos con equipo bajo. |
| `UNDERGEARED_ENABLED` | `true` | `false` elimina por completo la penalización y el tope por "equipo bajo". |
| `UNKNOWN_SPEC_ROLE` | `"DPS"` | Rol cuando no se detecta la rama por talentos. `"CLASS"` = por clase (comportamiento antiguo). |
| `BOT_ROLE_OVERRIDE` | `{}` | Fuerza el rol de un bot: `{ ["Nombre"] = "DPS" }` (`TANK`/`HEAL`/`DPS`). |
| `DEPART_FX` | `true` | Efecto de partida (carga, desvanecer, irse). |
| `DEPART_FX_CHARGE` / `DEPART_FX_BURST` | `{12042}` / `{}` | IDs de hechizos visuales sobre el bot al cargar / justo antes de irse. |
| `DEPART_FX_FADE` | `66` | Aura de desvanecimiento (`nil` = sin fundido). |
| `DEPART_FX_CHARGE_AT`, `_FADE_AT`, `_TELEPORT_AT` | `2400`, `3300`, `4500` | Tiempos en ms desde que pulsas Enviar. |
| `MAIL_REWARD_IF_BAGS_FULL` | `true` | Envía el objeto por correo si las mochilas están llenas. |
| `SUCCESS_OFFSET` | `0.0` | Se suma al % de todas las misiones. `-0.10` = más estricto, `+0.10` = más fácil. |
| `DIFFICULTY_ADJUST` | todo `0.0` | Ajuste extra por dificultad (`EASY/NORMAL/HARD/ELITE`). |
| `POWER_MULT` | `1.0` | Multiplica el poder total del grupo (<1 más estricto, >1 más flexible). |
| `BASE_SUCCESS`, `POWER_PER_POINT`, `MAX_SUCCESS`, `MIN_SUCCESS` | ver archivo | % base por dificultad, ganancia por punto de poder y límites globales. |

> **Nota sobre el GS:** el "GS" del panel lo calcula el servidor, no tu addon de GS. La consola del servidor imprime
> `[BotGarrison] GS bots …` con cada valor, su origen (`items`, `gs-api`, `neutral`) y el valor crudo del core (`api=`).

## Instalación y actualización

1. **Servidor:** sustituye `BotGarrison_Server.lua` y ejecuta `.reload eluna`.
2. **Cliente:** sustituye `BotGarrison.lua` y `BotGarrison.toc`.
3. **Cierra el juego y vuelve a entrar** la primera vez que instales el `.toc` con Mi Diario:
   con `/reload` no basta para que el cliente reconozca las variables guardadas. Hasta entonces
   el diario funciona, pero se pierde al salir.

## Notas

- Si un jugador no tiene el addon, con `USE_PANEL = true` no verá nada al pulsar el tablón.
- Mi Diario empieza vacío: no incluye misiones reclamadas antes de instalarlo.
- El diario está en el cliente: cambiar de ordenador o borrar la carpeta `WTF` lo pierde.


<img width="960" height="716" alt="2" src="https://github.com/user-attachments/assets/34d9e412-f985-4c3a-bf81-9eb8b9079044" />

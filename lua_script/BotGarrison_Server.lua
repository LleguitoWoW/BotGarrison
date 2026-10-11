-- ============================================================
--  BotGarrison_Server.lua  v0.4.0  (GS mínimo, oro×nivel, XP prioritaria a bots)




--  Eluna — AzerothCore + mod-playerbots
--
--  Tablón de misiones estilo Garrison para ALTBOTS.
--  Interacción: GameObject entry 900100 (gossip).
-- ============================================================

local GO_ENTRY = 900100
-- (sin protocolo BQST en chat; el tablón usa solo mensajes legibles)

-- ============================================================
--  CONFIG
-- ============================================================
local CFG = {
    QUALITIES              = { 1, 2, 3 },
    ITEM_CLASSES           = { 2, 4 },
    ARMOR_SUBCLASS_EXCLUDE = { 0, 11, 12, 13, 14 },
    WEAPON_SUBCLASS_EXCLUDE= {},
    FLAG_BLACKLIST         = 2048 + 524288,
    FLAGS_EXTRA_BLACKLIST  = 3,
    MIN_ITEM_LEVEL         = 5,
    MAX_PER_POOL           = 300,
    LEVEL_RANGES = {
        [1]={1,10}, [2]={11,20}, [3]={21,30}, [4]={31,40},
        [5]={41,50},[6]={51,60}, [7]={61,70}, [8]={71,80},
    },

    -- Bases más bajas: sin equipo decente no se llega al 50%
    BASE_SUCCESS = { EASY = 0.28, NORMAL = 0.18, HARD = 0.10, ELITE = 0.05 },
    POWER_PER_POINT = 0.025,
    MAX_SUCCESS = 0.95,
    MIN_SUCCESS = 0.05,

    FAIL_COOLDOWN_SECS = { EASY = 120, NORMAL = 300, HARD = 600, ELITE = 1200 },

    CLASS_ROLE_WEIGHT = {
        [1]=1.3, [2]=1.5, [3]=1.0, [4]=1.1, [5]=1.4,
        [6]=1.3, [7]=1.4, [8]=1.0, [9]=1.0, [11]=1.5,
    },
    DEFAULT_ROLE_WEIGHT = 1.0,
    COMPOSITION_BONUS = 3.0,

    -- GearScore: GS_DIVISOR más bajo = el equipo pesa más
    GS_DIVISOR = 35,

    -- Poder del Capitan: GS del jugador (no va a la mision, pero lidera)
    -- bonus = (GS_jugador / GS_DIVISOR) * CAPTAIN_POWER_MULT
    CAPTAIN_POWER_MULT = 0.75,

    -- GS mínimo "aceptable" ≈ level * MIN_GS_PER_LEVEL
    -- ~5 verdes de nivel adecuado ≈ level*15–20 en muchos servidores
    MIN_GS_PER_LEVEL = 15,

    -- Por debajo del mínimo: el bonus de equipo se reduce mucho
    UNDERGEARED_GEAR_MULT = 0.25,

    -- Tope de éxito si el grupo está undergeared (media bajo el mínimo)
    UNDERGEARED_MAX_SUCCESS = 0.40,

    -- Oro: goldMin/Max del QUEST se multiplican por nivel del jugador
    -- final ≈ random(min,max) * level * GOLD_LEVEL_MULT  (en cobre)
    GOLD_LEVEL_MULT = 0,  -- 0 = oro absoluto (valores del BotQuest original ya escalan por tramo)

    -- XP (solo en éxito). Los bots reciben más que el jugador.
    XP_BOT_BASE = { EASY = 60, NORMAL = 120, HARD = 200, ELITE = 350 },
    XP_PLAYER_RATIO = 0.25,  -- el master recibe 25% de la XP de un bot
    XP_TO_PLAYER = true,
    XP_TO_BOTS = true,

    -- Destacamento: solo altbots (el jugador no va a la misión)
    MIN_BOTS = 1,
    MAX_MISSION_BOTS = 4,  -- máx. bots por misión (grupo 5 = 1 jugador + 4 bots)

    -- Tras completar una mision, no vuelve a salir en la lista durante X segundos
    MISSION_LIST_CD = 900,  -- 15 min

    -- Cuantas misiones mostrar por dificultad (rotacion aleatoria del pool disponible)
    LIST_SLOTS = { EASY = 2, NORMAL = 3, HARD = 1, ELITE = 1 },

    -- Sonidos al completar (se prueba el primero que exista en el cliente)
    -- 13363 cuerno generico; 8472/7211 alternativas; ajusta si no se oye
    COMPLETE_SOUND_IDS = { 13363, 8472, 7211 },

    -- Modo de envío a misión:
    -- "park"   = teleporta lejos y devuelve al acabar (RECOMENDADO, automático)
    -- "logout" = logout/login (en tu core el login automático fallaba)
    -- "none"   = solo simulación
    BOT_MISSION_MODE = "park",

    PARK_MAP = 13,
    PARK_X   = 0,
    PARK_Y   = 0,
    PARK_Z   = 0,
    PARK_O   = 0,

    LOGOUT_DELAY_MS = 500,
    LOGIN_DELAY_MS  = 1000,
    PARK_DELAY_MS   = 300,

    -- Bloquear summon/follow de bots en mision
    BLOCK_SUMMON_WHILE_MISSION = true,
    -- Si el jugador igual los trae, re-aparcar cada X ms
    MISSION_BOT_WATCHDOG_MS = 5000,
    -- Si el bot esta a menos de estas yardas del master, se re-aparca
    SUMMON_NEAR_YARDS = 80,
}

-- Misiones portadas desde BotQuest_Data.lua (original)
-- oro ABSOLUTO (ya escalado por tramo de nivel en el original)
local QUESTS = {
    {
        id=1, name="Patrulla de la Aldea", difficulty="EASY",
        minLevel=1, maxLevel=10, duration=300,
        goldMin=50, goldMax=200,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los aldeanos necesitan protección. Envía tus bots a vigilar el perímetro durante la noche.",
    },
    {
        id=2, name="Caza Menor", difficulty="EASY",
        minLevel=1, maxLevel=10, duration=300,
        goldMin=80, goldMax=250,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Las bestias del bosque se acercan demasiado. Despeja la zona.",
    },
    {
        id=3, name="Suministros Perdidos", difficulty="EASY",
        minLevel=3, maxLevel=10, duration=300,
        goldMin=60, goldMax=220,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Un carro de carga fue asaltado cerca. Recupera las cajas antes que los carroñeros.",
    },
    {
        id=4, name="Plaga de Jabalíes", difficulty="EASY",
        minLevel=2, maxLevel=10, duration=300,
        goldMin=70, goldMax=240,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los jabalíes están destrozando los cultivos locales. Reduce su número.",
    },
    {
        id=5, name="Escaramuza de Práctica", difficulty="NORMAL",
        minLevel=5, maxLevel=10, duration=600,
        goldMin=100, goldMax=300,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        isPvP=true, honorPoints=50,
        desc="Entrena a tus bots en un entorno controlado de combate contra la facción contraria.",
    },
    {
        id=6, name="Amenaza Centauro", difficulty="NORMAL",
        minLevel=6, maxLevel=10, duration=600,
        goldMin=120, goldMax=350,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Exploradores reportan movimientos hostiles en las fronteras. Dispersa sus campamentos.",
    },
    {
        id=7, name="Limpieza de las Minas", difficulty="NORMAL",
        minLevel=7, maxLevel=10, duration=600,
        goldMin=150, goldMax=400,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los kóbolds o troggs han tomado los túneles inferiores. Despéjalos para los mineros.",
    },
    {
        id=8, name="El Desafío del Recluta", difficulty="HARD",
        minLevel=8, maxLevel=10, duration=1200,
        goldMin=200, goldMax=500,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=80,
        desc="Muestra el temple de tu equipo desafiando a los campeones locales en un duelo de honor.",
    },
    {
        id=9, name="Escolta del Mercader", difficulty="NORMAL",
        minLevel=11, maxLevel=20, duration=600,
        goldMin=300, goldMax=800,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Un mercader necesita llegar sano y salvo a la ciudad. Que tus bots lo acompañen.",
    },
    {
        id=10, name="Expurgar la Cueva", difficulty="NORMAL",
        minLevel=15, maxLevel=20, duration=600,
        goldMin=500, goldMax=1200,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Una cueva cercana está infestada de muertos vivientes. Limpia el nido.",
    },
    {
        id=11, name="Frente en Grito de Guerra", difficulty="HARD",
        minLevel=11, maxLevel=20, duration=1200,
        goldMin=600, goldMax=1500,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="La batalla por los recursos forestales ha comenzado. Captura la bandera enemiga.",
    },
    {
        id=12, name="Bandidos de los Caminos", difficulty="EASY",
        minLevel=12, maxLevel=20, duration=300,
        goldMin=400, goldMax=900,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Una banda de forajidos está cobrando peajes ilegales en las rutas principales. Elimínalos.",
    },
    {
        id=13, name="Sabotaje Almanegra", difficulty="NORMAL",
        minLevel=14, maxLevel=20, duration=600,
        goldMin=550, goldMax=1300,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Infíltrate en los muelles de los piratas y quema sus planos de navegación.",
    },
    {
        id=14, name="Fauna Corrupta", difficulty="EASY",
        minLevel=13, maxLevel=20, duration=300,
        goldMin=450, goldMax=1000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Animales salvajes afectados por magia residual atacan a los viajeros. Ponles fin.",
    },
    {
        id=15, name="Defensa de la Encrucijada", difficulty="HARD",
        minLevel=16, maxLevel=20, duration=1200,
        goldMin=700, goldMax=1600,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Repele las oleadas de atacantes que intentan asediar nuestro puesto de avanzada.",
    },
    {
        id=16, name="Disputa de Suministros JcJ", difficulty="HARD",
        minLevel=18, maxLevel=20, duration=1200,
        goldMin=800, goldMax=1800,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=200,
        desc="Intercepta un cargamento de suministros que la facción rival intenta reclamar.",
    },
    {
        id=17, name="[ÉLITE] La Mina Infestada de Garras", difficulty="ELITE",
        minLevel=15, maxLevel=20, duration=900,
        goldMin=8000, goldMax=18000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Una antigua mina al norte ha sido tomada por arañas carroñeras y sus reinas. Los colonos no se atreven a acercarse. Infiltra un equipo y extermina a la matriarca antes de que la infestación se extienda.",
    },
    {
        id=18, name="[ÉLITE] Patrulla de los Muertos Errantes", difficulty="ELITE",
        minLevel=15, maxLevel=20, duration=1200,
        goldMin=10000, goldMax=22000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Desde el cementerio olvidado al este del poblado emergen no-muertos cada noche atacando las granjas cercanas. Elimina al nigromante que los levanta antes del próximo amanecer.",
    },
    {
        id=19, name="Ruinas Antiguas", difficulty="NORMAL",
        minLevel=21, maxLevel=30, duration=600,
        goldMin=1000, goldMax=2500,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Explora las ruinas y recupera los artefactos antes de que caigan en malas manos.",
    },
    {
        id=20, name="Incursión al Campamento", difficulty="HARD",
        minLevel=25, maxLevel=30, duration=1200,
        goldMin=2000, goldMax=4000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Un campamento enemigo amenaza la región. Asalto rápido y retirada.",
    },
    {
        id=21, name="Batalla por la Cuenca", difficulty="HARD",
        minLevel=21, maxLevel=30, duration=1200,
        goldMin=2200, goldMax=4500,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=300,
        desc="Envía tus bots a capturar y defender las cinco bases clave de recursos.",
    },
    {
        id=22, name="Golems Descontrolados", difficulty="NORMAL",
        minLevel=22, maxLevel=30, duration=600,
        goldMin=1200, goldMax=2800,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Golems de piedra antiguos han despertado y destruyen los caminos arqueológicos.",
    },
    {
        id=23, name="Conflictos Territoriales", difficulty="NORMAL",
        minLevel=24, maxLevel=30, duration=600,
        goldMin=1500, goldMax=3200,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Las tensiones en las zonas en disputa aumentan. Da caza a los soldados de la otra facción.",
    },
    {
        id=24, name="La Tribu Grimpato", difficulty="NORMAL",
        minLevel=26, maxLevel=30, duration=600,
        goldMin=1800, goldMax=3800,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los harrier y geománticos de esta tribu hostil están organizando una emboscada masiva.",
    },
    {
        id=25, name="El Secreto de la Arboleda", difficulty="EASY",
        minLevel=27, maxLevel=30, duration=300,
        goldMin=1100, goldMax=2600,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Ayuda a los investigadores a purificar un pozo lunar infectado de siles.",
    },
    {
        id=26, name="Objetivo: El Comandante", difficulty="ELITE",
        minLevel=29, maxLevel=30, duration=2400,
        goldMin=3000, goldMax=6000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        isPvP=true, honorPoints=0,
        desc="Asalta el búnker fortificado de la facción rival y descabeza su línea de mando regional.",
    },
    {
        id=27, name="[ÉLITE] El Señor del Pantano", difficulty="ELITE",
        minLevel=22, maxLevel=28, duration=1200,
        goldMin=18000, goldMax=35000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Una criatura colosal domina los pantanos del sur hundiendo las barcazas de suministros. Los mercaderes ofrecen una recompensa generosa por su cabeza. El terreno dificulta el combate.",
    },
    {
        id=28, name="[ÉLITE] Cámara Sellada de Gnomeregan", difficulty="ELITE",
        minLevel=22, maxLevel=28, duration=1500,
        goldMin=22000, goldMax=45000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un sector irradiado de Gnomeregan esconde tecnología prototipo de alto valor. El lépero jefe que guarda la cámara es enormemente resistente. Se requiere coordinación táctica y equipo anti-radiación.",
    },
    {
        id=29, name="Convoy Real", difficulty="HARD",
        minLevel=31, maxLevel=40, duration=1200,
        goldMin=4000, goldMax=8000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Protege el convoy real a través de territorio peligroso.",
    },
    {
        id=30, name="Fortaleza Gnoll", difficulty="HARD",
        minLevel=35, maxLevel=40, duration=1200,
        goldMin=5000, goldMax=10000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Los gnolls han levantado una fortaleza. Derriba sus defensas.",
    },
    {
        id=31, name="Cacería en Vega de Tuercespina", difficulty="HARD",
        minLevel=32, maxLevel=40, duration=1200,
        goldMin=4500, goldMax=9000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Embosca a los jugadores y bots de la otra facción en el mapa de mundo abierto más sangriento.",
    },
    {
        id=32, name="Corsarios de Tanaris", difficulty="NORMAL",
        minLevel=33, maxLevel=40, duration=600,
        goldMin=4200, goldMax=8500,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Asalta los navíos piratas que atracaron en las costas del desierto.",
    },
    {
        id=33, name="Infiltración Escarlata", difficulty="HARD",
        minLevel=36, maxLevel=40, duration=1200,
        goldMin=5200, goldMax=11000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Envía a tus bots a robar los manuscritos secretos guardados celosamente en el monasterio.",
    },
    {
        id=34, name="Guerra de Clanes (Grito de Guerra)", difficulty="HARD",
        minLevel=38, maxLevel=40, duration=1200,
        goldMin=5500, goldMax=12000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="La contienda en el cañón se intensifica. Consigue una victoria aplastante.",
    },
    {
        id=35, name="Calamidad Elemental", difficulty="NORMAL",
        minLevel=34, maxLevel=40, duration=600,
        goldMin=4300, goldMax=8800,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Cierra las brechas mágicas que están liberando elementales furiosos en la meseta.",
    },
    {
        id=36, name="El Ídolo de Piedra", difficulty="ELITE",
        minLevel=39, maxLevel=40, duration=2400,
        goldMin=6000, goldMax=13000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Recupera una enorme reliquia antes de que los trols locales terminen su ritual de sacrificio.",
    },
    {
        id=37, name="[ÉLITE] Fortaleza Mor'shan: Contraataque", difficulty="ELITE",
        minLevel=31, maxLevel=37, duration=1800,
        goldMin=35000, goldMax=65000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un clan de trolls de Zul'Farrak ha enviado una vanguardia para asaltar la Fortaleza Mor'shan. Los refuerzos tardarán demasiado. Tu escuadrón debe contener la oleada y eliminar al jefe de guerra troll.",
    },
    {
        id=38, name="[ÉLITE] La Sombra de los Serenos Solares", difficulty="ELITE",
        minLevel=31, maxLevel=37, duration=2100,
        goldMin=40000, goldMax=75000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Espías de los Serenos Solares han robado artefactos de luz sagrada de un templo de la Alianza. Infiltra su campamento en Desolace, recupera los artefactos y neutraliza al agente infiltrado antes de que huya.",
    },
    {
        id=39, name="Las Minas Profundas", difficulty="HARD",
        minLevel=41, maxLevel=50, duration=1200,
        goldMin=10000, goldMax=20000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Criaturas desconocidas emergen de las minas. Investiga y elimina la amenaza.",
    },
    {
        id=40, name="Retomar el Puesto", difficulty="ELITE",
        minLevel=45, maxLevel=50, duration=2400,
        goldMin=15000, goldMax=30000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un puesto avanzado fue tomado por el enemigo. Recupéralo a cualquier precio.",
    },
    {
        id=41, name="Conflicto por las Tierras Altas", difficulty="HARD",
        minLevel=41, maxLevel=50, duration=1200,
        goldMin=11000, goldMax=22000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=8,
        desc="Establece control absoluto sobre el aserradero y la mina en la Cuenca de Arathi.",
    },
    {
        id=42, name="Venganza en Gadgetzan", difficulty="NORMAL",
        minLevel=43, maxLevel=50, duration=600,
        goldMin=10500, goldMax=21000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Caza a los renegados enemigos que merodean los límites de la ciudad neutral.",
    },
    {
        id=43, name="Alrededores de Sandfury", difficulty="NORMAL",
        minLevel=44, maxLevel=50, duration=600,
        goldMin=12000, goldMax=24000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los trols de las arenas preparan un ataque masivo. Sabotea sus fuentes de agua.",
    },
    {
        id=44, name="Corrupción en Felwood", difficulty="NORMAL",
        minLevel=46, maxLevel=50, duration=600,
        goldMin=13000, goldMax=26000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Saca la esencia corrupta de los satiros que deambulan los bosques marchitos.",
    },
    {
        id=45, name="Golems de Hinterlands", difficulty="EASY",
        minLevel=42, maxLevel=50, duration=300,
        goldMin=9500, goldMax=19000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Destruye los constructos rúnicos que los enanos u orcos salvajes han dejado sin control.",
    },
    {
        id=46, name="El Nido de las Harpías", difficulty="ELITE",
        minLevel=48, maxLevel=50, duration=2400,
        goldMin=17000, goldMax=35000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Sube a los riscos más altos de Feralas y elimina a la matriarca de las harpías.",
    },
    {
        id=47, name="[ÉLITE] Las Catacumbas de Marrón Carmesí", difficulty="ELITE",
        minLevel=40, maxLevel=45, duration=2400,
        goldMin=65000, goldMax=120000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Bajo las ruinas de Maraudon yace una cámara sellada con una entidad corrupta de la naturaleza. El grupo deberá atravesar varias oleadas de guardianes elementales antes de enfrentarla. La corrupción afecta el entorno.",
    },
    {
        id=48, name="[ÉLITE] Escolta del Convoy Real", difficulty="ELITE",
        minLevel=40, maxLevel=45, duration=2700,
        goldMin=70000, goldMax=130000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un convoy con suministros críticos para el frente de guerra debe atravesar las Tierras Inhóspitas, un corredor infestado por gnolls de élite y bandidos mercenarios. Protégelo hasta el destino sin bajas.",
    },
    {
        id=49, name="[ÉLITE] El Heraldo de la Llama Negra", difficulty="ELITE",
        minLevel=45, maxLevel=52, duration=2700,
        goldMin=90000, goldMax=175000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un heraldo de Ragnaros ha sido avistado en las Tierras de Fuego exteriores coordinando ataques contra asentamientos enanos. Intercepta su ritual antes de que convoque refuerzos desde el Núcleo de Magma.",
    },
    {
        id=50, name="[ÉLITE] Prisión de los Vientos: Fuga", difficulty="ELITE",
        minLevel=45, maxLevel=52, duration=3000,
        goldMin=100000, goldMax=190000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un peligroso arúspice de los Vientos del Norte ha escapado de su celda en Alterac. Su rastro de magia elemental devastadora debe cortarse antes de que alcance a sus cómplices en las montañas.",
    },
    {
        id=51, name="La Plaga del Pantano", difficulty="ELITE",
        minLevel=51, maxLevel=60, duration=2400,
        goldMin=30000, goldMax=60000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Algo corrompe las aguas del pantano. Busca el origen y destrúyelo.",
    },
    {
        id=52, name="El Guardián Antiguo", difficulty="ELITE",
        minLevel=58, maxLevel=60, duration=2400,
        goldMin=50000, goldMax=100000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un ser ancestral ha despertado y siembra el caos. Solo los más valientes se atreven.",
    },
    {
        id=53, name="Guerra Total en Alterac", difficulty="ELITE",
        minLevel=51, maxLevel=60, duration=2400,
        goldMin=45000, goldMax=95000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        isPvP=true, honorPoints=0,
        desc="La batalla definitiva. Destruye los búnkeres, invoca al elemental y ejecuta al general enemigo.",
    },
    {
        id=54, name="Las Colmenas Silítidas", difficulty="HARD",
        minLevel=54, maxLevel=60, duration=1200,
        goldMin=35000, goldMax=70000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Infíltrate en los insectarios de Silithus y acaba con los bichos excavadores.",
    },
    {
        id=55, name="Torres de las Tierras de la Peste", difficulty="HARD",
        minLevel=55, maxLevel=60, duration=1200,
        goldMin=38000, goldMax=80000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Captura las torres de vigilancia para debilitar la presencia de la facción contraria en la zona.",
    },
    {
        id=56, name="Espías en la Roca Negra", difficulty="NORMAL",
        minLevel=52, maxLevel=60, duration=600,
        goldMin=32000, goldMax=65000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Vigila la entrada de la Montaña Roca Negra y liquida a las patrullas orcas del clan competidor.",
    },
    {
        id=57, name="Invasión en Tierras de la Peste", difficulty="HARD",
        minLevel=56, maxLevel=60, duration=1200,
        goldMin=40000, goldMax=85000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Combate directo contra las fuerzas de élite enemigas en las ruinas de Stratholme exterior.",
    },
    {
        id=58, name="Gigantes de Cuna de Invierno", difficulty="NORMAL",
        minLevel=57, maxLevel=60, duration=600,
        goldMin=36000, goldMax=75000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Elimina a los gigantes de hielo que congelan las rutas de comercio neutrales.",
    },
    {
        id=59, name="Patrulla en Terrallende", difficulty="HARD",
        minLevel=61, maxLevel=70, duration=1200,
        goldMin=60000, goldMax=120000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Los demonios no descansan. Mantén el perímetro del portal bajo control.",
    },
    {
        id=60, name="La Torre del Mago Negro", difficulty="ELITE",
        minLevel=65, maxLevel=70, duration=2400,
        goldMin=100000, goldMax=200000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un brujo ha tomado una torre estratégica. Asáltala y elimínalo.",
    },
    {
        id=61, name="Dominio en el Ojo de la Tormenta", difficulty="HARD",
        minLevel=61, maxLevel=70, duration=1200,
        goldMin=70000, goldMax=140000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Cruza los puentes flotantes de Tormenta Abisal. Mantén las torres y captura la runa central.",
    },
    {
        id=62, name="Fortificaciones de la Península", difficulty="NORMAL",
        minLevel=62, maxLevel=70, duration=600,
        goldMin=65000, goldMax=130000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Asalta los tres puntos de control clave en el mapa de la Península del Fuego Infernal.",
    },
    {
        id=63, name="Gigantes de la Marisma", difficulty="EASY",
        minLevel=63, maxLevel=70, duration=300,
        goldMin=55000, goldMax=110000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Consigue los fluidos vitales de los caminantes fúngicos gigantes de Marisma de Zangar.",
    },
    {
        id=64, name="Guerra de Bandas en Halaa", difficulty="HARD",
        minLevel=66, maxLevel=70, duration=1200,
        goldMin=85000, goldMax=170000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=2200,
        desc="Combate a campo abierto para reclamar el control de la ciudad fortificada de Halaa.",
    },
    {
        id=65, name="Los Cielos de Skettis", difficulty="NORMAL",
        minLevel=68, maxLevel=70, duration=600,
        goldMin=80000, goldMax=160000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Derriba a los jinetes de kaliri y destruye los huevos de los hombres pájaro.",
    },
    {
        id=66, name="Frente de la Isla de Quel'Danas", difficulty="ELITE",
        minLevel=70, maxLevel=70, duration=2400,
        goldMin=120000, goldMax=250000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Cumple misiones de sabotaje contra las fuerzas de Kael'thas en los muelles.",
    },
    {
        id=67, name="Vanguardia en Rasganorte", difficulty="HARD",
        minLevel=71, maxLevel=80, duration=1200,
        goldMin=150000, goldMax=300000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="La Plaga avanza. Detén la oleada antes de que llegue al campamento base.",
    },
    {
        id=68, name="La Cripta Helada", difficulty="ELITE",
        minLevel=75, maxLevel=80, duration=2400,
        goldMin=250000, goldMax=500000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Los no-muertos se agitan en la cripta. Séllala antes del amanecer.",
    },
    {
        id=69, name="Conquista del Invierno", difficulty="ELITE",
        minLevel=78, maxLevel=80, duration=2400,
        goldMin=400000, goldMax=850000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        isPvP=true, honorPoints=0,
        desc="¡La fortaleza está bajo asedio! Conduce vehículos de guerra y destruye los muros enemigos.",
    },
    {
        id=70, name="Playa de los Ancestros", difficulty="HARD",
        minLevel=71, maxLevel=80, duration=1200,
        goldMin=200000, goldMax=450000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=2500,
        desc="Asalta las playas usando las reliquias de titán y los demoledores de asedio.",
    },
    {
        id=71, name="La Sombra de Naxxramas", difficulty="NORMAL",
        minLevel=73, maxLevel=80, duration=600,
        goldMin=180000, goldMax=380000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Destruye a las gárgolas de plaga que custodian el cielo de Cementerio de Dragones.",
    },
    {
        id=72, name="Suministros Kalu'ak", difficulty="EASY",
        minLevel=72, maxLevel=80, duration=300,
        goldMin=160000, goldMax=320000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Ayuda a los mofletones pescadores defendiendo sus trampas contra los feroces piratas marinos.",
    },
    {
        id=73, name="Los Hijos de Hodir", difficulty="HARD",
        minLevel=77, maxLevel=80, duration=1200,
        goldMin=300000, goldMax=600000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Derrota a los gigantes de escarcha rebeldes para ganarte el respeto de los señores del trueno.",
    },
    {
        id=74, name="Limpieza en las Islas del Eco", difficulty="EASY",
        minLevel=1, maxLevel=10, duration=300,
        goldMin=50, goldMax=210,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los tigres y ratiyas locales están descontrolados. Ayuda a asegurar la zona de inicio.",
    },
    {
        id=75, name="Plaga en los Viñedos", difficulty="EASY",
        minLevel=2, maxLevel=10, duration=300,
        goldMin=60, goldMax=230,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Las arañas han anidado cerca de las tierras de cultivo del sur. Quema sus sacos de huevos.",
    },
    {
        id=76, name="Cardos para los Alquimistas", difficulty="EASY",
        minLevel=3, maxLevel=10, duration=300,
        goldMin=55, goldMax=225,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los botánicos locales necesitan muestras de plantas que crecen cerca de los nidos de los kóbolds.",
    },
    {
        id=77, name="Invasión de Troggs", difficulty="NORMAL",
        minLevel=4, maxLevel=10, duration=600,
        goldMin=110, goldMax=310,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los troggs han salido de sus cuevas e interrumpen las operaciones de excavación de los enanos.",
    },
    {
        id=78, name="Los Clanes Gnoll", difficulty="NORMAL",
        minLevel=5, maxLevel=10, duration=600,
        goldMin=115, goldMax=320,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los gnolls Garrapata se están agrupando. Elimina a sus exploradores antes de que organicen un ataque.",
    },
    {
        id=79, name="Vigilancia en el Camino Real", difficulty="NORMAL",
        minLevel=5, maxLevel=10, duration=600,
        goldMin=130, goldMax=340,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Protege las caravanas de suministros de los asaltantes nocturnos que se esconden en los arbustos.",
    },
    {
        id=80, name="La Reliquia Perdida", difficulty="NORMAL",
        minLevel=6, maxLevel=10, duration=600,
        goldMin=140, goldMax=360,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Recupera un antiguo tomo de magia que fue robado de la abadía/academia local por cultistas.",
    },
    {
        id=81, name="Escaramuza en la Frontera", difficulty="HARD",
        minLevel=7, maxLevel=10, duration=1200,
        goldMin=180, goldMax=450,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Fuerzas de exploración enemigas merodean las zonas de inicio. Repele la intrusión de la otra facción.",
    },
    {
        id=82, name="Garras de la Costa", difficulty="HARD",
        minLevel=8, maxLevel=10, duration=1200,
        goldMin=190, goldMax=480,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Un enorme crustáceo mutado está aterrorizando a los pescadores en las playas. Elimínalo.",
    },
    {
        id=83, name="El Rey de los Murlocs", difficulty="ELITE",
        minLevel=9, maxLevel=10, duration=2400,
        goldMin=250, goldMax=600,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Organiza una incursión al campamento murloc principal de la costa y acaba con su chamán líder.",
    },
    {
        id=84, name="Cosechadores de la Muerte", difficulty="EASY",
        minLevel=11, maxLevel=20, duration=300,
        goldMin=420, goldMax=850,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los golems mecánicos de las cosechas se han vuelto locos. Desmárcalos antes de que destrocen el trigo.",
    },
    {
        id=85, name="Los Oasis Ocultos", difficulty="EASY",
        minLevel=12, maxLevel=20, duration=300,
        goldMin=440, goldMax=880,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Recoge muestras de agua de los oasis de Los Barrenos para investigar la flora mutada.",
    },
    {
        id=86, name="Sabotaje en la Fundición", difficulty="NORMAL",
        minLevel=13, maxLevel=20, duration=600,
        goldMin=500, goldMax=1100,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="La Compañía Ventura está talando árboles ilegalmente. Roba las piezas de sus trituradoras.",
    },
    {
        id=87, name="Cacería en la Costa de Darkshore", difficulty="NORMAL",
        minLevel=14, maxLevel=20, duration=600,
        goldMin=520, goldMax=1150,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los murlocs de las playas del norte tienen artefactos antiguos robados de los elfos. Recupéralos.",
    },
    {
        id=88, name="Garras de los Riscos", difficulty="NORMAL",
        minLevel=15, maxLevel=20, duration=600,
        goldMin=540, goldMax=1250,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Las arpías del cañón están atacando a los jinetes de viento. Limpia sus nidos en las alturas.",
    },
    {
        id=89, name="Los Guardias Defias", difficulty="NORMAL",
        minLevel=16, maxLevel=20, duration=600,
        goldMin=580, goldMax=1300,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Elimina las patrullas que vigilan las entradas ocultas de los túneles de los bandidos.",
    },
    {
        id=90, name="Frente Forestal JcJ", difficulty="HARD",
        minLevel=17, maxLevel=20, duration=1200,
        goldMin=750, goldMax=1650,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="Ashenvale arde. Asalta el puesto de control de la facción contraria en el bosque profundo.",
    },
    {
        id=91, name="Maldición de los Hombres Lobo", difficulty="HARD",
        minLevel=18, maxLevel=20, duration=1200,
        goldMin=780, goldMax=1700,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Los huargen del Castillo de Colmillo Oscuro se extienden por los bosques de Argénteos. Cázalos.",
    },
    {
        id=92, name="Los Fósiles de Bael Modan", difficulty="HARD",
        minLevel=19, maxLevel=20, duration=1200,
        goldMin=820, goldMax=1750,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Recupera reliquias rúnicas excavadas por enanos antes de que destruyan el Lore local.",
    },
    {
        id=93, name="El Capataz de la Fundición", difficulty="ELITE",
        minLevel=20, maxLevel=20, duration=2400,
        goldMin=1000, goldMax=2200,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Infíltrate en el centro logístico criminal y ejecuta al ingeniero jefe de los bandidos.",
    },
    {
        id=94, name="Las Sombras de Raven Hill", difficulty="EASY",
        minLevel=21, maxLevel=30, duration=300,
        goldMin=1050, goldMax=2200,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los esqueletos caminan por el cementerio de Duskwood. Pon fin a su tormento eterno.",
    },
    {
        id=95, name="Raíces de los Humedales", difficulty="EASY",
        minLevel=22, maxLevel=30, duration=300,
        goldMin=1100, goldMax=2300,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Consigue tubérculos pantanosos raros custodiados por los feroces crocoliscos.",
    },
    {
        id=96, name="Disputa en Trabalomas JcJ", difficulty="HARD",
        minLevel=23, maxLevel=30, duration=1200,
        goldMin=1600, goldMax=3400,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="La histórica rivalidad entre Costasur y Molino de Tarren revive. Ejecuta campeones enemigos.",
    },
    {
        id=97, name="Las Ruinas de Zul'Kunda", difficulty="NORMAL",
        minLevel=24, maxLevel=30, duration=600,
        goldMin=1300, goldMax=2900,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los trols Singapur están reuniendo pociones de vudú. Sabotea sus calderos.",
    },
    {
        id=98, name="El Asedio de Dun Modr", difficulty="NORMAL",
        minLevel=25, maxLevel=30, duration=600,
        goldMin=1400, goldMax=3100,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los enanos Hierro Negro han sitiado el puente del norte. Limpia las barricadas.",
    },
    {
        id=99, name="La Amenaza de Crestagrana", difficulty="NORMAL",
        minLevel=26, maxLevel=30, duration=600,
        goldMin=1500, goldMax=3300,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los orcos del clan Roca Negra han tomado las fortalezas del este. Reduce sus filas.",
    },
    {
        id=100, name="Guerra de Clanes en Desolace", difficulty="NORMAL",
        minLevel=27, maxLevel=30, duration=600,
        goldMin=1650, goldMax=3600,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Elige un bando implícitamente atacando las líneas de suministros de los centauros Kolkar.",
    },
    {
        id=101, name="Calamidad en las Salinas", difficulty="HARD",
        minLevel=28, maxLevel=30, duration=1200,
        goldMin=2100, goldMax=4200,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Elementales de tierra y aire bloquean las pistas de carreras de los gnomos. Despéchalos.",
    },
    {
        id=102, name="Fragmentos de Almas", difficulty="HARD",
        minLevel=29, maxLevel=30, duration=1200,
        goldMin=2300, goldMax=4500,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Los nigromantes están extrayendo almas en cementerios locales. Recupera las gemas rúnicas.",
    },
    {
        id=103, name="El Comandante de Crestagrana", difficulty="ELITE",
        minLevel=30, maxLevel=30, duration=2400,
        goldMin=3200, goldMax=6500,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Entra en la torre fortificada de Alther y elimina al capataz ogro que lidera las fuerzas de asedio.",
    },
    {
        id=104, name="Carreras en Las Mil Agujas", difficulty="EASY",
        minLevel=31, maxLevel=40, duration=300,
        goldMin=3800, goldMax=7500,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los ingenieros goblins necesitan piezas metálicas raras esparcidas por las Salinas.",
    },
    {
        id=105, name="Maestría en Caza: Panteras", difficulty="EASY",
        minLevel=32, maxLevel=40, duration=300,
        goldMin=4000, goldMax=7800,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Las selvas de Tuercespina son mortales. Caza a las panteras sombrías imperceptibles.",
    },
    {
        id=106, name="Los Corsarios de la Vela Roja", difficulty="NORMAL",
        minLevel=33, maxLevel=40, duration=600,
        goldMin=4400, goldMax=8900,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los piratas amenazan el comercio de Bahía del Botín. Hunde sus barcos quemando sus velas.",
    },
    {
        id=107, name="El Vuelo Verde en el Pantano", difficulty="NORMAL",
        minLevel=34, maxLevel=40, duration=600,
        goldMin=4600, goldMax=9200,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Dragonantes jóvenes se han vuelto agresivos cerca del Templo de Atal'Hakkar. Cázalos.",
    },
    {
        id=108, name="Los Ogros de Alterac", difficulty="NORMAL",
        minLevel=35, maxLevel=40, duration=600,
        goldMin=4800, goldMax=9600,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Las ruinas heladas de Alterac están repletas de ogros corpulentos. Limpia las fortificaciones.",
    },
    {
        id=109, name="La Locura de Kurzen", difficulty="NORMAL",
        minLevel=36, maxLevel=40, duration=600,
        goldMin=5000, goldMax=10000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los soldados renegados de Kurzen se esconden en la jungla. Elimina a sus oficiales médicos.",
    },
    {
        id=110, name="Control de Canteras JcJ", difficulty="HARD",
        minLevel=37, maxLevel=40, duration=1200,
        goldMin=5600, goldMax=11500,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="La facción rival está extrayendo hierro sagrado en Arathi. Asalta las canteras y elimina jugadores.",
    },
    {
        id=111, name="La Tribu Witherbark", difficulty="HARD",
        minLevel=38, maxLevel=40, duration=1200,
        goldMin=5800, goldMax=12000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Los trols de las Tierras Altas de Arathi traman un asalto a los refugios. Detenlos.",
    },
    {
        id=112, name="Invocaciones de Maraudon", difficulty="HARD",
        minLevel=39, maxLevel=40, duration=1200,
        goldMin=6000, goldMax=12500,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Criaturas de tierra corruptas emergen de los valles de Desolace. Destruye sus núcleos.",
    },
    {
        id=113, name="El Gran Gorila de la Isla", difficulty="ELITE",
        minLevel=40, maxLevel=40, duration=2400,
        goldMin=7500, goldMax=15000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Encuentra al gorila alfa albino gigante en las islas del sur de Tuercespina y tráeme su pellejo.",
    },
    {
        id=114, name="Los Clamores de la Arena", difficulty="EASY",
        minLevel=41, maxLevel=50, duration=300,
        goldMin=9000, goldMax=18000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los trols Sandfury vigilan ruinas llenas de escarabajos rúnicos. Recolecta sus caparazones.",
    },
    {
        id=115, name="Los Maleantes de las Dunas", difficulty="EASY",
        minLevel=42, maxLevel=50, duration=300,
        goldMin=9500, goldMax=19000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los piratas de parajes baldíos han robado los suministros de agua de Gadgetzan. Recupéralos.",
    },
    {
        id=116, name="Las Puertas de Hierro JcJ", difficulty="NORMAL",
        minLevel=43, maxLevel=50, duration=600,
        goldMin=11000, goldMax=22000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Controla los pasos de montaña clave hacia la Garganta de Fuego exterminando batallones enemigos.",
    },
    {
        id=117, name="La Fundición de Searing Gorge", difficulty="NORMAL",
        minLevel=44, maxLevel=50, duration=600,
        goldMin=11500, goldMax=23000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los enanos Hierro Negro forjan armas oscuras. Sabotea sus fuelles industriales.",
    },
    {
        id=118, name="Los Buhomutantes Salvajes", difficulty="NORMAL",
        minLevel=45, maxLevel=50, duration=600,
        goldMin=12000, goldMax=24000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Criaturas lunares salvajes de Hinterlands atacan sin razón. Purifica la zona cazándolos.",
    },
    {
        id=119, name="El Altar de Jintha'Alor", difficulty="HARD",
        minLevel=46, maxLevel=50, duration=1200,
        goldMin=14000, goldMax=28000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Sube a la cúspide de la ciudad trol élite de Hinterlands y destruye los fetiches de sacrificio.",
    },
    {
        id=120, name="Las Ruinas de Uldaman", difficulty="HARD",
        minLevel=47, maxLevel=50, duration=1200,
        goldMin=14500, goldMax=29000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Registra las afueras de la excavación enana y elimina los troggs mutados por energía titánica.",
    },
    {
        id=121, name="El Cráter de Un'Goro", difficulty="HARD",
        minLevel=48, maxLevel=50, duration=1200,
        goldMin=15000, goldMax=30000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Recoge cristales de energía puros custodiados por dinosaurios agresivos e hiladores de fuego.",
    },
    {
        id=122, name="Exploradores de Silithus", difficulty="HARD",
        minLevel=49, maxLevel=50, duration=1200,
        goldMin=16000, goldMax=32000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Los primeros insectos de las colmenas se asoman en los bordes del desierto. Elimínalos ya.",
    },
    {
        id=123, name="El Guardián del Altar de Alquitrán", difficulty="ELITE",
        minLevel=50, maxLevel=50, duration=2400,
        goldMin=20000, goldMax=40000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Destruye al elemental de lodo negro masivo que habita en los pozos de alquitrán de Un'Goro.",
    },
    {
        id=124, name="El Linaje de Azshara", difficulty="EASY",
        minLevel=51, maxLevel=60, duration=300,
        goldMin=28000, goldMax=55000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los dragonantes del Vuelo Azul custodian runas en los acantilados. Recupera sus escamas mágicas.",
    },
    {
        id=125, name="Las Almas de Stratholme", difficulty="EASY",
        minLevel=52, maxLevel=60, duration=300,
        goldMin=29000, goldMax=58000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Espíritus atormentados vagan por las calles exteriores de la ciudad destruida. Exorcízalos.",
    },
    {
        id=126, name="Los Acólitos de Caer Darrow", difficulty="NORMAL",
        minLevel=53, maxLevel=60, duration=600,
        goldMin=31000, goldMax=62000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Cultistas de la Plaga protegen la entrada del fuerte de la isla. Limpia el puente fortificado.",
    },
    {
        id=127, name="Las Sombras de Jaedenar", difficulty="NORMAL",
        minLevel=54, maxLevel=60, duration=600,
        goldMin=33000, goldMax=66000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="El Consejo de la Sombra opera en las cuevas oscuras de Felwood. Elimina a sus súcubos e invocadores.",
    },
    {
        id=128, name="Los Elfos Noche de Azshara", difficulty="NORMAL",
        minLevel=55, maxLevel=60, duration=600,
        goldMin=34000, goldMax=68000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Fantasmas altopatricios protegen reliquias sagradas en los templos inundados. Roba sus pergaminos.",
    },
    {
        id=129, name="Los Textos Crepusculares", difficulty="HARD",
        minLevel=56, maxLevel=60, duration=1200,
        goldMin=39000, goldMax=82000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Asalta los campamentos del Martillo Crepuscular en Silithus para recuperar sus códigos secretos.",
    },
    {
        id=130, name="Torres de Andorhal JcJ", difficulty="HARD",
        minLevel=57, maxLevel=60, duration=1200,
        goldMin=42000, goldMax=88000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Las facciones luchan por las ruinas centrales de Tierras de la Peste del Oeste. Captura el centro estratégico.",
    },
    {
        id=131, name="La Forja de la Montaña Roca Negra", difficulty="HARD",
        minLevel=58, maxLevel=60, duration=1200,
        goldMin=44000, goldMax=90000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Elementales ígneos colosales patrullan los pasajes interiores de la montaña. Destruye sus esencias.",
    },
    {
        id=132, name="Las Quimeras de Hielo", difficulty="HARD",
        minLevel=59, maxLevel=60, duration=1200,
        goldMin=46000, goldMax=95000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Caza a las quimeras ancestrales de Cuna de Invierno para obtener sus alas congeladas impecables.",
    },
    {
        id=133, name="El Azote del Ladero de Stratholme", difficulty="ELITE",
        minLevel=60, maxLevel=60, duration=2400,
        goldMin=60000, goldMax=120000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Entra en el bastión de la Plaga y descabeza al Jinete que coordina los envíos de grano infestado.",
    },
    {
        id=134, name="La Sangre de los Orcos Viles", difficulty="EASY",
        minLevel=61, maxLevel=70, duration=300,
        goldMin=52000, goldMax=105000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los orcos corruptos de la Ciudadela del Fuego Infernal atacan las rutas. Mitiga su número.",
    },
    {
        id=135, name="Sabotaje en la Bomba de Vapor", difficulty="EASY",
        minLevel=62, maxLevel=70, duration=300,
        goldMin=56000, goldMax=112000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los naga de la Reserva Colmillo Torcido drenan los lagos. Destruye sus generadores de vapor.",
    },
    {
        id=136, name="Los Jinetes de Terokkar", difficulty="NORMAL",
        minLevel=63, maxLevel=70, duration=600,
        goldMin=68000, goldMax=138000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los arakkoa de Skettis mandan espías kaliri a los bosques. Derriba a sus aves mensajeras.",
    },
    {
        id=137, name="Los Contrabandistas Etéreos", difficulty="NORMAL",
        minLevel=64, maxLevel=70, duration=600,
        goldMin=72000, goldMax=145000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los etéreos del Consorcio están robando fragmentos flotantes en Nagrand. Desmantela sus campamentos.",
    },
    {
        id=138, name="El Estandarte de Halaa JcJ", difficulty="HARD",
        minLevel=65, maxLevel=70, duration=1200,
        goldMin=88000, goldMax=175000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        isPvP=true, honorPoints=0,
        desc="La ciudad fortificada de Halaa está bajo disputa. Planta tu bandera eliminando defensores contrarios.",
    },
    {
        id=139, name="Los Ogros de Vanguardia", difficulty="NORMAL",
        minLevel=66, maxLevel=70, duration=600,
        goldMin=76000, goldMax=155000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los ogros de la montaña de Nagrand planean invadir los asentamientos de llanura. Elimina sus brutos.",
    },
    {
        id=140, name="El Trono de Elementos", difficulty="HARD",
        minLevel=67, maxLevel=70, duration=1200,
        goldMin=92000, goldMax=185000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Furia de fuego sacude el Valle Sombraluna. Mitiga las manifestaciones viles en las grietas de lava.",
    },
    {
        id=141, name="Las Bio-domos de Tormenta Abisal", difficulty="HARD",
        minLevel=68, maxLevel=70, duration=1200,
        goldMin=96000, goldMax=195000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Los tecnomagos goblins informan de sabotajes en los ecosistemas cerrados. Repara los domos rúnicos.",
    },
    {
        id=142, name="Las Forjas de la Legión", difficulty="HARD",
        minLevel=69, maxLevel=70, duration=1200,
        goldMin=105000, goldMax=210000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Infiltración en las bases de ingeniería de Illidan para destruir los Mecanostriders viles en producción.",
    },
    {
        id=143, name="El Comandante de la Furia del Sol", difficulty="ELITE",
        minLevel=70, maxLevel=70, duration=2400,
        goldMin=130000, goldMax=260000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="El lugarteniente de Kael'thas custodia los planos del pozo solar en Quel'Danas. Ejecútalo.",
    },
    {
        id=144, name="Los Vrykul de Utgarde", difficulty="EASY",
        minLevel=71, maxLevel=80, duration=300,
        goldMin=155000, goldMax=310000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="Los gigantes nórdicos de la costa asaltan los barcos de suministros. Detén sus drakkares.",
    },
    {
        id=145, name="Líneas Ley de Coldarra", difficulty="EASY",
        minLevel=72, maxLevel=80, duration=300,
        goldMin=165000, goldMax=330000,
        minBots=1, minTank=0, minHealer=0, minDps=0,
        desc="El Vuelo Azul altera los conductos mágicos del mundo. Estabiliza las fallas de energía.",
    },
    {
        id=146, name="Conflictos en Colinas Pardas", difficulty="NORMAL",
        minLevel=73, maxLevel=80, duration=600,
        goldMin=185000, goldMax=390000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Las escaramuzas entre tramperos locales y licántropos Fauces de Madera amenazan los campamentos.",
    },
    {
        id=147, name="La Plaga de Gundrak", difficulty="NORMAL",
        minLevel=74, maxLevel=80, duration=600,
        goldMin=195000, goldMax=410000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="Los trols Drakkari sacrifican a sus propios Dioses Salvajes debido a la desesperación. Intercepta los altares.",
    },
    {
        id=148, name="Talleres de Conquista JcJ", difficulty="HARD",
        minLevel=75, maxLevel=80, duration=1200,
        goldMin=260000, goldMax=520000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Captura las fábricas de vehículos del sur en los campos de batalla helados para asegurar el asedio.",
    },
    {
        id=149, name="Infiltración en la Cuenca de Sholazar", difficulty="NORMAL",
        minLevel=76, maxLevel=80, duration=600,
        goldMin=210000, goldMax=430000,
        minBots=2, minTank=0, minHealer=0, minDps=0,
        desc="El Culto de los Malditos sabotea los pilares de los Titanes que protegen el clima tropical de la cuenca.",
    },
    {
        id=150, name="Los Enanos Mecánicos de Thorim", difficulty="HARD",
        minLevel=77, maxLevel=80, duration=1200,
        goldMin=280000, goldMax=580000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Estructuras rúnicas creadas por Loken marchan por las cumbres níveas. Destruye sus circuitos.",
    },
    {
        id=151, name="El Frente del Veredicto", difficulty="HARD",
        minLevel=78, maxLevel=80, duration=1200,
        goldMin=320000, goldMax=640000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Establece cabezas de playa en los riscos de Corona de Hielo usando cañones de asedio de la Cruzada.",
    },
    {
        id=152, name="Nidos de Protodracos", difficulty="HARD",
        minLevel=79, maxLevel=80, duration=1200,
        goldMin=350000, goldMax=700000,
        minBots=3, minTank=1, minHealer=1, minDps=0,
        desc="Robar los huevos de los jinetes vrykul en los pináculos de la montaña para debilitar su fuerza aérea.",
    },
    {
        id=153, name="[ÉLITE] Las Puertas de la Plaga: Avalón Occidental", difficulty="ELITE",
        minLevel=53, maxLevel=60, duration=3300,
        goldMin=130000, goldMax=260000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="La Plaga avanza sin descanso por el Frente Occidental. Tu escuadrón debe contener una oleada de no-muertos mientras el último sacerdote sella el portal de invocación. Cada segundo cuenta. No hay retirada.",
    },
    {
        id=154, name="[ÉLITE] El Pacto Roto de Scholomance", difficulty="ELITE",
        minLevel=53, maxLevel=60, duration=3600,
        goldMin=140000, goldMax=280000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Un archimago renegado ha tomado el control de Scholomance rompiendo el pacto con la Kirin Tor. Sus experimentos amenazan con liberar una plaga mágica. Penetra sus defensas, destruye sus notas y elimínalo.",
    },
    {
        id=155, name="[ÉLITE] El Azote de Stratholme", difficulty="ELITE",
        minLevel=55, maxLevel=60, duration=1800,
        goldMin=150000, goldMax=300000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Envía a tus mejores hombres a limpiar los remanentes de la Plaga. La resistencia es feroz y requerirá una coordinación perfecta.",
    },
    {
        id=156, name="[ÉLITE] Núcleo de Magma: Incursión", difficulty="ELITE",
        minLevel=60, maxLevel=80, duration=3600,
        goldMin=500000, goldMax=1000000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Los señores de fuego amenazan con despertar. Solo un grupo con equipamiento excepcional saldrá con vida.",
    },
    {
        id=157, name="[DESAFÍO] Asalto a la Ciudadela", difficulty="ELITE",
        minLevel=80, maxLevel=80, duration=5400,
        goldMin=2000000, goldMax=5000000,
        minBots=4, minTank=1, minHealer=1, minDps=1,
        desc="Una misión suicida a las puertas del Trono helado. El escalado de poder requerido es absurdo.",
    },
}

local function FormatCopper(c)
    c = math.max(0, math.floor(c or 0))
    local g = math.floor(c / 10000)
    local s = math.floor((c % 10000) / 100)
    local b = c % 100
    local parts = {}
    if g > 0 then parts[#parts+1] = g .. " oro" end
    if s > 0 then parts[#parts+1] = s .. " plata" end
    if b > 0 or #parts == 0 then parts[#parts+1] = b .. " bronce" end
    return table.concat(parts, " ")
end

local function FormatTimeMMSS(secs)
    secs = math.max(0, math.floor(secs or 0))
    local m = math.floor(secs / 60)
    local s = secs % 60
    return string.format("%02d:%02d", m, s)
end

local REWARD_ITEM_FLAVOR = {
    EASY   = "un objeto |cffffffffComún|r o |cff1eff00Poco común|r",
    NORMAL = "un objeto |cff1eff00Poco común|r",
    HARD   = "un objeto |cff1eff00Poco común|r o |cff0070ddRaro|r",
    ELITE  = "un objeto |cff0070ddRaro|r de valor",
}

local DIFF_LABEL = {
    EASY   = "|cff1eff00Fácil|r",
    NORMAL = "|cffffffffNormal|r",
    HARD   = "|cffff8800Difícil|r",
    ELITE  = "|cffff4444Élite|r",
}

-- ============================================================
--  ESTADO
-- ============================================================
local ItemPools          = {}
local ItemPoolsByQuality = {}
local PoolsReady         = false
local QUALITY_WEIGHTS = { [1]=50, [2]=35, [3]=15 }
local QUALITY_COLOR   = { [1]="|cffffffff", [2]="|cff1eff00", [3]="|cff0070dd" }
local QUALITY_NAME    = { [1]="Común", [2]="Poco común", [3]="Raro" }

local FailCooldowns  = {}   -- [guidStr] = expiry unix
local ActiveMissions = {}   -- [guidStr] = mission table
local QuestListCD    = {}   -- [guidStr] = { [questId] = expiry unix }
local GossipContext  = {}   -- [guidStr] = { page, list }

-- ============================================================
--  POOLS DE ÍTEMS
-- ============================================================
local function BuildSubclassExclusion(cls, list)
    if #list == 0 then return "" end
    return string.format(" AND NOT (class=%d AND subclass IN (%s))", cls, table.concat(list, ","))
end

local function LoadItemPool(idx)
    local range = CFG.LEVEL_RANGES[idx]
    if not range then return end
    local lo, hi = range[1], range[2]

    local query = string.format([[
        SELECT entry, name, Quality FROM item_template
        WHERE Quality IN (%s) AND class IN (%s) AND ItemLevel >= %d
          AND ((RequiredLevel >= %d AND RequiredLevel <= %d) OR (RequiredLevel = 0 AND ItemLevel BETWEEN %d AND %d))
          AND (flags & %d) = 0 AND (flagsExtra & %d) = 0 AND bonding IN (0,2,3) %s %s
        ORDER BY RAND() LIMIT %d
    ]],
        table.concat(CFG.QUALITIES, ","),
        table.concat(CFG.ITEM_CLASSES, ","),
        CFG.MIN_ITEM_LEVEL,
        lo, hi, math.floor(lo*1.2), math.floor(hi*1.5),
        CFG.FLAG_BLACKLIST, CFG.FLAGS_EXTRA_BLACKLIST,
        BuildSubclassExclusion(2, CFG.ARMOR_SUBCLASS_EXCLUDE),
        BuildSubclassExclusion(4, CFG.WEAPON_SUBCLASS_EXCLUDE),
        CFG.MAX_PER_POOL
    )

    local res = WorldDBQuery(query)
    local pool, byQ = {}, {}
    if res then
        repeat
            local entry   = res:GetUInt32(0)
            local name    = res:GetString(1)
            local quality = res:GetUInt8(2)
            pool[#pool+1] = { id=entry, name=name, quality=quality }
            byQ[quality]  = byQ[quality] or {}
            byQ[quality][#byQ[quality]+1] = entry
        until not res:NextRow()
    end
    ItemPools[idx], ItemPoolsByQuality[idx] = pool, byQ
    print(string.format("[BotGarrison] Pool %d (lvl %d-%d): %d items.", idx, lo, hi, #pool))
end

local function LoadAllItemPools()
    print("[BotGarrison] Cargando pools de items...")
    for i = 1, #CFG.LEVEL_RANGES do LoadItemPool(i) end
    PoolsReady = true
    print("[BotGarrison] Pools listos.")
end

local function GetRangeIndex(level)
    for idx, r in ipairs(CFG.LEVEL_RANGES) do
        if level >= r[1] and level <= r[2] then return idx end
    end
    return 8
end

local function PickQuality()
    local total, acc = 0, 0
    for _, q in ipairs(CFG.QUALITIES) do total = total + (QUALITY_WEIGHTS[q] or 0) end
    local roll = math.random(1, total)
    for _, q in ipairs(CFG.QUALITIES) do
        acc = acc + (QUALITY_WEIGHTS[q] or 0)
        if roll <= acc then return q end
    end
    return CFG.QUALITIES[1]
end

local function PickRandomItemForLevel(level)
    local idx = GetRangeIndex(level)
    local byQ = ItemPoolsByQuality[idx]
    if not byQ or not next(byQ) then return 6256, "Tela de lino", 1 end

    local itemId, itemName, quality
    for _ = 1, 3 do
        local q = PickQuality()
        local pool = byQ[q]
        if pool and #pool > 0 then
            itemId, quality = pool[math.random(1, #pool)], q
            for _, item in ipairs(ItemPools[idx]) do
                if item.id == itemId then itemName = item.name; break end
            end
            break
        end
    end
    if not itemId then
        local p = ItemPools[idx]
        local x = p[math.random(1, #p)]
        itemId, itemName, quality = x.id, x.name, x.quality
    end
    return itemId, itemName or "Desconocido", quality or 1
end

-- ============================================================
--  ALTBOTS
-- ============================================================
local function SafeIsAltBot(unit)
    if not unit then return false end
    -- API playerbots (preferida)
    if unit.IsAltBot then
        local ok, res = pcall(function() return unit:IsAltBot() end)
        if ok and res then return true end
    end
    if unit.IsPlayerbot then
        local ok, res = pcall(function() return unit:IsPlayerbot() end)
        if ok and res then
            -- Si es playerbot pero no tenemos IsAltBot, aceptamos como bot de grupo
            -- (más restrictivo: solo si también es del grupo del master)
            return true
        end
    end
    return false
end

local function SafeIsHealer(unit)
    if unit.IsHealer then
        local ok, res = pcall(function() return unit:IsHealer() end)
        if ok and res then return true end
    end
    local cls = unit:GetClass()
    return cls == 2 or cls == 5 or cls == 7 or cls == 11
end

local function SafeIsTank(unit)
    if unit.IsMainTank then
        local ok, res = pcall(function() return unit:IsMainTank() end)
        if ok and res then return true end
    end
    if unit.IsAssistTank then
        local ok, res = pcall(function() return unit:IsAssistTank() end)
        if ok and res then return true end
    end
    local cls = unit:GetClass()
    return cls == 1 or cls == 2 or cls == 6 or cls == 11
end

local function SafeGearScore(unit)
    if not unit then return 0 end
    -- API playerbots / cores con GearScore
    if unit.GetMixedGearScore then
        local ok, gs = pcall(function() return unit:GetMixedGearScore(false, false, 0) end)
        if ok and type(gs) == "number" and gs > 0 then return gs end
        ok, gs = pcall(function() return unit:GetMixedGearScore(true, false, 0) end)
        if ok and type(gs) == "number" and gs > 0 then return gs end
    end
    if unit.GetGearScore then
        local ok, gs = pcall(function() return unit:GetGearScore() end)
        if ok and type(gs) == "number" and gs > 0 then return gs end
    end
    -- Fallback: nivel * 10 (solo si no hay API de GS)
    return (unit:GetLevel() or 1) * 10
end

--- Devuelve lista de altbots del jugador (grupo + mgr)
local function GetAltBots(player)
    local bots = {}
    local seen = {}

    local function addBot(bot)
        if not bot or not bot.GetGUIDLow then return end
        local g = bot:GetGUIDLow()
        if seen[g] or g == player:GetGUIDLow() then return end
        if not SafeIsAltBot(bot) then return end
        seen[g] = true
        bots[#bots+1] = bot
    end

    -- 1) Miembros del grupo
    local group = player:GetGroup()
    if group then
        local members = group:GetMembers()
        if members then
            for _, m in pairs(members) do
                addBot(m)
            end
        end
    end

    -- 2) PlayerbotMgr del jugador (altbots logueados aunque no estén en grupo)
    if GetPlayerbotsMgr then
        local ok, mgr = pcall(function()
            local pbm = GetPlayerbotsMgr()
            if pbm and pbm.GetPlayerbotMgr then
                return pbm:GetPlayerbotMgr(player)
            end
            return nil
        end)
        if ok and mgr and mgr.GetPlayerBots then
            local ok2, list = pcall(function() return mgr:GetPlayerBots() end)
            if ok2 and list then
                for _, bot in pairs(list) do
                    addBot(bot)
                end
            end
        end
    end

    return bots
end

local function GetBotNamesString(bots)
    if not bots or #bots == 0 then return "Ninguno" end
    local names = {}
    for _, b in ipairs(bots) do
        names[#names+1] = b:GetName()
    end
    return table.concat(names, ", ")
end

-- ============================================================
--  LOGOUT / LOGIN de altbots durante la misión (seguro / diferido)
-- ============================================================
local function GetMasterBotMgr(player)
    if not GetPlayerbotsMgr then return nil end
    local ok, mgr = pcall(function()
        local pbm = GetPlayerbotsMgr()
        if pbm and pbm.GetPlayerbotMgr then
            return pbm:GetPlayerbotMgr(player)
        end
        return nil
    end)
    if ok then return mgr end
    return nil
end

--- Extrae nombres YA (antes de que el objeto bot se invalide)
local function CollectBotNames(bots)
    local names = {}
    for _, bot in ipairs(bots or {}) do
        local ok, name = pcall(function() return bot:GetName() end)
        if ok and name and name ~= "" then
            names[#names+1] = name
        end
    end
    return names
end

--- Aparca bots lejos (modo park) o logout (modo logout)
local function DismissBotsOnMission(player, bots)
    local mode = CFG.BOT_MISSION_MODE or "park"
    if mode == "none" then return 0 end

    local names = CollectBotNames(bots)
    if #names == 0 then return 0 end

    local masterGuid = player:GetGUID()
    local delay = (mode == "park") and (CFG.PARK_DELAY_MS or 300) or (CFG.LOGOUT_DELAY_MS or 500)

    -- Guardar datos de bots para el evento diferido
    local botData = {}
    for _, bot in ipairs(bots or {}) do
        local ok, name = pcall(function() return bot:GetName() end)
        local okG, guid = pcall(function() return bot:GetGUID() end)
        local okL, low = pcall(function() return bot:GetGUIDLow() end)
        if ok and name then
            botData[#botData+1] = { name = name, guid = okG and guid or nil, low = okL and low or nil }
        end
    end

    CreateLuaEvent(function()
        local p = GetPlayerByGUID(masterGuid)
        if not p then return end
        local mgr = GetMasterBotMgr(p)

        for _, info in ipairs(botData) do
            local bot = nil
            -- Reobtener bot online por nombre desde el grupo / mgr
            local group = p:GetGroup()
            if group then
                local members = group:GetMembers()
                if members then
                    for _, m in pairs(members) do
                        local okN, n = pcall(function() return m:GetName() end)
                        if okN and n == info.name then bot = m; break end
                    end
                end
            end
            if not bot and mgr and mgr.GetPlayerBots then
                local okList, list = pcall(function() return mgr:GetPlayerBots() end)
                if okList and list then
                    for _, b in pairs(list) do
                        local okN, n = pcall(function() return b:GetName() end)
                        if okN and n == info.name then bot = b; break end
                    end
                end
            end

            if mode == "park" and bot then
                -- Un solo saludo one-shot. EmoteState(66) dejaba el gesto EN BUCLE.
                pcall(function()
                    if bot.EmoteState then bot:EmoteState(0) end
                end)
                pcall(function()
                    if bot.HandleEmoteCommand then
                        bot:HandleEmoteCommand(66)
                    elseif bot.Emote then
                        bot:Emote(66)
                    end
                end)

                local botGuid = bot:GetGUID()
                local botName = info.name
                -- stay + teleport DESPUES del saludo (si no, cancelan la animacion)
                CreateLuaEvent(function()
                    local b = GetPlayerByGUID and GetPlayerByGUID(botGuid) or nil
                    if not b and GetPlayerByName then
                        local ok, bb = pcall(function() return GetPlayerByName(botName) end)
                        if ok then b = bb end
                    end
                    if not b then return end
                    pcall(function()
                        if b.EmoteState then b:EmoteState(0) end
                    end)
                    local m = GetMasterBotMgr(p)
                    if m and m.HandlePlayerbotCommand then
                        pcall(function() m:HandlePlayerbotCommand("bot " .. botName .. " stay") end)
                    end
                    pcall(function()
                        b:Teleport(CFG.PARK_MAP or 13, CFG.PARK_X or 0, CFG.PARK_Y or 0, CFG.PARK_Z or 0, CFG.PARK_O or 0)
                    end)
                end, 2000, 1)
                print(string.format("[BotGarrison] Park bot '%s' → map %s (salute)", info.name, tostring(CFG.PARK_MAP)))
            elseif mode == "logout" then
                local done = false
                if mgr and bot and mgr.LogoutPlayerBot then
                    local okG, guid = pcall(function() return bot:GetGUID() end)
                    if okG and guid then
                        done = pcall(function() mgr:LogoutPlayerBot(guid) end)
                    end
                end
                if not done and mgr and mgr.HandlePlayerbotCommand then
                    pcall(function() mgr:HandlePlayerbotCommand("remove " .. info.name) end)
                    pcall(function() mgr:HandlePlayerbotCommand("bot remove " .. info.name) end)
                end
                print(string.format("[BotGarrison] Logout bot '%s' ok=%s", info.name, tostring(done)))
            end
        end
    end, delay, 1)

    return #botData
end

--- Devuelve bots: park → teleport al jugador; logout → intentar login
local function RecallBotsFromMission(player, mission)
    local mode = CFG.BOT_MISSION_MODE or "park"
    if mode == "none" then return 0 end
    if not mission then return 0 end

    local names = {}
    if mission.botNames and mission.botNames ~= "" and mission.botNames ~= "Ninguno" then
        for name in string.gmatch(mission.botNames, "[^,]+") do
            name = name:match("^%s*(.-)%s*$")
            if name and name ~= "" then
                names[#names+1] = name
            end
        end
    end

    local guidLows = {}
    if mission.botGuids and mission.botGuids ~= "" then
        for g in string.gmatch(mission.botGuids, "[^,]+") do
            local n = tonumber(g)
            if n then guidLows[#guidLows+1] = n end
        end
    end

    if #names == 0 and #guidLows == 0 then return 0 end

    local masterGuid = player:GetGUID()
    local delay = (mode == "park") and (CFG.PARK_DELAY_MS or 300) or (CFG.LOGIN_DELAY_MS or 1000)

    CreateLuaEvent(function()
        local p = GetPlayerByGUID(masterGuid)
        if not p then
            print("[BotGarrison] Recall: jugador offline, abort")
            return
        end

        local px, py, pz, po = p:GetX(), p:GetY(), p:GetZ(), p:GetO()
        local pmap = p:GetMapId()
        local mgr = GetMasterBotMgr(p)

        if mode == "park" then
            -- Buscar bots online (siguen logueados en el mapa park) y traerlos
            local function tryTeleportBot(bot, name)
                if not bot then return false end
                local ok = pcall(function()
                    bot:Teleport(pmap, px + math.random(-3, 3), py + math.random(-3, 3), pz, po)
                end)
                -- Orden AI follow (silencioso)
                pcall(function()
                    if mgr and mgr.HandlePlayerbotCommand then
                        mgr:HandlePlayerbotCommand("bot " .. name .. " follow")
                    end
                end)
                pcall(function()
                    if bot.EmoteState then bot:EmoteState(0) end
                end)
                pcall(function()
                    if bot.HandleEmoteCommand then
                        bot:HandleEmoteCommand(66)
                    elseif bot.Emote then
                        bot:Emote(66)
                    end
                end)
                print(string.format("[BotGarrison] Recall park '%s' → %s (salute)", name, tostring(ok)))
                return ok
            end

            -- Por mgr
            if mgr and mgr.GetPlayerBots then
                local okList, list = pcall(function() return mgr:GetPlayerBots() end)
                if okList and list then
                    for _, bot in pairs(list) do
                        local okN, n = pcall(function() return bot:GetName() end)
                        if okN and n then
                            for _, want in ipairs(names) do
                                if n == want then tryTeleportBot(bot, n) end
                            end
                        end
                    end
                end
            end

            -- Por nombre en el mundo (GetPlayerByName si existe)
            if GetPlayerByName then
                for _, name in ipairs(names) do
                    local ok, bot = pcall(function() return GetPlayerByName(name) end)
                    if ok and bot then tryTeleportBot(bot, name) end
                end
            end

            p:SendBroadcastMessage("|cff00ff00[BotGarrison]|r Compañeros de vuelta a tu posición.")
        else
            -- Modo logout: intentar login (puede fallar en algunos cores)
            if GetPlayerbotsMgr then
                pcall(function()
                    local pbm = GetPlayerbotsMgr()
                    if pbm and pbm.AddPlayerbotData then pbm:AddPlayerbotData(p) end
                end)
            end
            mgr = GetMasterBotMgr(p)
            if mgr and mgr.AddPlayerBot then
                for _, low in ipairs(guidLows) do
                    pcall(function() mgr:AddPlayerBot(low) end)
                end
            end
            if mgr and mgr.HandlePlayerbotCommand then
                for _, name in ipairs(names) do
                    pcall(function() mgr:HandlePlayerbotCommand("add " .. name) end)
                    pcall(function() mgr:HandlePlayerbotCommand("bot add " .. name) end)
                end
            end
            if #names > 0 then
                p:SendBroadcastMessage("|cffffcc00[BotGarrison]|r Si no han vuelto, usa: .playerbots bot add <nombre>")
            end
        end
    end, delay, 1)

    return math.max(#names, #guidLows)
end

--- Clasifica roles del destacamento (solo bots)
local function CountBotRoles(bots)
    local tanks, healers, dps = 0, 0, 0
    for _, bot in ipairs(bots or {}) do
        local isT = SafeIsTank(bot)
        local isH = SafeIsHealer(bot)
        -- Si es tank y healer (p.ej. pala), cuenta tank prioritario si IsMainTank, si no heal
        if isT and isH then
            if bot.IsMainTank then
                local ok, mt = pcall(function() return bot:IsMainTank() end)
                if ok and mt then tanks = tanks + 1
                else healers = healers + 1 end
            else
                tanks = tanks + 1 -- por defecto tank dual-spec ambiguo
            end
        elseif isT then
            tanks = tanks + 1
        elseif isH then
            healers = healers + 1
        else
            dps = dps + 1
        end
    end
    return tanks, healers, dps
end

--- Comprueba requisitos de la misión (bots, tank, heal, dps)
local function CheckQuestRequirements(quest, bots)
    local botCount = #(bots or {})
    local tanks, healers, dps = CountBotRoles(bots)
    local minB = quest.minBots or CFG.MIN_BOTS or 1
    local maxB = quest.maxBots or CFG.MAX_MISSION_BOTS or 4
    local needT = quest.minTank or 0
    local needH = quest.minHealer or 0
    local needD = quest.minDps or 0

    if botCount < minB then
        return false, string.format("Hacen falta al menos %d compañeros (tienes %d).", minB, botCount)
    end
    if botCount > maxB then
        return false, string.format("Máximo %d compañeros en misión (tienes %d). Saca alguno del grupo.", maxB, botCount)
    end
    if tanks < needT then
        return false, string.format("Requiere %d tank(s). Detectados: %d.", needT, tanks)
    end
    if healers < needH then
        return false, string.format("Requiere %d healer(s). Detectados: %d.", needH, healers)
    end
    if dps < needD then
        return false, string.format("Requiere %d DPS. Detectados: %d.", needD, dps)
    end
    return true, nil, tanks, healers, dps
end

local function CalculateGroupPower(player, bots)
    bots = bots or GetAltBots(player)
    local power, hasTank, hasHealer, botCount = 0, false, false, 0
    local playerLevel = math.max(1, player:GetLevel())

    -- GS de los altbots que van a la mision
    local totalGs, totalMin = 0, 0
    local gsDebug = {}

    for _, bot in ipairs(bots) do
        botCount = botCount + 1
        local okN, name = pcall(function() return bot:GetName() end)
        local lvl = bot:GetLevel() or 1
        local gs = SafeGearScore(bot)
        totalGs = totalGs + gs
        totalMin = totalMin + (lvl * (CFG.MIN_GS_PER_LEVEL or 15))
        gsDebug[#gsDebug+1] = string.format("%s=%d", okN and name or "?", gs)

        local cls = bot:GetClass()
        local weight = CFG.CLASS_ROLE_WEIGHT[cls] or CFG.DEFAULT_ROLE_WEIGHT
        local levelFactor = math.max(0.5, lvl / playerLevel)
        power = power + (weight * levelFactor)

        if SafeIsTank(bot) then hasTank = true end
        if SafeIsHealer(bot) then hasHealer = true end
    end

    local avgGs = (botCount > 0) and (totalGs / botCount) or 0
    local avgMinGs = (botCount > 0) and (totalMin / botCount) or 0
    local undergeared = botCount > 0 and avgGs < avgMinGs

    local gearBonus = avgGs / (CFG.GS_DIVISOR or 35)
    if undergeared then
        gearBonus = gearBonus * (CFG.UNDERGEARED_GEAR_MULT or 0.25)
    end
    power = power + gearBonus

    -- Poder del Capitan: GS del jugador (aura ficticia de liderazgo)
    local captainGs = SafeGearScore(player)
    local captainMult = CFG.CAPTAIN_POWER_MULT or 0.75
    local captainBonus = (captainGs / (CFG.GS_DIVISOR or 35)) * captainMult
    power = power + captainBonus

    if hasTank and hasHealer and botCount >= 2 then
        power = power + CFG.COMPOSITION_BONUS
    end

    print(string.format(
        "[BotGarrison] GS bots (%d): %s | media=%.1f (min=%.1f) under=%s | Capitan GS=%d (+%.1f poder) | power=%.1f",
        botCount, table.concat(gsDebug, ", "), avgGs, avgMinGs, tostring(undergeared),
        captainGs, captainBonus, power
    ))

    return power, hasTank, hasHealer, botCount, bots, undergeared, avgGs, captainGs
end

local function CalculateSuccessChance(power, difficulty, undergeared)
    local base = CFG.BASE_SUCCESS[difficulty] or 0.20
    local bonus = power * (CFG.POWER_PER_POINT or 0.025)
    local chance = base + bonus
    local maxS = CFG.MAX_SUCCESS or 0.95
    local minS = CFG.MIN_SUCCESS or 0.05
    if undergeared then
        maxS = math.min(maxS, CFG.UNDERGEARED_MAX_SUCCESS or 0.40)
    end
    return math.max(minS, math.min(maxS, chance))
end

local function RollSuccess(chance)
    return math.random() <= chance
end

-- ============================================================
--  COOLDOWNS / PERSISTENCIA
-- ============================================================
local function GuidKey(player)
    return tostring(player:GetGUIDLow())
end

local function SetFailCooldown(guidStr, difficulty)
    local secs = CFG.FAIL_COOLDOWN_SECS[difficulty] or 300
    FailCooldowns[guidStr] = os.time() + secs
    return secs
end

local function GetRemainingCooldown(guidStr)
    local expiry = FailCooldowns[guidStr]
    if not expiry then return 0 end
    local remaining = expiry - os.time()
    if remaining <= 0 then
        FailCooldowns[guidStr] = nil
        return 0
    end
    return remaining
end

local function SaveMissionToDB(player, mission)
    local guid = player:GetGUIDLow()
    CharDBExecute(string.format([[
        REPLACE INTO character_bot_missions
        (player_guid, quest_id, quest_name, difficulty, start_time, duration, end_time,
         gold_min, gold_max, bot_guids, bot_names, power, chance)
        VALUES (%d, %d, '%s', '%s', %d, %d, %d, %d, %d, '%s', '%s', %f, %f)
    ]],
        guid,
        mission.questId,
        mission.questName:gsub("'", "''"),
        mission.difficulty,
        mission.startTime,
        mission.duration,
        mission.endTime,
        mission.goldMin,
        mission.goldMax,
        mission.botGuids or "",
        (mission.botNames or ""):gsub("'", "''"),
        mission.power or 0,
        mission.chance or 0
    ))
end

local function ClearMissionDB(player)
    CharDBExecute(string.format(
        "DELETE FROM character_bot_missions WHERE player_guid = %d",
        player:GetGUIDLow()
    ))
end

local function LoadMissionFromDB(player)
    local res = CharDBQuery(string.format(
        "SELECT quest_id, quest_name, difficulty, start_time, duration, end_time, gold_min, gold_max, bot_guids, bot_names, power, chance FROM character_bot_missions WHERE player_guid = %d LIMIT 1",
        player:GetGUIDLow()
    ))
    if not res then return nil end
    return {
        questId    = res:GetUInt32(0),
        questName  = res:GetString(1),
        difficulty = res:GetString(2),
        startTime  = res:GetUInt32(3),
        duration   = res:GetUInt32(4),
        endTime    = res:GetUInt32(5),
        goldMin    = res:GetUInt32(6),
        goldMax    = res:GetUInt32(7),
        botGuids   = res:GetString(8),
        botNames   = res:GetString(9),
        power      = res:GetFloat(10),
        chance     = res:GetFloat(11),
        cancelled  = false,
    }
end

-- ============================================================
--  RECOMPENSAS / RESOLUCIÓN
-- ============================================================
local function FindQuest(id)
    for _, q in ipairs(QUESTS) do
        if q.id == id then return q end
    end
    return nil
end

local function NormQuestId(questId)
    local n = tonumber(questId)
    return n
end

local function IsQuestOnListCD(guidStr, questId)
    questId = NormQuestId(questId)
    if not questId then return false end
    local t = QuestListCD[guidStr]
    if not t then return false end
    local exp = t[questId]
    if not exp then return false end
    if os.time() >= exp then
        t[questId] = nil
        -- limpia BD
        pcall(function()
            CharDBExecute(string.format(
                "DELETE FROM character_bot_quest_cd WHERE player_guid = %d AND quest_id = %d",
                tonumber(guidStr) or 0, questId))
        end)
        return false
    end
    return true
end

local function GetQuestListCDRemaining(guidStr, questId)
    questId = NormQuestId(questId)
    if not questId then return 0 end
    local t = QuestListCD[guidStr]
    if not t or not t[questId] then return 0 end
    local rem = t[questId] - os.time()
    if rem <= 0 then
        t[questId] = nil
        return 0
    end
    return rem
end

local function SetQuestListCD(guidStr, questId, secsOverride)
    questId = NormQuestId(questId)
    if not questId then
        print("[BotGarrison] SetQuestListCD: questId invalido")
        return
    end
    local secs = secsOverride or CFG.MISSION_LIST_CD or 900
    local expiry = os.time() + secs
    QuestListCD[guidStr] = QuestListCD[guidStr] or {}
    QuestListCD[guidStr][questId] = expiry

    local pguid = tonumber(guidStr) or 0
    pcall(function()
        CharDBExecute(string.format(
            "REPLACE INTO character_bot_quest_cd (player_guid, quest_id, expiry) VALUES (%d, %d, %d)",
            pguid, questId, expiry))
    end)
    print(string.format("[BotGarrison] CD lista quest=%d player=%s hasta +%ds", questId, guidStr, secs))
end

local function LoadQuestListCDFromDB(player)
    local guidStr = GuidKey(player)
    local pguid = player:GetGUIDLow()
    local ok, res = pcall(function()
        return CharDBQuery(string.format(
            "SELECT quest_id, expiry FROM character_bot_quest_cd WHERE player_guid = %d", pguid))
    end)
    if not ok or not res then return end
    QuestListCD[guidStr] = QuestListCD[guidStr] or {}
    local now = os.time()
    repeat
        local qid = res:GetUInt32(0)
        local exp = res:GetUInt32(1)
        if exp > now then
            QuestListCD[guidStr][qid] = exp
        end
    until not res:NextRow()
    -- limpia caducados
    pcall(function()
        CharDBExecute(string.format(
            "DELETE FROM character_bot_quest_cd WHERE player_guid = %d AND expiry <= %d", pguid, now))
    end)
end

--- Pool de misiones validas por nivel (sin las en CD de lista)
local function QuestsAvailable(player)
    local level = player:GetLevel()
    local guidStr = GuidKey(player)
    local list = {}
    for _, q in ipairs(QUESTS) do
        local minL = q.minLevel or 1
        local maxL = q.maxLevel or 80
        local qid = NormQuestId(q.id)
        if level >= minL and level <= maxL and not IsQuestOnListCD(guidStr, qid) then
            list[#list+1] = q
        end
    end
    return list
end

--- Elige un subconjunto rotativo: p.ej. 2 faciles, 3 normales, 1 dificil, 1 elite
local function BuildOfferList(player)
    local pool = QuestsAvailable(player)
    local slots = CFG.LIST_SLOTS or { EASY = 2, NORMAL = 3, HARD = 1, ELITE = 1 }
    local byDiff = { EASY = {}, NORMAL = {}, HARD = {}, ELITE = {} }
    for _, q in ipairs(pool) do
        local d = q.difficulty or "NORMAL"
        if byDiff[d] then
            byDiff[d][#byDiff[d]+1] = q
        end
    end
    -- barajar cada cubo
    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = math.random(1, i)
            t[i], t[j] = t[j], t[i]
        end
    end
    local offer = {}
    for _, diff in ipairs({ "EASY", "NORMAL", "HARD", "ELITE" }) do
        local bucket = byDiff[diff] or {}
        shuffle(bucket)
        local n = slots[diff] or 0
        for i = 1, math.min(n, #bucket) do
            offer[#offer+1] = bucket[i]
        end
    end
    -- si el pool es muy pequeño, rellenar con lo que quede
    if #offer == 0 then
        shuffle(pool)
        for i = 1, math.min(5, #pool) do
            offer[#offer+1] = pool[i]
        end
    end
    return offer
end

local function PlayMissionCompleteSound(player)
    local ids = CFG.COMPLETE_SOUND_IDS or { 13363 }
    for _, sid in ipairs(ids) do
        if player.PlayDirectSound then
            local ok = pcall(function() player:PlayDirectSound(sid) end)
            if ok then break end
        elseif player.PlayDistanceSound then
            local ok = pcall(function() player:PlayDistanceSound(sid) end)
            if ok then break end
        end
    end
end

local function ScaleGold(baseMin, baseMax, level)
    level = math.max(1, level or 1)
    local multCfg = CFG.GOLD_LEVEL_MULT or 0
    -- mult 0 = oro absoluto (BotQuest original); si >0 multiplica por nivel
    local mult = (multCfg > 0) and (multCfg * level) or 1
    local lo = math.max(1, math.floor((baseMin or 50) * mult))
    local hi = math.max(lo, math.floor((baseMax or 100) * mult))
    return math.random(lo, hi)
end

local function SafeGiveXP(unit, amount)
    if not unit or not amount or amount <= 0 then return false end
    if unit.GiveXP then
        local ok = pcall(function() unit:GiveXP(amount) end)
        if ok then return true end
    end
    if unit.ModifyXP then
        local ok = pcall(function() unit:ModifyXP(amount) end)
        if ok then return true end
    end
    return false
end

local function GrantMissionXP(player, mission)
    if not CFG.XP_TO_PLAYER and not CFG.XP_TO_BOTS then return end
    local diff = mission.difficulty or "NORMAL"
    local base = (CFG.XP_BOT_BASE and CFG.XP_BOT_BASE[diff]) or 100
    local names = {}
    if mission.botNames and mission.botNames ~= "" then
        for name in string.gmatch(mission.botNames, "[^,]+") do
            name = name:match("^%s*(.-)%s*$")
            if name and name ~= "" then names[#names+1] = name end
        end
    end

    local masterGuid = player:GetGUID()
    -- Esperar a que el park devuelva a los bots
    local delay = (CFG.PARK_DELAY_MS or 300) + 500

    CreateLuaEvent(function()
        local p = GetPlayerByGUID(masterGuid)
        if not p then return end

        local botXpGiven = 0
        if CFG.XP_TO_BOTS then
            local function giveBot(bot)
                if not bot then return end
                local lvl = bot:GetLevel() or 1
                local xp = math.floor(base * lvl)
                if SafeGiveXP(bot, xp) then
                    botXpGiven = botXpGiven + xp
                    print(string.format("[BotGarrison] XP bot '%s' +%d", bot:GetName(), xp))
                end
            end

            local mgr = GetMasterBotMgr(p)
            if mgr and mgr.GetPlayerBots then
                local okList, list = pcall(function() return mgr:GetPlayerBots() end)
                if okList and list then
                    for _, bot in pairs(list) do
                        local okN, n = pcall(function() return bot:GetName() end)
                        if okN and n then
                            for _, want in ipairs(names) do
                                if n == want then giveBot(bot) end
                            end
                        end
                    end
                end
            end
            if GetPlayerByName then
                for _, name in ipairs(names) do
                    local ok, bot = pcall(function() return GetPlayerByName(name) end)
                    if ok and bot then giveBot(bot) end
                end
            end
        end

        if CFG.XP_TO_PLAYER then
            local lvl = p:GetLevel() or 1
            local xpBotRef = math.floor(base * lvl)
            local xpPlayer = math.floor(xpBotRef * (CFG.XP_PLAYER_RATIO or 0.25))
            if SafeGiveXP(p, xpPlayer) then
                p:SendBroadcastMessage(string.format("|cff00ff00[BotGarrison]|r Experiencia (tú): |cffffffff+%d|r", xpPlayer))
            end
        end

        if botXpGiven > 0 then
            p:SendBroadcastMessage(string.format("|cff00ff00[BotGarrison]|r Experiencia (compañeros): |cffffffff+%d|r total", botXpGiven))
        end
    end, delay, 1)
end

local function DeliverRewards(player, mission)
    local level = player:GetLevel()
    local gold = ScaleGold(mission.goldMin, mission.goldMax, level)
    player:ModifyMoney(gold)

    local itemId, itemName, quality = PickRandomItemForLevel(level)
    player:AddItem(itemId, 1)

    local qColor = QUALITY_COLOR[quality] or "|cffffffff"
    local qName  = QUALITY_NAME[quality] or ""

    player:SendBroadcastMessage("|cff00ff00[BotGarrison]|r ¡Misión completada: |cffffcc00" .. (mission.questName or "?") .. "|r!")
    player:SendBroadcastMessage(string.format("  |cffffcc00Oro:|r +%dg %dp %dc",
        math.floor(gold/10000), math.floor((gold%10000)/100), gold%100))
    player:SendBroadcastMessage(string.format("  |cffffcc00Item:|r %s[%s]|r |cff888888(%s)|r",
        qColor, itemName, qName))

    GrantMissionXP(player, mission)
end

local function ResolveMission(player, mission)
    local guidStr = GuidKey(player)
    -- Usar poder/chance guardados al inicio (los bots están offline)
    local power = mission.power or 0
    local chance = mission.chance or CalculateSuccessChance(power, mission.difficulty)
    local botCount = 0
    if mission.botGuids and mission.botGuids ~= "" then
        for _ in string.gmatch(mission.botGuids, "[^,]+") do botCount = botCount + 1 end
    end
    local success = RollSuccess(chance)

    print(string.format("[BotGarrison] Resolve '%s' | %s | bots:%d power:%.1f chance:%.0f%% → %s",
        mission.questName or mission.questId, player:GetName(), botCount, power, chance*100,
        success and "OK" or "FAIL"))

    -- Volver a loguear los altbots
    RecallBotsFromMission(player, mission)
    player:SendBroadcastMessage("|cff00ff00[BotGarrison]|r ¡Tus compañeros han regresado!")

    local qid = NormQuestId(mission.questId)
    if success then
        mission.chance = chance
        DeliverRewards(player, mission)
        PlayMissionCompleteSound(player)
        -- CD de lista: esta mision no vuelve a salir 15 min
        SetQuestListCD(guidStr, qid, CFG.MISSION_LIST_CD or 900)
        player:SendBroadcastMessage(string.format(
            "|cff00ccff[BotGarrison]|r |cffffcc00%s|r no volvera al tablon en |cffffffff%d min|r.",
            mission.questName or ("#" .. tostring(qid)),
            math.ceil((CFG.MISSION_LIST_CD or 900) / 60)))
    else
        local cd = SetFailCooldown(guidStr, mission.difficulty)
        player:SendBroadcastMessage("|cffff4444[BotGarrison]|r Misión fallida. Tus bots regresan derrotados.")
        player:SendBroadcastMessage(string.format("|cffff8800[BotGarrison]|r Cooldown: |cffffffff%d min|r.", math.ceil(cd/60)))
        -- Fallo: CD de lista a la mitad
        local half = math.floor((CFG.MISSION_LIST_CD or 900) / 2)
        SetQuestListCD(guidStr, qid, half)
        player:SendBroadcastMessage(string.format(
            "|cff00ccff[BotGarrison]|r |cffffcc00%s|r no volvera al tablon en |cffffffff%d min|r.",
            mission.questName or ("#" .. tostring(qid)), math.ceil(half / 60)))
    end

    ActiveMissions[guidStr] = nil
    ClearMissionDB(player)
end

local function StartMission(player, quest)
    local guidStr = GuidKey(player)
    local cd = GetRemainingCooldown(guidStr)
    if cd > 0 then
        player:SendBroadcastMessage(string.format(
            "|cffff4444[BotGarrison]|r Bots recuperándose: |cffffffff%d min %d s|r.",
            math.floor(cd/60), cd%60))
        return false
    end

    local qid = NormQuestId(quest and quest.id)
    local listRem = GetQuestListCDRemaining(guidStr, qid)
    if listRem > 0 then
        player:SendBroadcastMessage(string.format(
            "|cffff4444[BotGarrison]|r Esa mision esta en cooldown de lista: |cffffffff%s|r.",
            FormatTimeMMSS(listRem)))
        return false
    end

    if ActiveMissions[guidStr] and not ActiveMissions[guidStr].cancelled then
        player:SendBroadcastMessage("|cffff4444[BotGarrison]|r Ya hay una misión en curso.")
        return false
    end

    local bots = GetAltBots(player)
    local power, hasTank, hasHealer, botCount, _, undergeared = CalculateGroupPower(player, bots)

    local okReq, reqMsg = CheckQuestRequirements(quest, bots)
    if not okReq then
        player:SendBroadcastMessage("|cffff4444[BotGarrison]|r " .. (reqMsg or "Requisitos no cumplidos."))
        return false
    end

    local chance = CalculateSuccessChance(power, quest.difficulty, undergeared)
    if undergeared then
        player:SendBroadcastMessage("|cffff8800[BotGarrison]|r Aviso: equipo bajo del destacamento. Éxito limitado.")
    end
    local duration = math.max(30, math.min(quest.duration or 300, 3600))
    local now = os.time()

    local botGuidList, botNameList = {}, {}
    for _, b in ipairs(bots) do
        botGuidList[#botGuidList+1] = tostring(b:GetGUIDLow())
        botNameList[#botNameList+1] = b:GetName()
    end

    local mission = {
        questId    = quest.id,
        questName  = quest.name,
        difficulty = quest.difficulty,
        startTime  = now,
        duration   = duration,
        endTime    = now + duration,
        goldMin    = quest.goldMin,
        goldMax    = quest.goldMax,
        botGuids   = table.concat(botGuidList, ","),
        botNames   = table.concat(botNameList, ", "),
        power      = power,
        chance     = chance,
        cancelled  = false,
        ready      = false,
    }

    mission.masterGuid = player:GetGUID()
    ActiveMissions[guidStr] = mission
    SaveMissionToDB(player, mission)

    -- Desconectar altbots para simular que están de misión
    local dismissed = DismissBotsOnMission(player, bots)

    local comp = (hasTank and hasHealer and botCount >= 2) and " |cff00ff00[Bonus composición]|r" or ""
    player:SendBroadcastMessage(string.format(
        "|cff00ccff[BotGarrison]|r Misión iniciada: |cffffcc00%s|r (%s)",
        quest.name, DIFF_LABEL[quest.difficulty] or quest.difficulty))
    player:SendBroadcastMessage(string.format(
        "  Grupo: |cffffffff%d altbots|r | Poder: |cffffcc00%.1f|r | Éxito: |cffffcc00%.0f%%|r%s",
        botCount, power, chance*100, comp))
    player:SendBroadcastMessage(string.format(
        "  Duración: |cffffffff%d min|r | Compañeros: |cffaaaaaa%s|r",
        math.ceil(duration/60), mission.botNames))
    player:SendBroadcastMessage(string.format(
        "|cff00ccff[BotGarrison]|r %d compañero(s) han partido de misión.",
        dismissed))

    -- Al acabar el tiempo: queda LISTA para reclamar (estilo Garrison), no se resuelve sola
    local fullGuid = player:GetGUID()
    local capturedQuestId = quest.id
    CreateLuaEvent(function()
        local m = ActiveMissions[guidStr]
        if not m or m.cancelled or m.questId ~= capturedQuestId then return end
        m.ready = true
        local p = GetPlayerByGUID(fullGuid)
        if p then
            p:SendBroadcastMessage("|cff00ff00[BotGarrison]|r !! Mision lista! Vuelve al tablon y reclama el resultado.")
            if p.SendNotification then
                pcall(function()
                    p:SendNotification("BotGarrison: Mision lista para reclamar!")
                end)
            end
        end
        print(string.format("[BotGarrison] Mision lista para reclamar: %s (%s)",
            m.questName or "?", guidStr))
    end, duration * 1000, 1)

    return true
end

local function ClaimMission(player)
    local guidStr = GuidKey(player)
    local m = ActiveMissions[guidStr]
    if not m or m.cancelled then
        player:SendBroadcastMessage("|cffff8800[BotGarrison]|r No hay misión para reclamar.")
        return
    end
    if not m.ready and os.time() < (m.endTime or 0) then
        local rem = math.max(0, m.endTime - os.time())
        player:SendBroadcastMessage(string.format(
            "|cffff8800[BotGarrison]|r La misión aún no ha terminado (%s restantes).",
            FormatTimeMMSS(rem)))
        return
    end
    m.ready = true
    ResolveMission(player, m)
end

local function CancelMission(player)
    local guidStr = GuidKey(player)
    local m = ActiveMissions[guidStr]
    if not m then
        player:SendBroadcastMessage("|cffff8800[BotGarrison]|r No hay misión activa.")
        return
    end
    if m.ready then
        player:SendBroadcastMessage("|cffff8800[BotGarrison]|r La misión ya terminó: reclama el resultado en el tablón.")
        return
    end
    m.cancelled = true
    RecallBotsFromMission(player, m)
    ActiveMissions[guidStr] = nil
    ClearMissionDB(player)
    player:SendBroadcastMessage("|cffff8800[BotGarrison]|r Misión cancelada. Compañeros de vuelta. Sin recompensa.")
end

-- ============================================================
--  GOSSIP — TABLÓN
-- ============================================================
-- intids:
--  1        = refrescar / actualizar contador
--  2        = ver misiones
--  3        = cancelar misión
--  5        = reclamar misión lista
--  100+n    = detalle misión n (índice en lista filtrada)
--  200+n    = confirmar envío misión n
--  9        = cerrar

--- Trunca texto para una sola línea de gossip
local function ShortLine(s, maxLen)
    maxLen = maxLen or 70
    s = tostring(s or "")
    if #s <= maxLen then return s end
    return s:sub(1, maxLen - 3) .. "..."
end

local function GossipShowMain(player, go)
    local guidStr = GuidKey(player)
    local bots = GetAltBots(player)
    local power, hasTank, hasHealer, botCount, _, undergeared, avgGs, captainGs = CalculateGroupPower(player, bots)
    local cd = GetRemainingCooldown(guidStr)
    local mission = ActiveMissions[guidStr]
    local tanks, healers, dps = CountBotRoles(bots)

    -- Si el tiempo ya pasó, marcar lista
    if mission and not mission.cancelled and not mission.ready and os.time() >= (mission.endTime or 0) then
        mission.ready = true
    end

    player:GossipClearMenu()

    if mission and not mission.cancelled then
        if mission.ready then
            -- Estilo Garrison: misión lista para abrir
            player:GossipMenuAddItem(2,
                "|cff00ff00>> MISION LISTA! Reclamar resultado <<|r", 0, 5)
            player:GossipMenuAddItem(0,
                "|cffffcc00" .. (mission.questName or "Mision") .. "|r - companeros de vuelta al reclamar", 0, 5)
            player:SendBroadcastMessage(string.format(
                "|cff00ff00[BotGarrison]|r !! Mision lista: |cffffcc00%s|r - reclama en el tablon.",
                mission.questName or "?"))
        else
            local rem = math.max(0, (mission.endTime or 0) - os.time())
            -- Contador: al pulsar se refresca el menú (intid 1)
            player:GossipMenuAddItem(0, string.format(
                "|cffffcc00Tiempo de misión:|r |cffffffff%s|r", FormatTimeMMSS(rem)), 0, 1)
            player:GossipMenuAddItem(0, string.format(
                "|cffaaaaaa%s|r — pulsa el tiempo para actualizar",
                ShortLine(mission.questName, 40)), 0, 1)
            player:GossipMenuAddItem(4, "Cancelar misión actual", 0, 3)
            player:SendBroadcastMessage(string.format(
                "|cff00ccff[BotGarrison]|r En curso: |cffffcc00%s|r | Tiempo: |cffffffff%s|r",
                mission.questName or "?", FormatTimeMMSS(rem)))
        end
    else
        player:GossipMenuAddItem(2, "Ver misiones disponibles", 0, 2)
        player:SendBroadcastMessage(string.format(
            "|cff00ccff[BotGarrison]|r Destacamento: |cffffffff%d|r bots | GS bots |cffffffff%.0f|r | Capitan |cffffffff%.0f|r | Poder |cffffffff%.1f|r | T%d/H%d/D%d%s",
            botCount, avgGs or 0, captainGs or 0, power, tanks, healers, dps,
            undergeared and " |cffff8800(equipo bajo)|r" or ""
        ))
        if cd > 0 then
            player:SendBroadcastMessage(string.format(
                "|cff00ccff[BotGarrison]|r Cooldown: |cffffffff%s|r", FormatTimeMMSS(cd)))
        end
    end

    player:GossipMenuAddItem(0, "Ver misiones en cooldown", 0, 6)
    player:GossipMenuAddItem(0, "Adiós", 0, 9)
    player:GossipSendMenu(1, go)
end

--- Lista de misiones con CD de lista activo (15 min al completar)
local function GossipShowListCD(player, go)
    local guidStr = GuidKey(player)
    local t = QuestListCD[guidStr]
    local now = os.time()
    local rows = {}

    if t then
        for qid, exp in pairs(t) do
            local rem = (exp or 0) - now
            if rem > 0 then
                local q = FindQuest(qid)
                local name = (q and q.name) or ("Mision #" .. tostring(qid))
                local diff = (q and q.difficulty) or "?"
                rows[#rows + 1] = {
                    name = name,
                    diff = diff,
                    rem = rem,
                    qid = qid,
                }
            else
                t[qid] = nil
            end
        end
    end

    -- Ordenar por tiempo restante (menos primero)
    table.sort(rows, function(a, b) return a.rem < b.rem end)

    player:GossipClearMenu()
    player:SendBroadcastMessage("|cff00ccff======== Misiones en cooldown ========|r")

    if #rows == 0 then
        player:SendBroadcastMessage("|cffaaaaaaNinguna mision en cooldown de lista.|r")
        player:GossipMenuAddItem(0, "No hay misiones en CD", 0, 1)
    else
        player:SendBroadcastMessage(string.format(
            "|cffffffff%d|r mision(es) bloqueadas (vuelven al tablon al acabar el tiempo):", #rows))
        for i, r in ipairs(rows) do
            local diffCol =
                (r.diff == "EASY" and "|cff1eff00Facil|r")
                or (r.diff == "NORMAL" and "|cffffffffNormal|r")
                or (r.diff == "HARD" and "|cffff8800Dificil|r")
                or (r.diff == "ELITE" and "|cffff4444Elite|r")
                or r.diff
            player:SendBroadcastMessage(string.format(
                "  %s |cffffcc00%s|r — queda |cffffffff%s|r",
                diffCol, r.name, FormatTimeMMSS(r.rem)))
            -- Max ~10 lineas clicables en gossip
            if i <= 10 then
                player:GossipMenuAddItem(0, string.format(
                    "%s (%s)", ShortLine(r.name, 40), FormatTimeMMSS(r.rem)), 0, 1)
            end
        end
        if #rows > 10 then
            player:SendBroadcastMessage(string.format(
                "|cffaaaaaa... y %d mas (mira el chat)|r", #rows - 10))
        end
    end

    player:SendBroadcastMessage("|cff00ccff====================================|r")
    player:GossipMenuAddItem(0, "Volver al menu", 0, 1)
    player:GossipSendMenu(1, go)
end

local function GossipShowQuestList(player, go)
    local guidStr = GuidKey(player)
    local list = BuildOfferList(player)
    GossipContext[guidStr] = { list = list }

    -- Aviso de misiones en CD (si hay)
    local onCd = {}
    local t = QuestListCD[guidStr]
    if t then
        local now = os.time()
        for qid, exp in pairs(t) do
            local rem = (exp or 0) - now
            if rem > 0 then
                local q = FindQuest(qid)
                local name = (q and q.name) or ("#" .. tostring(qid))
                onCd[#onCd+1] = string.format("%s (%s)", name, FormatTimeMMSS(rem))
            end
        end
    end
    if #onCd > 0 then
        player:SendBroadcastMessage("|cffff8800[BotGarrison]|r En cooldown de lista:")
        for i = 1, math.min(5, #onCd) do
            player:SendBroadcastMessage("  |cffaaaaaa- " .. onCd[i] .. "|r")
        end
        if #onCd > 5 then
            player:SendBroadcastMessage(string.format("  |cffaaaaaa... y %d mas|r", #onCd - 5))
        end
    end

    player:GossipClearMenu()
    if #list == 0 then
        player:SendBroadcastMessage("|cff00ccff[BotGarrison]|r No hay misiones disponibles (nivel o en cooldown de lista).")
        player:GossipMenuAddItem(0, "Volver al menú", 0, 1)
    else
        player:SendBroadcastMessage(string.format(
            "|cff00ccff[BotGarrison]|r Ofertas del tablon: |cffffffff%d|r (rotan; CD 15 min al completar).",
            #list))
        for i, q in ipairs(list) do
            local diff =
                (q.difficulty == "EASY" and "|cff1eff00Facil|r")
                or (q.difficulty == "NORMAL" and "|cffffffffNormal|r")
                or (q.difficulty == "HARD" and "|cffff8800Dificil|r")
                or (q.difficulty == "ELITE" and "|cffff4444Elite|r")
                or q.difficulty
            local label = string.format("%s |cffffcc00%s|r (%d min)",
                diff, q.name, math.ceil(q.duration / 60))
            player:GossipMenuAddItem(2, label, 0, 100 + i)
        end
        player:GossipMenuAddItem(0, "Volver al menú", 0, 1)
    end
    player:GossipSendMenu(1, go)
end

local function GossipShowQuestDetail(player, go, index)
    local ctx = GossipContext[GuidKey(player)]
    if not ctx or not ctx.list or not ctx.list[index] then
        GossipShowMain(player, go)
        return
    end
    local q = ctx.list[index]
    local bots = GetAltBots(player)
    local power, hasTank, hasHealer, botCount, _, undergeared, avgGs = CalculateGroupPower(player, bots)
    local chance = CalculateSuccessChance(power, q.difficulty, undergeared)
    local tanks, healers, dps = CountBotRoles(bots)
    local okReq, reqMsg = CheckQuestRequirements(q, bots)
    local lvl = player:GetLevel()
    local multCfg = CFG.GOLD_LEVEL_MULT or 0
    local mult = (multCfg > 0) and (multCfg * lvl) or 1
    local gLo = math.floor((q.goldMin or 50) * mult)
    local gHi = math.floor((q.goldMax or 100) * mult)

    local reqParts = {}
    if (q.minBots or 0) > 0 then reqParts[#reqParts+1] = (q.minBots or 0) .. " bots" end
    if (q.minTank or 0) > 0 then reqParts[#reqParts+1] = (q.minTank or 0) .. " tank" end
    if (q.minHealer or 0) > 0 then reqParts[#reqParts+1] = (q.minHealer or 0) .. " heal" end
    if (q.minDps or 0) > 0 then reqParts[#reqParts+1] = (q.minDps or 0) .. " dps" end
    local reqStr = (#reqParts > 0) and table.concat(reqParts, ", ") or "cualquiera"
    local itemFlavor = REWARD_ITEM_FLAVOR[q.difficulty] or "un objeto"
    local diffLabel = DIFF_LABEL[q.difficulty] or q.difficulty

    -- Detalle completo en chat (texto, no clicable)
    player:SendBroadcastMessage("|cff00ccff======== BotGarrison ========|r")
    player:SendBroadcastMessage("|cffffcc00" .. q.name .. "|r")
    if q.desc and q.desc ~= "" then
        player:SendBroadcastMessage("|cffaaaaaa" .. q.desc .. "|r")
    end
    player:SendBroadcastMessage(string.format(
        "Dificultad: %s | Duración: %d min | Éxito: |cff00ff00~%.0f%%|r",
        diffLabel, math.ceil((q.duration or 60) / 60), chance * 100))
    player:SendBroadcastMessage(string.format(
        "Recompensa: |cffffffff%s - %s|r y %s",
        FormatCopper(gLo), FormatCopper(gHi), itemFlavor))
    player:SendBroadcastMessage(string.format(
        "Requisitos: |cffffffff%s|r | Tu grupo: |cffffffff%d (T%d/H%d/D%d)|r | GS medio: |cffffffff%.0f|r",
        reqStr, botCount, tanks, healers, dps, avgGs or 0))
    if undergeared then
        player:SendBroadcastMessage("|cffff8800Equipo bajo del destacamento — éxito tope 40%.|r")
    end
    if not okReq then
        player:SendBroadcastMessage("|cffff4444" .. (reqMsg or "Requisitos no cumplidos.") .. "|r")
    end
    player:SendBroadcastMessage("|cff00ccff============================|r")

    -- Solo botones importantes
    player:GossipClearMenu()
    if okReq then
        player:GossipMenuAddItem(2, "|cff1eff00Enviar compañeros a esta misión|r", 0, 200 + index)
    end
    player:GossipMenuAddItem(0, "Volver a la lista", 0, 2)
    player:GossipMenuAddItem(0, "Volver al menú", 0, 1)
    player:GossipSendMenu(1, go)
end

local function OnGossipHello(event, player, go)
    GossipShowMain(player, go)
    return true
end

local function OnGossipSelect(event, player, go, sender, intid, code)
    if intid == 9 then
        player:GossipComplete()
        return true
    end

    if intid == 1 then
        GossipShowMain(player, go)
        return true
    end

    if intid == 2 then
        GossipShowQuestList(player, go)
        return true
    end

    if intid == 3 then
        CancelMission(player)
        player:GossipComplete()
        return true
    end

    -- Ver misiones en cooldown de lista
    if intid == 6 then
        GossipShowListCD(player, go)
        return true
    end

    -- Reclamar misión lista (estilo Garrison)
    if intid == 5 then
        ClaimMission(player)
        player:GossipComplete()
        return true
    end

    if intid >= 100 and intid < 200 then
        GossipShowQuestDetail(player, go, intid - 100)
        return true
    end

    if intid >= 200 and intid < 300 then
        local index = intid - 200
        local ctx = GossipContext[GuidKey(player)]
        if ctx and ctx.list and ctx.list[index] then
            StartMission(player, ctx.list[index])
        end
        player:GossipComplete()
        return true
    end

    player:GossipComplete()
    return true
end

RegisterGameObjectGossipEvent(GO_ENTRY, 1, OnGossipHello)
RegisterGameObjectGossipEvent(GO_ENTRY, 2, OnGossipSelect)

-- ============================================================
--  LOGIN — misiones offline
-- ============================================================

-- ============================================================
--  Anti-summon: bloquear comandos y re-aparcar si vuelven
-- ============================================================
local SUMMON_CMD_PATTERNS = {
    "summon", "follow", "come", "bot add", "bots add",
    "addclass", "teleport", "tele ", "come to me",
    "co ", "follow me", "attack my target", -- algunos usamos follow
}

local function MissionBotNameSet(mission)
    local set = {}
    if not mission then return set end
    if mission.botNames and mission.botNames ~= "" and mission.botNames ~= "Ninguno" then
        for name in string.gmatch(mission.botNames, "[^,]+") do
            name = name:match("^%s*(.-)%s*$")
            if name and name ~= "" then set[name:lower()] = true end
        end
    end
    return set
end

local function GetActiveMissionFor(player)
    if not player then return nil end
    local m = ActiveMissions[GuidKey(player)]
    if m and not m.cancelled then return m end
    return nil
end

local function ForceParkBot(player, bot)
    if not player or not bot then return end
    pcall(function()
        local mgr = GetMasterBotMgr(player)
        local name = bot:GetName()
        if mgr and mgr.HandlePlayerbotCommand and name then
            pcall(function() mgr:HandlePlayerbotCommand("bot " .. name .. " stay") end)
        end
        bot:Teleport(CFG.PARK_MAP or 13, CFG.PARK_X or 0, CFG.PARK_Y or 0, CFG.PARK_Z or 0, CFG.PARK_O or 0)
    end)
end

local function CommandLooksLikeSummon(msg)
    if not msg then return false end
    local m = msg:lower()
    -- quitar barra inicial de comandos
    m = m:gsub("^%.", ""):gsub("^/", "")
    for _, pat in ipairs(SUMMON_CMD_PATTERNS) do
        if m:find(pat, 1, true) then return true end
    end
    return false
end

--- Evento comando (si el core lo dispara). return false = bloquear
local function OnPlayerCommand(event, player, command)
    if not CFG.BLOCK_SUMMON_WHILE_MISSION then return end
    local mission = GetActiveMissionFor(player)
    if not mission or mission.ready then return end
    if not CommandLooksLikeSummon(command) then return end
    player:SendBroadcastMessage("|cffff8800[BotGarrison]|r Tus companeros estan de mision. No puedes llamarlos hasta reclamar el resultado en el mapa.")
    return false
end

--- Watchdog: si un bot de mision esta cerca del master o fuera del mapa park, lo devuelve
local function MissionBotWatchdog()
    if not CFG.BLOCK_SUMMON_WHILE_MISSION then return end
    local near = CFG.SUMMON_NEAR_YARDS or 80
    for guidStr, mission in pairs(ActiveMissions) do
        if mission and not mission.cancelled and not mission.ready then
            local player = nil
            if mission.masterGuid and GetPlayerByGUID then
                local ok, pl = pcall(function() return GetPlayerByGUID(mission.masterGuid) end)
                if ok then player = pl end
            end
            if player then
                local names = MissionBotNameSet(mission)
                if next(names) ~= nil then
                    local bots = {}
                    local group = player:GetGroup()
                    if group then
                        local members = group:GetMembers()
                        if members then
                            for _, mem in pairs(members) do
                                local okN, n = pcall(function() return mem:GetName() end)
                                if okN and n and names[n:lower()] then
                                    bots[#bots+1] = mem
                                end
                            end
                        end
                    end
                    local mgr = GetMasterBotMgr(player)
                    if mgr and mgr.GetPlayerBots then
                        local okList, list = pcall(function() return mgr:GetPlayerBots() end)
                        if okList and list then
                            for _, b in pairs(list) do
                                local okN, n = pcall(function() return b:GetName() end)
                                if okN and n and names[n:lower()] then
                                    local already = false
                                    for _, x in ipairs(bots) do
                                        if x == b then already = true break end
                                    end
                                    if not already then bots[#bots+1] = b end
                                end
                            end
                        end
                    end
                    local warned = false
                    for _, bot in ipairs(bots) do
                        local needPark = false
                        local okMap, bmap = pcall(function() return bot:GetMapId() end)
                        if okMap and bmap ~= (CFG.PARK_MAP or 13) then
                            needPark = true
                        end
                        if not needPark then
                            local okD, dist = pcall(function() return player:GetDistance(bot) end)
                            if okD and dist and dist < near then
                                needPark = true
                            end
                        end
                        if needPark then
                            ForceParkBot(player, bot)
                            if not warned then
                                player:SendBroadcastMessage("|cffff8800[BotGarrison]|r Un companero intento volver: sigue de mision. Reclama en el mapa cuando acabe.")
                                warned = true
                            end
                        end
                    end
                end
            end
        end
    end
end


local function OnPlayerLogin(event, player)
    local guidStr = GuidKey(player)

    -- CDs de lista de misiones (15 min por quest completada)
    LoadQuestListCDFromDB(player)

    -- Cargar misión desde BD si no está en memoria
    if not ActiveMissions[guidStr] then
        local m = LoadMissionFromDB(player)
        if m then ActiveMissions[guidStr] = m end
    end

    local cd = GetRemainingCooldown(guidStr)
    if cd > 0 then
        player:SendBroadcastMessage(string.format(
            "|cffff8800[BotGarrison]|r Cooldown activo: %d min %d s.",
            math.floor(cd/60), cd%60))
    end

    local mission = ActiveMissions[guidStr]
    if not mission or mission.cancelled then return end

    if os.time() >= mission.endTime then
        mission.ready = true
        player:SendBroadcastMessage(string.format(
            "|cff00ff00[BotGarrison]|r !! Mision lista: |cffffcc00%s|r - ve al tablon y reclama el resultado.",
            mission.questName or "?"))
    else
        local rem = mission.endTime - os.time()
        player:SendBroadcastMessage(string.format(
            "|cff00ccff[BotGarrison]|r Misión en curso: |cffffcc00%s|r — |cffffffff%s|r restantes.",
            mission.questName, FormatTimeMMSS(rem)))

        -- Reprogramar: al acabar queda lista (no se resuelve sola)
        local fullGuid = player:GetGUID()
        local capturedQuestId = mission.questId
        CreateLuaEvent(function()
            local m = ActiveMissions[guidStr]
            if not m or m.cancelled or m.questId ~= capturedQuestId then return end
            m.ready = true
            local p = GetPlayerByGUID(fullGuid)
            if p then
                p:SendBroadcastMessage("|cff00ff00[BotGarrison]|r !! Mision lista! Reclama en el tablon.")
            end
        end, rem * 1000, 1)
    end
end
RegisterPlayerEvent(3, OnPlayerLogin)

-- ============================================================
--  GM: .bg reload
-- ============================================================
local function OnChat(event, player, msg)
    if not player or not msg then return end

    -- GM reload
    if player:IsGM() and (msg == ".bg reload" or msg == ".botgarrison reload") then
        PoolsReady = false
        LoadAllItemPools()
        player:SendBroadcastMessage("|cff00ff00[BotGarrison]|r Pools recargados.")
        return false
    end

    -- Bloquear summon/follow mientras hay mision activa (no lista para reclamar)
    if CFG.BLOCK_SUMMON_WHILE_MISSION then
        local mission = GetActiveMissionFor(player)
        if mission and not mission.ready and CommandLooksLikeSummon(msg) then
            player:SendBroadcastMessage("|cffff8800[BotGarrison]|r Tus companeros estan de mision. No puedes llamarlos hasta reclamar el resultado en el mapa.")
            return false
        end
    end
end
RegisterPlayerEvent(18, OnChat)

-- Comandos tipo .bot / .playerbot (si el core emite ON_COMMAND)
pcall(function()
    RegisterPlayerEvent(42, OnPlayerCommand) -- PLAYER_EVENT_ON_COMMAND
end)

-- Watchdog re-park
if (CFG.MISSION_BOT_WATCHDOG_MS or 0) > 0 then
    CreateLuaEvent(function()
        pcall(MissionBotWatchdog)
    end, CFG.MISSION_BOT_WATCHDOG_MS, 0)
end

CreateLuaEvent(function() LoadAllItemPools() end, 3000, 1)

print("[BotGarrison] v0.7.7 cargado — anti-summon en mision")

-- ============================================================
--  BotGarrison_Herald.lua
--  Goblin 900101
--  - Frases periodicas (SAY + gesto hablar), solo si hay jugadores cerca
--  - Gossip: explicacion en el texto del NPC (npc_text 900101)
--    Solo boton "Entendido" (sin lineas de menu clicables de texto)
-- ============================================================

local NPC_ENTRY   = 900101
local NPC_TEXT_ID = 900101   -- npc_text.ID (world) -- debe existir en la BD
local INTERVAL_MS = 45000
local FIRST_MS    = 5000
local LANG        = 0
local HEAR_RANGE  = 40       -- solo habla si hay un jugador a menos de estas yardas (0 = siempre)

math.randomseed(os.time() + NPC_ENTRY)   -- que las frases no sigan siempre el mismo orden tras reiniciar

local LINES = {
    "Oye, tú! El mapa de misiones tiene trabajo fresco. Oro fácil si tus muchachos valen la pena.",
    "¿Compañeros aburridos en el banco? Mándalos de misión desde el mapa.",
    "Tablón de misiones, aquí al lado. No muerdo... mucho.",
    "Escuadrones listos, botín listo. Solo falta que alguien dé la orden.",
    "Si tus altbots están oxidados, una patrulla les viene de perlas.",
    "Mapa actualizado. Rutas peligrosas, recompensas jugosas.",
    "No soy un héroe, soy un intermediario. Tú pones los bots, el tablón pone el oro.",
    "¡Eh! No pases de largo. Hay misiones esperando junto al mapa.",
}

local lastLine = {}   -- [creatureGuidLow] = ultimo indice dicho

local function TalkGesture(creature)
    pcall(function()
        if creature.PerformEmote then creature:PerformEmote(1)
        elseif creature.HandleEmoteCommand then creature:HandleEmoteCommand(1)
        elseif creature.Emote then creature:Emote(1)
        end
    end)
end

local function PlayersNear(creature)
    if HEAR_RANGE <= 0 then return true end
    if not creature.GetPlayersInRange then return true end   -- API no disponible: habla igual
    local ok, list = pcall(function() return creature:GetPlayersInRange(HEAR_RANGE) end)
    if not ok or type(list) ~= "table" then return true end
    return #list > 0
end

local function Speak(creature)
    if not creature or #LINES < 1 then return end
    if not PlayersNear(creature) then return end
    local okG, g = pcall(function() return creature:GetGUIDLow() end)
    g = okG and g or 0
    local idx = math.random(1, #LINES)
    if #LINES > 1 and idx == lastLine[g] then idx = (idx % #LINES) + 1 end   -- no repetir la misma
    lastLine[g] = idx
    local text = LINES[idx]
    TalkGesture(creature)
    local ok = pcall(function() creature:SendUnitSay(text, LANG) end)
    if not ok then pcall(function() creature:Say(text, LANG) end) end
end

local function StartTalking(event, creature)
    if not creature or not creature.RegisterEvent then return end
    pcall(function() if creature.RemoveEvents then creature:RemoveEvents() end end)
    creature:RegisterEvent(function(_, _, _, cre) Speak(cre) end, FIRST_MS, 1)
    creature:RegisterEvent(function(_, _, _, cre) Speak(cre) end, INTERVAL_MS, 0)
end

-- 5 = CREATURE_EVENT_ON_SPAWN (tras .reload eluna hay que respawnear al NPC)
RegisterCreatureEvent(NPC_ENTRY, 5, StartTalking)

-- ===================== GOSSIP (texto en ventana, no chat) =====================
local function OnGossipHello(event, player, creature)
    if not player or not creature then return false end
    TalkGesture(creature)

    player:GossipClearMenu()
    -- Solo un boton de cierre; la explicacion va en npc_text
    player:GossipMenuAddItem(0, "Entendido.", 0, 9)
    -- GossipSendMenu(npc_text_id, sender)
    player:GossipSendMenu(NPC_TEXT_ID, creature)
    return true
end

local function OnGossipSelect(event, player, creature, sender, intid, code)
    player:GossipComplete()
    return true
end

RegisterCreatureGossipEvent(NPC_ENTRY, 1, OnGossipHello)
RegisterCreatureGossipEvent(NPC_ENTRY, 2, OnGossipSelect)

print("[BotGarrison] Herald cargado )

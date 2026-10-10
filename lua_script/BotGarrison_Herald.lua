-- ============================================================
--  BotGarrison_Herald.lua
--  Goblin 900101
--  - Frases periodicas (SAY + gesto hablar)
--  - Gossip: explicacion en el texto del NPC (npc_text 900101)
--    Solo boton "Entendido" (sin lineas de menu clicables de texto)
-- ============================================================

local NPC_ENTRY   = 900101
local NPC_TEXT_ID = 900101   -- npc_text.ID (world)
local INTERVAL_MS = 45000
local FIRST_MS    = 5000
local LANG        = 0

local LINES = {
    "Oye, tu! El mapa de misiones tiene trabajo fresco. Oro facil si tus muchachos valen la pena.",
    "Companeros aburridos en el banco? Mandalos de mision desde el mapa.",
    "Tablon de misiones, aqui al lado. No muerdo... mucho.",
    "Escuadrones listos, botin listo. Solo falta que alguien de la orden.",
    "Si tus altbots estan oxidados, una patrulla les viene de perlas.",
    "Mapa actualizado. Rutas peligrosas, recompensas jugosas.",
    "No soy un heroe, soy un intermediario. Tu pones los bots, el tablon pone el oro.",
    "Eh! No pases de largo. Hay misiones esperando junto al mapa.",
}

local function TalkGesture(creature)
    pcall(function()
        if creature.PerformEmote then creature:PerformEmote(1)
        elseif creature.HandleEmoteCommand then creature:HandleEmoteCommand(1)
        elseif creature.Emote then creature:Emote(1)
        end
    end)
end

local function Speak(creature)
    if not creature or #LINES < 1 then return end
    local text = LINES[math.random(1, #LINES)]
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

print("[BotGarrison] Herald cargado entry=" .. NPC_ENTRY .. " gossip npc_text=" .. NPC_TEXT_ID)

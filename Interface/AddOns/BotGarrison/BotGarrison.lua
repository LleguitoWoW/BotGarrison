-- ============================================================
--  BotGarrison Client (3.3.5) v1.5
--  Panel rediseñado + barra de progreso + minimapa parpadea al completar
-- ============================================================

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

local Handlers = AIO.AddHandlers("BotGarrison", {})

local UI = {}
UI.data = { active = false }
UI._rem = 0
UI._total = 0
UI._key = nil
UI._acc = 0
UI._blink = 0
UI._readyAlert = false
UI._dragging = false

local WHITE = "Interface\\Buttons\\WHITE8X8"

local function FormatTime(secs)
    secs = math.max(0, math.floor(secs or 0))
    local h = math.floor(secs / 3600)
    local m = math.floor((secs % 3600) / 60)
    local s = secs % 60
    if h > 0 then
        return string.format("%d:%02d:%02d", h, m, s)
    end
    return string.format("%02d:%02d", m, s)
end

local function SetReadyAlert(on)
    UI._readyAlert = on and true or false
    if not on then
        if UI.minimapIcon then UI.minimapIcon:SetVertexColor(1, 1, 1) end
        if UI.minimapGlow then UI.minimapGlow:Hide() end
    end
end

local function ToggleMain()
    if UI.main:IsShown() then
        UI.main:Hide()
    else
        UI.main:Show()
        AIO.Handle("BotGarrison", "requestStatus")
        if UI._readyAlert then
            SetReadyAlert(false)
        end
    end
end

-- Crea un panel oscuro con borde fino
local function MakePanel(parent, x, y, w, h)
    local p = CreateFrame("Frame", nil, parent)
    p:SetSize(w, h)
    p:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    p:SetBackdrop({
        bgFile   = WHITE,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    p:SetBackdropColor(0.04, 0.04, 0.06, 0.75)
    p:SetBackdropBorderColor(0.45, 0.38, 0.22, 1)
    return p
end

-- -------------------- FRAME PRINCIPAL --------------------
UI.main = CreateFrame("Frame", "BotGarrisonMainWindow", UIParent)
UI.main:SetSize(360, 470)
UI.main:SetPoint("CENTER", 0, 40)
UI.main:SetMovable(true)
UI.main:EnableMouse(true)
UI.main:SetClampedToScreen(true)
UI.main:RegisterForDrag("LeftButton")
UI.main:SetScript("OnDragStart", UI.main.StartMoving)
UI.main:SetScript("OnDragStop", UI.main.StopMovingOrSizing)
UI.main:Hide()
tinsert(UISpecialFrames, "BotGarrisonMainWindow")

UI.main:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
UI.main:SetBackdropColor(1, 1, 1, 1)

-- Cabecera
UI.header = UI.main:CreateTexture(nil, "ARTWORK")
UI.header:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
UI.header:SetSize(300, 64)
UI.header:SetPoint("TOP", 0, 14)

UI.titleText = UI.main:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.titleText:SetPoint("TOP", UI.header, "TOP", 0, -14)
UI.titleText:SetText("Misión de Compañeros")

UI.close = CreateFrame("Button", nil, UI.main, "UIPanelCloseButton")
UI.close:SetPoint("TOPRIGHT", -4, -4)
UI.close:SetScale(0.85)

-- Icono + estado
UI.iconFrame = CreateFrame("Frame", nil, UI.main)
UI.iconFrame:SetSize(46, 46)
UI.iconFrame:SetPoint("TOPLEFT", 24, -38)
UI.iconFrame:SetBackdrop({
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 2, right = 2, top = 2, bottom = 2 }
})
UI.iconFrame:SetBackdropBorderColor(0.8, 0.65, 0.2, 1)

UI.questIcon = UI.iconFrame:CreateTexture(nil, "ARTWORK")
UI.questIcon:SetPoint("TOPLEFT", 4, -4)
UI.questIcon:SetPoint("BOTTOMRIGHT", -4, 4)
UI.questIcon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")
UI.questIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

UI.status = UI.main:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.status:SetPoint("LEFT", UI.iconFrame, "RIGHT", 12, 0)
UI.status:SetWidth(250)
UI.status:SetJustifyH("LEFT")
UI.status:SetText("|cff888888Sin misión activa|r")

-- Tarjeta principal: nombre, dificultad, tiempo y progreso
UI.card = MakePanel(UI.main, 18, -94, 324, 124)

UI.name = UI.card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UI.name:SetPoint("TOPLEFT", 12, -10)
UI.name:SetWidth(300)
UI.name:SetJustifyH("LEFT")
UI.name:SetText("")

UI.diff = UI.card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.diff:SetPoint("TOPLEFT", 12, -32)
UI.diff:SetWidth(150)
UI.diff:SetJustifyH("LEFT")
UI.diff:SetText("")

UI.chance = UI.card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.chance:SetPoint("TOPRIGHT", -12, -32)
UI.chance:SetWidth(150)
UI.chance:SetJustifyH("RIGHT")
UI.chance:SetText("")

UI.timer = UI.card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
UI.timer:SetPoint("TOP", 0, -52)
UI.timer:SetWidth(300)
UI.timer:SetJustifyH("CENTER")
UI.timer:SetText("")

UI.barBG = UI.card:CreateTexture(nil, "BACKGROUND")
UI.barBG:SetTexture(WHITE)
UI.barBG:SetVertexColor(0, 0, 0, 0.7)
UI.barBG:SetSize(300, 16)
UI.barBG:SetPoint("BOTTOM", 0, 12)

UI.bar = CreateFrame("StatusBar", nil, UI.card)
UI.bar:SetSize(298, 14)
UI.bar:SetPoint("CENTER", UI.barBG, "CENTER", 0, 0)
UI.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
UI.bar:SetMinMaxValues(0, 1)
UI.bar:SetValue(0)
UI.bar:SetStatusBarColor(1, 0.75, 0.1)

UI.barText = UI.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.barText:SetPoint("CENTER", 0, 0)
UI.barText:SetText("")

-- Descripción
UI.descPanel = MakePanel(UI.main, 18, -226, 324, 66)

UI.desc = UI.descPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.desc:SetPoint("TOPLEFT", 12, -10)
UI.desc:SetWidth(300)
UI.desc:SetHeight(48)
UI.desc:SetJustifyH("LEFT")
UI.desc:SetJustifyV("TOP")
UI.desc:SetText("")

-- Destacamento y recompensa
UI.infoPanel = MakePanel(UI.main, 18, -300, 324, 112)

UI.botsLabel = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.botsLabel:SetPoint("TOPLEFT", 12, -10)
UI.botsLabel:SetText("Destacamento")

UI.bots = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.bots:SetPoint("TOPLEFT", 12, -27)
UI.bots:SetWidth(300)
UI.bots:SetJustifyH("LEFT")
UI.bots:SetText("")

UI.sep = UI.infoPanel:CreateTexture(nil, "ARTWORK")
UI.sep:SetTexture(WHITE)
UI.sep:SetVertexColor(0.5, 0.4, 0.25, 0.5)
UI.sep:SetHeight(1)
UI.sep:SetPoint("TOPLEFT", 12, -58)
UI.sep:SetPoint("TOPRIGHT", -12, -58)

UI.rewLabel = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.rewLabel:SetPoint("TOPLEFT", 12, -66)
UI.rewLabel:SetText("Recompensa estimada")

UI.rew = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.rew:SetPoint("TOPLEFT", 12, -83)
UI.rew:SetWidth(300)
UI.rew:SetJustifyH("LEFT")
UI.rew:SetText("")

-- Botones
UI.refreshBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.refreshBtn:SetSize(120, 26)
UI.refreshBtn:SetPoint("BOTTOMLEFT", 28, 22)
UI.refreshBtn:SetText("Actualizar")
UI.refreshBtn:SetScript("OnClick", function()
    AIO.Handle("BotGarrison", "requestStatus")
end)

UI.claimBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.claimBtn:SetSize(120, 26)
UI.claimBtn:SetPoint("BOTTOMRIGHT", -28, 22)
UI.claimBtn:SetText("Reclamar")
UI.claimBtn:Hide()
UI.claimBtn:SetScript("OnClick", function()
    AIO.Handle("BotGarrison", "claimMission")
    SetReadyAlert(false)
end)

-- -------------------- MINIMAPA --------------------
UI.minimap = CreateFrame("Button", "BotGarrisonMinimapButton", Minimap)
UI.minimap:SetSize(32, 32)
UI.minimap:SetFrameStrata("MEDIUM")
UI.minimap:SetFrameLevel(8)
UI.minimap:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
UI.minimap:RegisterForClicks("AnyUp")
UI.minimap:RegisterForDrag("LeftButton")
UI.minimap:SetMovable(true)

UI.minimapIcon = UI.minimap:CreateTexture(nil, "BACKGROUND")
UI.minimapIcon:SetSize(20, 20)
UI.minimapIcon:SetPoint("CENTER", 0, 1)
UI.minimapIcon:SetTexture("Interface\\Icons\\INV_Misc_Map_01")

UI.minimapGlow = UI.minimap:CreateTexture(nil, "OVERLAY")
UI.minimapGlow:SetSize(28, 28)
UI.minimapGlow:SetPoint("CENTER", 0, 1)
UI.minimapGlow:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
UI.minimapGlow:SetBlendMode("ADD")
UI.minimapGlow:Hide()

UI.minimapBorder = UI.minimap:CreateTexture(nil, "OVERLAY")
UI.minimapBorder:SetSize(52, 52)
UI.minimapBorder:SetPoint("TOPLEFT", 0, 0)
UI.minimapBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local minimapAngle = 220
local function UpdateMinimapPos()
    local a = math.rad(minimapAngle)
    UI.minimap:ClearAllPoints()
    UI.minimap:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * 80, math.sin(a) * 80)
end
UpdateMinimapPos()

UI.minimap:SetScript("OnDragStart", function() UI._dragging = true end)
UI.minimap:SetScript("OnDragStop", function() UI._dragging = false end)
UI.minimap:SetScript("OnClick", function(_, button)
    if button == "LeftButton" then ToggleMain() end
end)
UI.minimap:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("BotGarrison", 1, 0.85, 0)
    GameTooltip:AddLine("Click: abrir panel", 1, 1, 1)
    if UI._readyAlert then
        GameTooltip:AddLine("¡Misión lista!", 0, 1, 0)
    elseif UI.data and UI.data.active then
        GameTooltip:AddLine(UI.data.name or "?", 0.9, 0.9, 0.5)
        GameTooltip:AddLine("En curso: " .. FormatTime(UI._rem or 0), 1, 0.8, 0.2)
    end
    GameTooltip:Show()
end)
UI.minimap:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Un solo OnUpdate: gestiona arrastre y parpadeo (antes el arrastre pisaba el parpadeo)
UI.minimap:SetScript("OnUpdate", function(self, elapsed)
    if UI._dragging then
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        minimapAngle = math.deg(math.atan2(cy - my, cx - mx))
        UpdateMinimapPos()
    end

    if not UI._readyAlert then return end
    UI._blink = (UI._blink or 0) + elapsed
    local pulse = (math.sin(UI._blink * 6) + 1) * 0.5
    UI.minimapIcon:SetVertexColor(0.3, 1, 0.3)
    UI.minimapGlow:Show()
    UI.minimapGlow:SetAlpha(0.25 + pulse * 0.75)
end)

-- -------------------- LOGICA --------------------
local function UpdateProgress()
    local d = UI.data
    if not d or not d.active then
        UI.bar:SetValue(0)
        UI.barText:SetText("")
        return
    end
    if d.ready then
        UI.bar:SetStatusBarColor(0.1, 0.85, 0.1)
        UI.bar:SetValue(1)
        UI.barText:SetText("100%")
        return
    end
    local total = UI._total
    local frac = 0
    if total and total > 0 then
        frac = 1 - ((UI._rem or 0) / total)
    end
    frac = math.max(0, math.min(1, frac))
    UI.bar:SetStatusBarColor(1, 0.75, 0.1)
    UI.bar:SetValue(frac)
    UI.barText:SetText(string.format("%d%%", frac * 100))
end

local function ApplyData(data)
    UI.data = data or { active = false }

    if not data or not data.active then
        UI.status:SetText("|cff888888Sin misión activa|r")
        UI.name:SetText("")
        UI.diff:SetText("")
        UI.timer:SetText("")
        UI.desc:SetText("|cff999999Usa el mapa de misiones en la ciudad para enviar a tus bots.\n\n|cffffffff/bg|r|cff999999 abre este panel.|r")
        UI.bots:SetText("")
        UI.rew:SetText("")
        UI.chance:SetText("")
        UI.claimBtn:Hide()
        UI._rem = 0
        UI._total = 0
        UI._key = nil
        UpdateProgress()
        SetReadyAlert(false)
        return
    end

    -- Duración total (para la barra): usa el dato del servidor si existe
    local key = data.name or "?"
    local serverTotal = data.total or data.duration or data.totalTime
    if serverTotal and serverTotal > 0 then
        UI._total = serverTotal
    elseif UI._key ~= key or (data.remaining and data.remaining > (UI._total or 0)) then
        UI._total = data.remaining or 0
    end
    UI._key = key

    UI.name:SetText("|cffffd100" .. (data.name or "?") .. "|r")
    UI.diff:SetText(data.diffLabel or data.difficulty or "")
    UI.desc:SetText((data.desc and data.desc ~= "") and ("|cffdddddd" .. data.desc .. "|r") or "")
    UI.bots:SetText("|cffffffff" .. (data.bots or "—") .. "|r")
    UI.rew:SetText(string.format("|cffffffff%s - %s|r\n|cffaaaaaa%s|r",
        data.goldMinStr or "?", data.goldMaxStr or "?", data.itemFlavor or ""))
    UI.chance:SetText(data.chance and string.format("|cffaaaaaaÉxito:|r |cff00ff00~%.0f%%|r", data.chance * 100) or "")

    if data.remaining then UI._rem = data.remaining end

    if data.ready then
        UI.status:SetText("|cff00ff00Misión lista — puedes reclamar|r")
        UI.timer:SetText("|cff00ff00COMPLETADA|r")
        UI.claimBtn:Show()
        SetReadyAlert(true)
    else
        UI.status:SetText("|cffffcc00Misión en curso|r")
        UI.timer:SetText("|cffffffff" .. FormatTime(UI._rem) .. "|r")
        UI.claimBtn:Hide()
        SetReadyAlert(false)
    end
    UpdateProgress()
end

UI.main:SetScript("OnUpdate", function(self, elapsed)
    if not self:IsShown() then return end
    if not UI.data or not UI.data.active or UI.data.ready then return end
    UI._acc = (UI._acc or 0) + elapsed
    if UI._acc < 0.25 then return end
    local dt = UI._acc
    UI._acc = 0
    UI._rem = math.max(0, (UI._rem or 0) - dt)
    if UI._rem <= 0 then
        UI.status:SetText("|cff00ff00Misión lista — puedes reclamar|r")
        UI.timer:SetText("|cff00ff00COMPLETADA|r")
        UI.claimBtn:Show()
        UI.data.ready = true
        SetReadyAlert(true)
    else
        UI.timer:SetText("|cffffffff" .. FormatTime(UI._rem) .. "|r")
    end
    UpdateProgress()
end)

function Handlers.UpdateStatus(player, data)
    if data and data.active and data.remaining then UI._rem = data.remaining end
    ApplyData(data)
end

SLASH_BOTGARRISON1 = "/bg"
SLASH_BOTGARRISON2 = "/botgarrison"
SLASH_BOTGARRISON3 = "/companeros"
SlashCmdList["BOTGARRISON"] = ToggleMain

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function()
    AIO.Handle("BotGarrison", "requestStatus")
end)

DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[BotGarrison]|r v1.5 |cffffffff/bg|r")

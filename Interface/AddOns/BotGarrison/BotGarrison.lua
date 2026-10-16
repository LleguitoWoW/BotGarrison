-- ============================================================
--  BotGarrison Client (3.3.5) v2.1
--  Tablón de misiones en panel propio + misión en curso + minimapa
-- ============================================================

local AIO = AIO or require("AIO")
if AIO.AddAddon() then return end

local Handlers = AIO.AddHandlers("BotGarrison", {})

local UI = {}
UI.data = { active = false }
UI.board = nil          -- ultimo BoardData recibido
UI.sel = nil            -- oferta seleccionada
UI.mode = "idle"        -- "mission" | "board" | "idle"
UI._rem = 0
UI._total = 0
UI._key = nil
UI._cd = 0
UI._acc = 0
UI._blink = 0
UI._readyAlert = false
UI._dragging = false

local WHITE = "Interface\\Buttons\\WHITE8X8"
local WIN_W, WIN_H = 420, 520
local PANEL_W = 384
local MAX_ROWS = 8
local ROW_H = 21

local DIFFCOL  = { EASY = "|cff1eff00", NORMAL = "|cffffffff", HARD = "|cffff8800", ELITE = "|cffff4444" }
local DIFFNAME = { EASY = "Fácil", NORMAL = "Normal", HARD = "Difícil", ELITE = "Élite" }

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

local function ChanceColor(c)
    c = c or 0
    if c >= 0.7 then return "|cff00ff00" end
    if c >= 0.4 then return "|cffffcc00" end
    return "|cffff5555"
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
        AIO.Handle("BotGarrison", "requestBoard")   -- trae mision + tablon (si estas cerca)
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
UI.main:SetSize(WIN_W, WIN_H)
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

-- Icono + estado (comun a todas las vistas)
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
UI.status:SetWidth(215)
UI.status:SetJustifyH("LEFT")
UI.status:SetText("|cff888888Sin misión activa|r")

-- ====================== VISTA: SIN MISION ======================
UI.idlePanel = MakePanel(UI.main, 18, -94, PANEL_W, 350)

UI.idleText = UI.idlePanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.idleText:SetPoint("TOPLEFT", 20, -30)
UI.idleText:SetWidth(PANEL_W - 40)
UI.idleText:SetJustifyH("CENTER")
UI.idleText:SetText("|cffffd100No tienes ninguna misión en curso|r\n\n" ..
    "|cffbbbbbbAcércate al |r|cffffffffTablón de Misiones|r|cffbbbbbb y púlsalo para elegir una misión para tus compañeros.|r\n\n" ..
    "|cff888888/bg abre este panel.|r")

-- ====================== VISTA: MISION EN CURSO ======================
UI.card = MakePanel(UI.main, 18, -94, PANEL_W, 124)

UI.name = UI.card:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UI.name:SetPoint("TOPLEFT", 12, -10)
UI.name:SetWidth(PANEL_W - 24)
UI.name:SetJustifyH("LEFT")
UI.name:SetText("")

UI.diff = UI.card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.diff:SetPoint("TOPLEFT", 12, -32)
UI.diff:SetWidth(170)
UI.diff:SetJustifyH("LEFT")
UI.diff:SetText("")

UI.chance = UI.card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.chance:SetPoint("TOPRIGHT", -12, -32)
UI.chance:SetWidth(170)
UI.chance:SetJustifyH("RIGHT")
UI.chance:SetText("")

UI.timer = UI.card:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
UI.timer:SetPoint("TOP", 0, -52)
UI.timer:SetWidth(PANEL_W - 24)
UI.timer:SetJustifyH("CENTER")
UI.timer:SetText("")

UI.barBG = UI.card:CreateTexture(nil, "BACKGROUND")
UI.barBG:SetTexture(WHITE)
UI.barBG:SetVertexColor(0, 0, 0, 0.7)
UI.barBG:SetSize(PANEL_W - 24, 16)
UI.barBG:SetPoint("BOTTOM", 0, 12)

UI.bar = CreateFrame("StatusBar", nil, UI.card)
UI.bar:SetSize(PANEL_W - 26, 14)
UI.bar:SetPoint("CENTER", UI.barBG, "CENTER", 0, 0)
UI.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
UI.bar:SetMinMaxValues(0, 1)
UI.bar:SetValue(0)
UI.bar:SetStatusBarColor(1, 0.75, 0.1)

UI.barText = UI.bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.barText:SetPoint("CENTER", 0, 0)
UI.barText:SetText("")

UI.descPanel = MakePanel(UI.main, 18, -226, PANEL_W, 80)

UI.desc = UI.descPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.desc:SetPoint("TOPLEFT", 12, -10)
UI.desc:SetWidth(PANEL_W - 24)
UI.desc:SetHeight(60)
UI.desc:SetJustifyH("LEFT")
UI.desc:SetJustifyV("TOP")
UI.desc:SetText("")

UI.infoPanel = MakePanel(UI.main, 18, -314, PANEL_W, 130)

UI.botsLabel = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.botsLabel:SetPoint("TOPLEFT", 12, -10)
UI.botsLabel:SetText("Destacamento")

UI.bots = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.bots:SetPoint("TOPLEFT", 12, -27)
UI.bots:SetWidth(PANEL_W - 24)
UI.bots:SetJustifyH("LEFT")
UI.bots:SetText("")

UI.sep = UI.infoPanel:CreateTexture(nil, "ARTWORK")
UI.sep:SetTexture(WHITE)
UI.sep:SetVertexColor(0.5, 0.4, 0.25, 0.5)
UI.sep:SetHeight(1)
UI.sep:SetPoint("TOPLEFT", 12, -64)
UI.sep:SetPoint("TOPRIGHT", -12, -64)

UI.rewLabel = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.rewLabel:SetPoint("TOPLEFT", 12, -72)
UI.rewLabel:SetText("Recompensa estimada")

UI.rew = UI.infoPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.rew:SetPoint("TOPLEFT", 12, -89)
UI.rew:SetWidth(PANEL_W - 24)
UI.rew:SetJustifyH("LEFT")
UI.rew:SetText("")

-- ====================== VISTA: TABLON ======================
-- Resumen del destacamento
UI.groupPanel = MakePanel(UI.main, 18, -94, PANEL_W, 60)

UI.g1 = UI.groupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.g1:SetPoint("TOPLEFT", 12, -8)
UI.g1:SetWidth(PANEL_W - 24)
UI.g1:SetJustifyH("LEFT")
UI.g1:SetText("")

UI.g2 = UI.groupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.g2:SetPoint("TOPLEFT", 12, -26)
UI.g2:SetWidth(PANEL_W - 24)
UI.g2:SetJustifyH("LEFT")
UI.g2:SetText("")

UI.g3 = UI.groupPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.g3:SetPoint("TOPLEFT", 12, -42)
UI.g3:SetWidth(PANEL_W - 24)
UI.g3:SetJustifyH("LEFT")
UI.g3:SetText("")

-- Lista de ofertas
UI.listPanel = MakePanel(UI.main, 18, -160, PANEL_W, 178)

UI.emptyText = UI.listPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.emptyText:SetPoint("CENTER", 0, 0)
UI.emptyText:SetWidth(PANEL_W - 60)
UI.emptyText:SetJustifyH("CENTER")
local EMPTY_TXT = "|cff999999No hay misiones disponibles ahora mismo.\nVuelve cuando termine algún cooldown.|r"
local LOADING_TXT = "|cff999999Actualizando misiones...|r"
UI.emptyText:SetText(EMPTY_TXT)
UI.emptyText:Hide()

UI.rows = {}
local function MakeRow(i)
    local b = CreateFrame("Button", nil, UI.listPanel)
    b:SetSize(PANEL_W - 16, ROW_H - 1)
    b:SetPoint("TOPLEFT", 8, -7 - (i - 1) * ROW_H)
    b:SetHighlightTexture(WHITE)
    local hl = b:GetHighlightTexture()
    if hl then hl:SetVertexColor(1, 1, 1, 0.10) end

    b.sel = b:CreateTexture(nil, "BACKGROUND")
    b.sel:SetAllPoints(b)
    b.sel:SetTexture(WHITE)
    b.sel:SetVertexColor(1, 0.8, 0.2, 0.22)
    b.sel:Hide()

    b.diffFS = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.diffFS:SetPoint("LEFT", 6, 0)
    b.diffFS:SetWidth(46)
    b.diffFS:SetJustifyH("LEFT")

    b.nameFS = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.nameFS:SetPoint("LEFT", 56, 0)
    b.nameFS:SetWidth(210)
    b.nameFS:SetJustifyH("LEFT")

    b.infoFS = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.infoFS:SetPoint("RIGHT", -6, 0)
    b.infoFS:SetWidth(90)
    b.infoFS:SetJustifyH("RIGHT")

    b.index = i
    b:SetScript("OnClick", function(self)
        UI.sel = self.index
        UI.UpdateSelection()
        UI.UpdateDetail()
        UI.UpdateSendButton()
    end)
    b:Hide()
    return b
end
for i = 1, MAX_ROWS do
    UI.rows[i] = MakeRow(i)
end

-- Detalle de la oferta seleccionada
UI.detailPanel = MakePanel(UI.main, 18, -344, PANEL_W, 124)

UI.dName = UI.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
UI.dName:SetPoint("TOPLEFT", 12, -8)
UI.dName:SetWidth(PANEL_W - 24)
UI.dName:SetJustifyH("LEFT")

UI.dMeta = UI.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.dMeta:SetPoint("TOPLEFT", 12, -29)
UI.dMeta:SetWidth(PANEL_W - 24)
UI.dMeta:SetJustifyH("LEFT")

UI.dDesc = UI.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.dDesc:SetPoint("TOPLEFT", 12, -45)
UI.dDesc:SetWidth(PANEL_W - 24)
UI.dDesc:SetHeight(28)
UI.dDesc:SetJustifyH("LEFT")
UI.dDesc:SetJustifyV("TOP")

UI.dReward = UI.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.dReward:SetPoint("TOPLEFT", 12, -76)
UI.dReward:SetWidth(PANEL_W - 24)
UI.dReward:SetHeight(24)
UI.dReward:SetJustifyH("LEFT")
UI.dReward:SetJustifyV("TOP")

UI.dReq = UI.detailPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.dReq:SetPoint("TOPLEFT", 12, -100)
UI.dReq:SetWidth(PANEL_W - 24)
UI.dReq:SetHeight(20)
UI.dReq:SetJustifyH("LEFT")
UI.dReq:SetJustifyV("TOP")

-- ====================== BOTONES ======================
UI.refreshBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.refreshBtn:SetSize(84, 20)
UI.refreshBtn:SetPoint("TOPRIGHT", UI.main, "TOPRIGHT", -34, -40)
UI.refreshBtn:SetText("Actualizar")
UI.refreshBtn:SetScript("OnClick", function()
    AIO.Handle("BotGarrison", "requestBoard")
end)

UI.claimBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.claimBtn:SetSize(130, 26)
UI.claimBtn:SetPoint("BOTTOMRIGHT", -28, 22)
UI.claimBtn:SetText("Reclamar")
UI.claimBtn:Hide()
UI.claimBtn:SetScript("OnClick", function()
    UI.emptyText:SetText(LOADING_TXT)
    AIO.Handle("BotGarrison", "claimMission")
    SetReadyAlert(false)
end)

UI.sendBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.sendBtn:SetSize(160, 26)
UI.sendBtn:SetPoint("BOTTOMRIGHT", -28, 22)
UI.sendBtn:SetText("Enviar compañeros")
UI.sendBtn:Hide()
UI.sendBtn:SetScript("OnClick", function()
    if UI.sel then
        UI.sendBtn:Disable()  -- evita doble clic; el servidor responde con datos nuevos
        AIO.Handle("BotGarrison", "startMission", UI.sel)
    end
end)

StaticPopupDialogs["BOTGARRISON_CANCEL"] = {
    text = "¿Cancelar la misión actual?\n\nLos compañeros vuelven sin recompensa.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        UI.emptyText:SetText(LOADING_TXT)
        AIO.Handle("BotGarrison", "cancelMission")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

UI.cancelBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.cancelBtn:SetSize(120, 26)
UI.cancelBtn:SetPoint("BOTTOMLEFT", 28, 22)
UI.cancelBtn:SetText("Cancelar")
UI.cancelBtn:Hide()
UI.cancelBtn:SetScript("OnClick", function()
    StaticPopup_Show("BOTGARRISON_CANCEL")
end)

UI.cdBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.cdBtn:SetSize(140, 26)
UI.cdBtn:SetPoint("BOTTOMLEFT", 28, 22)
UI.cdBtn:SetText("Bloqueadas")
UI.cdBtn:Hide()
UI.cdBtn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Misiones en cooldown", 1, 0.85, 0)
    local list = UI.board and UI.board.listCD
    local elapsed = GetTime() - (UI._boardTime or GetTime())
    local shown = 0
    if list then
        for _, r in ipairs(list) do
            local rem = (r.rem or 0) - elapsed
            if rem > 0 then
                shown = shown + 1
                GameTooltip:AddDoubleLine((DIFFCOL[r.diff] or "|cffffffff") .. (r.name or "?") .. "|r",
                    FormatTime(rem), 1, 1, 1, 1, 0.8, 0.2)
            end
        end
    end
    if shown == 0 then
        GameTooltip:AddLine("Ninguna", 0.7, 0.7, 0.7)
    else
        GameTooltip:AddLine("Vuelven al tablón al acabar el tiempo.", 0.6, 0.6, 0.6)
    end
    GameTooltip:Show()
end)
UI.cdBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)


-- ====================== MI DIARIO ======================
-- Registro de misiones. Se guarda en el CLIENTE (SavedVariablesPerCharacter), no en la BD
-- del servidor: el servidor solo manda cada resultado al resolverse la mision.
local DIARY_MAX   = 200
local DIARY_W     = 380
local DIARY_H     = 520
local DIARY_ROW_H = 66
local QUALCOL = { [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00", [3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000" }

local function DiaryDB()
    if type(BotGarrisonDiary) ~= "table" then BotGarrisonDiary = {} end
    if type(BotGarrisonDiary.entries) ~= "table" then BotGarrisonDiary.entries = {} end
    return BotGarrisonDiary
end

local function MoneyText(copper)
    copper = math.floor(copper or 0)
    local g = math.floor(copper / 10000)
    local s = math.floor((copper % 10000) / 100)
    local b = copper % 100
    local t = {}
    if g > 0 then t[#t + 1] = g .. "|cffffd700g|r" end
    if s > 0 then t[#t + 1] = s .. "|cffc7c7cfs|r" end
    if b > 0 or #t == 0 then t[#t + 1] = b .. "|cffeda55fc|r" end
    return table.concat(t, " ")
end

UI.diary = CreateFrame("Frame", "BotGarrisonDiaryWindow", UIParent)
UI.diary:SetSize(DIARY_W, DIARY_H)
UI.diary:SetPoint("TOPLEFT", UI.main, "TOPRIGHT", -2, 0)
UI.diary:SetMovable(true)
UI.diary:EnableMouse(true)
UI.diary:SetClampedToScreen(true)
UI.diary:RegisterForDrag("LeftButton")
UI.diary:SetScript("OnDragStart", UI.diary.StartMoving)
UI.diary:SetScript("OnDragStop", UI.diary.StopMovingOrSizing)
UI.diary:Hide()
tinsert(UISpecialFrames, "BotGarrisonDiaryWindow")
UI.diary:SetBackdrop({
    bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 }
})
UI.diary:SetBackdropColor(1, 1, 1, 1)

UI.diaryHeader = UI.diary:CreateTexture(nil, "ARTWORK")
UI.diaryHeader:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header")
UI.diaryHeader:SetSize(240, 64)
UI.diaryHeader:SetPoint("TOP", 0, 14)

UI.diaryTitle = UI.diary:CreateFontString(nil, "OVERLAY", "GameFontNormal")
UI.diaryTitle:SetPoint("TOP", UI.diaryHeader, "TOP", 0, -14)
UI.diaryTitle:SetText("Mi Diario")

UI.diaryClose = CreateFrame("Button", nil, UI.diary, "UIPanelCloseButton")
UI.diaryClose:SetPoint("TOPRIGHT", -4, -4)
UI.diaryClose:SetScale(0.85)

-- Resumen
UI.diarySummaryPanel = MakePanel(UI.diary, 18, -34, DIARY_W - 36, 56)
UI.diarySummary1 = UI.diarySummaryPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.diarySummary1:SetPoint("TOPLEFT", 12, -9)
UI.diarySummary1:SetWidth(DIARY_W - 60)
UI.diarySummary1:SetJustifyH("LEFT")
UI.diarySummary2 = UI.diarySummaryPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
UI.diarySummary2:SetPoint("TOPLEFT", 12, -30)
UI.diarySummary2:SetWidth(DIARY_W - 60)
UI.diarySummary2:SetJustifyH("LEFT")

-- Lista con scroll
UI.diaryScroll = CreateFrame("ScrollFrame", "BotGarrisonDiaryScroll", UI.diary, "UIPanelScrollFrameTemplate")
UI.diaryScroll:SetPoint("TOPLEFT", UI.diary, "TOPLEFT", 20, -98)
UI.diaryScroll:SetPoint("BOTTOMRIGHT", UI.diary, "BOTTOMRIGHT", -38, 60)
UI.diaryChild = CreateFrame("Frame", nil, UI.diaryScroll)
UI.diaryChild:SetSize(DIARY_W - 62, 1)
UI.diaryScroll:SetScrollChild(UI.diaryChild)

UI.diaryEmpty = UI.diary:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
UI.diaryEmpty:SetPoint("CENTER", UI.diary, "CENTER", 0, 10)
UI.diaryEmpty:SetWidth(DIARY_W - 80)
UI.diaryEmpty:SetJustifyH("CENTER")
UI.diaryEmpty:SetText("|cff999999Aún no hay misiones registradas.\nAquí aparecerán las que reclames.|r")
UI.diaryEmpty:Hide()

UI.diaryRows = {}
local function GetDiaryRow(i)
    local r = UI.diaryRows[i]
    if r then return r end
    r = CreateFrame("Frame", nil, UI.diaryChild)
    r:SetSize(DIARY_W - 62, DIARY_ROW_H - 4)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * DIARY_ROW_H)
    r:SetBackdrop({
        bgFile   = WHITE,
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 10,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    r:SetBackdropColor(0.04, 0.04, 0.06, 0.75)

    r.l1 = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    r.l1:SetPoint("TOPLEFT", 9, -7)
    r.l1:SetWidth(190)
    r.l1:SetJustifyH("LEFT")

    r.date = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.date:SetPoint("TOPRIGHT", -9, -8)
    r.date:SetWidth(90)
    r.date:SetJustifyH("RIGHT")

    r.l2 = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.l2:SetPoint("TOPLEFT", 9, -23)
    r.l2:SetWidth(DIARY_W - 84)
    r.l2:SetJustifyH("LEFT")

    r.l3 = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.l3:SetPoint("TOPLEFT", 9, -36)
    r.l3:SetWidth(DIARY_W - 84)
    r.l3:SetJustifyH("LEFT")

    r.l4 = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.l4:SetPoint("TOPLEFT", 9, -48)
    r.l4:SetWidth(DIARY_W - 84)
    r.l4:SetJustifyH("LEFT")

    UI.diaryRows[i] = r
    return r
end

local function RefreshDiary()
    local entries = DiaryDB().entries
    local n = #entries
    local okN, failN, gold = 0, 0, 0

    for i = 1, n do
        local e = entries[i]
        local r = GetDiaryRow(i)
        if e.ok then
            okN = okN + 1
            gold = gold + (e.gold or 0)
            r:SetBackdropBorderColor(0.2, 0.65, 0.25, 1)
        else
            failN = failN + 1
            r:SetBackdropBorderColor(0.7, 0.2, 0.2, 1)
        end
        r.l1:SetText("|cffffd100" .. (e.name or "?") .. "|r")
        r.date:SetText("|cffaaaaaa" .. (e.t and date("%d/%m %H:%M", e.t) or "") .. "|r")
        r.l2:SetText((DIFFCOL[e.diff] or "|cffffffff") .. (DIFFNAME[e.diff] or e.diff or "") ..
            "|r  |cff888888·|r  |cffaaaaaaGrupo:|r |cffffffff" .. ((e.bots and e.bots ~= "") and e.bots or "—") .. "|r")
        if e.ok then
            r.l3:SetText("|cff00ff00Éxito|r  |cff888888·|r  |cffaaaaaaOro:|r " .. MoneyText(e.gold))
            if e.itemName then
                r.l4:SetText("|cffaaaaaaBotín:|r " .. (QUALCOL[e.quality or 1] or "|cffffffff") .. "[" .. e.itemName .. "]|r")
            else
                r.l4:SetText("")
            end
        else
            r.l3:SetText("|cffff4444Misión fallida|r")
            r.l4:SetText("|cff888888Sin botín|r")
        end
        r:Show()
    end
    for i = n + 1, #UI.diaryRows do UI.diaryRows[i]:Hide() end

    UI.diaryChild:SetHeight(math.max(1, n * DIARY_ROW_H))
    if n == 0 then UI.diaryEmpty:Show() else UI.diaryEmpty:Hide() end

    UI.diarySummary1:SetText(string.format("|cffffffff%d|r misiones   |cff00ff00%d éxitos|r   |cffff4444%d fallidas|r", n, okN, failN))
    UI.diarySummary2:SetText(string.format("|cffaaaaaaÉxito:|r |cffffffff%s|r   |cffaaaaaaOro ganado:|r %s",
        n > 0 and string.format("%d%%", math.floor(okN * 100 / n + 0.5)) or "—", MoneyText(gold)))
end

local function ToggleDiary()
    if UI.diary:IsShown() then
        UI.diary:Hide()
    else
        RefreshDiary()
        UI.diary:Show()
    end
end

StaticPopupDialogs["BOTGARRISON_CLEAR_DIARY"] = {
    text = "¿Borrar todo Mi Diario?\n\nEsta acción no se puede deshacer.",
    button1 = YES,
    button2 = NO,
    OnAccept = function()
        DiaryDB().entries = {}
        RefreshDiary()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

UI.diaryClear = CreateFrame("Button", nil, UI.diary, "UIPanelButtonTemplate")
UI.diaryClear:SetSize(120, 24)
UI.diaryClear:SetPoint("BOTTOM", 0, 24)
UI.diaryClear:SetText("Borrar diario")
UI.diaryClear:SetScript("OnClick", function()
    StaticPopup_Show("BOTGARRISON_CLEAR_DIARY")
end)

UI.diaryBtn = CreateFrame("Button", nil, UI.main, "UIPanelButtonTemplate")
UI.diaryBtn:SetSize(84, 20)
UI.diaryBtn:SetPoint("TOPRIGHT", UI.main, "TOPRIGHT", -34, -63)
UI.diaryBtn:SetText("Mi Diario")
UI.diaryBtn:SetScript("OnClick", ToggleDiary)

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

-- Un solo OnUpdate: gestiona arrastre y parpadeo
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

-- -------------------- LOGICA: TABLON --------------------
local function OfferAt(i)
    local b = UI.board
    return b and b.offers and i and b.offers[i] or nil
end

function UI.UpdateSelection()
    for i, r in ipairs(UI.rows) do
        if UI.sel == i and r:IsShown() then r.sel:Show() else r.sel:Hide() end
    end
end

function UI.UpdateDetail()
    local o = OfferAt(UI.sel)
    if not o then
        UI.dName:SetText("")
        UI.dMeta:SetText("")
        UI.dDesc:SetText("")
        UI.dReward:SetText("")
        UI.dReq:SetText("")
        return
    end
    UI.dName:SetText("|cffffd100" .. (o.name or "?") .. "|r")
    UI.dMeta:SetText(string.format("%s   |cff888888·|r   |cffffffff%d min|r   |cff888888·|r   Éxito %s~%.0f%%|r",
        o.diffLabel or "", o.minutes or 0, ChanceColor(o.chance), (o.chance or 0) * 100))
    UI.dDesc:SetText((o.desc and o.desc ~= "") and ("|cffdddddd" .. o.desc .. "|r") or "")
    UI.dReward:SetText(string.format("|cffffd100Recompensa:|r |cffffffff%s - %s|r\n%s",
        o.goldMinStr or "?", o.goldMaxStr or "?", o.itemFlavor or ""))
    if o.ok then
        UI.dReq:SetText("|cffffd100Requisitos:|r |cffffffff" .. (o.req or "cualquiera") .. "|r")
    else
        UI.dReq:SetText("|cffff4444" .. (o.reqMsg or "Requisitos no cumplidos.") .. "|r")
    end
end

function UI.UpdateSendButton()
    local o = OfferAt(UI.sel)
    if o and o.ok and (UI._cd or 0) <= 0 then
        UI.sendBtn:Enable()
    else
        UI.sendBtn:Disable()
    end
end

function UI.UpdateGroupExtras()
    local g = UI.board and UI.board.group or {}
    local parts = {}
    if g.under then parts[#parts + 1] = "|cffff8800Equipo bajo: éxito limitado|r" end
    if (UI._cd or 0) > 0 then
        parts[#parts + 1] = "|cffff4444Bots recuperándose: " .. FormatTime(UI._cd) .. "|r"
    end
    UI.g3:SetText(table.concat(parts, "     "))
end

local function PopulateBoard()
    local b = UI.board
    if not b then return end
    local g = b.group or {}

    UI.g1:SetText(string.format(
        "|cffffd100Destacamento|r  |cffffffff%d/%d|r compañeros     |cff4da6ffT%d|r  |cff33ff66H%d|r  |cffff6666D%d|r",
        g.bots or 0, g.max or 4, g.tanks or 0, g.healers or 0, g.dps or 0))
    UI.g2:SetText(string.format(
        "|cffaaaaaaGS medio|r |cffffffff%d|r   |cffaaaaaaCapitán|r |cffffffff%d|r   |cffaaaaaaPoder|r |cffffffff%.1f|r",
        g.gs or 0, g.captain or 0, g.power or 0))
    UI.UpdateGroupExtras()

    local offers = b.offers or {}
    for i = 1, MAX_ROWS do
        local r, o = UI.rows[i], offers[i]
        if o then
            local col = DIFFCOL[o.diff] or "|cffffffff"
            r.diffFS:SetText(col .. (DIFFNAME[o.diff] or o.diff or "") .. "|r")
            r.nameFS:SetText((o.ok and "|cffffd100" or "|cff888888") .. (o.name or "?") .. "|r")
            r.infoFS:SetText(string.format("|cffaaaaaa%d min|r  %s%.0f%%|r",
                o.minutes or 0, ChanceColor(o.chance), (o.chance or 0) * 100))
            r:Show()
        else
            r:Hide()
        end
    end

    UI.emptyText:SetText(EMPTY_TXT)
    if #offers == 0 then UI.emptyText:Show() else UI.emptyText:Hide() end

    if not UI.sel or not offers[UI.sel] then
        UI.sel = (#offers > 0) and 1 or nil
    end

    -- boton "Bloqueadas (n)"
    local n = b.listCD and #b.listCD or 0
    UI.cdBtn:SetText(string.format("Bloqueadas (%d)", n))

    UI.UpdateSelection()
    UI.UpdateDetail()
    UI.UpdateSendButton()
end

-- -------------------- LOGICA: VISTAS --------------------
local function SetShownAll(list, show)
    for _, f in ipairs(list) do
        if show then f:Show() else f:Hide() end
    end
end

local MISSION_FRAMES = { UI.card, UI.descPanel, UI.infoPanel }
local BOARD_FRAMES   = { UI.groupPanel, UI.listPanel, UI.detailPanel }

local function RefreshView()
    local d = UI.data
    local mode
    if d and d.active then
        mode = "mission"
    elseif UI.board and UI.board.near then
        mode = "board"
    else
        mode = "idle"
    end
    UI.mode = mode

    SetShownAll(MISSION_FRAMES, mode == "mission")
    SetShownAll(BOARD_FRAMES, mode == "board")
    if mode == "idle" then UI.idlePanel:Show() else UI.idlePanel:Hide() end

    if mode == "mission" then
        if d.ready then
            UI.status:SetText("|cff00ff00¡Misión lista!|r\n|cffaaaaaaYa puedes reclamarla|r")
            UI.claimBtn:Show()
            UI.cancelBtn:Hide()
        else
            UI.status:SetText("|cffffcc00Misión en curso|r")
            UI.claimBtn:Hide()
            UI.cancelBtn:Show()
        end
        UI.sendBtn:Hide()
        UI.cdBtn:Hide()
    elseif mode == "board" then
        UI.status:SetText("|cffffd100Tablón de misiones|r\n|cffaaaaaaElige una misión|r")
        UI.claimBtn:Hide()
        UI.cancelBtn:Hide()
        UI.sendBtn:Show()
        UI.cdBtn:Show()
    else
        UI.status:SetText("|cff888888Sin misión activa|r")
        UI.claimBtn:Hide()
        UI.cancelBtn:Hide()
        UI.sendBtn:Hide()
        UI.cdBtn:Hide()
    end
end

-- -------------------- LOGICA: MISION --------------------
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
        UI.name:SetText("")
        UI.diff:SetText("")
        UI.timer:SetText("")
        UI.desc:SetText("")
        UI.bots:SetText("")
        UI.rew:SetText("")
        UI.chance:SetText("")
        UI._rem = 0
        UI._total = 0
        UI._key = nil
        UpdateProgress()
        SetReadyAlert(false)
        RefreshView()
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
        UI.timer:SetText("|cff00ff00COMPLETADA|r")
        SetReadyAlert(true)
    else
        UI.timer:SetText("|cffffffff" .. FormatTime(UI._rem) .. "|r")
        SetReadyAlert(false)
    end
    UpdateProgress()
    RefreshView()
end

UI.main:SetScript("OnUpdate", function(self, elapsed)
    if not self:IsShown() then return end

    -- Hasta recibir el primer dato, reintenta cada 3 s
    UI._poll = (UI._poll or 0) + elapsed
    if UI._poll >= 3 and not UI._gotData then
        UI._poll = 0
        AIO.Handle("BotGarrison", "requestStatus")
    end

    UI._acc = (UI._acc or 0) + elapsed
    if UI._acc < 0.25 then return end
    local dt = UI._acc
    UI._acc = 0

    -- Temporizador de la mision en curso
    if UI.data and UI.data.active and not UI.data.ready then
        UI._rem = math.max(0, (UI._rem or 0) - dt)
        if UI._rem <= 0 then
            UI.timer:SetText("|cff00ff00COMPLETADA|r")
            UI.data.ready = true
            SetReadyAlert(true)
            RefreshView()
        else
            UI.timer:SetText("|cffffffff" .. FormatTime(UI._rem) .. "|r")
        end
        UpdateProgress()
    end

    -- Vista tablon: comprobar cada 3 s que sigues junto al tablon (el servidor decide)
    if UI.mode == "board" then
        UI._boardPoll = (UI._boardPoll or 0) + dt
        if UI._boardPoll >= 3 then
            UI._boardPoll = 0
            AIO.Handle("BotGarrison", "requestBoard")
        end
    else
        UI._boardPoll = 0
    end

    -- Cooldown de bots (vista tablon)
    if (UI._cd or 0) > 0 then
        UI._cd = math.max(0, UI._cd - dt)
        if UI.mode == "board" then
            UI.UpdateGroupExtras()
            if UI._cd <= 0 then UI.UpdateSendButton() end
        end
    end
end)

-- -------------------- HANDLERS AIO --------------------
local function DebugDump(tag, data)
    if not UI.debug then return end
    local parts = {}
    if type(data) == "table" then
        for k, v in pairs(data) do parts[#parts + 1] = tostring(k) .. "=" .. tostring(v) end
    else
        parts[1] = tostring(data)
    end
    DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[BG debug]|r " .. tag .. ": " .. table.concat(parts, ", "))
end

function Handlers.UpdateStatus(player, data)
    UI._gotData = true
    DebugDump("UpdateStatus", data)
    if data and data.active and data.remaining then UI._rem = data.remaining end
    ApplyData(data)
end

function Handlers.DiaryEntry(player, entry)
    DebugDump("DiaryEntry", entry)
    if type(entry) ~= "table" then return end
    local entries = DiaryDB().entries
    table.insert(entries, 1, entry)               -- la mas reciente arriba
    while #entries > DIARY_MAX do table.remove(entries) end
    if UI.diary:IsShown() then RefreshDiary() end
end

function Handlers.BoardData(player, payload)
    UI._gotData = true
    DebugDump("BoardData", payload)
    if type(payload) ~= "table" then return end

    UI.board = payload
    UI._boardTime = GetTime()
    UI._cd = payload.cd or 0
    if payload.open then UI.sel = nil end

    local m = payload.mission or { active = false }
    if m.active and m.remaining then UI._rem = m.remaining end
    ApplyData(m)       -- tambien llama a RefreshView
    PopulateBoard()

    if payload.open then
        UI.main:Show()
        if UI._readyAlert then SetReadyAlert(false) end
    end
end

SLASH_BOTGARRISON1 = "/bg"
SLASH_BOTGARRISON2 = "/botgarrison"
SLASH_BOTGARRISON3 = "/companeros"
SlashCmdList["BOTGARRISON"] = function(msg)
    if msg and msg:lower() == "debug" then
        UI.debug = not UI.debug
        DEFAULT_CHAT_FRAME:AddMessage("|cffff8800[BG debug]|r " .. (UI.debug and "activado" or "desactivado"))
        AIO.Handle("BotGarrison", "requestStatus")
        return
    end
    if msg and (msg:lower() == "diario" or msg:lower() == "diary") then
        ToggleDiary()
        return
    end
    ToggleMain()
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "BotGarrison" then DiaryDB() end   -- SavedVariables ya cargadas
        return
    end
    AIO.Handle("BotGarrison", "requestStatus")
end)

RefreshView()

DEFAULT_CHAT_FRAME:AddMessage("|cff00ccff[BotGarrison]|r v2.1 |cffffffff/bg|r  |cffffffff/bg diario|r")

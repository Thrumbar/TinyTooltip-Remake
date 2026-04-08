local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local DEAD = DEAD
local CopyTable = CopyTable
local GetMouseFocus = GetMouseFocus or GetMouseFoci

local addon = TinyTooltip
local Util = addon.Util or {}

TinyTooltipRemakeDB = TinyTooltipRemakeDB or {}
TinyTooltipRemakeCharacterDB = TinyTooltipRemakeCharacterDB or {}
addon.defaults = CopyTable(addon.db)

local function MigrateLegacyIdInfoSettings(db)
    if (type(db) ~= "table") then return end

    local general = db.general
    local display = general and general.idInfoDisplay
    if (type(display) ~= "table") then return end

    db.item = db.item or {}
    db.spell = db.spell or {}

    if (db.item.showItemId == nil and display.spellItem ~= nil) then
        db.item.showItemId = display.spellItem and true or false
    end
    if (db.item.showItemMaxStack == nil and display.spellItem ~= nil) then
        db.item.showItemMaxStack = display.spellItem and true or false
    end
    if (db.item.showItemExpansion == nil and display.spellItem ~= nil) then
        db.item.showItemExpansion = display.spellItem and true or false
    end
    if (db.item.showItemIconId == nil and display.icon ~= nil) then
        db.item.showItemIconId = display.icon and true or false
    end
    if (db.item.showItemMaxStack == nil and db.item.showItemId ~= nil) then
        db.item.showItemMaxStack = db.item.showItemId and true or false
    end

    if (db.spell.showSpellId == nil and display.spellItem ~= nil) then
        db.spell.showSpellId = display.spellItem and true or false
    end
    if (db.spell.showSpellIconId == nil and display.icon ~= nil) then
        db.spell.showSpellIconId = display.icon and true or false
    end
end

local function GetStatusbarUnit()
    local focus = GetMouseFocus and GetMouseFocus()
    if (focus and focus.unit) then
        return focus.unit
    end
    return "mouseover"
end

local function ColorStatusBar(statusBar, value)
    local general = addon.db and addon.db.general
    if (not general) then return end

    if (general.statusbarColor == "auto") then
        local unit = GetStatusbarUnit()
        local red, green, blue
        if (UnitIsPlayer(unit)) then
            red, green, blue = GetClassColor(select(2, UnitClass(unit)))
        else
            red, green, blue = GameTooltip_UnitColor(unit)
            if (green == 0.6) then green = 0.9 end
            if (red == 1 and green == 1 and blue == 1) then
                red, green, blue = 0, 0.9, 0.1
            end
        end
        statusBar:SetStatusBarColor(red, green, blue)
    elseif (value and general.statusbarColor == "smooth") then
        HealthBar_OnValueChanged(statusBar, value, true)
    end
end

local function SetStatusBarText(text)
    local statusBar = GameTooltipStatusBar
    if (statusBar and statusBar.TextString) then
        statusBar.TextString:SetText(text or "")
    end
end

local function SetDeadStatusBarText(unit, showText, showPercent)
    local maxHealth = UnitHealthMax(unit) or 1
    if (showText) then
        SetStatusBarText(("|cff999999%s|r |cffffcc33<%s>|r"):format(AbbreviateLargeNumbers(maxHealth), DEAD))
    elseif (showPercent) then
        SetStatusBarText(("|cffffcc33<%s>|r"):format(DEAD))
    else
        SetStatusBarText("")
    end
end

local function GetUnitHealthPercentText(unit)
    if (not UnitHealthPercent) then
        return nil
    end

    local ok, percent = pcall(function()
        return UnitHealthPercent(unit, true, CurveConstants and CurveConstants.ScaleTo100)
    end)
    if (ok and type(percent) == "number") then
        return string.format("%.0f%%", percent)
    end
end

local function SetLiveStatusBarText(unit, showText, showPercent)
    local currentHealth = UnitHealth(unit) or 1
    local maxHealth = UnitHealthMax(unit) or 1
    local currentText = AbbreviateLargeNumbers(currentHealth)
    local maxText = AbbreviateLargeNumbers(maxHealth)
    local percentText = GetUnitHealthPercentText(unit)

    if (showText and showPercent) then
        if (percentText) then
            SetStatusBarText(currentText .. " / " .. maxText .. " (" .. percentText .. ")")
        else
            SetStatusBarText(currentText .. " / " .. maxText)
        end
    elseif (showText) then
        SetStatusBarText(currentText .. " / " .. maxText)
    elseif (showPercent) then
        SetStatusBarText(percentText or "")
    else
        SetStatusBarText("")
    end
end

local function UpdateStatusBarText(statusBar)
    local general = addon.db and addon.db.general
    local unit = GetStatusbarUnit()
    if (not general or not statusBar or not statusBar.TextString) then
        return
    end

    local showText = general.statusbarText
    local showPercent = general.statusbarPercent
    local shouldShowText = (showText or showPercent) and not statusBar.forceHideText

    if (UnitIsDeadOrGhost(unit)) then
        SetDeadStatusBarText(unit, showText, showPercent)
    elseif (shouldShowText) then
        SetLiveStatusBarText(unit, showText, showPercent)
    else
        SetStatusBarText("")
    end
end

local function InitializeStatusBar()
    local statusBar = GameTooltipStatusBar
    statusBar.bg = statusBar.bg or statusBar:CreateTexture(nil, "BACKGROUND")
    statusBar.bg:SetAllPoints()
    statusBar.bg:SetColorTexture(1, 1, 1)
    statusBar.bg:SetVertexColor(0.2, 0.2, 0.2, 0.8)

    if (not statusBar.TextString) then
        statusBar.TextString = statusBar:CreateFontString(nil, "OVERLAY")
        statusBar.TextString:SetPoint("CENTER")
    end
    statusBar.TextString:SetFont(NumberFontNormal:GetFont(), 11, "THINOUTLINE")
    statusBar.capNumericDisplay = true
    statusBar.lockShow = 1

    statusBar:HookScript("OnShow", function(self)
        ColorStatusBar(self)
        if (addon.db.general.statusbarHeight == 0 or addon.db.general.statusbarHide) then
            self:Hide()
        end
    end)

    statusBar:HookScript("OnValueChanged", function(self, value)
        UpdateStatusBarText(self)
        ColorStatusBar(self, value)
    end)
end

local function InitializeItemRefCloseButton()
    if (not ItemRefCloseButton or IsAddOnLoaded("ElvUI")) then
        return
    end

    ItemRefCloseButton:SetSize(14, 14)
    ItemRefCloseButton:SetPoint("TOPRIGHT", -4, -4)
    ItemRefCloseButton:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
    ItemRefCloseButton:SetPushedTexture("Interface\\Buttons\\UI-StopButton")
    ItemRefCloseButton:GetNormalTexture():SetVertexColor(0.9, 0.6, 0)
end

local function LoadDatabase()
    MigrateLegacyIdInfoSettings(TinyTooltipRemakeDB)
    MigrateLegacyIdInfoSettings(TinyTooltipRemakeCharacterDB)

    addon.db = addon:MergeVariable(addon.db, TinyTooltipRemakeDB)
    if (addon.db.general.SavedVariablesPerCharacter) then
        local mergedDatabase = CopyTable(addon.db)
        addon.db = addon:MergeVariable(mergedDatabase, TinyTooltipRemakeCharacterDB)
    end
end

local function InitializeFontShadows()
    GameTooltipHeaderText:SetShadowOffset(1, -1)
    GameTooltipHeaderText:SetShadowColor(0, 0, 0, 0.9)
    GameTooltipText:SetShadowOffset(1, -1)
    GameTooltipText:SetShadowColor(0, 0, 0, 0.9)
    Tooltip_Small:SetShadowOffset(1, -1)
    Tooltip_Small:SetShadowColor(0, 0, 0, 0.9)
end

LibEvent:attachEvent("VARIABLES_LOADED", function()
    InitializeItemRefCloseButton()
    InitializeStatusBar()
    LoadDatabase()

    LibEvent:trigger("tooltip:variables:loaded")
    LibEvent:trigger("TINYTOOLTIP_GENERAL_INIT")

    InitializeFontShadows()
end)

LibEvent:attachEvent("PLAYER_LOGIN", function()
    local general = addon.db and addon.db.general
    if (not general) then return end

    local title = addon.L["about.announcement.title"] or ""
    local chatKey = addon.L["about.announcement.chatKey"] or ""
    local chatContent = addon.L["about.announcement.chat"] or ""
    local mode = general.announcementMode or "noticeAlways"

    if (mode == "noticeNever" or chatKey == "") then
        return
    end
    if (mode == "noticeSnooze" and general.announcementLastSeen == chatKey) then
        return
    end

    if (title ~= "") then
        print(("|cff33eeff[TinyTooltip-Remake]|r %s"):format(title))
    end
    if (chatContent ~= "") then
        print(chatContent)
    end
    general.announcementLastSeen = chatKey
end)

LibEvent:attachTrigger("tooltip:cleared, tooltip:hide", function(self, tooltip)
    if (addon.db and addon.db.general) then
        LibEvent:trigger("tooltip.style.bgfile", tooltip, addon.db.general.bgfile)
    end
    LibEvent:trigger("tooltip.style.border.color", tooltip, unpack(addon.db.general.borderColor))
    LibEvent:trigger("tooltip.style.background", tooltip, unpack(addon.db.general.background))
    if (tooltip.BigFactionIcon) then
        tooltip.BigFactionIcon:Hide()
    end
end)

LibEvent:attachTrigger("tooltip:show", function(self, tooltip)
    if (tooltip ~= GameTooltip) then return end

    LibEvent:trigger(
        "tooltip.statusbar.position",
        addon.db.general.statusbarPosition,
        addon.db.general.statusbarOffsetX,
        addon.db.general.statusbarOffsetY
    )

    local text = GameTooltipStatusBar and GameTooltipStatusBar.TextString
    if (not text) then return end

    local stringWidth = (text.GetStringWidth and text:GetStringWidth()) or (text.GetWidth and text:GetWidth())
    local tooltipWidth = tooltip and tooltip.GetWidth and tooltip:GetWidth()

    local okWidth, desiredWidth = pcall(function()
        return stringWidth + 10
    end)
    if (not okWidth or type(desiredWidth) ~= "number") then return end

    local okMinimum, minimumWidth = pcall(function()
        return desiredWidth + 2
    end)
    if (not okMinimum or type(minimumWidth) ~= "number") then return end

    if (GameTooltipStatusBar:IsShown()) then
        local okCompare, isWider = pcall(function()
            return (type(tooltipWidth) == "number") and (desiredWidth > tooltipWidth)
        end)
        if (okCompare and isWider) then
            tooltip:SetMinimumWidth(minimumWidth)
            tooltip:Show()
        end
    end
end)

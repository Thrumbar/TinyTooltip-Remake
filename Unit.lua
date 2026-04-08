local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local LEVEL = LEVEL
local PVP = PVP
local FACTION_HORDE = FACTION_HORDE
local FACTION_ALLIANCE = FACTION_ALLIANCE
local TOOLTIP_DATA_POST_PROCESSOR = TooltipDataProcessor
local TOOLTIP_DATA_TYPE_ENUM = Enum and Enum.TooltipDataType

local addon = TinyTooltip
local Util = addon.Util or {}
local SafeBool = Util.SafeBool or function(fn, ...)
    local ok, value = pcall(fn, ...)
    return ok and value == true or false
end
local SafeCall = Util.SafeCall or function(fn, ...)
    local ok, a, b, c, d = pcall(fn, ...)
    if (ok) then
        return a, b, c, d
    end
end
local SafeConcat = Util.SafeConcat or function(values, separator)
    return table.concat(values or {}, separator or " ")
end
local StripColorCodes = Util.StripColorCodes or function(text)
    if (type(text) ~= "string") then return end
    if (issecretvalue and issecretvalue(text) and not (canaccessvalue and canaccessvalue(text))) then return end
    local ok, value = pcall(function()
        local stripped = string.gsub(text, "|c%x%x%x%x%x%x%x%x", "")
        stripped = string.gsub(stripped, "|r", "")
        return strtrim(stripped)
    end)
    if (ok and value ~= "") then
        return value
    end
end
local GetTooltipLineText = Util.GetTooltipLineText or function(line)
    if (line and line.GetText) then
        return line:GetText()
    end
end
local GetUnitGuidSafe = Util.GetUnitGuidSafe or function(unit)
    if (SafeBool(UnitExists, unit) and UnitGUID) then
        return SafeCall(UnitGUID, unit)
    end
end

local function StripTrimMarker(text)
    if (type(text) ~= "string") then return "" end
    if (issecretvalue and issecretvalue(text) and not (canaccessvalue and canaccessvalue(text))) then
        return ""
    end
    local ok, value = pcall(string.gsub, text, "%s+([|%x%s]+)<trim>", "%1")
    if (ok and type(value) == "string") then
        return value
    end
    return ""
end

local function ShouldShowElement(config, elementKey)
    return config and config.elements and config.elements[elementKey] and config.elements[elementKey].enable
end

local function FindMountAura(unit)
    if (not C_MountJournal or not C_MountJournal.GetMountFromSpell) then return end

    if (AuraUtil and AuraUtil.ForEachAura) then
        local auraName
        local auraSpellID
        local mountID
        local ok = pcall(AuraUtil.ForEachAura, unit, "HELPFUL", nil, function(aura)
            if (type(aura) ~= "table" or not aura.spellId) then return end
            local foundMountID = C_MountJournal.GetMountFromSpell(aura.spellId)
            if (foundMountID) then
                auraName = aura.name
                auraSpellID = aura.spellId
                mountID = foundMountID
                return true
            end
        end)
        if (ok and auraSpellID) then
            return auraName, auraSpellID, mountID
        end
    end

    if (UnitAura) then
        for index = 1, 40 do
            local name, _, _, _, _, _, _, _, _, spellID = UnitAura(unit, index, "HELPFUL")
            if (not name) then break end
            local mountID = C_MountJournal.GetMountFromSpell(spellID)
            if (mountID) then
                return name, spellID, mountID
            end
        end
        return
    end

    if (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
        for index = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unit, index, "HELPFUL")
            if (not aura) then break end
            local mountID = C_MountJournal.GetMountFromSpell(aura.spellId)
            if (mountID) then
                return aura.name, aura.spellId, mountID
            end
        end
    end
end

local function GetMountInfo(unit)
    if (not C_MountJournal or not C_MountJournal.GetMountInfoByID) then return end
    if (not SafeBool(UnitIsPlayer, unit)) then return end

    local auraName, _, mountID = FindMountAura(unit)
    if (not auraName) then return end

    local mountName
    local isCollected
    if (mountID) then
        local ok, resolvedName, _, _, _, _, _, _, _, _, _, collected = pcall(C_MountJournal.GetMountInfoByID, mountID)
        if (ok) then
            mountName = resolvedName
            isCollected = collected
        end
    end

    return mountName or auraName, isCollected
end

local function GetLineByIndex(tip, index)
    return _G[tip:GetName() .. "TextLeft" .. index]
end

local function FindPreferredSpecLine(tip, className)
    if (not tip or not className or className == "") then return end

    local bestText
    local bestLength
    for lineIndex = 2, tip:NumLines() do
        local line = GetLineByIndex(tip, lineIndex)
        local stripped = StripColorCodes(GetTooltipLineText(line))
        if (stripped and stripped ~= "") then
            local ok, matchesClass = pcall(function()
                if (stripped:find("^%d")) then return false end
                if (stripped:find("^<")) then return false end
                return stripped:find(className, 1, true) ~= nil
            end)
            if (ok and matchesClass) then
                local strippedLength = #stripped
                if (not bestLength or strippedLength < bestLength) then
                    bestText = stripped
                    bestLength = strippedLength
                end
            end
        end
    end

    return bestText
end

local function HideMatchingTooltipLine(tip, targetText)
    if (not tip or not targetText or targetText == "") then return end

    for lineIndex = 2, tip:NumLines() do
        local line = GetLineByIndex(tip, lineIndex)
        local stripped = StripColorCodes(GetTooltipLineText(line))
        if (stripped and stripped == targetText) then
            line:SetText(nil)
            return true
        end
    end
end

local function PreserveSpecLine(tip, unit, raw)
    local unitGuid = GetUnitGuidSafe(unit)
    local specLine = FindPreferredSpecLine(tip, raw and raw.className)

    if (specLine) then
        raw.className = specLine
        HideMatchingTooltipLine(tip, specLine)
        if (unitGuid) then
            tip._tinySpecGUID = unitGuid
            tip._tinySpecLine = specLine
        end
        return
    end

    if (
        unitGuid
        and tip._tinySpecGUID == unitGuid
        and type(tip._tinySpecLine) == "string"
        and tip._tinySpecLine ~= ""
    ) then
        raw.className = tip._tinySpecLine
    end
end

local function ResolvePlayerSpecIcon(unit, raw, config)
    raw.classSpecIcon = nil
    if (not ShouldShowElement(config, "className")) then return end
    if (not config.elements.className.icon) then return end
    if (not raw or type(raw.className) ~= "string" or raw.className == "") then return end

    if (GetSpecialization and GetSpecializationInfo and SafeBool(UnitIsUnit, unit, "player")) then
        local specializationIndex = GetSpecialization()
        if (type(specializationIndex) == "number" and specializationIndex > 0) then
            local ok, _, _, _, icon = pcall(GetSpecializationInfo, specializationIndex)
            if (ok and icon) then
                raw.classSpecIcon = icon
                return
            end
        end
    end

    if (GetInspectSpecialization and GetSpecializationInfoByID and SafeBool(UnitIsPlayer, unit)) then
        local okInspect, specializationID = pcall(GetInspectSpecialization, unit)
        if (okInspect and type(specializationID) == "number" and specializationID > 0) then
            local okSpec, _, _, _, icon = pcall(GetSpecializationInfoByID, specializationID)
            if (okSpec and icon) then
                raw.classSpecIcon = icon
                return
            end
        end
    end

    if (GetNumSpecializationsForClassID and GetSpecializationInfoForClassID and UnitClass) then
        local _, _, classID = UnitClass(unit)
        if (type(classID) == "number" and classID > 0) then
            local loweredClassLine = strlower(raw.className)
            local specializationCount = GetNumSpecializationsForClassID(classID) or 0
            for specializationIndex = 1, specializationCount do
                local okSpec, _, specName, _, icon = pcall(GetSpecializationInfoForClassID, classID, specializationIndex)
                if (okSpec and type(specName) == "string" and specName ~= "" and icon) then
                    if (strfind(loweredClassLine, strlower(specName), 1, true)) then
                        raw.classSpecIcon = icon
                        return
                    end
                end
            end
        end
    end
end

local function PopulateOptionalPlayerData(unit, raw, config)
    raw.mountName = nil
    raw.mountCollected = nil
    if (ShouldShowElement(config, "mount")) then
        raw.mountName, raw.mountCollected = GetMountInfo(unit)
    end

    if (ShouldShowElement(config, "itemLevel") and addon.RequestInspectItemLevel) then
        if (raw.itemLevel == addon.L["unknown"]) then
            addon:RequestInspectItemLevel(unit)
        end
    end

    if (ShouldShowElement(config, "achievementPoints") and addon.RequestInspectAchievementPoints) then
        if (raw.achievementPoints == addon.L["unknown"]) then
            addon:RequestInspectAchievementPoints(unit)
        end
    end
end

local function ColorBorder(tip, config, raw)
    if (config.coloredBorder and addon.colorfunc[config.coloredBorder]) then
        local r, g, b = addon.colorfunc[config.coloredBorder](raw)
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
        return
    end

    if (type(config.coloredBorder) == "string" and config.coloredBorder ~= "default") then
        local r, g, b = addon:GetRGBColor(config.coloredBorder)
        if (r and g and b) then
            LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
            return
        end
    end

    LibEvent:trigger("tooltip.style.border.color", tip, unpack(addon.db.general.borderColor))
end

local function ColorBackground(tip, config, raw)
    local background = config.background
    if (not background) then return end

    if (background.colorfunc == "default" or background.colorfunc == "" or background.colorfunc == "inherit") then
        local r, g, b, a = unpack(addon.db.general.background)
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, background.alpha or a)
        return
    end

    if (addon.colorfunc[background.colorfunc]) then
        local r, g, b = addon.colorfunc[background.colorfunc](raw)
        LibEvent:trigger("tooltip.style.background", tip, r, g, b, background.alpha or 0.8)
    end
end

local function GrayForDead(tip, config, unit)
    if (not config.grayForDead or not SafeBool(UnitIsDeadOrGhost, unit)) then return end

    LibEvent:trigger("tooltip.style.border.color", tip, 0.6, 0.6, 0.6)
    LibEvent:trigger("tooltip.style.background", tip, 0.1, 0.1, 0.1)

    for lineIndex = 1, tip:NumLines() do
        local line = GetLineByIndex(tip, lineIndex)
        if (line) then
            local text = GetTooltipLineText(line)
            if (type(text) == "string") then
                local ok, grayText = pcall(string.gsub, text, "|cff%x%x%x%x%x%x", "|cffaaaaaa")
                line:SetTextColor(0.7, 0.7, 0.7)
                if (ok and type(grayText) == "string") then
                    line:SetText(grayText)
                end
            end
        end
    end
end

local function ShowBigFactionIcon(tip, config, raw)
    if (not tip or not tip.BigFactionIcon) then return end

    if (
        config.elements.factionBig
        and config.elements.factionBig.enable
        and (raw.factionGroup == "Alliance" or raw.factionGroup == "Horde")
    ) then
        tip.BigFactionIcon:SetTexture("Interface\\Timer\\" .. raw.factionGroup .. "-Logo")
        tip.BigFactionIcon:Show()
        return
    end

    tip.BigFactionIcon:Hide()
end

local function ApplyUnitVisualStyle(tip, unit, config, raw)
    ColorBorder(tip, config, raw)
    ColorBackground(tip, config, raw)
    GrayForDead(tip, config, unit)
    ShowBigFactionIcon(tip, config, raw)
    if (addon.AutoSetTooltipWidth) then
        addon:AutoSetTooltipWidth(tip)
    end
end

local function HideBaseUnitLines(tip)
    addon:HideLine(tip, "^" .. LEVEL)
    addon:HideLine(tip, "^" .. FACTION_ALLIANCE)
    addon:HideLine(tip, "^" .. FACTION_HORDE)
    addon:HideLine(tip, "^" .. PVP)
end

local function WriteTooltipDataRows(tip, dataRows, startIndex)
    local baseIndex = tonumber(startIndex) or 1
    for rowOffset = 1, #dataRows do
        addon:GetLine(tip, baseIndex + rowOffset - 1):SetText(StripTrimMarker(SafeConcat(dataRows[rowOffset], " ")))
    end
end

local function UpdatePlayerTooltip(tip, unit, config, raw)
    PreserveSpecLine(tip, unit, raw)
    ResolvePlayerSpecIcon(unit, raw, config)
    PopulateOptionalPlayerData(unit, raw, config)

    local dataRows = addon:GetUnitData(unit, config.elements, raw)
    addon:HideLines(tip, 2, 3)
    HideBaseUnitLines(tip)
    WriteTooltipDataRows(tip, dataRows, 1)
    ApplyUnitVisualStyle(tip, unit, config, raw)
end

local function FormatNpcTitleLine(titleLine, config, raw)
    if (not titleLine or not config.elements.npcTitle.enable) then
        return false
    end

    local npcTitleText = GetTooltipLineText(titleLine)
    if (type(npcTitleText) ~= "string" or npcTitleText == "") then
        return false
    end

    titleLine:SetText(addon:FormatData(npcTitleText, config.elements.npcTitle, raw))
    return true
end

local function UpdateNpcTooltip(tip, unit, config, raw)
    local hasBaseData = addon:FindLine(tip, "^" .. LEVEL) or tip:NumLines() > 1
    if (hasBaseData) then
        local dataRows = addon:GetUnitData(unit, config.elements, raw)
        local titleLine = addon:GetNpcTitle(tip)
        local hasTitleLine = FormatNpcTitleLine(titleLine, config, raw)

        if (dataRows[1]) then
            addon:GetLine(tip, 1):SetText(SafeConcat(dataRows[1], " "))
        end
        if (dataRows[2]) then
            local secondRowIndex = hasTitleLine and 3 or 2
            addon:GetLine(tip, secondRowIndex):SetText(SafeConcat(dataRows[2], " "))
        end
        for rowIndex = 3, #dataRows do
            local targetLineIndex = rowIndex + (hasTitleLine and 1 or 0)
            addon:GetLine(tip, targetLineIndex):SetText(SafeConcat(dataRows[rowIndex], " "))
        end
    end

    addon:HideLine(tip, "^" .. LEVEL)
    addon:HideLine(tip, "^" .. PVP)
    ApplyUnitVisualStyle(tip, unit, config, raw)
end

local function ClearUnitTooltipState(tip)
    if (not tip) then return end
    tip._tinyUnitGUID = nil
    tip._tinySpecGUID = nil
    tip._tinySpecLine = nil
end

local function RefreshTooltipUnitState(tip, unit)
    if (not tip) then return end

    local previousGuid = tip._tinyUnitGUID
    tip._tinyUnitGUID = GetUnitGuidSafe(unit)
    if (previousGuid and tip._tinyUnitGUID and previousGuid ~= tip._tinyUnitGUID) then
        tip._tinySpecGUID = nil
        tip._tinySpecLine = nil
    end
end

local function IsUnitTooltip(tt)
    local owner = tt and tt:GetOwner()
    if (not owner) then return false end

    local ok, ownerUnit = pcall(function()
        return owner.unit
    end)
    if (ok and ownerUnit) then
        return true
    end

    if (owner.GetAttribute) then
        local attributeUnit = SafeCall(owner.GetAttribute, owner, "unit")
        if (attributeUnit) then
            return true
        end
    end

    return false
end

local function ClearLineByExactText(tip, exactText)
    if (not tip or not exactText or exactText == "") then return false end

    local removed = false
    for lineIndex = 2, tip:NumLines() do
        local line = GetLineByIndex(tip, lineIndex)
        local stripped = StripColorCodes(GetTooltipLineText(line))
        if (stripped and stripped == exactText) then
            line:SetText("")
            removed = true
        end
    end
    return removed
end

local function RemoveFactionLines(tip)
    local removedAlliance = FACTION_ALLIANCE and ClearLineByExactText(tip, FACTION_ALLIANCE)
    local removedHorde = FACTION_HORDE and ClearLineByExactText(tip, FACTION_HORDE)
    return removedAlliance or removedHorde
end

local function RemoveRightClickHint(tip)
    if (not tip or not tip.GetName or not UNIT_POPUP_RIGHT_CLICK) then
        return false
    end

    local removed = false
    for lineIndex = 2, tip:NumLines() do
        local line = GetLineByIndex(tip, lineIndex)
        local text = GetTooltipLineText(line)
        if (type(text) == "string") then
            if (issecretvalue and issecretvalue(text)) then
                -- cannot safely inspect secret text
            else
                local stripped = StripColorCodes(text)
                if (stripped == UNIT_POPUP_RIGHT_CLICK) then
                    line:SetText("")
                    removed = true
                end
            end
        end
    end

    return removed
end

local function HideLatestInstructionLine(tip)
    local latestIndex = tip:NumLines()
    local latestLine = GetLineByIndex(tip, latestIndex)
    if (latestLine) then
        SafeCall(latestLine.SetText, latestLine, "")
        SafeCall(latestLine.Hide, latestLine)
    end

    local spacerLine = GetLineByIndex(tip, latestIndex - 1)
    if (spacerLine and spacerLine.GetText) then
        local previousText = SafeCall(spacerLine.GetText, spacerLine)
        if (type(previousText) == "string" and not (issecretvalue and issecretvalue(previousText)) and previousText == " ") then
            SafeCall(spacerLine.Hide, spacerLine)
        end
    end
end

local function RemoveUnitTooltipNoise(tip)
    local removedAny = false
    if (RemoveFactionLines(tip)) then
        removedAny = true
    end
    if (RemoveRightClickHint(tip)) then
        removedAny = true
    end
    return removedAny
end

LibEvent:attachTrigger("tooltip:unit", function(self, tip, unit)
    if (not unit or not SafeBool(UnitExists, unit)) then return end

    RefreshTooltipUnitState(tip, unit)

    local raw = addon:GetUnitInfo(unit)
    if (SafeBool(UnitIsPlayer, unit)) then
        UpdatePlayerTooltip(tip, unit, addon.db.unit.player, raw)
    else
        UpdateNpcTooltip(tip, unit, addon.db.unit.npc, raw)
    end
end)

LibEvent:attachTrigger("tooltip:item, tooltip:spell, tooltip:aura, tooltip:hide, tooltip:cleared", function(self, tip)
    ClearUnitTooltipState(tip)
end)

LibEvent:attachTrigger("tooltip:show", function(self, tip)
    if (tip ~= GameTooltip) then return end
    RemoveFactionLines(tip)
end)

if (TOOLTIP_DATA_POST_PROCESSOR and TOOLTIP_DATA_POST_PROCESSOR.AddTooltipPostCall and TOOLTIP_DATA_TYPE_ENUM) then
    TOOLTIP_DATA_POST_PROCESSOR.AddTooltipPostCall(TOOLTIP_DATA_TYPE_ENUM.Unit, function(tip)
        RemoveFactionLines(tip)
    end)
end

if (GameTooltip_AddInstructionLine) then
    hooksecurefunc("GameTooltip_AddInstructionLine", function(tip, text)
        local general = addon.db and addon.db.general
        if (not general or not general.hideUnitFrameHint) then return end
        if (tip ~= GameTooltip) then return end
        if (not IsUnitTooltip(tip)) then return end

        if (type(text) == "string" and not (issecretvalue and issecretvalue(text)) and UNIT_POPUP_RIGHT_CLICK and text == UNIT_POPUP_RIGHT_CLICK) then
            HideLatestInstructionLine(tip)
            return
        end

        RemoveRightClickHint(tip)
    end)
end

addon.ColorUnitBorder = ColorBorder
addon.ColorUnitBackground = ColorBackground

local quickFocusBindingFrame = CreateFrame("Frame")
local quickFocusActionButton = CreateFrame("Button", "TinyTooltipQuickFocusButton", UIParent, "SecureActionButtonTemplate")
local quickFocusPendingUpdate

quickFocusActionButton:RegisterForClicks("AnyDown")
quickFocusActionButton:SetAttribute("type1", "macro")
quickFocusActionButton:SetAttribute("macrotext1", "/focus [@mouseover,exists]\n/clearfocus [@mouseover,noexists]")

local function ResolveQuickFocusBinding()
    local general = addon and addon.db and addon.db.general
    local modifierKey = general and general.quickFocusModKey or "none"
    if (modifierKey == "alt") then
        return "ALT-BUTTON1"
    elseif (modifierKey == "ctrl") then
        return "CTRL-BUTTON1"
    elseif (modifierKey == "shift") then
        return "SHIFT-BUTTON1"
    end
end

local function ApplyQuickFocusBinding()
    if (InCombatLockdown()) then
        quickFocusPendingUpdate = true
        return
    end

    quickFocusPendingUpdate = nil
    ClearOverrideBindings(quickFocusBindingFrame)

    local binding = ResolveQuickFocusBinding()
    if (binding and SetOverrideBindingClick) then
        SetOverrideBindingClick(quickFocusBindingFrame, true, binding, "TinyTooltipQuickFocusButton", "LeftButton")
    end
end

quickFocusBindingFrame:RegisterEvent("PLAYER_LOGIN")
quickFocusBindingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
quickFocusBindingFrame:SetScript("OnEvent", function(_, event)
    if (event == "PLAYER_LOGIN") then
        ApplyQuickFocusBinding()
    elseif (event == "PLAYER_REGEN_ENABLED" and quickFocusPendingUpdate) then
        ApplyQuickFocusBinding()
    end
end)

LibEvent:attachTrigger("tooltip:variables:loaded", function()
    ApplyQuickFocusBinding()
end)

LibEvent:attachTrigger("tooltip:variable:changed", function(self, keystring)
    if (keystring == "general.quickFocusModKey") then
        ApplyQuickFocusBinding()
    end
end)

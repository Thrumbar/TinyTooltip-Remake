local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local YOU = YOU
local TARGET = TARGET
local TOOLTIP_UPDATE_TIME = TOOLTIP_UPDATE_TIME or 0.2
local FACTION_HORDE = FACTION_HORDE
local FACTION_ALLIANCE = FACTION_ALLIANCE
local UNIT_POPUP_RIGHT_CLICK = UNIT_POPUP_RIGHT_CLICK

local addon = TinyTooltip
local Util = addon.Util or {}

local function GetUnitSettings()
    local db = addon.db
    if (not db or not db.unit) then
        return nil, nil
    end
    return db.unit.player, db.unit.npc
end

local function IsTargetToken(unit)
    if (type(unit) ~= "string") then
        return false
    end

    local ok, result = pcall(function()
        return unit:match("target$") ~= nil
    end)
    return ok and result == true
end

local function GetColoredPlayerName(unit, name)
    local classToken = select(2, UnitClass(unit))
    local colorCode = select(4, GetClassColor(classToken))
    return format("|c%s%s|r", colorCode or "ffffffff", name)
end

local function FormatTargetName(unit)
    local name = Util.SafeCall(UnitName, unit)
    if (type(name) ~= "string" or name == "") then
        return nil
    end

    local icon = addon:GetRaidIcon(unit) or ""
    if (Util.SafeBool(UnitIsUnit, unit, "player")) then
        return format("|cffff3333>>%s<<|r", strupper(YOU))
    end
    if (Util.SafeBool(UnitIsPlayer, unit)) then
        return icon .. GetColoredPlayerName(unit, name)
    end

    local red, green, blue = GameTooltip_UnitColor(unit)
    if (Util.SafeBool(UnitIsOtherPlayersPet, unit)) then
        return format("%s|cff%s<%s>|r", icon, addon:GetHexColor(red, green, blue), name)
    end
    return format("%s|cff%s[%s]|r", icon, addon:GetHexColor(red, green, blue), name)
end

local function GetTargetDisplayText(unit)
    if (not unit or not Util.SafeBool(UnitExists, unit)) then
        return nil
    end

    if (IsTargetToken(unit)) then
        return FormatTargetName(unit)
    end

    local ok, targetUnit = pcall(function()
        return unit .. "target"
    end)
    if (not ok or type(targetUnit) ~= "string" or not Util.SafeBool(UnitExists, targetUnit)) then
        return nil
    end

    return FormatTargetName(targetUnit)
end

local function FindTargetLine(tooltip)
    if (tooltip.ttTargetLine) then
        return tooltip.ttTargetLine
    end
    local line = addon:FindLine(tooltip, TARGET .. ":")
    tooltip.ttTargetLine = line
    return line
end

local function ClearDuplicateTargetLines(tooltip, activeLine)
    for lineIndex = 2, tooltip:NumLines() do
        local line = Util.GetTooltipLeftLine(tooltip, lineIndex)
        if (line and line ~= activeLine) then
            local text = Util.GetTooltipLineText(line)
            if (type(text) == "string") then
                local ok, matches = pcall(strfind, text, TARGET .. ":", 1, true)
                if (ok and matches) then
                    line:SetText(nil)
                end
            end
        end
    end
end

local function UpdateTargetLine(tooltip, unit)
    local targetText = GetTargetDisplayText(unit)
    local targetLine = FindTargetLine(tooltip)
    local changed = false

    if (not targetText) then
        if (targetLine) then
            targetLine:SetText(nil)
            tooltip.ttTargetLine = nil
            tooltip.ttTargetFormatted = nil
            changed = true
        end
        if (changed and addon.AutoSetTooltipWidth) then
            addon:AutoSetTooltipWidth(tooltip)
        end
        if (changed) then
            tooltip:Show()
        end
        return
    end

    local formattedText = format("%s: %s", TARGET, targetText)
    if (not targetLine) then
        tooltip:AddLine(formattedText)
        targetLine = Util.GetTooltipLeftLine(tooltip, tooltip:NumLines())
        tooltip.ttTargetLine = targetLine
    else
        targetLine:SetText(formattedText)
    end
    tooltip.ttTargetFormatted = formattedText
    changed = true

    ClearDuplicateTargetLines(tooltip, targetLine)

    if (changed and addon.AutoSetTooltipWidth) then
        addon:AutoSetTooltipWidth(tooltip)
    end
    if (changed) then
        tooltip:Show()
    end

    if (FACTION_ALLIANCE) then addon:HideLine(tooltip, "^" .. FACTION_ALLIANCE) end
    if (FACTION_HORDE) then addon:HideLine(tooltip, "^" .. FACTION_HORDE) end
    if (UNIT_POPUP_RIGHT_CLICK) then addon:HideLine(tooltip, UNIT_POPUP_RIGHT_CLICK) end
end

local function ResolveTargetUnitForTooltip(unit, isPlayerUnit, playerSettings, npcSettings)
    if (Util.SafeBool(UnitIsUnit, unit, "player")) then
        if (playerSettings.showTarget) then
            return "playertarget"
        end
        return nil
    end

    if (Util.SafeBool(UnitIsUnit, unit, "mouseover")) then
        if ((isPlayerUnit and playerSettings.showTarget) or ((not isPlayerUnit) and npcSettings.showTarget)) then
            return "mouseovertarget"
        end
        return nil
    end

    if ((isPlayerUnit and not playerSettings.showTarget) or ((not isPlayerUnit) and not npcSettings.showTarget)) then
        return nil
    end

    return unit
end

local function GetTargetedByText(mouseoverUnit, memberCount, tooltip)
    local groupPrefix = IsInRaid() and "raid" or "party"
    local count = 0
    local firstLine = true
    local isPlayerUnit = Util.SafeBool(UnitIsPlayer, mouseoverUnit)
    local targetByLabel = addon.L and addon.L["TargetBy"]

    for memberIndex = 1, memberCount do
        local groupUnit = groupPrefix .. memberIndex
        local targetUnit = groupUnit .. "target"
        if (Util.SafeBool(UnitIsUnit, mouseoverUnit, targetUnit) and not Util.SafeBool(UnitIsUnit, groupUnit, "player")) then
            count = count + 1
            if (isPlayerUnit or groupPrefix == "party") then
                if (firstLine) then
                    tooltip:AddLine(format("%s:", targetByLabel))
                    firstLine = false
                end
                local roleIcon = addon:GetRoleIcon(groupUnit) or ""
                local name = Util.SafeCall(UnitName, groupUnit)
                tooltip:AddLine("   " .. roleIcon .. " " .. GetColoredPlayerName(groupUnit, name or ""))
            end
        end
    end

    if (count > 0 and not isPlayerUnit and groupPrefix ~= "party") then
        return format("|cff33ffff%s|r", count)
    end
end

local function RemoveRightClickHint(tooltip)
    if (not addon.db.general.hideUnitFrameHint) then
        return
    end

    for lineIndex = 2, tooltip:NumLines() do
        local line = Util.GetTooltipLeftLine(tooltip, lineIndex)
        local text = Util.GetTooltipLineText(line)
        local stripped = Util.StripColorCodes and Util.StripColorCodes(text)
        if (stripped and UNIT_POPUP_RIGHT_CLICK and stripped == UNIT_POPUP_RIGHT_CLICK) then
            line:SetText(nil)
        end
    end
end

LibEvent:attachTrigger("tooltip:unit", function(self, tooltip, unit)
    tooltip.ttIsUnit = true

    local playerSettings, npcSettings = GetUnitSettings()
    if (not playerSettings or not npcSettings) then
        return
    end

    local isPlayerUnit = Util.SafeBool(UnitIsPlayer, unit)
    local targetUnit = ResolveTargetUnitForTooltip(unit, isPlayerUnit, playerSettings, npcSettings)
    UpdateTargetLine(tooltip, targetUnit)
    RemoveRightClickHint(tooltip)
end)

LibEvent:attachTrigger("tooltip:item, tooltip:spell", function(self, tooltip)
    tooltip.ttIsUnit = false
    if (tooltip.ttTargetLine) then
        tooltip.ttTargetLine:SetText(nil)
        tooltip.ttTargetLine = nil
    end
    tooltip.ttTargetFormatted = nil
end)

LibEvent:attachTrigger("tooltip:cleared, tooltip:hide", function(self, tooltip)
    if (tooltip) then
        tooltip.ttTargetLine = nil
        tooltip.ttTargetFormatted = nil
        tooltip.ttIsUnit = nil
    end
end)

GameTooltip:HookScript("OnUpdate", function(self, elapsed)
    self.updateElapsed = (self.updateElapsed or 0) + elapsed
    if (self.updateElapsed < TOOLTIP_UPDATE_TIME) then
        return
    end
    self.updateElapsed = 0

    local owner = self:GetOwner()
    if (owner and (owner.unit or (owner.GetAttribute and owner:GetAttribute("unit")))) then
        return
    end
    if (not self.ttIsUnit or not Util.SafeBool(UnitExists, "mouseover")) then
        return
    end

    local playerSettings, npcSettings = GetUnitSettings()
    if (not playerSettings or not npcSettings) then
        return
    end

    local isPlayerUnit = Util.SafeBool(UnitIsPlayer, "mouseover")
    if ((playerSettings.showTarget and isPlayerUnit) or (npcSettings.showTarget and not isPlayerUnit)) then
        UpdateTargetLine(self, "mouseovertarget")
    end
end)

LibEvent:attachTrigger("tooltip:unit", function(self, tooltip, unit)
    if (not Util.SafeBool(UnitExists, "mouseover")) then
        return
    end

    local memberCount = GetNumGroupMembers()
    if (memberCount < 1) then
        return
    end

    local playerSettings, npcSettings = GetUnitSettings()
    if (not playerSettings or not npcSettings) then
        return
    end

    local isPlayerUnit = Util.SafeBool(UnitIsPlayer, "mouseover")
    if ((playerSettings.showTargetBy and isPlayerUnit) or (npcSettings.showTargetBy and not isPlayerUnit)) then
        local text = GetTargetedByText("mouseover", memberCount, tooltip)
        if (text) then
            tooltip:AddLine(format("%s: %s", addon.L["TargetBy"], text), nil, nil, nil, true)
        end
    end
end)

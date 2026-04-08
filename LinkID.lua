local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local Util = addon.Util or {}
local L = addon.L or {}

local function IsModifierKeyDown()
    return IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()
end

local function ShouldShowIds(forceShow)
    return forceShow or IsModifierKeyDown()
end

local function GetTooltipItemLink(tooltip)
    if (not tooltip or type(tooltip.GetItem) ~= "function") then return end
    local _, itemLink = Util.SafeCall(tooltip.GetItem, tooltip)
    if (type(itemLink) == "string" and itemLink ~= "") then
        return itemLink
    end
end

local function GetTooltipSpellId(tooltip)
    if (not tooltip or type(tooltip.GetSpell) ~= "function") then return end
    local _, spellId = Util.SafeCall(tooltip.GetSpell, tooltip)
    if (type(spellId) == "number") then
        return spellId
    end
end

local function FindLabelLine(tooltip, label)
    if (not tooltip or type(label) ~= "string" or label == "") then return end
    for lineIndex = 1, tooltip:NumLines() do
        local line = Util.GetTooltipLeftLine(tooltip, lineIndex)
        local text = Util.GetTooltipLineText(line)
        local stripped = Util.StripColorCodes(text)
        if (type(stripped) == "string" and stripped:match("^%s*" .. label:gsub("([^%w])", "%%%1") .. ":")) then
            return line, lineIndex
        end
    end
end

local function ShowId(tooltip, label, value, noBlankLine, forceShow)
    if (not tooltip or not label or value == nil) then return end
    if (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if (not ShouldShowIds(forceShow)) then return end
    if (FindLabelLine(tooltip, label)) then
        LibEvent:trigger("tooltip.linkid", tooltip, label, value, noBlankLine)
        return
    end

    if (not noBlankLine) then
        tooltip:AddLine(" ")
    end
    tooltip:AddLine(format("%s: |cffffffff%s|r", label, value), 0, 1, 0.8)
    tooltip:Show()
    LibEvent:trigger("tooltip.linkid", tooltip, label, value, noBlankLine)
end

local function ParseHyperLink(link)
    if (type(link) ~= "string") then return end
    local name, value = string.match(link, "|?H(%a+):(%d+):")
    if (name and value) then
        return name:gsub("^([a-z])", strupper), value
    end
end

local function ParseItemString(linkOrId)
    if (type(linkOrId) ~= "string") then return end
    local itemString = linkOrId:match("|?Hitem:([^|]+)") or linkOrId:match("^item:([^|]+)")
    if (not itemString or itemString == "") then return end

    local segments = {}
    for value in (itemString .. ":"):gmatch("(.-):") do
        segments[#segments + 1] = value
    end
    return segments
end

local function JoinWrapped(values, label)
    if (type(values) ~= "table" or #values == 0) then return end
    local indent = string.rep(" ", string.len(label or "") + 2)
    local out = {}
    for index, value in ipairs(values) do
        out[#out + 1] = value
        if (index < #values) then
            if (index % 4 == 0) then
                out[#out + 1] = ",\n" .. indent
            else
                out[#out + 1] = ", "
            end
        end
    end
    return table.concat(out)
end

local function GetSpellIconId(spellId)
    if (type(spellId) ~= "number" or not C_Spell or not C_Spell.GetSpellTexture) then return end
    local icon = Util.SafeCall(C_Spell.GetSpellTexture, spellId)
    if (type(icon) == "number") then
        return icon
    end
end

local function GetItemIconId(linkOrId)
    if (not linkOrId) then return end
    local _, _, _, _, _, _, _, _, _, icon = GetItemInfo(linkOrId)
    if (type(icon) == "number") then
        return icon
    end
end

local function GetItemMaxStack(linkOrId)
    if (not linkOrId) then return end
    local _, _, _, _, _, _, _, maxStack = GetItemInfo(linkOrId)
    if (type(maxStack) == "number" and maxStack > 0) then
        return maxStack
    end
end

local function GetSpellDisplaySettings()
    local spellSettings = addon.db and addon.db.spell or {}
    local showId = spellSettings.showSpellId ~= false
    local showIconId = spellSettings.showSpellIconId ~= false

    if (IsModifierKeyDown() and spellSettings.modifierShowAll) then
        showId = true
        showIconId = true
    end

    return {
        showId = showId,
        showIconId = showIconId,
    }
end

local function ShowSpellInfo(tooltip, spellId)
    if (type(spellId) ~= "number") then return end

    local settings = GetSpellDisplaySettings()
    if (settings.showId) then
        ShowId(tooltip, L["id.spell"], spellId, nil, true)
    end

    local iconId = GetSpellIconId(spellId)
    if (iconId and settings.showIconId) then
        ShowId(tooltip, L["id.icon"], iconId, true, true)
    end
end

local function GetItemDisplaySettings()
    local itemSettings = addon.db and addon.db.item or {}
    local settings = {
        showItemId = itemSettings.showItemId ~= false,
        showItemBonusId = itemSettings.showItemBonusId ~= false,
        showItemEnhancementId = itemSettings.showItemEnhancementId ~= false,
        showItemGemId = itemSettings.showItemGemId ~= false,
        showItemMaxStack = itemSettings.showItemMaxStack ~= false,
        showItemIconId = itemSettings.showItemIconId ~= false,
    }

    if (IsModifierKeyDown() and itemSettings.modifierShowAll) then
        settings.showItemId = true
        settings.showItemBonusId = true
        settings.showItemEnhancementId = true
        settings.showItemGemId = true
        settings.showItemMaxStack = true
        settings.showItemIconId = true
    end

    return settings
end

local function GetItemLinkDetails(linkOrId)
    local details = {
        itemId = select(2, ParseHyperLink(linkOrId)),
        isEquippable = IsEquippableItem and IsEquippableItem(linkOrId) or false,
        bonusId = L["id.na"],
        enhancementId = L["id.na"],
        gemId = L["id.na"],
        iconId = GetItemIconId(linkOrId),
        maxStack = GetItemMaxStack(linkOrId),
    }

    local segments = ParseItemString(linkOrId)
    if (not segments) then
        return details
    end

    local enhancementId = segments[2]
    if (enhancementId and enhancementId ~= "" and enhancementId ~= "0") then
        details.enhancementId = enhancementId
    end

    local gemIds = {}
    for index = 3, 6 do
        local gemId = segments[index]
        if (gemId and gemId ~= "" and gemId ~= "0") then
            gemIds[#gemIds + 1] = gemId
        end
    end
    if (#gemIds > 0) then
        details.gemId = table.concat(gemIds, ", ")
    end

    local bonusCount = tonumber(segments[14] or "")
    if (bonusCount and bonusCount > 0) then
        local bonusIds = {}
        for index = 1, bonusCount do
            local bonusId = segments[14 + index]
            if (bonusId and bonusId ~= "") then
                bonusIds[#bonusIds + 1] = bonusId
            end
        end
        local wrapped = JoinWrapped(bonusIds, L["id.bonus"])
        if (wrapped and wrapped ~= "") then
            details.bonusId = wrapped
        end
    end

    return details
end

local function ShowItemInfo(tooltip, linkOrId)
    if (not linkOrId) then return end

    local settings = GetItemDisplaySettings()
    local details = GetItemLinkDetails(linkOrId)

    if (settings.showItemId) then
        local hasExpansionLine = FindLabelLine(tooltip, L["id.expansion"])
        ShowId(tooltip, L["id.item"], details.itemId, hasExpansionLine and true or false, true)
    end
    if (details.isEquippable and settings.showItemBonusId) then
        ShowId(tooltip, L["id.bonus"], details.bonusId, true, true)
    end
    if (details.isEquippable and settings.showItemEnhancementId) then
        ShowId(tooltip, L["id.enhancement"], details.enhancementId, true, true)
    end
    if (details.isEquippable and settings.showItemGemId) then
        ShowId(tooltip, L["id.gem"], details.gemId, true, true)
    end
    if (details.iconId and settings.showItemIconId) then
        ShowId(tooltip, L["id.icon"], details.iconId, true, true)
    end
    if (details.maxStack and settings.showItemMaxStack) then
        ShowId(tooltip, L["id.maxStack"], details.maxStack, true, true)
    end
end

local function GetAuraSpellId(unit, index, filter)
    if (not C_UnitAuras or not C_UnitAuras.GetAuraDataByIndex) then return end
    local aura = Util.SafeCall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
    if (type(aura) == "table") then
        return aura.spellId
    end
end

local function GetAuraSpellIdByInstance(unit, auraInstanceID)
    if (not C_UnitAuras or not C_UnitAuras.GetAuraDataByAuraInstanceID) then return end
    local aura = Util.SafeCall(C_UnitAuras.GetAuraDataByAuraInstanceID, unit, auraInstanceID)
    if (type(aura) == "table") then
        return aura.spellId
    end
end

local function HookAuraSetter(methodName, resolver)
    if (not GameTooltip or type(GameTooltip[methodName]) ~= "function") then return end
    hooksecurefunc(GameTooltip, methodName, function(tip, ...)
        ShowSpellInfo(tip, resolver(...))
    end)
end

local function ShowAchievementId(button)
    if (not button or not button.id or not IsModifierKeyDown()) then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT", 0, -32)
    GameTooltip:SetText(format("|cffffdd22%s:|r %s", L["Achievement"], button.id), 0, 1, 0.8)
    GameTooltip:Show()
end

local function HookAchievementButton(button, includeLeave)
    if (not button or button._tinyTooltipAchievementHooked) then return end
    button:HookScript("OnEnter", ShowAchievementId)
    if (includeLeave) then
        button:HookScript("OnLeave", GameTooltip_Hide)
    end
    button._tinyTooltipAchievementHooked = true
end

LibEvent:attachTrigger("tooltip:item", function(self, tip, link)
    ShowItemInfo(tip, link or GetTooltipItemLink(tip))
end)

LibEvent:attachTrigger("tooltip:spell", function(self, tip, spellId)
    ShowSpellInfo(tip, spellId or GetTooltipSpellId(tip))
end)

LibEvent:attachTrigger("tooltip:aura", function(self, tip, args)
    local spellId = (args and args[2] and args[2].intVal) or GetTooltipSpellId(tip)
    ShowSpellInfo(tip, spellId)
end)

HookAuraSetter("SetUnitAura", function(unit, index, filter)
    return GetAuraSpellId(unit, index, filter)
end)

HookAuraSetter("SetUnitBuff", function(unit, index, filter)
    return GetAuraSpellId(unit, index, filter)
end)

HookAuraSetter("SetUnitDebuff", function(unit, index, filter)
    return GetAuraSpellId(unit, index, filter)
end)

HookAuraSetter("SetUnitAuraByAuraInstanceID", function(unit, auraInstanceID)
    return GetAuraSpellIdByInstance(unit, auraInstanceID)
end)

HookAuraSetter("SetUnitBuffByAuraInstanceID", function(unit, auraInstanceID)
    return GetAuraSpellIdByInstance(unit, auraInstanceID)
end)

HookAuraSetter("SetUnitDebuffByAuraInstanceID", function(unit, auraInstanceID)
    return GetAuraSpellIdByInstance(unit, auraInstanceID)
end)

if (QuestMapLogTitleButton_OnEnter) then
    hooksecurefunc("QuestMapLogTitleButton_OnEnter", function(button)
        if (button.questID and addon.db.quest and addon.db.quest.showQuestId ~= false) then
            ShowId(GameTooltip, L["id.quest"], button.questID, nil, true)
        end
    end)
end

if (HybridScrollFrame_CreateButtons) then
    hooksecurefunc("HybridScrollFrame_CreateButtons", function(frame, buttonTemplate)
        if (buttonTemplate == "StatTemplate") then
            for _, button in pairs(frame.buttons) do
                HookAchievementButton(button, false)
            end
        elseif (buttonTemplate == "AchievementTemplate") then
            for _, button in pairs(frame.buttons) do
                HookAchievementButton(button, true)
            end
        end
    end)
end

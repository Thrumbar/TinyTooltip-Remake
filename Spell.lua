local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local Util = addon.Util or {}
local GetSpellTextureSafe = GetSpellTexture or (C_Spell and C_Spell.GetSpellTexture)

local function ResolveTooltipSpellId(tip)
    if (not tip or type(tip.GetSpell) ~= "function") then return end
    local _, spellId = Util.SafeCall(tip.GetSpell, tip)
    if (type(spellId) == "number") then
        return spellId
    end
end

local function GetHeaderText(tip)
    local line = addon:GetLine(tip, 1)
    if (not line) then return end
    return Util.GetTooltipLineText(line)
end

local function HeaderAlreadyHasIcon(tip)
    local text = GetHeaderText(tip)
    return type(text) == "string" and strfind(text, "^|T") ~= nil
end

local function ApplyGeneralTooltipStyle(tip)
    local general = addon.db and addon.db.general
    if (not general) then return end
    LibEvent:trigger("tooltip.style.bgfile", tip, general.bgfile)
    LibEvent:trigger("tooltip.style.border.corner", tip, general.borderCorner)
    if (general.borderCorner == "angular") then
        LibEvent:trigger("tooltip.style.border.size", tip, general.borderSize)
    end
end

local function ApplySpellTooltipStyle(tip)
    local spellSettings = addon.db and addon.db.spell
    if (not spellSettings) then return end
    if (spellSettings.borderColor) then
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(spellSettings.borderColor))
    end
    if (spellSettings.background) then
        LibEvent:trigger("tooltip.style.background", tip, unpack(spellSettings.background))
    end
end

local function AddSpellIconToHeader(tip, spellId)
    local spellSettings = addon.db and addon.db.spell
    if (not spellSettings or not spellSettings.showIcon) then return end
    if (not GetSpellTextureSafe) then return end
    if (HeaderAlreadyHasIcon(tip)) then return end

    local resolvedSpellId = spellId or ResolveTooltipSpellId(tip)
    if (type(resolvedSpellId) ~= "number") then return end

    local texture = Util.SafeCall(GetSpellTextureSafe, resolvedSpellId)
    local headerText = GetHeaderText(tip)
    if (type(texture) ~= "number" and type(texture) ~= "string") then return end
    if (type(headerText) ~= "string" or headerText == "") then return end

    addon:GetLine(tip, 1):SetFormattedText(
        "|T%s:16:16:0:0:32:32:2:30:2:30|t %s",
        texture,
        headerText
    )
    tip:Show()
    if (addon.AutoSetTooltipWidth) then
        addon:AutoSetTooltipWidth(tip)
    end
end

LibEvent:attachTrigger("tooltip:spell", function(self, tip, spellId)
    ApplyGeneralTooltipStyle(tip)
    AddSpellIconToHeader(tip, spellId)
    ApplySpellTooltipStyle(tip)
end)

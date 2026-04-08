local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local Util = addon.Util or {}

local GetSpellTextureSafe = (C_Spell and C_Spell.GetSpellTexture) or GetSpellTexture
local GetSpellNameSafe = (C_Spell and C_Spell.GetSpellName) or function(spellId)
    local name = GetSpellInfo and GetSpellInfo(spellId)
    return name
end

local function ResolveTooltipSpellId(tip)
    if (not tip or type(tip.GetSpell) ~= "function") then
        return
    end

    local _, spellId = Util.SafeCall(tip.GetSpell, tip)
    if (type(spellId) == "number") then
        return spellId
    end
end

local function GetSpellNameFromId(spellId)
    if (type(spellId) ~= "number") then
        return
    end

    local name = Util.SafeCall(GetSpellNameSafe, spellId)
    if (type(name) == "string" and name ~= "") then
        return name
    end
end

local function ApplyGeneralTooltipStyle(tip)
    local general = addon.db and addon.db.general
    if (not general) then
        return
    end

    LibEvent:trigger("tooltip.style.bgfile", tip, general.bgfile)
    LibEvent:trigger("tooltip.style.border.corner", tip, general.borderCorner)

    if (general.borderCorner == "angular") then
        LibEvent:trigger("tooltip.style.border.size", tip, general.borderSize)
    end
end

local function ApplySpellTooltipStyle(tip)
    local spellSettings = addon.db and addon.db.spell
    if (not spellSettings) then
        return
    end

    if (spellSettings.borderColor) then
        LibEvent:trigger("tooltip.style.border.color", tip, unpack(spellSettings.borderColor))
    end

    if (spellSettings.background) then
        LibEvent:trigger("tooltip.style.background", tip, unpack(spellSettings.background))
    end
end

local function HasTinySpellIconForSpell(tip, spellId)
    return tip and type(spellId) == "number" and tip._tinySpellHeaderIconSpellId == spellId
end

local function MarkTinySpellIconForSpell(tip, spellId)
    if (tip) then
        tip._tinySpellHeaderIconSpellId = spellId
    end
end

local function AddSpellIconToHeader(tip, spellId)
    local spellSettings = addon.db and addon.db.spell
    if (not spellSettings or not spellSettings.showIcon) then
        return
    end

    if (not GetSpellTextureSafe) then
        return
    end

    local resolvedSpellId = spellId or ResolveTooltipSpellId(tip)
    if (type(resolvedSpellId) ~= "number") then
        return
    end

    if (HasTinySpellIconForSpell(tip, resolvedSpellId)) then
        return
    end

    local texture = Util.SafeCall(GetSpellTextureSafe, resolvedSpellId)
    local spellName = GetSpellNameFromId(resolvedSpellId)
    local headerLine = addon:GetLine(tip, 1)

    if ((type(texture) ~= "number" and type(texture) ~= "string") or type(spellName) ~= "string" or spellName == "") then
        return
    end

    if (not headerLine or type(headerLine.SetFormattedText) ~= "function") then
        return
    end

    local ok = pcall(
        headerLine.SetFormattedText,
        headerLine,
        "|T%s:16:16:0:0:32:32:2:30:2:30|t %s",
        texture,
        spellName
    )

    if (not ok) then
        return
    end

    MarkTinySpellIconForSpell(tip, resolvedSpellId)
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

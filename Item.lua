local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local L = addon.L or {}
local Util = addon.Util or {}

local function GetItemInfoFromLink(linkOrId)
    if (linkOrId == nil or linkOrId == "") then
        return nil
    end

    local name, link, quality, _, _, _, _, stackCount, _, texture = GetItemInfo(linkOrId)
    if (not name) then
        return nil
    end

    return {
        itemLink = link,
        itemQuality = quality,
        itemStackCount = stackCount,
        itemTexture = texture,
    }
end

local function GetTooltipTitleColor(tooltip)
    local line = Util.GetTooltipLeftLine and Util.GetTooltipLeftLine(tooltip, 1)
    if (not line or not line.GetTextColor) then
        return nil
    end

    local ok, r, g, b = pcall(line.GetTextColor, line)
    if (not ok or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number") then
        return nil
    end

    return r, g, b
end

local function ApplyItemStyle(tooltip, borderRed, borderGreen, borderBlue)
    local general = addon.db.general
    LibEvent:trigger("tooltip.style.bgfile", tooltip, general.bgfile)
    LibEvent:trigger("tooltip.style.background", tooltip, unpack(general.background))
    LibEvent:trigger("tooltip.style.border.corner", tooltip, general.borderCorner)

    if (general.borderCorner == "angular") then
        LibEvent:trigger("tooltip.style.border.size", tooltip, general.borderSize)
    end

    if (addon.db.item.coloredItemBorder) then
        LibEvent:trigger("tooltip.style.border.color", tooltip, borderRed, borderGreen, borderBlue)
    else
        LibEvent:trigger("tooltip.style.border.color", tooltip, unpack(general.borderColor))
    end
end

local function PrependItemIcon(tooltip, itemInfo)
    if (not addon.db.item.showItemIcon) then
        return
    end

    local texture = itemInfo and itemInfo.itemTexture
    local line = addon:GetLine(tooltip, 1)
    local text = Util.GetTooltipLineText and Util.GetTooltipLineText(line) or (line and line:GetText())
    if (texture and type(text) == "string") then
        local ok, hasIcon = pcall(strfind, text, "^|T")
        if (not ok or not hasIcon) then
            line:SetFormattedText("|T%s:16:16:0:0:32:32:2:30:2:30|t %s", texture, text)
        end
    end
end

local function AppendStackCount(tooltip, itemInfo)
    if (not addon.db.item.showItemMaxStack) then
        return
    end

    local stackCount = itemInfo and itemInfo.itemStackCount
    if (type(stackCount) ~= "number" or stackCount <= 1) then
        return
    end

    local line = addon:GetLine(tooltip, 1)
    local text = Util.GetTooltipLineText and Util.GetTooltipLineText(line) or (line and line:GetText())
    if (type(text) ~= "string" or text == "") then
        return
    end

    line:SetText(text .. format(" |cff00eeee/%s|r", stackCount))
end

local function MaybeAddExpansionLine(tooltip, link)
    if (not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden())) then
        return
    end

    local showItemExpansion = addon.db.item.showItemExpansion
    if ((IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown()) and addon.db.item.modifierShowAll) then
        showItemExpansion = true
    end
    if (not showItemExpansion) then
        return
    end

    local itemLink = link
    if (not itemLink and tooltip and tooltip.GetItem) then
        _, _, itemLink = pcall(tooltip.GetItem, tooltip)
    end
    if (not itemLink) then
        return
    end

    local _, _, _, _, _, _, _, _, _, _, _, _, _, _, expansionId = GetItemInfo(itemLink)
    if (type(expansionId) ~= "number") then
        return
    end

    local expansionName = _G["EXPANSION_NAME" .. expansionId]
    if (type(expansionName) ~= "string" or expansionName == "") then
        expansionName = tostring(expansionId)
    end

    local expansionLabel = L["id.expansion"]
    if (addon:FindLine(tooltip, expansionLabel)) then
        return
    end

    local itemLabel = L["id.item"]
    if (not addon:FindLine(tooltip, itemLabel)) then
        tooltip:AddLine(" ")
    end

    tooltip:AddLine(format("%s: |cffffffff%s|r", expansionLabel, expansionName), 0, 1, 0.8)
    tooltip:Show()
end

LibEvent:attachTrigger("tooltip:item", function(self, tooltip, link)
    MaybeAddExpansionLine(tooltip, link)

    local itemInfo = GetItemInfoFromLink(link)
    local quality = (itemInfo and itemInfo.itemQuality) or 0
    local red, green, blue = GetItemQualityColor(quality)

    local titleRed, titleGreen, titleBlue = GetTooltipTitleColor(tooltip)
    if (titleRed and titleGreen and titleBlue) then
        red, green, blue = titleRed, titleGreen, titleBlue
    end

    ApplyItemStyle(tooltip, red, green, blue)
    AppendStackCount(tooltip, itemInfo)
    PrependItemIcon(tooltip, itemInfo)
end)

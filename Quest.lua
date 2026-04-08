local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local Util = addon.Util or {}

local function ApplyQuestBorderColor(tip, r, g, b)
    if (addon.db.quest and addon.db.quest.coloredQuestBorder) then
        LibEvent:trigger("tooltip.style.border.color", tip, r, g, b)
    end
end

local function ParseQuestIdFromLink(link)
    if (type(link) ~= "string") then return end
    local questId = link:match("|?H?quest:(%-?%d+):")
    if (questId) then
        return tonumber(questId)
    end
end

local function GetQuestColor(questId)
    if (type(questId) ~= "number" or not C_QuestLog or not C_QuestLog.GetQuestDifficultyLevel) then
        return
    end

    local level = Util.SafeCall(C_QuestLog.GetQuestDifficultyLevel, questId)
    if (type(level) ~= "number") then return end

    local playerLevel = Util.SafeCall(UnitLevel, "player")
    if (type(playerLevel) ~= "number") then
        playerLevel = 1
    end

    local colorLevel = (level < 0) and playerLevel or level
    local color = Util.SafeCall(GetQuestDifficultyColor, colorLevel)
    if (type(color) == "table" and color.r and color.g and color.b) then
        return color.r, color.g, color.b
    end
end

local function UpdateQuestTooltipBorder(tip, link)
    local questId = ParseQuestIdFromLink(link)
    if (not questId) then return end

    local r, g, b = GetQuestColor(questId)
    if (r and g and b) then
        ApplyQuestBorderColor(tip, r, g, b)
    end
end

if (ItemRefTooltip and ItemRefTooltip.SetHyperlink) then
    hooksecurefunc(ItemRefTooltip, "SetHyperlink", function(self, link)
        UpdateQuestTooltipBorder(self, link)
    end)
end

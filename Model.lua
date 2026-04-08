local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local Util = addon.Util or {}

local MODEL_SIZE = 100
local MODEL_FACING = -0.25

local function EnsureTooltipModel(tooltip)
    if (tooltip ~= GameTooltip or tooltip.model) then
        return
    end

    local model = CreateFrame("PlayerModel", nil, tooltip)
    model:SetSize(MODEL_SIZE, MODEL_SIZE)
    model:SetFacing(MODEL_FACING)
    model:SetPoint("BOTTOMRIGHT", tooltip, "TOPRIGHT", 8, -16)
    model:Hide()
    model:SetScript("OnUpdate", function(self, elapsed)
        if (IsControlKeyDown() or IsAltKeyDown()) then
            self:SetFacing(self:GetFacing() + math.pi * elapsed)
        end
    end)

    tooltip.model = model
end

local function ResetTooltipModel(tooltip)
    if (tooltip ~= GameTooltip or not tooltip.model) then
        return
    end

    tooltip.model:ClearModel()
    tooltip.model:Hide()
end

local function ShouldShowModelForUnit(unit)
    if (unit ~= "mouseover") then
        return false
    end
    if (not Util.SafeBool or not Util.SafeBool(UnitExists, unit)) then
        return false
    end
    if (not Util.SafeBool(UnitIsVisible, unit)) then
        return false
    end

    if (Util.SafeBool(UnitIsPlayer, unit)) then
        return addon.db.unit.player.showModel == true
    end

    return addon.db.unit.npc.showModel == true
end

local function UpdateTooltipModel(tooltip, unit)
    if (tooltip ~= GameTooltip or not tooltip.model) then
        return
    end

    if (ShouldShowModelForUnit(unit)) then
        tooltip.model:SetUnit(unit)
        tooltip.model:SetFacing(MODEL_FACING)
        tooltip.model:Show()
        return
    end

    ResetTooltipModel(tooltip)
end

LibEvent:attachTrigger("tooltip:init", function(self, tooltip)
    EnsureTooltipModel(tooltip)
end)

LibEvent:attachTrigger("tooltip:unit", function(self, tooltip, unit)
    UpdateTooltipModel(tooltip, unit)
end)

LibEvent:attachTrigger("tooltip:cleared", function(self, tooltip)
    ResetTooltipModel(tooltip)
end)

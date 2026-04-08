local addon = TinyTooltip
if not addon then return end

local LibEvent = LibStub and LibStub:GetLibrary("LibEvent.7000", true)
if not LibEvent then return end

local scaleDetectorInstalled = false
local dialogueHooksInstalled = false

local function GetUiScale()
    if (UIParent and UIParent.GetEffectiveScale) then
        return UIParent:GetEffectiveScale()
    end
    return 1
end

local function GetDialogueScaleFactor()
    return addon._dialogueScaleFactor or 1
end

local function GetDesiredTooltipScale()
    local general = addon.db and addon.db.general
    local baseScale = (general and general.scale) or 1
    return baseScale * GetDialogueScaleFactor()
end

local function ForEachTooltip(callback)
    if (type(callback) ~= "function") then return end
    for _, tip in ipairs(addon.tooltips or {}) do
        if (tip) then
            callback(tip)
        end
    end
end

local function ApplyScaledTooltips()
    if (not addon.db or not addon.db.general) then return end
    local desiredScale = GetDesiredTooltipScale()
    addon._applyingDialogueScale = true
    ForEachTooltip(function(tip)
        LibEvent:trigger("tooltip.scale", tip, desiredScale)
    end)
    addon._applyingDialogueScale = nil
end

local function EnableDialogueScale()
    addon._dialogueActive = true
    addon._dialogueScaleFactor = GetUiScale()
    ApplyScaledTooltips()
end

local function DisableDialogueScale()
    addon._dialogueActive = nil
    addon._dialogueScaleFactor = nil
    ApplyScaledTooltips()
end

local function HookDialogueUI()
    if (dialogueHooksInstalled) then return end
    local dialogue = _G.DialogueUI
    local rewardTooltipCode = dialogue and dialogue.RewardTooltipCode
    if (not rewardTooltipCode) then return end

    hooksecurefunc(rewardTooltipCode, "TakeOutGameTooltip", EnableDialogueScale)
    hooksecurefunc(rewardTooltipCode, "RestoreGameTooltip", DisableDialogueScale)
    dialogueHooksInstalled = true
end

local function IsDialogueStack()
    if (not debugstack) then return false end
    local ok, stack = pcall(debugstack, 2, 6, 2)
    if (not ok or type(stack) ~= "string") then return false end
    return stack:find("DialogueUI/Code/Dialogue/RewardTooltipCode.lua", 1, true) ~= nil
end

local function IsApproximately(left, right)
    if (type(left) ~= "number" or type(right) ~= "number") then
        return false
    end
    return math.abs(left - right) < 0.0001
end

local function OnTooltipSetScale(_, scale)
    if (addon._applyingDialogueScale) then return end
    local uiScale = GetUiScale()
    local isDialogue = IsDialogueStack()

    if (isDialogue and IsApproximately(scale, uiScale)) then
        if (not addon._dialogueActive) then
            EnableDialogueScale()
        end
        return
    end

    if (isDialogue and IsApproximately(scale, 1)) then
        if (addon._dialogueActive) then
            DisableDialogueScale()
        end
    end
end

local function HookTooltipScale(tip)
    if (not tip or not tip.SetScale or tip.TinyTooltipDialogueHooked) then return end
    tip.TinyTooltipDialogueHooked = true
    hooksecurefunc(tip, "SetScale", OnTooltipSetScale)
end

local function HookTooltipScaleDetect()
    if (not scaleDetectorInstalled) then
        local tips = {
            GameTooltip,
            ShoppingTooltip1,
            ShoppingTooltip2,
            GarrisonFollowerTooltip,
        }
        for _, tip in ipairs(tips) do
            HookTooltipScale(tip)
        end
        scaleDetectorInstalled = true
    end

    ForEachTooltip(HookTooltipScale)
end

local function AdjustScaleIfDialogue(frame)
    if (not addon._dialogueActive or addon._applyingDialogueScale) then return end
    if (not frame or not frame.SetScale) then return end

    addon._applyingDialogueScale = true
    frame:SetScale(GetDesiredTooltipScale())
    addon._applyingDialogueScale = nil
end

LibEvent:attachTrigger("tooltip.scale", function(self, frame)
    AdjustScaleIfDialogue(frame)
end)

LibEvent:attachTrigger("tooltip:show", function(self, frame)
    AdjustScaleIfDialogue(frame)
end)

LibEvent:attachTrigger("tooltip:init", function(self, frame)
    HookTooltipScale(frame)
    AdjustScaleIfDialogue(frame)
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, _, name)
    if (name ~= "DialogueUI") then return end
    HookTooltipScaleDetect()
    HookDialogueUI()
end)

if (IsAddOnLoaded and IsAddOnLoaded("DialogueUI")) then
    HookTooltipScaleDetect()
    HookDialogueUI()
end

HookTooltipScaleDetect()

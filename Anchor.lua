local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")

local GetMouseFocus = GetMouseFocus or GetMouseFoci

local addon = TinyTooltip
local Util = addon.Util or {}
local SafeBool = Util.SafeBool or function(fn, ...)
    local ok, value = pcall(fn, ...)
    return ok and value == true or false
end
local SafeCall = Util.SafeCall or function(fn, ...)
    local ok, a, b, c = pcall(fn, ...)
    if (ok) then
        return a, b, c
    end
end

local modifierStateOverrideKey
local modifierStateOverrideDown
local dbGeneralAnchor
local dbPlayerAnchor
local dbNpcAnchor

local function CacheAnchorSetting()
    local db = addon and addon.db
    if (not db) then
        dbGeneralAnchor = nil
        dbPlayerAnchor = nil
        dbNpcAnchor = nil
        return
    end

    dbGeneralAnchor = db.general and db.general.anchor
    dbPlayerAnchor = db.unit and db.unit.player and db.unit.player.anchor
    dbNpcAnchor = db.unit and db.unit.npc and db.unit.npc.anchor
end

local function IsConfiguredModifierDown(modifierKey)
    if (modifierKey and modifierKey == modifierStateOverrideKey and modifierStateOverrideDown ~= nil) then
        return modifierStateOverrideDown
    end
    if (modifierKey == "alt") then
        return IsAltKeyDown()
    elseif (modifierKey == "ctrl") then
        return IsControlKeyDown()
    elseif (modifierKey == "shift") then
        return IsShiftKeyDown()
    end
    return false
end

local function GetAnchorModifierKey(anchor)
    local modifierKey = anchor and anchor.modifierShowInCombatKey
    if (modifierKey == "global") then
        modifierKey = dbGeneralAnchor and dbGeneralAnchor.modifierShowInCombatKey
    end
    if (modifierKey == "alt" or modifierKey == "ctrl" or modifierKey == "shift") then
        return modifierKey
    end
    return "none"
end

local function ShouldHideInCombat(anchor)
    if (not anchor or not anchor.hiddenInCombat or not InCombatLockdown()) then
        return false
    end

    local modifierKey = GetAnchorModifierKey(anchor)
    if (modifierKey ~= "none" and IsConfiguredModifierDown(modifierKey)) then
        return false
    end

    return true
end

local function SafeSetOwner(frame, parent, anchorType, ...)
    if (not frame or not frame.SetOwner) then return end
    if (not parent or type(parent) ~= "table") then
        parent = UIParent
    end
    pcall(frame.SetOwner, frame, parent, anchorType, ...)
end

local function IsStaticAnchorPosition(anchor)
    return anchor and anchor.position == "static"
end

local function ResolveStaticAnchor(anchor)
    if (not anchor) then
        return dbGeneralAnchor
    end
    if (anchor.position == "inherit") then
        return dbGeneralAnchor
    end
    return anchor
end

local function AnchorCursorOnExecute(task)
    if (not task.tip or not task.tip:IsShown()) then
        return true
    end

    local anchorType = task.tip:GetAnchorType()
    if (anchorType ~= "ANCHOR_CURSOR" and anchorType ~= "ANCHOR_NONE") then
        return true
    end

    local cursorX, cursorY = GetCursorPosition()
    task.tip:ClearAllPoints()
    task.tip:SetPoint(
        task.point,
        UIParent,
        "BOTTOMLEFT",
        floor(cursorX / task.scale + task.offsetX),
        floor(cursorY / task.scale + task.offsetY)
    )
end

local function StartCursorAnchorTracking(tip, point, offsetX, offsetY)
    local cursorX, cursorY = GetCursorPosition()
    local scale = tip:GetEffectiveScale()

    tip:ClearAllPoints()
    tip:SetPoint(point, UIParent, "BOTTOMLEFT", floor(cursorX / scale + offsetX), floor(cursorY / scale + offsetY))

    LibSchedule:AddTask({
        identity = tostring(tip),
        elasped = 0.01,
        expired = GetTime() + 300,
        override = true,
        tip = tip,
        point = point,
        offsetX = offsetX,
        offsetY = offsetY,
        scale = scale,
        onExecute = AnchorCursorOnExecute,
    })
end

local function ApplyDefaultAnchor(tip, parent, anchor)
    local resolvedAnchor = ResolveStaticAnchor(anchor)
    if (not resolvedAnchor) then return end
    LibEvent:trigger("tooltip.anchor.static", tip, parent, resolvedAnchor.x, resolvedAnchor.y, resolvedAnchor.p)
end

local function ResolveCombatAnchorRule(anchor, combatAnchor)
    local hideAnchor = combatAnchor or anchor
    if (
        hideAnchor
        and hideAnchor ~= dbGeneralAnchor
        and not hideAnchor.hiddenInCombat
        and not hideAnchor.returnInCombat
        and not hideAnchor.returnOnUnitFrame
    ) then
        hideAnchor = dbGeneralAnchor
    end
    return hideAnchor
end

local function AnchorFrame(tip, parent, anchor, isUnitFrame, combatAnchor)
    if (not tip) then return end

    local activeAnchor = anchor or dbGeneralAnchor
    local hideAnchor = ResolveCombatAnchorRule(activeAnchor, combatAnchor)
    if (ShouldHideInCombat(hideAnchor)) then
        return LibEvent:trigger("tooltip.anchor.none", tip, parent)
    end
    if (not activeAnchor) then return end

    if (hideAnchor and hideAnchor.returnInCombat and InCombatLockdown()) then
        return ApplyDefaultAnchor(tip, parent, hideAnchor)
    end
    if (hideAnchor and hideAnchor.returnOnUnitFrame and isUnitFrame) then
        return ApplyDefaultAnchor(tip, parent, hideAnchor)
    end

    if (activeAnchor.position == "cursorRight") then
        LibEvent:trigger("tooltip.anchor.cursor.right", tip, parent)
        return
    end

    if (activeAnchor.position == "cursor") then
        local offsetX = tonumber(activeAnchor.cx) or 0
        local offsetY = tonumber(activeAnchor.cy) or 0
        local point = activeAnchor.cp or "BOTTOM"
        if (offsetX == 0 and offsetY == 0 and point == "BOTTOM") then
            LibEvent:trigger("tooltip.anchor.cursor", tip, parent)
        else
            SafeSetOwner(tip, parent, "ANCHOR_CURSOR")
            StartCursorAnchorTracking(tip, point, offsetX, offsetY)
        end
        return
    end

    if (activeAnchor.position == "inherit") then
        return ApplyDefaultAnchor(tip, parent, activeAnchor)
    end

    if (IsStaticAnchorPosition(activeAnchor)) then
        LibEvent:trigger("tooltip.anchor.static", tip, parent, activeAnchor.x, activeAnchor.y, activeAnchor.p)
    end
end

local function GetFocusedUnit()
    local focus = GetMouseFocus()
    if (not focus) then
        return "mouseover", false
    end

    local directUnit = SafeCall(function(frame)
        return frame.unit
    end, focus)
    if (directUnit) then
        return directUnit, true
    end

    if (focus.GetAttribute) then
        local attributeUnit = SafeCall(focus.GetAttribute, focus, "unit")
        if (attributeUnit) then
            return attributeUnit, true
        end
    end

    return "mouseover", false
end

local function GetContextualAnchor(unit)
    if (SafeBool(UnitIsPlayer, unit)) then
        return dbPlayerAnchor or dbGeneralAnchor
    end
    if (SafeBool(UnitExists, unit)) then
        return dbNpcAnchor or dbGeneralAnchor
    end
    return dbGeneralAnchor
end

local function GetMouseoverContext()
    local unit, isUnitFrame = GetFocusedUnit()
    local combatAnchor = GetContextualAnchor(unit)
    local activeAnchor = combatAnchor
    if (activeAnchor and activeAnchor.position == "inherit") then
        activeAnchor = dbGeneralAnchor
    end
    if (not combatAnchor) then
        combatAnchor = activeAnchor
    end
    return unit, isUnitFrame, activeAnchor, combatAnchor
end

local function IsModifierStateMatch(modifierKey, changedKey)
    local normalizedKey = changedKey and strupper(changedKey)
    if (modifierKey == "alt") then
        return normalizedKey == "LALT" or normalizedKey == "RALT" or normalizedKey == "ALT"
    elseif (modifierKey == "ctrl") then
        return normalizedKey == "LCTRL" or normalizedKey == "RCTRL" or normalizedKey == "CTRL"
    elseif (modifierKey == "shift") then
        return normalizedKey == "LSHIFT" or normalizedKey == "RSHIFT" or normalizedKey == "SHIFT"
    end
    return false
end

local function RefreshTooltipForModifier(unit)
    if (unit == "mouseover" and GameTooltip.SetMouseoverUnit) then
        pcall(GameTooltip.SetMouseoverUnit, GameTooltip)
        return
    end
    pcall(GameTooltip.SetUnit, GameTooltip, unit)
end

LibEvent:attachTrigger("tooltip:anchor", function(self, tip, parent)
    if (tip ~= GameTooltip) then return end
    if (tip._tinySkipCustomAnchor) then
        tip._tinySkipCustomAnchor = nil
        return
    end

    local _, isUnitFrame, activeAnchor, combatAnchor = GetMouseoverContext()
    AnchorFrame(tip, parent, activeAnchor, isUnitFrame, combatAnchor)
end)

local modifierWatcher = CreateFrame("Frame")
modifierWatcher:RegisterEvent("MODIFIER_STATE_CHANGED")
modifierWatcher:SetScript("OnEvent", function(_, _, key, state)
    if (not InCombatLockdown()) then return end

    local unit, isUnitFrame, activeAnchor, combatAnchor = GetMouseoverContext()
    local ruleAnchor = ResolveCombatAnchorRule(activeAnchor, combatAnchor)
    if (not SafeBool(UnitExists, unit) or not ruleAnchor or not ruleAnchor.hiddenInCombat) then return end

    local modifierKey = GetAnchorModifierKey(ruleAnchor)
    if (modifierKey == "none" or not IsModifierStateMatch(modifierKey, key)) then
        return
    end

    local isDown = tonumber(state) == 1
    modifierStateOverrideKey = modifierKey
    modifierStateOverrideDown = isDown

    AnchorFrame(GameTooltip, GameTooltip:GetOwner() or UIParent, activeAnchor, isUnitFrame, ruleAnchor)

    local shouldHide = ShouldHideInCombat(ruleAnchor)
    if (isDown) then
        RefreshTooltipForModifier(unit)
    end
    if (not shouldHide and not GameTooltip:IsShown()) then
        GameTooltip:Show()
    end

    modifierStateOverrideKey = nil
    modifierStateOverrideDown = nil
end)

CacheAnchorSetting()
LibEvent:attachTrigger("tooltip:variables:loaded, tooltip:variable:changed", function()
    CacheAnchorSetting()
end)

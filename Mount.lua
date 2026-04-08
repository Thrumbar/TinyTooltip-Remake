local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibSchedule = LibStub:GetLibrary("LibSchedule.7000")

local addon = TinyTooltip
local L = addon.L or {}
local mountCache = {}

if (not C_MountJournal) then
    return
end

local function BuildMountCache()
    local mountIds = C_MountJournal.GetMountIDs()
    if (type(mountIds) ~= "table") then
        return false
    end

    local cachedCount = 0
    for _, mountId in ipairs(mountIds) do
        local name, spellId, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountId)
        if (spellId) then
            local _, _, source = C_MountJournal.GetMountInfoExtraByID(mountId)
            mountCache[spellId] = {
                source = source,
                isCollected = isCollected,
                mountId = mountId,
                name = name,
            }
            cachedCount = cachedCount + 1
        end
    end

    return cachedCount > 0
end

LibEvent:attachEvent("VARIABLES_LOADED", function()
    LibSchedule:AddTask({
        identity = "TinyTooltipRemake.BuildMountCache",
        elasped = 10,
        begined = GetTime() + 2,
        expired = GetTime() + 100,
        override = true,
        onExecute = BuildMountCache,
    })
end)

LibEvent:attachTrigger("tooltip:aura", function(self, tooltip, args)
    local spellId = args and args[2] and args[2].intVal
    local mountInfo = spellId and mountCache[spellId]
    if (not mountInfo) then
        return
    end

    local sourceText = mountInfo.source
    if (type(sourceText) ~= "string" or sourceText == "") then
        sourceText = mountInfo.name or ""
    end

    tooltip:AddLine(" ")
    if (mountInfo.isCollected) then
        tooltip:AddDoubleLine(sourceText, L["collected"], 1, 1, 1, 0.1, 1, 0.1)
    else
        tooltip:AddLine(sourceText, 1, 1, 1)
    end
    tooltip:Show()
end)

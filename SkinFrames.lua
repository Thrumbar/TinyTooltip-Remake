local LibEvent = LibStub:GetLibrary("LibEvent.7000")

local addon = TinyTooltip
local registeredFrames = setmetatable({}, { __mode = "k" })

local function GetFrameCandidates()
    return {
        _G.AtlasLootTooltip,
        _G.QuestHelperTooltip,
        _G.QuestGuru_QuestWatchTooltip,
        _G.ChatMenu,
        _G.EmoteMenu,
        _G.LanguageMenu,
        _G.VoiceMacroMenu,
        _G.DropDownList1MenuBackdrop,
        _G.DropDownList2MenuBackdrop,
        _G.AutoCompleteBox,
        _G.FriendsTooltip,
        _G.FriendsMenuXPMenuBackdrop,
        _G.FriendsMenuXPSecureMenuBackdrop,
        _G.GeneralDockManagerOverflowButtonList,
        _G.QueueStatusFrame,
        _G.BattlePetTooltip,
        _G.PetBattlePrimaryAbilityTooltip,
        _G.PetBattlePrimaryUnitTooltip,
        _G.FloatingBattlePetTooltip,
        _G.FloatingPetBattleAbilityTooltip,
        _G.GarrisonMissionMechanicTooltip,
        _G.GarrisonMissionMechanicFollowerCounterTooltip,
        _G.GarrisonShipyardMapMissionTooltip,
        _G.GarrisonBonusAreaTooltip,
        _G.FloatingGarrisonShipyardFollowerTooltip,
        _G.GarrisonShipyardFollowerTooltip,
        _G.GarrisonFollowerAbilityWithoutCountersTooltip,
        _G.GarrisonFollowerMissionAbilityWithoutCountersTooltip,
        _G.FloatingGarrisonFollowerTooltip,
        _G.FloatingGarrisonFollowerAbilityTooltip,
        _G.FloatingGarrisonMissionTooltip,
        _G.GarrisonFollowerAbilityTooltip,
        _G.GarrisonFollowerTooltip,
        _G.QuestScrollFrame and _G.QuestScrollFrame.StoryTooltip,
    }
end

local function RegisterFrame(frame)
    if (not frame or registeredFrames[frame] or frame._tinyNativeStyle) then
        return
    end

    registeredFrames[frame] = true
    tinsert(addon.tooltips, frame)

    if (addon.db and addon.db.general and addon.db.general.skinMoreFrames) then
        LibEvent:trigger("tooltip.style.init", frame)
        LibEvent:trigger("tooltip.scale", frame, addon.db.general.scale)
        LibEvent:trigger("tooltip.style.mask", frame, addon.db.general.mask)
        LibEvent:trigger("tooltip.style.bgfile", frame, addon.db.general.bgfile)
        LibEvent:trigger("tooltip.style.border.corner", frame, addon.db.general.borderCorner)
        LibEvent:trigger("tooltip.style.border.size", frame, addon.db.general.borderSize)
        LibEvent:trigger("tooltip.style.border.color", frame, unpack(addon.db.general.borderColor))
        LibEvent:trigger("tooltip.style.background", frame, unpack(addon.db.general.background))
    end
end

local function RefreshRegisteredFrames()
    if (not addon.db or not addon.db.general or not addon.db.general.skinMoreFrames) then
        return
    end

    for _, frame in ipairs(GetFrameCandidates()) do
        RegisterFrame(frame)
    end
end

LibEvent:attachTrigger("tooltip:variables:loaded", function()
    RefreshRegisteredFrames()
end)

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if (event == "ADDON_LOADED") then
        if (addonName == "Blizzard_GarrisonUI" or addonName == "Blizzard_PetBattleUI") then
            RefreshRegisteredFrames()
        end
        return
    end

    RefreshRegisteredFrames()
end)

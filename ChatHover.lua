local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
    or (Constants and Constants.ChatFrameConstants and Constants.ChatFrameConstants.MaxChatWindows)
    or 10

local supportedHyperlinkTypes = {
    achievement = true,
    battlepet = true,
    currency = true,
    enchant = true,
    item = true,
    journal = true,
    mount = true,
    quest = true,
    spell = true,
}

local hookedFrames = {}
local showingTooltip

local function GetLinkType(link)
    if (type(link) ~= "string") then return end
    return link:match("^([^:]+):")
end

local function ResetAnchorOverride()
    GameTooltip._tinySkipCustomAnchor = nil
end

local function HideShowingTooltip()
    if (showingTooltip and showingTooltip.Hide) then
        pcall(showingTooltip.Hide, showingTooltip)
    end
    showingTooltip = nil
end

local function ClearCurrentTooltipState()
    HideShowingTooltip()
    if (GameTooltip and GameTooltip.Hide) then
        pcall(GameTooltip.Hide, GameTooltip)
    end
    ResetAnchorOverride()
end

local function SetTooltipOwner(frame, tooltip)
    tooltip = tooltip or GameTooltip
    if (not tooltip or not tooltip.SetOwner) then return end
    GameTooltip._tinySkipCustomAnchor = true
    pcall(tooltip.SetOwner, tooltip, frame or UIParent, "ANCHOR_CURSOR")
end

local function ShowBattlePetLink(frame, text)
    if (not BattlePetToolTip_ShowLink or not BattlePetTooltip) then
        return false
    end
    SetTooltipOwner(frame, BattlePetTooltip)
    showingTooltip = BattlePetTooltip
    local ok = pcall(BattlePetToolTip_ShowLink, text)
    if (not ok) then
        HideShowingTooltip()
        ResetAnchorOverride()
    end
    return ok
end

local function ShowHyperlinkTooltip(frame, link)
    if (not GameTooltip or not GameTooltip.SetHyperlink) then
        return false
    end
    SetTooltipOwner(frame, GameTooltip)
    showingTooltip = GameTooltip
    local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
    if (ok and GameTooltip.Show) then
        pcall(GameTooltip.Show, GameTooltip)
        return true
    end
    HideShowingTooltip()
    ResetAnchorOverride()
    return false
end

local function OnHyperlinkEnter(frame, link, text)
    local linkType = GetLinkType(link)
    if (linkType) then
        linkType = string.lower(linkType)
    end
    if (not linkType or not supportedHyperlinkTypes[linkType]) then return end

    ClearCurrentTooltipState()

    if (linkType == "battlepet") then
        if (ShowBattlePetLink(frame, text)) then
            return
        end
    end

    ShowHyperlinkTooltip(frame, link)
end

local function OnHyperlinkLeave()
    ClearCurrentTooltipState()
end

local function HookChatFrame(frame)
    if (not frame or hookedFrames[frame] or not frame.HookScript) then return end
    frame:HookScript("OnHyperlinkEnter", OnHyperlinkEnter)
    frame:HookScript("OnHyperlinkLeave", OnHyperlinkLeave)
    hookedFrames[frame] = true
end

local function HookDefaultChatFrames()
    for i = 1, NUM_CHAT_WINDOWS do
        HookChatFrame(_G["ChatFrame" .. i])
    end
end

local function HookCommunitiesChatFrame()
    local communities = _G.CommunitiesFrame
    local frame = communities and communities.Chat and communities.Chat.MessageFrame
    HookChatFrame(frame)
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("UPDATE_CHAT_WINDOWS")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addonName)
    if (event == "ADDON_LOADED") then
        if (addonName == "Blizzard_Communities") then
            HookCommunitiesChatFrame()
        end
        return
    end

    HookDefaultChatFrames()
    HookCommunitiesChatFrame()
end)

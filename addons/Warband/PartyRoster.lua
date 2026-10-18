-- Warband party roster: a Party tab on the Friends frame (opened with O).
--
-- The client has no party-management window at all: the Friends frame's Raid tab manages raids, not
-- who is standing next to you and who could be invited. This file adds the missing window where a
-- player looks for social things.
--
-- Data comes from the server: `.warband party` answers with one line per character on the account
-- (name|class|level|online|grouped), chunked into a few chat lines and closed by an empty one. The
-- buttons then send the commands Playerbots already owns - `.playerbots bot add <name>` and
-- `.playerbots bot remove <name>` - so nothing about invitations is reimplemented here.
--
-- The tab is created defensively: the exact tab template is a client detail that cannot be read
-- from the MPQs in this repository, so a missing template falls back to a plain button rather than
-- raising an error mid-file.

local TAB_TITLE = "Party"
local REPLY_TIMEOUT = 6
local REFRESH_DELAY = 1.5
local ROW_HEIGHT = 20
local ROW_SLOTS = 16

-- Our tab sits after the client's own. Selecting that index is what makes Blizzard's
-- FriendsFrame_Update hide its own content panes: none of its branches match, so it hides them all
-- and we draw ours on top.
local OUR_TAB_INDEX = 6

local CLASS_NAMES = {
    [1] = "Warrior", [2] = "Paladin", [3] = "Hunter", [4] = "Rogue", [5] = "Priest",
    [6] = "Death Knight", [7] = "Shaman", [8] = "Mage", [9] = "Warlock", [11] = "Druid",
}

-- Class id to the token RAID_CLASS_COLORS is keyed by. Written out rather than looked up: a 3.3.5
-- client has no GetClassInfo, and calling it threw inside the renderer, which is what stopped the
-- roster from drawing at all.
local CLASS_TOKENS = {
    [1] = "WARRIOR", [2] = "PALADIN", [3] = "HUNTER", [4] = "ROGUE", [5] = "PRIEST",
    [6] = "DEATHKNIGHT", [7] = "SHAMAN", [8] = "MAGE", [9] = "WARLOCK", [11] = "DRUID",
}

local tab
local panel
local statusText
local rows = {}
local roster = {}
local request = { pending = false, deadline = nil }
local refreshAt

local function SetStatus(text, color)
    if statusText then
        statusText:SetText(text)
        statusText:SetTextColor(color[1], color[2], color[3])
    end
end

local function ClassColour(classId)
    local classToken = CLASS_TOKENS[classId]
    local colours = RAID_CLASS_COLORS

    if colours and classToken and colours[classToken] then
        local colour = colours[classToken]
        return colour.r, colour.g, colour.b
    end

    return 1, 1, 1
end

local function SendBotCommand(action, name)
    -- Logging a bot out does not take it out of the group: Playerbots' logout cleanup only saves its
    -- AI state. So a dismiss removes the member first, then logs the character out.
    if action == "remove" and UninviteUnit then
        UninviteUnit(name)
    end

    SendChatMessage(".playerbots bot " .. action .. " " .. name, "SAY")
    SetStatus("Sent " .. action .. " for " .. name .. "...", { 1, 0.7, 0 })
    refreshAt = GetTime() + REFRESH_DELAY
end

local function CreateRow(index)
    local row = CreateFrame("Button", "WarbandPartyRow" .. index, panel)
    row:SetHeight(ROW_HEIGHT)

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("LEFT", row, "LEFT", 4, 0)
    name:SetJustifyH("LEFT")

    local state = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    state:SetPoint("LEFT", row, "LEFT", 150, 0)
    state:SetJustifyH("LEFT")

    local action = CreateFrame("Button", "WarbandPartyRowAction" .. index, row,
        "UIPanelButtonTemplate")
    action:SetSize(90, 18)
    action:SetPoint("RIGHT", row, "RIGHT", -4, 0)

    action:SetScript("OnClick", function(self)
        if self.memberName then
            SendBotCommand(self.memberAction, self.memberName)
        end
    end)

    row.nameText = name
    row.stateText = state
    row.action = action

    row:Hide()

    return row
end

local function LayoutRow(row, index)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -26 - (index - 1) * ROW_HEIGHT)
    row:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -26 - (index - 1) * ROW_HEIGHT)
end

local function FillRow(row, index, entry)
    local classR, classG, classB = ClassColour(entry.class)

    row.nameText:SetText(entry.name)
    row.nameText:SetTextColor(classR, classG, classB)

    local pieces = {}

    if entry.level > 0 then
        table.insert(pieces, "Level " .. entry.level)
    end

    local className = CLASS_NAMES[entry.class]
    if className then
        table.insert(pieces, className)
    end

    table.insert(pieces, entry.online and "online" or "offline")

    row.stateText:SetText(table.concat(pieces, " - "))

    local shade = entry.online and 0.85 or 0.55
    row.stateText:SetTextColor(shade, shade, shade)

    -- A running character is one of the bots already; anything else is a candidate to invite.
    if entry.online then
        row.action:SetText("Dismiss")
        row.action.memberAction = "remove"
    else
        row.action:SetText("Invite")
        row.action.memberAction = "add"
    end

    row.action.memberName = entry.name
    row.action:Enable()

    LayoutRow(row, index)
    row:Show()
end

local function RenderRoster()
    local onlineCount = 0

    for _, entry in ipairs(roster) do
        if entry.online then
            onlineCount = onlineCount + 1
        end
    end

    SetStatus(string.format("%d character(s) on this account, %d online", #roster, onlineCount),
        { 1, 0.82, 0 })

    -- Any failure while drawing shows up in the status line instead of vanishing into a Lua error,
    -- and the data is echoed to chat so the roster is still usable.
    local ok, err = pcall(function()
        for index, entry in ipairs(roster) do
            local row = rows[index]

            if not row then
                row = CreateRow(index)
                rows[index] = row
            end

            FillRow(row, index, entry)
        end

        for index = #roster + 1, #rows do
            rows[index]:Hide()
        end
    end)

    if not ok then
        SetStatus("Roster display failed: " .. tostring(err), { 1, 0.25, 0.25 })

        for _, entry in ipairs(roster) do
            print(string.format("|cff4CFF00Warband|r %s - level %d - %s", entry.name, entry.level,
                entry.online and "online" or "offline"))
        end
    end
end

local function ParsePayload(payload)
    for entry in string.gmatch(payload, "([^;]+)") do
        local name, classId, level, online, grouped =
            string.match(entry, "^([^|]+)|(%d+)|(%d+)|(%d+)|(%d+)$")

        if name then
            table.insert(roster, {
                name = name,
                class = tonumber(classId) or 0,
                level = tonumber(level) or 0,
                online = online == "1",
                grouped = grouped == "1",
            })
        end
    end
end

local function RequestRoster()
    roster = {}
    request.pending = true
    request.deadline = GetTime() + REPLY_TIMEOUT

    SetStatus("Reading the account's characters...", { 1, 0.7, 0 })
    SendChatMessage(".warband party", "SAY")
end

-- The panes the client draws inside the Friends frame. They are hidden by name because the frame's
-- own update routine does not recognise our tab index and therefore leaves the last one showing.
local BLIZZARD_PANES = {
    "FriendsFrameFriendsScrollFrame",
    "FriendsFrameInset",
    "WhoFrame",
    "WhoFrameScrollFrame",
    "IgnoreFrame",
    "RaidFrame",
    "RaidFrameInfo",
}

local function HideBlizzardPanes()
    for _, paneName in ipairs(BLIZZARD_PANES) do
        local pane = _G[paneName]

        if pane and pane.Hide then
            pane:Hide()
        end
    end
end

local function CreatePanel()
    -- Anchor to the client's own friends list, not to the frame or its inset: that scroll frame is
    -- by definition the usable content rectangle of this window, in whatever proportions this
    -- client build uses. Hiding it later does not disturb the anchors.
    local anchor = FriendsFrameFriendsScrollFrame
        or WhoFrameScrollFrame
        or WhoFrame
        or FriendsFrame

    local frame = CreateFrame("Frame", "WarbandPartyPanel", FriendsFrame)
    frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)

    -- Drawn above whatever the client has there, and opaque, so old contents cannot show through
    -- even if a pane is missed by name.
    frame:SetFrameLevel(FriendsFrame:GetFrameLevel() + 20)
    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
    frame:EnableMouse(true)
    frame:Hide()

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    statusText:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -8)

    local refresh = CreateFrame("Button", "WarbandPartyRefresh", frame, "UIPanelButtonTemplate")
    refresh:SetSize(80, 18)
    refresh:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", RequestRoster)

    return frame
end

local function CreateTabButton()
    local templates = { "FriendsFrameTabButtonTemplate", "CharacterFrameTabButtonTemplate", nil }

    for _, template in ipairs(templates) do
        local ok, button = pcall(CreateFrame, "Button", "WarbandPartyTab", FriendsFrame, template)

        if ok and button then
            return button
        end
    end

    return nil
end

local function SelectOurTab()
    -- Tell the frame which tab is selected, then let its own update routine run, then hide its
    -- panes by name: the routine has no branch for our index and leaves the previous tab's pane up.
    if PanelTemplates_SetTab then
        PanelTemplates_SetTab(FriendsFrame, OUR_TAB_INDEX)
    end

    if FriendsFrame_Update then
        FriendsFrame_Update()
    end

    HideBlizzardPanes()

    panel:Show()
    RequestRoster()
end

local function Init()
    if not FriendsFrame then
        return
    end

    tab = CreateTabButton()

    if tab then
        local lastTab

        for index = 1, 6 do
            local existing = _G["FriendsFrameTab" .. index]

            if existing then
                lastTab = existing
            end
        end

        if lastTab then
            tab:SetPoint("LEFT", lastTab, "RIGHT", -8, 0)
        else
            tab:SetPoint("BOTTOMLEFT", FriendsFrame, "BOTTOMLEFT", 20, 4)
        end

        tab:SetText(TAB_TITLE)
        tab:SetScript("OnClick", SelectOurTab)
    end

    panel = CreatePanel()

    -- Build the row slots once, at load. Creating frames later, while answering a chat message, is
    -- the part that failed silently in the live client, so every slot exists from the start and
    -- rendering only fills and shows them.
    for index = 1, ROW_SLOTS do
        rows[index] = CreateRow(index)
    end

    -- Every time the frame refreshes its tabs, our panel follows the selected index. This covers
    -- the built-in tabs being clicked, the frame being reopened, and anything else that calls the
    -- update routine.
    if FriendsFrame_Update then
        hooksecurefunc("FriendsFrame_Update", function()
            if not panel then
                return
            end

            if PanelTemplates_GetSelectedTab(FriendsFrame) == OUR_TAB_INDEX then
                HideBlizzardPanes()
                panel:Show()
            else
                panel:Hide()
            end
        end)
    end

    FriendsFrame:HookScript("OnHide", function()
        panel:Hide()
    end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("CHAT_MSG_SYSTEM")
loader:RegisterEvent("GROUP_ROSTER_UPDATE")
loader:SetScript("OnUpdate", function()
    if refreshAt and GetTime() >= refreshAt then
        refreshAt = nil

        if panel and panel:IsShown() then
            RequestRoster()
        end
    end

    if request.pending and GetTime() >= request.deadline then
        request.pending = false
        SetStatus("The server did not answer .warband party.", { 1, 0.25, 0.25 })
    end
end)

loader:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local addonName = ...

        if addonName ~= "Warband" then
            return
        end

        Init()
        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        local message = ...

        local prefixStart = string.find(message or "", "WARBAND_PARTY=", 1, true)
        if not prefixStart then
            return
        end

        local payload = string.sub(message, prefixStart + #"WARBAND_PARTY=")

        if payload == "" then
            -- The empty line closes the list.
            if request.pending then
                request.pending = false
                RenderRoster()
            end
        else
            ParsePayload(payload)
        end

        return
    end

    if event == "GROUP_ROSTER_UPDATE" and panel and panel:IsShown() and not request.pending then
        refreshAt = GetTime() + REFRESH_DELAY
    end
end)

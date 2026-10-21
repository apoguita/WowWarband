-- Warband Dungeon Finder: the complete destination list, in place of the queue that never matched.
--
-- The finder's own list is the client's, not the server's: the client asks its own copy of the
-- dungeon data which entries to draw (GetLFDChoiceInfo / GetLFDChoiceOrder, see LFDFrame.lua), and
-- that data carries a level window per dungeon - Deadmines 15-25, Stockades 55-65, a Northrend
-- heroic 80-83. A dungeon outside the window is never handed to the UI, so nothing the server sends
-- can make the stock list complete.
--
-- On a Warband the queue itself is pointless as well: one player and their companions have nobody to
-- be matched with, and the server answers a finder pick with travel instead. So this window is not a
-- finder any more - it is the travel menu. The queue view is never drawn: Blizzard's LFDQueueFrame is
-- hidden, and this panel takes the whole window with a plain black background.
--
-- The list comes from the server's own table (`.warband travel <id>` answers it), every dungeon,
-- heroic and raid it has an entrance for, with the level window kept as information rather than used
-- as a filter. Clicking a row travels the party through the same path a finder pick uses.

local ROW_HEIGHT = 16
local ROW_WIDTH = 300
local PAGE_LEVEL_OFFSET = 10

local travelState = {
    destinations = nil,
    incoming = nil,
    requesting = false,
    deadline = 0,
}

local warbandLFDPage
local warbandLFDScroll
local warbandLFDScrollContent
local warbandLFDStatus
local warbandLFDRows = {}
local warbandLFDBuilt = false

-- The DBC's own kinds: 1 dungeon, 2 raid, 5 heroic. A raid entry also carries its size, because a
-- 10-man and its 25-man sibling share a name.
local function KindLabel(kind, difficulty)
    if kind == 5 then
        return "Heroic"
    end

    if kind == 2 then
        if difficulty == 1 or difficulty == 2 then
            return "Raid 25"
        end

        return "Raid 10"
    end

    return "Dungeon"
end

-- The level a dungeon is "for", which is what WoW colours a finder entry by: the entry's
-- recommended level (LFGDungeonInfo's recLevel), asked of the client's own copy of the dungeon data.
-- If that lookup is not available, the listed minimum level is the closest honest answer.
local function RecommendedLevel(id, fallbackMin)
    if type(GetLFGDungeonInfo) == "function" and id then
        local _, _, _, minLevel, _, recLevel = GetLFGDungeonInfo(id)
        local resolved = tonumber(recLevel) or tonumber(minLevel)

        if resolved then
            return resolved
        end
    end

    return fallbackMin
end

-- The game's own con colour for a dungeon's level: the same GetQuestDifficultyColor the Dungeon
-- Finder itself calls (LFDFrame.lua), so the thresholds are Blizzard's and not a guess:
--   levelDiff >= 5   red      (too high)
--   levelDiff >= 3   orange   (close to the limit)
--   levelDiff >= -2  yellow   (at your level)
--   -levelDiff <= GetQuestGreenRange()   green   (lower than you; the band is level-dependent)
--   beyond that      grey     (trivial)
local function DifficultyColor(level)
    if type(GetQuestDifficultyColor) ~= "function" then
        return nil
    end

    local color = GetQuestDifficultyColor(level)

    -- 3.3.5's QuestDifficultyColors carries r/g/b only (the .font some UI code expects is not set in
    -- this client), so the colour is applied directly instead of through a font object.
    if color and color.r then
        return color
    end

    return nil
end

local WARBAND_TRAVEL_REFUSAL = {
    noentrance = "the server has no entrance for that dungeon",
    dead = "you are dead",
    combat = "you are in combat",
    battleground = "you are in a battleground",
    refused = "the game's own teleport checks said no",
}

local function SetTravelStatus(text, r, g, b)
    if not warbandLFDStatus then
        return
    end

    warbandLFDStatus:SetText(text)
    warbandLFDStatus:SetTextColor(r, g, b)
end

local function RequestTravelList()
    travelState.incoming = nil
    travelState.requesting = true
    travelState.deadline = GetTime() + 5
    SetTravelStatus("Reading the destination list from the server...", 1, 0.7, 0)
    SendChatMessage(".warband travel", "SAY")
end

local function CreateTravelRow(index)
    local row = CreateFrame("Button", "WarbandLFDRow" .. index, warbandLFDScrollContent)
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")

    local name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    name:SetJustifyH("LEFT")
    name:SetPoint("LEFT", row, "LEFT", 2, 0)
    name:SetWidth(160)
    row.name = name

    local level = row:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    level:SetJustifyH("LEFT")
    level:SetPoint("LEFT", row, "LEFT", 164, 0)
    level:SetWidth(40)
    row.level = level

    local kind = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    kind:SetJustifyH("LEFT")
    kind:SetPoint("LEFT", row, "LEFT", 206, 0)
    kind:SetWidth(58)
    row.kind = kind

    local action = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    action:SetJustifyH("RIGHT")
    action:SetPoint("RIGHT", row, "RIGHT", -2, 0)
    action:SetWidth(36)
    action:SetText("Travel")
    action:SetTextColor(1, 0.82, 0)
    row.action = action

    row:SetScript("OnClick", function(self)
        if not self.destinationId then
            return
        end

        SetTravelStatus("Travelling to " .. (self.destinationName or "the dungeon") .. "...", 1, 0.7, 0)
        SendChatMessage(".warband travel " .. self.destinationId, "SAY")
    end)

    row:SetScript("OnEnter", function(self)
        if not self.destinationId then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(self.destinationName or "Dungeon")
        GameTooltip:AddLine("Travel the whole party here, companions included.", 1, 1, 1)
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    warbandLFDRows[index] = row
    return row
end

local function RenderTravel()
    if not warbandLFDBuilt or not travelState.destinations then
        return
    end

    local destinations = travelState.destinations

    if #destinations == 0 then
        SetTravelStatus("The server reported no destination it can reach.", 0.62, 0.62, 0.62)
    else
        SetTravelStatus(string.format("%d destinations, nothing filtered.", #destinations), 0.1, 1, 0.1)
    end

    local shown = 0

    for index, destination in ipairs(destinations) do
        local row = warbandLFDRows[index] or CreateTravelRow(index)

        row.destinationId = destination.id
        row.destinationName = destination.name
        row.name:SetText(destination.name)
        row.level:SetText(string.format("%d-%d", destination.minLevel, destination.maxLevel))

        -- The whole row takes the difficulty colour the game would give it: grey for trivial, green
        -- for easy, yellow at your level, orange for three or four above, red for five or more.
        local difficulty = DifficultyColor(RecommendedLevel(destination.id, destination.minLevel))

        if difficulty then
            row.name:SetTextColor(difficulty.r, difficulty.g, difficulty.b)
            row.level:SetTextColor(difficulty.r, difficulty.g, difficulty.b)
        end

        row.kind:SetText(KindLabel(destination.kind, destination.difficulty))
        row.kind:SetTextColor(1, 0.82, 0)

        row:Show()
        shown = index
    end

    for index = shown + 1, #warbandLFDRows do
        warbandLFDRows[index]:Hide()
    end

    local height = math.max(#destinations * ROW_HEIGHT, ROW_HEIGHT)
    warbandLFDScrollContent:SetHeight(height)
    warbandLFDScroll:UpdateScrollChildRect()

    local bar = _G[warbandLFDScroll:GetName() .. "ScrollBar"]
    if not bar then
        return
    end

    local maxScroll = math.max(height - warbandLFDScroll:GetHeight(), 0)
    bar:SetMinMaxValues(0, maxScroll)
    if bar:GetValue() > maxScroll then
        bar:SetValue(maxScroll)
    end
end

-- The queue view is never part of this window any more: a Warband has nobody to be matched with, and
-- the server answers a pick with travel. Hiding LFDQueueFrame also removes its artwork, which is what
-- used to show around this panel.
local function HideQueueView()
    local queueFrame = _G.LFDQueueFrame

    if queueFrame and queueFrame:IsShown() then
        queueFrame:Hide()
    end
end

local function ShowTravelPanel()
    if not warbandLFDBuilt then
        return
    end

    HideQueueView()
    warbandLFDPage:Show()

    if travelState.destinations then
        RenderTravel()
    else
        RequestTravelList()
    end
end

local function BuildTravelPanel()
    if warbandLFDBuilt then
        return
    end

    local parent = _G.LFDParentFrame
    if not parent or not parent.GetFrameLevel then
        return
    end

    -- The panel is the window: full size, plain black, one frame level above whatever the finder
    -- would have drawn there.
    warbandLFDPage = CreateFrame("Frame", "WarbandLFDPage", parent)
    warbandLFDPage:SetAllPoints(parent)
    warbandLFDPage:SetFrameStrata(parent:GetFrameStrata())
    warbandLFDPage:SetFrameLevel(parent:GetFrameLevel() + PAGE_LEVEL_OFFSET)
    warbandLFDPage:EnableMouse(true)

    local black = warbandLFDPage:CreateTexture(nil, "BACKGROUND")
    black:SetAllPoints(warbandLFDPage)
    black:SetTexture("Interface\\Buttons\\WHITE8X8")
    black:SetVertexColor(0, 0, 0, 1)

    -- A worldserver without the travel command never answers, so the waiting line must not sit there
    -- for ever pretending something is coming.
    warbandLFDPage:SetScript("OnUpdate", function()
        if not travelState.requesting or GetTime() < travelState.deadline then
            return
        end

        travelState.requesting = false
        travelState.incoming = nil
        SetTravelStatus("Unavailable: this worldserver does not answer .warband travel yet.",
            0.62, 0.62, 0.62)
    end)

    -- Blizzard's close button is a direct child of the window, and this panel would otherwise sit on
    -- top of it and swallow the click. Raising the button costs nothing and touches no script.
    for _, child in ipairs({ parent:GetChildren() }) do
        if child and child.IsObjectType and child:IsObjectType("Button") then
            child:SetFrameLevel(warbandLFDPage:GetFrameLevel() + 5)
        end
    end

    local title = warbandLFDPage:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    title:SetPoint("TOPLEFT", warbandLFDPage, "TOPLEFT", 14, -14)
    title:SetText("ALL DESTINATIONS")
    title:SetTextColor(1, 0.82, 0)

    local refresh = CreateFrame("Button", "WarbandLFDRefresh", warbandLFDPage, "UIPanelButtonTemplate")
    refresh:SetSize(90, 18)
    refresh:SetPoint("BOTTOMLEFT", warbandLFDPage, "BOTTOMLEFT", 14, 12)
    refresh:SetText("Refresh")
    refresh:SetScript("OnClick", function()
        RequestTravelList()
    end)

    warbandLFDStatus = warbandLFDPage:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    warbandLFDStatus:SetPoint("TOPLEFT", warbandLFDPage, "TOPLEFT", 14, -32)
    warbandLFDStatus:SetPoint("RIGHT", warbandLFDPage, "RIGHT", -14, 0)
    warbandLFDStatus:SetJustifyH("LEFT")
    warbandLFDStatus:SetText("Reading the destination list from the server...")

    warbandLFDScroll = CreateFrame("ScrollFrame", "WarbandLFDScroll", warbandLFDPage,
        "UIPanelScrollFrameTemplate")
    warbandLFDScroll:SetPoint("TOPLEFT", warbandLFDPage, "TOPLEFT", 14, -48)
    warbandLFDScroll:SetPoint("BOTTOMRIGHT", warbandLFDPage, "BOTTOMRIGHT", -28, 62)

    warbandLFDScrollContent = CreateFrame("Frame", "WarbandLFDScrollContent", warbandLFDScroll)
    warbandLFDScrollContent:SetSize(ROW_WIDTH, ROW_HEIGHT)
    warbandLFDScroll:SetScrollChild(warbandLFDScrollContent)

    local hint = warbandLFDPage:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("BOTTOMLEFT", warbandLFDPage, "BOTTOMLEFT", 14, 36)
    hint:SetPoint("BOTTOMRIGHT", warbandLFDPage, "BOTTOMRIGHT", -28, 36)
    hint:SetJustifyH("LEFT")
    hint:SetText("Coloured for your level: grey trivial, green easy, yellow even, orange close, red too high.")

    warbandLFDBuilt = true
    HideQueueView()
end

local function ReadTravelChunk(payload)
    travelState.incoming = travelState.incoming or {}

    for entry in string.gmatch(payload, "[^;]+") do
        local id, kind, difficulty, minLevel, maxLevel, name =
            string.match(entry, "^(%d+)|(%d+)|(%d+)|(%d+)|(%d+)|(.-)$")

        if id then
            table.insert(travelState.incoming, {
                id = tonumber(id),
                kind = tonumber(kind),
                difficulty = tonumber(difficulty),
                minLevel = tonumber(minLevel),
                maxLevel = tonumber(maxLevel),
                name = name,
            })
        end
    end
end

-- The server's answer, on the same chat channel the rest of the panel reads. The panel's own handler
-- ignores prefixes it does not know, so these two lines are ours alone.
local function OnTravelMessage(message)
    if not message then
        return
    end

    if string.find(message, "WARBAND_TRAVELGO=", 1, true) then
        travelState.requesting = false

        if string.find(message, "ok=1", 1, true) then
            SetTravelStatus("Travelling to " .. (string.match(message, "name=([^;]*)$") or "the dungeon")
                .. ".", 0.1, 1, 0.1)

            if _G.LFDParentFrame then
                HideUIPanel(_G.LFDParentFrame)
            end
        else
            local reason = string.match(message, "reason=([%a_]+)")
            SetTravelStatus("That travel was refused: " .. (WARBAND_TRAVEL_REFUSAL[reason]
                or "the server did not say why") .. ".", 1, 0.25, 0.25)
        end

        return
    end

    local start = string.find(message, "WARBAND_TRAVEL=", 1, true)
    if not start then
        return
    end

    local payload = string.sub(message, start + 15)

    if payload == "" then
        travelState.destinations = travelState.incoming or {}
        travelState.incoming = nil
        travelState.requesting = false

        -- Cached, so the list costs nothing the next time; Refresh asks again.
        WarbandDB.dungeonTravel = { destinations = travelState.destinations }

        RenderTravel()
        return
    end

    ReadTravelChunk(payload)
end

local travelLoader = CreateFrame("Frame")
travelLoader:RegisterEvent("ADDON_LOADED")
travelLoader:RegisterEvent("PLAYER_LOGIN")
travelLoader:RegisterEvent("CHAT_MSG_SYSTEM")
travelLoader:SetScript("OnEvent", function(self, event, arg1)
    if event == "CHAT_MSG_SYSTEM" then
        OnTravelMessage(arg1)
        return
    end

    if event == "ADDON_LOADED" then
        if arg1 ~= "Warband" then
            return
        end

        WarbandDB = WarbandDB or {}
        travelState.destinations = WarbandDB.dungeonTravel and WarbandDB.dungeonTravel.destinations
        self:UnregisterEvent("ADDON_LOADED")
        BuildTravelPanel()
        return
    end

    if event == "PLAYER_LOGIN" then
        BuildTravelPanel()

        if _G.LFDParentFrame then
            _G.LFDParentFrame:HookScript("OnShow", function()
                ShowTravelPanel()
            end)
        end

        -- Whatever re-shows the queue view must not win: the window is this panel and nothing else.
        if _G.LFDQueueFrame then
            _G.LFDQueueFrame:HookScript("OnShow", function(self)
                if warbandLFDBuilt and warbandLFDPage:IsShown() then
                    self:Hide()
                end
            end)
        end
    end
end)

-- If the finder's frame did not exist yet, look for it for a few seconds and then give up quietly.
local travelWaited = 0
local travelRetry = CreateFrame("Frame")
travelRetry:SetScript("OnUpdate", function(self, elapsed)
    if warbandLFDBuilt then
        self:Hide()
        return
    end

    travelWaited = travelWaited + elapsed
    if travelWaited > 20 then
        self:Hide()
        return
    end

    if _G.LFDParentFrame then
        BuildTravelPanel()

        if warbandLFDBuilt then
            self:Hide()
        end
    end
end)

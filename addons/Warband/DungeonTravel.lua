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
    tab = 0,
}

local warbandLFDPage
local warbandLFDScroll
local warbandLFDScrollContent
local warbandLFDStatus
local warbandLFDRefresh
local warbandLFDTabs = {}
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

-- The curated list, as one table: id = { expansion, min level, max level, is raid, raid size }.
--
-- The levels are the content's own, not the finder's entry windows. LFGDungeons.dbc publishes windows
-- like 55-65 for Lower Blackrock Spire or 60-83 for Molten Core, which is "who may walk in during
-- Wrath", not "what this content is for" - using those put level-80 numbers in a vanilla tab. These
-- are the levels the content is actually played at, so the vanilla tab ends at 60, TBC at 70 and
-- WotLK at 80, and the colour of a row means something useful again.
--
-- A dungeon is a 5-man and anything else is a raid: Upper Blackrock Spire is a 10-man and sits under
-- Raids with a size, Trial of the Champion is a 5-man and sits under Dungeons, and a heroic is the
-- same 5-man at the harder difficulty, so it is filed with the dungeons and says Heroic.
--
-- The list is the menu: an entry that is not in this table is not drawn at all. That is what keeps the
-- four holiday bosses (the Headless Horseman, Coren Direbrew, the Crown Chemical Co., Ahune) out of
-- the vanilla and TBC tabs, where the finder files them despite them being level 80 events.
local DUNGEON_DATA = {
    [4] = { 0, 13, 18, 0, 0 }, [1] = { 0, 15, 25, 0, 0 }, [6] = { 0, 17, 23, 0, 0 },
    [8] = { 0, 18, 30, 0, 0 }, [12] = { 0, 22, 30, 0, 0 }, [10] = { 0, 24, 32, 0, 0 },
    [163] = { 0, 26, 45, 0, 0 }, [164] = { 0, 26, 45, 0, 0 }, [18] = { 0, 26, 45, 0, 0 },
    [165] = { 0, 26, 45, 0, 0 }, [14] = { 0, 29, 38, 0, 0 }, [16] = { 0, 30, 40, 0, 0 },
    [20] = { 0, 40, 50, 0, 0 }, [22] = { 0, 42, 52, 0, 0 }, [24] = { 0, 44, 54, 0, 0 },
    [26] = { 0, 46, 55, 0, 0 }, [273] = { 0, 46, 55, 0, 0 }, [272] = { 0, 46, 55, 0, 0 },
    [28] = { 0, 50, 60, 0, 0 }, [30] = { 0, 52, 60, 0, 0 }, [276] = { 0, 52, 60, 0, 0 },
    [34] = { 0, 55, 60, 0, 0 }, [38] = { 0, 55, 60, 0, 0 }, [36] = { 0, 55, 60, 0, 0 },
    [32] = { 0, 55, 60, 0, 0 }, [2] = { 0, 58, 60, 0, 0 }, [40] = { 0, 58, 60, 0, 0 },
    [274] = { 0, 58, 60, 0, 0 }, [160] = { 0, 60, 60, 1, 20 }, [161] = { 0, 60, 60, 1, 40 },
    [50] = { 0, 60, 60, 1, 40 }, [48] = { 0, 60, 60, 1, 40 }, [44] = { 0, 60, 60, 1, 10 },
    [42] = { 0, 60, 60, 1, 20 }, [136] = { 1, 58, 62, 0, 0 }, [137] = { 1, 61, 63, 0, 0 },
    [140] = { 1, 62, 64, 0, 0 }, [146] = { 1, 63, 65, 0, 0 }, [148] = { 1, 64, 66, 0, 0 },
    [149] = { 1, 65, 67, 0, 0 }, [170] = { 1, 66, 68, 0, 0 }, [150] = { 1, 67, 69, 0, 0 },
    [151] = { 1, 68, 70, 0, 0 }, [138] = { 1, 69, 70, 0, 0 }, [172] = { 1, 69, 70, 0, 0 },
    [147] = { 1, 69, 70, 0, 0 }, [178] = { 1, 70, 70, 0, 0 }, [187] = { 1, 70, 70, 0, 0 },
    [188] = { 1, 70, 70, 0, 0 }, [198] = { 1, 70, 70, 0, 0 }, [201] = { 1, 70, 70, 0, 0 },
    [179] = { 1, 70, 70, 0, 0 }, [180] = { 1, 70, 70, 0, 0 }, [181] = { 1, 70, 70, 0, 0 },
    [189] = { 1, 70, 70, 0, 0 }, [184] = { 1, 70, 70, 0, 0 }, [174] = { 1, 70, 70, 0, 0 },
    [190] = { 1, 70, 70, 0, 0 }, [171] = { 1, 70, 70, 0, 0 }, [182] = { 1, 70, 70, 0, 0 },
    [173] = { 1, 70, 70, 0, 0 }, [191] = { 1, 70, 70, 0, 0 }, [183] = { 1, 70, 70, 0, 0 },
    [192] = { 1, 70, 70, 0, 0 }, [185] = { 1, 70, 70, 0, 0 }, [186] = { 1, 70, 70, 0, 0 },
    [196] = { 1, 70, 70, 1, 25 }, [177] = { 1, 70, 70, 1, 25 }, [195] = { 1, 70, 70, 1, 25 },
    [175] = { 1, 70, 70, 1, 10 }, [176] = { 1, 70, 70, 1, 25 }, [194] = { 1, 70, 70, 1, 25 },
    [193] = { 1, 70, 70, 1, 25 }, [199] = { 1, 70, 70, 1, 25 }, [197] = { 1, 70, 70, 1, 10 },
    [202] = { 2, 70, 72, 0, 0 }, [225] = { 2, 71, 73, 0, 0 }, [204] = { 2, 72, 74, 0, 0 },
    [218] = { 2, 73, 75, 0, 0 }, [214] = { 2, 74, 76, 0, 0 }, [220] = { 2, 75, 77, 0, 0 },
    [216] = { 2, 76, 78, 0, 0 }, [208] = { 2, 77, 79, 0, 0 }, [207] = { 2, 78, 80, 0, 0 },
    [209] = { 2, 78, 80, 0, 0 }, [219] = { 2, 80, 80, 0, 0 }, [241] = { 2, 80, 80, 0, 0 },
    [215] = { 2, 80, 80, 0, 0 }, [217] = { 2, 80, 80, 0, 0 }, [212] = { 2, 80, 80, 0, 0 },
    [255] = { 2, 80, 80, 0, 0 }, [256] = { 2, 80, 80, 0, 0 }, [213] = { 2, 80, 80, 0, 0 },
    [253] = { 2, 80, 80, 0, 0 }, [254] = { 2, 80, 80, 0, 0 }, [210] = { 2, 80, 80, 0, 0 },
    [251] = { 2, 80, 80, 0, 0 }, [252] = { 2, 80, 80, 0, 0 }, [226] = { 2, 80, 80, 0, 0 },
    [206] = { 2, 80, 80, 0, 0 }, [211] = { 2, 80, 80, 0, 0 }, [245] = { 2, 80, 80, 0, 0 },
    [249] = { 2, 80, 80, 0, 0 }, [242] = { 2, 80, 80, 0, 0 }, [203] = { 2, 80, 80, 0, 0 },
    [205] = { 2, 80, 80, 0, 0 }, [221] = { 2, 80, 80, 0, 0 }, [279] = { 2, 80, 80, 1, 10 },
    [280] = { 2, 80, 80, 1, 25 }, [159] = { 2, 80, 80, 1, 10 }, [227] = { 2, 80, 80, 1, 25 },
    [46] = { 2, 80, 80, 1, 10 }, [257] = { 2, 80, 80, 1, 25 }, [293] = { 2, 80, 80, 1, 10 },
    [294] = { 2, 80, 80, 1, 25 }, [223] = { 2, 80, 80, 1, 10 }, [237] = { 2, 80, 80, 1, 25 },
    [224] = { 2, 80, 80, 1, 10 }, [238] = { 2, 80, 80, 1, 25 }, [246] = { 2, 80, 80, 1, 10 },
    [248] = { 2, 80, 80, 1, 25 }, [247] = { 2, 80, 80, 1, 10 }, [250] = { 2, 80, 80, 1, 25 },
    [243] = { 2, 80, 80, 1, 10 }, [244] = { 2, 80, 80, 1, 25 }, [239] = { 2, 80, 80, 1, 10 },
    [240] = { 2, 80, 80, 1, 25 },
}

local EXPANSION_TABS = {
    { label = "Vanilla" },
    { label = "TBC" },
    { label = "WotLK" },
}

-- The two groups a tab is read in. A heroic is a dungeon at the harder difficulty, so it is filed
-- with the dungeons and says "Heroic" in its kind column.
local LIST_GROUPS = {
    { key = "dungeons", title = "Dungeons" },
    { key = "raids", title = "Raids" },
}

-- The curated list's row for a destination, or nil when the list does not carry it - in which case
-- the window does not draw it either.
local function DungeonData(destination)
    return DUNGEON_DATA[destination.id]
end

local function DungeonExpansion(destination)
    local data = DungeonData(destination)

    if data then
        return data[1]
    end

    return nil
end

-- A raid is anything that is not a 5-man: the table says which, and the row's own kind is only the
-- fallback for an id the list does not carry.
local function DungeonIsRaid(destination)
    local data = DungeonData(destination)

    if data then
        return data[4] == 1
    end

    return destination.kind == 2
end

local function DungeonGroup(destination)
    if DungeonIsRaid(destination) then
        return "raids"
    end

    return "dungeons"
end

-- How many players a raid takes, 0 for anything that is not a raid. It is in the table because the
-- kind column is the only place a 10-man and a 40-man differ, and the LFG difficulty that separates
-- 10 from 25 says nothing at all about the classic raids, which were fixed-size.
local function DungeonRaidSize(destination)
    local data = DungeonData(destination)

    if not data or data[4] ~= 1 then
        return 0
    end

    return data[5] or 0
end

-- The level window the row shows: the content's own, from the curated list. The wire's window is only
-- there for an id the list does not carry - it is the finder's "who may walk in" range, inflated for
-- 3.3.5 (55-65 for Lower Blackrock Spire, 60-83 for Molten Core) and useless as content levels.
local function DungeonLevelRange(destination)
    local data = DungeonData(destination)

    if data then
        return data[2], data[3]
    end

    return destination.minLevel, destination.maxLevel
end

-- The level a row is coloured by: the level the content starts at, so a dungeon opens orange or red
-- while the character is below it and turns yellow when they reach it. A 0 is not a level, so the top
-- of the window answers for a row that carries nothing.
local function DungeonColourLevel(destination)
    local minimum = DungeonLevelRange(destination)

    if minimum and tonumber(minimum) and tonumber(minimum) > 0 then
        return tonumber(minimum)
    end

    local _, maximum = DungeonLevelRange(destination)

    return tonumber(maximum) or destination.minLevel
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

-- Which tab looks chosen. The panel button template has no selected state of its own, so the chosen
-- one keeps its highlight locked on and the others release it.
local function ShowSelectedTab()
    for index, tab in ipairs(warbandLFDTabs) do
        if index - 1 == travelState.tab then
            tab:LockHighlight()
        else
            tab:UnlockHighlight()
        end
    end
end

local function RenderTravel()
    if not warbandLFDBuilt or not travelState.destinations then
        return
    end

    local destinations = travelState.destinations
    local tab = travelState.tab or 0

    -- The lines this tab shows: a heading per group, then that group's destinations.
    local lines = {}

    for _, group in ipairs(LIST_GROUPS) do
        local members = {}

        for _, destination in ipairs(destinations) do
            -- Only what the curated list carries is drawn: an entry that is not on it is not part of
            -- what this window offers, holiday bosses included.
            if DungeonExpansion(destination) == tab and DungeonGroup(destination) == group.key then
                table.insert(members, destination)
            end
        end

        if #members > 0 then
            table.insert(lines, { title = string.format("%s (%d)", group.title, #members) })

            for _, destination in ipairs(members) do
                table.insert(lines, { destination = destination })
            end
        end
    end

    ShowSelectedTab()

    if #destinations == 0 then
        SetTravelStatus("The server reported no destination it can reach.", 0.62, 0.62, 0.62)
    else
        local counted = 0

        for _, line in ipairs(lines) do
            if line.destination then
                counted = counted + 1
            end
        end

        SetTravelStatus(string.format("%d in %s, %d destinations in all.", counted,
            EXPANSION_TABS[(tab or 0) + 1].label, #destinations), 0.1, 1, 0.1)
    end

    local shown = 0

    for index, line in ipairs(lines) do
        local row = warbandLFDRows[index] or CreateTravelRow(index)

        if line.title then
            row.destinationId = nil
            row.destinationName = nil
            row.name:SetText(line.title)
            row.name:SetTextColor(1, 0.82, 0)
            row.level:Hide()
            row.kind:Hide()
            row.action:Hide()
        else
            local destination = line.destination
            local minimum, maximum = DungeonLevelRange(destination)

            row.destinationId = destination.id
            row.destinationName = destination.name
            row.name:SetText(destination.name)
            row.level:SetText(string.format("%d-%d", minimum, maximum))
            row.level:Show()

            -- The whole row takes the difficulty colour the game would give it: grey for trivial,
            -- green for easy, yellow at your level, orange for three or four above, red for five or
            -- more. A row is reused for whatever this tab needs there, so the colour is set either
            -- way - a heading's gold must not be left on a destination.
            local difficulty = DifficultyColor(DungeonColourLevel(destination))

            if difficulty then
                row.name:SetTextColor(difficulty.r, difficulty.g, difficulty.b)
                row.level:SetTextColor(difficulty.r, difficulty.g, difficulty.b)
            else
                row.name:SetTextColor(1, 1, 1)
                row.level:SetTextColor(0.62, 0.62, 0.62)
            end

            -- The kind column: a raid by its size, so a 40-man, a 25-man and a 10-man never read the
            -- same, and a dungeon or heroic as such.
            local raidSize = DungeonRaidSize(destination)

            if raidSize > 0 then
                row.kind:SetText(string.format("Raid %d", raidSize))
            else
                row.kind:SetText(KindLabel(destination.kind, destination.difficulty))
            end

            row.kind:SetTextColor(1, 0.82, 0)
            row.kind:Show()
            row.action:Show()
        end

        row:Show()
        shown = index
    end

    for index = shown + 1, #warbandLFDRows do
        warbandLFDRows[index]:Hide()
    end

    local height = math.max(#lines * ROW_HEIGHT, ROW_HEIGHT)
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
    -- Deliberately mouse-transparent: the panel covers the whole frame, and with the mouse enabled it
    -- would swallow the press that starts the window's own drag (BlizzMove puts its drag handler on
    -- LFDParentFrame itself), which is what stopped the window being moved. Nothing is lost: the tabs,
    -- rows, scroll bar and Refresh button are children and still get their own clicks - everything
    -- else falls through to the window, which keeps working exactly as it did before this panel.
    warbandLFDPage:EnableMouse(false)

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

    -- One tab per expansion. Switching is a redraw of the same cached list: no command, no refresh.
    local previousTab

    for index, config in ipairs(EXPANSION_TABS) do
        local tab = CreateFrame("Button", "WarbandLFDTab" .. index, warbandLFDPage, "UIPanelButtonTemplate")
        tab:SetSize(104, 20)
        tab:SetText(config.label)

        if previousTab then
            tab:SetPoint("LEFT", previousTab, "RIGHT", 4, 0)
        else
            tab:SetPoint("TOPLEFT", warbandLFDPage, "TOPLEFT", 14, -50)
        end

        tab.tabIndex = index - 1
        tab:SetScript("OnClick", function(self)
            travelState.tab = self.tabIndex
            RenderTravel()

            local bar = _G[warbandLFDScroll:GetName() .. "ScrollBar"]
            if bar then
                bar:SetValue(0)
            end
        end)

        warbandLFDTabs[index] = tab
        previousTab = tab
    end

    warbandLFDScroll = CreateFrame("ScrollFrame", "WarbandLFDScroll", warbandLFDPage,
        "UIPanelScrollFrameTemplate")
    warbandLFDScroll:SetPoint("TOPLEFT", warbandLFDPage, "TOPLEFT", 14, -76)
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

-- WoW Warband client window: a feature tree on the left, a detail pane per feature on the right.
--
-- Warband.xml holds the layout; this file owns the behaviour:
--   * the tree model with expand/collapse and selection,
--   * text pages rendered from the node data below,
--   * the live XP multiplier page and its chat protocol,
--   * opening and closing the window (/warband and /ww, or the compass icon by the minimap).
--
-- Server protocol, unchanged: ".warband xp" asks for the current multiplier and the module
-- answers with a WARBAND_XP=<rate> system message; ".warband xp set <1-10>" changes it live.
--
-- Setup runs on ADDON_LOADED instead of XML OnLoad handlers, so the file order in Warband.toc
-- cannot break frame creation.

local ADDON_NAME = "Warband"
local FRAME_NAME = "WarbandConfigFrame"

local XP_MIN = 1
local XP_MAX = 10
local XP_DEFAULT = 3
local REPLY_TIMEOUT = 5
local MINIMAP_RADIUS = 80

local ROW_HEIGHT = 24
local INDENT = 14
local PAGE_TEXT_WIDTH = 732

local TEXT_READING = "Reading the server value..."
local TEXT_SENDING = "Sending to the server..."
local TEXT_NO_REPLY = "No reply from the server. Check that worldserver runs the Warband build."
local TEXT_CATCHUP_NO_REPLY = "Unavailable: this worldserver does not answer .warband catchup yet."
local TEXT_GATHER_NO_REPLY = "Unavailable: this worldserver does not answer .warband gather yet."

local COLOR_GREEN = { 0.1, 1, 0.1 }
local COLOR_AMBER = { 1, 0.7, 0 }
local COLOR_RED = { 1, 0.25, 0.25 }
local COLOR_GREY = { 0.62, 0.62, 0.62 }

-- Status kinds colour the tree labels and label the detail header. "live" is the only state that
-- describes something working today, and "placeholder" is deliberately plain grey so an
-- unfinished item never reads as finished.
local STATUS = {
    live = { label = "Live", r = 0.1, g = 1, b = 0.1 },
    placeholder = { label = "Placeholder - not implemented yet", r = 0.62, g = 0.62, b = 0.62 },
    list = { label = "What this Warband adds", r = 1, g = 0.82, b = 0 },
    about = { label = "Project information", r = 1, g = 0.82, b = 0 },
}

-- The tree. A node with children expands; a node with a page shows one. Adding a feature later
-- means adding a node here, so nothing else has to change.
local Tree = {
    {
        id = "server",
        text = "Server",
        expanded = true,
        children = {
            { id = "xp", text = "XP Options", status = "live", page = "experience" },
            { id = "gathering", text = "Follower gathering", status = "live", page = "gathering" },
        },
    },
    {
        id = "features",
        text = "Features",
        status = "list",
        page = "text",
        dynamic = "features",
    },
    {
        id = "about",
        text = "About",
        status = "about",
        page = "text",
        dynamic = "about",
    },
}

local rate = XP_DEFAULT
local lastSentRate
-- Two independent requests are in flight when the window opens, so each keeps its own pending
-- state: a command the server does not answer must not make the other line report a failure.
local xpRequest = { pending = false, deadline = nil }
local catchUpRequest = { pending = false, deadline = nil }
local currentNode
local RefreshDynamicPage
local UpdateCatchUpDisplay
local SetCatchUpStatus

-- Follower catch-up settings as reported by the server. The defaults mirror the shipped
-- module configuration, so the panel shows something sensible before the first reply.
local catchUp = {
    known = false,
    enabled = true,
    step = 0.10,
    floor = 1.0,
    cap = 0,
}

-- Follower gathering as reported by the server: which gathering values the leader has, and how
-- the mirror is configured. The values shown are the leader's own, since those are what followers
-- receive.
local gather = {
    known = false,
    enabled = true,
    automatic = true,
    herbalism = 0,
    mining = 0,
    skinning = 0,
    updated = 0,
}

local gatherRequest = { pending = false, deadline = nil }
local UpdateGatherDisplay
local SetGatherStatus
local rowPool = {}
local textLinePool = {}
local minimapButton

-- ---------------------------------------------------------------------------
-- XP multiplier: the live part of the panel
-- ---------------------------------------------------------------------------

local function SetXpStatus(text, color)
    WarbandPageExperienceStatus:SetText(text)
    WarbandPageExperienceStatus:SetTextColor(color[1], color[2], color[3])
end

local function UpdateRateDisplay(value)
    WarbandPageExperienceValue:SetText(value .. "x")
end

local function StartRequest(request, text)
    request.pending = true
    request.deadline = GetTime() + REPLY_TIMEOUT
    SendChatMessage(text, "SAY")
end

local function ClearRequest(request)
    request.pending = false
    request.deadline = nil
end

local function SendWarbandCommand(command)
    StartRequest(xpRequest, ".warband xp" .. (command and (" " .. command) or ""))
end

local function RequestServerRate()
    SetXpStatus(TEXT_READING, COLOR_AMBER)
    SendWarbandCommand(nil)
end

local function RequestCatchUpSettings()
    if UpdateCatchUpDisplay then
        UpdateCatchUpDisplay()
    end

    StartRequest(catchUpRequest, ".warband catchup")
end

-- Read-only: "gather status" reports without applying, so opening the panel never writes to a
-- follower's skills behind the player's back.
local function RequestGatherState()
    if UpdateGatherDisplay then
        UpdateGatherDisplay()
    end

    StartRequest(gatherRequest, ".warband gather status")
end

-- Sends the value the panel shows. Repeating the last accepted value is skipped so a click that
-- changes nothing does not produce needless chat traffic.
local function CommitRate()
    if rate == lastSentRate then
        return
    end

    lastSentRate = rate
    SetXpStatus(TEXT_SENDING, COLOR_AMBER)
    SendWarbandCommand("set " .. rate)
end

function Warband_StepRate(delta)
    WarbandPageExperienceSlider:SetValue(rate + delta)
    CommitRate()
end

function Warband_SetRate(value)
    WarbandPageExperienceSlider:SetValue(value)
    CommitRate()
end

function Warband_OnSliderValueChanged(slider, value)
    local rounded = math.floor(value + 0.5)
    if rounded < XP_MIN then
        rounded = XP_MIN
    elseif rounded > XP_MAX then
        rounded = XP_MAX
    end

    rate = rounded
    UpdateRateDisplay(rounded)

    -- keeps the Features list showing the live number while the slider moves
    if RefreshDynamicPage then
        RefreshDynamicPage()
    end
end

function Warband_OnSliderMouseUp()
    CommitRate()
end

function Warband_OnUpdate()
    if xpRequest.pending and GetTime() >= xpRequest.deadline then
        ClearRequest(xpRequest)
        lastSentRate = nil
        SetXpStatus(TEXT_NO_REPLY, COLOR_RED)
    end

    if catchUpRequest.pending and GetTime() >= catchUpRequest.deadline then
        ClearRequest(catchUpRequest)
        SetCatchUpStatus(TEXT_CATCHUP_NO_REPLY, COLOR_GREY)
    end

    if gatherRequest.pending and GetTime() >= gatherRequest.deadline then
        ClearRequest(gatherRequest)
        SetGatherStatus(TEXT_GATHER_NO_REPLY, COLOR_GREY)
    end
end

function Warband_OnEvent(self, event, ...)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_LEVEL_UP" then
        if UpdateCatchUpDisplay then
            UpdateCatchUpDisplay()
        end
        return
    end

    if event ~= "CHAT_MSG_SYSTEM" then
        return
    end

    local message = ...

    if string.find(message or "", "WARBAND_GATHER=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "enabled" then
                gather.enabled = number == 1
            elseif key == "automatic" then
                gather.automatic = number == 1
            elseif key == "herbalism" then
                gather.herbalism = number or 0
            elseif key == "mining" then
                gather.mining = number or 0
            elseif key == "skinning" then
                gather.skinning = number or 0
            elseif key == "updated" then
                gather.updated = number or 0
            end
        end

        ClearRequest(gatherRequest)
        gather.known = true

        if UpdateGatherDisplay then
            UpdateGatherDisplay()
        end

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end

    if string.find(message or "", "WARBAND_CATCHUP=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "enabled" then
                catchUp.enabled = number == 1
            elseif key == "step" then
                catchUp.step = number or catchUp.step
            elseif key == "floor" then
                catchUp.floor = number or catchUp.floor
            elseif key == "cap" then
                catchUp.cap = number or catchUp.cap
            end
        end

        ClearRequest(catchUpRequest)
        catchUp.known = true

        if UpdateCatchUpDisplay then
            UpdateCatchUpDisplay()
        end

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end

    local serverRate = tonumber(string.match(message or "", "WARBAND_XP=([%d%.]+)"))
    if serverRate then
        ClearRequest(xpRequest)

        rate = math.floor(serverRate + 0.5)
        lastSentRate = rate
        WarbandPageExperienceSlider:SetValue(rate)
        UpdateRateDisplay(rate)
        SetXpStatus("Server at " .. rate .. "x", COLOR_GREEN)

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end

    if xpRequest.pending and string.find(message or "", "XP multiplier must be", 1, true) then
        ClearRequest(xpRequest)
        lastSentRate = nil
        SetXpStatus(message, COLOR_RED)
    end
end

-- ---------------------------------------------------------------------------
-- Tree: model, rows and selection
-- ---------------------------------------------------------------------------

local function IsExpanded(node)
    return node.expanded and true or false
end

local function SetExpanded(node, expanded)
    node.expanded = expanded
    WarbandDB.expanded = WarbandDB.expanded or {}
    WarbandDB.expanded[node.id] = expanded
end

local function ApplySavedExpansion(nodes)
    for _, node in ipairs(nodes) do
        if node.children then
            local saved = WarbandDB.expanded and WarbandDB.expanded[node.id]
            if saved ~= nil then
                node.expanded = saved
            end
            ApplySavedExpansion(node.children)
        end
    end
end

local function FindNodeById(nodes, id)
    for _, node in ipairs(nodes) do
        if node.id == id then
            return node
        end

        if node.children then
            local found = FindNodeById(node.children, id)
            if found then
                return found
            end
        end
    end

    return nil
end

-- Expands every container on the path to a node so a restored selection is visible.
local function ExpandAncestors(nodes, id)
    for _, node in ipairs(nodes) do
        if node.children then
            if node.id == id or ExpandAncestors(node.children, id) then
                SetExpanded(node, true)
                return true
            end
        end
    end

    return false
end

local function CollectVisibleRows()
    local rows = {}

    local function walk(nodes, depth)
        for _, node in ipairs(nodes) do
            table.insert(rows, { node = node, depth = depth })

            if node.children and IsExpanded(node) then
                walk(node.children, depth + 1)
            end
        end
    end

    walk(Tree, 0)
    return rows
end

local function CreateRow(index)
    local row = CreateFrame("Button", "WarbandTreeRow" .. index, WarbandTreeContent)
    row:SetSize(182, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

    local selected = row:CreateTexture(nil, "BACKGROUND")
    selected:SetAllPoints(row)
    selected:SetTexture("Interface\\Buttons\\WHITE8X8")
    selected:SetVertexColor(1, 0.82, 0, 0.18)
    row.selected = selected

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    highlight:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    highlight:SetBlendMode("ADD")

    local disclosure = CreateFrame("Button", nil, row)
    disclosure:SetSize(14, 14)
    disclosure:SetScript("OnClick", function(self)
        SetExpanded(self.node, not IsExpanded(self.node))
        Warband_RefreshTree()
    end)
    row.disclosure = disclosure

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetJustifyH("LEFT")
    row.label = label

    row:SetScript("OnClick", function(self)
        Warband_SelectNode(self.node)
    end)

    rowPool[index] = row
    return row
end

local function UpdateTreeScroll(rowCount)
    local height = math.max(rowCount * ROW_HEIGHT, WarbandTreeScroll:GetHeight())
    WarbandTreeContent:SetHeight(height)
    WarbandTreeScroll:UpdateScrollChildRect()

    local bar = _G[WarbandTreeScroll:GetName() .. "ScrollBar"]
    if not bar then
        return
    end

    local maxScroll = math.max(height - WarbandTreeScroll:GetHeight(), 0)
    bar:SetMinMaxValues(0, maxScroll)
    if bar:GetValue() > maxScroll then
        bar:SetValue(maxScroll)
    end
end

function Warband_RefreshTree()
    local rows = CollectVisibleRows()

    for index, entry in ipairs(rows) do
        local node = entry.node
        local row = rowPool[index] or CreateRow(index)
        local status = STATUS[node.status] or STATUS.placeholder

        row.node = node
        row.disclosure.node = node
        row.label:SetText(node.text)
        row.label:SetTextColor(status.r, status.g, status.b)

        row.label:ClearAllPoints()
        row.label:SetPoint("LEFT", row, "LEFT", 18 + (entry.depth * INDENT), 0)
        row.label:SetPoint("RIGHT", row, "RIGHT", -6, 0)

        if node == currentNode then
            row.selected:Show()
        else
            row.selected:Hide()
        end

        if node.children then
            row.disclosure:Show()
            row.disclosure:ClearAllPoints()
            row.disclosure:SetPoint("LEFT", row, "LEFT", 3 + (entry.depth * INDENT), 0)

            if IsExpanded(node) then
                row.disclosure:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-Up")
                row.disclosure:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-Down")
            else
                row.disclosure:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-Up")
                row.disclosure:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-Down")
            end
        else
            row.disclosure:Hide()
        end

        row:Show()
    end

    for index = #rows + 1, #rowPool do
        rowPool[index]:Hide()
    end

    UpdateTreeScroll(#rows)
end

local function RenderTextPage(lines)
    local page = WarbandPageText
    local offsetY = 0

    for index, line in ipairs(lines) do
        local text = textLinePool[index]
        if not text then
            text = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            text:SetJustifyH("LEFT")
            text:SetWidth(PAGE_TEXT_WIDTH)
            textLinePool[index] = text
        end

        text:SetText(line)
        text:ClearAllPoints()
        text:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -offsetY)
        text:Show()

        offsetY = offsetY + text:GetHeight() + 6
    end

    for index = #lines + 1, #textLinePool do
        textLinePool[index]:Hide()
    end
end

-- Follower catch-up: the curve the server applies, and what the party looks like right now.
local function CatchUpMultiplierFor(gap)
    if gap <= 0 then
        return 1.0
    end

    local multiplier = 1.0 + (catchUp.step * gap)
    if multiplier < catchUp.floor then
        multiplier = catchUp.floor
    end
    if catchUp.cap > 0 and multiplier > catchUp.cap then
        multiplier = catchUp.cap
    end

    return multiplier
end

SetCatchUpStatus = function(text, color)
    WarbandPageExperienceCatchUpStatus:SetText(text)
    WarbandPageExperienceCatchUpStatus:SetTextColor(color[1], color[2], color[3])
end

-- Ranges for the catch-up controls. The server validates the same limits, so a click can never
-- send a value it would reject.
local CATCHUP_STEP = { min = 0.0, max = 1.0, increment = 0.05 }
local CATCHUP_FLOOR = { min = 1.0, max = 10.0, increment = 0.5 }
local CATCHUP_CAP = { min = 0.0, max = 20.0, increment = 0.5 }

local function CatchUpField(field)
    if field == "step" then
        return catchUp.step, CATCHUP_STEP
    end

    if field == "floor" then
        return catchUp.floor, CATCHUP_FLOOR
    end

    return catchUp.cap, CATCHUP_CAP
end

-- One click, one .warband catchup command. The reply carries the whole new state, so nothing has
-- to be reconstructed locally.
function Warband_AdjustCatchUp(field, delta)
    local current, range = CatchUpField(field)
    local value = math.floor(((current + (delta * range.increment)) / range.increment) + 0.5)
        * range.increment

    if value < range.min then
        value = range.min
    elseif value > range.max then
        value = range.max
    end

    local wanted = string.format("%.2f", value)
    if wanted ~= string.format("%.2f", current) then
        StartRequest(catchUpRequest, ".warband catchup " .. field .. " " .. wanted)
    end
end

function Warband_ToggleCatchUp()
    StartRequest(catchUpRequest, ".warband catchup " .. (catchUp.enabled and "off" or "on"))
end

-- Level gaps are client-side knowledge, so this readout stays live without asking the server.
local function PartyGapLines()
    local playerLevel = UnitLevel("player") or 0
    local count = GetNumPartyMembers and GetNumPartyMembers() or 0
    local prefix = "party"

    if GetNumRaidMembers and GetNumRaidMembers() > 0 then
        count = GetNumRaidMembers()
        prefix = "raid"
    end

    local parts = {}
    for index = 1, count do
        local unit = prefix .. index
        if UnitExists(unit) and not UnitIsUnit(unit, "player") then
            local level = UnitLevel(unit) or 0
            if level > 0 then
                local gap = playerLevel - level
                local name = UnitName(unit) or unit

                if gap > 0 then
                    table.insert(parts, name .. " " .. gap .. " behind (x"
                        .. string.format("%.2f", CatchUpMultiplierFor(gap)) .. ")")
                else
                    table.insert(parts, name .. " level with you")
                end
            end
        end
    end

    if #parts == 0 then
        return "No followers in your party. Leader level " .. playerLevel .. "."
    end

    return "Leader level " .. playerLevel .. ". " .. table.concat(parts, ". ") .. "."
end

UpdateCatchUpDisplay = function()
    if not catchUp.known then
        SetCatchUpStatus("Reading the catch-up settings...", COLOR_AMBER)
    elseif not catchUp.enabled then
        SetCatchUpStatus("Disabled on the server", COLOR_GREY)
    else
        SetCatchUpStatus(string.format("Live - +%.2f per level behind, floor %.2f, %s",
            catchUp.step,
            catchUp.floor,
            catchUp.cap > 0 and string.format("cap %.2f", catchUp.cap) or "uncapped"), COLOR_GREEN)
    end

    WarbandPageExperienceCatchUpToggle:SetText(catchUp.enabled and "Catch-up: on" or "Catch-up: off")
    WarbandPageExperienceCatchUpStepValue:SetText(string.format("%.2f", catchUp.step))
    WarbandPageExperienceCatchUpFloorValue:SetText(string.format("%.2f", catchUp.floor))
    WarbandPageExperienceCatchUpCapValue:SetText(catchUp.cap > 0
        and string.format("%.2f", catchUp.cap) or "uncapped")

    WarbandPageExperienceCatchUpText:SetText(PartyGapLines())
end

-- Follower gathering: the server mirrors the leader's gathering skills to the party. The panel
-- shows the values the leader has and can trigger the mirror on demand.
SetGatherStatus = function(text, color)
    WarbandPageGatheringStatus:SetText(text)
    WarbandPageGatheringStatus:SetTextColor(color[1], color[2], color[3])
end

local function GatherSkillText()
    local parts = {}
    if gather.herbalism > 0 then
        table.insert(parts, "Herbalism " .. gather.herbalism)
    end
    if gather.mining > 0 then
        table.insert(parts, "Mining " .. gather.mining)
    end
    if gather.skinning > 0 then
        table.insert(parts, "Skinning " .. gather.skinning)
    end

    if #parts == 0 then
        return "You have no gathering professions, so there is nothing to mirror yet."
    end

    return "Yours: " .. table.concat(parts, "   ")
end

UpdateGatherDisplay = function()
    if not gather.known then
        SetGatherStatus("Reading the gathering settings...", COLOR_AMBER)
    elseif not gather.enabled then
        SetGatherStatus("Disabled on the server", COLOR_GREY)
    else
        SetGatherStatus(string.format("Live - raised only, kept in step on login, join and every skill change: %s",
            gather.automatic and "yes" or "no"), COLOR_GREEN)
    end

    local detail = GatherSkillText()
    if gather.updated and gather.updated > 0 then
        detail = detail .. "\nThe last apply changed " .. gather.updated .. " follower(s)."
    end

    WarbandPageGatheringDetail:SetText(detail)
end

function Warband_ApplyGathering()
    SetGatherStatus("Applying to your followers...", COLOR_AMBER)
    StartRequest(gatherRequest, ".warband gather")
end

-- Pages whose content depends on live state rather than fixed text.
local function DynamicLines(kind)
    if kind == "features" then
        local lines = {
            "Everything this Warband adds to the game:",
            " ",
            "- XP rates heightened to " .. rate .. "x",
        }

        if catchUp.known and catchUp.enabled and catchUp.step > 0 then
            table.insert(lines, "- Follower catch-up: +" .. string.format("%.2f", catchUp.step)
                .. " per level behind (x" .. string.format("%.2f", CatchUpMultiplierFor(5))
                .. " at 5 levels behind, x" .. string.format("%.2f", CatchUpMultiplierFor(20))
                .. " at 20)")
        end

        if gather.known and gather.enabled and
            (gather.herbalism > 0 or gather.mining > 0 or gather.skinning > 0) then
            table.insert(lines, "- Follower gathering: followers receive your Herbalism, Mining "
                .. "and Skinning values")
        end

        table.insert(lines, " ")
        table.insert(lines, "New features are listed here as they are added.")
        return lines
    end

    if kind == "about" then
        return {
            "Author: Apo",
            " ",
            "A solo World of Warcraft experience: you roleplay the whole party at the same time, "
                .. "with content tailored for a five man group.",
            " ",
            "Panel " .. (GetAddOnMetadata("Warband", "Version") or "unknown")
                .. ". Open with /warband or /ww, or the icon by the minimap.",
        }
    end

    return { "No details recorded for this feature yet." }
end

RefreshDynamicPage = function()
    if currentNode and currentNode.dynamic then
        RenderTextPage(DynamicLines(currentNode.dynamic))
    end
end

local function ShowNode(node)
    currentNode = node

    local status = STATUS[node.status] or STATUS.placeholder
    WarbandDetailTitle:SetText(node.text)
    WarbandDetailStatus:SetText(status.label)
    WarbandDetailStatus:SetTextColor(status.r, status.g, status.b)

    WarbandPageText:Hide()
    WarbandPageExperience:Hide()
    WarbandPageGathering:Hide()

    if node.page == "experience" then
        WarbandPageExperience:Show()
        return
    end

    if node.page == "gathering" then
        if UpdateGatherDisplay then
            UpdateGatherDisplay()
        end

        WarbandPageGathering:Show()
        return
    end

    RenderTextPage(node.dynamic and DynamicLines(node.dynamic) or node.lines
        or { "No details recorded for this feature yet." })
    WarbandPageText:Show()
end

function Warband_SelectNode(node)
    WarbandDB.selected = node.id

    if node.children then
        SetExpanded(node, not IsExpanded(node))
        Warband_RefreshTree()
        return
    end

    ShowNode(node)
    Warband_RefreshTree()
end

-- ---------------------------------------------------------------------------
-- Window plumbing
-- ---------------------------------------------------------------------------

function Warband_OnShow()
    Warband_RefreshTree()
    RequestServerRate()
    RequestCatchUpSettings()
    RequestGatherState()
end

function Warband_OnHide()
    ClearRequest(xpRequest)
    ClearRequest(catchUpRequest)
end

function Warband_OnCloseClick()
    HideUIPanel(WarbandConfigFrame)
end

function Warband_Toggle()
    if WarbandConfigFrame:IsShown() then
        HideUIPanel(WarbandConfigFrame)
    else
        ShowUIPanel(WarbandConfigFrame)
    end
end

local function UpdateMinimapButtonPosition()
    local angle = math.rad(WarbandDB.minimapAngle or 200)
    minimapButton:SetPoint(
        "CENTER",
        Minimap,
        "CENTER",
        math.cos(angle) * MINIMAP_RADIUS,
        math.sin(angle) * MINIMAP_RADIUS)
end

local function OnMinimapButtonDrag()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    cursorX, cursorY = cursorX / scale, cursorY / scale

    WarbandDB.minimapAngle = math.deg(math.atan2(cursorY - centerY, cursorX - centerX))
    UpdateMinimapButtonPosition()
end

local function InitMinimapButton()
    if minimapButton or not Minimap then
        return
    end

    local button = CreateFrame("Button", "WarbandMinimapButton", Minimap)
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Trade_Engineering")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER", 0, 1)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(56, 56)
    border:SetPoint("TOPLEFT")

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", Warband_Toggle)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", OnMinimapButtonDrag)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("WoW Warband")
        GameTooltip:AddLine("Open or close the Warband settings window.", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    minimapButton = button
    UpdateMinimapButtonPosition()
end

-- The window has no default key binding on purpose. The binding below is offered in the Key
-- Bindings window so it can be set by hand; nothing is bound automatically.
BINDING_HEADER_WARBAND = "WoW Warband"
BINDING_NAME_WARBANDTOGGLE = "Toggle the Warband window"

SLASH_WARBAND1 = "/warband"
SLASH_WARBAND2 = "/ww"
SlashCmdList["WARBAND"] = function()
    Warband_Toggle()
end

local function InitWindow()
    local frame = WarbandConfigFrame

    table.insert(UISpecialFrames, FRAME_NAME)
    frame:RegisterEvent("CHAT_MSG_SYSTEM")
    frame:RegisterEvent("GROUP_ROSTER_UPDATE")
    frame:RegisterEvent("PLAYER_LEVEL_UP")

    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        self:SetUserPlaced(true)
    end)

    WarbandPageExperienceSlider:SetMinMaxValues(XP_MIN, XP_MAX)
    WarbandPageExperienceSlider:SetValueStep(1)
    WarbandPageExperienceSlider:SetValue(rate)
    UpdateRateDisplay(rate)
    SetXpStatus(TEXT_READING, COLOR_AMBER)

    WarbandTreeScroll:EnableMouseWheel(true)
    WarbandTreeScroll:SetScript("OnMouseWheel", function(self, delta)
        local bar = _G[self:GetName() .. "ScrollBar"]
        if bar then
            bar:SetValue(bar:GetValue() - (delta * ROW_HEIGHT * 3))
        end
    end)

    ApplySavedExpansion(Tree)
    ExpandAncestors(Tree, WarbandDB.selected or "xp")

    local node = FindNodeById(Tree, WarbandDB.selected or "xp")
        or Tree[1].children[1]
    ShowNode(node)
    Warband_RefreshTree()

    InitMinimapButton()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= ADDON_NAME then
        return
    end

    self:UnregisterEvent("ADDON_LOADED")
    WarbandDB = WarbandDB or {}
    InitWindow()
end)

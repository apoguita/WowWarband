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
local TEXT_BINDING_NO_REPLY = "Unavailable: this worldserver does not answer .warband binding yet."
local TEXT_MAGIC_FIND_NO_REPLY = "Unavailable: this worldserver does not answer .warband magicfind yet."
local TEXT_GOLD_FIND_NO_REPLY = "Unavailable: this worldserver does not answer .warband goldfind yet."
local TEXT_TRASH_SELL_NO_REPLY = "Unavailable: this worldserver does not answer .warband trash yet."

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
            { id = "binding", text = "Item binding", status = "live", page = "binding" },
            { id = "magicfind", text = "Magic find", status = "live", page = "magicfind" },
            { id = "goldfind", text = "Gold find", status = "live", page = "goldfind" },
            { id = "trashsell", text = "Trash sell", status = "live", page = "trashsell" },
            { id = "auctionhouse", text = "Auction house", status = "live", page = "auctionhouse" },
            { id = "instances", text = "Instances", status = "live", page = "instances" },
            { id = "convenience", text = "Convenience", status = "live", page = "convenience" },
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

-- The binding policy as reported by the server: whether binding restricts item movement. Off is the
-- Warband rule, where a bound piece moves like any other.
local binding = {
    known = false,
    enforced = false,
}

local bindingRequest = { pending = false, deadline = nil }
local UpdateBindingDisplay
local SetBindingStatus

-- Magic find as reported by the server: one multiplier per quality, x1 leaves the loot
-- tables exactly as the game ships them.
local MAGICFIND_TIERS = { "green", "blue", "purple", "orange", "gold" }
local MAGICFIND_LABELS = {
    green = "Green",
    blue = "Blue",
    purple = "Purple",
    orange = "Orange",
    gold = "Gold",
}
local MAGICFIND_STEP = 0.5
local MAGICFIND_MIN = 1
local MAGICFIND_MAX = 20

local magicFind = { known = false, mult = {} }
local magicFindRequest = { pending = false, deadline = nil }
-- Gold find: one multiplier on looted coin, held by the module as the core Rate.Drop.Money.
local GOLD_STEP = 0.5
local GOLD_MIN = 1
local GOLD_MAX = 20

local goldFind = { known = false, mult = 3 }
local goldFindRequest = { pending = false, deadline = nil }

-- Trash auto-sell: grey loot sold at pickup time so it never takes a bag slot. "sold" and
-- "copper" are the server's session totals, "swept" is what the last sweep command collected.
local trashSell = { known = false, enabled = true, sold = 0, copper = 0, swept = 0 }
local trashSellRequest = { pending = false, deadline = nil }
local UpdateTrashSellDisplay
local SetTrashSellStatus

-- Auction house: the market is run by the auction bot, which has no user front end. This page is
-- its only interface: on/off for its seller and buyer sides, and how busy each cycle is.
local AUCTION_ITEMS_STEP = 25
local AUCTION_ITEMS_MIN = 10
local AUCTION_ITEMS_MAX = 5000
local AUCTION_CANDIDATES_MIN = 1
local AUCTION_CANDIDATES_MAX = 50

local auction = {
    known = false,
    installed = false,
    seller = false,
    buyer = false,
    items = 0,
    candidates = 0,
    alliance = 0,
    horde = 0,
    neutral = 0,
}

local auctionRequest = { pending = false, deadline = nil }
local UpdateAuctionDisplay
local SetAuctionStatus

-- Instances stop restocking: a creature killed inside a dungeon stays dead for the run. "kept" is
-- how many creatures this session has kept down.
local instance = { known = false, enabled = true, kept = 0 }
local instanceRequest = { pending = false, deadline = nil }
local UpdateInstanceDisplay
local SetInstanceStatus

-- Convenience: the hearthstone's cooldown and hunter pet happiness, each its own switch.
local convenience = {
    hearthstone = true,
    hearthstoneKnown = false,
    cleared = 0,
    pets = true,
    petsKnown = false,
}

local hearthstoneRequest = { pending = false, deadline = nil }
local petsRequest = { pending = false, deadline = nil }
local UpdateConvenienceDisplay
local SetConvenienceStatus
local UpdateGoldFindDisplay
local SetGoldFindStatus
local goldFindValue
local UpdateMagicFindDisplay
local SetMagicFindStatus
local magicFindRows = {}

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

local function RequestBindingState()
    if UpdateBindingDisplay then
        UpdateBindingDisplay()
    end

    StartRequest(bindingRequest, ".warband binding")
end

local function RequestMagicFindState()
    if UpdateMagicFindDisplay then
        UpdateMagicFindDisplay()
    end

    StartRequest(magicFindRequest, ".warband magicfind")
end
local function RequestGoldFindState()
    if UpdateGoldFindDisplay then
        UpdateGoldFindDisplay()
    end

    StartRequest(goldFindRequest, ".warband goldfind")
end

local function RequestTrashSellState()
    if UpdateTrashSellDisplay then
        UpdateTrashSellDisplay()
    end

    StartRequest(trashSellRequest, ".warband trash")
end

local function RequestAuctionState()
    if UpdateAuctionDisplay then
        UpdateAuctionDisplay()
    end

    StartRequest(auctionRequest, ".warband ah")
end

local function RequestInstanceState()
    if UpdateInstanceDisplay then
        UpdateInstanceDisplay()
    end

    StartRequest(instanceRequest, ".warband instance")
end

local function RequestConvenienceState()
    if UpdateConvenienceDisplay then
        UpdateConvenienceDisplay()
    end

    StartRequest(hearthstoneRequest, ".warband hearthstone")
    StartRequest(petsRequest, ".warband pets")
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

    if bindingRequest.pending and GetTime() >= bindingRequest.deadline then
        ClearRequest(bindingRequest)
        SetBindingStatus(TEXT_BINDING_NO_REPLY, COLOR_GREY)
    end

    if magicFindRequest.pending and GetTime() >= magicFindRequest.deadline then
        ClearRequest(magicFindRequest)
    ClearRequest(goldFindRequest)
        SetMagicFindStatus(TEXT_MAGIC_FIND_NO_REPLY, COLOR_GREY)
    end
    if goldFindRequest.pending and GetTime() >= goldFindRequest.deadline then
        ClearRequest(goldFindRequest)
        SetGoldFindStatus(TEXT_GOLD_FIND_NO_REPLY, COLOR_GREY)
    end

    if trashSellRequest.pending and GetTime() >= trashSellRequest.deadline then
        ClearRequest(trashSellRequest)
        SetTrashSellStatus(TEXT_TRASH_SELL_NO_REPLY, COLOR_GREY)
    end

    if auctionRequest.pending and GetTime() >= auctionRequest.deadline then
        ClearRequest(auctionRequest)
        SetAuctionStatus("Unavailable: this worldserver does not answer .warband ah yet.", COLOR_GREY)
    end

    if instanceRequest.pending and GetTime() >= instanceRequest.deadline then
        ClearRequest(instanceRequest)
        SetInstanceStatus("Unavailable: this worldserver does not answer .warband instance yet.",
            COLOR_GREY)
    end

    if hearthstoneRequest.pending and GetTime() >= hearthstoneRequest.deadline then
        ClearRequest(hearthstoneRequest)
        SetConvenienceStatus("Unavailable: this worldserver does not answer .warband hearthstone.",
            COLOR_GREY)
    end

    if petsRequest.pending and GetTime() >= petsRequest.deadline then
        ClearRequest(petsRequest)
        SetConvenienceStatus("Unavailable: this worldserver does not answer .warband pets.",
            COLOR_GREY)
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

    if string.find(message or "", "WARBAND_GOLDFIND=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "WARBAND_GOLDFIND" and number then
                goldFind.mult = number
            end
        end

        ClearRequest(goldFindRequest)
        goldFind.known = true

        if UpdateGoldFindDisplay then
            UpdateGoldFindDisplay()
        end

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end
    if string.find(message or "", "WARBAND_HEARTHSTONE=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "enabled" then
                convenience.hearthstone = number == 1
            elseif key == "cleared" then
                convenience.cleared = number or 0
            end
        end

        ClearRequest(hearthstoneRequest)
        convenience.hearthstoneKnown = true

        if UpdateConvenienceDisplay then
            UpdateConvenienceDisplay()
        end

        return
    end

    if string.find(message or "", "WARBAND_PETS=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            if key == "enabled" then
                convenience.pets = tonumber(value) == 1
            end
        end

        ClearRequest(petsRequest)
        convenience.petsKnown = true

        if UpdateConvenienceDisplay then
            UpdateConvenienceDisplay()
        end

        return
    end

    if string.find(message or "", "WARBAND_INSTANCE=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "enabled" then
                instance.enabled = number == 1
            elseif key == "kept" then
                instance.kept = number or 0
            end
        end

        ClearRequest(instanceRequest)
        instance.known = true

        if UpdateInstanceDisplay then
            UpdateInstanceDisplay()
        end

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end

    if string.find(message or "", "WARBAND_AHBOT=", 1, true) then
        auction.installed = false

        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "installed" then
                auction.installed = number == 1
            elseif key == "seller" then
                auction.seller = number == 1
            elseif key == "buyer" then
                auction.buyer = number == 1
            elseif key == "items" then
                auction.items = number or 0
            elseif key == "candidates" then
                auction.candidates = number or 0
            elseif key == "alliance" then
                auction.alliance = number or 0
            elseif key == "horde" then
                auction.horde = number or 0
            elseif key == "neutral" then
                auction.neutral = number or 0
            end
        end

        ClearRequest(auctionRequest)
        auction.known = true

        if UpdateAuctionDisplay then
            UpdateAuctionDisplay()
        end

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end

    if string.find(message or "", "WARBAND_TRASHSELL=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "enabled" then
                trashSell.enabled = number == 1
            elseif key == "sold" then
                trashSell.sold = number or 0
            elseif key == "copper" then
                trashSell.copper = number or 0
            elseif key == "swept" then
                trashSell.swept = number or 0
            end
        end

        ClearRequest(trashSellRequest)
        trashSell.known = true

        if UpdateTrashSellDisplay then
            UpdateTrashSellDisplay()
        end

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end

    if string.find(message or "", "WARBAND_MAGICFIND=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if number and MAGICFIND_LABELS[key] then
                magicFind.mult[key] = number
            end
        end

        ClearRequest(magicFindRequest)
    ClearRequest(goldFindRequest)
        magicFind.known = true

        if UpdateMagicFindDisplay then
            UpdateMagicFindDisplay()
        end

        if RefreshDynamicPage then
            RefreshDynamicPage()
        end
        return
    end

    if string.find(message or "", "WARBAND_BINDING=", 1, true) then
        for key, value in string.gmatch(message, "([%a_]+)=([%d%.]+)") do
            local number = tonumber(value)
            if key == "enforced" then
                binding.enforced = number == 1
            end
        end

        ClearRequest(bindingRequest)
        binding.known = true

        if UpdateBindingDisplay then
            UpdateBindingDisplay()
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

-- Item binding: whether binding restricts item movement. The panel states the policy in words,
-- because "binding off" is easy to mistake for "items are unbound".
SetBindingStatus = function(text, color)
    WarbandPageBindingStatus:SetText(text)
    WarbandPageBindingStatus:SetTextColor(color[1], color[2], color[3])
end

UpdateBindingDisplay = function()
    if not binding.known then
        SetBindingStatus("Reading the binding policy...", COLOR_AMBER)
    elseif binding.enforced then
        SetBindingStatus("Binding enforced - the ordinary rule, a bound item stays with its owner",
            COLOR_GREY)
    else
        SetBindingStatus("Binding off - a bound item can be traded, mailed, sold and handed on",
            COLOR_GREEN)
    end

    local toggle = WarbandPageBindingToggle
    if binding.known and not binding.enforced then
        toggle:SetText("Turn binding on")
    else
        toggle:SetText("Turn binding off")
    end
end

function Warband_ToggleBinding()
    if not binding.known then
        SetBindingStatus("Waiting for the server before changing this...", COLOR_AMBER)
        StartRequest(bindingRequest, ".warband binding")
        return
    end

    local wanted = not binding.enforced

    if wanted then
        SetBindingStatus("Enforcing binding...", COLOR_AMBER)
        StartRequest(bindingRequest, ".warband binding on")
    else
        SetBindingStatus("Lifting the binding restriction...", COLOR_AMBER)
        StartRequest(bindingRequest, ".warband binding off")
    end
end

-- Magic find: one multiplier per quality, edited with a row of buttons each. The rows are built
-- once, then only the values and the worked example change.
SetMagicFindStatus = function(text, color)
    WarbandPageMagicFindStatus:SetText(text)
    WarbandPageMagicFindStatus:SetTextColor(color[1], color[2], color[3])
end

local function WorkedExample()
    local parts = {}

    for _, tier in ipairs(MAGICFIND_TIERS) do
        local mult = magicFind.mult[tier] or 1
        if mult > 1 then
            table.insert(parts, string.format("%s %.0f%%", string.lower(MAGICFIND_LABELS[tier]),
                math.min(100, 3 * mult)))
        end
    end

    if #parts == 0 then
        return ""
    end

    return "A 3% drop becomes: " .. table.concat(parts, ", ")
end

local function BuildMagicFindRows()
    if magicFindRows[1] then
        return
    end

    for index, tier in ipairs(MAGICFIND_TIERS) do
        local y = -104 - (index - 1) * 28

        local label = WarbandPageMagicFind:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        label:SetPoint("TOPLEFT", WarbandPageMagicFind, "TOPLEFT", 0, y)
        label:SetWidth(120)
        label:SetJustifyH("LEFT")
        label:SetText(MAGICFIND_LABELS[tier])

        local value = WarbandPageMagicFind:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
        value:SetPoint("TOPLEFT", WarbandPageMagicFind, "TOPLEFT", 130, y)
        value:SetWidth(160)
        value:SetJustifyH("LEFT")

        local down = CreateFrame("Button", nil, WarbandPageMagicFind, "UIPanelButtonTemplate")
        down:SetSize(28, 20)
        down:SetPoint("TOPLEFT", WarbandPageMagicFind, "TOPLEFT", 300, y + 4)
        down:SetText("-")
        down:SetScript("OnClick", function() Warband_AdjustMagicFind(tier, -MAGICFIND_STEP) end)

        local up = CreateFrame("Button", nil, WarbandPageMagicFind, "UIPanelButtonTemplate")
        up:SetSize(28, 20)
        up:SetPoint("TOPLEFT", WarbandPageMagicFind, "TOPLEFT", 334, y + 4)
        up:SetText("+")
        up:SetScript("OnClick", function() Warband_AdjustMagicFind(tier, MAGICFIND_STEP) end)

        magicFindRows[index] = { value = value }
    end

    local reset = CreateFrame("Button", nil, WarbandPageMagicFind, "UIPanelButtonTemplate")
    reset:SetSize(150, 22)
    reset:SetPoint("TOPLEFT", WarbandPageMagicFind, "TOPLEFT", 0, -104 - #MAGICFIND_TIERS * 28 - 6)
    reset:SetText("Reset to x1")
    reset:SetScript("OnClick", function()
        SetMagicFindStatus("Clearing the multipliers...", COLOR_AMBER)
        StartRequest(magicFindRequest, ".warband magicfind reset")
    end)
end

UpdateMagicFindDisplay = function()
    BuildMagicFindRows()

    local boosted = false
    for _, tier in ipairs(MAGICFIND_TIERS) do
        if (magicFind.mult[tier] or 1) > 1 then
            boosted = true
            break
        end
    end

    if not magicFind.known then
        SetMagicFindStatus("Reading the magic find values...", COLOR_AMBER)
    elseif boosted then
        SetMagicFindStatus("Live - better qualities drop more often, nothing else changes", COLOR_GREEN)
    else
        SetMagicFindStatus("Neutral - the loot tables are exactly as the game ships them", COLOR_GREY)
    end

    for index, tier in ipairs(MAGICFIND_TIERS) do
        local row = magicFindRows[index]
        if row then
            row.value:SetText(string.format("x%.2f", magicFind.mult[tier] or 1))
        end
    end

    WarbandPageMagicFindExample:SetText(WorkedExample())
end

function Warband_AdjustMagicFind(tier, delta)
    local current = magicFind.mult[tier] or 1
    local wanted = math.max(MAGICFIND_MIN, math.min(MAGICFIND_MAX, current + delta))

    if wanted == current then
        return
    end

    magicFind.mult[tier] = wanted
    UpdateMagicFindDisplay()
    SetMagicFindStatus("Applying the multiplier...", COLOR_AMBER)
    StartRequest(magicFindRequest, string.format(".warband magicfind %s %.2f", tier, wanted))
end

-- Gold find: a single multiplier row, built once.
SetGoldFindStatus = function(text, color)
    WarbandPageGoldFindStatus:SetText(text)
    WarbandPageGoldFindStatus:SetTextColor(color[1], color[2], color[3])
end

local function BuildGoldFindRow()
    if goldFindValue then
        return
    end

    local y = -104

    local label = WarbandPageGoldFind:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    label:SetPoint("TOPLEFT", WarbandPageGoldFind, "TOPLEFT", 0, y)
    label:SetWidth(120)
    label:SetJustifyH("LEFT")
    label:SetText("Coins")

    goldFindValue = WarbandPageGoldFind:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    goldFindValue:SetPoint("TOPLEFT", WarbandPageGoldFind, "TOPLEFT", 130, y)
    goldFindValue:SetWidth(160)
    goldFindValue:SetJustifyH("LEFT")

    local down = CreateFrame("Button", nil, WarbandPageGoldFind, "UIPanelButtonTemplate")
    down:SetSize(28, 20)
    down:SetPoint("TOPLEFT", WarbandPageGoldFind, "TOPLEFT", 300, y + 4)
    down:SetText("-")
    down:SetScript("OnClick", function() Warband_AdjustGoldFind(-GOLD_STEP) end)

    local up = CreateFrame("Button", nil, WarbandPageGoldFind, "UIPanelButtonTemplate")
    up:SetSize(28, 20)
    up:SetPoint("TOPLEFT", WarbandPageGoldFind, "TOPLEFT", 334, y + 4)
    up:SetText("+")
    up:SetScript("OnClick", function() Warband_AdjustGoldFind(GOLD_STEP) end)

    local reset = CreateFrame("Button", nil, WarbandPageGoldFind, "UIPanelButtonTemplate")
    reset:SetSize(150, 22)
    reset:SetPoint("TOPLEFT", WarbandPageGoldFind, "TOPLEFT", 0, y - 34)
    reset:SetText("Reset to x1")
    reset:SetScript("OnClick", function()
        SetGoldFindStatus("Clearing the multiplier...", COLOR_AMBER)
        StartRequest(goldFindRequest, ".warband goldfind reset")
    end)
end

UpdateGoldFindDisplay = function()
    BuildGoldFindRow()

    if not goldFind.known then
        SetGoldFindStatus("Reading the gold find multiplier...", COLOR_AMBER)
    elseif goldFind.mult > 1 then
        SetGoldFindStatus(string.format("Live - looted coin is multiplied by x%.2f", goldFind.mult),
            COLOR_GREEN)
    else
        SetGoldFindStatus("Neutral - coin is exactly as the loot drops it", COLOR_GREY)
    end

    goldFindValue:SetText(string.format("x%.2f", goldFind.mult or 1))

    if (goldFind.mult or 1) > 1 then
        WarbandPageGoldFindExample:SetText(string.format(
            "A 50 silver pile becomes %.1f gold", 0.5 * goldFind.mult))
    else
        WarbandPageGoldFindExample:SetText("")
    end
end

function Warband_AdjustGoldFind(delta)
    local current = goldFind.mult or 1
    local wanted = math.max(GOLD_MIN, math.min(GOLD_MAX, current + delta))

    if wanted == current then
        return
    end

    goldFind.mult = wanted
    UpdateGoldFindDisplay()
    SetGoldFindStatus("Applying the multiplier...", COLOR_AMBER)
    StartRequest(goldFindRequest, string.format(".warband goldfind %.2f", wanted))
end

-- Trash auto-sell: one toggle and a sweep button. "Sold at pickup" is easy to disbelieve until the
-- bags stay empty, so the page also reports what the feature has cleared so far.
local function FormatCopper(copper)
    copper = copper or 0

    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100

    if gold > 0 then
        return string.format("%dg %ds %dc", gold, silver, rest)
    end

    if silver > 0 then
        return string.format("%ds %dc", silver, rest)
    end

    return string.format("%dc", rest)
end

SetTrashSellStatus = function(text, color)
    WarbandPageTrashSellStatus:SetText(text)
    WarbandPageTrashSellStatus:SetTextColor(color[1], color[2], color[3])
end

UpdateTrashSellDisplay = function()
    if not trashSell.known then
        SetTrashSellStatus("Reading the trash auto-sell state...", COLOR_AMBER)
    elseif trashSell.enabled then
        SetTrashSellStatus("Live - grey loot is sold on pickup and never takes a bag slot", COLOR_GREEN)
    else
        SetTrashSellStatus("Off - grey loot stays in the bags", COLOR_GREY)
    end

    WarbandPageTrashSellToggle:SetText(trashSell.enabled and "Trash sell: on" or "Trash sell: off")

    if not trashSell.known then
        WarbandPageTrashSellDetail:SetText("Waiting for the server...")
        return
    end

    local detail = string.format("Cleared so far: %d item(s) for %s", trashSell.sold,
        FormatCopper(trashSell.copper))

    if trashSell.swept and trashSell.swept > 0 then
        detail = detail .. string.format("\nThe last sweep sold %d item(s) from the bags.",
            trashSell.swept)
    end

    WarbandPageTrashSellDetail:SetText(detail)
end

function Warband_ToggleTrashSell()
    if not trashSell.known then
        SetTrashSellStatus("Waiting for the server before changing this...", COLOR_AMBER)
        StartRequest(trashSellRequest, ".warband trash")
        return
    end

    if trashSell.enabled then
        SetTrashSellStatus("Switching trash sell off...", COLOR_AMBER)
        StartRequest(trashSellRequest, ".warband trash off")
    else
        SetTrashSellStatus("Switching trash sell on...", COLOR_AMBER)
        StartRequest(trashSellRequest, ".warband trash on")
    end
end

function Warband_SellJunkNow()
    SetTrashSellStatus("Selling the junk in the bags...", COLOR_AMBER)
    StartRequest(trashSellRequest, ".warband trash sell")
end

-- Auction house: the bot has no interface of its own, so this page is it.
SetAuctionStatus = function(text, color)
    WarbandPageAuctionHouseStatus:SetText(text)
    WarbandPageAuctionHouseStatus:SetTextColor(color[1], color[2], color[3])
end

UpdateAuctionDisplay = function()
    if not auction.known then
        SetAuctionStatus("Reading the auction house settings...", COLOR_AMBER)
    elseif not auction.installed then
        SetAuctionStatus("No auction bot on this worldserver", COLOR_GREY)
    elseif auction.seller and auction.buyer then
        SetAuctionStatus("Live - the houses are stocked and your listings can be bought", COLOR_GREEN)
    elseif auction.seller then
        SetAuctionStatus("Seller only - stocked, but nothing buys your listings", COLOR_AMBER)
    elseif auction.buyer then
        SetAuctionStatus("Buyer only - your listings sell, the houses are not restocked", COLOR_AMBER)
    else
        SetAuctionStatus("Both sides off - the market is only what players put there", COLOR_GREY)
    end

    WarbandPageAuctionHouseSellerToggle:SetText(auction.seller and "Seller: on" or "Seller: off")
    WarbandPageAuctionHouseBuyerToggle:SetText(auction.buyer and "Buyer: on" or "Buyer: off")

    if auction.installed then
        WarbandPageAuctionHouseDetail:SetText(string.format(
            "%d listings added per cycle, %d checked for buying per cycle\nStock targets: %d Alliance, %d Horde, %d Neutral",
            auction.items, auction.candidates, auction.alliance, auction.horde, auction.neutral))
    else
        WarbandPageAuctionHouseDetail:SetText("")
    end
end

function Warband_ToggleAuctionSeller()
    if auction.known and not auction.installed then
        return
    end

    SetAuctionStatus("Switching the seller...", COLOR_AMBER)
    StartRequest(auctionRequest,
        auction.seller and ".warband ah seller off" or ".warband ah seller on")
end

function Warband_ToggleAuctionBuyer()
    if auction.known and not auction.installed then
        return
    end

    SetAuctionStatus("Switching the buyer...", COLOR_AMBER)
    StartRequest(auctionRequest,
        auction.buyer and ".warband ah buyer off" or ".warband ah buyer on")
end

function Warband_StepAuctionItems(delta)
    if auction.known and not auction.installed then
        return
    end

    local wanted = math.max(AUCTION_ITEMS_MIN, math.min(AUCTION_ITEMS_MAX, auction.items + delta))
    SetAuctionStatus("Applying...", COLOR_AMBER)
    StartRequest(auctionRequest, ".warband ah items " .. wanted)
end

function Warband_StepAuctionCandidates(delta)
    if auction.known and not auction.installed then
        return
    end

    local wanted = math.max(AUCTION_CANDIDATES_MIN,
        math.min(AUCTION_CANDIDATES_MAX, auction.candidates + delta))
    SetAuctionStatus("Applying...", COLOR_AMBER)
    StartRequest(auctionRequest, ".warband ah candidates " .. wanted)
end

function Warband_RefreshAuction()
    if auction.known and not auction.installed then
        return
    end

    SetAuctionStatus("Restocking the auction houses...", COLOR_AMBER)
    StartRequest(auctionRequest, ".warband ah repopulate")
end

-- Instances: one switch, and a count of what this session has kept down.
SetInstanceStatus = function(text, color)
    WarbandPageInstanceStatus:SetText(text)
    WarbandPageInstanceStatus:SetTextColor(color[1], color[2], color[3])
end

UpdateInstanceDisplay = function()
    if not instance.known then
        SetInstanceStatus("Reading whether instances restock...", COLOR_AMBER)
    elseif instance.enabled then
        SetInstanceStatus("Live - a creature killed inside a dungeon stays dead for the run",
            COLOR_GREEN)
    else
        SetInstanceStatus("Off - instance creatures respawn on the ordinary timers", COLOR_GREY)
    end

    WarbandPageInstanceToggle:SetText(instance.enabled and "Instances stay dead: on"
        or "Instances stay dead: off")

    if instance.known then
        WarbandPageInstanceDetail:SetText(string.format(
            "Kept down this session: %d creature(s)\nA reset, manual or the daily one, brings a dungeon back.",
            instance.kept))
    else
        WarbandPageInstanceDetail:SetText("Waiting for the server...")
    end
end

function Warband_ToggleInstanceNoRespawn()
    if not instance.known then
        SetInstanceStatus("Waiting for the server before changing this...", COLOR_AMBER)
        StartRequest(instanceRequest, ".warband instance")
        return
    end

    if instance.enabled then
        SetInstanceStatus("Switching it off...", COLOR_AMBER)
        StartRequest(instanceRequest, ".warband instance off")
    else
        SetInstanceStatus("Switching it on...", COLOR_AMBER)
        StartRequest(instanceRequest, ".warband instance on")
    end
end

-- Convenience: hearthstone cooldown and pet happiness.
SetConvenienceStatus = function(text, color)
    WarbandPageConvenienceStatus:SetText(text)
    WarbandPageConvenienceStatus:SetTextColor(color[1], color[2], color[3])
end

UpdateConvenienceDisplay = function()
    if not (convenience.hearthstoneKnown and convenience.petsKnown) then
        SetConvenienceStatus("Reading the settings...", COLOR_AMBER)
    elseif convenience.hearthstone and convenience.pets then
        SetConvenienceStatus("Live - the hearthstone is always ready and every pet stays happy",
            COLOR_GREEN)
    else
        SetConvenienceStatus("Partly on - see the buttons", COLOR_AMBER)
    end

    WarbandPageConvenienceHearthstone:SetText(convenience.hearthstone
        and "Hearthstone: no cooldown" or "Hearthstone: normal cooldown")
    WarbandPageConveniencePets:SetText(convenience.pets
        and "Pets: always happy" or "Pets: normal happiness")

    if convenience.hearthstoneKnown then
        WarbandPageConvenienceDetail:SetText(string.format(
            "Hearthstone cooldowns cleared this session: %d", convenience.cleared))
    else
        WarbandPageConvenienceDetail:SetText("")
    end
end

function Warband_ToggleHearthstone()
    if convenience.hearthstoneKnown and convenience.hearthstone then
        SetConvenienceStatus("Switching the hearthstone cooldown back on...", COLOR_AMBER)
        StartRequest(hearthstoneRequest, ".warband hearthstone off")
    else
        SetConvenienceStatus("Clearing the hearthstone cooldown...", COLOR_AMBER)
        StartRequest(hearthstoneRequest, ".warband hearthstone on")
    end
end

function Warband_TogglePets()
    if convenience.petsKnown and convenience.pets then
        SetConvenienceStatus("Letting pets go back to normal happiness...", COLOR_AMBER)
        StartRequest(petsRequest, ".warband pets off")
    else
        SetConvenienceStatus("Keeping pets happy...", COLOR_AMBER)
        StartRequest(petsRequest, ".warband pets on")
    end
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

        if binding.known and not binding.enforced then
            table.insert(lines, "- Gear sharing: any bound item can be traded, mailed, sold and "
                .. "handed to a companion")
        elseif binding.known then
            table.insert(lines, "- Binding enforced: a bound item stays with the character that "
                .. "bound it")
        end

        if goldFind.known then
            table.insert(lines, string.format("%sGold find: looted coin x%.1f", "- ", goldFind.mult or 1))
        end

        if magicFind.known then
            table.insert(lines, "- Magic find: green x" .. string.format("%.1f", magicFind.mult.green or 1)
                .. ", blue x" .. string.format("%.1f", magicFind.mult.blue or 1)
                .. ", purple x" .. string.format("%.1f", magicFind.mult.purple or 1)
                .. ", orange x" .. string.format("%.1f", magicFind.mult.orange or 1))
        end

        if trashSell.known and trashSell.enabled then
            table.insert(lines, "- Trash sell: grey loot is sold on pickup, so bags stay empty")
        end

        if auction.known and auction.installed and auction.seller then
            table.insert(lines, auction.buyer
                and "- Auction house: stocked by the bot, and it buys what the party lists"
                or "- Auction house: stocked by the bot, selling waits for a buyer")
        end

        if instance.known and instance.enabled then
            table.insert(lines, "- Instances: a creature killed inside one stays dead for the run")
        end

        if convenience.hearthstoneKnown and convenience.hearthstone then
            table.insert(lines, "- Hearthstone: no cooldown")
        end

        if convenience.petsKnown and convenience.pets then
            table.insert(lines, "- Pets: always happy, companions included")
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
    WarbandPageBinding:Hide()
    WarbandPageMagicFind:Hide()
    WarbandPageGoldFind:Hide()
    WarbandPageTrashSell:Hide()
    WarbandPageAuctionHouse:Hide()
    WarbandPageInstance:Hide()
    WarbandPageConvenience:Hide()

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

    if node.page == "binding" then
        if UpdateBindingDisplay then
            UpdateBindingDisplay()
        end

        WarbandPageBinding:Show()
        return
    end

    if node.page == "goldfind" then
        if UpdateGoldFindDisplay then
            UpdateGoldFindDisplay()
        end

        WarbandPageGoldFind:Show()
        return
    end
    if node.page == "magicfind" then
        if UpdateMagicFindDisplay then
            UpdateMagicFindDisplay()
        end

        WarbandPageMagicFind:Show()
        return
    end

    if node.page == "trashsell" then
        if UpdateTrashSellDisplay then
            UpdateTrashSellDisplay()
        end

        WarbandPageTrashSell:Show()
        return
    end

    if node.page == "auctionhouse" then
        if UpdateAuctionDisplay then
            UpdateAuctionDisplay()
        end

        WarbandPageAuctionHouse:Show()
        return
    end

    if node.page == "instances" then
        if UpdateInstanceDisplay then
            UpdateInstanceDisplay()
        end

        WarbandPageInstance:Show()
        return
    end

    if node.page == "convenience" then
        if UpdateConvenienceDisplay then
            UpdateConvenienceDisplay()
        end

        WarbandPageConvenience:Show()
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
    RequestBindingState()
    RequestMagicFindState()
    RequestGoldFindState()
    RequestTrashSellState()
    RequestAuctionState()
    RequestInstanceState()
    RequestConvenienceState()
end

function Warband_OnHide()
    ClearRequest(xpRequest)
    ClearRequest(catchUpRequest)
    ClearRequest(gatherRequest)
    ClearRequest(bindingRequest)
    ClearRequest(magicFindRequest)
    ClearRequest(goldFindRequest)
    ClearRequest(trashSellRequest)
    ClearRequest(auctionRequest)
    ClearRequest(instanceRequest)
    ClearRequest(hearthstoneRequest)
    ClearRequest(petsRequest)
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

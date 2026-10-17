-- Warband party access: a member strip on the bag frame and on the character frame.
--
-- The bot addon (MultiBot) already knows how to open a follower's inventory and character sheet.
-- What it has no one-click way in from the windows the player actually uses, and that is the whole
-- point of this file: a strip of party members on the bags and on the character sheet, each button
-- pointing at those existing windows.
--
-- This file never talks to the server by itself. Every click calls a MultiBot function, so the
-- whisper protocol, the payload sync and the item moves stay MultiBot's business; Warband only
-- supplies the doorway. If MultiBot is not loaded the strip says so and does nothing.

local ADDON_NAME = "Warband"

local ACTION_BAGS = "bags"
local ACTION_SHEET = "sheet"

local BUTTON_WIDTH = 60
local BUTTON_HEIGHT = 20
local BUTTON_GAP = 4

local strips = {}

local function MultiBotReady()
    return type(MultiBot) == "table"
        and type(MultiBot.RequestBotInventory) == "function"
        and type(MultiBot.OpenCharacterInfo) == "function"
end

local function OpenAction(action, name)
    if not MultiBotReady() then
        return false
    end

    if action == ACTION_BAGS then
        MultiBot.RequestBotInventory(name)
    else
        MultiBot.OpenCharacterInfo(name)
    end

    return true
end

local OTHER_ACTION = { bags = ACTION_SHEET, sheet = ACTION_BAGS }

local ACTION_LABEL = {
    bags = "bags",
    sheet = "character sheet",
}

-- The companions only, never the player: the player's own items belong in the real bag frame and
-- the real character sheet, which are already open behind this strip. MultiBot's windows are for
-- bots, and asking them for a real account shows an empty list.
local function PartyNames()
    local names = {}

    if IsInGroup() then
        for index = 1, GetNumPartyMembers() do
            local name = UnitName("party" .. index)
            if name then
                table.insert(names, name)
            end
        end
    end

    return names
end

local function CreateStrip(name, action, captionText)
    local strip = CreateFrame("Frame", name, UIParent)
    strip:SetSize(64, BUTTON_HEIGHT + 4)
    strip.action = action
    strip.captionText = captionText
    strip.buttons = {}

    local caption = strip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    caption:SetPoint("BOTTOMLEFT", strip, "TOPLEFT", 0, 3)
    caption:SetText(captionText)
    caption:SetTextColor(1, 0.82, 0)

    strip.caption = caption
    strips[name] = strip

    return strip
end

local function MakeButton(strip, index)
    local button = CreateFrame("Button", strip:GetName() .. "Member" .. index, strip,
        "UIPanelButtonTemplate")
    button:SetSize(BUTTON_WIDTH, BUTTON_HEIGHT)
    button:SetPoint("LEFT", strip, "LEFT", (index - 1) * (BUTTON_WIDTH + BUTTON_GAP), 0)
    button:RegisterForClicks("LeftButtonUp")

    button:SetScript("OnClick", function(self)
        local action = strip.action

        -- Shift asks for the other window, so one row covers both without a second strip.
        if IsShiftKeyDown() then
            action = OTHER_ACTION[action]
        end

        if not OpenAction(action, self.memberName) then
            strip.caption:SetText(strip.captionText .. "  - MultiBot not loaded")
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(self.memberName, 1, 1, 1)

        if not MultiBotReady() then
            GameTooltip:AddLine("MultiBot is not loaded, so there is no window to open.",
                1, 0.4, 0.4)
        else
            GameTooltip:AddLine(string.format("Click: open %s's %s", self.memberName,
                ACTION_LABEL[strip.action]), 1, 1, 1)
            GameTooltip:AddLine(string.format("Shift-click: their %s",
                ACTION_LABEL[OTHER_ACTION[strip.action]]), 0.8, 0.8, 0.8)
        end

        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    button:Hide()

    return button
end

local function RefreshStrip(strip)
    local names = PartyNames()

    for index, name in ipairs(names) do
        local button = strip.buttons[index] or MakeButton(strip, index)
        strip.buttons[index] = button
        button.memberName = name
        button:SetText(string.sub(name, 1, 6))
        button:Show()
    end

    for index = #names + 1, #strip.buttons do
        strip.buttons[index]:Hide()
    end

    strip:SetWidth(#names * (BUTTON_WIDTH + BUTTON_GAP))

    -- No companions in the party: nothing to point at, so the strip goes away entirely rather than
    -- sitting there with a caption and no buttons.
    if #names == 0 then
        strip:Hide()
        return false
    end

    if MultiBotReady() then
        strip.caption:SetText(strip.captionText)
    else
        strip.caption:SetText(strip.captionText .. "  - MultiBot not loaded")
    end

    return true
end

local function RefreshAllStrips()
    for _, strip in pairs(strips) do
        RefreshStrip(strip)
    end
end

local function AttachStrip(strip, parent, caption)
    strip:SetParent(parent)
    strip:SetPoint("BOTTOMLEFT", parent, "TOPLEFT", 0, 6)

    parent:HookScript("OnShow", function()
        if RefreshStrip(strip) then
            strip:Show()
        end
    end)

    parent:HookScript("OnHide", function()
        strip:Hide()
    end)

    strip:Hide()
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("GROUP_ROSTER_UPDATE")
loader:SetScript("OnEvent", function(self, event, name)
    if event == "ADDON_LOADED" then
        if name ~= ADDON_NAME then
            return
        end

        local bags = CreateStrip("WarbandBagMembers", ACTION_BAGS, "PARTY BAGS")
        local sheet = CreateStrip("WarbandSheetMembers", ACTION_SHEET, "PARTY SHEET")

        if ContainerFrame1 then
            AttachStrip(bags, ContainerFrame1)
        end

        if CharacterFrame then
            AttachStrip(sheet, CharacterFrame)
        end

        self:UnregisterEvent("ADDON_LOADED")
        return
    end

    RefreshAllStrips()
end)

-- Warband window layout: the frames Blizzard anchors for you become draggable for good.
--
-- The client marks some windows movable and others not. The character sheet and the container
-- frames are in the second group: they are anchored to fixed points and their frames are not
-- flagged movable, so dragging does nothing. That flag is just a property an addon may set, so
-- this file sets it once at load — there is no mode to turn on, no command to remember: the
-- windows simply move when you drag them, and stay where you left them.
--
-- Drag by the frame's own edge or title area, not by an item slot: a slot is a button of its own
-- and it keeps the click. Positions are saved per character in WarbandDB.

local MOVABLE_FRAMES = {
    "ContainerFrame1",
    "ContainerFrame2",
    "ContainerFrame3",
    "ContainerFrame4",
    "ContainerFrame5",
    "CharacterFrame",
}

local function SaveAnchor(frame)
    local frameName = frame:GetName()
    if not frameName then
        return
    end

    local point, _, relativePoint, x, y = frame:GetPoint(1)

    WarbandDB.layout = WarbandDB.layout or {}
    WarbandDB.layout[frameName] = {
        point = point or "CENTER",
        relativePoint = relativePoint or "CENTER",
        x = x or 0,
        y = y or 0,
    }
end

local function ApplyAnchor(frame)
    local layout = WarbandDB and WarbandDB.layout
    local saved = layout and layout[frame:GetName()]
    if not saved then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(saved.point, UIParent, saved.relativePoint, saved.x, saved.y)
end

local function MakeMovable(frame)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SaveAnchor(self)
    end)
end

-- The character sheet is special: its body is a full-size child frame (PaperDollFrame, and the
-- tab panes inside it), so every click lands on a child and the window never sees the drag. A thin
-- permanent strip across the top edge gives it somewhere to be grabbed, without covering a tab or
-- a button.
local function AddGripStrip(frame)
    local gripName = frame:GetName() .. "WarbandGrip"
    if _G[gripName] then
        return
    end

    local grip = CreateFrame("Button", gripName, frame)
    grip:SetHeight(10)
    grip:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 0, 0)
    grip:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)
    grip:SetFrameLevel(frame:GetFrameLevel() + 20)

    local texture = grip:CreateTexture(nil, "BACKGROUND")
    texture:SetAllPoints(grip)
    texture:SetTexture("Interface\\Buttons\\WHITE8X8")
    texture:SetVertexColor(0, 0, 0, 0.45)

    local dots = grip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dots:SetPoint("CENTER")
    dots:SetText("....")
    dots:SetTextColor(1, 0.82, 0, 0.7)

    grip:RegisterForDrag("LeftButton")
    grip:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    grip:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveAnchor(frame)
    end)

    grip:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Drag to move this window", 1, 1, 1)
        GameTooltip:Show()
    end)
    grip:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local loader = CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent", function(self, event, name)
    if name ~= "Warband" then
        return
    end

    WarbandDB = WarbandDB or {}

    for _, frameName in ipairs(MOVABLE_FRAMES) do
        local frame = _G[frameName]

        if frame then
            ApplyAnchor(frame)
            MakeMovable(frame)

            if frameName == "CharacterFrame" then
                AddGripStrip(frame)
            end
        end
    end

    self:UnregisterEvent("ADDON_LOADED")
end)

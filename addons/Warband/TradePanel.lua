-- Warband trade gold panel.
--
-- A small frame that attaches to the side of the trade window and goes away with it. It exists for
-- one job: telling the server "the companion is paying this much" so the trade window fills itself,
-- instead of the whisper sequence (t <amount> twice) that has to be remembered exactly.
--
-- The panel is deliberately tiny: the partner's purse, a gold / silver / copper amount, and one
-- button. Everything it sends is a Warband command:
--
--   .warband trade                    the reply WARBAND_TRADE=open=..;partner=..;purse=..;inTrade=..
--   .warband trade gold <g s c>       the reply WARBAND_TRADEGOLD=ok=..;partner=..;amount=..;purse=..

local PANEL_WIDTH = 158
local PANEL_HEIGHT = 132
local STEP_HEIGHT = 18
local AMOUNT_LIMIT = { gold = 9999, silver = 99, copper = 99 }

local panel
local status
local purseLine
local amountValue = {}
local amount = { gold = 0, silver = 0, copper = 0 }
local partnerName
local partnerPurse
local requestPending = false

local function totalCopper()
    return amount.gold * 10000 + amount.silver * 100 + amount.copper
end

local function formatMoney(copper)
    local gold = math.floor(copper / 10000)
    local silver = math.floor((copper % 10000) / 100)
    local rest = copper % 100

    local parts = {}
    if gold > 0 then
        parts[#parts + 1] = gold .. "g"
    end
    if silver > 0 then
        parts[#parts + 1] = silver .. "s"
    end
    if rest > 0 or #parts == 0 then
        parts[#parts + 1] = rest .. "c"
    end

    return table.concat(parts, " ")
end

local function setStatus(text, color)
    if not status then
        return
    end

    status:SetText(text or "")
    if color then
        status:SetTextColor(color[1], color[2], color[3])
    end
end

local function updatePurseLine()
    if not purseLine then
        return
    end

    if not partnerName then
        purseLine:SetText("Waiting for the trade...")
        return
    end

    if partnerPurse then
        purseLine:SetText(string.format("%s carries %s", partnerName, formatMoney(partnerPurse)))
    else
        purseLine:SetText(partnerName)
    end
end

local function updateAmountLabels()
    for key, label in pairs(amountValue) do
        label:SetText(string.format("%d", amount[key]))
    end
end

local function resetAmount()
    amount.gold, amount.silver, amount.copper = 0, 0, 0
    updateAmountLabels()
end

local function buildAmountCommand()
    local copper = totalCopper()
    if copper == 0 then
        return "0"
    end

    local parts = {}
    if amount.gold > 0 then
        parts[#parts + 1] = amount.gold .. "g"
    end
    if amount.silver > 0 then
        parts[#parts + 1] = amount.silver .. "s"
    end
    if amount.copper > 0 then
        parts[#parts + 1] = amount.copper .. "c"
    end

    return table.concat(parts)
end

local function sendTradeCommand(extra)
    local command = ".warband trade"
    if extra then
        command = command .. " " .. extra
    end

    SendChatMessage(command, "SAY")
end

local function stepAmount(key, delta)
    local limit = AMOUNT_LIMIT[key] or 99
    local value = amount[key] + delta

    if value < 0 then
        value = 0
    elseif value > limit then
        value = limit
    end

    if value == amount[key] then
        return
    end

    amount[key] = value
    updateAmountLabels()
end

-- The boxes are editable: typing a number is kept, clamped to the column's range and written back,
-- so the buttons and the keyboard always agree on what the trade will be filled with.
local function commitAmount(key)
    local box = amountValue[key]
    if not box then
        return
    end

    local limit = AMOUNT_LIMIT[key] or 99
    local value = math.floor(tonumber(box:GetText()) or 0)

    if value < 0 then
        value = 0
    elseif value > limit then
        value = limit
    end

    amount[key] = value
    box:SetText(string.format("%d", value))
end

local function onFill()
    if totalCopper() == 0 then
        setStatus("Set an amount first.", { 1, 0.55, 0.25 })
        return
    end

    setStatus("Filling the trade...", { 1, 0.82, 0 })
    sendTradeCommand("gold " .. buildAmountCommand())
end

local function makeStepper(parent, key, label, offsetY)
    local caption = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    caption:SetPoint("TOPLEFT", 8, offsetY)
    caption:SetText(label)

    local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    minus:SetSize(18, STEP_HEIGHT)
    minus:SetPoint("TOPLEFT", 46, offsetY + 2)
    minus:SetText("-")
    minus:SetScript("OnClick", function() stepAmount(key, -1) end)

    local value = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    value:SetSize(34, 18)
    value:SetPoint("LEFT", minus, "RIGHT", 4, 0)
    value:SetAutoFocus(false)
    value:SetMaxLetters(4)
    value:SetNumeric(true)
    value:SetJustifyH("CENTER")
    value:SetText("0")
    value:SetScript("OnEnterPressed", function(self)
        commitAmount(key)
        self:ClearFocus()
    end)
    value:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    value:SetScript("OnEditFocusLost", function()
        commitAmount(key)
    end)
    value:SetScript("OnTextChanged", function(self, userInput)
        if not userInput then
            return
        end

        commitAmount(key)
    end)
    amountValue[key] = value

    local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    plus:SetSize(18, STEP_HEIGHT)
    plus:SetPoint("LEFT", value, "RIGHT", 4, 0)
    plus:SetText("+")
    plus:SetScript("OnClick", function() stepAmount(key, 1) end)
end

local function anchorBesideTrade()
    if not panel then
        return
    end

    panel:ClearAllPoints()

    if TradeFrame and TradeFrame:GetLeft() and TradeFrame:GetLeft() > PANEL_WIDTH + 40 then
        panel:SetPoint("TOPRIGHT", TradeFrame, "TOPLEFT", -8, 0)
    elseif TradeFrame then
        panel:SetPoint("TOPLEFT", TradeFrame, "TOPRIGHT", 8, 0)
    else
        panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function createPanel()
    if panel then
        return
    end

    panel = CreateFrame("Frame", "WarbandTradePanel", UIParent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:SetToplevel(true)
    panel:SetClampedToScreen(true)
    panel:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", panel.StartMoving)
    panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
    panel:Hide()

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    title:SetPoint("TOPLEFT", 8, -8)
    title:SetText("Warband gold")
    title:SetTextColor(1, 0.82, 0)

    purseLine = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    purseLine:SetPoint("TOPLEFT", 8, -24)
    purseLine:SetWidth(PANEL_WIDTH - 16)
    purseLine:SetJustifyH("LEFT")
    purseLine:SetText("Waiting for the trade...")

    makeStepper(panel, "gold", "Gold", -42)
    makeStepper(panel, "silver", "Silver", -62)
    makeStepper(panel, "copper", "Copper", -82)

    local fill = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    fill:SetSize(PANEL_WIDTH - 16, 20)
    fill:SetPoint("TOPLEFT", 8, -100)
    fill:SetText("Put in trade")
    fill:SetScript("OnClick", onFill)

    status = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", 8, -122)
    status:SetWidth(PANEL_WIDTH - 16)
    status:SetJustifyH("LEFT")
    status:SetText("")

    updateAmountLabels()
end

local function parseTradeReply(message)
    if string.find(message, "WARBAND_TRADE=", 1, true) then
        requestPending = false

        if string.find(message, "open=0", 1, true) then
            partnerName = nil
            partnerPurse = nil
            updatePurseLine()
            return true
        end

        partnerName = string.match(message, "partner=([^;]+)")
        partnerPurse = tonumber(string.match(message, "purse=(%d+)"))

        updatePurseLine()
        return true
    end

    if string.find(message, "WARBAND_TRADEGOLD=", 1, true) then
        partnerName = string.match(message, "partner=([^;]+)") or partnerName
        partnerPurse = tonumber(string.match(message, "purse=(%d+)")) or partnerPurse

        if string.find(message, "ok=1", 1, true) then
            local amountSent = tonumber(string.match(message, "amount=(%d+)")) or totalCopper()
            resetAmount()
            setStatus(string.format("%s in the trade from %s", formatMoney(amountSent),
                partnerName or "the companion"), { 0.1, 1, 0.1 })
        else
            local reason = string.match(message, "reason=([%a]+)") or "unknown"
            if reason == "notrade" then
                setStatus("No trade is open.", { 1, 0.25, 0.25 })
            elseif reason == "notcompanion" then
                setStatus("That trade partner is another player.", { 1, 0.25, 0.25 })
            elseif reason == "nofunds" then
                setStatus(string.format("They only carry %s.", formatMoney(partnerPurse or 0)),
                    { 1, 0.25, 0.25 })
            else
                setStatus("Could not fill the trade.", { 1, 0.25, 0.25 })
            end
        end

        updatePurseLine()
        return true
    end

    return false
end

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("TRADE_SHOW")
watcher:RegisterEvent("TRADE_CLOSED")
watcher:RegisterEvent("CHAT_MSG_SYSTEM")

watcher:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "Warband" then
            return
        end

        self:UnregisterEvent("ADDON_LOADED")
        createPanel()
        return
    end

    if event == "TRADE_SHOW" then
        createPanel()
        partnerName = UnitName("NPC")
        partnerPurse = nil
        resetAmount()
        setStatus("", nil)
        updatePurseLine()
        anchorBesideTrade()
        panel:Show()
        sendTradeCommand(nil)
        requestPending = true
        return
    end

    if event == "TRADE_CLOSED" then
        if panel then
            panel:Hide()
        end

        partnerName = nil
        partnerPurse = nil
        requestPending = false
        return
    end

    if event == "CHAT_MSG_SYSTEM" then
        parseTradeReply(arg1 or "")
    end
end)

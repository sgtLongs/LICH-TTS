local ChatService = require("src/ChatService")

local TurnSystem = {}

-- These are the six seats used by the game, in clockwise turn order.
local PLAYER_COLORS = {
    "White",
    "Brown",
    "Red",
    "Green",
    "Teal",
    "Blue"
}

local PLAYER_HEX_COLORS = {
    White = "#FFFFFF",
    Brown = "#713B17",
    Red = "#C83232",
    Green = "#2E9F4D",
    Teal = "#21B19B",
    Blue = "#2E6DD8"
}

local currentTurnIndex = 1

local function getCurrentColor()
    return PLAYER_COLORS[currentTurnIndex]
end

local function getPlayerName(playerColor)
    local player = Player[playerColor]

    if player ~= nil and player.steam_name ~= nil and player.steam_name ~= "" then
        return player.steam_name
    end

    return playerColor
end

local function updateUi()
    local currentColor = getCurrentColor()
    local playerName = getPlayerName(currentColor)

    UI.setAttribute("turnPlayerName", "text", playerName .. "'s Turn")
    UI.setAttribute("turnPlayerName", "color", PLAYER_HEX_COLORS[currentColor])
    UI.setAttribute("turnColorName", "text", currentColor .. " Player")

    for _, playerColor in ipairs(PLAYER_COLORS) do
        local buttonId = "endTurn" .. playerColor
        local isCurrentPlayer = playerColor == currentColor

        UI.setAttribute(
            buttonId,
            "text",
            isCurrentPlayer and "END MY TURN" or "WAITING..."
        )
        UI.setAttribute(buttonId, "interactable", isCurrentPlayer and "true" or "false")
    end
end

local function announceTurn()
    local currentColor = getCurrentColor()
    local playerName = getPlayerName(currentColor)

    ChatService.sayToAll(playerName .. " (" .. currentColor .. "), it is your turn!")
end

function TurnSystem.onLoad(savedTurnState)
    if type(savedTurnState) == "table" then
        local savedIndex = tonumber(savedTurnState.currentTurnIndex)

        if savedIndex ~= nil and savedIndex >= 1 and savedIndex <= #PLAYER_COLORS then
            currentTurnIndex = math.floor(savedIndex)
        end
    end

    -- Waiting one frame ensures the Global XML has been created before it is edited.
    Wait.frames(function()
        updateUi()
        announceTurn()
    end, 1)
end

function TurnSystem.getSaveState()
    return {
        currentTurnIndex = currentTurnIndex
    }
end

function TurnSystem.endTurn(playerColor)
    local currentColor = getCurrentColor()

    if playerColor ~= currentColor then
        broadcastToColor(
            "It is " .. getPlayerName(currentColor) .. "'s turn.",
            playerColor,
            {1, 0.35, 0.35}
        )
        return
    end

    currentTurnIndex = (currentTurnIndex % #PLAYER_COLORS) + 1
    updateUi()
    announceTurn()
end

function TurnSystem.refreshUi()
    updateUi()
end

return TurnSystem

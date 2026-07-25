local ChatService = require("src/ChatService")
local Config = require("src/config/TurnConfig")

local TurnSystem = {}
local currentTurnIndex = 1

local function getCurrentColor()
    return Config.playerColors[currentTurnIndex]
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

    UI.setAttribute(
        Config.ui.playerNameId,
        "text",
        playerName .. "'s Turn"
    )
    UI.setAttribute(
        Config.ui.playerNameId,
        "color",
        Config.playerHexColors[currentColor]
    )
    UI.setAttribute(
        Config.ui.colorNameId,
        "text",
        currentColor .. " Player"
    )

    for _, playerColor in ipairs(Config.playerColors) do
        local buttonId = Config.ui.endTurnButtonPrefix .. playerColor
        local isCurrentPlayer = playerColor == currentColor

        UI.setAttribute(
            buttonId,
            "text",
            isCurrentPlayer
                and Config.ui.activeButtonText
                or Config.ui.waitingButtonText
        )
        UI.setAttribute(
            buttonId,
            "interactable",
            isCurrentPlayer and "true" or "false"
        )
    end
end

local function announceTurn()
    local currentColor = getCurrentColor()
    local playerName = getPlayerName(currentColor)

    ChatService.sayToAll(
        playerName .. " (" .. currentColor .. "), it is your turn!"
    )
end

function TurnSystem.onLoad(savedTurnState)
    if type(savedTurnState) == "table" then
        local savedIndex = tonumber(savedTurnState.currentTurnIndex)

        if savedIndex ~= nil
            and savedIndex >= 1
            and savedIndex <= #Config.playerColors
        then
            currentTurnIndex = math.floor(savedIndex)
        end
    end

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
            Config.invalidTurnColor
        )
        return
    end

    currentTurnIndex = (currentTurnIndex % #Config.playerColors) + 1
    updateUi()
    announceTurn()
end

function TurnSystem.refreshUi()
    updateUi()
end

return TurnSystem

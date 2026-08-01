local ChatService = require("src/ChatService")
local Config = require("src/config/TurnConfig")
local TurnState = require("src/turns/TurnState")

local TurnSystem = {}
local turnState = TurnState.new({})
local activeByColor = {}

local function getCurrentColor()
    return TurnState.getCurrentColor(turnState)
end

local function getPlayerName(playerColor)
    if playerColor == nil then
        return nil
    end

    local player = Player[playerColor]

    if player ~= nil and player.steam_name ~= nil and player.steam_name ~= "" then
        return player.steam_name
    end

    return playerColor
end

local function updateUi()
    local currentColor = getCurrentColor()
    local currentPhase = TurnState.getCurrentPhase(turnState)

    if currentColor == nil then
        UI.setAttribute(
            Config.ui.playerNameId,
            "text",
            Config.ui.noPlayersText
        )
        UI.setAttribute(
            Config.ui.playerNameId,
            "color",
            "#FFFFFF"
        )
        UI.setAttribute(
            Config.ui.colorNameId,
            "text",
            Config.ui.noPlayersDetailText
        )
    else
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
    end

    for _, phase in ipairs(TurnState.getPhases()) do
        local isCurrentPhase = phase == currentPhase

        UI.setAttribute(
            Config.ui.phaseIdPrefix .. phase,
            "text",
            (isCurrentPhase
                and Config.ui.activePhasePrefix
                or Config.ui.inactivePhasePrefix)
                .. Config.phaseLabels[phase]
        )
        UI.setAttribute(
            Config.ui.phaseIdPrefix .. phase,
            "color",
            isCurrentPhase
                and Config.ui.activePhaseColor
                or Config.ui.inactivePhaseColor
        )
    end

    for _, playerColor in ipairs(Config.playerColors) do
        local buttonId = Config.ui.phaseButtonPrefix .. playerColor
        local isCurrentPlayer = playerColor == currentColor
        local activeButtonText = currentPhase == "end"
            and Config.ui.endPhaseButtonText
            or Config.ui.activeButtonText

        UI.setAttribute(
            buttonId,
            "text",
            isCurrentPlayer and activeButtonText
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

    if currentColor == nil then
        return
    end

    local playerName = getPlayerName(currentColor)

    ChatService.sayToAll(
        playerName .. " (" .. currentColor .. "), it is your turn!"
    )
end

function TurnSystem.advancePhase(playerColor)
    local currentColor = getCurrentColor()

    if currentColor == nil then
        broadcastToColor(
            "No players have spawned a deck yet.",
            playerColor,
            Config.invalidTurnColor
        )
        return false
    end

    if playerColor ~= currentColor then
        broadcastToColor(
            "It is " .. getPlayerName(currentColor) .. "'s turn.",
            playerColor,
            Config.invalidTurnColor
        )
        return false
    end

    local previousColor = currentColor
    local advanced = TurnState.advancePhase(turnState, playerColor)
    updateUi()

    if advanced and getCurrentColor() ~= previousColor then
        announceTurn()
    end

    return advanced
end

local function getActivePlayerColors()
    local playerColors = {}

    for _, playerColor in ipairs(Config.playerColors) do
        if activeByColor[playerColor] == true then
            playerColors[#playerColors + 1] = playerColor
        end
    end

    return playerColors
end

local function restoreActivePlayers(savedTurnState)
    activeByColor = {}

    if type(savedTurnState) ~= "table"
        or type(savedTurnState.activePlayerColors) ~= "table"
    then
        return
    end

    for _, playerColor in ipairs(savedTurnState.activePlayerColors) do
        activeByColor[playerColor] = true
    end
end

function TurnSystem.onLoad(savedTurnState)
    restoreActivePlayers(savedTurnState)
    turnState = TurnState.new(
        getActivePlayerColors(),
        savedTurnState
    )

    Wait.frames(function()
        updateUi()
        announceTurn()
    end, 1)
end

function TurnSystem.getSaveState()
    local saveState = TurnState.getSaveState(turnState)
    saveState.activePlayerColors = getActivePlayerColors()
    return saveState
end

function TurnSystem.endTurn(playerColor)
    local currentColor = getCurrentColor()

    if currentColor == nil then
        broadcastToColor(
            "No players have spawned a deck yet.",
            playerColor,
            Config.invalidTurnColor
        )
        return false
    end

    if playerColor ~= currentColor then
        broadcastToColor(
            "It is " .. getPlayerName(currentColor) .. "'s turn.",
            playerColor,
            Config.invalidTurnColor
        )
        return false
    end

    TurnState.endTurn(turnState, playerColor)
    updateUi()
    announceTurn()
    return true
end

function TurnSystem.activatePlayer(playerColor)
    if activeByColor[playerColor] == true
        or Config.playerHexColors[playerColor] == nil
    then
        return false
    end

    local hadCurrentPlayer = getCurrentColor() ~= nil
    activeByColor[playerColor] = true
    TurnState.setPlayerColors(turnState, getActivePlayerColors())
    updateUi()

    if not hadCurrentPlayer then
        announceTurn()
    end

    return true
end

function TurnSystem.isPlayerActive(playerColor)
    return activeByColor[playerColor] == true
end

function TurnSystem.refreshUi()
    updateUi()
end

return TurnSystem

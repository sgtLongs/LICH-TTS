local ChatConfig = require("src/config/ChatConfig")
local Config = require("src/config/TurnConfig")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local UiAdapter = require("src/tts/UiAdapter")
local TurnState = require("src/turns/TurnState")
local TurnView = require("src/turns/TurnView")

local TurnController = {}

function TurnController.new(dependencies)
    dependencies = dependencies or {}

    local config = dependencies.config or Config
    local stateApi = dependencies.turnState or TurnState
    local view = dependencies.view or TurnView
    local uiAdapter = dependencies.uiAdapter or UiAdapter.default()
    local scheduler = dependencies.scheduler or Scheduler.default()
    local runtime = dependencies.runtime or Runtime.default()
    local getPlayer = dependencies.getPlayer or runtime.getPlayer
    local sendPrivate = dependencies.broadcastToColor
        or runtime.broadcastToColor
    local announce = dependencies.announce or function(message)
        runtime.printToAll(message, ChatConfig.defaultColor)
    end
    local turnState = stateApi.new({})
    local activeByColor = {}
    local controller = {}

    local function getCurrentColor()
        return stateApi.getCurrentColor(turnState)
    end

    local function getPlayerName(playerColor)
        if playerColor == nil then
            return nil
        end

        local player = getPlayer(playerColor)

        if player ~= nil
            and player.steam_name ~= nil
            and player.steam_name ~= ""
        then
            return player.steam_name
        end

        return playerColor
    end

    local function updateUi()
        local currentColor = getCurrentColor()
        local model = view.buildModel(
            currentColor,
            stateApi.getCurrentPhase(turnState),
            getPlayerName(currentColor)
        )
        model.phases = stateApi.getPhases()
        uiAdapter.apply(view.buildPatch(config, model))
    end

    local function announceTurn()
        local currentColor = getCurrentColor()

        if currentColor == nil then
            return
        end

        announce(
            getPlayerName(currentColor)
                .. " (" .. currentColor .. "), it is your turn!"
        )
    end

    local function getActivePlayerColors()
        local playerColors = {}

        for _, playerColor in ipairs(config.playerColors) do
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

    local function untapAllCards()
        for _, object in ipairs(runtime.getAllObjects()) do
            if object.tag == "Card" and type(object.call) == "function" then
                local succeeded, rotated = pcall(function()
                    return object.call("getActionZoneTapRotation")
                end)

                if succeeded and rotated == true then
                    pcall(function()
                        object.call("onCardTapped", object)
                    end)
                end
            end
        end
    end

    function controller.advancePhase(playerColor)
        local currentColor = getCurrentColor()

        if currentColor == nil then
            sendPrivate(
                "No players have spawned a deck yet.",
                playerColor,
                config.invalidTurnColor
            )
            return false
        end

        if playerColor ~= currentColor then
            sendPrivate(
                "It is " .. getPlayerName(currentColor) .. "'s turn.",
                playerColor,
                config.invalidTurnColor
            )
            return false
        end

        local previousColor = currentColor

        if stateApi.getCurrentPhase(turnState) == "start" then
            untapAllCards()
        end

        local advanced = stateApi.advancePhase(turnState, playerColor)
        updateUi()

        if advanced and getCurrentColor() ~= previousColor then
            announceTurn()
        end

        return advanced
    end

    function controller.onLoad(savedTurnState)
        restoreActivePlayers(savedTurnState)
        turnState = stateApi.new(
            getActivePlayerColors(),
            savedTurnState
        )

        scheduler.frames(function()
            updateUi()
            announceTurn()
        end, 1)
    end

    function controller.getSaveState()
        local saveState = stateApi.getSaveState(turnState)
        saveState.activePlayerColors = getActivePlayerColors()
        return saveState
    end

    function controller.endTurn(playerColor)
        local currentColor = getCurrentColor()

        if currentColor == nil then
            sendPrivate(
                "No players have spawned a deck yet.",
                playerColor,
                config.invalidTurnColor
            )
            return false
        end

        if playerColor ~= currentColor then
            sendPrivate(
                "It is " .. getPlayerName(currentColor) .. "'s turn.",
                playerColor,
                config.invalidTurnColor
            )
            return false
        end

        stateApi.endTurn(turnState, playerColor)
        updateUi()
        announceTurn()
        return true
    end

    function controller.activatePlayer(playerColor)
        if activeByColor[playerColor] == true
            or config.playerHexColors[playerColor] == nil
        then
            return false
        end

        local hadCurrentPlayer = getCurrentColor() ~= nil
        activeByColor[playerColor] = true
        stateApi.setPlayerColors(turnState, getActivePlayerColors())
        updateUi()

        if not hadCurrentPlayer then
            announceTurn()
        end

        return true
    end

    function controller.isPlayerActive(playerColor)
        return activeByColor[playerColor] == true
    end

    function controller.refreshUi()
        updateUi()
    end

    return controller
end

return TurnController

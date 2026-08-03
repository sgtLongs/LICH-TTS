local ChatConfig = require("src/config/ChatConfig")
local Config = require("src/config/TurnConfig")
local DrawPhase = require("src/turns/DrawPhase")
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
    local cardFields = dependencies.cardFields
    local sendPrivate = dependencies.broadcastToColor
        or runtime.broadcastToColor
    local announce = dependencies.announce or function(message)
        runtime.printToAll(message, ChatConfig.defaultColor)
    end
    local log = dependencies.log or runtime.log or function()
    end
    local turnState = stateApi.new({})
    local activeByColor = {}
    local drawGeneration = 0
    local isDrawing = false
    local controller = {}

    local function scheduleTime(callback, delay)
        if type(scheduler.time) == "function" then
            return scheduler.time(callback, delay)
        end

        return callback()
    end

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
        model.isDrawing = isDrawing
        uiAdapter.apply(view.buildPatch(config, model))
    end

    local function cancelDrawing()
        drawGeneration = drawGeneration + 1
        isDrawing = false
    end

    local function getHandCount(playerColor)
        local player = getPlayer(playerColor)

        if player == nil or type(player.getHandObjects) ~= "function" then
            return 0
        end

        local succeeded, objects = pcall(player.getHandObjects)
        return succeeded and type(objects) == "table" and #objects or 0
    end

    local function beginDrawing()
        local playerColor = getCurrentColor()

        if playerColor == nil
            or stateApi.getCurrentPhase(turnState) ~= "draw"
        then
            return
        end

        cancelDrawing()
        local generation = drawGeneration
        isDrawing = true
        updateUi()

        local drawInfo = cardFields ~= nil
            and type(cardFields.getPlayerDrawInfo) == "function"
            and cardFields.getPlayerDrawInfo(playerColor) or nil
        local remaining = DrawPhase.cardCount(
            drawInfo and drawInfo.intelligence or 0,
            getHandCount(playerColor)
        )

        local function isCurrentDraw()
            return generation == drawGeneration
                and getCurrentColor() == playerColor
                and stateApi.getCurrentPhase(turnState) == "draw"
        end

        local function complete()
            if not isCurrentDraw() then
                return
            end

            isDrawing = false
            stateApi.advancePhase(turnState, playerColor)
            updateUi()
        end

        local function drawNext()
            if not isCurrentDraw() then
                return
            end

            if remaining <= 0 then
                complete()
                return
            end

            local source = DrawPhase.findDrawSource(
                runtime.getAllObjects(),
                drawInfo and drawInfo.deckPosition or nil,
                config.drawPhase.deckSearchRadius
            )

            if source == nil then
                log(
                    "Draw phase: no deck found for " .. playerColor .. "."
                )
                complete()
                return
            end

            local succeeded, result = pcall(source.deal, 1, playerColor)

            if not succeeded or result == false then
                log(
                    "Draw phase: could not draw a card for "
                        .. playerColor .. "."
                )
                complete()
                return
            end

            remaining = remaining - 1

            if remaining <= 0 then
                scheduleTime(
                    complete,
                    config.drawPhase.cardIntervalSeconds
                )
            else
                scheduleTime(
                    drawNext,
                    config.drawPhase.cardIntervalSeconds
                )
            end
        end

        scheduleTime(drawNext, config.drawPhase.delaySeconds)
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

        if isDrawing then
            sendPrivate(
                "Cards are currently drawing.",
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

        if advanced and stateApi.getCurrentPhase(turnState) == "draw" then
            beginDrawing()
        end

        if advanced and getCurrentColor() ~= previousColor then
            announceTurn()
        end

        return advanced
    end

    function controller.onLoad(savedTurnState)
        cancelDrawing()
        restoreActivePlayers(savedTurnState)
        turnState = stateApi.new(
            getActivePlayerColors(),
            savedTurnState
        )

        scheduler.frames(function()
            updateUi()
            announceTurn()

            if stateApi.getCurrentPhase(turnState) == "draw" then
                beginDrawing()
            end
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

        cancelDrawing()
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

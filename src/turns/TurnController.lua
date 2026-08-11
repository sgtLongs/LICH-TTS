local ChatConfig = require("src/config/ChatConfig")
local Config = require("src/config/TurnConfig")
local MockPlayerFeature = require(
    "src/mock_players/MockPlayerFeature"
)
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
    local endPhase = dependencies.endPhase
    local sendPrivate = dependencies.broadcastToColor
        or runtime.broadcastToColor
    local announce = dependencies.announce or function(message)
        runtime.printToAll(message, ChatConfig.defaultColor)
    end
    local log = dependencies.log or runtime.log or function()
    end
    local turnState = stateApi.new({})
    local activeByColor = {}
    local untapGeneration = 0
    local isUntapping = false
    local drawGeneration = 0
    local isDrawing = false
    local isPlacingDeathFog = false
    local controller = {}
    local mockPlayers = dependencies.mockPlayers
        or MockPlayerFeature.new({
            turnConfig = config,
            config = dependencies.mockPlayerConfig,
            scheduler = scheduler,
            runtime = runtime,
            getPlayer = getPlayer
        })

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

        local mockName = mockPlayers:getName(playerColor)

        if mockName ~= nil then
            return mockName
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
        model.isUntapping = isUntapping
        model.isDrawing = isDrawing
        model.isPlacingDeathFog = isPlacingDeathFog
        uiAdapter.apply(view.buildPatch(config, model))
    end

    local function cancelDrawing()
        drawGeneration = drawGeneration + 1
        isDrawing = false
    end

    local function scheduleMockTurn()
        mockPlayers:schedule({
            getCurrentColor = getCurrentColor,
            isBlocked = function()
                return isUntapping or isDrawing or isPlacingDeathFog
            end,
            advance = function(playerColor)
                controller.advancePhase(playerColor)
            end
        })
    end

    local function cancelDeathFogPlacement()
        local playerColor = getCurrentColor()
        isPlacingDeathFog = false

        if endPhase ~= nil
            and type(endPhase.cancelDeathFogPlacement) == "function"
        then
            endPhase.cancelDeathFogPlacement(playerColor)
        end
    end

    local function beginDeathFogPlacement()
        local playerColor = getCurrentColor()
        local isMockPlayer = mockPlayers:isMock(playerColor)
        local beginPlacement = mockPlayers:getDeathFogStarter(
            endPhase,
            playerColor
        )

        if playerColor == nil
            or stateApi.getCurrentPhase(turnState) ~= "end"
            or type(beginPlacement) ~= "function"
        then
            isPlacingDeathFog = false
            return
        end

        isPlacingDeathFog = true
        local accepted = beginPlacement(
            playerColor,
            function(succeeded)
                if (succeeded == true or isMockPlayer)
                    and getCurrentColor() == playerColor
                    and stateApi.getCurrentPhase(turnState) == "end"
                then
                    isPlacingDeathFog = false
                    controller.endTurn(playerColor)
                end
            end
        )

        if accepted == false then
            isPlacingDeathFog = false
        end
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
            scheduleMockTurn()
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

    local function cancelUntapping()
        untapGeneration = untapGeneration + 1
        isUntapping = false
    end

    local function beginUntapping()
        local playerColor = getCurrentColor()

        if playerColor == nil
            or stateApi.getCurrentPhase(turnState) ~= "start"
        then
            isUntapping = false
            return
        end

        cancelUntapping()
        local generation = untapGeneration
        isUntapping = true
        updateUi()

        scheduler.frames(function()
            if generation ~= untapGeneration
                or getCurrentColor() ~= playerColor
                or stateApi.getCurrentPhase(turnState) ~= "start"
            then
                return
            end

            untapAllCards()

            if cardFields ~= nil
                and type(cardFields.renewActionPoints) == "function"
            then
                cardFields.renewActionPoints(playerColor)
            end

            stateApi.advancePhase(turnState, playerColor)
            isUntapping = false
            updateUi()
            scheduleMockTurn()
        end, 1)
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

        if isUntapping then
            sendPrivate(
                "Cards are currently untapping.",
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

        if isPlacingDeathFog then
            sendPrivate(
                "Place a death fog tile before ending the turn.",
                playerColor,
                config.invalidTurnColor
            )
            return false
        end

        local previousColor = currentColor

        local advanced = stateApi.advancePhase(turnState, playerColor)

        if advanced and stateApi.getCurrentPhase(turnState) == "end" then
            beginDeathFogPlacement()
        end

        updateUi()

        if advanced and stateApi.getCurrentPhase(turnState) == "draw" then
            beginDrawing()
        end

        if advanced and getCurrentColor() ~= previousColor then
            cancelDeathFogPlacement()
            announceTurn()
            beginUntapping()
        end

        scheduleMockTurn()

        return advanced
    end

    function controller.onLoad(savedTurnState)
        cancelUntapping()
        cancelDrawing()
        cancelDeathFogPlacement()
        restoreActivePlayers(savedTurnState)
        mockPlayers:load(savedTurnState, activeByColor)
        turnState = stateApi.new(
            getActivePlayerColors(),
            savedTurnState
        )

        scheduler.frames(function()
            if stateApi.getCurrentPhase(turnState) == "start" then
                beginUntapping()
            elseif stateApi.getCurrentPhase(turnState) == "draw" then
                beginDrawing()
            elseif stateApi.getCurrentPhase(turnState) == "end" then
                beginDeathFogPlacement()
            end

            updateUi()
            announceTurn()
            scheduleMockTurn()
        end, 1)
    end

    function controller.resetForRestart()
        controller.onLoad({})
        return true
    end

    function controller.getSaveState()
        local saveState = stateApi.getSaveState(turnState)
        saveState.activePlayerColors = getActivePlayerColors()
        saveState.mockPlayerColors = mockPlayers:getPlayerColors()
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

        if isUntapping then
            sendPrivate(
                "Cards are currently untapping.",
                playerColor,
                config.invalidTurnColor
            )
            return false
        end

        if isPlacingDeathFog then
            sendPrivate(
                "Place a death fog tile before ending the turn.",
                playerColor,
                config.invalidTurnColor
            )
            return false
        end

        cancelDrawing()
        cancelDeathFogPlacement()
        stateApi.endTurn(turnState, playerColor)
        updateUi()
        announceTurn()
        beginUntapping()
        scheduleMockTurn()
        return true
    end

    function controller.activatePlayer(playerColor, preserveMock)
        if config.playerHexColors[playerColor] == nil then
            return false
        end

        if activeByColor[playerColor] == true then
            if not mockPlayers:isMock(playerColor) then
                return false
            end

            if not mockPlayers:replaceWithReal(
                playerColor,
                preserveMock
            ) then
                return false
            end

            updateUi()
            scheduleMockTurn()
            return true
        end

        local hadCurrentPlayer = getCurrentColor() ~= nil
        activeByColor[playerColor] = true
        stateApi.setPlayerColors(turnState, getActivePlayerColors())
        updateUi()

        if not hadCurrentPlayer then
            announceTurn()
            beginUntapping()
        end

        scheduleMockTurn()

        return true
    end

    function controller.addMockPlayer()
        local added, playerColor = mockPlayers:add(activeByColor)

        if not added then
            return false, nil
        end

        local hadCurrentPlayer = getCurrentColor() ~= nil
        activeByColor[playerColor] = true
        stateApi.setPlayerColors(turnState, getActivePlayerColors())
        updateUi()

        if not hadCurrentPlayer then
            announceTurn()
            beginUntapping()
        end

        scheduleMockTurn()
        return true, playerColor
    end

    function controller.removeMockPlayer(playerColor)
        if not mockPlayers:remove(playerColor) then
            return false
        end

        activeByColor[playerColor] = nil
        stateApi.setPlayerColors(turnState, getActivePlayerColors())
        updateUi()
        scheduleMockTurn()
        return true
    end

    function controller.removeMostRecentMockPlayer()
        local playerColor = mockPlayers:getMostRecentPlayerColor()

        if playerColor == nil
            or not controller.removeMockPlayer(playerColor)
        then
            return false, nil
        end

        return true, playerColor
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

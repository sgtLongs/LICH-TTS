local Test = require("tests/support/Test")

local callbackNames = {
    "onLoad",
    "onSave",
    "getCardButtonConfig",
    "showCardPreview",
    "hideCardPreview",
    "onCardPreviewActionClicked",
    "onCardPreviewStackClicked",
    "getCardFieldDestination",
    "onObjectHover",
    "onObjectPickUp",
    "onObjectDrop",
    "onObjectRotate",
    "onObjectLeaveContainer",
    "onObjectEnterZone",
    "returnCardToHandThroughDeck",
    "onCardLeavesActionZone",
    "onActionStackUpClicked",
    "onActionStackDownClicked",
    "onActionZoneCardRotationChanged",
    "onEndTurnClicked",
    "onAdvancePhaseClicked",
    "onFirstPlayerUiClicked",
    "onPlayersUiClicked",
    "onActionPoint1Clicked",
    "onActionPoint2Clicked",
    "onActionPoint3Clicked",
    "onActionPoint4Clicked",
    "onHexGridClicked",
    "onCardFieldDeckSlotClicked",
    "onDeckSelectionUiClicked",
    "onHexGridObjectClicked",
    "onHexGridMenuUiClicked",
    "onSurfaceUiClicked",
    "onHexGridSpawnSelectorUiClicked",
    "onSettingsUiClicked",
    "onSettingsJsonEdited",
    "onSettingsBoardNameEdited",
    "onSettingsEditModeChanged",
    "onDungeonMapUiClicked",
    "onPlayerAction",
    "onScriptingButtonDown",
    "onObjectNumberTyped",
    "onObjectDestroy",
    "onPlayerConnect",
    "onPlayerDisconnect"
}

local gameMethods = {
    "onLoad",
    "onSave",
    "getCardButtonConfig",
    "showCardPreview",
    "hideCardPreview",
    "onCardPreviewActionClicked",
    "onCardPreviewStackClicked",
    "getCardFieldDestination",
    "refreshCardButtons",
    "onObjectHover",
    "onObjectPickUp",
    "onObjectDrop",
    "onObjectRotate",
    "onObjectLeaveContainer",
    "onObjectEnterZone",
    "returnCardToHandThroughDeck",
    "onCardLeavesActionZone",
    "onActionStackUpClicked",
    "onActionStackDownClicked",
    "onActionZoneCardRotationChanged",
    "onEndTurnClicked",
    "onAdvancePhaseClicked",
    "onFirstPlayerUiClicked",
    "onPlayersUiClicked",
    "onActionPoint1Clicked",
    "onActionPoint2Clicked",
    "onActionPoint3Clicked",
    "onActionPoint4Clicked",
    "onHexGridClicked",
    "onCardFieldDeckSlotClicked",
    "onDeckSelectionUiClicked",
    "onHexGridObjectClicked",
    "onHexGridMenuUiClicked",
    "onSurfaceUiClicked",
    "onHexGridSpawnSelectorUiClicked",
    "onSettingsUiClicked",
    "onSettingsJsonEdited",
    "onSettingsBoardNameEdited",
    "onSettingsEditModeChanged",
    "onDungeonMapUiClicked",
    "onPlayerAction",
    "onScriptingButtonDown",
    "onObjectNumberTyped",
    "onObjectDestroy",
    "onPlayerConnect",
    "onPlayerDisconnect"
}

local function withGlobalCallbacks(testFunction)
    local previousGame = package.loaded["src/Game"]
    local previousJson = JSON
    local previousWait = Wait
    local previousCallbacks = {}
    local calls = {}
    local callsByName = {}
    local encodedValue = nil
    local scheduled = nil
    local game = {}

    for _, callbackName in ipairs(callbackNames) do
        previousCallbacks[callbackName] = _G[callbackName]
    end

    for _, methodName in ipairs(gameMethods) do
        game[methodName] = function(...)
            local call = {name = methodName, arguments = {...}}
            calls[#calls + 1] = call
            callsByName[methodName] = call

            if methodName == "onSave" then
                return "saved-game"
            end

            if methodName == "getCardButtonConfig" then
                return {tap = {width = 1200}}
            end

            if methodName == "getCardFieldDestination" then
                return {x = 4, y = 5, z = 6}
            end

            return "result-" .. methodName
        end
    end

    package.loaded["src/Game"] = game
    JSON = {
        encode = function(value)
            encodedValue = value
            return "encoded-config"
        end
    }
    Wait = {
        time = function(callback, delay)
            scheduled = {callback = callback, delay = delay}
        end
    }

    local succeeded, failure = pcall(function()
        dofile(TEST_REPOSITORY_ROOT .. "/Global.lua")
        testFunction({
            calls = calls,
            callsByName = callsByName,
            encodedValue = function() return encodedValue end,
            game = game,
            scheduled = function() return scheduled end
        })
    end)

    package.loaded["src/Game"] = previousGame
    JSON = previousJson
    Wait = previousWait

    for _, callbackName in ipairs(callbackNames) do
        _G[callbackName] = previousCallbacks[callbackName]
    end

    if not succeeded then
        error(failure, 0)
    end
end

Test.case("global lifecycle delegates and schedules card refresh", function()
    withGlobalCallbacks(function(context)
        onLoad("serialized")

        Test.equal("serialized", context.callsByName.onLoad.arguments[1])
        Test.equal(0.5, context.scheduled().delay)
        Test.equal(context.game.refreshCardButtons, context.scheduled().callback)
        Test.equal("saved-game", onSave())
        Test.equal("encoded-config", getCardButtonConfig())
        Test.equal(1200, context.encodedValue().tap.width)
    end)
end)

Test.case("global object events preserve TTS argument order", function()
    withGlobalCallbacks(function(context)
        local object = {}
        local container = {}
        local zone = {}

        Test.equal(
            "result-onObjectPickUp",
            onObjectPickUp("Blue", object)
        )
        Test.equal("Blue", context.callsByName.onObjectPickUp.arguments[1])
        Test.equal(object, context.callsByName.onObjectPickUp.arguments[2])
        Test.equal("result-onObjectDrop", onObjectDrop("Red", object))
        Test.equal(
            "result-onObjectRotate",
            onObjectRotate(object, 90, 0, "Red", 0, 0)
        )
        Test.equal(object, context.callsByName.onObjectRotate.arguments[1])
        Test.equal(90, context.callsByName.onObjectRotate.arguments[2])

        onObjectHover("Teal", object)
        Test.equal("Teal", context.callsByName.onObjectHover.arguments[1])
        Test.equal(object, context.callsByName.onObjectHover.arguments[2])

        onObjectLeaveContainer(container, object)
        Test.equal(
            container,
            context.callsByName.onObjectLeaveContainer.arguments[1]
        )
        onObjectEnterZone(zone, object)
        Test.equal(zone, context.callsByName.onObjectEnterZone.arguments[1])
    end)
end)

Test.case("global card routes validate parameter tables", function()
    withGlobalCallbacks(function(context)
        Test.falsy(showCardPreview(nil))
        Test.falsy(hideCardPreview("card"))
        Test.nilValue(getCardFieldDestination(nil))
        Test.falsy(returnCardToHandThroughDeck(nil))
        Test.falsy(onCardLeavesActionZone("card"))
        Test.falsy(onActionZoneCardRotationChanged(false))
        Test.nilValue(context.callsByName.returnCardToHandThroughDeck)

        local card = {}
        local deck = {}
        Test.equal(
            "result-showCardPreview",
            showCardPreview({
                card = card,
                playerColor = "Red",
                imageUrl = "front.png"
            })
        )
        Test.equal(
            card,
            context.callsByName.showCardPreview.arguments[1]
        )
        Test.equal(
            "front.png",
            context.callsByName.showCardPreview.arguments[3]
        )
        Test.equal(
            "result-hideCardPreview",
            hideCardPreview({card = card, playerColor = "Red"})
        )
        Test.equal(
            "result-onCardPreviewActionClicked",
            onCardPreviewActionClicked({color = "Red"}, "destroy")
        )
        Test.equal(
            "Red",
            context.callsByName.onCardPreviewActionClicked.arguments[1]
        )
        Test.equal(
            "destroy",
            context.callsByName.onCardPreviewActionClicked.arguments[2]
        )
        Test.equal(
            "result-onCardPreviewStackClicked",
            onCardPreviewStackClicked({color = "Red"}, "down")
        )
        Test.equal(
            "Red",
            context.callsByName.onCardPreviewStackClicked.arguments[1]
        )
        Test.equal(
            "down",
            context.callsByName.onCardPreviewStackClicked.arguments[2]
        )
        local destination = getCardFieldDestination({
            fieldId = "field-a",
            destination = "abyss"
        })
        Test.equal(4, destination.x)
        Test.equal(
            "field-a",
            context.callsByName.getCardFieldDestination.arguments[1]
        )
        Test.equal(
            "abyss",
            context.callsByName.getCardFieldDestination.arguments[2]
        )
        Test.equal(
            "result-returnCardToHandThroughDeck",
            returnCardToHandThroughDeck({
                card = card,
                deck = deck,
                playerColor = "White"
            })
        )
        Test.equal(
            card,
            context.callsByName.returnCardToHandThroughDeck.arguments[1]
        )
        Test.equal(
            deck,
            context.callsByName.returnCardToHandThroughDeck.arguments[2]
        )
        Test.equal(
            "White",
            context.callsByName.returnCardToHandThroughDeck.arguments[3]
        )

        Test.equal(
            "result-onCardLeavesActionZone",
            onCardLeavesActionZone({card = card})
        )
        Test.equal(
            "result-onActionZoneCardRotationChanged",
            onActionZoneCardRotationChanged({card = card, rotated = true})
        )
        Test.truthy(
            context.callsByName.onActionZoneCardRotationChanged.arguments[2]
        )
    end)
end)

Test.case("global turn and action buttons unwrap player data", function()
    withGlobalCallbacks(function(context)
        local card = {}
        onEndTurnClicked({color = "Brown"}, nil, "end")
        onAdvancePhaseClicked({color = "Green"}, nil, "phase")
        onFirstPlayerUiClicked({color = "White"}, "chooseBlue", "first")
        onActionStackUpClicked(card, "Red", false)
        onActionStackDownClicked(card, "Red", false)
        onActionPoint3Clicked(card, "Red", false)

        Test.equal("Brown", context.callsByName.onEndTurnClicked.arguments[1])
        Test.equal(
            "Green",
            context.callsByName.onAdvancePhaseClicked.arguments[1]
        )
        Test.equal(
            "White",
            context.callsByName.onFirstPlayerUiClicked.arguments[1]
        )
        Test.equal(
            "chooseBlue",
            context.callsByName.onFirstPlayerUiClicked.arguments[2]
        )
        Test.equal(card, context.callsByName.onActionStackUpClicked.arguments[1])
        Test.equal(card, context.callsByName.onActionStackDownClicked.arguments[1])
        Test.equal(
            "Red",
            context.callsByName.onActionStackUpClicked.arguments[2]
        )
        Test.equal(
            "Red",
            context.callsByName.onActionStackDownClicked.arguments[2]
        )
        Test.equal(card, context.callsByName.onActionPoint3Clicked.arguments[1])
        Test.equal("Red", context.callsByName.onActionPoint3Clicked.arguments[2])
    end)
end)

Test.case("global menu callbacks unwrap player and action values", function()
    withGlobalCallbacks(function(context)
        local player = {color = "Teal"}

        onDeckSelectionUiClicked(player, "9636", "deck")
        onHexGridMenuUiClicked(player, "tree", "hex")
        Test.equal(
            "result-onSurfaceUiClicked",
            onSurfaceUiClicked(player, "deathFog", "surface")
        )
        Test.equal(
            "result-onHexGridSpawnSelectorUiClicked",
            onHexGridSpawnSelectorUiClicked(player, "4", "spawn")
        )
        onSettingsUiClicked(player, "save", "settings")
        onSettingsJsonEdited(player, "{}", "json")
        onSettingsBoardNameEdited(player, "Crypt", "name")
        onSettingsEditModeChanged(player, "True", "edit")
        onDungeonMapUiClicked(player, "tile1", "dungeon")
        Test.equal(
            "result-onPlayersUiClicked",
            onPlayersUiClicked(player, "removeRed", "players")
        )

        Test.equal("Teal", context.callsByName.onDeckSelectionUiClicked.arguments[1])
        Test.equal("9636", context.callsByName.onDeckSelectionUiClicked.arguments[2])
        Test.equal("tree", context.callsByName.onHexGridMenuUiClicked.arguments[2])
        Test.equal("deathFog", context.callsByName.onSurfaceUiClicked.arguments[2])
        Test.equal("4", context.callsByName.onHexGridSpawnSelectorUiClicked.arguments[2])
        Test.equal("save", context.callsByName.onSettingsUiClicked.arguments[2])
        Test.equal("{}", context.callsByName.onSettingsJsonEdited.arguments[2])
        Test.equal("Crypt", context.callsByName.onSettingsBoardNameEdited.arguments[2])
        Test.equal("True", context.callsByName.onSettingsEditModeChanged.arguments[2])
        Test.equal("tile1", context.callsByName.onDungeonMapUiClicked.arguments[2])
        Test.equal("Teal", context.callsByName.onPlayersUiClicked.arguments[1])
        Test.equal("removeRed", context.callsByName.onPlayersUiClicked.arguments[2])
    end)
end)

Test.case("global board callbacks preserve object and input arguments", function()
    withGlobalCallbacks(function(context)
        local board = {}
        local object = {}
        local targets = {object}
        local player = {color = "Red"}

        onHexGridClicked(board, "Red", true)
        onCardFieldDeckSlotClicked(board, "Red", false)
        onHexGridObjectClicked(object, "Red", false)
        Test.equal(
            "result-onPlayerAction",
            onPlayerAction(player, "Select", targets)
        )
        Test.equal(
            "result-onScriptingButtonDown",
            onScriptingButtonDown(7, "Red")
        )
        Test.equal(
            "result-onObjectNumberTyped",
            onObjectNumberTyped(object, "Red", 9, true)
        )

        Test.equal("Red", context.callsByName.onHexGridClicked.arguments[1])
        Test.truthy(context.callsByName.onHexGridClicked.arguments[2])
        Test.equal(board, context.callsByName.onCardFieldDeckSlotClicked.arguments[1])
        Test.equal(object, context.callsByName.onHexGridObjectClicked.arguments[1])
        Test.equal(player, context.callsByName.onPlayerAction.arguments[1])
        Test.equal(targets, context.callsByName.onPlayerAction.arguments[3])
        Test.equal(7, context.callsByName.onScriptingButtonDown.arguments[1])
        Test.equal(9, context.callsByName.onObjectNumberTyped.arguments[3])
        Test.truthy(context.callsByName.onObjectNumberTyped.arguments[4])
    end)
end)

Test.case("global destruction and player callbacks delegate", function()
    withGlobalCallbacks(function(context)
        local object = {}

        onObjectDestroy(object)
        local connectedPlayer = {color = "Blue", steam_name = "Bea"}
        onPlayerConnect(connectedPlayer)
        onPlayerDisconnect({color = "Red"})

        Test.equal(object, context.callsByName.onObjectDestroy.arguments[1])
        Test.truthy(context.callsByName.onPlayerConnect)
        Test.equal(
            connectedPlayer,
            context.callsByName.onPlayerConnect.arguments[1]
        )
        Test.equal(
            "Red",
            context.callsByName.onPlayerDisconnect.arguments[1]
        )
    end)
end)

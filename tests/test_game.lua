local Test = require("tests/support/Test")

local calls = {}
local encodedValue = nil
local decodedValue = nil

local CardFields = {
    getSaveState = function()
        return {area = "cards"}
    end,
    onLoad = function(savedState)
        calls.cardFieldsLoaded = true
        calls.cardFieldsState = savedState
    end,
    onDeckSlotClicked = function(object, playerColor)
        calls.deckSlotObject = object
        calls.deckSlotPlayerColor = playerColor
    end,
    onDeckMenuUiClicked = function(playerColor, action)
        calls.deckMenuPlayerColor = playerColor
        calls.deckMenuAction = action
    end,
    onObjectPickUp = function(object)
        calls.pickedUpCard = object
        return true
    end,
    onObjectDrop = function(object)
        calls.droppedCard = object
        return true
    end,
    onCardLeavesActionZone = function(object)
        calls.actionZoneLeavingCard = object
        return true
    end,
    onActionStackNavigationClicked = function(object, direction)
        calls.actionStackCard = object
        calls.actionStackDirection = direction
        return true
    end,
    onActionZoneCardRotationChanged = function(object, rotated)
        calls.actionStackRotatedCard = object
        calls.actionStackRotated = rotated
        return true
    end,
    renewDeckSlotButton = function()
        return true
    end
}
local DungeonMap = {
    getSaveState = function()
        return {area = "dungeon"}
    end,
    initialize = function(context, savedState)
        calls.dungeonContext = context
        calls.dungeonState = savedState
    end,
    handleAction = function()
    end,
    onSavedBoardsChanged = function()
    end,
    onExternalBoardLoadStarted = function()
    end,
    onExternalBoardLoadCompleted = function()
    end
}
local HexGrid = {
    getSaveState = function()
        return {area = "hex"}
    end,
    onLoad = function(savedState)
        calls.hexState = savedState
    end,
    getBoardState = function()
    end,
    getBoardStateJson = function()
    end,
    loadBoardState = function()
    end,
    loadBoardStateJson = function()
    end,
    setEditMode = function()
    end,
    onObjectHover = function()
    end,
    onClicked = function()
    end,
    onObjectClicked = function()
    end,
    onMenuUiClicked = function()
    end,
    onSpawnSelectorUiClicked = function(playerColor, action)
        calls.spawnSelectorPlayerColor = playerColor
        calls.spawnSelectorAction = action
        return true
    end,
    onPlayerAction = function()
    end,
    onScriptingButtonDown = function(index, playerColor)
        calls.scriptingButtonIndex = index
        calls.scriptingButtonPlayerColor = playerColor
        return true
    end,
    onObjectNumberTyped = function(object, playerColor, number, alt)
        calls.numberTypedObject = object
        calls.numberTypedPlayerColor = playerColor
        calls.numberTypedNumber = number
        calls.numberTypedAlt = alt
        return true
    end,
    onObjectDestroy = function()
    end
}
local SettingsMenu = {
    getSaveState = function()
        return {area = "settings"}
    end,
    initialize = function(context, savedState)
        calls.settingsContext = context
        calls.settingsState = savedState
    end,
    getSavedBoardSummaries = function()
    end,
    loadSavedBoardById = function()
    end,
    handleAction = function()
    end,
    onJsonEdited = function()
    end,
    onBoardNameEdited = function()
    end,
    onEditModeChanged = function(playerColor, value)
        calls.editModePlayerColor = playerColor
        calls.editModeValue = value
    end
}
local TurnSystem = {
    getSaveState = function()
        return {area = "turn"}
    end,
    onLoad = function(savedState)
        calls.turnState = savedState
    end,
    endTurn = function()
    end,
    advancePhase = function(playerColor)
        calls.phasePlayerColor = playerColor
        return true
    end,
    refreshUi = function()
    end
}

package.loaded["src/card_fields/CardFields"] = CardFields
package.loaded["src/dungeon/DungeonMap"] = DungeonMap
package.loaded["src/hex/HexGrid"] = HexGrid
package.loaded["src/SettingsMenu"] = SettingsMenu
package.loaded["src/turns/TurnSystem"] = TurnSystem

JSON = {
    encode = function(value)
        encodedValue = value
        return "encoded-state"
    end,
    decode = function(value)
        if value == "invalid" then
            error("invalid JSON")
        end

        return decodedValue
    end
}

Global = {script_state = ""}

function storeRewindState(callback, includeCurrentState)
    calls.rewindCallback = callback
    calls.includeCurrentState = includeCurrentState
end

local Game = require("src/Game")

Test.case("game save gathers state from each subsystem", function()
    local result = Game.onSave()

    Test.equal("encoded-state", result)
    Test.equal("cards", encodedValue.cardFields.area)
    Test.equal("dungeon", encodedValue.dungeonMap.area)
    Test.equal("hex", encodedValue.hexGrid.area)
    Test.equal("settings", encodedValue.settings.area)
    Test.equal("turn", encodedValue.turnSystem.area)
end)

Test.case("game load wires subsystems to saved state", function()
    decodedValue = {
        cardFields = {loaded = "cards"},
        dungeonMap = {loaded = "dungeon"},
        hexGrid = {loaded = "hex"},
        settings = {loaded = "settings"},
        turnSystem = {loaded = "turn"}
    }

    Game.onLoad("valid")

    Test.truthy(calls.cardFieldsLoaded)
    Test.equal("cards", calls.cardFieldsState.loaded)
    Test.equal("hex", calls.hexState.loaded)
    Test.equal("turn", calls.turnState.loaded)
    Test.equal("settings", calls.settingsState.loaded)
    Test.equal("dungeon", calls.dungeonState.loaded)
    Test.equal(
        HexGrid.loadBoardState,
        calls.settingsContext.loadBoardState
    )
    Test.equal(
        HexGrid.setEditMode,
        calls.settingsContext.setEditMode
    )
    Test.equal(
        CardFields.renewDeckSlotButton,
        calls.settingsContext.renewDeckSlotButton
    )
    Test.equal(
        SettingsMenu.loadSavedBoardById,
        calls.dungeonContext.loadSavedBoardById
    )
end)

Test.case("game routes edit mode UI changes", function()
    Game.onSettingsEditModeChanged("Red", "True")

    Test.equal("Red", calls.editModePlayerColor)
    Test.equal("True", calls.editModeValue)
end)

Test.case("game exposes card button runtime configuration", function()
    local config = Game.getCardButtonConfig()

    Test.truthy(config.tap)
    Test.truthy(config.destroy)
end)

Test.case("game routes phase advances", function()
    Test.truthy(Game.onAdvancePhaseClicked("Teal"))
    Test.equal("Teal", calls.phasePlayerColor)
end)

Test.case("game routes deck slot and deck menu choices", function()
    local object = {}

    Game.onCardFieldDeckSlotClicked(object, "Blue")
    Game.onDeckSelectionUiClicked("Blue", "9636")

    Test.equal(object, calls.deckSlotObject)
    Test.equal("Blue", calls.deckSlotPlayerColor)
    Test.equal("Blue", calls.deckMenuPlayerColor)
    Test.equal("9636", calls.deckMenuAction)
end)

Test.case("game routes card pickup and drop events", function()
    local card = {}

    Test.truthy(Game.onObjectPickUp("Blue", card))
    Test.equal(card, calls.pickedUpCard)
    Test.truthy(Game.onObjectDrop("Blue", card))
    Test.equal(card, calls.droppedCard)
end)

Test.case("game handles cards leaving decks and entering zones", function()
    local card = {tag = "Card"}

    Game.onObjectLeaveContainer({}, card)
    Game.onObjectEnterZone({tag = "Hand"}, card)
end)

Test.case("game rejects an invalid return-through-deck request", function()
    Test.falsy(Game.returnCardToHandThroughDeck(nil, nil, "Blue"))
end)

Test.case("game routes scripted cards leaving action zones", function()
    local card = {}

    Test.truthy(Game.onCardLeavesActionZone(card))
    Test.equal(card, calls.actionZoneLeavingCard)
end)

Test.case("game routes action stack navigation arrows", function()
    local card = {}

    Test.truthy(Game.onActionStackDownClicked(card))
    Test.equal(card, calls.actionStackCard)
    Test.equal(1, calls.actionStackDirection)
    Test.truthy(Game.onActionStackUpClicked(card))
    Test.equal(-1, calls.actionStackDirection)
end)

Test.case("game routes action stack card rotation changes", function()
    local card = {}

    Test.truthy(Game.onActionZoneCardRotationChanged(card, true))
    Test.equal(card, calls.actionStackRotatedCard)
    Test.truthy(calls.actionStackRotated)
end)

Test.case("game routes edit mode object number keys", function()
    local object = {}

    Test.truthy(Game.onScriptingButtonDown(4, "Red"))
    Test.truthy(Game.onObjectNumberTyped(object, "Red", 7, false))

    Test.equal(4, calls.scriptingButtonIndex)
    Test.equal("Red", calls.scriptingButtonPlayerColor)
    Test.equal(object, calls.numberTypedObject)
    Test.equal("Red", calls.numberTypedPlayerColor)
    Test.equal(7, calls.numberTypedNumber)
    Test.falsy(calls.numberTypedAlt)
end)

Test.case("game routes spawn palette choices", function()
    Test.truthy(Game.onHexGridSpawnSelectorUiClicked("Red", "9"))

    Test.equal("Red", calls.spawnSelectorPlayerColor)
    Test.equal("9", calls.spawnSelectorAction)
end)

Test.case("game load tolerates invalid JSON", function()
    Game.onLoad("invalid")

    Test.nilValue(calls.hexState)
    Test.nilValue(calls.turnState)
    Test.nilValue(calls.settingsState)
    Test.nilValue(calls.dungeonState)
end)

Test.case("game persistence updates TTS script state", function()
    local persisted = Game.persistState()

    Test.truthy(persisted)
    Test.equal("encoded-state", Global.script_state)
    Test.falsy(calls.includeCurrentState)
end)

local Test = require("tests/support/Test")

local calls = {}
local encodedValue = nil
local decodedValue = nil

local ChatService = {
    sayButtonClicked = function()
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
    onObjectHover = function()
    end,
    onClicked = function()
    end,
    onObjectClicked = function()
    end,
    onMenuUiClicked = function()
    end,
    onPlayerAction = function()
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
    refreshUi = function()
    end
}

package.loaded["src/ChatService"] = ChatService
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
    Test.equal("dungeon", encodedValue.dungeonMap.area)
    Test.equal("hex", encodedValue.hexGrid.area)
    Test.equal("settings", encodedValue.settings.area)
    Test.equal("turn", encodedValue.turnSystem.area)
end)

Test.case("game load wires subsystems to saved state", function()
    decodedValue = {
        dungeonMap = {loaded = "dungeon"},
        hexGrid = {loaded = "hex"},
        settings = {loaded = "settings"},
        turnSystem = {loaded = "turn"}
    }

    Game.onLoad("valid")

    Test.equal("hex", calls.hexState.loaded)
    Test.equal("turn", calls.turnState.loaded)
    Test.equal("settings", calls.settingsState.loaded)
    Test.equal("dungeon", calls.dungeonState.loaded)
    Test.equal(
        HexGrid.loadBoardState,
        calls.settingsContext.loadBoardState
    )
    Test.equal(
        SettingsMenu.loadSavedBoardById,
        calls.dungeonContext.loadSavedBoardById
    )
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

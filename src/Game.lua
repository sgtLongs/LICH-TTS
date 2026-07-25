local ChatService = require("src/ChatService")
local HexGrid = require("src/hex/HexGrid")
local SettingsMenu = require("src/SettingsMenu")
local TurnSystem = require("src/turns/TurnSystem")

local Game = {}

local function getSaveState()
    return {
        hexGrid = HexGrid.getSaveState(),
        settings = SettingsMenu.getSaveState(),
        turnSystem = TurnSystem.getSaveState()
    }
end

local function encodeSaveState()
    return JSON.encode(getSaveState())
end

function Game.persistState()
    local encodedState = encodeSaveState()
    local stateUpdated, updateError = pcall(function()
        Global.script_state = encodedState

        if Global.script_state ~= encodedState then
            error("Global script state did not retain the saved data.")
        end
    end)

    if not stateUpdated then
        print(
            "Could not immediately update Global script state: "
                .. tostring(updateError)
        )
    end

    pcall(function()
        storeRewindState(function()
        end, false)
    end)

    return stateUpdated
end

function Game.onLoad(saveState)
    local savedGame = {}

    if saveState ~= nil and saveState ~= "" then
        local success, decodedState = pcall(JSON.decode, saveState)

        if success and type(decodedState) == "table" then
            savedGame = decodedState
        end
    end

    HexGrid.onLoad(savedGame.hexGrid)
    TurnSystem.onLoad(savedGame.turnSystem)
    SettingsMenu.initialize({
        getBoardState = HexGrid.getBoardState,
        getBoardStateJson = HexGrid.getBoardStateJson,
        loadBoardState = HexGrid.loadBoardState,
        loadBoardStateJson = HexGrid.loadBoardStateJson,
        persistState = Game.persistState
    }, savedGame.settings)
end

function Game.onSave()
    return encodeSaveState()
end

function Game.onObjectHover()
    HexGrid.onObjectHover()
end

function Game.onSpeakerButtonClicked(data)
    ChatService.sayButtonClicked(data.playerColor, data.objectName)
end

function Game.onEndTurnClicked(playerColor)
    TurnSystem.endTurn(playerColor)
end

function Game.onHexGridClicked(playerColor, altClick)
    HexGrid.onClicked(playerColor, altClick)
end

function Game.onHexGridMenuUiClicked(playerColor, action)
    HexGrid.onMenuUiClicked(playerColor, action)
end

function Game.onSettingsUiClicked(playerColor, action)
    SettingsMenu.handleAction(playerColor, action)
end

function Game.onSettingsJsonEdited(playerColor, value)
    SettingsMenu.onJsonEdited(playerColor, value)
end

function Game.onSettingsBoardNameEdited(playerColor, value)
    SettingsMenu.onBoardNameEdited(playerColor, value)
end

function Game.onPlayerAction(player, action, targets)
    return HexGrid.onPlayerAction(player, action, targets)
end

function Game.onObjectDestroy(object)
    HexGrid.onObjectDestroy(object)
end

function Game.onPlayerConnect()
    TurnSystem.refreshUi()
end

return Game

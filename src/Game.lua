local CardFields = require("src/card_fields/CardFields")
local CardLogic = require("src/cards/CardLogic")
local DungeonMap = require("src/dungeon/DungeonMap")
local HexGrid = require("src/hex/HexGrid")
local SettingsMenu = require("src/SettingsMenu")
local TurnSystem = require("src/turns/TurnSystem")

local Game = {}

local function getSaveState()
    return {
        cardFields = CardFields.getSaveState(),
        dungeonMap = DungeonMap.getSaveState(),
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

    TurnSystem.onLoad(savedGame.turnSystem)
    CardFields.onLoad(savedGame.cardFields)
    HexGrid.onLoad(savedGame.hexGrid)
    SettingsMenu.initialize({
        getBoardState = HexGrid.getBoardState,
        getBoardStateJson = HexGrid.getBoardStateJson,
        loadBoardState = HexGrid.loadBoardState,
        loadBoardStateJson = HexGrid.loadBoardStateJson,
        onBoardLoadStarted = DungeonMap.onExternalBoardLoadStarted,
        onBoardLoadCompleted = DungeonMap.onExternalBoardLoadCompleted,
        onSavedBoardsChanged = DungeonMap.onSavedBoardsChanged,
        setEditMode = HexGrid.setEditMode,
        renewDeckSlotButton = CardFields.renewDeckSlotButton,
        persistState = Game.persistState
    }, savedGame.settings)
    DungeonMap.initialize({
        getSavedBoardSummaries = SettingsMenu.getSavedBoardSummaries,
        loadSavedBoardById = SettingsMenu.loadSavedBoardById,
        persistState = Game.persistState
    }, savedGame.dungeonMap)
end

function Game.onSave()
    return encodeSaveState()
end

function Game.onObjectHover()
    HexGrid.onObjectHover()
end

function Game.onEndTurnClicked(playerColor)
    TurnSystem.endTurn(playerColor)
end

function Game.getCardButtonConfig()
    return CardLogic.getButtonConfig()
end

function Game.refreshCardButtons()
    CardLogic.refreshExistingButtons()
end

function Game.onAdvancePhaseClicked(playerColor)
    return TurnSystem.advancePhase(playerColor)
end

function Game.onHexGridClicked(playerColor, altClick)
    HexGrid.onClicked(playerColor, altClick)
end

function Game.onCardFieldDeckSlotClicked(object, playerColor)
    CardFields.onDeckSlotClicked(object, playerColor)
end

function Game.onDeckSelectionUiClicked(playerColor, action)
    CardFields.onDeckMenuUiClicked(playerColor, action)
end

function Game.onHexGridObjectClicked(object, playerColor, altClick)
    HexGrid.onObjectClicked(object, playerColor, altClick)
end

function Game.onHexGridMenuUiClicked(playerColor, action)
    HexGrid.onMenuUiClicked(playerColor, action)
end

function Game.onHexGridSpawnSelectorUiClicked(playerColor, action)
    return HexGrid.onSpawnSelectorUiClicked(playerColor, action)
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

function Game.onSettingsEditModeChanged(playerColor, value)
    SettingsMenu.onEditModeChanged(playerColor, value)
end

function Game.onDungeonMapUiClicked(playerColor, action)
    DungeonMap.handleAction(playerColor, action)
end

function Game.onPlayerAction(player, action, targets)
    return HexGrid.onPlayerAction(player, action, targets)
end

function Game.onScriptingButtonDown(index, playerColor)
    return HexGrid.onScriptingButtonDown(index, playerColor)
end

function Game.onObjectNumberTyped(object, playerColor, number, alt)
    return HexGrid.onObjectNumberTyped(
        object,
        playerColor,
        number,
        alt
    )
end

function Game.onObjectDestroy(object)
    HexGrid.onObjectDestroy(object)
end

function Game.onPlayerConnect()
    TurnSystem.refreshUi()
end

return Game

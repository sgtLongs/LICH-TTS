local CardFields = require("src/card_fields/CardFields")
local CardLogic = require("src/cards/CardLogic")
local BoardLoadCoordinator = require("src/boards/BoardLoadCoordinator")
local SavedBoardCatalog = require("src/boards/SavedBoardCatalog")
local SettingsConfig = require("src/config/SettingsConfig")
local DungeonMap = require("src/dungeon/DungeonMap")
local GameController = require("src/GameController")
local HexGrid = require("src/hex/HexGrid")
local SettingsMenu = require("src/SettingsMenu")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local TurnSystem = require("src/turns/TurnSystem")

if type(CardFields.configureDefaultDependencies) == "function" then
    CardFields.configureDefaultDependencies({
        onDeckSpawned = function(ownerColor)
            return TurnSystem.activatePlayer(ownerColor)
        end
    })
end

local savedBoardCatalog = SavedBoardCatalog.new({
    schemaVersion = SettingsConfig.settingsSchemaVersion,
    legacySchemaVersion = SettingsConfig.legacySettingsSchemaVersion,
    decodeJson = function(value)
        return JSON.decode(value)
    end
})
local boardLoadCoordinator = BoardLoadCoordinator.new({
    schedule = function(callback, frameCount)
        return Scheduler.default().frames(callback, frameCount)
    end
})

local controller = GameController.new({
    cardFields = CardFields,
    cardLogic = CardLogic,
    dungeonMap = DungeonMap,
    hexGrid = HexGrid,
    settingsMenu = SettingsMenu,
    turnSystem = TurnSystem,
    runtime = Runtime.default(),
    savedBoardCatalog = savedBoardCatalog,
    boardLoadCoordinator = boardLoadCoordinator
})

local Game = {
    new = GameController.new
}

local publicMethods = {
    "persistState",
    "onLoad",
    "onSave",
    "onObjectHover",
    "onEndTurnClicked",
    "getCardButtonConfig",
    "getCardFieldDestination",
    "refreshCardButtons",
    "onAdvancePhaseClicked",
    "onHexGridClicked",
    "onCardFieldDeckSlotClicked",
    "onDeckSelectionUiClicked",
    "onObjectPickUp",
    "onObjectDrop",
    "onObjectLeaveContainer",
    "onObjectEnterZone",
    "returnCardToHandThroughDeck",
    "onCardLeavesActionZone",
    "onActionStackUpClicked",
    "onActionStackDownClicked",
    "onActionZoneCardRotationChanged",
    "onHexGridObjectClicked",
    "onHexGridMenuUiClicked",
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
    "onPlayerConnect"
}

for _, methodName in ipairs(publicMethods) do
    local name = methodName
    Game[name] = function(...)
        return controller[name](controller, ...)
    end
end

return Game

local DungeonMapController = require(
    "src/dungeon/DungeonMapController"
)

local DungeonMap = {}
local defaultController = DungeonMapController.new()

function DungeonMap.new(dependencies)
    return DungeonMapController.new(dependencies)
end

function DungeonMap.initialize(parameters, savedState)
    return defaultController.initialize(parameters, savedState)
end

function DungeonMap.getSaveState()
    return defaultController.getSaveState()
end

function DungeonMap.handleAction(playerColor, action)
    return defaultController.handleAction(playerColor, action)
end

function DungeonMap.onSavedBoardsChanged()
    return defaultController.onSavedBoardsChanged()
end

function DungeonMap.onExternalBoardLoadStarted(boardSaveId)
    return defaultController.onExternalBoardLoadStarted(boardSaveId)
end

function DungeonMap.onExternalBoardLoadCompleted(
    loadGeneration,
    boardSaveId,
    succeeded
)
    return defaultController.onExternalBoardLoadCompleted(
        loadGeneration,
        boardSaveId,
        succeeded
    )
end

return DungeonMap

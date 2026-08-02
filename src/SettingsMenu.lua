local SettingsMenuController = require(
    "src/settings/SettingsMenuController"
)

local SettingsMenu = {}
local defaultController = SettingsMenuController.new()

function SettingsMenu.new(dependencies)
    return SettingsMenuController.new(dependencies)
end

function SettingsMenu.initialize(parameters, savedState)
    return defaultController.initialize(parameters, savedState)
end

function SettingsMenu.getSaveState()
    return defaultController.getSaveState()
end

function SettingsMenu.getSavedBoardSummaries()
    return defaultController.getSavedBoardSummaries()
end

function SettingsMenu.loadSavedBoardById(
    boardId,
    playerColor,
    onCompleted
)
    return defaultController.loadSavedBoardById(
        boardId,
        playerColor,
        onCompleted
    )
end

function SettingsMenu.handleAction(playerColor, action)
    return defaultController.handleAction(playerColor, action)
end

function SettingsMenu.onJsonEdited(playerColor, value)
    return defaultController.onJsonEdited(playerColor, value)
end

function SettingsMenu.onBoardNameEdited(playerColor, value)
    return defaultController.onBoardNameEdited(playerColor, value)
end

function SettingsMenu.onEditModeChanged(playerColor, value)
    return defaultController.onEditModeChanged(playerColor, value)
end

return SettingsMenu

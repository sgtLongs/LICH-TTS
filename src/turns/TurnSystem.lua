local TurnController = require("src/turns/TurnController")

local TurnSystem = {}
local defaultController = TurnController.new()

function TurnSystem.new(dependencies)
    return TurnController.new(dependencies)
end

function TurnSystem.configureDefaultDependencies(dependencies)
    defaultController = TurnController.new(dependencies)
    return defaultController
end

function TurnSystem.advancePhase(playerColor)
    return defaultController.advancePhase(playerColor)
end

function TurnSystem.onLoad(savedTurnState)
    return defaultController.onLoad(savedTurnState)
end

function TurnSystem.resetForRestart()
    return defaultController.resetForRestart()
end

function TurnSystem.getSaveState()
    return defaultController.getSaveState()
end

function TurnSystem.endTurn(playerColor)
    return defaultController.endTurn(playerColor)
end

function TurnSystem.activatePlayer(playerColor, preserveMock)
    return defaultController.activatePlayer(playerColor, preserveMock)
end

function TurnSystem.addMockPlayer()
    return defaultController.addMockPlayer()
end

function TurnSystem.removePlayer(playerColor)
    return defaultController.removePlayer(playerColor)
end

function TurnSystem.removeMockPlayer(playerColor)
    return defaultController.removeMockPlayer(playerColor)
end

function TurnSystem.removeMostRecentMockPlayer()
    return defaultController.removeMostRecentMockPlayer()
end

function TurnSystem.isPlayerActive(playerColor)
    return defaultController.isPlayerActive(playerColor)
end

function TurnSystem.refreshUi()
    return defaultController.refreshUi()
end

return TurnSystem

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

function TurnSystem.getSaveState()
    return defaultController.getSaveState()
end

function TurnSystem.endTurn(playerColor)
    return defaultController.endTurn(playerColor)
end

function TurnSystem.activatePlayer(playerColor)
    return defaultController.activatePlayer(playerColor)
end

function TurnSystem.isPlayerActive(playerColor)
    return defaultController.isPlayerActive(playerColor)
end

function TurnSystem.refreshUi()
    return defaultController.refreshUi()
end

return TurnSystem

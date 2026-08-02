local HexGridMenuController = require(
    "src/hex/HexGridMenuController"
)

local HexGridMenu = {}
local defaultController = HexGridMenuController.new()

function HexGridMenu.new(dependencies)
    return HexGridMenuController.new(dependencies)
end

function HexGridMenu.initialize(parameters)
    return defaultController.initialize(parameters)
end

function HexGridMenu.showSpawnSelector(selectedTemplate)
    return defaultController.showSpawnSelector(selectedTemplate)
end

function HexGridMenu.hideSpawnSelector()
    return defaultController.hideSpawnSelector()
end

function HexGridMenu.open(playerColor, player, cell, placement)
    return defaultController.open(
        playerColor,
        player,
        cell,
        placement
    )
end

function HexGridMenu.handleAction(playerColor, action)
    return defaultController.handleAction(playerColor, action)
end

function HexGridMenu.close()
    return defaultController.close()
end

return HexGridMenu

local HexGridController = require("src/hex/HexGridController")

local HexGrid = {}
local defaultController = HexGridController.new()

function HexGrid.new(dependencies)
    return HexGridController.new(dependencies)
end

function HexGrid.onLoad(savedState)
    return defaultController.onLoad(savedState)
end

function HexGrid.onObjectHover()
    return defaultController.onObjectHover()
end

function HexGrid.getSaveState()
    return defaultController.getSaveState()
end

function HexGrid.getBoardState()
    return defaultController.getBoardState()
end

function HexGrid.getBoardStateJson()
    return defaultController.getBoardStateJson()
end

function HexGrid.loadBoardState(boardState, playerColor, onCompleted)
    return defaultController.loadBoardState(
        boardState,
        playerColor,
        onCompleted
    )
end

function HexGrid.loadBoardStateJson(
    boardStateJson,
    playerColor,
    onCompleted
)
    return defaultController.loadBoardStateJson(
        boardStateJson,
        playerColor,
        onCompleted
    )
end

function HexGrid.onObjectDestroy(object)
    return defaultController.onObjectDestroy(object)
end

function HexGrid.onClicked(playerColor, altClick)
    return defaultController.onClicked(playerColor, altClick)
end

function HexGrid.onObjectClicked(object, playerColor, altClick)
    return defaultController.onObjectClicked(
        object,
        playerColor,
        altClick
    )
end

function HexGrid.onPlayerAction(player, action, targets)
    return defaultController.onPlayerAction(player, action, targets)
end

function HexGrid.onMenuUiClicked(playerColor, action)
    return defaultController.onMenuUiClicked(playerColor, action)
end

function HexGrid.onSurfaceUiClicked(playerColor, action)
    return defaultController.onSurfaceUiClicked(playerColor, action)
end

function HexGrid.onSpawnSelectorUiClicked(playerColor, action)
    return defaultController.onSpawnSelectorUiClicked(
        playerColor,
        action
    )
end

function HexGrid.onScriptingButtonDown(index, playerColor)
    return defaultController.onScriptingButtonDown(index, playerColor)
end

function HexGrid.onObjectNumberTyped(object, playerColor, number)
    return defaultController.onObjectNumberTyped(
        object,
        playerColor,
        number
    )
end

function HexGrid.setEditMode(enabled, playerColor)
    return defaultController.setEditMode(enabled, playerColor)
end

function HexGrid.beginDeathFogPlacement(playerColor, onCompleted)
    return defaultController.beginDeathFogPlacement(
        playerColor,
        onCompleted
    )
end

function HexGrid.cancelDeathFogPlacement(playerColor)
    return defaultController.cancelDeathFogPlacement(playerColor)
end

return HexGrid

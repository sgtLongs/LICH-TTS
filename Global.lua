local Game = require("src/Game")

function onLoad(saveState)
    Game.onLoad(saveState)
end

function onSave()
    return Game.onSave()
end

function onObjectHover(playerColor, object)
    Game.onObjectHover(playerColor, object)
end

function onEndTurnClicked(player, value, id)
    Game.onEndTurnClicked(player.color)
end

function onAdvancePhaseClicked(player, value, id)
    Game.onAdvancePhaseClicked(player.color)
end

function onHexGridClicked(object, playerColor, altClick)
    Game.onHexGridClicked(playerColor, altClick)
end

function onCardFieldDeckSlotClicked(object, playerColor, altClick)
    Game.onCardFieldDeckSlotClicked(object, playerColor)
end

function onDeckSelectionUiClicked(player, action, id)
    Game.onDeckSelectionUiClicked(player.color, action)
end

function onHexGridObjectClicked(object, playerColor, altClick)
    Game.onHexGridObjectClicked(object, playerColor, altClick)
end

function onHexGridMenuUiClicked(player, action, id)
    Game.onHexGridMenuUiClicked(player.color, action)
end

function onHexGridSpawnSelectorUiClicked(player, action, id)
    return Game.onHexGridSpawnSelectorUiClicked(player.color, action)
end

function onSettingsUiClicked(player, action, id)
    Game.onSettingsUiClicked(player.color, action)
end

function onSettingsJsonEdited(player, value, id)
    Game.onSettingsJsonEdited(player.color, value)
end

function onSettingsBoardNameEdited(player, value, id)
    Game.onSettingsBoardNameEdited(player.color, value)
end

function onSettingsEditModeChanged(player, value, id)
    Game.onSettingsEditModeChanged(player.color, value)
end

function onDungeonMapUiClicked(player, action, id)
    Game.onDungeonMapUiClicked(player.color, action)
end

function onPlayerAction(player, action, targets)
    return Game.onPlayerAction(player, action, targets)
end

function onScriptingButtonDown(index, playerColor)
    return Game.onScriptingButtonDown(index, playerColor)
end

function onObjectNumberTyped(object, playerColor, number, alt)
    return Game.onObjectNumberTyped(object, playerColor, number, alt)
end

function onObjectDestroy(object)
    Game.onObjectDestroy(object)
end

function onPlayerConnect(player)
    Game.onPlayerConnect()
end

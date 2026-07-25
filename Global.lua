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

function onSpeakerButtonClicked(data)
    Game.onSpeakerButtonClicked(data)
end

function onEndTurnClicked(player, value, id)
    Game.onEndTurnClicked(player.color)
end

function onHexGridClicked(object, playerColor, altClick)
    Game.onHexGridClicked(playerColor, altClick)
end

function onHexGridMenuUiClicked(player, action, id)
    Game.onHexGridMenuUiClicked(player.color, action)
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

function onPlayerAction(player, action, targets)
    return Game.onPlayerAction(player, action, targets)
end

function onObjectDestroy(object)
    Game.onObjectDestroy(object)
end

function onPlayerConnect(player)
    Game.onPlayerConnect()
end

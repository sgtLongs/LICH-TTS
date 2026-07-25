local Game = require("src/Game")

function onLoad(saveState)
    Game.onLoad(saveState)
end

function onSave()
    return Game.onSave()
end

function onSpeakerButtonClicked(data)
    Game.onSpeakerButtonClicked(data)
end

function onEndTurnClicked(player, value, id)
    Game.onEndTurnClicked(player.color)
end

function onHexGridClicked(object, playerColor, altClick)
    Game.onHexGridClicked(playerColor)
end

function onPlayerConnect(player)
    Game.onPlayerConnect()
end

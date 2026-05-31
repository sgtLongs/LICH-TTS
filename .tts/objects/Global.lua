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
local ChatService = require("src/ChatService")

local Game = {}

function Game.onLoad(saveState)
    printToAll("Game loaded", {0, 1, 0})
end

function Game.onSave()
    return ""
end

function Game.onSpeakerButtonClicked(data)
    ChatService.sayButtonClicked(data.playerColor, data.objectName)
end

return Game
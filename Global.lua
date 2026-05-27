local ChatService = require("src/ChatService")

function onSpeakerButtonClicked(data)
    ChatService.sayButtonClicked(data.playerColor, data.objectName)
end
local Config = require("src/config/ChatConfig")

local ChatService = {}

function ChatService.sayToAll(message)
    printToAll(message, Config.defaultColor)
end

function ChatService.sayButtonClicked(playerColor, objectName)
    if objectName == nil or objectName == "" then
        objectName = "an object"
    end

    ChatService.sayToAll(playerColor .. " clicked " .. objectName)
end

return ChatService

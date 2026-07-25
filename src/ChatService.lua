local Config = require("src/config/ChatConfig")

local ChatService = {}

function ChatService.sayToAll(message)
    printToAll(message, Config.defaultColor)
end

return ChatService

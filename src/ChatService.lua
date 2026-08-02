local Config = require("src/config/ChatConfig")
local Runtime = require("src/tts/Runtime")

local ChatService = {}

function ChatService.sayToAll(message)
    return Runtime.default().printToAll(message, Config.defaultColor)
end

return ChatService

local ChatService = {}

function ChatService.sayToAll(message)
    printToAll(message, {1, 1, 1})
end

function ChatService.sayButtonClicked(playerColor, objectName)
    if objectName == nil or objectName == "" then
        objectName = "an object"
    end

    ChatService.sayToAll(playerColor .. " clicked " .. objectName)
end

return ChatService
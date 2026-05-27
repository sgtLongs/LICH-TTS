--[[ Lua code. See documentation: http://berserk-games.com/knowledgebase/scripting/ --]]

--[[ The OnLoad function. This is called after everything in the game save finishes loading.
Most of your script code goes here. --]]

local ChatService = require("src/ChatService")

function onSpeakerButtonClicked(data)
    ChatService.sayButtonClicked(data.playerColor, data.objectName)
end

function onload()
    --[[ print('Onload!') --]]
end

--[[ The Update function. This is called once per frame. --]]
function update ()
    --[[ print('Update loop!') --]]
end


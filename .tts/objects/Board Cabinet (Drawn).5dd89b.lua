local SpeakerButton = require("object_logic/SpeakerButton")

function onLoad()
    SpeakerButton.onLoad(self)
end

function handleSpeakButtonClicked(obj, playerColor, altClick)
    SpeakerButton.handleSpeakButtonClicked(self, obj, playerColor, altClick)
end
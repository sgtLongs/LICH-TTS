local SpeakerButton = require("objects/SpeakerButton")

function onLoad()
    SpeakerButton.onLoad(self)
end

function handleSpeakButtonClicked(obj, playerColor, altClick)
    SpeakerButton.handleSpeakButtonClicked(self, obj, playerColor, altClick)
end
local ButtonFactory = require("src/ButtonFactory")

local SpeakerButton = {}

function SpeakerButton.onLoad(ttsObject)
    ButtonFactory.createTextButton(
        ttsObject,
        "Speak",
        "handleSpeakButtonClicked",
        {0, 0.3, 0}
    )
end

function SpeakerButton.handleSpeakButtonClicked(ttsObject, obj, playerColor, altClick)
    Global.call("onSpeakerButtonClicked", {
        playerColor = playerColor,
        objectGuid = ttsObject.getGUID(),
        objectName = ttsObject.getName()
    })
end

return SpeakerButton
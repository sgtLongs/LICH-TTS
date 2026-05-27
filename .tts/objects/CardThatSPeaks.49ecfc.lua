function onLoad()
    self.clearButtons()

    self.createButton({
        label = "Speak",
        click_function = "handleSpeakButtonClicked",
        function_owner = self,

        position = {0, 0.3, 0},
        width = 900,
        height = 400,
        font_size = 180
    })
end

function handleSpeakButtonClicked(obj, playerColor, altClick)
    printToAll("Object handler fired", {1, 1, 0})

    Global.call("onSpeakerButtonClicked", {
        playerColor = playerColor,
        objectGuid = self.getGUID(),
        objectName = self.getName()
    })
end
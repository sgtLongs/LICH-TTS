local Test = require("tests/support/Test")

local uiUpdates = {}
local announcements = {}
local privateMessages = {}

Player = {
    White = {steam_name = "Wendy"},
    Brown = {},
    Red = {},
    Green = {},
    Teal = {},
    Blue = {steam_name = "Ben"}
}

UI = {
    setAttribute = function(id, attribute, value)
        uiUpdates[id .. ":" .. attribute] = value
    end
}

Wait = {
    frames = function(callback)
        callback()
    end
}

function printToAll(message, color)
    announcements[#announcements + 1] = {
        message = message,
        color = color
    }
end

function broadcastToColor(message, playerColor, color)
    privateMessages[#privateMessages + 1] = {
        message = message,
        playerColor = playerColor,
        color = color
    }
end

local TurnSystem = require("src/turns/TurnSystem")

Test.case("turn system restores state and updates the TTS boundary", function()
    TurnSystem.onLoad({currentTurnIndex = 6})

    Test.equal(6, TurnSystem.getSaveState().currentTurnIndex)
    Test.equal("Ben's Turn", uiUpdates["turnPlayerName:text"])
    Test.equal("true", uiUpdates["endTurnBlue:interactable"])
    Test.equal("Ben (Blue), it is your turn!", announcements[1].message)
end)

Test.case("turn system advances a valid turn", function()
    TurnSystem.endTurn("Blue")

    Test.equal(1, TurnSystem.getSaveState().currentTurnIndex)
    Test.equal("Wendy's Turn", uiUpdates["turnPlayerName:text"])
end)

Test.case("turn system reports an invalid turn without advancing", function()
    TurnSystem.endTurn("Red")

    Test.equal(1, TurnSystem.getSaveState().currentTurnIndex)
    Test.equal("Red", privateMessages[1].playerColor)
    Test.contains(privateMessages[1].message, "Wendy")
end)

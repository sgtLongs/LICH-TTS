local ChatService = require("src/ChatService")
local HexGrid = require("src/hex/HexGrid")
local TurnSystem = require("src/turns/TurnSystem")

local Game = {}

function Game.onLoad(saveState)
    local savedGame = {}

    if saveState ~= nil and saveState ~= "" then
        local success, decodedState = pcall(JSON.decode, saveState)

        if success and type(decodedState) == "table" then
            savedGame = decodedState
        end
    end

    HexGrid.onLoad(savedGame.hexGrid)
    TurnSystem.onLoad(savedGame.turnSystem)
end

function Game.onSave()
    return JSON.encode({
        hexGrid = HexGrid.getSaveState(),
        turnSystem = TurnSystem.getSaveState()
    })
end

function Game.onObjectHover()
    HexGrid.onObjectHover()
end

function Game.onSpeakerButtonClicked(data)
    ChatService.sayButtonClicked(data.playerColor, data.objectName)
end

function Game.onEndTurnClicked(playerColor)
    TurnSystem.endTurn(playerColor)
end

function Game.onHexGridClicked(playerColor, altClick)
    HexGrid.onClicked(playerColor, altClick)
end

function Game.onHexGridMenuUiClicked(playerColor, action)
    HexGrid.onMenuUiClicked(playerColor, action)
end

function Game.onPlayerAction(player, action, targets)
    return HexGrid.onPlayerAction(player, action, targets)
end

function Game.onPlayerConnect()
    TurnSystem.refreshUi()
end

return Game

local Test = require("tests/support/Test")
local Config = require("src/config/TurnConfig")
local TurnView = require("src/turns/TurnView")

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
    TurnSystem.onLoad({
        currentTurnIndex = 6,
        activePlayerColors = Config.playerColors
    })

    Test.equal(6, TurnSystem.getSaveState().currentTurnIndex)
    Test.equal("Ben's Turn", uiUpdates["turnPlayerName:text"])
    Test.equal("true", uiUpdates["advancePhaseBlue:interactable"])
    Test.equal("UNTAP ALL", uiUpdates["advancePhaseBlue:text"])
    Test.equal("> START PHASE", uiUpdates["turnPhasestart:text"])
    Test.equal("Ben (Blue), it is your turn!", announcements[1].message)
end)

Test.case("turn system advances phases and ends after end phase", function()
    TurnSystem.onLoad({
        currentTurnColor = "White",
        activePlayerColors = {"White", "Blue"}
    })

    Test.truthy(TurnSystem.advancePhase("White"))
    Test.equal("main", TurnSystem.getSaveState().currentPhase)
    Test.equal("> MAIN PHASE", uiUpdates["turnPhasemain:text"])
    Test.equal("NEXT PHASE", uiUpdates["advancePhaseWhite:text"])

    Test.truthy(TurnSystem.advancePhase("White"))
    Test.truthy(TurnSystem.advancePhase("White"))
    Test.equal("end", TurnSystem.getSaveState().currentPhase)
    Test.equal("END TURN", uiUpdates["advancePhaseWhite:text"])

    Test.truthy(TurnSystem.advancePhase("White"))
    Test.equal("Blue", TurnSystem.getSaveState().currentTurnColor)
    Test.equal("start", TurnSystem.getSaveState().currentPhase)
end)

Test.case("draw phase fills the hand one card at a configured interval", function()
    local FakeWait = require("tests/support/FakeWait")
    local wait = FakeWait.new()
    local draws = {}
    local hand = {{}, {}}
    local deck = {
        tag = "Deck",
        getPosition = function()
            return {x = 10, y = 2, z = 20}
        end,
        deal = function(count, color)
            draws[#draws + 1] = {
                count = count,
                color = color,
                time = wait.currentTime
            }
            return true
        end
    }
    local controller = TurnSystem.new({
        cardFields = {
            getPlayerDrawInfo = function(color)
                Test.equal("White", color)
                return {
                    intelligence = 5,
                    deckPosition = {x = 10, y = 2, z = 20}
                }
            end
        },
        runtime = {
            getAllObjects = function()
                return {deck}
            end,
            getPlayer = function()
                return {
                    steam_name = "Wendy",
                    getHandObjects = function()
                        return hand
                    end
                }
            end,
            log = function() end
        },
        scheduler = wait,
        uiAdapter = {apply = function(patches)
            for _, patch in ipairs(patches) do
                uiUpdates[patch.id .. ":" .. patch.attribute] = patch.value
            end
        end},
        announce = function() end,
        broadcastToColor = function() end
    })

    controller.onLoad({activePlayerColors = {"White"}})
    wait.advanceFrames(1)
    Test.truthy(controller.advancePhase("White"))
    Test.truthy(controller.advancePhase("White"))
    Test.equal("draw", controller.getSaveState().currentPhase)
    Test.equal("> DRAWING", uiUpdates["turnPhasedraw:text"])
    Test.equal("DRAWING...", uiUpdates["advancePhaseWhite:text"])
    Test.equal("false", uiUpdates["advancePhaseWhite:interactable"])
    Test.falsy(controller.advancePhase("White"))

    wait.advanceTime(Config.drawPhase.delaySeconds)
    Test.equal(1, #draws)
    Test.equal("draw", controller.getSaveState().currentPhase)
    wait.advanceTime(Config.drawPhase.cardIntervalSeconds)
    Test.equal(2, #draws)
    wait.advanceTime(Config.drawPhase.cardIntervalSeconds)

    Test.equal(3, #draws)
    Test.equal(1, draws[1].count)
    Test.equal("White", draws[1].color)
    Test.near(
        Config.drawPhase.cardIntervalSeconds,
        draws[2].time - draws[1].time,
        0.0001
    )
    Test.equal("draw", controller.getSaveState().currentPhase)
    wait.advanceTime(Config.drawPhase.cardIntervalSeconds)
    Test.equal("status", controller.getSaveState().currentPhase)
    Test.equal("> STATUS PHASE", uiUpdates["turnPhasestatus:text"])
end)

Test.case("draw phase draws no cards when the hand meets intelligence", function()
    local FakeWait = require("tests/support/FakeWait")
    local wait = FakeWait.new()
    local controller = TurnSystem.new({
        cardFields = {
            getPlayerDrawInfo = function()
                return {intelligence = 2, deckPosition = {x = 0, z = 0}}
            end
        },
        runtime = {
            getAllObjects = function()
                return {}
            end,
            getPlayer = function()
                return {getHandObjects = function() return {{}, {}, {}} end}
            end,
            log = function() end
        },
        scheduler = wait,
        uiAdapter = {apply = function() end},
        announce = function() end,
        broadcastToColor = function() end
    })

    controller.onLoad({activePlayerColors = {"White"}})
    wait.advanceFrames(1)
    controller.advancePhase("White")
    controller.advancePhase("White")
    Test.equal("draw", controller.getSaveState().currentPhase)
    wait.advanceTime(Config.drawPhase.delaySeconds)
    Test.equal("status", controller.getSaveState().currentPhase)
end)

Test.case("draw phase skips to status when its deck is unavailable", function()
    local FakeWait = require("tests/support/FakeWait")
    local wait = FakeWait.new()
    local messages = {}
    local controller = TurnSystem.new({
        cardFields = {
            getPlayerDrawInfo = function()
                return {intelligence = 3, deckPosition = {x = 0, z = 0}}
            end
        },
        runtime = {
            getAllObjects = function() return {} end,
            getPlayer = function()
                return {getHandObjects = function() return {} end}
            end,
            log = function(message) messages[#messages + 1] = message end
        },
        scheduler = wait,
        uiAdapter = {apply = function() end},
        announce = function() end,
        broadcastToColor = function() end
    })

    controller.onLoad({activePlayerColors = {"White"}})
    wait.advanceFrames(1)
    controller.advancePhase("White")
    controller.advancePhase("White")
    wait.advanceTime(Config.drawPhase.delaySeconds)

    Test.equal("status", controller.getSaveState().currentPhase)
    Test.contains(messages[1], "no deck found")
end)

Test.case("ending a turn cancels a stale draw callback", function()
    local FakeWait = require("tests/support/FakeWait")
    local wait = FakeWait.new()
    local drawCount = 0
    local controller = TurnSystem.new({
        cardFields = {
            getPlayerDrawInfo = function()
                return {intelligence = 1, deckPosition = {x = 0, z = 0}}
            end
        },
        runtime = {
            getAllObjects = function()
                return {{
                    tag = "Card",
                    getPosition = function() return {x = 0, z = 0} end,
                    deal = function() drawCount = drawCount + 1 end
                }}
            end,
            getPlayer = function()
                return {getHandObjects = function() return {} end}
            end,
            log = function() end
        },
        scheduler = wait,
        uiAdapter = {apply = function() end},
        announce = function() end,
        broadcastToColor = function() end
    })

    controller.onLoad({activePlayerColors = {"White", "Blue"}})
    wait.advanceFrames(1)
    controller.advancePhase("White")
    controller.advancePhase("White")
    Test.truthy(controller.endTurn("White"))
    wait.advanceTime(Config.drawPhase.delaySeconds)

    Test.equal(0, drawCount)
    Test.equal("Blue", controller.getSaveState().currentTurnColor)
    Test.equal("start", controller.getSaveState().currentPhase)
end)

Test.case("turn system rejects a phase change from another player", function()
    TurnSystem.onLoad({
        currentTurnColor = "White",
        activePlayerColors = {"White", "Blue"}
    })

    Test.falsy(TurnSystem.advancePhase("Blue"))
    Test.equal("start", TurnSystem.getSaveState().currentPhase)
    Test.equal("Blue", privateMessages[#privateMessages].playerColor)
end)

Test.case("start phase untaps every tapped card before advancing", function()
    local events = {}
    local tappedCard = {tag = "Card"}
    local untappedCard = {tag = "Card"}
    local deck = {tag = "Deck"}

    tappedCard.call = function(functionName, parameters)
        events[#events + 1] = "tapped:" .. functionName

        if functionName == "getActionZoneTapRotation" then
            return true
        end

        Test.equal(tappedCard, parameters)
    end
    untappedCard.call = function(functionName)
        events[#events + 1] = "untapped:" .. functionName
        return false
    end
    deck.call = function()
        error("decks must not be untapped")
    end

    local controller = TurnSystem.new({
        runtime = {
            getAllObjects = function()
                return {tappedCard, untappedCard, deck}
            end,
            getPlayer = function(color)
                return {steam_name = color}
            end
        },
        scheduler = {frames = function(callback) callback() end},
        uiAdapter = {apply = function() end},
        announce = function() end,
        broadcastToColor = function() end
    })

    controller.onLoad({activePlayerColors = {"White"}})
    Test.truthy(controller.advancePhase("White"))
    Test.equal("main", controller.getSaveState().currentPhase)
    Test.deepEqual({
        "tapped:getActionZoneTapRotation",
        "tapped:onCardTapped",
        "untapped:getActionZoneTapRotation"
    }, events)

    events = {}
    Test.truthy(controller.advancePhase("White"))
    Test.deepEqual({}, events)
end)

Test.case("turn system advances a valid turn", function()
    TurnSystem.endTurn("Blue")

    Test.equal(1, TurnSystem.getSaveState().currentTurnIndex)
    Test.equal("Wendy's Turn", uiUpdates["turnPlayerName:text"])
end)

Test.case("turn system reports an invalid turn without advancing", function()
    TurnSystem.endTurn("Red")

    Test.equal(1, TurnSystem.getSaveState().currentTurnIndex)
    Test.equal("Red", privateMessages[#privateMessages].playerColor)
    Test.contains(privateMessages[#privateMessages].message, "Wendy")
end)

Test.case("turn system includes only players with spawned decks", function()
    local announcementCount = #announcements

    TurnSystem.onLoad(nil)

    Test.equal(0, #TurnSystem.getSaveState().activePlayerColors)
    Test.equal(
        Config.ui.noPlayersText,
        uiUpdates["turnPlayerName:text"]
    )
    Test.equal(
        "false",
        uiUpdates["advancePhaseWhite:interactable"]
    )
    Test.equal(announcementCount, #announcements)
    Test.falsy(TurnSystem.endTurn("White"))
    Test.contains(
        privateMessages[#privateMessages].message,
        "No players"
    )

    Test.truthy(TurnSystem.activatePlayer("Red"))
    Test.falsy(TurnSystem.activatePlayer("Red"))
    Test.truthy(TurnSystem.activatePlayer("Blue"))
    Test.equal("Red", TurnSystem.getSaveState().currentTurnColor)
    Test.equal(
        "true",
        uiUpdates["advancePhaseRed:interactable"]
    )

    Test.truthy(TurnSystem.endTurn("Red"))
    Test.equal("Blue", TurnSystem.getSaveState().currentTurnColor)
    Test.equal(2, #TurnSystem.getSaveState().activePlayerColors)
end)

Test.case("turn view builds a deterministic UI patch", function()
    local model = TurnView.buildModel("Red", "end", "Rhea")
    model.phases = {"start", "end"}

    local patches = TurnView.buildPatch(Config, model)

    Test.deepEqual({
        {
            id = "turnPlayerName",
            attribute = "text",
            value = "Rhea's Turn"
        },
        {
            id = "turnPlayerName",
            attribute = "color",
            value = Config.playerHexColors.Red
        },
        {
            id = "turnColorName",
            attribute = "text",
            value = "Red Player"
        },
        {
            id = "turnPhasestart",
            attribute = "text",
            value = "  START PHASE"
        },
        {
            id = "turnPhasestart",
            attribute = "color",
            value = Config.ui.inactivePhaseColor
        },
        {
            id = "turnPhaseend",
            attribute = "text",
            value = "> END PHASE"
        },
        {
            id = "turnPhaseend",
            attribute = "color",
            value = Config.ui.activePhaseColor
        }
    }, {
        patches[1],
        patches[2],
        patches[3],
        patches[4],
        patches[5],
        patches[6],
        patches[7]
    })
    Test.equal(19, #patches)
    Test.deepEqual({
        id = "advancePhaseRed",
        attribute = "text",
        value = "END TURN"
    }, patches[12])
    Test.deepEqual({
        id = "advancePhaseRed",
        attribute = "interactable",
        value = "true"
    }, patches[13])
end)

Test.case("constructed turn controllers own isolated state", function()
    local announcements = {}
    local privateMessages = {}
    local appliedPatches = {}
    local scheduled = nil
    local dependencies = {
        getPlayer = function(color)
            return {steam_name = "Player " .. color}
        end,
        announce = function(message)
            announcements[#announcements + 1] = message
        end,
        broadcastToColor = function(message, color)
            privateMessages[#privateMessages + 1] = {message, color}
        end,
        scheduler = {
            frames = function(callback, frames)
                scheduled = {callback = callback, frames = frames}
            end
        },
        uiAdapter = {
            apply = function(patches)
                appliedPatches[#appliedPatches + 1] = patches
            end
        }
    }
    local first = TurnSystem.new(dependencies)
    local second = TurnSystem.new(dependencies)

    first.onLoad({activePlayerColors = {"Red"}})
    Test.equal(1, scheduled.frames)
    scheduled.callback()

    Test.truthy(first.isPlayerActive("Red"))
    Test.falsy(second.isPlayerActive("Red"))
    Test.falsy(first.advancePhase("Blue"))
    Test.equal("Blue", privateMessages[1][2])
    Test.contains(privateMessages[1][1], "Player Red")
    Test.equal("Player Red (Red), it is your turn!", announcements[1])
    Test.truthy(#appliedPatches > 0)
end)

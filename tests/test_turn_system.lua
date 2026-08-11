local Test = require("tests/support/Test")
local Config = require("src/config/TurnConfig")
local MockPlayerConfig = require(
    "src/mock_players/MockPlayerConfig"
)
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
    Test.equal("NEXT PHASE", uiUpdates["advancePhaseBlue:text"])
    Test.equal("> MAIN PHASE", uiUpdates["turnPhasemain:text"])
    Test.equal("Ben (Blue), it is your turn!", announcements[1].message)
end)

Test.case("restart clears all active players and turn progress", function()
    TurnSystem.onLoad({
        currentTurnColor = "Blue",
        currentPhase = "status",
        activePlayerColors = {"White", "Blue"}
    })

    Test.truthy(TurnSystem.resetForRestart())
    local state = TurnSystem.getSaveState()
    Test.equal(0, #state.activePlayerColors)
    Test.equal(0, #state.mockPlayerColors)
    Test.nilValue(state.currentTurnColor)
    Test.equal("start", state.currentPhase)
end)

Test.case("mock players automatically click through their turns", function()
    local FakeWait = require("tests/support/FakeWait")
    local Scheduler = require("src/tts/Scheduler")
    local wait = FakeWait.new()
    local announced = {}
    local randomFogPlacements = {}
    local controller = TurnSystem.new({
        runtime = {
            getPlayer = function(color)
                return {steam_name = color, seated = color == "Red"}
            end,
            getAllObjects = function()
                return {}
            end
        },
        scheduler = Scheduler.new(wait),
        endPhase = {
            beginRandomDeathFogPlacement = function(color, onCompleted)
                randomFogPlacements[#randomFogPlacements + 1] = color
                onCompleted(true)
                return true
            end,
            cancelDeathFogPlacement = function()
                return true
            end
        },
        uiAdapter = {apply = function()
        end},
        announce = function(message)
            announced[#announced + 1] = message
        end,
        broadcastToColor = function()
        end
    })

    controller.onLoad({
        currentTurnColor = "Red",
        activePlayerColors = {"Red"}
    })
    wait.advanceFrames(2)

    local added, mockColor = controller.addMockPlayer()
    Test.truthy(added)
    Test.equal("White", mockColor)
    Test.deepEqual({"White"}, controller.getSaveState().mockPlayerColors)

    Test.truthy(controller.endTurn("Red"))
    Test.equal("White", controller.getSaveState().currentTurnColor)
    Test.contains(announced[#announced], "Mock White")
    Test.equal("start", controller.getSaveState().currentPhase)

    wait.advanceFrames(1)
    Test.equal("main", controller.getSaveState().currentPhase)

    wait.advanceTime(MockPlayerConfig.phaseDelaySeconds)
    Test.equal("status", controller.getSaveState().currentPhase)

    wait.advanceTime(MockPlayerConfig.phaseDelaySeconds)
    Test.deepEqual({"White"}, randomFogPlacements)
    Test.equal("Red", controller.getSaveState().currentTurnColor)
    Test.equal("start", controller.getSaveState().currentPhase)
end)

Test.case("a real deck activation replaces a mock player", function()
    local controller = TurnSystem.new({
        getPlayer = function()
            return {seated = false}
        end,
        scheduler = {frames = function(callback)
            callback()
        end},
        uiAdapter = {apply = function()
        end},
        announce = function()
        end,
        broadcastToColor = function()
        end
    })

    controller.onLoad({})
    local added, mockColor = controller.addMockPlayer()
    Test.truthy(added)
    Test.falsy(controller.activatePlayer(mockColor, true))
    Test.equal(1, #controller.getSaveState().mockPlayerColors)
    Test.truthy(controller.activatePlayer(mockColor))
    Test.equal(0, #controller.getSaveState().mockPlayerColors)
    Test.truthy(controller.isPlayerActive(mockColor))
end)

Test.case("turn system removes the most recently added mock player", function()
    local controller = TurnSystem.new({
        getPlayer = function()
            return {seated = false}
        end,
        scheduler = {frames = function(callback)
            callback()
        end},
        uiAdapter = {apply = function()
        end},
        announce = function()
        end,
        broadcastToColor = function()
        end
    })

    controller.onLoad({})
    local _, firstColor = controller.addMockPlayer()
    local _, secondColor = controller.addMockPlayer()

    local removed, removedColor = controller.removeMostRecentMockPlayer()
    Test.truthy(removed)
    Test.equal(secondColor, removedColor)
    Test.truthy(controller.isPlayerActive(firstColor))
    Test.falsy(controller.isPlayerActive(secondColor))
    Test.deepEqual({firstColor}, controller.getSaveState().mockPlayerColors)

    controller.removeMostRecentMockPlayer()
    removed, removedColor = controller.removeMostRecentMockPlayer()
    Test.falsy(removed)
    Test.nilValue(removedColor)
end)

Test.case("turn system removes disconnected players from turn order", function()
    local FakeWait = require("tests/support/FakeWait")
    local wait = FakeWait.new()
    local controller = TurnSystem.new({
        scheduler = wait,
        uiAdapter = {apply = function()
        end},
        announce = function()
        end,
        broadcastToColor = function()
        end
    })

    controller.onLoad({
        currentTurnColor = "White",
        activePlayerColors = {"White", "Blue"}
    })

    Test.truthy(controller.removePlayer("White"))
    Test.falsy(controller.isPlayerActive("White"))
    Test.deepEqual({"Blue"}, controller.getSaveState().activePlayerColors)
    Test.equal("Blue", controller.getSaveState().currentTurnColor)
    Test.falsy(controller.removePlayer("White"))

    wait.advanceFrames(1)
    Test.equal("main", controller.getSaveState().currentPhase)
    Test.truthy(controller.advancePhase("Blue"))
end)

Test.case("turn system advances phases and ends after end phase", function()
    TurnSystem.onLoad({
        currentTurnColor = "White",
        currentPhase = "main",
        activePlayerColors = {"White", "Blue"}
    })

    Test.truthy(TurnSystem.advancePhase("White"))
    Test.equal("status", TurnSystem.getSaveState().currentPhase)
    Test.equal("> STATUS PHASE", uiUpdates["turnPhasestatus:text"])
    Test.equal("NEXT PHASE", uiUpdates["advancePhaseWhite:text"])

    Test.truthy(TurnSystem.advancePhase("White"))
    Test.equal("end", TurnSystem.getSaveState().currentPhase)
    Test.equal("END TURN", uiUpdates["advancePhaseWhite:text"])

    Test.truthy(TurnSystem.advancePhase("White"))
    Test.equal("Blue", TurnSystem.getSaveState().currentTurnColor)
    Test.equal("main", TurnSystem.getSaveState().currentPhase)
end)

Test.case("end phase requires a completed death fog placement", function()
    local completion = nil
    local privateMessage = nil
    local controller = TurnSystem.new({
        endPhase = {
            beginDeathFogPlacement = function(color, onCompleted)
                Test.equal("White", color)
                completion = onCompleted
                return true
            end,
            cancelDeathFogPlacement = function()
                return true
            end
        },
        getPlayer = function(color)
            return {steam_name = color}
        end,
        broadcastToColor = function(message)
            privateMessage = message
        end,
        announce = function()
        end,
        scheduler = {
            frames = function(callback)
                callback()
            end
        },
        uiAdapter = {apply = function()
        end}
    })

    controller.onLoad({
        currentTurnColor = "White",
        currentPhase = "status",
        activePlayerColors = {"White", "Blue"}
    })

    Test.truthy(controller.advancePhase("White"))
    Test.equal("end", controller.getSaveState().currentPhase)
    Test.truthy(type(completion) == "function")
    Test.falsy(controller.advancePhase("White"))
    Test.contains(privateMessage, "death fog")

    completion(true)
    Test.equal("Blue", controller.getSaveState().currentTurnColor)
    Test.equal("main", controller.getSaveState().currentPhase)

    completion(true)
    Test.equal("Blue", controller.getSaveState().currentTurnColor)
end)

Test.case("turn view disables the end button during fog placement", function()
    local model = TurnView.buildModel("Red", "end", "Rhea")
    model.phases = {"end"}
    model.isPlacingDeathFog = true
    local patches = TurnView.buildPatch(Config, model)

    Test.deepEqual({
        id = "advancePhaseRed",
        attribute = "text",
        value = Config.ui.deathFogButtonText
    }, patches[10])
    Test.deepEqual({
        id = "advancePhaseRed",
        attribute = "interactable",
        value = "false"
    }, patches[11])
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
    wait.advanceFrames(2)
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
    wait.advanceFrames(2)
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
    wait.advanceFrames(2)
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
    wait.advanceFrames(2)
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
    Test.equal("main", TurnSystem.getSaveState().currentPhase)
    Test.equal("Blue", privateMessages[#privateMessages].playerColor)
end)

Test.case("start phase untaps only the current player's field", function()
    local FakeWait = require("tests/support/FakeWait")
    local wait = FakeWait.new()
    local events = {}
    local renewedColor = nil
    local privateMessage = nil
    local applied = {}
    local tappedCard = {tag = "Card"}
    local otherPlayerCard = {tag = "Card"}
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
    otherPlayerCard.call = function(functionName)
        events[#events + 1] = "other:" .. functionName
        return true
    end
    deck.call = function()
        error("decks must not be untapped")
    end

    local controller = TurnSystem.new({
        cardFields = {
            isCardOnPlayerField = function(color, card)
                Test.equal("White", color)
                return card == tappedCard or card == untappedCard
            end,
            renewActionPoints = function(color)
                renewedColor = color
            end
        },
        runtime = {
            getAllObjects = function()
                return {
                    tappedCard,
                    otherPlayerCard,
                    untappedCard,
                    deck
                }
            end,
            getPlayer = function(color)
                return {steam_name = color}
            end
        },
        scheduler = wait,
        uiAdapter = {apply = function(patches)
            for _, patch in ipairs(patches) do
                applied[patch.id .. ":" .. patch.attribute] = patch.value
            end
        end},
        announce = function() end,
        broadcastToColor = function(message)
            privateMessage = message
        end
    })

    controller.onLoad({activePlayerColors = {"White"}})
    wait.advanceFrames(1)
    Test.equal("start", controller.getSaveState().currentPhase)
    Test.equal("UNTAPPING...", applied["advancePhaseWhite:text"])
    Test.equal("false", applied["advancePhaseWhite:interactable"])
    Test.falsy(controller.advancePhase("White"))
    Test.contains(privateMessage, "untapping")
    Test.deepEqual({}, events)

    wait.advanceFrames(1)
    Test.equal("main", controller.getSaveState().currentPhase)
    Test.equal("NEXT PHASE", applied["advancePhaseWhite:text"])
    Test.equal("true", applied["advancePhaseWhite:interactable"])
    Test.equal("White", renewedColor)
    Test.deepEqual({
        "tapped:getActionZoneTapRotation",
        "tapped:onCardTapped",
        "untapped:getActionZoneTapRotation"
    }, events)

    events = {}
    renewedColor = nil
    Test.truthy(controller.advancePhase("White"))
    Test.deepEqual({}, events)
    Test.nilValue(renewedColor)
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

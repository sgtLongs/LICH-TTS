local Test = require("tests/support/Test")
local MockPlayerConfig = require(
    "src/mock_players/MockPlayerConfig"
)
local MockPlayerFeature = require(
    "src/mock_players/MockPlayerFeature"
)
local FakeWait = require("tests/support/FakeWait")
local Scheduler = require("src/tts/Scheduler")

Test.case("mock player feature owns allocation names and persistence", function()
    local players = {
        White = {seated = true},
        Brown = {seated = false}
    }
    local feature = MockPlayerFeature.new({
        getPlayer = function(color)
            return players[color]
        end
    })
    local activeByColor = {Red = true}

    local added, color = feature:add(activeByColor)

    Test.truthy(added)
    Test.equal("Brown", color)
    Test.truthy(feature:isMock("Brown"))
    Test.equal("Mock Brown", feature:getName("Brown"))
    Test.deepEqual({"Brown"}, feature:getPlayerColors())

    feature:load({
        mockPlayerColors = {"Blue", "invalid", "White"},
        disconnectedMockPlayerColors = {"Blue", "White"}
    }, {Blue = true})
    Test.deepEqual({"Blue"}, feature:getPlayerColors())
    Test.deepEqual({"Blue"}, feature:getDisconnectedPlayerColors())
    Test.equal("Mock Blue (Disconnected)", feature:getName("Blue"))
end)

Test.case("mock player feature tracks the most recently added player", function()
    local feature = MockPlayerFeature.new({
        getPlayer = function()
            return {seated = false}
        end
    })
    local activeByColor = {}

    local _, firstColor = feature:add(activeByColor)
    activeByColor[firstColor] = true
    local _, secondColor = feature:add(activeByColor)
    activeByColor[secondColor] = true

    Test.equal(secondColor, feature:getMostRecentPlayerColor())
    Test.truthy(feature:remove(secondColor))
    Test.equal(firstColor, feature:getMostRecentPlayerColor())

    Test.truthy(feature:replaceWithReal(firstColor))
    activeByColor[firstColor] = nil
    local _, readdedColor = feature:add(activeByColor)
    Test.equal(firstColor, readdedColor)
    Test.equal(firstColor, feature:getMostRecentPlayerColor())
    Test.deepEqual({firstColor}, feature:getPlayerColors())
end)

Test.case("disconnecting a mock preserves it and stops automation", function()
    local wait = FakeWait.new()
    local advanced = {}
    local feature = MockPlayerFeature.new({
        scheduler = Scheduler.new(wait),
        getPlayer = function()
            return {seated = false}
        end
    })
    local _, firstColor = feature:add({})
    local activeByColor = {[firstColor] = true}
    local _, secondColor = feature:add(activeByColor)
    local parameters = {
        getCurrentColor = function()
            return secondColor
        end,
        isBlocked = function()
            return false
        end,
        advance = function(color)
            advanced[#advanced + 1] = color
        end
    }

    Test.truthy(feature:schedule(parameters))
    local disconnected, color = feature:disconnectMostRecent()
    Test.truthy(disconnected)
    Test.equal(secondColor, color)
    Test.truthy(feature:isMock(secondColor))
    Test.truthy(feature:isDisconnected(secondColor))
    Test.deepEqual({firstColor, secondColor}, feature:getPlayerColors())
    Test.deepEqual({secondColor}, feature:getDisconnectedPlayerColors())
    Test.falsy(feature:schedule(parameters))

    wait.advanceTime(MockPlayerConfig.phaseDelaySeconds)
    Test.deepEqual({}, advanced)
    disconnected, color = feature:disconnectMostRecent()
    Test.truthy(disconnected)
    Test.equal(firstColor, color)
    Test.falsy(feature:disconnectMostRecent())
end)

Test.case("mock player feature schedules only current unblocked mocks", function()
    local wait = FakeWait.new()
    local currentColor = "White"
    local advanced = {}
    local feature = MockPlayerFeature.new({
        scheduler = Scheduler.new(wait),
        getPlayer = function()
            return {seated = false}
        end
    })
    feature:add({})
    local parameters = {
        getCurrentColor = function()
            return currentColor
        end,
        isBlocked = function()
            return false
        end,
        advance = function(color)
            advanced[#advanced + 1] = color
        end
    }

    Test.truthy(feature:schedule(parameters))
    currentColor = "Red"
    wait.advanceTime(MockPlayerConfig.phaseDelaySeconds)
    Test.deepEqual({}, advanced)

    currentColor = "White"
    Test.truthy(feature:schedule(parameters))
    wait.advanceTime(MockPlayerConfig.phaseDelaySeconds)
    Test.deepEqual({"White"}, advanced)
end)

Test.case("mock player feature routes random decks and rolls back failures", function()
    local removedColor = nil
    local turnSystem = {
        addMockPlayer = function()
            return true, "Teal"
        end,
        removeMockPlayer = function(color)
            removedColor = color
        end
    }
    local succeeded, color, deckName =
        MockPlayerFeature.addWithRandomDeck(turnSystem, {
            spawnRandomDeck = function(requestedColor)
                Test.equal("Teal", requestedColor)
                return true, {name = "Brain"}
            end
        })

    Test.truthy(succeeded)
    Test.equal("Teal", color)
    Test.equal("Brain", deckName)

    succeeded, color, deckName =
        MockPlayerFeature.addWithRandomDeck(turnSystem, {
            spawnRandomDeck = function()
                return false, nil
            end
        })
    Test.falsy(succeeded)
    Test.nilValue(color)
    Test.nilValue(deckName)
    Test.equal("Teal", removedColor)
end)

Test.case("mock player feature selects the random death fog boundary", function()
    local feature = MockPlayerFeature.new({
        getPlayer = function()
            return {seated = false}
        end
    })
    local normal = function()
    end
    local random = function()
    end
    local endPhase = {
        beginDeathFogPlacement = normal,
        beginRandomDeathFogPlacement = random
    }

    Test.equal(normal, feature:getDeathFogStarter(endPhase, "Red"))
    feature:add({})
    Test.equal(random, feature:getDeathFogStarter(endPhase, "White"))
end)

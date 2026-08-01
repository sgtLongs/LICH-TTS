local Test = require("tests/support/Test")
local TurnState = require("src/turns/TurnState")

local colors = {"White", "Red", "Blue"}

Test.case("turn state starts at the first player", function()
    local state = TurnState.new(colors)

    Test.equal("White", TurnState.getCurrentColor(state))
    Test.equal(1, TurnState.getSaveState(state).currentTurnIndex)
    Test.equal("start", TurnState.getCurrentPhase(state))
end)

Test.case("turn state advances through every phase in order", function()
    local state = TurnState.new(colors)

    Test.truthy(TurnState.advancePhase(state, "White"))
    Test.equal("main", TurnState.getCurrentPhase(state))
    Test.truthy(TurnState.advancePhase(state, "White"))
    Test.equal("draw", TurnState.getCurrentPhase(state))
    Test.truthy(TurnState.advancePhase(state, "White"))
    Test.equal("status", TurnState.getCurrentPhase(state))
    Test.truthy(TurnState.advancePhase(state, "White"))
    Test.equal("end", TurnState.getCurrentPhase(state))

    Test.truthy(TurnState.advancePhase(state, "White"))
    Test.equal("Red", TurnState.getCurrentColor(state))
    Test.equal("start", TurnState.getCurrentPhase(state))
end)

Test.case("turn state rejects phase changes from another player", function()
    local state = TurnState.new(colors)

    Test.falsy(TurnState.advancePhase(state, "Red"))
    Test.equal("start", TurnState.getCurrentPhase(state))
end)

Test.case("turn state restores a saved phase", function()
    local state = TurnState.new(colors, {
        currentTurnColor = "Blue",
        currentPhase = "status"
    })

    Test.equal("Blue", TurnState.getCurrentColor(state))
    Test.equal("status", TurnState.getCurrentPhase(state))
    Test.equal(4, TurnState.getSaveState(state).currentPhaseIndex)
end)

Test.case("turn state restores a saved turn", function()
    local state = TurnState.new(colors, {currentTurnIndex = 2})

    Test.equal("Red", TurnState.getCurrentColor(state))
end)

Test.case("turn state ignores invalid saved turns", function()
    local state = TurnState.new(colors, {currentTurnIndex = 20})

    Test.equal("White", TurnState.getCurrentColor(state))
end)

Test.case("turn state rejects the wrong player", function()
    local state = TurnState.new(colors)

    Test.falsy(TurnState.endTurn(state, "Red"))
    Test.equal("White", TurnState.getCurrentColor(state))
end)

Test.case("turn state advances and wraps", function()
    local state = TurnState.new(colors, {currentTurnIndex = 3})

    Test.truthy(TurnState.endTurn(state, "Blue"))
    Test.equal("White", TurnState.getCurrentColor(state))
end)

Test.case("turn state supports changing active players", function()
    local state = TurnState.new({})

    Test.equal(nil, TurnState.getCurrentColor(state))
    Test.falsy(TurnState.endTurn(state, "White"))

    TurnState.setPlayerColors(state, {"Red"})
    Test.equal("Red", TurnState.getCurrentColor(state))

    TurnState.setPlayerColors(state, {"White", "Red", "Blue"})
    Test.equal("Red", TurnState.getCurrentColor(state))

    TurnState.setPlayerColors(state, {"White", "Blue"})
    Test.equal("White", TurnState.getCurrentColor(state))
end)

Test.case("turn state restores the active current color", function()
    local state = TurnState.new(
        {"White", "Red", "Blue"},
        {
            currentTurnIndex = 1,
            currentTurnColor = "Blue"
        }
    )

    Test.equal("Blue", TurnState.getCurrentColor(state))
end)

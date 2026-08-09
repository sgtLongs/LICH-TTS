local Test = require("tests/support/Test")
local ActionPoints = require("src/action_points/ActionPoints")
local playerColors = {"Red"}

Test.case("action points restore and expose semantic operations", function()
    local actionPoints = ActionPoints.new({count = 4})
    actionPoints:load(playerColors, {
        Red = {true, false, true, true, true}
    })

    Test.deepEqual(
        {true, false, true, true},
        actionPoints:getUsed("Red")
    )
    Test.truthy(actionPoints:restore("Red", 1))
    Test.falsy(actionPoints:restore("Red", 1))
    Test.truthy(actionPoints:use("Red", 2))
    Test.falsy(actionPoints:use("Red", 2))
    Test.falsy(actionPoints:toggle("Red", 5))
    Test.deepEqual({false, true, true, true}, actionPoints:getUsed("Red"))
    Test.truthy(actionPoints:setUsed("Red", 4, false))
    Test.falsy(actionPoints:setUsed("Blue", 1, true))

    local status = actionPoints:getStatus("Red")
    Test.equal(2, status.usableCount)
    Test.equal(4, status.total)
    Test.truthy(actionPoints:renew("Red"))
    Test.deepEqual(
        {false, false, false, false},
        actionPoints:save(playerColors).Red
    )
end)

Test.case("action point snapshots cannot mutate feature state", function()
    local actionPoints = ActionPoints.new({count = 2})
    actionPoints:load(playerColors, {Red = {true, false}})
    local status = actionPoints:getStatus("Red")

    status.used[1] = false

    Test.deepEqual({true, false}, actionPoints:getUsed("Red"))
end)

local Test = require("tests/support/Test")
local BoardLoadCoordinator = require("src/boards/BoardLoadCoordinator")

local function makeCoordinator()
    local scheduled = {}
    local coordinator = BoardLoadCoordinator.new({
        schedule = function(callback, frameCount)
            scheduled[#scheduled + 1] = {
                callback = callback,
                frameCount = frameCount
            }
        end
    })

    local function run(frameCount)
        local ran = 0
        local index = 1

        while index <= #scheduled do
            local item = scheduled[index]

            if item.frameCount == frameCount then
                table.remove(scheduled, index)
                item.callback()
                ran = ran + 1
            else
                index = index + 1
            end
        end

        return ran
    end

    return coordinator, run, scheduled
end

Test.case("board load coordinator orders synchronous completion after acceptance", function()
    local coordinator, run = makeCoordinator()
    local finished = {}
    local generation = coordinator:begin({
        requestedId = "board-a",
        timeoutFrames = 600,
        completionDelayFrames = 75,
        onFinished = function(result)
            finished[#finished + 1] = result
        end
    })

    Test.truthy(coordinator:complete(generation, "board-a", true))
    Test.equal(0, #finished)
    Test.truthy(coordinator:accept(generation, "accepted"))
    Test.equal(0, #finished)
    Test.equal(1, run(75))
    Test.equal(1, #finished)
    Test.truthy(finished[1].succeeded)
    Test.equal("accepted", finished[1].acceptedValue)
end)

Test.case("board load coordinator times out accepted incomplete loads", function()
    local coordinator, run = makeCoordinator()
    local result = nil
    local generation = coordinator:begin({
        requestedId = "board-a",
        timeoutFrames = 30,
        onFinished = function(value)
            result = value
        end
    })

    coordinator:accept(generation)
    Test.equal(1, run(30))
    Test.truthy(result.timedOut)
    Test.falsy(result.succeeded)
    Test.falsy(coordinator:isActive(generation))
end)

Test.case("board load coordinator rejects duplicate and stale completion", function()
    local coordinator = makeCoordinator()
    local first = coordinator:begin({})
    local second = coordinator:begin({completionDelayFrames = 5})

    Test.falsy(coordinator:complete(first, "old", true))
    Test.truthy(coordinator:complete(second, "new", false))
    Test.falsy(coordinator:complete(second, "new", true))
    Test.truthy(coordinator:cancel(second))
    Test.falsy(coordinator:cancel(second))
end)

Test.case("board request tracker reports synchronous callbacks exactly once", function()
    local coordinator = BoardLoadCoordinator.new()
    local calls = {}
    local request = coordinator:createRequest({
        requestedId = "board-a",
        onStarted = function(boardSaveId)
            calls[#calls + 1] = "started:" .. boardSaveId
            return 17
        end,
        onCompleted = function(generation, boardSaveId, succeeded)
            calls[#calls + 1] = "completed:" .. generation .. ":"
                .. boardSaveId .. ":" .. tostring(succeeded)
        end
    })

    Test.truthy(request:complete(true))
    Test.equal(0, #calls)
    Test.truthy(request:accept())
    Test.deepEqual({
        "started:board-a",
        "completed:17:board-a:true"
    }, calls)
    Test.falsy(request:complete(false))
    Test.falsy(request:accept())
    Test.equal(2, #calls)
end)

local FakeWait = {}

function FakeWait.new()
    local fake = {
        currentFrame = 0,
        currentTime = 0
    }
    local nextId = 1
    local scheduledFrames = {}
    local scheduledTimes = {}
    local conditions = {}
    local stopped = {}

    local function allocateId()
        local identifier = nextId
        nextId = nextId + 1
        return identifier
    end

    function fake.frames(callback, frameCount)
        local identifier = allocateId()
        scheduledFrames[#scheduledFrames + 1] = {
            id = identifier,
            due = fake.currentFrame + math.max(0, frameCount or 0),
            callback = callback
        }
        return identifier
    end

    function fake.time(callback, delay, repetitions)
        local identifier = allocateId()
        scheduledTimes[#scheduledTimes + 1] = {
            id = identifier,
            due = fake.currentTime + math.max(0, delay or 0),
            delay = math.max(0, delay or 0),
            repetitions = repetitions == nil and 1 or repetitions,
            callback = callback
        }
        return identifier
    end

    function fake.condition(callback, predicate, timeout, timeoutCallback)
        local identifier = allocateId()
        conditions[#conditions + 1] = {
            id = identifier,
            callback = callback,
            predicate = predicate,
            deadline = timeout ~= nil
                and fake.currentTime + math.max(0, timeout) or nil,
            timeoutCallback = timeoutCallback
        }
        return identifier
    end

    function fake.stop(identifier)
        stopped[identifier] = true
    end

    local function evaluateConditions()
        for index = #conditions, 1, -1 do
            local condition = conditions[index]

            if stopped[condition.id] then
                table.remove(conditions, index)
            elseif condition.predicate() then
                table.remove(conditions, index)
                condition.callback()
            elseif condition.deadline ~= nil
                and fake.currentTime >= condition.deadline
            then
                table.remove(conditions, index)

                if condition.timeoutCallback ~= nil then
                    condition.timeoutCallback()
                end
            end
        end
    end

    local function runFrameTasks()
        local ran = true

        while ran do
            ran = false

            for index = #scheduledFrames, 1, -1 do
                local scheduled = scheduledFrames[index]

                if stopped[scheduled.id] then
                    table.remove(scheduledFrames, index)
                elseif scheduled.due <= fake.currentFrame then
                    table.remove(scheduledFrames, index)
                    scheduled.callback()
                    ran = true
                end
            end
        end
    end

    local function runTimeTasks()
        local ran = true

        while ran do
            ran = false

            for index = #scheduledTimes, 1, -1 do
                local scheduled = scheduledTimes[index]

                if stopped[scheduled.id] then
                    table.remove(scheduledTimes, index)
                elseif scheduled.due <= fake.currentTime then
                    table.remove(scheduledTimes, index)
                    scheduled.callback()
                    ran = true

                    if scheduled.repetitions == -1
                        or scheduled.repetitions > 1
                    then
                        if scheduled.repetitions > 1 then
                            scheduled.repetitions = scheduled.repetitions - 1
                        end

                        -- TTS permits zero-delay repeating timers. Keep those
                        -- deterministic without executing the same timer
                        -- forever in a single runDue call.
                        scheduled.due = fake.currentTime
                            + math.max(scheduled.delay, 0.000001)
                        scheduledTimes[#scheduledTimes + 1] = scheduled
                    end
                end
            end
        end
    end

    function fake.runDue()
        runFrameTasks()
        runTimeTasks()
        evaluateConditions()
    end

    function fake.advanceFrames(frameCount)
        for _ = 1, math.max(0, frameCount or 1) do
            fake.currentFrame = fake.currentFrame + 1
            fake.runDue()
        end
    end

    function fake.advanceTime(seconds)
        fake.currentTime = fake.currentTime + math.max(0, seconds or 0)
        fake.runDue()
    end

    function fake.pendingCount()
        return #scheduledFrames + #scheduledTimes + #conditions
    end

    function fake.runAll(maxIterations)
        local limit = maxIterations or 1000
        local iterations = 0

        while fake.pendingCount() > 0 and iterations < limit do
            iterations = iterations + 1
            fake.currentFrame = fake.currentFrame + 1
            fake.currentTime = fake.currentTime + 1
            fake.runDue()
        end

        if fake.pendingCount() > 0 then
            error("FakeWait exceeded its runAll iteration limit.")
        end
    end

    return fake
end

return FakeWait

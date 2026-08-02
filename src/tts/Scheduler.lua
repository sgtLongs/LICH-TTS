local Scheduler = {}
local defaultScheduler = nil

function Scheduler.new(waitApi)
    local scheduler = {}

    local function getWait()
        if waitApi ~= nil then
            return waitApi
        end

        return Wait
    end

    function scheduler.hasFrames()
        local wait = getWait()
        return wait ~= nil and type(wait.frames) == "function"
    end

    function scheduler.hasTime()
        local wait = getWait()
        return wait ~= nil and type(wait.time) == "function"
    end

    function scheduler.hasCondition()
        local wait = getWait()
        return wait ~= nil and type(wait.condition) == "function"
    end

    function scheduler.frames(callback, frameCount)
        local wait = getWait()

        if wait ~= nil and type(wait.frames) == "function" then
            return wait.frames(callback, frameCount)
        end

        return callback()
    end

    function scheduler.time(callback, delay, repetitions)
        local wait = getWait()

        if wait ~= nil and type(wait.time) == "function" then
            return wait.time(callback, delay, repetitions)
        end

        callback()
        return nil
    end

    function scheduler.condition(
        callback,
        predicate,
        timeout,
        timeoutCallback
    )
        local wait = getWait()

        if wait ~= nil and type(wait.condition) == "function" then
            return wait.condition(
                callback,
                predicate,
                timeout,
                timeoutCallback
            )
        end

        if predicate() then
            return callback()
        end

        if timeoutCallback ~= nil then
            return timeoutCallback()
        end

        return nil
    end

    function scheduler.stop(identifier)
        local wait = getWait()

        if wait ~= nil and type(wait.stop) == "function" then
            return wait.stop(identifier)
        end

        return nil
    end

    return scheduler
end

function Scheduler.default()
    if defaultScheduler == nil then
        defaultScheduler = Scheduler.new()
    end

    return defaultScheduler
end

function Scheduler.setDefault(scheduler)
    defaultScheduler = scheduler or Scheduler.new()
end

return Scheduler

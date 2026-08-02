local BoardLoadCoordinator = {}
local Coordinator = {}
local Request = {}

Coordinator.__index = Coordinator
Request.__index = Request

local function resolveOption(value, fallback)
    if value == nil then
        return fallback
    end

    return value
end

function BoardLoadCoordinator.new(options)
    options = options or {}

    return setmetatable({
        schedule = options.schedule,
        defaultTimeoutFrames = options.timeoutFrames,
        defaultCompletionDelayFrames = options.completionDelayFrames or 0,
        generation = 0,
        active = nil
    }, Coordinator)
end

function Coordinator:reset()
    self.generation = 0
    self.active = nil
end

function Coordinator:getGeneration()
    return self.generation
end

function Coordinator:getActive()
    return self.active
end

function Coordinator:isActive(generation)
    return self.active ~= nil
        and self.active.generation == generation
        and not self.active.finished
end

function Coordinator:_finish(transaction, timedOut)
    if not self:isActive(transaction.generation) then
        return false
    end

    transaction.finished = true
    self.active = nil

    if transaction.onFinished ~= nil then
        transaction.onFinished({
            generation = transaction.generation,
            requestedId = transaction.requestedId,
            completedId = transaction.completedId,
            succeeded = not timedOut
                and transaction.completionSucceeded == true,
            timedOut = timedOut == true,
            acceptedValue = transaction.acceptedValue
        })
    end

    return true
end

function Coordinator:_scheduleCompletion(transaction)
    if transaction.completionScheduled
        or not transaction.accepted
        or not transaction.completionArrived
    then
        return
    end

    transaction.completionScheduled = true
    local delayFrames = resolveOption(
        transaction.completionDelayFrames,
        self.defaultCompletionDelayFrames
    )

    if delayFrames > 0 and self.schedule ~= nil then
        self.schedule(function()
            self:_finish(transaction, false)
        end, delayFrames)
    else
        self:_finish(transaction, false)
    end
end

function Coordinator:begin(options)
    options = options or {}
    self.generation = self.generation + 1

    local transaction = {
        generation = self.generation,
        requestedId = options.requestedId,
        timeoutFrames = options.timeoutFrames,
        completionDelayFrames = options.completionDelayFrames,
        onFinished = options.onFinished,
        accepted = false,
        completionArrived = false,
        completionScheduled = false,
        finished = false
    }

    self.active = transaction
    return transaction.generation
end

function Coordinator:accept(generation, acceptedValue)
    if not self:isActive(generation) then
        return false
    end

    local transaction = self.active

    if transaction.accepted then
        return false
    end

    transaction.accepted = true
    transaction.acceptedValue = acceptedValue
    local timeoutFrames = resolveOption(
        transaction.timeoutFrames,
        self.defaultTimeoutFrames
    )

    if timeoutFrames ~= nil
        and timeoutFrames > 0
        and self.schedule ~= nil
    then
        self.schedule(function()
            if self:isActive(generation)
                and not transaction.completionArrived
            then
                self:_finish(transaction, true)
            end
        end, timeoutFrames)
    end

    self:_scheduleCompletion(transaction)
    return true
end

function Coordinator:complete(generation, completedId, succeeded)
    if not self:isActive(generation) then
        return false
    end

    local transaction = self.active

    if transaction.completionArrived then
        return false
    end

    transaction.completionArrived = true
    transaction.completedId = completedId
    transaction.completionSucceeded = succeeded == true
    self:_scheduleCompletion(transaction)
    return true
end

function Coordinator:cancel(generation)
    if not self:isActive(generation) then
        return false
    end

    self.active.finished = true
    self.active = nil
    return true
end

function Coordinator:createRequest(options)
    options = options or {}

    return setmetatable({
        requestedId = options.requestedId,
        onStarted = options.onStarted,
        onCompleted = options.onCompleted,
        onReported = options.onReported,
        accepted = false,
        completionArrived = false,
        completionReported = false,
        completionSucceeded = false,
        generation = nil
    }, Request)
end

function Request:_reportIfReady()
    if self.completionReported
        or not self.accepted
        or not self.completionArrived
    then
        return false
    end

    self.completionReported = true
    local completionAccepted = true

    if self.onCompleted ~= nil then
        completionAccepted = self.onCompleted(
            self.generation,
            self.requestedId,
            self.completionSucceeded
        ) ~= false
    end

    if self.onReported ~= nil then
        self.onReported(
            self.completionSucceeded,
            completionAccepted
        )
    end

    return true
end

function Request:accept()
    if self.accepted then
        return false
    end

    self.accepted = true

    if self.onStarted ~= nil then
        self.generation = self.onStarted(self.requestedId)
    end

    self:_reportIfReady()
    return true
end

function Request:complete(succeeded)
    if self.completionArrived then
        return false
    end

    self.completionArrived = true
    self.completionSucceeded = succeeded == true
    self:_reportIfReady()
    return true
end

return BoardLoadCoordinator

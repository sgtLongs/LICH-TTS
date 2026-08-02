local ZoneBehaviorRegistry = {}
ZoneBehaviorRegistry.__index = ZoneBehaviorRegistry

function ZoneBehaviorRegistry.new()
    return setmetatable({
        behaviorsByType = {},
        orderedTypes = {}
    }, ZoneBehaviorRegistry)
end

function ZoneBehaviorRegistry:register(zoneType, behavior)
    if type(zoneType) ~= "string" or zoneType == "" then
        error("Zone behavior type must be a non-empty string.", 2)
    end

    if type(behavior) ~= "table" then
        error("Zone behavior must be a table.", 2)
    end

    if self.behaviorsByType[zoneType] == nil then
        self.orderedTypes[#self.orderedTypes + 1] = zoneType
    end

    self.behaviorsByType[zoneType] = behavior
    return behavior
end

function ZoneBehaviorRegistry:get(zoneType)
    return self.behaviorsByType[zoneType]
end

function ZoneBehaviorRegistry:load(fields, savedState)
    savedState = type(savedState) == "table" and savedState or {}

    for _, zoneType in ipairs(self.orderedTypes) do
        local behavior = self.behaviorsByType[zoneType]
        local handler = behavior.onLoad or behavior.load

        if type(handler) == "function" then
            handler(fields, savedState[behavior.saveKey or zoneType])
        end
    end
end

function ZoneBehaviorRegistry:save(fields)
    local savedState = {}

    for _, zoneType in ipairs(self.orderedTypes) do
        local behavior = self.behaviorsByType[zoneType]
        local handler = behavior.getSaveState or behavior.save

        if type(handler) == "function" then
            savedState[behavior.saveKey or zoneType] = handler(fields)
        end
    end

    return savedState
end

function ZoneBehaviorRegistry:refresh(fields)
    for _, zoneType in ipairs(self.orderedTypes) do
        local behavior = self.behaviorsByType[zoneType]

        if type(behavior.refresh) == "function" then
            behavior.refresh(fields)
        end
    end
end

function ZoneBehaviorRegistry:dispatch(eventName, fields, ...)
    for _, zoneType in ipairs(self.orderedTypes) do
        local behavior = self.behaviorsByType[zoneType]
        local handler = behavior[eventName]
        local result = nil

        if type(handler) == "function" then
            result = handler(fields, ...)
        elseif type(behavior.handle) == "function" then
            result = behavior.handle(eventName, fields, ...)
        end

        if result then
            return result
        end
    end

    return false
end

return ZoneBehaviorRegistry

local ActionPoints = {}
ActionPoints.__index = ActionPoints

local function normalizedCount(value)
    return math.max(0, math.floor(tonumber(value) or 0))
end

function ActionPoints.new(config)
    config = config or {}

    return setmetatable({
        count = normalizedCount(config.count),
        usedByPlayer = {}
    }, ActionPoints)
end

function ActionPoints:load(playerColors, savedByPlayer)
    self.usedByPlayer = {}
    savedByPlayer = type(savedByPlayer) == "table" and savedByPlayer or {}

    for _, playerColor in ipairs(playerColors or {}) do
        local saved = savedByPlayer[playerColor]
        local used = {}

        for index = 1, self.count do
            used[index] = type(saved) == "table" and saved[index] == true
        end

        self.usedByPlayer[playerColor] = used
    end
end

function ActionPoints:getUsed(playerColor)
    local current = self.usedByPlayer[playerColor] or {}
    local copy = {}

    for index = 1, #current do
        copy[index] = current[index] == true
    end

    return copy
end

function ActionPoints:getStatus(playerColor)
    local used = self:getUsed(playerColor)
    local usableCount = 0

    for index = 1, #used do
        if not used[index] then
            usableCount = usableCount + 1
        end
    end

    return {
        used = used,
        usableCount = usableCount,
        total = #used
    }
end

function ActionPoints:setUsed(playerColor, index, used)
    local current = self.usedByPlayer[playerColor]

    if type(index) ~= "number" or current == nil
        or current[index] == nil
    then
        return false
    end

    current[index] = used == true
    return true
end

function ActionPoints:use(playerColor, index)
    local current = self.usedByPlayer[playerColor]

    if type(index) ~= "number" or current == nil
        or current[index] ~= false
    then
        return false
    end

    current[index] = true
    return true
end

function ActionPoints:restore(playerColor, index)
    local current = self.usedByPlayer[playerColor]

    if type(index) ~= "number" or current == nil
        or current[index] ~= true
    then
        return false
    end

    current[index] = false
    return true
end

function ActionPoints:toggle(playerColor, index)
    local current = self.usedByPlayer[playerColor]

    if type(index) ~= "number" or current == nil
        or current[index] == nil
    then
        return false
    end

    current[index] = not current[index]
    return true
end

function ActionPoints:renew(playerColor)
    local current = self.usedByPlayer[playerColor]

    if current == nil then
        return false
    end

    for index = 1, #current do
        current[index] = false
    end

    return true
end

function ActionPoints:save(playerColors)
    local savedByPlayer = {}

    for _, playerColor in ipairs(playerColors or {}) do
        savedByPlayer[playerColor] = self:getUsed(playerColor)
    end

    return savedByPlayer
end

return ActionPoints

local DrawPhase = {}

function DrawPhase.cardCount(intelligence, handCount)
    local target = math.floor(tonumber(intelligence) or 0)
    local current = math.floor(tonumber(handCount) or 0)
    return math.max(0, target - math.max(0, current))
end

function DrawPhase.findDrawSource(objects, deckPosition, searchRadius)
    if type(deckPosition) ~= "table" then
        return nil
    end

    local targetX = tonumber(deckPosition.x or deckPosition[1])
    local targetZ = tonumber(deckPosition.z or deckPosition[3])

    if targetX == nil or targetZ == nil then
        return nil
    end

    local radius = math.max(0, tonumber(searchRadius) or 0)
    local best = nil
    local bestDistanceSquared = radius * radius

    for _, object in ipairs(objects or {}) do
        local eligible = object ~= nil
            and (object.tag == "Deck" or object.tag == "Card")
            and type(object.getPosition) == "function"
            and type(object.deal) == "function"

        if eligible and type(object.isDestroyed) == "function" then
            local succeeded, destroyed = pcall(object.isDestroyed)
            eligible = not succeeded or destroyed ~= true
        end

        if eligible then
            local succeeded, position = pcall(object.getPosition)

            if succeeded and type(position) == "table" then
                local x = tonumber(position.x or position[1])
                local z = tonumber(position.z or position[3])

                if x ~= nil and z ~= nil then
                    local xOffset = x - targetX
                    local zOffset = z - targetZ
                    local distanceSquared = xOffset * xOffset
                        + zOffset * zOffset

                    if distanceSquared <= bestDistanceSquared then
                        best = object
                        bestDistanceSquared = distanceSquared
                    end
                end
            end
        end
    end

    return best
end

return DrawPhase

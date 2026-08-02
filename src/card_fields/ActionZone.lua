local ActionZone = {}
local pickedUpFieldByCard = {}

local function rotateToWorld(localX, localZ, field)
    local radians = math.rad(field.downRotationDegrees or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return {
        x = field.position.x + localX * cosine + localZ * sine,
        z = field.position.z - localX * sine + localZ * cosine
    }
end

local function rotateToLocal(position, field)
    local radians = math.rad(field.downRotationDegrees or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    local offsetX = position.x - field.position.x
    local offsetZ = position.z - field.position.z

    return {
        x = offsetX * cosine - offsetZ * sine,
        z = offsetX * sine + offsetZ * cosine
    }
end

local function isCard(object)
    return object ~= nil
        and object.tag == "Card"
        and type(object.getPosition) == "function"
end

local function cardKey(object)
    if object ~= nil and type(object.getGUID) == "function" then
        return tostring(object.getGUID())
    end

    return tostring(object)
end

local function getObjects(objects)
    if type(objects) == "table" then
        return objects
    end

    return getAllObjects()
end

function ActionZone.contains(field, position)
    local zone = field and field.actionZone

    if zone == nil or type(position) ~= "table" then
        return false
    end

    local localPosition = rotateToLocal(position, field)
    return localPosition.x >= zone.localLeft
        and localPosition.x <= zone.localRight
        and localPosition.z >= zone.localTop
        and localPosition.z <= zone.localBottom
end

function ActionZone.findField(fields, position)
    for _, field in ipairs(fields or {}) do
        if ActionZone.contains(field, position) then
            return field
        end
    end

    return nil
end

function ActionZone.getSnapPositions(field, cardCount)
    local positions = {}
    local zone = field and field.actionZone
    cardCount = math.floor(tonumber(cardCount) or 0)

    if zone == nil or cardCount <= 0 then
        return positions
    end

    local defaultSlots = math.max(
        1,
        math.floor(tonumber(zone.defaultSlots) or 5)
    )
    local zoneWidth = zone.localRight - zone.localLeft
    local defaultSpacing = zoneWidth / defaultSlots
    local firstX = zone.localLeft + defaultSpacing * 0.5
    local lastX = zone.localRight - defaultSpacing * 0.5
    local spacing = defaultSpacing

    if cardCount > defaultSlots then
        spacing = (lastX - firstX) / (cardCount - 1)
    end

    for index = 1, cardCount do
        local worldPosition = rotateToWorld(
            firstX + (index - 1) * spacing,
            zone.localCenterZ,
            field
        )
        worldPosition.y = zone.y + zone.cardCenterHeight
        positions[index] = worldPosition
    end

    return positions
end

local function collectCards(field, preferredCard, excludedCard, objects)
    local cards = {}

    for _, object in ipairs(getObjects(objects)) do
        if object ~= preferredCard
            and object ~= excludedCard
            and isCard(object)
            and ActionZone.contains(field, object.getPosition())
        then
            cards[#cards + 1] = object
        end
    end

    table.sort(cards, function(leftCard, rightCard)
        local leftPosition = rotateToLocal(leftCard.getPosition(), field)
        local rightPosition = rotateToLocal(rightCard.getPosition(), field)

        if leftPosition.x == rightPosition.x then
            return cardKey(leftCard) < cardKey(rightCard)
        end

        return leftPosition.x < rightPosition.x
    end)

    if preferredCard ~= nil then
        cards[#cards + 1] = preferredCard
    end

    return cards
end

local function moveCard(card, position)
    if type(card.setVelocity) == "function" then
        card.setVelocity({0, 0, 0})
    end

    if type(card.setAngularVelocity) == "function" then
        card.setAngularVelocity({0, 0, 0})
    end

    if type(card.setPositionSmooth) == "function" then
        card.setPositionSmooth(position, false, true)
    elseif type(card.setPosition) == "function" then
        card.setPosition(position)
    end
end

function ActionZone.arrange(field, preferredCard, objects, excludedCard)
    if field == nil or field.actionZone == nil then
        return false
    end

    local cards = collectCards(
        field,
        preferredCard,
        excludedCard,
        objects
    )
    local positions = ActionZone.getSnapPositions(field, #cards)

    for index, card in ipairs(cards) do
        moveCard(card, positions[index])
    end

    return #cards > 0
end

function ActionZone.onCardLeaves(fields, object, objects)
    if not isCard(object) then
        return false
    end

    local field = ActionZone.findField(fields, object.getPosition())

    if field == nil then
        return false
    end

    pickedUpFieldByCard[cardKey(object)] = nil
    ActionZone.arrange(field, nil, getObjects(objects), object)
    return true
end

function ActionZone.onObjectPickUp(fields, object)
    if not isCard(object) then
        return false
    end

    local field = ActionZone.findField(fields, object.getPosition())
    pickedUpFieldByCard[cardKey(object)] = field
    return field ~= nil
end

function ActionZone.onObjectDrop(fields, object, objects)
    if not isCard(object) then
        return false
    end

    local key = cardKey(object)
    local previousField = pickedUpFieldByCard[key]
    local targetField = ActionZone.findField(fields, object.getPosition())
    local allObjects = getObjects(objects)
    pickedUpFieldByCard[key] = nil

    if targetField ~= nil then
        ActionZone.arrange(targetField, object, allObjects)
    end

    if previousField ~= nil and previousField ~= targetField then
        ActionZone.arrange(previousField, nil, allObjects)
    end

    return targetField ~= nil
end

return ActionZone

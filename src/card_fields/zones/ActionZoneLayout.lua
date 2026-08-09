local ActionZoneState = require("src/card_fields/zones/ActionZoneState")

local ActionZoneLayout = {}

local NAVIGATE_UP_FUNCTION = "onActionStackUpClicked"
local NAVIGATE_DOWN_FUNCTION = "onActionStackDownClicked"

function ActionZoneLayout.toWorld(localX, localZ, field)
    local radians = math.rad(field.downRotationDegrees or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return {
        x = field.position.x + localX * cosine + localZ * sine,
        z = field.position.z - localX * sine + localZ * cosine
    }
end

function ActionZoneLayout.toLocal(position, field)
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

function ActionZoneLayout.contains(field, position)
    local zone = field and field.actionZone

    if zone == nil
        or type(field.position) ~= "table"
        or type(position) ~= "table"
        or tonumber(position.x) == nil
        or tonumber(position.z) == nil
    then
        return false
    end

    local localPosition = ActionZoneLayout.toLocal(position, field)
    return localPosition.x >= zone.localLeft
        and localPosition.x <= zone.localRight
        and localPosition.z >= zone.localTop
        and localPosition.z <= zone.localBottom
end

function ActionZoneLayout.findField(fields, position)
    for _, field in ipairs(fields or {}) do
        if ActionZoneLayout.contains(field, position) then
            return field
        end
    end

    return nil
end

function ActionZoneLayout.getSnapPositions(field, cardCount)
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
        local worldPosition = ActionZoneLayout.toWorld(
            firstX + (index - 1) * spacing,
            zone.localCenterZ,
            field
        )
        worldPosition.y = zone.y + zone.cardCenterHeight
        positions[index] = worldPosition
    end

    return positions
end

function ActionZoneLayout.comparePositions(field, left, right)
    local leftLocal = ActionZoneLayout.toLocal(left.position, field)
    local rightLocal = ActionZoneLayout.toLocal(right.position, field)

    if leftLocal.x == rightLocal.x then
        if leftLocal.z == rightLocal.z then
            return tostring(left.cardId) < tostring(right.cardId)
        end

        return leftLocal.z < rightLocal.z
    end

    return leftLocal.x < rightLocal.x
end

function ActionZoneLayout.findDropTarget(
    field,
    droppedPosition,
    candidates
)
    if not ActionZoneLayout.contains(field, droppedPosition) then
        return nil
    end

    local droppedLocal = ActionZoneLayout.toLocal(droppedPosition, field)
    local zone = field.actionZone or {}
    local maxX = tonumber(zone.stackDropHalfWidth) or 1.5
    local maxZ = tonumber(zone.stackDropHalfDepth) or 1.75
    local bestCardId = nil
    local bestScore = nil
    local bestHeight = nil

    for _, candidate in ipairs(candidates or {}) do
        if candidate.cardId ~= nil
            and type(candidate.position) == "table"
            and ActionZoneLayout.contains(field, candidate.position)
        then
            local candidateLocal = ActionZoneLayout.toLocal(
                candidate.position,
                field
            )
            local dx = math.abs(droppedLocal.x - candidateLocal.x)
            local dz = math.abs(droppedLocal.z - candidateLocal.z)

            if dx <= maxX and dz <= maxZ then
                local score = (dx / maxX) * (dx / maxX)
                    + (dz / maxZ) * (dz / maxZ)
                local height = tonumber(candidate.position.y) or 0

                if bestScore == nil
                    or score < bestScore
                    or (score == bestScore and height > bestHeight)
                then
                    bestCardId = candidate.cardId
                    bestScore = score
                    bestHeight = height
                end
            end
        end
    end

    return bestCardId
end

function ActionZoneLayout.getStackLayout(field, fieldState)
    local result = {}
    local stacks = type(fieldState) == "table"
        and fieldState.stacks or {}
    local snapPositions = ActionZoneLayout.getSnapPositions(
        field,
        #stacks
    )
    local zone = field.actionZone or {}
    local cardZOffset = tonumber(zone.stackCardZOffset) or -0.55
    local layerHeight = tonumber(zone.stackLayerHeight) or 0.03
    local selectedLift = tonumber(zone.selectedCardLift) or 0.4

    for stackIndex, stack in ipairs(stacks) do
        local selectedIndex = ActionZoneState.selectedIndex(stack)
        local basePosition = snapPositions[stackIndex]
        local cards = {}

        for cardIndex, cardId in ipairs(stack.cards or {}) do
            local stackOffset = ActionZoneLayout.toWorld(
                0,
                (cardIndex - 1) * cardZOffset,
                field
            )
            local position = {
                x = basePosition.x + stackOffset.x - field.position.x,
                y = basePosition.y
                    + (#stack.cards - cardIndex) * layerHeight,
                z = basePosition.z + stackOffset.z - field.position.z
            }
            local selected = cardIndex == selectedIndex

            if selected then
                position.y = basePosition.y
                    + (#stack.cards - 1) * layerHeight
                    + (#stack.cards > 1 and selectedLift or 0)
            end

            cards[#cards + 1] = {
                cardId = cardId,
                cardIndex = cardIndex,
                position = position,
                selected = selected,
                tapEnabled = selected,
                lockManaged = #stack.cards > 1,
                shouldLock = #stack.cards > 1 and not selected
            }
        end

        result[#result + 1] = {
            stack = stack,
            stackIndex = stackIndex,
            selectedIndex = selectedIndex,
            cards = cards
        }
    end

    return result
end

function ActionZoneLayout.navigationButtonPosition(position, rotated)
    if not rotated then
        return position
    end

    return {
        x = position.z,
        y = position.y,
        z = -position.x
    }
end

function ActionZoneLayout.makeNavigationButton(
    field,
    direction,
    rotated,
    functionOwner
)
    local zone = field.actionZone or {}
    local config = zone.navigationButtons or {}
    local isUp = direction < 0
    local buttonConfig = isUp and config.up or config.down

    if type(buttonConfig) ~= "table" then
        buttonConfig = {}
    end

    local position = buttonConfig.position
        or (isUp and config.topPosition or config.bottomPosition)

    if type(position) ~= "table" then
        position = {
            x = 0,
            y = 0.45,
            z = isUp and -1.35 or 1.35
        }
    end

    return {
        label = isUp and "▲" or "▼",
        click_function = isUp
            and NAVIGATE_UP_FUNCTION or NAVIGATE_DOWN_FUNCTION,
        function_owner = functionOwner,
        position = ActionZoneLayout.navigationButtonPosition(
            position,
            rotated
        ),
        rotation = rotated and {0, -90, 0} or {0, 0, 0},
        width = tonumber(buttonConfig.width or config.width) or 500,
        height = tonumber(buttonConfig.height or config.height) or 350,
        font_size = tonumber(buttonConfig.fontSize or config.fontSize) or 260,
        color = buttonConfig.color
            or config.color or {0.08, 0.08, 0.08, 0.92},
        font_color = buttonConfig.fontColor
            or config.fontColor or {1, 1, 1, 1},
        hover_color = buttonConfig.hoverColor
            or config.hoverColor or {0.2, 0.55, 0.9, 1},
        press_color = buttonConfig.pressColor
            or config.pressColor or {0.05, 0.3, 0.62, 1},
        tooltip = isUp and "Show card above" or "Show card below"
    }
end

ActionZoneLayout.NAVIGATE_UP_FUNCTION = NAVIGATE_UP_FUNCTION
ActionZoneLayout.NAVIGATE_DOWN_FUNCTION = NAVIGATE_DOWN_FUNCTION

return ActionZoneLayout

local ActionZone = {}
local pickedUpFieldByCard = {}
local statesByField = {}
local managedLocksByCard = {}
local restoredOriginalLocks = {}
local tapRotatedByCard = {}

local NAVIGATE_UP_FUNCTION = "onActionStackUpClicked"
local NAVIGATE_DOWN_FUNCTION = "onActionStackDownClicked"

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

local function fieldKey(field)
    if field == nil then
        return ""
    end

    return tostring(
        field.surfaceObjectGuid
            or field.ownerColor
            or field.playerColor
            or field
    )
end

local function getObjects(objects)
    if type(objects) == "table" then
        return objects
    end

    if type(getAllObjects) == "function" then
        return getAllObjects()
    end

    return {}
end

local function getState(field)
    local key = fieldKey(field)
    local state = statesByField[key]

    if state == nil then
        state = {stacks = {}}
        statesByField[key] = state
    end

    return state
end

local function findSelectedIndex(stack)
    for index, key in ipairs(stack.cards or {}) do
        if key == stack.selectedKey then
            return index
        end
    end

    if #(stack.cards or {}) > 0 then
        stack.selectedKey = stack.cards[1]
        return 1
    end

    stack.selectedKey = nil
    return nil
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

local function collectAvailableCards(field, objects, excludedCard)
    local cards = {}
    local cardsByKey = {}

    for _, object in ipairs(getObjects(objects)) do
        if object ~= excludedCard
            and isCard(object)
            and ActionZone.contains(field, object.getPosition())
        then
            local key = cardKey(object)
            cards[#cards + 1] = object
            cardsByKey[key] = object
        end
    end

    table.sort(cards, function(leftCard, rightCard)
        local leftPosition = rotateToLocal(leftCard.getPosition(), field)
        local rightPosition = rotateToLocal(rightCard.getPosition(), field)

        if leftPosition.x == rightPosition.x then
            if leftPosition.z == rightPosition.z then
                return cardKey(leftCard) < cardKey(rightCard)
            end

            return leftPosition.z < rightPosition.z
        end

        return leftPosition.x < rightPosition.x
    end)

    return cards, cardsByKey
end

local function reconcileState(field, objects, excludedCard)
    local state = getState(field)
    local cards, cardsByKey = collectAvailableCards(
        field,
        objects,
        excludedCard
    )
    local seen = {}
    local reconciledStacks = {}

    for _, stack in ipairs(state.stacks or {}) do
        local reconciledCards = {}

        for _, key in ipairs(stack.cards or {}) do
            if cardsByKey[key] ~= nil and not seen[key] then
                reconciledCards[#reconciledCards + 1] = key
                seen[key] = true
            end
        end

        if #reconciledCards > 0 then
            stack.cards = reconciledCards

            if not seen[stack.selectedKey] then
                stack.selectedKey = reconciledCards[1]
            end

            reconciledStacks[#reconciledStacks + 1] = stack
        end
    end

    for _, card in ipairs(cards) do
        local key = cardKey(card)

        if not seen[key] then
            reconciledStacks[#reconciledStacks + 1] = {
                cards = {key},
                selectedKey = key
            }
            seen[key] = true
        end
    end

    state.stacks = reconciledStacks

    for key, managedLock in pairs(managedLocksByCard) do
        if not seen[key]
            and managedLock.fieldKey == fieldKey(field)
            and managedLock.card ~= nil
        then
            pcall(managedLock.card.setLock, managedLock.originalLock)
            managedLocksByCard[key] = nil
            restoredOriginalLocks[key] = nil
        end
    end

    return state, cardsByKey
end

local function setManagedLock(field, card, shouldLock)
    if card == nil or type(card.setLock) ~= "function" then
        return
    end

    local key = cardKey(card)
    local managedLock = managedLocksByCard[key]

    if managedLock == nil then
        local originalLock = restoredOriginalLocks[key]

        if originalLock == nil and type(card.getLock) == "function" then
            local succeeded, currentLock = pcall(card.getLock)

            if succeeded then
                originalLock = currentLock == true
            end
        end

        managedLock = {
            card = card,
            fieldKey = fieldKey(field),
            originalLock = originalLock == true
        }
        managedLocksByCard[key] = managedLock
    else
        managedLock.card = card
        managedLock.fieldKey = fieldKey(field)
    end

    pcall(
        card.setLock,
        shouldLock and true or managedLock.originalLock
    )
end

local function releaseManagedLock(card)
    if card == nil then
        return
    end

    local key = cardKey(card)
    local managedLock = managedLocksByCard[key]

    if managedLock ~= nil and type(card.setLock) == "function" then
        pcall(card.setLock, managedLock.originalLock)
    end

    managedLocksByCard[key] = nil
    restoredOriginalLocks[key] = nil
end

local function removeNavigationButtons(card)
    if card == nil
        or type(card.getButtons) ~= "function"
        or type(card.removeButton) ~= "function"
    then
        return
    end

    local succeeded, buttons = pcall(card.getButtons)

    if not succeeded or type(buttons) ~= "table" then
        return
    end

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if button.click_function == NAVIGATE_UP_FUNCTION
            or button.click_function == NAVIGATE_DOWN_FUNCTION
        then
            pcall(card.removeButton, button.index)
        end
    end
end

local function findButton(card, clickFunction)
    if card == nil or type(card.getButtons) ~= "function" then
        return nil
    end

    local succeeded, buttons = pcall(card.getButtons)

    if not succeeded or type(buttons) ~= "table" then
        return nil
    end

    for _, button in ipairs(buttons) do
        if button.click_function == clickFunction then
            return button
        end
    end

    return nil
end

local function removeTapButton(card)
    if card == nil or type(card.removeButton) ~= "function" then
        return
    end

    local tapButton = findButton(card, "onCardTapped")

    if tapButton ~= nil then
        pcall(card.removeButton, tapButton.index)
    end
end

local function setTapEnabled(card, enabled)
    if card == nil then
        return
    end

    if type(card.call) == "function" then
        pcall(function()
            card.call("setActionZoneTapEnabled", {enabled = enabled})
        end)
    end

    if not enabled then
        removeTapButton(card)

        -- Older spawned cards do not have the tap-gate function. Their
        -- onDrop refresh runs two frames later, so clean up once more after it.
        if Wait ~= nil
            and type(Wait.frames) == "function"
        then
            Wait.frames(function()
                removeTapButton(card)
            end, 3)
        end
    elseif findButton(card, "onCardTapped") == nil
        and type(card.call) == "function"
    then
        pcall(function()
            card.call("refreshCardButtons")
        end)
    end
end

local function isCardTapRotated(card)
    local key = cardKey(card)

    if type(card.call) == "function" then
        local succeeded, rotated = pcall(function()
            return card.call("getActionZoneTapRotation")
        end)

        if succeeded and type(rotated) == "boolean" then
            tapRotatedByCard[key] = rotated
        end
    end

    return tapRotatedByCard[key] == true
end

local function navigationButtonPosition(position, rotated)
    if not rotated then
        return position
    end

    return {
        x = position.z,
        y = position.y,
        z = -position.x
    }
end

local function makeNavigationButton(field, direction, rotated)
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
        function_owner = Global,
        position = navigationButtonPosition(position, rotated),
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

local function refreshStackButtons(field, stack, cardsByKey)
    for _, key in ipairs(stack.cards) do
        removeNavigationButtons(cardsByKey[key])
    end

    local selectedIndex = findSelectedIndex(stack)
    local selectedCard = selectedIndex and cardsByKey[stack.selectedKey]

    if selectedCard == nil or type(selectedCard.createButton) ~= "function" then
        return
    end

    local rotated = isCardTapRotated(selectedCard)

    if selectedIndex > 1 then
        selectedCard.createButton(makeNavigationButton(field, -1, rotated))
    end

    if selectedIndex < #stack.cards then
        selectedCard.createButton(makeNavigationButton(field, 1, rotated))
    end
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

local function arrangeState(field, state, cardsByKey)
    local positions = ActionZone.getSnapPositions(field, #state.stacks)
    local zone = field.actionZone or {}
    local cardZOffset = tonumber(zone.stackCardZOffset) or -0.55
    local layerHeight = tonumber(zone.stackLayerHeight) or 0.03
    local selectedLift = tonumber(zone.selectedCardLift) or 0.4

    for stackIndex, stack in ipairs(state.stacks) do
        local selectedIndex = findSelectedIndex(stack)
        local basePosition = positions[stackIndex]
        local selectedCard = nil
        local selectedPosition = nil

        for cardIndex, key in ipairs(stack.cards) do
            local card = cardsByKey[key]

            if card ~= nil then
                -- Lower cards may be selected and lifted for reading, but
                -- only the first card in a slot owns its large tap target.
                setTapEnabled(card, cardIndex == 1)

                if #stack.cards > 1 then
                    -- Keeping covered cards locked prevents TTS from merging
                    -- the deliberately overlapping cards into a Deck object.
                    setManagedLock(field, card, cardIndex ~= selectedIndex)
                else
                    releaseManagedLock(card)
                end

                local stackOffset = rotateToWorld(
                    0,
                    (cardIndex - 1) * cardZOffset,
                    field
                )
                local position = {
                    x = basePosition.x
                        + stackOffset.x - field.position.x,
                    y = basePosition.y
                        + (#stack.cards - cardIndex) * layerHeight,
                    z = basePosition.z
                        + stackOffset.z - field.position.z
                }

                if cardIndex == selectedIndex then
                    selectedCard = card
                    position.y = basePosition.y
                        + (#stack.cards - 1) * layerHeight
                        + (#stack.cards > 1 and selectedLift or 0)
                    selectedPosition = position
                else
                    moveCard(card, position)
                end
            end
        end

        -- Move the selected card last so it remains visibly in front while
        -- every other card keeps its original vertical stack order.
        if selectedCard ~= nil then
            moveCard(selectedCard, selectedPosition)
        end

        refreshStackButtons(field, stack, cardsByKey)
    end

    return #state.stacks > 0
end

local function removeCardFromState(state, key)
    for stackIndex = #state.stacks, 1, -1 do
        local stack = state.stacks[stackIndex]
        local selectedIndex = findSelectedIndex(stack)

        for cardIndex = #stack.cards, 1, -1 do
            if stack.cards[cardIndex] == key then
                table.remove(stack.cards, cardIndex)

                if #stack.cards == 0 then
                    table.remove(state.stacks, stackIndex)
                elseif stack.selectedKey == key then
                    local nextIndex = math.min(selectedIndex, #stack.cards)
                    stack.selectedKey = stack.cards[nextIndex]
                end

                return true
            end
        end
    end

    return false
end

local function findStack(state, key)
    for stackIndex, stack in ipairs(state.stacks) do
        for cardIndex, cardGuid in ipairs(stack.cards) do
            if cardGuid == key then
                return stack, stackIndex, cardIndex
            end
        end
    end

    return nil, nil, nil
end

local function findDropTarget(field, droppedCard, objects)
    local droppedPosition = droppedCard.getPosition()
    local droppedLocalPosition = rotateToLocal(droppedPosition, field)
    local zone = field.actionZone or {}
    local maxX = tonumber(zone.stackDropHalfWidth) or 1.5
    local maxZ = tonumber(zone.stackDropHalfDepth) or 1.75
    local bestCard = nil
    local bestScore = nil
    local bestHeight = nil

    for _, candidate in ipairs(getObjects(objects)) do
        if candidate ~= droppedCard
            and isCard(candidate)
            and ActionZone.contains(field, candidate.getPosition())
        then
            local candidatePosition = candidate.getPosition()
            local candidateLocalPosition = rotateToLocal(
                candidatePosition,
                field
            )
            local dx = math.abs(
                droppedLocalPosition.x - candidateLocalPosition.x
            )
            local dz = math.abs(
                droppedLocalPosition.z - candidateLocalPosition.z
            )

            if dx <= maxX and dz <= maxZ then
                local score = (dx / maxX) * (dx / maxX)
                    + (dz / maxZ) * (dz / maxZ)
                local height = tonumber(candidatePosition.y) or 0

                if bestScore == nil
                    or score < bestScore
                    or (score == bestScore and height > bestHeight)
                then
                    bestCard = candidate
                    bestScore = score
                    bestHeight = height
                end
            end
        end
    end

    return bestCard
end

function ActionZone.arrange(field, preferredCard, objects, excludedCard)
    if field == nil or field.actionZone == nil then
        return false
    end

    local state, cardsByKey = reconcileState(
        field,
        objects,
        excludedCard
    )

    if excludedCard ~= nil then
        removeCardFromState(state, cardKey(excludedCard))
        removeNavigationButtons(excludedCard)
        releaseManagedLock(excludedCard)
        setTapEnabled(excludedCard, true)
    end

    if preferredCard ~= nil then
        local key = cardKey(preferredCard)
        removeCardFromState(state, key)
        state.stacks[#state.stacks + 1] = {
            cards = {key},
            selectedKey = key
        }
        cardsByKey[key] = preferredCard
    end

    return arrangeState(field, state, cardsByKey)
end

function ActionZone.refresh(fields, objects)
    local allObjects = getObjects(objects)

    for _, field in ipairs(fields or {}) do
        local state, cardsByKey = reconcileState(field, allObjects)
        arrangeState(field, state, cardsByKey)
    end
end

function ActionZone.onLoad(fields, savedState)
    pickedUpFieldByCard = {}
    statesByField = {}
    managedLocksByCard = {}
    restoredOriginalLocks = {}
    tapRotatedByCard = {}
    local savedFields = type(savedState) == "table"
        and savedState.fields or {}
    local savedOriginalLocks = type(savedState) == "table"
        and savedState.originalLocks or {}

    if type(savedOriginalLocks) == "table" then
        for key, originalLock in pairs(savedOriginalLocks) do
            restoredOriginalLocks[tostring(key)] = originalLock == true
        end
    end

    for _, field in ipairs(fields or {}) do
        local restoredState = {stacks = {}}
        local savedField = type(savedFields) == "table"
            and savedFields[fieldKey(field)] or nil

        if type(savedField) == "table"
            and type(savedField.stacks) == "table"
        then
            local restoredKeys = {}

            for _, savedStack in ipairs(savedField.stacks) do
                if type(savedStack) == "table"
                    and type(savedStack.cards) == "table"
                then
                    local restoredCards = {}

                    for _, key in ipairs(savedStack.cards) do
                        key = tostring(key)

                        if key ~= "" and not restoredKeys[key] then
                            restoredCards[#restoredCards + 1] = key
                            restoredKeys[key] = true
                        end
                    end

                    if #restoredCards > 0 then
                        local selectedIndex = math.floor(
                            tonumber(savedStack.selectedIndex) or 1
                        )
                        selectedIndex = math.max(
                            1,
                            math.min(selectedIndex, #restoredCards)
                        )
                        restoredState.stacks[#restoredState.stacks + 1] = {
                            cards = restoredCards,
                            selectedKey = restoredCards[selectedIndex]
                        }
                    end
                end
            end
        end

        statesByField[fieldKey(field)] = restoredState
    end
end

function ActionZone.getSaveState(fields)
    local savedFields = {}
    local savedOriginalLocks = {}

    for _, field in ipairs(fields or {}) do
        local state = getState(field)
        local savedStacks = {}

        for _, stack in ipairs(state.stacks) do
            if #stack.cards > 0 then
                local cards = {}

                for index, key in ipairs(stack.cards) do
                    cards[index] = key
                end

                savedStacks[#savedStacks + 1] = {
                    cards = cards,
                    selectedIndex = findSelectedIndex(stack) or 1
                }
            end
        end

        savedFields[fieldKey(field)] = {stacks = savedStacks}
    end

    for key, originalLock in pairs(restoredOriginalLocks) do
        savedOriginalLocks[key] = originalLock == true
    end

    for key, managedLock in pairs(managedLocksByCard) do
        savedOriginalLocks[key] = managedLock.originalLock == true
    end

    return {
        fields = savedFields,
        originalLocks = savedOriginalLocks
    }
end

function ActionZone.onCardLeaves(fields, object, objects)
    if not isCard(object) then
        return false
    end

    local field = ActionZone.findField(fields, object.getPosition())

    if field == nil then
        return false
    end

    local allObjects = getObjects(objects)
    local state, cardsByKey = reconcileState(field, allObjects)
    local key = cardKey(object)
    pickedUpFieldByCard[key] = nil
    removeCardFromState(state, key)
    removeNavigationButtons(object)
    releaseManagedLock(object)
    setTapEnabled(object, true)
    tapRotatedByCard[key] = nil
    cardsByKey[key] = nil
    arrangeState(field, state, cardsByKey)
    return true
end

function ActionZone.onObjectPickUp(fields, object, objects)
    if not isCard(object) then
        return false
    end

    local field = ActionZone.findField(fields, object.getPosition())
    pickedUpFieldByCard[cardKey(object)] = field

    if field ~= nil then
        reconcileState(field, objects)
        removeNavigationButtons(object)
    end

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
    local dropTarget = targetField
        and findDropTarget(targetField, object, allObjects) or nil
    pickedUpFieldByCard[key] = nil
    removeNavigationButtons(object)

    if previousField ~= nil then
        local previousState, previousCards = reconcileState(
            previousField,
            allObjects
        )
        removeCardFromState(previousState, key)

        if previousField ~= targetField then
            arrangeState(previousField, previousState, previousCards)
        end
    end

    if targetField ~= nil then
        local targetState, targetCards = reconcileState(
            targetField,
            allObjects
        )
        removeCardFromState(targetState, key)
        targetCards[key] = object

        local targetStack = dropTarget
            and findStack(targetState, cardKey(dropTarget)) or nil

        if targetStack ~= nil then
            local _, _, targetIndex = findStack(
                targetState,
                cardKey(dropTarget)
            )
            table.insert(targetStack.cards, targetIndex + 1, key)
        else
            targetState.stacks[#targetState.stacks + 1] = {
                cards = {key},
                selectedKey = key
            }
        end

        arrangeState(targetField, targetState, targetCards)
    else
        releaseManagedLock(object)
        setTapEnabled(object, true)
        tapRotatedByCard[key] = nil
    end

    return targetField ~= nil
end

function ActionZone.onStackNavigationClicked(
    fields,
    object,
    direction,
    objects
)
    if not isCard(object) then
        return false
    end

    direction = tonumber(direction)

    if direction ~= -1 and direction ~= 1 then
        return false
    end

    local field = ActionZone.findField(fields, object.getPosition())

    if field == nil then
        return false
    end

    local state, cardsByKey = reconcileState(field, objects)
    local stack, _, cardIndex = findStack(state, cardKey(object))

    if stack == nil or stack.selectedKey ~= cardKey(object) then
        return false
    end

    local nextIndex = cardIndex + direction

    if nextIndex < 1 or nextIndex > #stack.cards then
        return false
    end

    stack.selectedKey = stack.cards[nextIndex]

    local function finishNavigation()
        local currentState, currentCards = reconcileState(field, objects)
        arrangeState(field, currentState, currentCards)
    end

    -- Removing and recreating the clicked button during its own callback can
    -- invalidate TTS's dispatcher. Rebuild it on the following frame.
    if Wait ~= nil and type(Wait.frames) == "function" then
        Wait.frames(finishNavigation, 1)
    else
        finishNavigation()
    end

    return true
end

function ActionZone.onCardRotationChanged(fields, object, rotated, objects)
    if not isCard(object) then
        return false
    end

    local field = ActionZone.findField(fields, object.getPosition())

    if field == nil then
        tapRotatedByCard[cardKey(object)] = nil
        return false
    end

    tapRotatedByCard[cardKey(object)] = rotated == true
    local state, cardsByKey = reconcileState(field, objects)
    local stack = findStack(state, cardKey(object))

    if stack == nil then
        return false
    end

    refreshStackButtons(field, stack, cardsByKey)
    return true
end

return ActionZone

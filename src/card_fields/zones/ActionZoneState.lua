local ActionZoneState = {}

local function normalizeKey(value)
    if value == nil then
        return nil
    end

    local key = tostring(value)

    if key == "" then
        return nil
    end

    return key
end

local function emptyFieldState()
    return {stacks = {}}
end

function ActionZoneState.fieldId(field)
    if field == nil then
        return ""
    end

    return tostring(
        field.fieldId
            or field.surfaceObjectGuid
            or field.ownerColor
            or field.playerColor
            or field
    )
end

function ActionZoneState.cardId(card)
    if card ~= nil and type(card.getGUID) == "function" then
        return tostring(card.getGUID())
    end

    return tostring(card)
end

function ActionZoneState.ensureField(state, field)
    local fieldId = ActionZoneState.fieldId(field)
    local fieldState = state.fields[fieldId]

    if fieldState == nil then
        fieldState = emptyFieldState()
        state.fields[fieldId] = fieldState
    end

    return fieldState
end


function ActionZoneState.selectedIndex(stack)
    local cards = type(stack) == "table" and stack.cards or nil

    if type(cards) ~= "table" then
        return nil
    end

    for index, key in ipairs(cards) do
        if key == stack.selectedKey then
            return index
        end
    end

    if #cards > 0 then
        stack.selectedKey = cards[1]
        return 1
    end

    stack.selectedKey = nil
    return nil
end

function ActionZoneState.findStack(fieldState, cardId)
    if type(fieldState) ~= "table" then
        return nil, nil, nil
    end

    for stackIndex, stack in ipairs(fieldState.stacks or {}) do
        for cardIndex, currentCardId in ipairs(stack.cards or {}) do
            if currentCardId == cardId then
                return stack, stackIndex, cardIndex
            end
        end
    end

    return nil, nil, nil
end

function ActionZoneState.removeCard(fieldState, cardId)
    if type(fieldState) ~= "table" then
        return false
    end

    for stackIndex = #(fieldState.stacks or {}), 1, -1 do
        local stack = fieldState.stacks[stackIndex]
        local selectedIndex = ActionZoneState.selectedIndex(stack)

        for cardIndex = #(stack.cards or {}), 1, -1 do
            if stack.cards[cardIndex] == cardId then
                table.remove(stack.cards, cardIndex)

                if #stack.cards == 0 then
                    table.remove(fieldState.stacks, stackIndex)
                elseif stack.selectedKey == cardId then
                    local nextIndex = math.min(
                        selectedIndex or 1,
                        #stack.cards
                    )
                    stack.selectedKey = stack.cards[nextIndex]
                end

                return true
            end
        end
    end

    return false
end

function ActionZoneState.addStack(fieldState, cardId)
    fieldState.stacks = fieldState.stacks or {}
    fieldState.stacks[#fieldState.stacks + 1] = {
        cards = {cardId},
        selectedKey = cardId
    }
    return fieldState.stacks[#fieldState.stacks]
end

function ActionZoneState.reconcile(fieldState, availableCardIds)
    fieldState.stacks = fieldState.stacks or {}
    local available = {}
    local orderedAvailable = {}

    for _, value in ipairs(availableCardIds or {}) do
        local cardId = normalizeKey(value)

        if cardId ~= nil and not available[cardId] then
            available[cardId] = true
            orderedAvailable[#orderedAvailable + 1] = cardId
        end
    end

    local seen = {}
    local reconciledStacks = {}

    for _, stack in ipairs(fieldState.stacks) do
        local reconciledCards = {}

        for _, value in ipairs(stack.cards or {}) do
            local cardId = normalizeKey(value)

            if cardId ~= nil
                and available[cardId]
                and not seen[cardId]
            then
                reconciledCards[#reconciledCards + 1] = cardId
                seen[cardId] = true
            end
        end

        if #reconciledCards > 0 then
            local selectedKey = normalizeKey(stack.selectedKey)
            stack.cards = reconciledCards

            if selectedKey == nil or not seen[selectedKey] then
                stack.selectedKey = reconciledCards[1]
            else
                local selectedIsInStack = false

                for _, cardId in ipairs(reconciledCards) do
                    if cardId == selectedKey then
                        selectedIsInStack = true
                        break
                    end
                end

                stack.selectedKey = selectedIsInStack
                    and selectedKey or reconciledCards[1]
            end

            reconciledStacks[#reconciledStacks + 1] = stack
        end
    end

    for _, cardId in ipairs(orderedAvailable) do
        if not seen[cardId] then
            reconciledStacks[#reconciledStacks + 1] = {
                cards = {cardId},
                selectedKey = cardId
            }
            seen[cardId] = true
        end
    end

    fieldState.stacks = reconciledStacks
    return seen
end

function ActionZoneState.load(fields, savedState)
    local state = {
        fields = {},
        originalLocks = {}
    }
    local savedFields = type(savedState) == "table"
        and savedState.fields or {}
    local savedOriginalLocks = type(savedState) == "table"
        and savedState.originalLocks or {}

    if type(savedOriginalLocks) == "table" then
        for key, originalLock in pairs(savedOriginalLocks) do
            state.originalLocks[tostring(key)] = originalLock == true
        end
    end

    for _, field in ipairs(fields or {}) do
        local fieldId = ActionZoneState.fieldId(field)
        local restoredState = emptyFieldState()
        local savedField = type(savedFields) == "table"
            and savedFields[fieldId] or nil

        if type(savedField) == "table"
            and type(savedField.stacks) == "table"
        then
            local restoredCardIds = {}

            for _, savedStack in ipairs(savedField.stacks) do
                if type(savedStack) == "table"
                    and type(savedStack.cards) == "table"
                then
                    local restoredCards = {}

                    for _, value in ipairs(savedStack.cards) do
                        local cardId = normalizeKey(value)

                        if cardId ~= nil and not restoredCardIds[cardId] then
                            restoredCards[#restoredCards + 1] = cardId
                            restoredCardIds[cardId] = true
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

        state.fields[fieldId] = restoredState
    end

    return state
end

function ActionZoneState.new(fields, savedState)
    return ActionZoneState.load(fields, savedState)
end

function ActionZoneState.save(state, fields, additionalOriginalLocks)
    state = type(state) == "table" and state or {
        fields = {},
        originalLocks = {}
    }
    local savedFields = {}
    local savedOriginalLocks = {}

    for _, field in ipairs(fields or {}) do
        local fieldState = ActionZoneState.ensureField(state, field)
        local savedStacks = {}

        for _, stack in ipairs(fieldState.stacks or {}) do
            if #(stack.cards or {}) > 0 then
                local cards = {}

                for index, cardId in ipairs(stack.cards) do
                    cards[index] = cardId
                end

                savedStacks[#savedStacks + 1] = {
                    cards = cards,
                    selectedIndex = ActionZoneState.selectedIndex(stack) or 1
                }
            end
        end

        savedFields[ActionZoneState.fieldId(field)] = {
            stacks = savedStacks
        }
    end

    for key, originalLock in pairs(state.originalLocks or {}) do
        savedOriginalLocks[tostring(key)] = originalLock == true
    end

    for key, originalLock in pairs(additionalOriginalLocks or {}) do
        savedOriginalLocks[tostring(key)] = originalLock == true
    end

    return {
        fields = savedFields,
        originalLocks = savedOriginalLocks
    }
end

return ActionZoneState

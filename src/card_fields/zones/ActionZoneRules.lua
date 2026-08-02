local ActionZoneState = require("src/card_fields/zones/ActionZoneState")

local ActionZoneRules = {}

function ActionZoneRules.reconcile(fieldState, availableCardIds)
    local seen = ActionZoneState.reconcile(fieldState, availableCardIds)
    return fieldState, {
        {type = "arrange", seenCardIds = seen}
    }
end

function ActionZoneRules.remove(fieldState, cardId)
    local removed = ActionZoneState.removeCard(fieldState, cardId)
    local effects = {}

    if removed then
        effects[1] = {type = "arrange"}
    end

    return fieldState, effects, removed
end

function ActionZoneRules.drop(fieldState, cardId, targetCardId)
    ActionZoneState.removeCard(fieldState, cardId)
    local targetStack = targetCardId
        and ActionZoneState.findStack(fieldState, targetCardId) or nil

    if targetStack ~= nil then
        local _, _, targetIndex = ActionZoneState.findStack(
            fieldState,
            targetCardId
        )
        table.insert(targetStack.cards, targetIndex + 1, cardId)
    else
        ActionZoneState.addStack(fieldState, cardId)
    end

    return fieldState, {
        {
            type = "arrange",
            cardId = cardId,
            targetCardId = targetCardId
        }
    }
end

function ActionZoneRules.prefer(fieldState, cardId)
    ActionZoneState.removeCard(fieldState, cardId)
    ActionZoneState.addStack(fieldState, cardId)
    return fieldState, {
        {type = "arrange", cardId = cardId}
    }
end

function ActionZoneRules.navigate(fieldState, cardId, direction)
    direction = tonumber(direction)

    if direction ~= -1 and direction ~= 1 then
        return fieldState, {}, false
    end

    local stack, _, cardIndex = ActionZoneState.findStack(
        fieldState,
        cardId
    )

    if stack == nil or stack.selectedKey ~= cardId then
        return fieldState, {}, false
    end

    local nextIndex = cardIndex + direction

    if nextIndex < 1 or nextIndex > #stack.cards then
        return fieldState, {}, false
    end

    stack.selectedKey = stack.cards[nextIndex]
    return fieldState, {
        {
            type = "selectionChanged",
            previousCardId = cardId,
            selectedCardId = stack.selectedKey
        },
        {type = "arrange"}
    }, true
end

function ActionZoneRules.handle(fieldState, event)
    if type(event) ~= "table" then
        return fieldState, {}, false
    end

    if event.type == "reconcile" then
        local nextState, effects = ActionZoneRules.reconcile(
            fieldState,
            event.availableCardIds
        )
        return nextState, effects, true
    elseif event.type == "drop" then
        local nextState, effects = ActionZoneRules.drop(
            fieldState,
            event.cardId,
            event.targetCardId
        )
        return nextState, effects, true
    elseif event.type == "remove" then
        return ActionZoneRules.remove(fieldState, event.cardId)
    elseif event.type == "navigate" then
        return ActionZoneRules.navigate(
            fieldState,
            event.cardId,
            event.direction
        )
    end

    return fieldState, {}, false
end

return ActionZoneRules

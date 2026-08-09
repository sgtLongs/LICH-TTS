local ActionZoneLayout = require("src/card_fields/zones/ActionZoneLayout")
local ActionZoneRules = require("src/card_fields/zones/ActionZoneRules")
local ActionZoneState = require("src/card_fields/zones/ActionZoneState")
local ObjectAdapter = require("src/tts/ObjectAdapter")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")

local ActionZoneController = {}
ActionZoneController.__index = ActionZoneController

local function isCard(object)
    return object ~= nil
        and object.tag == "Card"
        and type(object.getPosition) == "function"
end

function ActionZoneController.new(dependencies)
    dependencies = dependencies or {}
    local defaultRuntime = Runtime.default()
    local defaultScheduler = Scheduler.default()
    local runtime = dependencies.runtime or defaultRuntime
    local scheduler = dependencies.scheduler or defaultScheduler
    local controller = setmetatable({}, ActionZoneController)
    controller.getAllObjects = dependencies.getAllObjects
        or runtime.getAllObjects
        or defaultRuntime.getAllObjects
    controller.scheduleFrames = dependencies.scheduleFrames
        or scheduler.frames
        or defaultScheduler.frames
    controller.getGlobalOwner = dependencies.getGlobalOwner
        or runtime.getGlobalOwner
        or defaultRuntime.getGlobalOwner
    controller.objectAdapter = dependencies.objectAdapter or ObjectAdapter
    controller.state = ActionZoneState.new({}, nil)
    controller.pickedUpFieldByCard = {}
    controller.managedLocksByCard = {}
    controller.tapRotatedByCard = {}
    return controller
end

function ActionZoneController:getObjects(objects)
    if type(objects) == "table" then
        return objects
    end

    local allObjects = self.getAllObjects()
    return type(allObjects) == "table" and allObjects or {}
end

function ActionZoneController:getFieldState(field)
    return ActionZoneState.ensureField(self.state, field)
end

function ActionZoneController:findFieldById(fields, fieldId, fallback)
    for _, field in ipairs(fields or {}) do
        if ActionZoneState.fieldId(field) == fieldId then
            return field
        end
    end

    return fallback
end

function ActionZoneController:collectAvailableCards(
    field,
    objects,
    excludedCard
)
    local cards = {}
    local cardsById = {}

    for _, object in ipairs(self:getObjects(objects)) do
        if object ~= excludedCard
            and isCard(object)
            and ActionZoneLayout.contains(field, object.getPosition())
        then
            local cardId = ActionZoneState.cardId(object)
            cards[#cards + 1] = object
            cardsById[cardId] = object
        end
    end

    table.sort(cards, function(leftCard, rightCard)
        return ActionZoneLayout.comparePositions(field, {
            cardId = ActionZoneState.cardId(leftCard),
            position = leftCard.getPosition()
        }, {
            cardId = ActionZoneState.cardId(rightCard),
            position = rightCard.getPosition()
        })
    end)

    return cards, cardsById
end

function ActionZoneController:reconcile(field, objects, excludedCard)
    local fieldState = self:getFieldState(field)
    local cards, cardsById = self:collectAvailableCards(
        field,
        objects,
        excludedCard
    )
    local orderedCardIds = {}

    for index, card in ipairs(cards) do
        orderedCardIds[index] = ActionZoneState.cardId(card)
    end

    local _, effects = ActionZoneRules.reconcile(
        fieldState,
        orderedCardIds
    )
    local seen = effects[1].seenCardIds
    local fieldId = ActionZoneState.fieldId(field)

    for cardId, managedLock in pairs(self.managedLocksByCard) do
        if not seen[cardId]
            and managedLock.fieldId == fieldId
            and managedLock.card ~= nil
        then
            pcall(managedLock.card.setLock, managedLock.originalLock)
            self.managedLocksByCard[cardId] = nil
            self.state.originalLocks[cardId] = nil
        end
    end

    return fieldState, cardsById
end

function ActionZoneController:setManagedLock(field, card, shouldLock)
    if card == nil or type(card.setLock) ~= "function" then
        return
    end

    local cardId = ActionZoneState.cardId(card)
    local managedLock = self.managedLocksByCard[cardId]

    if managedLock == nil then
        local originalLock = self.state.originalLocks[cardId]

        if originalLock == nil and type(card.getLock) == "function" then
            local succeeded, currentLock = pcall(card.getLock)

            if succeeded then
                originalLock = currentLock == true
            end
        end

        managedLock = {
            card = card,
            fieldId = ActionZoneState.fieldId(field),
            originalLock = originalLock == true
        }
        self.managedLocksByCard[cardId] = managedLock
        self.state.originalLocks[cardId] = managedLock.originalLock
    else
        managedLock.card = card
        managedLock.fieldId = ActionZoneState.fieldId(field)
    end

    pcall(
        card.setLock,
        shouldLock and true or managedLock.originalLock
    )
end

function ActionZoneController:releaseManagedLock(card)
    if card == nil then
        return
    end

    local cardId = ActionZoneState.cardId(card)
    local managedLock = self.managedLocksByCard[cardId]

    if managedLock ~= nil and type(card.setLock) == "function" then
        pcall(card.setLock, managedLock.originalLock)
    end

    self.managedLocksByCard[cardId] = nil
    self.state.originalLocks[cardId] = nil
end

function ActionZoneController:removeNavigationButtons(card)
    if card == nil then
        return
    end

    local buttons = self.objectAdapter.getButtons(card)

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if button.click_function == ActionZoneLayout.NAVIGATE_UP_FUNCTION
            or button.click_function
                == ActionZoneLayout.NAVIGATE_DOWN_FUNCTION
        then
            self.objectAdapter.removeButton(card, button.index)
        end
    end
end

function ActionZoneController:findButton(card, clickFunction)
    if card == nil then
        return nil
    end

    local buttons = self.objectAdapter.getButtons(card)

    for _, button in ipairs(buttons) do
        if button.click_function == clickFunction then
            return button
        end
    end

    return nil
end

function ActionZoneController:removeTapButton(card)
    if card == nil then
        return
    end

    local tapButton = self:findButton(card, "onCardTapped")

    if tapButton ~= nil then
        self.objectAdapter.removeButton(card, tapButton.index)
    end
end

function ActionZoneController:setTapEnabled(card, enabled, context)
    if card == nil then
        return
    end

    if type(card.call) == "function" then
        pcall(function()
            card.call("setActionZoneTapEnabled", {
                enabled = enabled,
                preserveCardPreview = type(context) == "table"
                    and context.preserveCardPreview == true
            })
        end)
    end

    if not enabled then
        self:removeTapButton(card)

        -- Older cards refresh their buttons two frames after onDrop. Repeat
        -- the cleanup after that callback without exposing Wait to the rules.
        self.scheduleFrames(function()
            self:removeTapButton(card)
        end, 3)
    elseif self:findButton(card, "onCardTapped") == nil
        and type(card.call) == "function"
    then
        pcall(function()
            card.call("refreshCardButtons")
        end)
    end
end

function ActionZoneController:isCardTapRotated(card)
    local cardId = ActionZoneState.cardId(card)

    if type(card.call) == "function" then
        local succeeded, rotated = pcall(function()
            return card.call("getActionZoneTapRotation")
        end)

        if succeeded and type(rotated) == "boolean" then
            self.tapRotatedByCard[cardId] = rotated
        end
    end

    return self.tapRotatedByCard[cardId] == true
end

function ActionZoneController:refreshStackButtons(field, stack, cardsById)
    for _, cardId in ipairs(stack.cards or {}) do
        self:removeNavigationButtons(cardsById[cardId])
    end

    local selectedIndex = ActionZoneState.selectedIndex(stack)
    local selectedCard = selectedIndex and cardsById[stack.selectedKey]

    if selectedCard == nil
        or type(selectedCard.createButton) ~= "function"
    then
        return
    end

    local rotated = self:isCardTapRotated(selectedCard)
    local functionOwner = self.getGlobalOwner()

    if selectedIndex > 1 then
        self.objectAdapter.createButton(
            selectedCard,
            ActionZoneLayout.makeNavigationButton(
            field,
            -1,
            rotated,
            functionOwner
        ))
    end

    if selectedIndex < #stack.cards then
        self.objectAdapter.createButton(
            selectedCard,
            ActionZoneLayout.makeNavigationButton(
            field,
            1,
            rotated,
            functionOwner
        ))
    end
end

function ActionZoneController:moveCard(card, position)
    if type(card.setVelocity) == "function" then
        card.setVelocity({0, 0, 0})
    end

    if type(card.setAngularVelocity) == "function" then
        card.setAngularVelocity({0, 0, 0})
    end

    self.objectAdapter.moveSmooth(card, position, false, true)
end

function ActionZoneController:arrangeState(
    field,
    fieldState,
    cardsById,
    context
)
    local stackLayouts = ActionZoneLayout.getStackLayout(
        field,
        fieldState
    )

    for _, stackLayout in ipairs(stackLayouts) do
        local selectedCard = nil
        local selectedPosition = nil

        for _, cardLayout in ipairs(stackLayout.cards) do
            local card = cardsById[cardLayout.cardId]

            if card ~= nil then
                -- The selected card owns the action trigger before a preview
                -- treats the full stack as one lifted UI target.
                self:setTapEnabled(card, cardLayout.tapEnabled, context)

                if cardLayout.lockManaged then
                    self:setManagedLock(
                        field,
                        card,
                        cardLayout.shouldLock
                    )
                else
                    self:releaseManagedLock(card)
                end

                if cardLayout.selected then
                    selectedCard = card
                    selectedPosition = cardLayout.position
                else
                    self:moveCard(card, cardLayout.position)
                end
            end
        end

        -- Moving the selected card last keeps it visibly in front while the
        -- stable card order continues to own every fan position.
        if selectedCard ~= nil then
            self:moveCard(selectedCard, selectedPosition)
        end

        self:refreshStackButtons(
            field,
            stackLayout.stack,
            cardsById
        )
    end

    return #stackLayouts > 0
end

function ActionZoneController:findDropTarget(field, droppedCard, objects)
    local candidates = {}

    for _, candidate in ipairs(self:getObjects(objects)) do
        if candidate ~= droppedCard
            and isCard(candidate)
            and ActionZoneLayout.contains(field, candidate.getPosition())
        then
            candidates[#candidates + 1] = {
                cardId = ActionZoneState.cardId(candidate),
                position = candidate.getPosition()
            }
        end
    end

    return ActionZoneLayout.findDropTarget(
        field,
        droppedCard.getPosition(),
        candidates
    )
end

function ActionZoneController:contains(field, position)
    return ActionZoneLayout.contains(field, position)
end

function ActionZoneController:findField(fields, position)
    return ActionZoneLayout.findField(fields, position)
end

function ActionZoneController:getSnapPositions(field, cardCount)
    return ActionZoneLayout.getSnapPositions(field, cardCount)
end

function ActionZoneController:arrange(
    field,
    preferredCard,
    objects,
    excludedCard
)
    if field == nil or field.actionZone == nil then
        return false
    end

    local fieldState, cardsById = self:reconcile(
        field,
        objects,
        excludedCard
    )

    if excludedCard ~= nil then
        local excludedCardId = ActionZoneState.cardId(excludedCard)
        ActionZoneRules.remove(fieldState, excludedCardId)
        self:removeNavigationButtons(excludedCard)
        self:releaseManagedLock(excludedCard)
        self:setTapEnabled(excludedCard, true)
    end

    if preferredCard ~= nil then
        local preferredCardId = ActionZoneState.cardId(preferredCard)
        ActionZoneRules.prefer(fieldState, preferredCardId)
        cardsById[preferredCardId] = preferredCard
    end

    return self:arrangeState(field, fieldState, cardsById)
end

function ActionZoneController:refresh(fields, objects)
    local allObjects = self:getObjects(objects)

    for _, field in ipairs(fields or {}) do
        local fieldState, cardsById = self:reconcile(field, allObjects)
        self:arrangeState(field, fieldState, cardsById)
    end
end

function ActionZoneController:onLoad(fields, savedState)
    self.state = ActionZoneState.load(fields, savedState)
    self.pickedUpFieldByCard = {}
    self.managedLocksByCard = {}
    self.tapRotatedByCard = {}
end

function ActionZoneController:getSaveState(fields)
    local managedOriginalLocks = {}

    for cardId, managedLock in pairs(self.managedLocksByCard) do
        managedOriginalLocks[cardId] = managedLock.originalLock == true
    end

    return ActionZoneState.save(
        self.state,
        fields,
        managedOriginalLocks
    )
end

function ActionZoneController:onCardLeaves(fields, object, objects)
    if not isCard(object) then
        return false
    end

    local field = self:findField(fields, object.getPosition())

    if field == nil then
        return false
    end

    local allObjects = self:getObjects(objects)
    local fieldState, cardsById = self:reconcile(field, allObjects)
    local cardId = ActionZoneState.cardId(object)
    self.pickedUpFieldByCard[cardId] = nil
    ActionZoneRules.remove(fieldState, cardId)
    self:removeNavigationButtons(object)
    self:releaseManagedLock(object)
    self:setTapEnabled(object, true)
    self.tapRotatedByCard[cardId] = nil
    cardsById[cardId] = nil
    self:arrangeState(field, fieldState, cardsById)
    return true
end

function ActionZoneController:onObjectPickUp(fields, object, objects)
    if not isCard(object) then
        return false
    end

    local field = self:findField(fields, object.getPosition())
    local cardId = ActionZoneState.cardId(object)

    if field ~= nil then
        self.pickedUpFieldByCard[cardId] = {
            fieldId = ActionZoneState.fieldId(field),
            field = field
        }
        self:reconcile(field, objects)
        self:removeNavigationButtons(object)
    else
        self.pickedUpFieldByCard[cardId] = nil
    end

    return field ~= nil
end

function ActionZoneController:onObjectDrop(fields, object, objects)
    if not isCard(object) then
        return false
    end

    local cardId = ActionZoneState.cardId(object)
    local pickedUpField = self.pickedUpFieldByCard[cardId]
    local previousField = pickedUpField and self:findFieldById(
        fields,
        pickedUpField.fieldId,
        pickedUpField.field
    ) or nil
    local targetField = self:findField(fields, object.getPosition())
    local allObjects = self:getObjects(objects)
    local dropTargetCardId = targetField
        and self:findDropTarget(targetField, object, allObjects) or nil
    self.pickedUpFieldByCard[cardId] = nil
    self:removeNavigationButtons(object)

    if previousField ~= nil then
        local previousState, previousCards = self:reconcile(
            previousField,
            allObjects
        )
        ActionZoneRules.remove(previousState, cardId)

        if ActionZoneState.fieldId(previousField)
            ~= ActionZoneState.fieldId(targetField)
        then
            self:arrangeState(
                previousField,
                previousState,
                previousCards
            )
        end
    end

    if targetField ~= nil then
        local targetState, targetCards = self:reconcile(
            targetField,
            allObjects
        )
        targetCards[cardId] = object
        ActionZoneRules.drop(
            targetState,
            cardId,
            dropTargetCardId
        )
        self:arrangeState(targetField, targetState, targetCards)
    else
        self:releaseManagedLock(object)
        self:setTapEnabled(object, true)
        self.tapRotatedByCard[cardId] = nil
    end

    return targetField ~= nil
end

function ActionZoneController:navigateStack(
    fields,
    object,
    direction,
    objects,
    context
)
    if not isCard(object) then
        return false
    end

    direction = tonumber(direction)

    if direction ~= -1 and direction ~= 1 then
        return false
    end

    local field = self:findField(fields, object.getPosition())

    if field == nil then
        return false
    end

    local fieldState, cardsById = self:reconcile(field, objects)
    local _, _, handled = ActionZoneRules.navigate(
        fieldState,
        ActionZoneState.cardId(object),
        direction
    )

    if not handled then
        return false
    end

    local function finishNavigation()
        local currentState, currentCards = self:reconcile(field, objects)
        self:arrangeState(field, currentState, currentCards, context)
    end

    -- Removing a button during its own callback can invalidate TTS's
    -- dispatcher, so its controller effects run on the following frame.
    if not self.scheduleFrames(finishNavigation, 1) then
        finishNavigation()
    end

    local selectedStack = ActionZoneState.findStack(
        fieldState,
        ActionZoneState.cardId(object)
    )
    return selectedStack ~= nil
        and cardsById[selectedStack.selectedKey] or true
end

-- Compatibility entry point for physical buttons and older callers. New
-- preview-aware code should call navigateStack with an explicit context.
function ActionZoneController:onStackNavigationClicked(
    fields,
    object,
    direction,
    objects,
    context
)
    return self:navigateStack(
        fields,
        object,
        direction,
        objects,
        context
    )
end

function ActionZoneController:getStackCards(fields, object, objects)
    if not isCard(object) then
        return nil, nil
    end

    local field = self:findField(fields, object.getPosition())

    if field == nil then
        return nil, nil
    end

    local fieldState, cardsById = self:reconcile(field, objects)
    local stack = ActionZoneState.findStack(
        fieldState,
        ActionZoneState.cardId(object)
    )

    if stack == nil then
        return nil, nil
    end

    local cards = {}

    for _, cardId in ipairs(stack.cards or {}) do
        if cardsById[cardId] ~= nil then
            cards[#cards + 1] = cardsById[cardId]
        end
    end

    return cards, ActionZoneState.selectedIndex(stack)
end

function ActionZoneController:onCardRotationChanged(
    fields,
    object,
    rotated,
    objects
)
    if not isCard(object) then
        return false
    end

    local cardId = ActionZoneState.cardId(object)
    local field = self:findField(fields, object.getPosition())

    if field == nil then
        self.tapRotatedByCard[cardId] = nil
        return false
    end

    self.tapRotatedByCard[cardId] = rotated == true
    local fieldState, cardsById = self:reconcile(field, objects)
    local stack = ActionZoneState.findStack(fieldState, cardId)

    if stack == nil then
        return false
    end

    self:refreshStackButtons(field, stack, cardsById)
    return true
end

function ActionZoneController:getInternalState()
    return self.state
end

function ActionZoneController:asBehavior()
    local controller = self

    return {
        saveKey = "actionZone",
        contains = function(field, position)
            return controller:contains(field, position)
        end,
        onLoad = function(fields, savedState)
            return controller:onLoad(fields, savedState)
        end,
        getSaveState = function(fields)
            return controller:getSaveState(fields)
        end,
        refresh = function(fields, objects)
            return controller:refresh(fields, objects)
        end,
        onObjectPickUp = function(fields, object, objects)
            return controller:onObjectPickUp(fields, object, objects)
        end,
        onObjectDrop = function(fields, object, objects)
            return controller:onObjectDrop(fields, object, objects)
        end,
        onCardLeaves = function(fields, object, objects)
            return controller:onCardLeaves(fields, object, objects)
        end,
        navigateStack = function(
            fields,
            object,
            direction,
            context
        )
            return controller:navigateStack(
                fields,
                object,
                direction,
                nil,
                context
            )
        end,
        getStackCards = function(fields, object, objects)
            return controller:getStackCards(fields, object, objects)
        end,
        onCardRotationChanged = function(
            fields,
            object,
            rotated,
            objects
        )
            return controller:onCardRotationChanged(
                fields,
                object,
                rotated,
                objects
            )
        end
    }
end

return ActionZoneController

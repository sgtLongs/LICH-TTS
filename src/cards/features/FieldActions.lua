return {
    -- This ID is persisted in LuaScriptState by cards generated before the
    -- extraction. Keep it stable even though the module has the clearer
    -- mechanic name `FieldActions`.
    id = "destroyToPurgatory",
    stateVersion = 1,
    enabledByDefault = true,
    usesButtons = true,
    hostButtons = {
        {
            callback = "onActionsClicked",
            configKey = "actions",
            sizeSource = "button"
        },
        {
            callback = "onDestroyCardClicked",
            configKey = "destroy",
            sizeSource = "actionList"
        },
        {
            callback = "onDamnCardClicked",
            configKey = "damn",
            sizeSource = "actionList"
        },
        {
            callback = "onUnequipCardClicked",
            configKey = "unequip",
            sizeSource = "actionList"
        },
        {
            callback = "onReturnCardClicked",
            configKey = "returnToHand",
            sizeSource = "actionList"
        },
        {
            callback = "onActionButtonAreaClicked",
            removeOnRefresh = true
        }
    },
    source = [=[
local actionButtonsVisible = false
local returnToHandInProgress = false
local actionButtonFunctions = {
    onDestroyCardClicked = true,
    onDamnCardClicked = true,
    onUnequipCardClicked = true,
    onReturnCardClicked = true,
    onActionButtonAreaClicked = true
}

local function findCardButton(clickFunction)
    for _, button in ipairs(self.getButtons() or {}) do
        if button.click_function == clickFunction then
            return button
        end
    end

    return nil
end

local function removeActionButtons()
    local buttons = self.getButtons() or {}

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if actionButtonFunctions[button.click_function] then
            self.removeButton(button.index)
        end
    end

    actionButtonsVisible = false
end

local function isCardTapRotated()
    local rotateState = cardState.features.rotate90
    return type(rotateState) == "table"
        and rotateState.rotated == true
end

local function resetCardTapRotation()
    local rotateState = cardState.features.rotate90

    if type(rotateState) ~= "table" or rotateState.rotated ~= true then
        return
    end

    rotateState.rotated = false

    if type(self.getRotation) == "function"
        and type(self.setRotation) == "function"
    then
        local rotation = self.getRotation()
        self.setRotation({
            x = rotation.x,
            y = rotation.y - 90,
            z = rotation.z
        })
    elseif type(self.rotate) == "function" then
        self.rotate({x = 0, y = -90, z = 0})
    end
end

local function actionButtonPosition(position)
    if not isCardTapRotated() then
        return position
    end

    -- Counter-rotate the local offset so the card's 90-degree rotation
    -- leaves the button in the same world-facing layout.
    return {
        x = position.z,
        y = position.y,
        z = -position.x
    }
end

local function actionButtonRotation()
    return isCardTapRotated() and {0, -90, 0} or {0, 0, 0}
end

local function makeActionButton(
    label,
    clickFunction,
    position,
    width,
    height,
    color,
    hoverColor,
    pressColor,
    tooltip
)
    return {
        label = label,
        click_function = clickFunction,
        function_owner = self,
        position = actionButtonPosition(position),
        rotation = actionButtonRotation(),
        width = width,
        height = height,
        font_size = 180,
        color = color,
        font_color = {1, 1, 1, 1},
        hover_color = hoverColor,
        press_color = pressColor,
        tooltip = tooltip
    }
end

local function showActionButtons()
    if cardButtonsSuppressed
        or isCardInHand()
        or not actionZoneTapEnabled
    then
        return
    end

    if actionButtonsVisible
        and findCardButton("onDestroyCardClicked") ~= nil
    then
        return
    end

    self.createButton(makeActionButton(
        "destroy", "onDestroyCardClicked",
        cardContext.destroyButtonPosition,
        cardContext.destroyButtonWidth,
        cardContext.destroyButtonHeight,
        {0.65, 0.08, 0.08, 0.95},
        {0.9, 0.12, 0.12, 1},
        {0.45, 0.03, 0.03, 1},
        "Move to purgatory"
    ))
    self.createButton(makeActionButton(
        "damn", "onDamnCardClicked",
        cardContext.damnButtonPosition,
        cardContext.damnButtonWidth,
        cardContext.damnButtonHeight,
        {0.25, 0.06, 0.38, 0.95},
        {0.42, 0.1, 0.62, 1},
        {0.16, 0.03, 0.25, 1},
        "Move to abyss"
    ))
    self.createButton(makeActionButton(
        "unequip", "onUnequipCardClicked",
        cardContext.unequipButtonPosition,
        cardContext.unequipButtonWidth,
        cardContext.unequipButtonHeight,
        {0.5, 0.3, 0.05, 0.95},
        {0.75, 0.48, 0.1, 1},
        {0.32, 0.18, 0.02, 1},
        "Return to bottom of deck"
    ))
    self.createButton(makeActionButton(
        "return", "onReturnCardClicked",
        cardContext.returnToHandButtonPosition,
        cardContext.returnToHandButtonWidth,
        cardContext.returnToHandButtonHeight,
        {0.05, 0.35, 0.58, 0.95},
        {0.08, 0.55, 0.85, 1},
        {0.02, 0.22, 0.38, 1},
        "Return to hand"
    ))
    actionButtonsVisible = true
end

local function makeActionsButton()
    return makeActionButton(
        "actions", "onActionsClicked",
        cardContext.actionsButtonPosition,
        cardContext.actionsButtonWidth,
        cardContext.actionsButtonHeight,
        {0.08, 0.32, 0.5, 0.95},
        {0.12, 0.5, 0.72, 1},
        {0.04, 0.2, 0.34, 1},
        "Show or hide card actions"
    )
end

function onActionsClicked(object, playerColor, altClick)
    if object ~= self
        or not isSingleCard()
        or not actionZoneTapEnabled
    then
        return
    end

    if actionButtonsVisible then
        removeActionButtons()
    else
        showActionButtons()
    end
end

function hideActionButtonsDuringCardRotation()
    local shouldRestore = actionButtonsVisible
    removeActionButtons()

    if not shouldRestore then
        return
    end

    local function restoreAfterRotation()
        Wait.condition(
            function()
                if not isCardInHand() then
                    showActionButtons()
                end
            end,
            function()
                return not self.isSmoothMoving()
            end
        )
    end

    -- rotate() begins smooth movement after this callback returns, so wait
    -- one frame before watching for its completion.
    Wait.frames(restoreAfterRotation, 1)
end

function refreshCardActionButtons()
    local actionsButton = findCardButton("onActionsClicked")

    if cardButtonsSuppressed
        or isCardInHand()
        or not actionZoneTapEnabled
    then
        removeActionButtons()

        if actionsButton ~= nil then
            self.removeButton(actionsButton.index)
        end

        return
    end

    local actionsParameters = makeActionsButton()

    if actionsButton == nil then
        self.createButton(actionsParameters)
    else
        actionsParameters.index = actionsButton.index
        self.editButton(actionsParameters)
    end

    if actionButtonsVisible
        and findCardButton("onDestroyCardClicked") == nil
    then
        actionButtonsVisible = false
        showActionButtons()
    end

    if not actionButtonsVisible then
        return
    end

    local configByFunction = {
        onDestroyCardClicked = {
            cardContext.destroyButtonPosition,
            cardContext.destroyButtonWidth,
            cardContext.destroyButtonHeight
        },
        onDamnCardClicked = {
            cardContext.damnButtonPosition,
            cardContext.damnButtonWidth,
            cardContext.damnButtonHeight
        },
        onUnequipCardClicked = {
            cardContext.unequipButtonPosition,
            cardContext.unequipButtonWidth,
            cardContext.unequipButtonHeight
        },
        onReturnCardClicked = {
            cardContext.returnToHandButtonPosition,
            cardContext.returnToHandButtonWidth,
            cardContext.returnToHandButtonHeight
        }
    }

    for _, button in ipairs(self.getButtons() or {}) do
        local config = configByFunction[button.click_function]

        if config ~= nil then
            self.editButton({
                index = button.index,
                position = actionButtonPosition(config[1]),
                rotation = actionButtonRotation(),
                width = config[2],
                height = config[3]
            })
        end
    end
end

local function notifyActionZoneCardLeaving()
    if Global ~= nil and type(Global.call) == "function" then
        pcall(
            Global.call,
            "onCardLeavesActionZone",
            {card = self}
        )
    end
end

local function resolveFieldDestination(destinationName, fallback)
    if type(cardContext.fieldId) ~= "string"
        or cardContext.fieldId == ""
        or Global == nil
        or type(Global.getVar) ~= "function"
        or type(Global.call) ~= "function"
    then
        return fallback
    end

    local found, resolver = pcall(
        Global.getVar,
        "getCardFieldDestination"
    )

    if not found or type(resolver) ~= "function" then
        return fallback
    end

    local resolved, destination = pcall(
        Global.call,
        "getCardFieldDestination",
        {
            fieldId = cardContext.fieldId,
            destination = destinationName
        }
    )

    if resolved and type(destination) == "table" then
        return destination
    end

    return fallback
end

local function normalizeCardBeforeHand()
    cardButtonsSuppressed = true
    removeAllCardButtons()

    if type(self.setLock) == "function" then
        self.setLock(false)
    end

    self.use_hands = true

    if type(self.setScale) == "function" then
        self.setScale(cardContext.cardScale or {x = 1, y = 1, z = 1})
    end

    if type(self.setVelocity) == "function" then
        self.setVelocity({0, 0, 0})
    end

    if type(self.setAngularVelocity) == "function" then
        self.setAngularVelocity({0, 0, 0})
    end
end

local function moveCardTo(destination, missingMessage)
    if type(destination) ~= "table" then
        print(missingMessage)
        return
    end

    removeActionButtons()
    notifyActionZoneCardLeaving()
    self.setPositionSmooth({
        x = destination.x,
        y = destination.y,
        z = destination.z
    }, false, true)
end

function onDestroyCardClicked(object, playerColor, altClick)
    if object ~= self or not isSingleCard() then
        return
    end

    moveCardTo(
        resolveFieldDestination(
            "purgatory",
            cardContext.purgatoryPosition
        ),
        "This card does not have a purgatory destination."
    )
end

function onDamnCardClicked(object, playerColor, altClick)
    if object ~= self or not isSingleCard() then
        return
    end

    moveCardTo(
        resolveFieldDestination(
            "abyss",
            cardContext.abyssPosition
        ),
        "This card does not have an abyss destination."
    )
end

local function findDeckAtDestination()
    local destination = resolveFieldDestination(
        "deck",
        cardContext.deckPosition
    )

    if type(destination) ~= "table" then
        return nil
    end

    local closest = nil
    local closestDistanceSquared = 4

    for _, object in ipairs(getAllObjects()) do
        if object ~= self and (object.tag == "Deck" or object.tag == "Card") then
            local position = object.getPosition()
            local dx = position.x - destination.x
            local dz = position.z - destination.z
            local distanceSquared = dx * dx + dz * dz

            if distanceSquared < closestDistanceSquared then
                closest = object
                closestDistanceSquared = distanceSquared
            end
        end
    end

    return closest
end

function onUnequipCardClicked(object, playerColor, altClick)
    if object ~= self or not isSingleCard() then
        return
    end

    local deck = findDeckAtDestination()

    if deck == nil then
        print("Could not find this card's deck.")
        return
    end

    cardButtonsSuppressed = true
    removeAllCardButtons()
    removeActionButtons()
    resetCardTapRotation()
    notifyActionZoneCardLeaving()
    removeAllCardButtons()
    local deckPosition = deck.getPosition()

    -- putObject inserts at the end nearest the card's Y elevation. Moving
    -- below the resting deck first guarantees insertion at the bottom.
    self.setPosition({
        x = deckPosition.x,
        y = deckPosition.y - 1,
        z = deckPosition.z
    })
    deck.putObject(self)
end

function onReturnCardClicked(object, playerColor, altClick)
    if object ~= self
        or not isSingleCard()
        or returnToHandInProgress
    then
        return
    end

    local player = Player[playerColor]

    if player == nil then
        print("Could not find the player's hand.")
        return
    end

    local deck = findDeckAtDestination()

    returnToHandInProgress = true

    -- Suppress first so delayed hover/movement callbacks cannot recreate a
    -- button between this cleanup and the hand deal.
    cardButtonsSuppressed = true
    removeAllCardButtons()
    removeActionButtons()
    resetCardTapRotation()
    notifyActionZoneCardLeaving()
    normalizeCardBeforeHand()

    local function returnAfterBoundsRefresh()
        -- Clear once more after the scale/rotation changes have propagated.
        -- This is the final operation before entering the original deck.
        normalizeCardBeforeHand()

        if Global ~= nil and type(Global.call) == "function" then
            local succeeded, started = pcall(
                Global.call,
                "returnCardToHandThroughDeck",
                {
                    card = self,
                    deck = deck,
                    playerColor = playerColor
                }
            )

            if succeeded and started == true then
                return
            end
        end

        returnToHandInProgress = false
        print("Could not return the card through its deck.")
        cardButtonsSuppressed = false
        refreshCardButtons()
    end

    -- Let Unity rebuild the collider after clearing UI, restoring scale, and
    -- undoing a tap rotation before the hand system measures the card.
    if Wait ~= nil and type(Wait.frames) == "function" then
        Wait.frames(returnAfterBoundsRefresh, 2)
    else
        returnAfterBoundsRefresh()
    end
end

registerCardFeature({
    id = "destroyToPurgatory",
    stateVersion = 1,
    usesButtons = true,

    migrate = function(state, savedVersion)
        -- The legacy state has no required fields. Return the original table
        -- so unknown per-card values survive save/load unchanged.
        return state
    end
})
]=]
}

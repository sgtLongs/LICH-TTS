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
            removeOnRefresh = true
        },
        {
            callback = "onDamnCardClicked",
            removeOnRefresh = true
        },
        {
            callback = "onUnequipCardClicked",
            removeOnRefresh = true
        },
        {
            callback = "onReturnCardClicked",
            removeOnRefresh = true
        },
        {
            callback = "onActionButtonAreaClicked",
            removeOnRefresh = true
        }
    },
    source = [=[
local actionButtonsVisible = false
local actionLiftBaseY = nil
local actionOriginalUseGravity = nil
local actionPreviewPlayerColor = nil
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

local function setActionCardLifted(lifted)
    local function restoreGravity()
        if actionOriginalUseGravity ~= nil then
            self.use_gravity = actionOriginalUseGravity
            actionOriginalUseGravity = nil
        end
    end

    if type(self.getPosition) ~= "function" then
        actionLiftBaseY = nil

        if not lifted then
            restoreGravity()
        end

        return
    end

    local position = self.getPosition()

    if position == nil
        or tonumber(position.x) == nil
        or tonumber(position.y) == nil
        or tonumber(position.z) == nil
    then
        actionLiftBaseY = nil

        if not lifted then
            restoreGravity()
        end

        return
    end

    if lifted and actionLiftBaseY == nil then
        actionLiftBaseY = tonumber(position.y)
        actionOriginalUseGravity = self.use_gravity ~= false
        self.use_gravity = false
    end

    local liftHeight = tonumber(cardContext.actionsLiftHeight) or 0
    local targetY = lifted
        and actionLiftBaseY + liftHeight
        or actionLiftBaseY

    if targetY == nil then
        if not lifted then
            restoreGravity()
        end

        return
    end

    local target = {
        x = tonumber(position.x),
        y = targetY,
        z = tonumber(position.z)
    }

    if type(self.setPositionSmooth) == "function" then
        self.setPositionSmooth(target, false, true)
    elseif type(self.setPosition) == "function" then
        self.setPosition(target)
    end

    if not lifted then
        actionLiftBaseY = nil
        restoreGravity()
    end
end

local function showCardPreview(playerColor)
    if type(playerColor) ~= "string"
        or playerColor == ""
        or type(cardContext.previewImageUrl) ~= "string"
        or cardContext.previewImageUrl == ""
        or Global == nil
        or type(Global.call) ~= "function"
    then
        return
    end

    actionPreviewPlayerColor = playerColor
    pcall(Global.call, "showCardPreview", {
        card = self,
        playerColor = playerColor,
        imageUrl = cardContext.previewImageUrl
    })
end

local function hideCardPreview()
    if actionPreviewPlayerColor == nil then
        return
    end

    if Global ~= nil and type(Global.call) == "function" then
        pcall(Global.call, "hideCardPreview", {
            card = self,
            playerColor = actionPreviewPlayerColor
        })
    end

    actionPreviewPlayerColor = nil
end

local function removeActionButtons()
    local buttons = self.getButtons() or {}

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if actionButtonFunctions[button.click_function] then
            self.removeButton(button.index)
        end
    end

    setActionCardLifted(false)
    hideCardPreview()
    actionButtonsVisible = false
end

function hideCardActions()
    removeActionButtons()
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

local function showActionButtons(playerColor)
    if cardButtonsSuppressed
        or isCardInHand()
        or not actionZoneTapEnabled
    then
        return
    end

    if actionButtonsVisible then
        return
    end

    setActionCardLifted(true)
    showCardPreview(playerColor)
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
        showActionButtons(playerColor)
    end
end

function onPreviewCardActionClicked(parameters)
    if type(parameters) ~= "table" then
        return false
    end

    local callbacks = {
        destroy = onDestroyCardClicked,
        damn = onDamnCardClicked,
        unequip = onUnequipCardClicked,
        returnToHand = onReturnCardClicked
    }
    local callback = callbacks[parameters.action]

    if type(callback) ~= "function" then
        return false
    end

    callback(self, parameters.playerColor, false)
    return true
end

function hideActionButtonsDuringCardRotation()
    local shouldRestore = actionButtonsVisible
    local restorePreviewPlayerColor = actionPreviewPlayerColor
    removeActionButtons()

    if not shouldRestore then
        return
    end

    local function restoreAfterRotation()
        Wait.condition(
            function()
                if not isCardInHand() then
                    showActionButtons(restorePreviewPlayerColor)
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
    removeActionButtons()

    if type(destination) ~= "table" then
        print(missingMessage)
        return
    end

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

    removeActionButtons()
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

    removeActionButtons()
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

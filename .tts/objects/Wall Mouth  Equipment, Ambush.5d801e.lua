local cardContext = {
fieldId = "3c4e81",
purgatoryPosition = {x = -48.000000, y = 1.000000, z = -41.000000},
abyssPosition = {x = -48.000000, y = 1.000000, z = -35.500000},
deckPosition = {x = -48.000000, y = 1.000000, z = -46.500000},
cardScale = {x = 1.000000, y = 1.000000, z = 1.000000},
untappedRotationY = 180,
tapSideRotationDegrees = 90,
tapRotationToleranceDegrees = 5,
previewImageUrl = "https://kickback-kingdom.com/assets/media/lich/cards/The-Awakening/1184.png",
drawButtons = false,
actionsButtonPosition = {x = 0.000000, y = 0.300000, z = -2.200000},
actionsButtonWidth = 1200,
actionsButtonHeight = 500,
actionsLiftHeight = 1.5,
}
local cardFeatures = {}
local cardState = {features = {}}
local actionZoneTapEnabled = true
local cardButtonsSuppressed = true
local tapSideRotationDegrees = tonumber(
    cardContext.tapSideRotationDegrees
) or 90
local tapSideToleranceDegrees = tonumber(
    cardContext.tapRotationToleranceDegrees
) or 5

local function normalizeSignedRotation(degrees)
    return ((degrees + 180) % 360) - 180
end

local function rotationDistance(first, second)
    return math.abs(normalizeSignedRotation(first - second))
end

local function currentCardSpin()
    if type(self.getRotation) ~= "function" then
        return tonumber(cardContext.untappedRotationY) or 0
    end

    local rotation = self.getRotation()
    return tonumber(rotation and (rotation.y or rotation[2]))
        or tonumber(cardContext.untappedRotationY)
        or 0
end

local function cardTapRotationDegrees(spin)
    local forward = tonumber(cardContext.untappedRotationY) or 0
    local positiveSide = forward + tapSideRotationDegrees
    local negativeSide = forward - tapSideRotationDegrees
    local positiveDistance = rotationDistance(spin, positiveSide)
    local negativeDistance = rotationDistance(spin, negativeSide)
    local nearestDistance = math.min(positiveDistance, negativeDistance)

    if nearestDistance > tapSideToleranceDegrees then
        return 0
    end

    if positiveDistance <= negativeDistance then
        return tapSideRotationDegrees
    end

    return -tapSideRotationDegrees
end

local function readCardTapRotation(spin)
    local rotateState = cardState.features.rotate90

    if type(rotateState) ~= "table" then
        return false
    end

    rotateState.rotated = cardTapRotationDegrees(
        tonumber(spin) or currentCardSpin()
    ) ~= 0
    return rotateState.rotated
end

local function writeCardTapRotation(rotated)
    local rotateState = cardState.features.rotate90

    if type(rotateState) == "table" then
        rotateState.rotated = rotated == true
    end
end

local function cardTapRotationTarget(rotated)
    local spin = currentCardSpin()
    local forward = tonumber(cardContext.untappedRotationY) or 0
    local nearestForward = spin - normalizeSignedRotation(spin - forward)

    if rotated then
        return nearestForward + tapSideRotationDegrees
    end

    return nearestForward
end

local function registerCardFeature(feature)
    cardFeatures[#cardFeatures + 1] = feature
end

local function isSingleCard()
    return self ~= nil and self.tag == "Card"
end

local function isCardInHand()
    if type(self.getZones) == "function" then
        local succeeded, zones = pcall(self.getZones)

        if succeeded and type(zones) == "table" then
            for _, zone in ipairs(zones) do
                if zone ~= nil and zone.tag == "Hand" then
                    return true
                end
            end
        end
    end

    if Player == nil or type(Player.getPlayers) ~= "function" then
        return false
    end

    for _, player in ipairs(Player.getPlayers() or {}) do
        if type(player.getHandObjects) == "function" then
            for _, object in ipairs(player.getHandObjects() or {}) do
                if object == self then
                    return true
                end
            end
        end
    end

    return false
end

local function removeExistingFeatureButtons()
    local buttons = self.getButtons() or {}

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        
if button.click_function == "onCardTapped"
            or button.click_function == "onActionsClicked"
            or button.click_function == "onDestroyCardClicked"
            or button.click_function == "onDamnCardClicked"
            or button.click_function == "onUnequipCardClicked"
            or button.click_function == "onReturnCardClicked"
            or button.click_function == "onActionButtonAreaClicked"
            or button.click_function == "onActionStackUpClicked"
            or button.click_function == "onActionStackDownClicked"
        then
            self.removeButton(button.index)
        end
    end
end

local function removeAllCardButtons()
    if type(hideCardActions) == "function" then
        hideCardActions()
    end

    if type(self.clearButtons) == "function" then
        self.clearButtons()
        return
    end

    local buttons = self.getButtons() or {}

    for index = #buttons, 1, -1 do
        self.removeButton(buttons[index].index)
    end
end

local function decodeState(savedState)
    if type(savedState) ~= "string" or savedState == "" then
        return {features = {}}
    end

    local succeeded, decoded = pcall(JSON.decode, savedState)

    if not succeeded or type(decoded) ~= "table" then
        return {features = {}}
    end

    decoded.features = type(decoded.features) == "table"
        and decoded.features or {}
    return decoded
end

local function refreshButtonConfig()
    if Global == nil or type(Global.call) ~= "function" then
        return
    end

    local succeeded, encodedConfig = pcall(
        Global.call,
        "getCardButtonConfig"
    )

    if not succeeded or type(encodedConfig) ~= "string" then
        return
    end

    local decoded, config = pcall(JSON.decode, encodedConfig)

    if not decoded or type(config) ~= "table" then
        return
    end

    cardContext.drawButtons = config.drawButtons == true


    if type(config.actions) == "table" then
        cardContext.actionsButtonPosition = config.actions.position
            or cardContext.actionsButtonPosition
        cardContext.actionsButtonWidth = tonumber(config.actions.width)
            or cardContext.actionsButtonWidth
        cardContext.actionsButtonHeight = tonumber(config.actions.height)
            or cardContext.actionsButtonHeight
        cardContext.actionsLiftHeight = tonumber(config.actions.liftHeight)
            or cardContext.actionsLiftHeight
    end

end

local function notifyActionZoneRotationChanged(rotated)
    if Global ~= nil and type(Global.call) == "function" then
        pcall(
            Global.call,
            "onActionZoneCardRotationChanged",
            {card = self, rotated = rotated}
        )
    end
end

registerCardFeature({
    id = "rotate90",
    stateVersion = 1,
    usesButtons = true,

    migrate = function(state, savedVersion)
        -- Missing versions are the legacy generated-card state. The legacy
        -- shape already uses `rotated`, so migration only normalizes it.
        state.rotated = state.rotated == true
        return state
    end,

    onLoad = function(state)
        local rotated = readCardTapRotation()
        notifyActionZoneRotationChanged(rotated)
    end,

    onTap = function(state)
        local rotated = not readCardTapRotation()
        writeCardTapRotation(rotated)
        notifyActionZoneRotationChanged(rotated)

        if type(hideActionButtonsDuringCardRotation) == "function" then
            hideActionButtonsDuringCardRotation()
        end

        local targetSpin = cardTapRotationTarget(rotated)

        if type(self.getRotation) == "function"
            and type(self.setRotationSmooth) == "function"
        then
            local rotation = self.getRotation()

            -- Use an exact target and ignore collisions while turning. The
            -- relative rotate API can be physically constrained by the
            -- locked cards directly beneath an action-stack card.
            self.setRotationSmooth({
                x = rotation.x,
                y = targetSpin,
                z = rotation.z
            }, false, true)
        else
            self.rotate({
                x = 0,
                y = normalizeSignedRotation(targetSpin - currentCardSpin()),
                z = 0
            })
        end
    end,

    onRotate = function(state, spin)
        local rotated = readCardTapRotation(spin)
        notifyActionZoneRotationChanged(rotated)

        if type(hideActionButtonsDuringCardRotation) == "function" then
            hideActionButtonsDuringCardRotation()
        end
    end
})

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
        return false
    end

    local succeeded, shown = pcall(Global.call, "showCardPreview", {
        card = self,
        playerColor = playerColor,
        imageUrl = cardContext.previewImageUrl
    })

    if succeeded and shown == true then
        actionPreviewPlayerColor = playerColor
        return true
    end

    return false
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

local function removeActionButtons(parameters)
    local preserveCardPreview = type(parameters) == "table"
        and parameters.preserveCardPreview == true
    local buttons = self.getButtons() or {}

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if actionButtonFunctions[button.click_function] then
            self.removeButton(button.index)
        end
    end

    setActionCardLifted(false)

    if preserveCardPreview then
        -- The action-zone controller is transferring selection within the
        -- same preview stack. Global retains the shared preview session.
        actionPreviewPlayerColor = nil
    else
        hideCardPreview()
    end

    actionButtonsVisible = false
end

function hideCardActions()
    removeActionButtons()
end

local function resetCardTapRotation()
    if not readCardTapRotation() then
        return
    end

    writeCardTapRotation(false)
    local targetSpin = cardTapRotationTarget(false)

    if type(self.getRotation) == "function"
        and type(self.setRotation) == "function"
    then
        local rotation = self.getRotation()
        self.setRotation({
            x = rotation.x,
            y = targetSpin,
            z = rotation.z
        })
    elseif type(self.rotate) == "function" then
        self.rotate({
            x = 0,
            y = normalizeSignedRotation(targetSpin - currentCardSpin()),
            z = 0
        })
    end
end

local function actionButtonPosition(position)
    if not readCardTapRotation() then
        return position
    end

    -- Counter-rotate the local offset so either 90-degree card rotation
    -- leaves the button in the same world-facing layout.
    if cardTapRotationDegrees(currentCardSpin()) < 0 then
        return {
            x = -position.z,
            y = position.y,
            z = position.x
        }
    end

    return {
        x = position.z,
        y = position.y,
        z = -position.x
    }
end

local function actionButtonRotation()
    if not readCardTapRotation() then
        return {0, 0, 0}
    end

    return {0, -cardTapRotationDegrees(currentCardSpin()), 0}
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

    if showCardPreview(playerColor) then
        setActionCardLifted(true)
        actionButtonsVisible = true
    end
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

function showCardActionsForPlayer(parameters)
    if type(parameters) ~= "table"
        or type(parameters.playerColor) ~= "string"
        or parameters.playerColor == ""
    then
        return false
    end

    showActionButtons(parameters.playerColor)
    return actionButtonsVisible
end

function getCardPreviewImageUrl()
    return cardContext.previewImageUrl
end

function releaseCardActionLiftForStackPreview()
    -- Global owns the preview for the rest of this stack-navigation session.
    -- Detach the original card so disabling its Actions trigger while another
    -- stack card becomes selected cannot close the shared preview.
    actionPreviewPlayerColor = nil
    actionButtonsVisible = false
    actionLiftBaseY = nil

    if actionOriginalUseGravity ~= nil then
        self.use_gravity = actionOriginalUseGravity
        actionOriginalUseGravity = nil
    end

    return true
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

function refreshCardActionButtons(parameters)
    local actionsButton = findCardButton("onActionsClicked")

    if cardButtonsSuppressed
        or isCardInHand()
        or not actionZoneTapEnabled
    then
        removeActionButtons(parameters)

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

function refreshCardButtons(parameters)
    if not isSingleCard() then
        return
    end

    refreshButtonConfig()

    if isCardInHand() or cardButtonsSuppressed then
        removeAllCardButtons()
        return
    end

    for _, button in ipairs(self.getButtons() or {}) do
        if button.click_function == "onCardTapped" then
            self.removeButton(button.index)
        end
    end

    if type(refreshCardActionButtons) == "function" then
        refreshCardActionButtons(parameters)
    end
end

function setActionZoneTapEnabled(parameters)
    actionZoneTapEnabled = type(parameters) ~= "table"
        or parameters.enabled ~= false
    refreshCardButtons({
        preserveCardPreview = type(parameters) == "table"
            and parameters.preserveCardPreview == true
    })
end

local function cardIsReadyForButtons()
    if isCardInHand() then
        return true
    end

    if self.spawning == true or self.loading_custom == true then
        return false
    end

    if self.held_by_color ~= nil then
        return false
    end

    return type(self.isSmoothMoving) ~= "function"
        or not self.isSmoothMoving()
end

local function refreshButtonsAfterMovement()
    local function completeRefresh()
        cardButtonsSuppressed = isCardInHand()
        refreshCardButtons()
    end

    if Wait ~= nil and type(Wait.condition) == "function" then
        Wait.condition(
            completeRefresh,
            cardIsReadyForButtons,
            5,
            completeRefresh
        )
    elseif Wait ~= nil and type(Wait.frames) == "function" then
        Wait.frames(completeRefresh, 10)
    else
        completeRefresh()
    end
end

local function migrateFeatureState(feature, featureState)
    local currentVersion = tonumber(feature.stateVersion)

    if currentVersion == nil then
        return featureState
    end

    local savedVersion = tonumber(featureState.stateVersion) or 0

    if savedVersion < currentVersion and type(feature.migrate) == "function" then
        local migrated = feature.migrate(featureState, savedVersion)

        if type(migrated) == "table" then
            featureState = migrated
        end
    end

    -- Do not downgrade state produced by a newer generated card script.
    if savedVersion <= currentVersion then
        featureState.stateVersion = currentVersion
    end

    return featureState
end

function getActionZoneTapRotation()
    return readCardTapRotation()
end

function onLoad(savedState)
    if not isSingleCard() then
        return
    end

    cardButtonsSuppressed = true
    removeAllCardButtons()
    refreshButtonConfig()
    cardState = decodeState(savedState)
    local hasTapFeature = false

    for _, feature in ipairs(cardFeatures) do
        local featureState = cardState.features[feature.id]

        if type(featureState) ~= "table" then
            featureState = {}
        end

        featureState = migrateFeatureState(feature, featureState)
        cardState.features[feature.id] = featureState

        if type(feature.onLoad) == "function" then
            feature.onLoad(featureState)
        end

        hasTapFeature = hasTapFeature
            or type(feature.onTap) == "function"
            or feature.usesButtons == true
    end

    -- Cards separated from a deck load before TTS has placed them in their
    -- destination. Do not create a full-size button until that move finishes,
    -- otherwise the hand layout can use the button's bounds for spacing.
    if hasTapFeature then
        refreshButtonsAfterMovement()
    end
end

function onPickUp(playerColor)
    cardButtonsSuppressed = true
    removeAllCardButtons()
    refreshButtonsAfterMovement()
end

function onDrop(playerColor)
    refreshButtonsAfterMovement()
end

function onHover(playerColor)
    if not isSingleCard() then
        return
    end

    for _, feature in ipairs(cardFeatures) do
        if type(feature.onHover) == "function" then
            feature.onHover(
                cardState.features[feature.id],
                playerColor
            )
        end
    end
end

function onRotate(spin, flip, playerColor, oldSpin, oldFlip)
    if not isSingleCard() then
        return
    end

    for _, feature in ipairs(cardFeatures) do
        if type(feature.onRotate) == "function" then
            feature.onRotate(
                cardState.features[feature.id],
                spin,
                flip,
                playerColor,
                oldSpin,
                oldFlip
            )
        end
    end
end

function onCardTapped(object, playerColor, altClick)
    if object ~= self
        or not isSingleCard()
        or not actionZoneTapEnabled
    then
        return
    end

    for _, feature in ipairs(cardFeatures) do
        if type(feature.onTap) == "function" then
            feature.onTap(
                cardState.features[feature.id],
                playerColor,
                altClick
            )
        end
    end
end

function onSave()
    readCardTapRotation()
    return JSON.encode(cardState)
end

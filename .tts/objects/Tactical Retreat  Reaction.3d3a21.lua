local cardContext = {
fieldId = "3c4e81",
purgatoryPosition = {x = -48.000000, y = 1.000000, z = -41.000000},
abyssPosition = {x = -48.000000, y = 1.000000, z = -35.500000},
deckPosition = {x = -48.000000, y = 1.000000, z = -46.500000},
cardScale = {x = 1.000000, y = 1.000000, z = 1.000000},
drawButtons = false,
tapButtonPosition = {x = 0.000000, y = 0.300000, z = 0.000000},
tapButtonWidth = 1200,
tapButtonHeight = 1600,
destroyButtonPosition = {x = -2.000000, y = 0.300000, z = 1.000000},
destroyButtonWidth = 900,
destroyButtonHeight = 1000,
damnButtonPosition = {x = -2.000000, y = 0.300000, z = -1.000000},
damnButtonWidth = 900,
damnButtonHeight = 1000,
unequipButtonPosition = {x = 2.000000, y = 0.300000, z = 1.000000},
unequipButtonWidth = 900,
unequipButtonHeight = 1000,
returnToHandButtonPosition = {x = 2.000000, y = 0.300000, z = -1.000000},
returnToHandButtonWidth = 900,
returnToHandButtonHeight = 1000,
tapDebugLabel = "tap",
tapDebugColor = {0.100000, 0.650000, 1.000000, 0.450000},
tapDebugHoverColor = {0.200000, 0.800000, 1.000000, 0.600000},
tapDebugPressColor = {0.050000, 0.450000, 0.800000, 0.700000},
tapDebugFontColor = {1.000000, 1.000000, 1.000000, 1.000000}
}
local cardFeatures = {}
local cardState = {features = {}}
local actionZoneTapEnabled = true
local cardButtonsSuppressed = true

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


    if type(config.tap) == "table" then
        cardContext.tapButtonPosition = config.tap.position
            or cardContext.tapButtonPosition
        cardContext.tapButtonWidth = tonumber(config.tap.width)
            or cardContext.tapButtonWidth
        cardContext.tapButtonHeight = tonumber(config.tap.height)
            or cardContext.tapButtonHeight
    end

    if type(config.destroy) == "table" then
        cardContext.destroyButtonPosition = config.destroy.position
            or cardContext.destroyButtonPosition
        cardContext.destroyButtonWidth = tonumber(config.destroy.width)
            or cardContext.destroyButtonWidth
        cardContext.destroyButtonHeight = tonumber(config.destroy.height)
            or cardContext.destroyButtonHeight
    end

    for _, actionName in ipairs({"damn", "unequip", "returnToHand"}) do
        local actionConfig = config[actionName]

        if type(actionConfig) == "table" then
            cardContext[actionName .. "ButtonPosition"] =
                actionConfig.position
                or cardContext[actionName .. "ButtonPosition"]
            cardContext[actionName .. "ButtonWidth"] =
                tonumber(actionConfig.width)
                or cardContext[actionName .. "ButtonWidth"]
            cardContext[actionName .. "ButtonHeight"] =
                tonumber(actionConfig.height)
                or cardContext[actionName .. "ButtonHeight"]
        end
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
        state.rotated = state.rotated == true
        notifyActionZoneRotationChanged(state.rotated)
    end,

    onTap = function(state)
        state.rotated = not state.rotated
        notifyActionZoneRotationChanged(state.rotated)

        if type(hideActionButtonsDuringCardRotation) == "function" then
            hideActionButtonsDuringCardRotation()
        end

        local amount = state.rotated and 90 or -90

        if type(self.getRotation) == "function"
            and type(self.setRotationSmooth) == "function"
        then
            local rotation = self.getRotation()

            -- Use an exact target and ignore collisions while turning. The
            -- relative rotate API can be physically constrained by the
            -- locked cards directly beneath an action-stack card.
            self.setRotationSmooth({
                x = rotation.x,
                y = rotation.y + amount,
                z = rotation.z
            }, false, true)
        else
            self.rotate({x = 0, y = amount, z = 0})
        end
    end
})

local actionButtonsVisible = false
local actionHoverPlayers = {}
local returnToHandInProgress = false
local actionButtonFunctions = {
    onDestroyCardClicked = true,
    onDamnCardClicked = true,
    onUnequipCardClicked = true,
    onReturnCardClicked = true,
    onActionButtonAreaClicked = true
}

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
    if actionButtonsVisible
        or cardButtonsSuppressed
        or isCardInHand()
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

function hideActionButtonsDuringCardRotation()
    local shouldRestore = actionButtonsVisible
    removeActionButtons()

    if not shouldRestore then
        return
    end

    local function restoreAfterRotation()
        Wait.condition(
            function()
                if next(actionHoverPlayers) ~= nil
                    and not isCardInHand()
                then
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
    end,

    onHover = function(state, playerColor)
        actionHoverPlayers[playerColor] = true
        showActionButtons()

        Wait.condition(
            function()
                actionHoverPlayers[playerColor] = nil

                if next(actionHoverPlayers) == nil then
                    removeActionButtons()
                end
            end,
            function()
                local player = Player[playerColor]
                return player == nil
                    or player.getHoverObject() ~= self
            end
        )
    end
})

local function makeTapButtonParameters()
    local showDebug = cardContext.drawButtons == true

    return {
        label = showDebug and cardContext.tapDebugLabel or "",
        click_function = "onCardTapped",
        function_owner = self,
        position = cardContext.tapButtonPosition,
        rotation = {0, 0, 0},
        width = cardContext.tapButtonWidth,
        height = cardContext.tapButtonHeight,
        font_size = showDebug and 180 or 1,
        color = showDebug
            and cardContext.tapDebugColor or {0, 0, 0, 0},
        font_color = showDebug
            and cardContext.tapDebugFontColor or {0, 0, 0, 0},
        hover_color = showDebug
            and cardContext.tapDebugHoverColor or {0, 0, 0, 0},
        press_color = showDebug
            and cardContext.tapDebugPressColor or {0, 0, 0, 0},
        tooltip = "tap"
    }
end

function refreshCardButtons()
    if not isSingleCard() then
        return
    end

    refreshButtonConfig()

    if isCardInHand() or cardButtonsSuppressed then
        removeAllCardButtons()
        return
    end

    local hasTapButton = false

    for _, button in ipairs(self.getButtons() or {}) do
        if button.click_function == "onCardTapped" then
            if actionZoneTapEnabled then
                hasTapButton = true
                local parameters = makeTapButtonParameters()
                parameters.index = button.index
                self.editButton(parameters)
            else
                self.removeButton(button.index)
            end
            break
        end
    end

    if actionZoneTapEnabled and not hasTapButton then
        for _, feature in ipairs(cardFeatures) do
            if type(feature.onTap) == "function" then
                self.createButton(makeTapButtonParameters())
                break
            end
        end
    end

    if type(refreshCardActionButtons) == "function" then
        refreshCardActionButtons()
    end
end

function setActionZoneTapEnabled(parameters)
    actionZoneTapEnabled = type(parameters) ~= "table"
        or parameters.enabled ~= false
    refreshCardButtons()
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
    local rotateState = cardState.features.rotate90
    return type(rotateState) == "table"
        and rotateState.rotated == true
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
    return JSON.encode(cardState)
end

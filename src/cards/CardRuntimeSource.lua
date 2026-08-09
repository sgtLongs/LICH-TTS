local CardRuntimeSource = {}

-- ActionZone owns these buttons, but generated cards must continue removing
-- stale copies when they enter a hand or reload. They are runtime integration
-- callbacks rather than callbacks owned by a card feature.
local compatibilityButtonCallbacks = {
    "onActionStackUpClicked",
    "onActionStackDownClicked"
}

local function appendUnique(values, seen, value)
    if type(value) == "string" and value ~= "" and not seen[value] then
        seen[value] = true
        values[#values + 1] = value
    end
end

local function collectDescriptorValues(descriptors, key, compatibilityValues)
    local values = {}
    local seen = {}

    for _, descriptor in ipairs(descriptors or {}) do
        for _, value in ipairs(descriptor[key] or {}) do
            appendUnique(values, seen, value)
        end
    end

    for _, value in ipairs(compatibilityValues or {}) do
        appendUnique(values, seen, value)
    end

    return values
end

local function collectButtonCallbacks(descriptors)
    local callbacks = collectDescriptorValues(
        descriptors,
        "buttonCallbacks"
    )
    local seen = {}

    for _, callbackName in ipairs(callbacks) do
        seen[callbackName] = true
    end

    for _, descriptor in ipairs(descriptors or {}) do
        for _, button in ipairs(descriptor.hostButtons or {}) do
            appendUnique(callbacks, seen, button.callback)
        end
    end

    for _, callbackName in ipairs(compatibilityButtonCallbacks) do
        appendUnique(callbacks, seen, callbackName)
    end

    return callbacks
end


local function collectRuntimeConfigKeys(descriptors)
    local keys = collectDescriptorValues(
        descriptors,
        "runtimeConfigKeys"
    )
    local seen = {}

    for _, key in ipairs(keys) do
        seen[key] = true
    end

    for _, descriptor in ipairs(descriptors or {}) do
        for _, button in ipairs(descriptor.hostButtons or {}) do
            appendUnique(keys, seen, button.configKey)
        end
    end

    return keys
end

local function makeButtonCleanupCondition(descriptors)
    local callbacks = collectButtonCallbacks(descriptors)
    local lines = {}

    for index, callbackName in ipairs(callbacks) do
        local prefix = index == 1 and "if " or "            or "
        lines[#lines + 1] = prefix
            .. "button.click_function == "
            .. string.format("%q", callbackName)
    end

    if #lines == 0 then
        return "if false"
    end

    return table.concat(lines, "\n")
end

local function makeRuntimeConfigRefresh(descriptors)
    local keys = collectRuntimeConfigKeys(descriptors)
    local selected = {}

    for _, key in ipairs(keys) do
        selected[key] = true
    end

    local chunks = {}

    if selected.actions then
        chunks[#chunks + 1] = [=[
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
]=]
    end

    return table.concat(chunks, "\n")
end

function CardRuntimeSource.buildBootstrap(descriptors)
    return table.concat({
        [=[
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

        ]=],
        makeButtonCleanupCondition(descriptors),
        [=[
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

]=],
        makeRuntimeConfigRefresh(descriptors),
        [=[
end
]=]
    }, "\n")
end

local lifecycle = [=[
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
]=]

function CardRuntimeSource.getLifecycle()
    return lifecycle
end

return CardRuntimeSource

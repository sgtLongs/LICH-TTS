local Config = require("src/config/CardLogicConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")

local CardLogic = {}

local featureSources = {}
local defaultFeatures = {}

local bootstrap = [=[
local cardFeatures = {}
local cardState = {features = {}}
local actionZoneTapEnabled = true

local function registerCardFeature(feature)
    cardFeatures[#cardFeatures + 1] = feature
end

local function isSingleCard()
    return self ~= nil and self.tag == "Card"
end

local function isCardInHand()
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
        then
            self.removeButton(button.index)
        end
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
]=]

local lifecycle = [=[
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

    if isCardInHand() then
        removeExistingFeatureButtons()
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

function getActionZoneTapRotation()
    local rotateState = cardState.features.rotate90
    return type(rotateState) == "table"
        and rotateState.rotated == true
end

function onLoad(savedState)
    if not isSingleCard() then
        return
    end

    removeExistingFeatureButtons()
    refreshButtonConfig()
    cardState = decodeState(savedState)
    local hasTapFeature = false

    for _, feature in ipairs(cardFeatures) do
        local featureState = cardState.features[feature.id]

        if type(featureState) ~= "table" then
            featureState = {}
            cardState.features[feature.id] = featureState
        end

        if type(feature.onLoad) == "function" then
            feature.onLoad(featureState)
        end

        hasTapFeature = hasTapFeature
            or type(feature.onTap) == "function"
    end

    if hasTapFeature
        and actionZoneTapEnabled
        and not isCardInHand()
    then
        self.createButton(makeTapButtonParameters())
    end
end

local function refreshButtonsAfterMovement()
    if Wait ~= nil and type(Wait.frames) == "function" then
        Wait.frames(refreshCardButtons, 2)
    else
        refreshCardButtons()
    end
end

function onPickUp(playerColor)
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

local function validateFeature(name, source)
    if type(name) ~= "string" or name == "" then
        error("Card feature names must be non-empty strings.", 3)
    end

    if type(source) ~= "string" or source == "" then
        error("Card feature sources must be non-empty strings.", 3)
    end
end

function CardLogic.registerFeature(name, source, enabledByDefault)
    validateFeature(name, source)
    featureSources[name] = source

    if enabledByDefault == true then
        defaultFeatures[#defaultFeatures + 1] = name
    end
end

function CardLogic.getButtonConfig()
    local actionList = Config.buttons.actionList

    return {
        drawButtons = DebugConfig.drawCardButtons == true,
        tap = {
            position = Config.buttons.tap.position,
            width = Config.buttons.tap.width,
            height = Config.buttons.tap.height
        },
        destroy = {
            position = Config.buttons.destroy.position,
            width = actionList.width,
            height = actionList.height
        },
        damn = {
            position = Config.buttons.damn.position,
            width = actionList.width,
            height = actionList.height
        },
        unequip = {
            position = Config.buttons.unequip.position,
            width = actionList.width,
            height = actionList.height
        },
        returnToHand = {
            position = Config.buttons.returnToHand.position,
            width = actionList.width,
            height = actionList.height
        }
    }
end

function CardLogic.refreshExistingButtons()
    for _, object in ipairs(getAllObjects()) do
        if object.tag == "Card" then
            local succeeded, buttons = pcall(object.getButtons)

            if succeeded and type(buttons) == "table" then
                for _, button in ipairs(buttons) do
                    if button.click_function
                        == "onActionButtonAreaClicked"
                    then
                        pcall(object.removeButton, button.index)
                    elseif button.click_function == "onCardTapped" then
                        local showDebug =
                            DebugConfig.drawCardButtons == true

                        pcall(object.editButton, {
                            index = button.index,
                            label = showDebug
                                and Config.debug.tapLabel or "",
                            position = Config.buttons.tap.position,
                            width = Config.buttons.tap.width,
                            height = Config.buttons.tap.height,
                            font_size = showDebug and 180 or 1,
                            color = showDebug
                                and Config.debug.tapColor
                                or {0, 0, 0, 0},
                            font_color = showDebug
                                and Config.debug.tapFontColor
                                or {0, 0, 0, 0},
                            hover_color = showDebug
                                and Config.debug.tapHoverColor
                                or {0, 0, 0, 0},
                            press_color = showDebug
                                and Config.debug.tapPressColor
                                or {0, 0, 0, 0}
                        })
                    elseif button.click_function
                        == "onDestroyCardClicked"
                        or button.click_function == "onDamnCardClicked"
                        or button.click_function == "onUnequipCardClicked"
                        or button.click_function == "onReturnCardClicked"
                    then
                        local configKeyByFunction = {
                            onDestroyCardClicked = "destroy",
                            onDamnCardClicked = "damn",
                            onUnequipCardClicked = "unequip",
                            onReturnCardClicked = "returnToHand"
                        }
                        local actionConfig = Config.buttons[
                            configKeyByFunction[button.click_function]
                        ]

                        pcall(object.editButton, {
                            index = button.index,
                            position = actionConfig.position,
                            width = Config.buttons.actionList.width,
                            height = Config.buttons.actionList.height
                        })
                    end
                end
            end

        end
    end
end

local function vectorLiteral(value, fallback)
    value = type(value) == "table" and value or fallback

    return string.format(
        "{x = %.6f, y = %.6f, z = %.6f}",
        tonumber(value.x or value[1]) or 0,
        tonumber(value.y or value[2]) or 0,
        tonumber(value.z or value[3]) or 0
    )
end

local function colorLiteral(value)
    return string.format(
        "{%.6f, %.6f, %.6f, %.6f}",
        tonumber(value[1]) or 0,
        tonumber(value[2]) or 0,
        tonumber(value[3]) or 0,
        tonumber(value[4]) or 1
    )
end

local function quoted(value)
    return string.format("%q", tostring(value or ""))
end

local function makeContextSource(context)
    local purgatoryPosition = context and context.purgatoryPosition
    local abyssPosition = context and context.abyssPosition
    local deckPosition = context and context.deckPosition
    local purgatoryLiteral = "nil"
    local abyssLiteral = "nil"
    local deckLiteral = "nil"

    if type(purgatoryPosition) == "table" then
        purgatoryLiteral = vectorLiteral(purgatoryPosition, {0, 0, 0})
    end

    if type(abyssPosition) == "table" then
        abyssLiteral = vectorLiteral(abyssPosition, {0, 0, 0})
    end

    if type(deckPosition) == "table" then
        deckLiteral = vectorLiteral(deckPosition, {0, 0, 0})
    end

    return table.concat({
        "local cardContext = {",
        "purgatoryPosition = " .. purgatoryLiteral .. ",",
        "abyssPosition = " .. abyssLiteral .. ",",
        "deckPosition = " .. deckLiteral .. ",",
        "drawButtons = "
            .. tostring(DebugConfig.drawCardButtons == true) .. ",",
        "tapButtonPosition = "
            .. vectorLiteral(Config.buttons.tap.position, {0, 0.3, 0})
            .. ",",
        "tapButtonWidth = "
            .. tostring(tonumber(Config.buttons.tap.width) or 2400) .. ",",
        "tapButtonHeight = "
            .. tostring(tonumber(Config.buttons.tap.height) or 3400) .. ",",
        "destroyButtonPosition = "
            .. vectorLiteral(Config.buttons.destroy.position, {1.8, 0.3, 0})
            .. ",",
        "destroyButtonWidth = "
            .. tostring(tonumber(Config.buttons.actionList.width) or 900) .. ",",
        "destroyButtonHeight = "
            .. tostring(tonumber(Config.buttons.actionList.height) or 500) .. ",",
        "damnButtonPosition = "
            .. vectorLiteral(Config.buttons.damn.position, {1.8, 0.3, -0.3})
            .. ",",
        "damnButtonWidth = "
            .. tostring(tonumber(Config.buttons.actionList.width) or 900) .. ",",
        "damnButtonHeight = "
            .. tostring(tonumber(Config.buttons.actionList.height) or 500) .. ",",
        "unequipButtonPosition = "
            .. vectorLiteral(Config.buttons.unequip.position, {1.8, 0.3, 0.3})
            .. ",",
        "unequipButtonWidth = "
            .. tostring(tonumber(Config.buttons.actionList.width) or 900) .. ",",
        "unequipButtonHeight = "
            .. tostring(tonumber(Config.buttons.actionList.height) or 500) .. ",",
        "returnToHandButtonPosition = "
            .. vectorLiteral(
                Config.buttons.returnToHand.position,
                {1.8, 0.3, 0.9}
            ) .. ",",
        "returnToHandButtonWidth = "
            .. tostring(tonumber(Config.buttons.actionList.width) or 900)
            .. ",",
        "returnToHandButtonHeight = "
            .. tostring(tonumber(Config.buttons.actionList.height) or 500)
            .. ",",
        "tapDebugLabel = " .. quoted(Config.debug.tapLabel) .. ",",
        "tapDebugColor = " .. colorLiteral(Config.debug.tapColor) .. ",",
        "tapDebugHoverColor = "
            .. colorLiteral(Config.debug.tapHoverColor) .. ",",
        "tapDebugPressColor = "
            .. colorLiteral(Config.debug.tapPressColor) .. ",",
        "tapDebugFontColor = "
            .. colorLiteral(Config.debug.tapFontColor),
        "}"
    }, "\n")
end

function CardLogic.build(featureNames, context)
    featureNames = featureNames or defaultFeatures
    local chunks = {makeContextSource(context), bootstrap}

    for _, name in ipairs(featureNames) do
        local source = featureSources[name]

        if source == nil then
            error("Unknown card feature: " .. tostring(name), 2)
        end

        chunks[#chunks + 1] = source
    end

    chunks[#chunks + 1] = lifecycle
    return table.concat(chunks, "\n")
end

CardLogic.registerFeature("rotate90", [=[
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
]=], true)

CardLogic.registerFeature("destroyToPurgatory", [=[
local actionButtonsVisible = false
local actionHoverPlayers = {}
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
    if actionButtonsVisible or isCardInHand() then
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
        cardContext.purgatoryPosition,
        "This card does not have a purgatory destination."
    )
end

function onDamnCardClicked(object, playerColor, altClick)
    if object ~= self or not isSingleCard() then
        return
    end

    moveCardTo(
        cardContext.abyssPosition,
        "This card does not have an abyss destination."
    )
end

local function findDeckAtDestination()
    local destination = cardContext.deckPosition

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

    removeActionButtons()
    notifyActionZoneCardLeaving()
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
    if object ~= self or not isSingleCard() then
        return
    end

    local player = Player[playerColor]

    if player == nil then
        print("Could not find the player's hand.")
        return
    end

    removeActionButtons()
    notifyActionZoneCardLeaving()
    self.deal(1, playerColor)
end

registerCardFeature({
    id = "destroyToPurgatory",

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
]=], true)

return CardLogic

local Config = require("src/config/CardLogicConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")

local CardLogic = {}

local featureSources = {}
local defaultFeatures = {}

local bootstrap = [=[
local cardFeatures = {}
local cardState = {features = {}}

local function registerCardFeature(feature)
    cardFeatures[#cardFeatures + 1] = feature
end

local function isSingleCard()
    return self ~= nil and self.tag == "Card"
end

local function removeExistingFeatureButtons()
    local buttons = self.getButtons() or {}

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if button.click_function == "onCardTapped"
            or button.click_function == "onDestroyCardClicked"
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

    for _, button in ipairs(self.getButtons() or {}) do
        if button.click_function == "onCardTapped" then
            local parameters = makeTapButtonParameters()
            parameters.index = button.index
            self.editButton(parameters)
            break
        end
    end

    if type(refreshDestroyCardButton) == "function" then
        refreshDestroyCardButton()
    end
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

    if hasTapFeature then
        self.createButton(makeTapButtonParameters())
    end
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
    if object ~= self or not isSingleCard() then
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
    return {
        drawButtons = DebugConfig.drawCardButtons == true,
        tap = {
            position = Config.buttons.tap.position,
            width = Config.buttons.tap.width,
            height = Config.buttons.tap.height
        },
        destroy = {
            position = Config.buttons.destroy.position,
            width = Config.buttons.destroy.width,
            height = Config.buttons.destroy.height
        }
    }
end

function CardLogic.refreshExistingButtons()
    for _, object in ipairs(getAllObjects()) do
        if object.tag == "Card" then
            local succeeded, buttons = pcall(object.getButtons)

            if succeeded and type(buttons) == "table" then
                for _, button in ipairs(buttons) do
                    if button.click_function == "onCardTapped" then
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
                    then
                        pcall(object.editButton, {
                            index = button.index,
                            position = Config.buttons.destroy.position,
                            width = Config.buttons.destroy.width,
                            height = Config.buttons.destroy.height
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
    local purgatoryLiteral = "nil"

    if type(purgatoryPosition) == "table" then
        purgatoryLiteral = vectorLiteral(purgatoryPosition, {0, 0, 0})
    end

    return table.concat({
        "local cardContext = {",
        "purgatoryPosition = " .. purgatoryLiteral .. ",",
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
            .. tostring(tonumber(Config.buttons.destroy.width) or 900) .. ",",
        "destroyButtonHeight = "
            .. tostring(tonumber(Config.buttons.destroy.height) or 500) .. ",",
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
registerCardFeature({
    id = "rotate90",

    onLoad = function(state)
        state.rotated = state.rotated == true
    end,

    onTap = function(state)
        state.rotated = not state.rotated
        self.rotate({
            x = 0,
            y = state.rotated and 90 or -90,
            z = 0
        })
    end
})
]=], true)

CardLogic.registerFeature("destroyToPurgatory", [=[
local destroyButtonVisible = false
local destroyHoverPlayers = {}

local function removeDestroyButton()
    for _, button in ipairs(self.getButtons() or {}) do
        if button.click_function == "onDestroyCardClicked" then
            self.removeButton(button.index)
            break
        end
    end

    destroyButtonVisible = false
end

local function showDestroyButton()
    if destroyButtonVisible then
        return
    end

    self.createButton({
        label = "destroy",
        click_function = "onDestroyCardClicked",
        function_owner = self,
        position = cardContext.destroyButtonPosition,
        rotation = {0, 0, 0},
        width = cardContext.destroyButtonWidth,
        height = cardContext.destroyButtonHeight,
        font_size = 180,
        color = {0.65, 0.08, 0.08, 0.95},
        font_color = {1, 1, 1, 1},
        hover_color = {0.9, 0.12, 0.12, 1},
        press_color = {0.45, 0.03, 0.03, 1},
        tooltip = "Move to purgatory"
    })
    destroyButtonVisible = true
end


function refreshDestroyCardButton()
    if not destroyButtonVisible then
        return
    end

    for _, button in ipairs(self.getButtons() or {}) do
        if button.click_function == "onDestroyCardClicked" then
            self.editButton({
                index = button.index,
                position = cardContext.destroyButtonPosition,
                width = cardContext.destroyButtonWidth,
                height = cardContext.destroyButtonHeight
            })
            break
        end
    end
end

function onDestroyCardClicked(object, playerColor, altClick)
    if object ~= self or not isSingleCard() then
        return
    end

    local destination = cardContext.purgatoryPosition

    if type(destination) ~= "table" then
        print("This card does not have a purgatory destination.")
        return
    end

    removeDestroyButton()
    self.setPositionSmooth({
        x = destination.x,
        y = destination.y,
        z = destination.z
    }, false, true)
end

registerCardFeature({
    id = "destroyToPurgatory",

    onHover = function(state, playerColor)
        destroyHoverPlayers[playerColor] = true
        showDestroyButton()

        Wait.condition(
            function()
                destroyHoverPlayers[playerColor] = nil

                if next(destroyHoverPlayers) == nil then
                    removeDestroyButton()
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

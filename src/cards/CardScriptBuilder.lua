local Config = require("src/config/CardLogicConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local CardRuntimeSource = require("src/cards/CardRuntimeSource")

local CardScriptBuilder = {}
CardScriptBuilder.__index = CardScriptBuilder

local function vectorLiteral(value, fallback)
    value = type(value) == "table" and value or fallback

    return string.format(
        "{x = %.6f, y = %.6f, z = %.6f}",
        tonumber(value.x or value[1]) or 0,
        tonumber(value.y or value[2]) or 0,
        tonumber(value.z or value[3]) or 0
    )
end

local function quoted(value)
    return string.format("%q", tostring(value or ""))
end

function CardScriptBuilder.new(dependencies)
    dependencies = dependencies or {}

    if dependencies.registry == nil then
        error("CardScriptBuilder requires a feature registry.", 2)
    end

    return setmetatable({
        registry = dependencies.registry,
        config = dependencies.config or Config,
        debugConfig = dependencies.debugConfig or DebugConfig,
        runtimeSource = dependencies.runtimeSource or CardRuntimeSource
    }, CardScriptBuilder)
end

function CardScriptBuilder:getButtonConfig()
    local buttons = self.config.buttons
    local runtimeConfig = {
        drawButtons = self.debugConfig.drawCardButtons == true
    }

    for _, feature in ipairs(self.registry:getDescriptors()) do
        for _, descriptor in ipairs(feature.hostButtons or {}) do
            local key = descriptor.configKey
            local buttonConfig = key ~= nil and buttons[key] or nil

            if type(buttonConfig) == "table"
                and runtimeConfig[key] == nil
            then
                runtimeConfig[key] = {
                    position = buttonConfig.position,
                    width = buttonConfig.width,
                    height = buttonConfig.height
                }

                if key == "actions" then
                    runtimeConfig[key].liftHeight =
                        tonumber(buttonConfig.liftHeight) or 0
                end
            end
        end
    end

    return runtimeConfig
end

function CardScriptBuilder:makeContextSource(context)
    context = context or {}
    local buttons = self.config.buttons
    local tap = self.config.tap or {}
    local purgatoryPosition = context.purgatoryPosition
    local abyssPosition = context.abyssPosition
    local deckPosition = context.deckPosition
    local purgatoryLiteral = "nil"
    local abyssLiteral = "nil"
    local deckLiteral = "nil"
    local fieldIdLiteral = "nil"

    if type(purgatoryPosition) == "table" then
        purgatoryLiteral = vectorLiteral(purgatoryPosition, {0, 0, 0})
    end

    if type(abyssPosition) == "table" then
        abyssLiteral = vectorLiteral(abyssPosition, {0, 0, 0})
    end

    if type(deckPosition) == "table" then
        deckLiteral = vectorLiteral(deckPosition, {0, 0, 0})
    end

    if type(context.fieldId) == "string" and context.fieldId ~= "" then
        fieldIdLiteral = quoted(context.fieldId)
    end

    return table.concat({
        "local cardContext = {",
        "fieldId = " .. fieldIdLiteral .. ",",
        "purgatoryPosition = " .. purgatoryLiteral .. ",",
        "abyssPosition = " .. abyssLiteral .. ",",
        "deckPosition = " .. deckLiteral .. ",",
        "cardScale = "
            .. vectorLiteral(context.cardScale, {1, 1, 1}) .. ",",
        "untappedRotationY = "
            .. tostring(tonumber(context.untappedRotationY) or 0) .. ",",
        "tapSideRotationDegrees = "
            .. tostring(tonumber(tap.sideRotationDegrees) or 90) .. ",",
        "tapRotationToleranceDegrees = "
            .. tostring(tonumber(tap.rotationToleranceDegrees) or 5) .. ",",
        "previewImageUrl = " .. quoted(context.previewImageUrl) .. ",",
        "drawButtons = "
            .. tostring(self.debugConfig.drawCardButtons == true) .. ",",
        "actionsButtonPosition = "
            .. vectorLiteral(buttons.actions.position, {0, 0.3, -2.2})
            .. ",",
        "actionsButtonWidth = "
            .. tostring(tonumber(buttons.actions.width) or 1200) .. ",",
        "actionsButtonHeight = "
            .. tostring(tonumber(buttons.actions.height) or 500) .. ",",
        "actionsLiftHeight = "
            .. tostring(tonumber(buttons.actions.liftHeight) or 0) .. ",",
        "}"
    }, "\n")
end

function CardScriptBuilder:build(featureIds, context)
    local descriptors = self.registry:resolve(featureIds)
    local chunks = {
        self:makeContextSource(context),
        self.runtimeSource.buildBootstrap(descriptors)
    }

    for _, descriptor in ipairs(descriptors) do
        chunks[#chunks + 1] = descriptor.source
    end

    chunks[#chunks + 1] = self.runtimeSource.getLifecycle()
    return table.concat(chunks, "\n")
end

return CardScriptBuilder

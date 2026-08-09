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
    local actionList = buttons.actionList
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
                local size = descriptor.sizeSource == "actionList"
                    and actionList or buttonConfig

                runtimeConfig[key] = {
                    position = buttonConfig.position,
                    width = size.width,
                    height = size.height
                }
            end
        end
    end

    return runtimeConfig
end

function CardScriptBuilder:makeContextSource(context)
    context = context or {}
    local buttons = self.config.buttons
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
        "drawButtons = "
            .. tostring(self.debugConfig.drawCardButtons == true) .. ",",
        "actionsButtonPosition = "
            .. vectorLiteral(buttons.actions.position, {0, 0.3, -2.2})
            .. ",",
        "actionsButtonWidth = "
            .. tostring(tonumber(buttons.actions.width) or 1200) .. ",",
        "actionsButtonHeight = "
            .. tostring(tonumber(buttons.actions.height) or 500) .. ",",
        "destroyButtonPosition = "
            .. vectorLiteral(buttons.destroy.position, {1.8, 0.3, 0})
            .. ",",
        "destroyButtonWidth = "
            .. tostring(tonumber(buttons.actionList.width) or 900) .. ",",
        "destroyButtonHeight = "
            .. tostring(tonumber(buttons.actionList.height) or 500) .. ",",
        "damnButtonPosition = "
            .. vectorLiteral(buttons.damn.position, {1.8, 0.3, -0.3})
            .. ",",
        "damnButtonWidth = "
            .. tostring(tonumber(buttons.actionList.width) or 900) .. ",",
        "damnButtonHeight = "
            .. tostring(tonumber(buttons.actionList.height) or 500) .. ",",
        "unequipButtonPosition = "
            .. vectorLiteral(buttons.unequip.position, {1.8, 0.3, 0.3})
            .. ",",
        "unequipButtonWidth = "
            .. tostring(tonumber(buttons.actionList.width) or 900) .. ",",
        "unequipButtonHeight = "
            .. tostring(tonumber(buttons.actionList.height) or 500) .. ",",
        "returnToHandButtonPosition = "
            .. vectorLiteral(
                buttons.returnToHand.position,
                {1.8, 0.3, 0.9}
            ) .. ",",
        "returnToHandButtonWidth = "
            .. tostring(tonumber(buttons.actionList.width) or 900)
            .. ",",
        "returnToHandButtonHeight = "
            .. tostring(tonumber(buttons.actionList.height) or 500)
            .. ",",
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

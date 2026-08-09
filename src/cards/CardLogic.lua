local CardFeatureRegistry = require("src/cards/CardFeatureRegistry")
local CardHostService = require("src/cards/CardHostService")
local CardScriptBuilder = require("src/cards/CardScriptBuilder")
local Rotate90 = require("src/cards/features/Rotate90")
local FieldActions = require("src/cards/features/FieldActions")

local CardLogic = {}
local featureRegistry = CardFeatureRegistry.new()

featureRegistry:register(Rotate90)
featureRegistry:register(FieldActions)

local scriptBuilder = CardScriptBuilder.new({
    registry = featureRegistry
})

-- Compatibility facade -----------------------------------------------------
-- Game, DeckGenerator, Global callbacks, and external tests can keep using
-- the original CardLogic API while each responsibility lives in a focused
-- module behind it.

CardLogic.removeAllButtons = CardHostService.removeAllButtons
CardLogic.removeButtonsIfInHand = CardHostService.removeButtonsIfInHand
CardLogic.scheduleHandButtonCleanup =
    CardHostService.scheduleHandButtonCleanup
CardLogic.suppressButtonsUntilPlaced =
    CardHostService.suppressButtonsUntilPlaced
CardLogic.returnToHandThroughDeck =
    CardHostService.returnToHandThroughDeck
CardLogic.reloadAndReturnToHand =
    CardHostService.reloadAndReturnToHand
CardLogic.isTappedRotation = CardHostService.isTappedRotation

function CardLogic.refreshExistingButtons()
    return CardHostService.refreshExistingButtons(
        featureRegistry:getDescriptors()
    )
end

function CardLogic.registerFeature(name, source, enabledByDefault)
    local previous = nil

    if type(name) == "string" and name ~= "" then
        previous = featureRegistry:get(name)
    end

    featureRegistry:replace({
        id = name,
        source = source,
        stateVersion = previous and previous.stateVersion or nil,
        enabledByDefault = enabledByDefault == true
            or (previous ~= nil and previous.enabledByDefault == true),
        hasTap = previous ~= nil and previous.hasTap == true,
        usesButtons = previous ~= nil and previous.usesButtons == true,
        buttonCallbacks = previous and previous.buttonCallbacks or nil,
        runtimeConfigKeys = previous and previous.runtimeConfigKeys or nil,
        hostButtons = previous and previous.hostButtons or nil
    })
end

function CardLogic.registerFeatureDescriptor(descriptor)
    return featureRegistry:register(descriptor)
end

function CardLogic.getFeatureDescriptors()
    return featureRegistry:getDescriptors()
end

function CardLogic.getButtonConfig()
    return scriptBuilder:getButtonConfig()
end

function CardLogic.getPreviewConfig()
    local config = require("src/config/CardLogicConfig")
    return config.preview
end

function CardLogic.build(featureNames, context)
    return scriptBuilder:build(featureNames, context)
end

return CardLogic

local CardFieldController = require("src/card_fields/CardFieldController")

local CardFields = {}
local defaultController = CardFieldController.new()

function CardFields.new(dependencies)
    return CardFieldController.new(dependencies)
end

function CardFields.setDefaultController(controller)
    if type(controller) ~= "table" then
        error("CardFields default controller must be a table.", 2)
    end

    defaultController = controller
    return defaultController
end

function CardFields.configureDefaultDependencies(dependencies)
    return CardFields.setDefaultController(
        CardFieldController.new(dependencies)
    )
end

function CardFields.getDefaultController()
    return defaultController
end

function CardFields.renewDeckSlotButton(playerColor)
    return defaultController:renewDeckSlotButton(playerColor)
end

function CardFields.onLoad(savedState)
    return defaultController:onLoad(savedState)
end

function CardFields.getSaveState()
    return defaultController:getSaveState()
end

function CardFields.getFields()
    return defaultController:getFields()
end

function CardFields.getCardFieldDestination(fieldId, destination)
    return defaultController:getCardFieldDestination(fieldId, destination)
end

function CardFields.onDeckSlotClicked(surface, playerColor)
    return defaultController:onDeckSlotClicked(surface, playerColor)
end

function CardFields.onDeckMenuUiClicked(playerColor, action)
    return defaultController:onDeckMenuUiClicked(playerColor, action)
end

function CardFields.onObjectPickUp(object)
    return defaultController:onObjectPickUp(object)
end

function CardFields.onObjectDrop(object)
    return defaultController:onObjectDrop(object)
end

function CardFields.onCardLeavesActionZone(object)
    return defaultController:onCardLeavesActionZone(object)
end

function CardFields.onActionStackNavigationClicked(object, direction)
    return defaultController:onActionStackNavigationClicked(
        object,
        direction
    )
end

function CardFields.onActionZoneCardRotationChanged(object, rotated)
    return defaultController:onActionZoneCardRotationChanged(
        object,
        rotated
    )
end

function CardFields.registerZoneBehavior(zoneType, behavior)
    return defaultController:registerZoneBehavior(zoneType, behavior)
end

return CardFields

local ActionZoneController =
    require("src/card_fields/zones/ActionZoneController")

local ActionZone = {}
local defaultController = ActionZoneController.new()

function ActionZone.new(dependencies)
    return ActionZoneController.new(dependencies)
end

function ActionZone.setDefaultController(controller)
    if type(controller) ~= "table" then
        error("ActionZone default controller must be a table.", 2)
    end

    defaultController = controller
    return defaultController
end

function ActionZone.configureDefaultDependencies(dependencies)
    return ActionZone.setDefaultController(
        ActionZoneController.new(dependencies)
    )
end

function ActionZone.getDefaultController()
    return defaultController
end

function ActionZone.contains(field, position)
    return defaultController:contains(field, position)
end

function ActionZone.findField(fields, position)
    return defaultController:findField(fields, position)
end

function ActionZone.getSnapPositions(field, cardCount)
    return defaultController:getSnapPositions(field, cardCount)
end

function ActionZone.arrange(field, preferredCard, objects, excludedCard)
    return defaultController:arrange(
        field,
        preferredCard,
        objects,
        excludedCard
    )
end

function ActionZone.refresh(fields, objects)
    return defaultController:refresh(fields, objects)
end

function ActionZone.onLoad(fields, savedState)
    return defaultController:onLoad(fields, savedState)
end

function ActionZone.getSaveState(fields)
    return defaultController:getSaveState(fields)
end

function ActionZone.onCardLeaves(fields, object, objects)
    return defaultController:onCardLeaves(fields, object, objects)
end

function ActionZone.onObjectPickUp(fields, object, objects)
    return defaultController:onObjectPickUp(fields, object, objects)
end

function ActionZone.onObjectDrop(fields, object, objects)
    return defaultController:onObjectDrop(fields, object, objects)
end

function ActionZone.onStackNavigationClicked(
    fields,
    object,
    direction,
    objects,
    context
)
    return defaultController:navigateStack(
        fields,
        object,
        direction,
        objects,
        context
    )
end

function ActionZone.navigateStack(fields, object, direction, objects, context)
    return defaultController:navigateStack(
        fields,
        object,
        direction,
        objects,
        context
    )
end

function ActionZone.getStackCards(fields, object, objects)
    return defaultController:getStackCards(fields, object, objects)
end

function ActionZone.onCardRotationChanged(fields, object, rotated, objects)
    return defaultController:onCardRotationChanged(
        fields,
        object,
        rotated,
        objects
    )
end

return ActionZone

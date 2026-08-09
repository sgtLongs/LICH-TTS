local Game = require("src/Game")

function onLoad(saveState)
    Game.onLoad(saveState)
    Wait.time(Game.refreshCardButtons, 0.5)
end

function onSave()
    return Game.onSave()
end

function getCardButtonConfig()
    return JSON.encode(Game.getCardButtonConfig())
end

function showCardPreview(parameters)
    if type(parameters) ~= "table" then
        return false
    end

    return Game.showCardPreview(
        parameters.card,
        parameters.playerColor,
        parameters.imageUrl
    )
end

function hideCardPreview(parameters)
    if type(parameters) ~= "table" then
        return false
    end

    return Game.hideCardPreview(parameters.card, parameters.playerColor)
end

function getCardFieldDestination(parameters)
    if type(parameters) ~= "table" then
        return nil
    end

    return Game.getCardFieldDestination(
        parameters.fieldId,
        parameters.destination
    )
end

function onObjectHover(playerColor, object)
    Game.onObjectHover(playerColor, object)
end

function onObjectPickUp(playerColor, object)
    return Game.onObjectPickUp(playerColor, object)
end

function onObjectDrop(playerColor, object)
    return Game.onObjectDrop(playerColor, object)
end

function onObjectLeaveContainer(container, object)
    Game.onObjectLeaveContainer(container, object)
end

function onObjectEnterZone(zone, object)
    Game.onObjectEnterZone(zone, object)
end

function returnCardToHandThroughDeck(parameters)
    if type(parameters) ~= "table" then
        return false
    end

    return Game.returnCardToHandThroughDeck(
        parameters.card,
        parameters.deck,
        parameters.playerColor
    )
end

function onCardLeavesActionZone(parameters)
    if type(parameters) ~= "table" then
        return false
    end

    return Game.onCardLeavesActionZone(parameters.card)
end

function onActionStackUpClicked(object, playerColor, altClick)
    return Game.onActionStackUpClicked(object)
end

function onActionStackDownClicked(object, playerColor, altClick)
    return Game.onActionStackDownClicked(object)
end

function onActionZoneCardRotationChanged(parameters)
    if type(parameters) ~= "table" then
        return false
    end

    return Game.onActionZoneCardRotationChanged(
        parameters.card,
        parameters.rotated
    )
end

function onEndTurnClicked(player, value, id)
    Game.onEndTurnClicked(player.color)
end

function onAdvancePhaseClicked(player, value, id)
    Game.onAdvancePhaseClicked(player.color)
end

function onHexGridClicked(object, playerColor, altClick)
    Game.onHexGridClicked(playerColor, altClick)
end

function onCardFieldDeckSlotClicked(object, playerColor, altClick)
    Game.onCardFieldDeckSlotClicked(object, playerColor)
end

function onDeckSelectionUiClicked(player, action, id)
    Game.onDeckSelectionUiClicked(player.color, action)
end

function onHexGridObjectClicked(object, playerColor, altClick)
    Game.onHexGridObjectClicked(object, playerColor, altClick)
end

function onHexGridMenuUiClicked(player, action, id)
    Game.onHexGridMenuUiClicked(player.color, action)
end

function onSurfaceUiClicked(player, action, id)
    return Game.onSurfaceUiClicked(player.color, action)
end

function onHexGridSpawnSelectorUiClicked(player, action, id)
    return Game.onHexGridSpawnSelectorUiClicked(player.color, action)
end

function onSettingsUiClicked(player, action, id)
    Game.onSettingsUiClicked(player.color, action)
end

function onSettingsJsonEdited(player, value, id)
    Game.onSettingsJsonEdited(player.color, value)
end

function onSettingsBoardNameEdited(player, value, id)
    Game.onSettingsBoardNameEdited(player.color, value)
end

function onSettingsEditModeChanged(player, value, id)
    Game.onSettingsEditModeChanged(player.color, value)
end

function onDungeonMapUiClicked(player, action, id)
    Game.onDungeonMapUiClicked(player.color, action)
end

function onPlayerAction(player, action, targets)
    return Game.onPlayerAction(player, action, targets)
end

function onScriptingButtonDown(index, playerColor)
    return Game.onScriptingButtonDown(index, playerColor)
end

function onObjectNumberTyped(object, playerColor, number, alt)
    return Game.onObjectNumberTyped(object, playerColor, number, alt)
end

function onHeroIntelligenceIncreaseClicked(object, playerColor)
    return Game.onHeroIntelligenceIncreaseClicked(object, playerColor)
end

function onHeroIntelligenceDecreaseClicked(object, playerColor)
    return Game.onHeroIntelligenceDecreaseClicked(object, playerColor)
end

function onHeroHealthIncreaseClicked(object, playerColor)
    return Game.onHeroHealthIncreaseClicked(object, playerColor)
end

function onHeroHealthDecreaseClicked(object, playerColor)
    return Game.onHeroHealthDecreaseClicked(object, playerColor)
end

function onHeroHealthIncreaseFiveClicked(object, playerColor)
    return Game.onHeroHealthIncreaseFiveClicked(object, playerColor)
end

function onHeroHealthDecreaseFiveClicked(object, playerColor)
    return Game.onHeroHealthDecreaseFiveClicked(object, playerColor)
end

function onActionPoint1Clicked(object, playerColor)
    return Game.onActionPoint1Clicked(object, playerColor)
end

function onActionPoint2Clicked(object, playerColor)
    return Game.onActionPoint2Clicked(object, playerColor)
end

function onActionPoint3Clicked(object, playerColor)
    return Game.onActionPoint3Clicked(object, playerColor)
end

function onActionPoint4Clicked(object, playerColor)
    return Game.onActionPoint4Clicked(object, playerColor)
end

function onObjectDestroy(object)
    Game.onObjectDestroy(object)
end

function onPlayerConnect(player)
    Game.onPlayerConnect()
end

local GameSaveCodec = require("src/persistence/GameSaveCodec")

local GameController = {}
GameController.__index = GameController

local function required(dependencies, name)
    local value = dependencies[name]

    if value == nil then
        error("GameController requires " .. name .. ".", 3)
    end

    return value
end

function GameController.new(dependencies)
    dependencies = dependencies or {}

    return setmetatable({
        cardFields = required(dependencies, "cardFields"),
        cardLogic = required(dependencies, "cardLogic"),
        dungeonMap = required(dependencies, "dungeonMap"),
        hexGrid = required(dependencies, "hexGrid"),
        settingsMenu = required(dependencies, "settingsMenu"),
        turnSystem = required(dependencies, "turnSystem"),
        runtime = required(dependencies, "runtime"),
        codec = dependencies.codec or GameSaveCodec,
        json = dependencies.json,
        savedBoardCatalog = dependencies.savedBoardCatalog,
        boardLoadCoordinator = dependencies.boardLoadCoordinator,
        uiAdapter = dependencies.uiAdapter,
        cardPreview = nil
    }, GameController)
end

function GameController:getJson()
    return self.json or JSON
end

function GameController:getSaveState()
    return {
        cardFields = self.cardFields.getSaveState(),
        dungeonMap = self.dungeonMap.getSaveState(),
        hexGrid = self.hexGrid.getSaveState(),
        settings = self.settingsMenu.getSaveState(),
        turnSystem = self.turnSystem.getSaveState()
    }
end

function GameController:encodeSaveState()
    return self.codec.encode(self:getSaveState(), self:getJson())
end

function GameController:persistState()
    local encodedState = self:encodeSaveState()
    local stateUpdated, updateError = pcall(function()
        if self.runtime.setGlobalScriptState(encodedState) == false then
            error("Global script state did not retain the saved data.")
        end
    end)

    if not stateUpdated then
        self.runtime.log(
            "Could not immediately update Global script state: "
                .. tostring(updateError)
        )
    end

    pcall(self.runtime.storeRewindState, function()
    end, false)

    return stateUpdated
end

function GameController:onLoad(saveState)
    local savedGame, decodeError = self.codec.decode(
        saveState,
        self:getJson()
    )

    if decodeError ~= nil then
        self.runtime.log("Game save ignored: " .. decodeError)
    end

    self.turnSystem.onLoad(savedGame.turnSystem)
    self.cardFields.onLoad(savedGame.cardFields)
    self.hexGrid.onLoad(savedGame.hexGrid)

    local function persistState()
        return self:persistState()
    end

    self.settingsMenu.initialize({
        getBoardState = self.hexGrid.getBoardState,
        getBoardStateJson = self.hexGrid.getBoardStateJson,
        loadBoardState = self.hexGrid.loadBoardState,
        loadBoardStateJson = self.hexGrid.loadBoardStateJson,
        onBoardLoadStarted = self.dungeonMap.onExternalBoardLoadStarted,
        onBoardLoadCompleted = self.dungeonMap.onExternalBoardLoadCompleted,
        onSavedBoardsChanged = self.dungeonMap.onSavedBoardsChanged,
        setEditMode = self.hexGrid.setEditMode,
        renewDeckSlotButton = self.cardFields.renewDeckSlotButton,
        restartGame = function(playerColor)
            return self:restartGame(playerColor)
        end,
        persistState = persistState,
        savedBoardCatalog = self.savedBoardCatalog,
        boardLoadCoordinator = self.boardLoadCoordinator,
        uiAdapter = self.uiAdapter
    }, savedGame.settings)
    self.dungeonMap.initialize({
        getSavedBoardSummaries = self.settingsMenu.getSavedBoardSummaries,
        loadSavedBoardById = self.settingsMenu.loadSavedBoardById,
        persistState = persistState,
        savedBoardCatalog = self.savedBoardCatalog,
        boardLoadCoordinator = self.boardLoadCoordinator,
        uiAdapter = self.uiAdapter
    }, savedGame.dungeonMap)
end

function GameController:restartGame()
    local objectsToDestroy = {}
    local seenObjects = {}
    local succeeded = true

    local function include(object)
        if object ~= nil and not seenObjects[object] then
            seenObjects[object] = true
            objectsToDestroy[#objectsToDestroy + 1] = object
        end
    end

    for _, object in ipairs(self.runtime.getAllObjects()) do
        if object.tag == "Card" or object.tag == "Deck" then
            include(object)
        end
    end

    for _, player in ipairs(self.runtime.getPlayers()) do
        if type(player.getHandObjects) == "function" then
            local succeeded, handObjects = pcall(player.getHandObjects)

            if succeeded and type(handObjects) == "table" then
                for _, object in ipairs(handObjects) do
                    include(object)
                end
            end
        end
    end

    for _, object in ipairs(objectsToDestroy) do
        local destroyed, destroyError = pcall(
            self.runtime.destroyObject,
            object
        )

        if not destroyed then
            succeeded = false
            self.runtime.log(
                "Could not clear a card or deck during restart: "
                    .. tostring(destroyError)
            )
        end
    end

    self.cardFields.resetForRestart()
    self.turnSystem.resetForRestart()
    if not self.hexGrid.clearSurfacesForRestart() then
        succeeded = false
    end
    self:persistState()
    return succeeded
end

function GameController:onSave()
    return self:encodeSaveState()
end

function GameController:onObjectHover()
    self.hexGrid.onObjectHover()
end

function GameController:onEndTurnClicked(playerColor)
    self.turnSystem.endTurn(playerColor)
end

function GameController:getCardButtonConfig()
    return self.cardLogic.getButtonConfig()
end

function GameController:showCardPreview(card, playerColor, imageUrl)
    local previewConfig = type(self.cardLogic.getPreviewConfig) == "function"
        and self.cardLogic.getPreviewConfig() or nil

    if card == nil
        or type(playerColor) ~= "string"
        or playerColor == ""
        or type(imageUrl) ~= "string"
        or imageUrl == ""
        or type(previewConfig) ~= "table"
        or self.uiAdapter == nil
    then
        return false
    end

    if self.cardPreview ~= nil then
        self:hideCardPreview(
            self.cardPreview.card,
            self.cardPreview.playerColor
        )
    end

    self.cardPreview = {card = card, playerColor = playerColor}
    self.uiAdapter.setAttribute(previewConfig.imageId, "image", imageUrl)
    self.uiAdapter.setAttribute(
        previewConfig.rootId,
        "visibility",
        playerColor
    )
    self.uiAdapter.setAttribute(previewConfig.rootId, "active", "true")

    if type(card.highlightOn) == "function" then
        local configured = previewConfig.glowColor or {}
        card.highlightOn({
            r = tonumber(configured.r or configured[1]) or 0.15,
            g = tonumber(configured.g or configured[2]) or 0.7,
            b = tonumber(configured.b or configured[3]) or 1
        })
    end

    return true
end

function GameController:hideCardPreview(card, playerColor)
    local preview = self.cardPreview

    if preview == nil
        or preview.card ~= card
        or preview.playerColor ~= playerColor
    then
        return false
    end

    local previewConfig = self.cardLogic.getPreviewConfig()
    self.cardPreview = nil

    if self.uiAdapter == nil or type(previewConfig) ~= "table" then
        return false
    end

    self.uiAdapter.setAttribute(previewConfig.rootId, "active", "false")

    if type(card.highlightOff) == "function" then
        card.highlightOff()
    end

    if type(card.call) == "function" then
        pcall(card.call, "hideCardActions")
    end

    return true
end

function GameController:onCardPreviewActionClicked(playerColor, action)
    local preview = self.cardPreview
    local validActions = {
        destroy = true,
        damn = true,
        unequip = true,
        returnToHand = true
    }

    if preview == nil
        or preview.playerColor ~= playerColor
        or validActions[action] ~= true
        or type(preview.card.call) ~= "function"
    then
        return false
    end

    local card = preview.card
    self:hideCardPreview(card, playerColor)
    local succeeded, handled = pcall(
        card.call,
        "onPreviewCardActionClicked",
        {action = action, playerColor = playerColor}
    )
    return succeeded and handled == true
end

function GameController:getCardFieldDestination(fieldId, destination)
    return self.cardFields.getCardFieldDestination(fieldId, destination)
end

function GameController:refreshCardButtons()
    self.cardLogic.refreshExistingButtons()
end

function GameController:onAdvancePhaseClicked(playerColor)
    return self.turnSystem.advancePhase(playerColor)
end

function GameController:onHexGridClicked(playerColor, altClick)
    self.hexGrid.onClicked(playerColor, altClick)
end

function GameController:onCardFieldDeckSlotClicked(object, playerColor)
    self.cardFields.onDeckSlotClicked(object, playerColor)
end

function GameController:onDeckSelectionUiClicked(playerColor, action)
    self.cardFields.onDeckMenuUiClicked(playerColor, action)
end

function GameController:onHeroIntelligenceIncreaseClicked(object, playerColor)
    return self.cardFields.onHeroIntelligenceIncreaseClicked(
        object, playerColor
    )
end

function GameController:onHeroIntelligenceDecreaseClicked(object, playerColor)
    return self.cardFields.onHeroIntelligenceDecreaseClicked(
        object, playerColor
    )
end

function GameController:onHeroHealthIncreaseClicked(object, playerColor)
    return self.cardFields.onHeroHealthIncreaseClicked(object, playerColor)
end

function GameController:onHeroHealthDecreaseClicked(object, playerColor)
    return self.cardFields.onHeroHealthDecreaseClicked(object, playerColor)
end

function GameController:onHeroHealthIncreaseFiveClicked(object, playerColor)
    return self.cardFields.onHeroHealthIncreaseFiveClicked(
        object, playerColor
    )
end

function GameController:onHeroHealthDecreaseFiveClicked(object, playerColor)
    return self.cardFields.onHeroHealthDecreaseFiveClicked(
        object, playerColor
    )
end

function GameController:onActionPointClicked(index, object, playerColor)
    return self.cardFields.onActionPointClicked(index, object, playerColor)
end

function GameController:onObjectPickUp(_, object)
    return self.cardFields.onObjectPickUp(object)
end

function GameController:onObjectDrop(_, object)
    local handled = self.cardFields.onObjectDrop(object)
    self.cardLogic.scheduleHandButtonCleanup(object)
    return handled
end

function GameController:onObjectLeaveContainer(_, object)
    self.cardLogic.suppressButtonsUntilPlaced(object)
end

function GameController:onObjectEnterZone(zone, object)
    if zone ~= nil and (zone.tag == "Hand" or zone.type == "Hand") then
        self.cardLogic.removeAllButtons(object)
    end

    self.cardLogic.scheduleHandButtonCleanup(object)
end

function GameController:returnCardToHandThroughDeck(card, deck, playerColor)
    if deck == nil then
        return self.cardLogic.reloadAndReturnToHand(card, playerColor)
    end

    return self.cardLogic.returnToHandThroughDeck(card, deck, playerColor)
end

function GameController:onCardLeavesActionZone(object)
    local handled = self.cardFields.onCardLeavesActionZone(object)
    self.cardLogic.scheduleHandButtonCleanup(object)
    return handled
end

function GameController:onActionStackUpClicked(object)
    return self.cardFields.onActionStackNavigationClicked(object, -1)
end

function GameController:onActionStackDownClicked(object)
    return self.cardFields.onActionStackNavigationClicked(object, 1)
end

function GameController:onActionZoneCardRotationChanged(object, rotated)
    return self.cardFields.onActionZoneCardRotationChanged(object, rotated)
end

function GameController:onHexGridObjectClicked(object, playerColor, altClick)
    self.hexGrid.onObjectClicked(object, playerColor, altClick)
end

function GameController:onHexGridMenuUiClicked(playerColor, action)
    self.hexGrid.onMenuUiClicked(playerColor, action)
end

function GameController:onSurfaceUiClicked(playerColor, action)
    return self.hexGrid.onSurfaceUiClicked(playerColor, action)
end

function GameController:onHexGridSpawnSelectorUiClicked(playerColor, action)
    return self.hexGrid.onSpawnSelectorUiClicked(playerColor, action)
end

function GameController:onSettingsUiClicked(playerColor, action)
    self.settingsMenu.handleAction(playerColor, action)
end

function GameController:onSettingsJsonEdited(playerColor, value)
    self.settingsMenu.onJsonEdited(playerColor, value)
end

function GameController:onSettingsBoardNameEdited(playerColor, value)
    self.settingsMenu.onBoardNameEdited(playerColor, value)
end

function GameController:onSettingsEditModeChanged(playerColor, value)
    self.settingsMenu.onEditModeChanged(playerColor, value)
end

function GameController:onDungeonMapUiClicked(playerColor, action)
    self.dungeonMap.handleAction(playerColor, action)
end

function GameController:onPlayerAction(player, action, targets)
    if self.cardPreview ~= nil
        and player ~= nil
        and player.color == self.cardPreview.playerColor
    then
        self:hideCardPreview(
            self.cardPreview.card,
            self.cardPreview.playerColor
        )
    end

    return self.hexGrid.onPlayerAction(player, action, targets)
end

function GameController:onScriptingButtonDown(index, playerColor)
    return self.hexGrid.onScriptingButtonDown(index, playerColor)
end

function GameController:onObjectNumberTyped(object, playerColor, number, alt)
    return self.hexGrid.onObjectNumberTyped(object, playerColor, number, alt)
end

function GameController:onObjectDestroy(object)
    if self.cardPreview ~= nil and self.cardPreview.card == object then
        self:hideCardPreview(object, self.cardPreview.playerColor)
    end

    self.hexGrid.onObjectDestroy(object)
end

function GameController:onPlayerConnect()
    self.cardFields.refreshDeckSlotGlow()
    self.turnSystem.refreshUi()
end

return GameController

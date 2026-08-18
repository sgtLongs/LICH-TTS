local GameSaveCodec = require("src/persistence/GameSaveCodec")
local MockPlayerFeature = require(
    "src/mock_players/MockPlayerFeature"
)

local GameController = {}
GameController.__index = GameController

local function isObjectReference(value)
    local valueType = type(value)
    return valueType == "table" or valueType == "userdata"
end

local function previewContainsCard(preview, card)
    if type(preview) ~= "table" or card == nil then
        return false
    end

    for _, stackCard in ipairs(preview.stackCards or {}) do
        if stackCard == card then
            return true
        end
    end

    return false
end

local function targetsPreviewStack(preview, targets)
    if type(preview) ~= "table" or type(targets) ~= "table" then
        return false
    end

    local targetObjects = targets

    if targets.tag ~= nil or type(targets.getGUID) == "function" then
        targetObjects = {targets}
    end

    for _, target in pairs(targetObjects) do
        local object = type(target) == "table"
            and (target.object or target.target or target) or target

        if previewContainsCard(preview, object) then
            return true
        end
    end

    return false
end

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
        mockPlayerFeature = dependencies.mockPlayerFeature
            or MockPlayerFeature,
        uiAdapter = dependencies.uiAdapter,
        scheduleFrames = dependencies.scheduleFrames or function(callback)
            callback()
        end,
        cardPreview = nil,
        cardPreviewGeneration = 0
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
        addMockPlayer = function()
            return self.mockPlayerFeature.addWithRandomDeck(
                self.turnSystem,
                self.cardFields
            )
        end,
        removeMockPlayer = self.turnSystem.removeMostRecentMockPlayer,
        disconnectMockPlayer =
            self.turnSystem.disconnectMostRecentMockPlayer,
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
            self.cardPreview.playerColor,
            true
        )
    end

    local stackCards = {card}
    local stackIndex = 1
    local stackPositions = {}

    if type(self.cardFields.getActionStackCards) == "function" then
        local cards, selectedIndex, positions =
            self.cardFields.getActionStackCards(card)

        if type(cards) == "table" and #cards > 0 then
            stackCards = cards
            stackIndex = tonumber(selectedIndex) or 1
            stackPositions = type(positions) == "table"
                and positions or {}

            for index, stackCard in ipairs(stackCards) do
                if stackCard == card then
                    stackIndex = index
                    break
                end
            end
        end
    end

    self.cardPreviewGeneration = self.cardPreviewGeneration + 1
    self.cardPreview = {
        card = card,
        triggerCard = card,
        playerColor = playerColor,
        stackCards = stackCards,
        stackIndex = stackIndex,
        stackPositions = stackPositions,
        globalLifts = {},
        navigationActive = false
    }
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

    if #stackCards > 1 then
        local preview = self.cardPreview
        local generation = self.cardPreviewGeneration

        self.scheduleFrames(function()
            if self.cardPreview ~= preview
                or self.cardPreviewGeneration ~= generation
            then
                return
            end

            for index, stackCard in ipairs(stackCards) do
                if stackCard ~= preview.triggerCard then
                    self:liftPreviewStackCard(
                        preview,
                        stackCard,
                        preview.stackPositions[index]
                    )
                end
            end
        end, 1)
    end

    return true
end

function GameController:getCardPreviewImageUrl(card)
    if card == nil then
        return nil
    end

    if type(card.call) == "function" then
        local succeeded, imageUrl = pcall(
            card.call,
            "getCardPreviewImageUrl"
        )

        if succeeded and type(imageUrl) == "string" and imageUrl ~= "" then
            return imageUrl
        end
    end

    if type(card.getCustomObject) == "function" then
        local succeeded, custom = pcall(card.getCustomObject)

        if succeeded and type(custom) == "table"
            and type(custom.face) == "string"
            and custom.face ~= ""
        then
            return custom.face
        end
    end

    if type(card.getData) ~= "function" then
        return nil
    end

    local succeeded, data = pcall(card.getData)

    if not succeeded or type(data) ~= "table"
        or type(data.CustomDeck) ~= "table"
    then
        return nil
    end

    local deckId = math.floor((tonumber(data.CardID) or 0) / 100)
    local deck = data.CustomDeck[deckId]
        or data.CustomDeck[tostring(deckId)]

    if type(deck) ~= "table" then
        for _, candidate in pairs(data.CustomDeck) do
            if type(candidate) == "table" then
                deck = candidate
                break
            end
        end
    end

    return type(deck) == "table"
        and type(deck.FaceURL) == "string"
        and deck.FaceURL ~= "" and deck.FaceURL or nil
end

function GameController:liftPreviewStackCard(preview, card, basePosition)
    if self.cardPreview ~= preview
        or type(card.getPosition) ~= "function"
    then
        return false
    end

    local position = type(basePosition) == "table"
        and basePosition or card.getPosition()

    if type(position) ~= "table" or tonumber(position.y) == nil then
        return false
    end

    local buttonConfig = type(self.cardLogic.getButtonConfig) == "function"
        and self.cardLogic.getButtonConfig() or {}
    local actions = type(buttonConfig.actions) == "table"
        and buttonConfig.actions or {}
    local liftHeight = tonumber(actions.liftHeight) or 0
    local lift = {
        card = card,
        position = {
            x = tonumber(position.x or position[1]) or 0,
            y = tonumber(position.y or position[2]) or 0,
            z = tonumber(position.z or position[3]) or 0
        },
        useGravity = card.use_gravity ~= false
    }
    preview.globalLifts[#preview.globalLifts + 1] = lift
    card.use_gravity = false
    local target = {
        x = lift.position.x,
        y = lift.position.y + liftHeight,
        z = lift.position.z
    }

    if type(card.setPositionSmooth) == "function" then
        card.setPositionSmooth(target, false, true)
    elseif type(card.setPosition) == "function" then
        card.setPosition(target)
    end

    return true
end

function GameController:restorePreviewStackLifts(preview)
    for _, lift in ipairs(preview.globalLifts or {}) do
        local card = lift.card

        if type(card.setPositionSmooth) == "function" then
            card.setPositionSmooth(lift.position, false, true)
        elseif type(card.setPosition) == "function" then
            card.setPosition(lift.position)
        end

        card.use_gravity = lift.useGravity
    end

    preview.globalLifts = {}
end

function GameController:hideCardPreview(card, playerColor, forceClose)
    local preview = self.cardPreview

    if preview == nil
        or (preview.card ~= card and preview.triggerCard ~= card)
        or preview.playerColor ~= playerColor
    then
        return false
    end

    -- Navigation changes which card owns the physical Actions trigger. Older
    -- generated cards close their preview when that trigger is disabled by
    -- the action-zone rearrangement. Ignore that card-local cleanup while the
    -- shared stack preview is navigating; explicit controller closes pass
    -- forceClose so outside clicks and preview actions still work.
    if preview.navigationActive
        and preview.triggerCard == card
        and forceClose ~= true
    then
        return false
    end

    local previewConfig = self.cardLogic.getPreviewConfig()
    self.cardPreviewGeneration = self.cardPreviewGeneration + 1
    preview.navigationActive = false
    self.cardPreview = nil

    if self.uiAdapter == nil or type(previewConfig) ~= "table" then
        return false
    end

    self.uiAdapter.setAttribute(previewConfig.rootId, "active", "false")

    self:restorePreviewStackLifts(preview)

    if type(preview.card.highlightOff) == "function" then
        preview.card.highlightOff()
    end

    if type(preview.triggerCard.call) == "function" then
        pcall(preview.triggerCard.call, "hideCardActions")
    end

    return true
end

function GameController:onCardPreviewStackClicked(playerColor, direction)
    local stackDirection = direction == "up" and -1
        or direction == "down" and 1 or nil

    if stackDirection == nil then
        return false
    end

    local routed, result = self:routeCardPreviewStackNavigation(
        playerColor,
        nil,
        stackDirection
    )
    return routed and result or false
end

function GameController:routeCardPreviewStackNavigation(
    playerColor,
    sourceCard,
    stackDirection
)
    local preview = self.cardPreview

    if preview == nil
        or preview.playerColor ~= playerColor
        or type(preview.stackCards) ~= "table"
        or #preview.stackCards < 2
        or (sourceCard ~= nil
            and not previewContainsCard(preview, sourceCard))
    then
        return false, false
    end

    return true, self:navigateCardPreviewStack(preview, stackDirection)
end

function GameController:navigateActionStack(card, direction, context)
    local navigate = self.cardFields.navigateActionStack
        or self.cardFields.onActionStackNavigationClicked

    if type(navigate) ~= "function" then
        return false
    end

    return navigate(card, direction, context)
end

function GameController:navigateCardPreviewStack(preview, stackDirection)
    if self.cardPreview ~= preview then
        return false
    end

    -- Begin the session before changing action-zone selection. A scheduler
    -- fallback may apply the selection synchronously, and older card scripts
    -- can request preview cleanup during that transfer.
    self.cardPreviewGeneration = self.cardPreviewGeneration + 1
    preview.navigationActive = true
    local arrowGeneration = self.cardPreviewGeneration
    self.scheduleFrames(function()
        if self.cardPreview == preview
            and self.cardPreviewGeneration == arrowGeneration
        then
            preview.navigationActive = false
        end
    end, 2)

    local selectedCard = self:navigateActionStack(
        preview.card,
        stackDirection,
        {preserveCardPreview = true}
    )

    -- Live TTS objects are userdata; tests and adapters commonly model them
    -- with tables. Both are valid navigation results.
    if not isObjectReference(selectedCard) then
        return false
    end

    local imageUrl = self:getCardPreviewImageUrl(selectedCard)

    if imageUrl == nil then
        return false
    end

    if type(preview.card.highlightOff) == "function" then
        preview.card.highlightOff()
    end

    self:restorePreviewStackLifts(preview)

    if type(preview.triggerCard.call) == "function" then
        pcall(
            preview.triggerCard.call,
            "releaseCardActionLiftForStackPreview"
        )
    end

    preview.card = selectedCard
    for index, stackCard in ipairs(preview.stackCards) do
        if stackCard == selectedCard then
            preview.stackIndex = index
            break
        end
    end
    local previewConfig = self.cardLogic.getPreviewConfig()
    self.uiAdapter.setAttribute(previewConfig.imageId, "image", imageUrl)

    if type(selectedCard.highlightOn) == "function" then
        local configured = previewConfig.glowColor or {}
        selectedCard.highlightOn({
            r = tonumber(configured.r or configured[1]) or 0.15,
            g = tonumber(configured.g or configured[2]) or 0.7,
            b = tonumber(configured.b or configured[3]) or 1
        })
    end

    local navigationGeneration = self.cardPreviewGeneration
    self.scheduleFrames(function()
        if self.cardPreview ~= preview
            or self.cardPreviewGeneration ~= navigationGeneration
        then
            return
        end

        local cards, selectedIndex, positions =
            self.cardFields.getActionStackCards(selectedCard)

        if type(cards) == "table" and #cards > 0 then
            preview.stackCards = cards
            preview.stackIndex = tonumber(selectedIndex)
                or preview.stackIndex
            preview.stackPositions = type(positions) == "table"
                and positions or {}
        end

        -- As with ActionZoneController:arrangeState, move the selected card
        -- last so overlapping cards render behind the card in the preview.
        local selectedPosition = nil

        for index, stackCard in ipairs(preview.stackCards) do
            if stackCard ~= selectedCard then
                self:liftPreviewStackCard(
                    preview,
                    stackCard,
                    preview.stackPositions[index]
                )
            else
                selectedPosition = preview.stackPositions[index]
            end
        end

        self:liftPreviewStackCard(
            preview,
            selectedCard,
            selectedPosition
        )
    end, 2)

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
    self:hideCardPreview(card, playerColor, true)
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

function GameController:onFirstPlayerUiClicked(playerColor, action)
    return self.turnSystem.onFirstPlayerUiClicked(playerColor, action)
end

function GameController:onPlayersUiClicked(playerColor, action)
    return self.turnSystem.onPlayersUiClicked(playerColor, action)
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

function GameController:onObjectRotate(object, spin)
    if type(self.cardLogic.isTappedRotation) ~= "function" then
        return false
    end

    local rotated = self.cardLogic.isTappedRotation(spin)
    return self.cardFields.onActionZoneCardRotationChanged(
        object,
        rotated
    )
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

function GameController:onActionStackUpClicked(object, playerColor)
    local routed, result = self:routeCardPreviewStackNavigation(
        playerColor,
        object,
        -1
    )

    if routed then
        return result
    end

    return self:navigateActionStack(object, -1)
end

function GameController:onActionStackDownClicked(object, playerColor)
    local routed, result = self:routeCardPreviewStackNavigation(
        playerColor,
        object,
        1
    )

    if routed then
        return result
    end

    return self:navigateActionStack(object, 1)
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
        if targetsPreviewStack(self.cardPreview, targets)
            or self.cardPreview.navigationActive
        then
            -- Selecting a card in the lifted stack or any selection event
            -- emitted during arrow navigation still targets this preview.
        else
            local preview = self.cardPreview
            local generation = self.cardPreviewGeneration

            -- TTS can report a Custom UI click as a table selection before
            -- the UI callback runs. Defer cleanup so a handled preview click
            -- can change the generation and cancel this pending close.
            self.scheduleFrames(function()
                if self.cardPreviewGeneration == generation
                    and self.cardPreview == preview
                then
                    self:hideCardPreview(
                        preview.card,
                        preview.playerColor,
                        true
                    )
                end
            end, 1)
        end
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
        self:hideCardPreview(
            object,
            self.cardPreview.playerColor,
            true
        )
    end

    self.hexGrid.onObjectDestroy(object)
end

function GameController:onPlayerConnect(player)
    self.cardFields.refreshDeckSlotGlow()
    if type(self.turnSystem.registerPlayer) == "function" then
        self.turnSystem.registerPlayer(player)
    else
        self.turnSystem.refreshUi()
    end
end

function GameController:onPlayerDisconnect()
    self.cardFields.refreshDeckSlotGlow()
    self.turnSystem.refreshUi()
end

return GameController

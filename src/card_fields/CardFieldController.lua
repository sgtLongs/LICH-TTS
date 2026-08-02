local Config = require("src/config/CardFieldConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local ActionZone = require("src/card_fields/ActionZone")
local CardFieldDefinitions =
    require("src/card_fields/CardFieldDefinitions")
local CardFieldLayout = require("src/card_fields/CardFieldLayout")
local CardFieldState = require("src/card_fields/CardFieldState")
local DeckSelectionMenu = require("src/card_fields/DeckSelectionMenu")
local ObjectAdapter = require("src/tts/ObjectAdapter")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local ZoneBehaviorRegistry =
    require("src/card_fields/zones/ZoneBehaviorRegistry")

local CardFieldController = {}
CardFieldController.__index = CardFieldController

local publicMethodNames = {
    "renewDeckSlotButton",
    "onLoad",
    "getSaveState",
    "getFields",
    "getCardFieldDestination",
    "onDeckSlotClicked",
    "onDeckMenuUiClicked",
    "onObjectPickUp",
    "onObjectDrop",
    "onCardLeavesActionZone",
    "onActionStackNavigationClicked",
    "onActionZoneCardRotationChanged",
    "registerZoneBehavior"
}

local function makeStaticActionBehavior(actionZone)
    return {
        saveKey = "actionZone",
        contains = actionZone.contains,
        onLoad = function(fields, savedState)
            return actionZone.onLoad(fields, savedState)
        end,
        getSaveState = function(fields)
            return actionZone.getSaveState(fields)
        end,
        refresh = function(fields, objects)
            return actionZone.refresh(fields, objects)
        end,
        onObjectPickUp = function(fields, object, objects)
            return actionZone.onObjectPickUp(fields, object, objects)
        end,
        onObjectDrop = function(fields, object, objects)
            return actionZone.onObjectDrop(fields, object, objects)
        end,
        onCardLeaves = function(fields, object, objects)
            return actionZone.onCardLeaves(fields, object, objects)
        end,
        onStackNavigationClicked = function(
            fields,
            object,
            direction,
            objects
        )
            return actionZone.onStackNavigationClicked(
                fields,
                object,
                direction,
                objects
            )
        end,
        onCardRotationChanged = function(
            fields,
            object,
            rotated,
            objects
        )
            return actionZone.onCardRotationChanged(
                fields,
                object,
                rotated,
                objects
            )
        end
    }
end

local function makeDefaultZoneBehaviors(dependencies)
    local registry = ZoneBehaviorRegistry.new()
    local actionZone = dependencies.actionZone

    if actionZone == nil then
        if type(ActionZone.new) == "function" then
            actionZone = ActionZone.new(dependencies.actionZoneDependencies)
        else
            actionZone = ActionZone
        end
    end

    local behavior = type(actionZone.asBehavior) == "function"
        and actionZone:asBehavior()
        or makeStaticActionBehavior(actionZone)
    registry:register("action", behavior)
    return registry
end

function CardFieldController.new(dependencies)
    dependencies = dependencies or {}
    local defaultRuntime = Runtime.default()
    local defaultScheduler = Scheduler.default()
    local runtime = dependencies.runtime or defaultRuntime
    local scheduler = dependencies.scheduler or defaultScheduler
    local controller = setmetatable({}, CardFieldController)
    controller.config = dependencies.config or Config
    controller.debugConfig = dependencies.debugConfig or DebugConfig
    controller.definitions = dependencies.definitions
        or CardFieldDefinitions.fromConfig(controller.config)
    controller.layout = dependencies.layout or CardFieldLayout
    controller.deckMenu = dependencies.deckMenu or DeckSelectionMenu
    controller.zoneBehaviors = dependencies.zoneBehaviors
        or makeDefaultZoneBehaviors(dependencies)
    controller.onDeckSpawned = dependencies.onDeckSpawned or function()
    end
    controller.objectAdapter = dependencies.objectAdapter or ObjectAdapter
    controller.getObjectFromGuid = dependencies.getObjectFromGUID
        or runtime.getObjectFromGUID
        or runtime.getObject
        or defaultRuntime.getObjectFromGUID
    controller.setVectorLines = dependencies.setVectorLines
        or runtime.setVectorLines
        or defaultRuntime.setVectorLines
    controller.waitTime = dependencies.waitTime
        or scheduler.time
        or runtime.waitTime
        or defaultScheduler.time
    controller.getGlobalOwner = dependencies.getGlobalOwner
        or runtime.getGlobalOwner
        or defaultRuntime.getGlobalOwner
    controller.log = dependencies.log or runtime.log or defaultRuntime.log
    controller.fields = {}
    controller.state = CardFieldState.new({}, nil)

    -- GameController consumes subsystem ports with dot calls, while feature
    -- tests and direct users commonly use colon calls. Keep both forms valid
    -- so a constructed controller can replace the compatibility facade.
    for _, methodName in ipairs(publicMethodNames) do
        local boundMethodName = methodName

        controller[boundMethodName] = function(first, ...)
            if first == controller then
                return CardFieldController[boundMethodName](
                    controller,
                    ...
                )
            end

            return CardFieldController[boundMethodName](
                controller,
                first,
                ...
            )
        end
    end

    return controller
end

function CardFieldController:removeDeckSlotButtons(surface)
    local buttons = self.objectAdapter.getButtons(surface)

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if button.click_function
            == self.config.deckSlot.clickFunction
        then
            self.objectAdapter.removeButton(surface, button.index)
        end
    end
end

function CardFieldController:addDeckSlotButton(field)
    local surface = self.getObjectFromGuid(field.surfaceObjectGuid)

    if surface == nil then
        self.log(
            "CardFields: could not find surface "
                .. tostring(field.surfaceObjectGuid)
                .. " for " .. field.playerColor .. "."
        )
        return false
    end

    self:removeDeckSlotButtons(surface)

    local ownerColor = CardFieldDefinitions.ownerColor(field)

    if CardFieldState.isDeckSpawned(self.state, field) then
        return true
    end

    field.onDeckSpawned = function()
        CardFieldState.setDeckSpawned(self.state, field, true)
        self.onDeckSpawned(ownerColor, field)

        local currentSurface = self.getObjectFromGuid(
            field.surfaceObjectGuid
        )

        if currentSurface ~= nil then
            self:removeDeckSlotButtons(currentSurface)
        end
    end

    local localPosition = surface.positionToLocal({
        x = field.deckSlot.x,
        y = field.deckSlot.y
            + self.config.deckSlot.buttonSurfaceOffset,
        z = field.deckSlot.z
    })
    local showDebug = self.debugConfig.drawCardFieldDeckButtons == true
    local buttonColor = showDebug
        and self.config.deckSlot.debugColor
        or self.config.deckSlot.invisibleButtonColor
    local fontColor = showDebug
        and self.config.deckSlot.debugFontColor
        or self.config.deckSlot.invisibleButtonColor

    self.objectAdapter.createButton(surface, {
        label = showDebug and self.config.deckSlot.debugLabel or "",
        click_function = self.config.deckSlot.clickFunction,
        function_owner = self.getGlobalOwner(),
        position = localPosition,
        rotation = {0, 0, 0},
        width = math.floor(
            self.config.deckSlot.buttonWidth * 100 + 0.5
        ),
        height = math.floor(
            self.config.deckSlot.buttonHeight * 100 + 0.5
        ),
        font_size = showDebug
            and self.config.deckSlot.debugFontSize or 1,
        color = buttonColor,
        font_color = fontColor,
        hover_color = showDebug
            and self.config.deckSlot.debugHoverColor or buttonColor,
        press_color = showDebug
            and self.config.deckSlot.debugPressColor or buttonColor,
        tooltip = "Choose a deck"
    })

    return true
end

function CardFieldController:refreshDeckSlotButtons()
    for _, field in ipairs(self.fields) do
        self:addDeckSlotButton(field)
    end
end

function CardFieldController:renewDeckSlotButton(playerColor)
    for _, field in ipairs(self.fields) do
        local ownerColor = CardFieldDefinitions.ownerColor(field)

        if ownerColor == playerColor then
            CardFieldState.setDeckSpawned(self.state, field, false)
            return self:addDeckSlotButton(field)
        end
    end

    return false
end

function CardFieldController:onLoad(savedState)
    self.deckMenu.initialize()

    local built = self.layout.buildAll(self.definitions)
    self.fields = built.fields
    self.state = CardFieldState.new(self.fields, savedState)
    self.zoneBehaviors:load(self.fields, savedState)

    -- Zone outlines are gameplay geometry and remain visible independently of
    -- the card-field debug controls.
    self.setVectorLines(built.lines)
    self:refreshDeckSlotButtons()

    self.waitTime(function()
        self.zoneBehaviors:refresh(self.fields)
    end, 0.5)

    -- Stateful cabinets can replace themselves after Global onLoad. Refresh
    -- once object-local load handlers have settled.
    self.waitTime(function()
        self:refreshDeckSlotButtons()
    end, 1)

    self.log(
        "CardFields: built " .. #self.fields
            .. " player fields with "
            .. self.config.columns .. "x" .. self.config.rows
            .. " spaces."
    )
end

function CardFieldController:getSaveState()
    local savedState = CardFieldState.save(self.state, self.fields)
    local savedZones = self.zoneBehaviors:save(self.fields)

    for key, value in pairs(savedZones) do
        savedState[key] = value
    end

    return savedState
end

function CardFieldController:getFields()
    return self.fields
end

function CardFieldController:getCardFieldDestination(fieldId, destination)
    local field = self.layout.findFieldById(self.fields, fieldId)

    if field == nil then
        return nil
    end

    if destination == "deck" then
        return self.layout.buttonAlignedDeckSpawnPosition(field)
    end

    if destination ~= "purgatory" and destination ~= "abyss" then
        return nil
    end

    local center = field.zoneCenters
        and field.zoneCenters[destination] or nil

    if center == nil then
        return nil
    end

    return {
        x = center.x,
        y = center.y + self.config.deckSlot.cardSpawnHeight,
        z = center.z
    }
end

function CardFieldController:onDeckSlotClicked(surface, playerColor)
    local guid = surface.getGUID()
    local field = self.layout.findFieldBySurface(self.fields, guid)

    if field ~= nil then
        local ownerColor = CardFieldDefinitions.ownerColor(field)

        if playerColor ~= ownerColor then
            self.log(
                tostring(playerColor)
                    .. " cannot spawn a deck on "
                    .. ownerColor .. "'s field."
            )
            return false
        end

        local spawnPosition =
            self.layout.buttonAlignedDeckSpawnPosition(field)
        self.log(
            "Deck slot clicked for " .. field.playerColor
                .. " at button-aligned x="
                .. tostring(spawnPosition.x)
                .. ", z=" .. tostring(spawnPosition.z)
                .. " (row " .. self.config.deckSlot.row
                .. ", column " .. self.config.deckSlot.column .. ")."
        )
        return self.deckMenu.open(playerColor, field, spawnPosition)
    end

    self.log("CardFields: clicked deck slot did not match a card field.")
    return false
end

function CardFieldController:onDeckMenuUiClicked(playerColor, action)
    return self.deckMenu.handleAction(playerColor, action)
end

function CardFieldController:onObjectPickUp(object)
    return self.zoneBehaviors:dispatch(
        "onObjectPickUp",
        self.fields,
        object
    )
end

function CardFieldController:onObjectDrop(object)
    return self.zoneBehaviors:dispatch(
        "onObjectDrop",
        self.fields,
        object
    )
end

function CardFieldController:onCardLeavesActionZone(object)
    return self.zoneBehaviors:dispatch(
        "onCardLeaves",
        self.fields,
        object
    )
end

function CardFieldController:onActionStackNavigationClicked(
    object,
    direction
)
    return self.zoneBehaviors:dispatch(
        "onStackNavigationClicked",
        self.fields,
        object,
        direction
    )
end

function CardFieldController:onActionZoneCardRotationChanged(
    object,
    rotated
)
    return self.zoneBehaviors:dispatch(
        "onCardRotationChanged",
        self.fields,
        object,
        rotated
    )
end

function CardFieldController:registerZoneBehavior(zoneType, behavior)
    return self.zoneBehaviors:register(zoneType, behavior)
end

return CardFieldController

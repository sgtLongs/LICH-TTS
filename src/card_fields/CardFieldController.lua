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
    "resetForRestart",
    "onLoad",
    "getSaveState",
    "getFields",
    "getPlayerDrawInfo",
    "getCardFieldDestination",
    "onDeckSlotClicked",
    "onDeckMenuUiClicked",
    "onHeroIntelligenceIncreaseClicked",
    "onHeroIntelligenceDecreaseClicked",
    "onHeroHealthIncreaseClicked",
    "onHeroHealthDecreaseClicked",
    "onHeroHealthIncreaseFiveClicked",
    "onHeroHealthDecreaseFiveClicked",
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

local function displayWorldPosition(field, configuredPosition)
    local radians = math.rad(field.downRotationDegrees or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    local localX = configuredPosition.x or 0
    local localZ = configuredPosition.z or 0

    return {
        x = field.position.x + localX * cosine + localZ * sine,
        y = configuredPosition.y,
        z = field.position.z - localX * sine + localZ * cosine
    }
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
    controller.getPlayer = dependencies.getPlayer
        or runtime.getPlayer
        or defaultRuntime.getPlayer
    controller.setVectorLines = dependencies.setVectorLines
        or runtime.setVectorLines
        or defaultRuntime.setVectorLines
    controller.waitTime = dependencies.waitTime
        or scheduler.time
        or runtime.waitTime
        or defaultScheduler.time
    controller.stopWait = dependencies.stopWait
        or scheduler.stop
        or defaultScheduler.stop
    controller.getGlobalOwner = dependencies.getGlobalOwner
        or runtime.getGlobalOwner
        or defaultRuntime.getGlobalOwner
    controller.log = dependencies.log or runtime.log or defaultRuntime.log
    controller.fields = {}
    controller.baseVectorLines = {}
    controller.state = CardFieldState.new({}, nil)
    controller.deckGlowPhase = 0
    controller.deckGlowWaitId = nil
    controller.deckGlowGeneration = 0

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

function CardFieldController:removeHeroStatDisplays(surface)
    local displayConfig = self.config.heroStatsDisplay

    if type(displayConfig) ~= "table" then
        return
    end

    local tooltipPrefix = displayConfig.tooltipPrefix or "Hero stat: "
    local buttons = self.objectAdapter.getButtons(surface)

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if type(button.tooltip) == "string"
            and string.sub(button.tooltip, 1, #tooltipPrefix)
                == tooltipPrefix
        then
            self.objectAdapter.removeButton(surface, button.index)
        end
    end
end

function CardFieldController:addHeroStatDisplays(field)
    local displayConfig = self.config.heroStatsDisplay

    if type(displayConfig) ~= "table" then
        return true
    end

    local surface = self.getObjectFromGuid(field.surfaceObjectGuid)

    if surface == nil then
        return false
    end

    self:removeHeroStatDisplays(surface)

    local stats = CardFieldState.getHeroStats(self.state, field) or {}
    local size = displayConfig.size or {}
    local tooltipPrefix = displayConfig.tooltipPrefix or "Hero stat: "
    local displays = {
        {key = "intelligence", config = displayConfig.intelligence},
        {key = "health", config = displayConfig.health}
    }

    for _, display in ipairs(displays) do
        local itemConfig = display.config or {}
        local position = itemConfig.position or {}
        local value = stats[display.key]
        local color = itemConfig.color or displayConfig.color

        self.objectAdapter.createButton(surface, {
            label = tostring(itemConfig.label or display.key)
                .. " " .. (value ~= nil and tostring(value) or "--"),
            click_function = "none",
            function_owner = self.getGlobalOwner(),
            position = surface.positionToLocal(
                displayWorldPosition(field, position)
            ),
            rotation = {0, 0, 0},
            width = math.floor((size.width or 3) * 100 + 0.5),
            height = math.floor((size.height or 1.25) * 100 + 0.5),
            font_size = displayConfig.fontSize or 260,
            color = displayConfig.color or {0.08, 0.08, 0.08, 0.92},
            font_color = itemConfig.fontColor
                or displayConfig.fontColor or {1, 1, 1, 1},
            hover_color = color,
            press_color = color,
            tooltip = tooltipPrefix .. display.key
        })

        local adjustConfig = displayConfig.adjustButtons or {}
        local adjustSize = adjustConfig.size or {}

        for _, button in ipairs(adjustConfig[display.key] or {}) do
            local offset = button.offset or {}
            local buttonPosition = {
                x = (position.x or 0) + (offset.x or 0),
                y = (position.y or 0)
                    + (offset.y or adjustConfig.surfaceOffset or 0.15),
                z = (position.z or 0) + (offset.z or 0)
            }

            self.objectAdapter.createButton(surface, {
                label = button.label or "",
                click_function = button.clickFunction,
                function_owner = self.getGlobalOwner(),
                position = surface.positionToLocal(
                    displayWorldPosition(field, buttonPosition)
                ),
                rotation = {0, 0, 0},
                width = math.floor(
                    (adjustSize.width or 1.5) * 100 + 0.5
                ),
                height = math.floor(
                    (adjustSize.height or 1) * 100 + 0.5
                ),
                font_size = adjustConfig.fontSize or 420,
                color = adjustConfig.color
                    or {0.08, 0.08, 0.08, 0.92},
                font_color = adjustConfig.fontColor
                    or {1, 1, 1, 1},
                hover_color = adjustConfig.hoverColor
                    or {0.2, 0.55, 0.9, 1},
                press_color = adjustConfig.pressColor
                    or {0.05, 0.3, 0.62, 1},
                tooltip = tooltipPrefix .. display.key
                    .. " adjustment"
            })
        end
    end

    return true
end

function CardFieldController:adjustHeroStat(
    statKey,
    surface,
    playerColor,
    amount
)
    if surface == nil or type(surface.getGUID) ~= "function" then
        return false
    end

    local field = self.layout.findFieldBySurface(
        self.fields,
        surface.getGUID()
    )

    if field == nil
        or CardFieldDefinitions.ownerColor(field) ~= playerColor
    then
        return false
    end

    local stats = CardFieldState.getHeroStats(self.state, field)

    if type(stats) ~= "table" or tonumber(stats[statKey]) == nil then
        return false
    end

    stats = {
        intelligence = tonumber(stats.intelligence) or 0,
        health = tonumber(stats.health) or 0
    }
    stats[statKey] = stats[statKey] + amount
    CardFieldState.setHeroStats(self.state, field, stats)
    self:addHeroStatDisplays(field)
    return true
end

function CardFieldController:deckSlotGlowColor()
    local glow = self.config.deckSlot.glow or {}
    local baseColor = glow.color or {1, 1, 0}
    local minimumOpacity = glow.minimumOpacity or 0
    local maximumOpacity = glow.maximumOpacity or 1
    local wave = (math.sin(self.deckGlowPhase) + 1) * 0.5

    return {
        baseColor[1] or 1,
        baseColor[2] or 1,
        baseColor[3] or 0,
        minimumOpacity
            + (maximumOpacity - minimumOpacity) * wave
    }
end

function CardFieldController:isFieldOccupied(field)
    local ownerColor = CardFieldDefinitions.ownerColor(field)
    local succeeded, player = pcall(self.getPlayer, ownerColor)

    if not succeeded or player == nil then
        return false
    end

    local readSucceeded, seated = pcall(function()
        return player.seated
    end)
    return readSucceeded and seated == true
end

function CardFieldController:refreshDeckSlotGlow()
    local lines = {}
    local glow = self.config.deckSlot.glow

    for _, line in ipairs(self.baseVectorLines) do
        lines[#lines + 1] = line
    end

    for _, field in ipairs(self.fields) do
        if type(glow) == "table"
            and not CardFieldState.isDeckSpawned(self.state, field)
            and self:isFieldOccupied(field)
        then
            for _, line in ipairs(field.deckZoneLines or {}) do
                lines[#lines + 1] = {
                    points = line.points,
                    color = self:deckSlotGlowColor(),
                    thickness = glow.lineThickness
                        or line.thickness
                }
            end
        end
    end

    self.setVectorLines(lines)
end

function CardFieldController:startDeckSlotGlow()
    if self.deckGlowWaitId ~= nil then
        self.stopWait(self.deckGlowWaitId)
        self.deckGlowWaitId = nil
    end

    local glow = self.config.deckSlot.glow

    if type(glow) ~= "table" then
        return
    end

    local interval = tonumber(glow.updateIntervalSeconds) or 0.1
    local period = tonumber(glow.periodSeconds) or 2

    if interval <= 0 or period <= 0 then
        return
    end

    self.deckGlowGeneration = self.deckGlowGeneration + 1
    local generation = self.deckGlowGeneration
    local phaseStep = 2 * math.pi * interval / period

    self.deckGlowWaitId = self.waitTime(function()
        if generation ~= self.deckGlowGeneration then
            return
        end

        self.deckGlowPhase = (self.deckGlowPhase + phaseStep)
            % (2 * math.pi)
        self:refreshDeckSlotGlow()
    end, interval, -1)
end

function CardFieldController:onHeroIntelligenceIncreaseClicked(surface, playerColor)
    return self:adjustHeroStat("intelligence", surface, playerColor, 1)
end

function CardFieldController:onHeroIntelligenceDecreaseClicked(surface, playerColor)
    return self:adjustHeroStat("intelligence", surface, playerColor, -1)
end

function CardFieldController:onHeroHealthIncreaseClicked(surface, playerColor)
    return self:adjustHeroStat("health", surface, playerColor, 1)
end

function CardFieldController:onHeroHealthDecreaseClicked(surface, playerColor)
    return self:adjustHeroStat("health", surface, playerColor, -1)
end

function CardFieldController:onHeroHealthIncreaseFiveClicked(surface, playerColor)
    return self:adjustHeroStat("health", surface, playerColor, 5)
end

function CardFieldController:onHeroHealthDecreaseFiveClicked(surface, playerColor)
    return self:adjustHeroStat("health", surface, playerColor, -5)
end

function CardFieldController:configureFieldCallbacks(field)
    local ownerColor = CardFieldDefinitions.ownerColor(field)

    field.onDeckSpawned = function()
        CardFieldState.setDeckSpawned(self.state, field, true)
        self.onDeckSpawned(ownerColor, field)

        local currentSurface = self.getObjectFromGuid(
            field.surfaceObjectGuid
        )

        if currentSurface ~= nil then
            self:removeDeckSlotButtons(currentSurface)
        end

        self:refreshDeckSlotGlow()
    end

    field.onHeroStatsAvailable = function(heroStats)
        CardFieldState.setHeroStats(self.state, field, heroStats)
        self:addHeroStatDisplays(field)
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

    if CardFieldState.isDeckSpawned(self.state, field) then
        return true
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
        self:configureFieldCallbacks(field)
        self:addHeroStatDisplays(field)
        self:addDeckSlotButton(field)
    end
end

function CardFieldController:renewDeckSlotButton(playerColor)
    for _, field in ipairs(self.fields) do
        local ownerColor = CardFieldDefinitions.ownerColor(field)

        if ownerColor == playerColor then
            CardFieldState.setDeckSpawned(self.state, field, false)
            CardFieldState.setHeroStats(self.state, field, nil)
            self:addHeroStatDisplays(field)
            local added = self:addDeckSlotButton(field)
            self:refreshDeckSlotGlow()
            return added
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
    self.baseVectorLines = built.lines
    self:refreshDeckSlotGlow()
    self:refreshDeckSlotButtons()
    self:startDeckSlotGlow()

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

function CardFieldController:resetForRestart()
    self:onLoad({})
    return true
end

function CardFieldController:getPlayerDrawInfo(playerColor)
    for _, field in ipairs(self.fields) do
        if CardFieldDefinitions.ownerColor(field) == playerColor then
            local stats = CardFieldState.getHeroStats(self.state, field)

            return {
                intelligence = stats and stats.intelligence or 0,
                deckPosition = self.layout.buttonAlignedDeckSpawnPosition(
                    field
                )
            }
        end
    end

    return nil
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

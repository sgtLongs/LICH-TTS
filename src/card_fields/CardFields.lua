local Config = require("src/config/CardFieldConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local CardFieldGeometry = require("src/card_fields/CardFieldGeometry")
local ActionZone = require("src/card_fields/ActionZone")
local DeckSelectionMenu = require("src/card_fields/DeckSelectionMenu")
local TurnSystem = require("src/turns/TurnSystem")

local CardFields = {}
local fields = {}

local function removeDeckSlotButtons(surface)
    local buttons = surface.getButtons() or {}

    for index = #buttons, 1, -1 do
        local button = buttons[index]

        if button.click_function == Config.deckSlot.clickFunction then
            surface.removeButton(button.index)
        end
    end
end

local function addDeckSlotButton(field)
    local surface = getObjectFromGUID(field.surfaceObjectGuid)

    if surface == nil then
        print(
            "CardFields: could not find surface "
                .. tostring(field.surfaceObjectGuid)
                .. " for " .. field.playerColor .. "."
        )
        return false
    end

    removeDeckSlotButtons(surface)

    local ownerColor = field.ownerColor or field.playerColor

    if field.deckSpawned == true then
        return true
    end

    field.onDeckSpawned = function()
        field.deckSpawned = true
        TurnSystem.activatePlayer(ownerColor)

        local currentSurface =
            getObjectFromGUID(field.surfaceObjectGuid)

        if currentSurface ~= nil then
            removeDeckSlotButtons(currentSurface)
        end
    end

    local localPosition = surface.positionToLocal({
        x = field.deckSlot.x,
        y = field.deckSlot.y + Config.deckSlot.buttonSurfaceOffset,
        z = field.deckSlot.z
    })
    local showDebug = DebugConfig.drawCardFieldDeckButtons == true
    local buttonColor = showDebug
        and Config.deckSlot.debugColor
        or Config.deckSlot.invisibleButtonColor
    local fontColor = showDebug
        and Config.deckSlot.debugFontColor
        or Config.deckSlot.invisibleButtonColor

    surface.createButton({
        label = showDebug and Config.deckSlot.debugLabel or "",
        click_function = Config.deckSlot.clickFunction,
        function_owner = Global,
        position = localPosition,
        rotation = {0, 0, 0},
        width = math.floor(Config.deckSlot.buttonWidth * 100 + 0.5),
        height = math.floor(Config.deckSlot.buttonHeight * 100 + 0.5),
        font_size = showDebug and Config.deckSlot.debugFontSize or 1,
        color = buttonColor,
        font_color = fontColor,
        hover_color = showDebug
            and Config.deckSlot.debugHoverColor or buttonColor,
        press_color = showDebug
            and Config.deckSlot.debugPressColor or buttonColor,
        tooltip = "Choose a deck"
    })

    return true
end

local function refreshDeckSlotButtons()
    for _, field in ipairs(fields) do
        addDeckSlotButton(field)
    end
end

function CardFields.renewDeckSlotButton(playerColor)
    for _, field in ipairs(fields) do
        local ownerColor = field.ownerColor or field.playerColor

        if ownerColor == playerColor then
            field.deckSpawned = false
            return addDeckSlotButton(field)
        end
    end

    return false
end

function CardFields.onLoad(savedState)
    DeckSelectionMenu.initialize()

    local built = CardFieldGeometry.buildAll(Config)
    fields = built.fields
    local spawnedByPlayer = type(savedState) == "table"
        and savedState.deckSpawnedByPlayer or {}

    for _, field in ipairs(fields) do
        local ownerColor = field.ownerColor or field.playerColor
        field.deckSpawned = spawnedByPlayer[ownerColor] == true
    end

    ActionZone.onLoad(
        fields,
        type(savedState) == "table" and savedState.actionZone or nil
    )

    -- Zone outlines are part of the playable field rather than debug
    -- geometry, so they are always visible.
    Global.setVectorLines(built.lines)

    refreshDeckSlotButtons()

    local function refreshActionZones()
        ActionZone.refresh(fields)
    end

    Wait.time(refreshActionZones, 0.5)

    -- Stateful cabinet objects can replace and reload themselves after Global's
    -- onLoad has run. Refresh once those object-level load handlers have
    -- settled so their replacement does not discard a deck-slot button.
    Wait.time(refreshDeckSlotButtons, 1)

    print(
        "CardFields: built " .. #fields
            .. " player fields with "
            .. Config.columns .. "x" .. Config.rows .. " spaces."
    )
end

function CardFields.getSaveState()
    local deckSpawnedByPlayer = {}

    for _, field in ipairs(fields) do
        local ownerColor = field.ownerColor or field.playerColor
        deckSpawnedByPlayer[ownerColor] = field.deckSpawned == true
    end

    return {
        deckSpawnedByPlayer = deckSpawnedByPlayer,
        actionZone = ActionZone.getSaveState(fields)
    }
end

function CardFields.getFields()
    return fields
end

local function getButtonAlignedSpawnPosition(field)
    -- The cabinet asset's button X axis is mirrored relative to the card
    -- field's world X axis. Reflecting around the field center makes the
    -- generated deck occupy the same visible column as the attached button.
    return {
        x = 2 * field.position.x - field.deckSlot.x,
        y = field.deckSlot.y,
        z = field.deckSlot.z
    }
end

function CardFields.onDeckSlotClicked(surface, playerColor)
    local guid = surface.getGUID()

    for _, field in ipairs(fields) do
        if field.surfaceObjectGuid == guid then
            local ownerColor =
                field.ownerColor or field.playerColor

            if playerColor ~= ownerColor then
                print(
                    tostring(playerColor)
                        .. " cannot spawn a deck on "
                        .. ownerColor .. "'s field."
                )
                return false
            end

            local spawnPosition = getButtonAlignedSpawnPosition(field)
            print(
                "Deck slot clicked for " .. field.playerColor
                    .. " at button-aligned x="
                    .. tostring(spawnPosition.x)
                    .. ", z=" .. tostring(spawnPosition.z)
                    .. " (row " .. Config.deckSlot.row
                    .. ", column " .. Config.deckSlot.column .. ")."
            )
            return DeckSelectionMenu.open(
                playerColor,
                field,
                spawnPosition
            )
        end
    end

    print("CardFields: clicked deck slot did not match a card field.")
    return false
end

function CardFields.onDeckMenuUiClicked(playerColor, action)
    return DeckSelectionMenu.handleAction(playerColor, action)
end

function CardFields.onObjectPickUp(object)
    return ActionZone.onObjectPickUp(fields, object)
end

function CardFields.onObjectDrop(object)
    return ActionZone.onObjectDrop(fields, object)
end

function CardFields.onCardLeavesActionZone(object)
    return ActionZone.onCardLeaves(fields, object)
end

function CardFields.onActionStackNavigationClicked(object, direction)
    return ActionZone.onStackNavigationClicked(fields, object, direction)
end

function CardFields.onActionZoneCardRotationChanged(object, rotated)
    return ActionZone.onCardRotationChanged(fields, object, rotated)
end

return CardFields

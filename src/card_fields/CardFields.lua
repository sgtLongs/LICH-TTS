local Config = require("src/config/CardFieldConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local CardFieldGeometry = require("src/card_fields/CardFieldGeometry")
local DeckSelectionMenu = require("src/card_fields/DeckSelectionMenu")

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
        return
    end

    removeDeckSlotButtons(surface)

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
end

function CardFields.onLoad()
    DeckSelectionMenu.initialize()

    local built = CardFieldGeometry.buildAll(Config)
    fields = built.fields

    if DebugConfig.drawCardFields == true then
        Global.setVectorLines(built.lines)
    else
        Global.setVectorLines({})
    end

    for _, field in ipairs(fields) do
        addDeckSlotButton(field)
    end

    print(
        "CardFields: built " .. #fields
            .. " player fields with "
            .. Config.columns .. "x" .. Config.rows .. " spaces."
    )
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
            local spawnPosition = getButtonAlignedSpawnPosition(field)
            print(
                "Deck slot clicked for " .. field.playerColor
                    .. " at button-aligned x="
                    .. tostring(spawnPosition.x)
                    .. ", z=" .. tostring(spawnPosition.z)
                    .. " (row " .. Config.deckSlot.row
                    .. ", column " .. Config.deckSlot.column .. ")."
            )
            DeckSelectionMenu.open(playerColor, field, spawnPosition)
            return
        end
    end

    print("CardFields: clicked deck slot did not match a card field.")
end

function CardFields.onDeckMenuUiClicked(playerColor, action)
    return DeckSelectionMenu.handleAction(playerColor, action)
end

return CardFields

local Config = require("src/config/CardFieldConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")

local DeckSelectionMenu = {}
local decksByLootId = {}
local activeSelection = nil

for _, deck in ipairs(Config.deckSlot.decks) do
    decksByLootId[tostring(deck.lootId)] = deck
end

local function hide()
    UI.setAttribute(Config.deckSlot.menuRootId, "active", "false")
end

function DeckSelectionMenu.initialize()
    activeSelection = nil
    hide()
end

function DeckSelectionMenu.open(playerColor, field, spawnPosition)
    local ownerColor = field ~= nil
        and (field.ownerColor or field.playerColor)

    if playerColor == nil
        or field == nil
        or playerColor ~= ownerColor
    then
        return false
    end

    activeSelection = {
        playerColor = playerColor,
        field = field,
        spawnPosition = spawnPosition
    }

    UI.setAttribute(
        Config.deckSlot.menuRootId,
        "visibility",
        playerColor
    )
    UI.setAttribute(Config.deckSlot.menuRootId, "active", "true")
    return true
end

function DeckSelectionMenu.handleAction(playerColor, action)
    if activeSelection == nil
        or activeSelection.playerColor ~= playerColor
    then
        return false
    end

    if action == "close" then
        activeSelection = nil
        hide()
        return true
    end

    local deck = decksByLootId[tostring(action)]

    if deck == nil then
        return false
    end

    local selection = activeSelection
    activeSelection = nil
    hide()

    return DeckGenerator.fetch(
        selection.field,
        selection.spawnPosition,
        deck.lootId
    )
end

return DeckSelectionMenu

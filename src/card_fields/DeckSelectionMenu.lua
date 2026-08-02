local DeckSelectionMenuController = require(
    "src/card_fields/DeckSelectionMenuController"
)

local DeckSelectionMenu = {}
local defaultController = DeckSelectionMenuController.new()

function DeckSelectionMenu.new(dependencies)
    return DeckSelectionMenuController.new(dependencies)
end

function DeckSelectionMenu.initialize()
    return defaultController.initialize()
end

function DeckSelectionMenu.open(playerColor, field, spawnPosition)
    return defaultController.open(playerColor, field, spawnPosition)
end

function DeckSelectionMenu.handleAction(playerColor, action)
    return defaultController.handleAction(playerColor, action)
end

return DeckSelectionMenu

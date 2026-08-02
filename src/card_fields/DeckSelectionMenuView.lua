local UiPatch = require("src/ui/UiPatch")

local DeckSelectionMenuView = {}

function DeckSelectionMenuView.buildHiddenPatch(config)
    return {
        UiPatch.set(config.deckSlot.menuRootId, "active", "false")
    }
end

function DeckSelectionMenuView.buildOpenPatch(config, playerColor)
    return {
        UiPatch.set(
            config.deckSlot.menuRootId,
            "visibility",
            playerColor
        ),
        UiPatch.set(config.deckSlot.menuRootId, "active", "true")
    }
end

return DeckSelectionMenuView

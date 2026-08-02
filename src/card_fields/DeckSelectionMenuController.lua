local Config = require("src/config/CardFieldConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")
local DeckSelectionMenuModel = require(
    "src/card_fields/DeckSelectionMenuModel"
)
local DeckSelectionMenuView = require(
    "src/card_fields/DeckSelectionMenuView"
)
local UiAdapter = require("src/tts/UiAdapter")

local DeckSelectionMenuController = {}

local function defaultFetchDeck(field, spawnPosition, lootId)
    return DeckGenerator.fetch(field, spawnPosition, lootId)
end

function DeckSelectionMenuController.new(dependencies)
    dependencies = dependencies or {}

    local config = dependencies.config or Config
    local modelApi = dependencies.model or DeckSelectionMenuModel
    local view = dependencies.view or DeckSelectionMenuView
    local uiAdapter = dependencies.uiAdapter or UiAdapter.default()
    local fetchDeck = dependencies.fetchDeck or defaultFetchDeck
    local model = modelApi.new()
    local decksByLootId = {}
    local controller = {}

    for _, deck in ipairs(config.deckSlot.decks) do
        decksByLootId[tostring(deck.lootId)] = deck
    end

    local function hide()
        uiAdapter.apply(view.buildHiddenPatch(config))
    end

    function controller.initialize()
        modelApi.clear(model)
        hide()
    end

    function controller.open(playerColor, field, spawnPosition)
        if not modelApi.open(
            model,
            playerColor,
            field,
            spawnPosition
        ) then
            return false
        end

        uiAdapter.apply(view.buildOpenPatch(config, playerColor))
        return true
    end

    function controller.handleAction(playerColor, action)
        local selection = modelApi.getSelection(model, playerColor)

        if selection == nil then
            return false
        end

        if action == "close" then
            modelApi.clear(model)
            hide()
            return true
        end

        local actionValue = tostring(action)
        local deck = decksByLootId[actionValue]
        local lootId = deck ~= nil and deck.lootId or nil

        if lootId == nil and actionValue:match("^%d+$") ~= nil then
            lootId = tonumber(actionValue)
        end

        if lootId == nil
            or lootId <= 0
            or lootId >= math.huge
        then
            return false
        end

        selection = modelApi.takeSelection(model, playerColor)
        hide()

        return fetchDeck(
            selection.field,
            selection.spawnPosition,
            lootId
        )
    end

    return controller
end

return DeckSelectionMenuController

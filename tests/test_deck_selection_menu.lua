local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")
local DeckSelectionMenu = require(
    "src/card_fields/DeckSelectionMenu"
)

Test.case("deck menu opens for its player and generates their choice", function()
    local previousUi = UI
    local previousFetch = DeckGenerator.fetch
    local attributes = {}
    local fetched = nil

    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    DeckGenerator.fetch = function(field, spawnPosition, lootId)
        fetched = {
            field = field,
            spawnPosition = spawnPosition,
            lootId = lootId
        }
        return true
    end

    local field = {playerColor = "Teal"}
    local spawnPosition = {x = 1, y = 2, z = 3}

    DeckSelectionMenu.initialize()
    Test.truthy(DeckSelectionMenu.open(
        "Teal",
        field,
        spawnPosition
    ))
    Test.equal(
        "Teal",
        attributes[Config.deckSlot.menuRootId .. ".visibility"]
    )
    Test.equal(
        "true",
        attributes[Config.deckSlot.menuRootId .. ".active"]
    )
    Test.falsy(DeckSelectionMenu.handleAction("Red", "9636"))
    Test.truthy(DeckSelectionMenu.handleAction("Teal", "9636"))
    Test.equal(field, fetched.field)
    Test.equal(spawnPosition, fetched.spawnPosition)
    Test.equal(9636, fetched.lootId)
    Test.equal(
        "false",
        attributes[Config.deckSlot.menuRootId .. ".active"]
    )

    DeckGenerator.fetch = previousFetch
    UI = previousUi
end)

Test.case("deck configuration includes every available choice", function()
    Test.equal(13, #Config.deckSlot.decks)
    Test.equal(9636, Config.deckSlot.decks[1].lootId)
    Test.equal("Arysa Andrews", Config.deckSlot.decks[1].name)
    Test.equal(4373, Config.deckSlot.decks[13].lootId)
    Test.equal(
        "Yashlaegon, the Sinful",
        Config.deckSlot.decks[13].name
    )
end)

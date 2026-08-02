local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local HeroConfig = require("src/config/HeroConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")
local DeckSelectionMenuModel = require(
    "src/card_fields/DeckSelectionMenuModel"
)
local DeckSelectionMenuView = require(
    "src/card_fields/DeckSelectionMenuView"
)
local DeckSelectionMenu = require(
    "src/card_fields/DeckSelectionMenu"
)

Test.case("deck menu opens for its player and generates their choice", function()
    local previousUi = UI
    local previousFetch = DeckGenerator.fetch
    local attributes = {}
    local fetched = nil

    Test.cleanup(function()
        DeckGenerator.fetch = previousFetch
        UI = previousUi
    end)

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

    local field = {
        playerColor = "Teal",
        ownerColor = "Red"
    }
    local spawnPosition = {x = 1, y = 2, z = 3}

    DeckSelectionMenu.initialize()
    Test.falsy(DeckSelectionMenu.open(
        "Teal",
        field,
        spawnPosition
    ))
    Test.falsy(DeckSelectionMenu.handleAction("Teal", "9636"))
    Test.truthy(DeckSelectionMenu.open(
        "Red",
        field,
        spawnPosition
    ))
    Test.equal(
        "Red",
        attributes[Config.deckSlot.menuRootId .. ".visibility"]
    )
    Test.equal(
        "true",
        attributes[Config.deckSlot.menuRootId .. ".active"]
    )
    Test.falsy(DeckSelectionMenu.handleAction("Teal", "9636"))
    Test.truthy(DeckSelectionMenu.handleAction("Red", "9636"))
    Test.equal(field, fetched.field)
    Test.equal(spawnPosition, fetched.spawnPosition)
    Test.equal(9636, fetched.lootId)
    Test.equal(
        "false",
        attributes[Config.deckSlot.menuRootId .. ".active"]
    )

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

    local expectedHeroes = {
        {"Arysa Andrews", 5, 60},
        {"Aureilia, Maiden of the Brush", 6, 40},
        {"Brain in a Jar", 8, 20},
        {"Devon Andrews", 5, 55},
        {"Draelith, Phoenix King", 6, 45},
        {"Eric and Eugene", 7, 35},
        {"Eric the Possessed", 5, 60},
        {"Isaiah Mangrum", 6, 55},
        {"Kronid The Wretched", 6, 45},
        {"Maldrith, Acolyte of Shadows", 6, 40},
        {"Manfred Schneider", 7, 40},
        {"Marok, The Devourer", 3, 60},
        {"Yashlaegon, the Sinful", 6, 45}
    }

    for index, expected in ipairs(expectedHeroes) do
        local hero = HeroConfig.heroes[index]

        Test.equal(expected[1], hero.titleContains)
        Test.equal(expected[2], hero.intelligence)
        Test.equal(expected[3], hero.health)
    end
end)

Test.case("deck selection model enforces field ownership", function()
    local model = DeckSelectionMenuModel.new()
    local field = {ownerColor = "Red"}
    local position = {x = 1, y = 2, z = 3}

    Test.falsy(DeckSelectionMenuModel.open(
        model,
        "Blue",
        field,
        position
    ))
    Test.truthy(DeckSelectionMenuModel.open(
        model,
        "Red",
        field,
        position
    ))
    Test.equal(nil, DeckSelectionMenuModel.getSelection(model, "Blue"))

    local selection = DeckSelectionMenuModel.takeSelection(model, "Red")
    Test.equal(field, selection.field)
    Test.equal(position, selection.spawnPosition)
    Test.equal(nil, DeckSelectionMenuModel.getSelection(model, "Red"))
end)

Test.case("deck selection view snapshots open and hidden patches", function()
    Test.deepEqual({
        {
            id = Config.deckSlot.menuRootId,
            attribute = "visibility",
            value = "Teal"
        },
        {
            id = Config.deckSlot.menuRootId,
            attribute = "active",
            value = "true"
        }
    }, DeckSelectionMenuView.buildOpenPatch(Config, "Teal"))
    Test.deepEqual({
        {
            id = Config.deckSlot.menuRootId,
            attribute = "active",
            value = "false"
        }
    }, DeckSelectionMenuView.buildHiddenPatch(Config))
end)

Test.case("constructed deck menu controllers isolate selections", function()
    local applied = {}
    local fetched = nil
    local dependencies = {
        uiAdapter = {
            apply = function(patches)
                applied[#applied + 1] = patches
            end
        },
        fetchDeck = function(field, position, lootId)
            fetched = {field, position, lootId}
            return true
        end
    }
    local first = DeckSelectionMenu.new(dependencies)
    local second = DeckSelectionMenu.new(dependencies)
    local field = {ownerColor = "Red"}
    local position = {x = 4, y = 5, z = 6}

    first.initialize()
    second.initialize()
    Test.truthy(first.open("Red", field, position))
    Test.falsy(second.handleAction("Red", "9636"))
    Test.falsy(first.handleAction("Blue", "9636"))
    Test.truthy(first.handleAction("Red", "9636"))
    Test.deepEqual({field, position, 9636}, fetched)
    Test.equal("false", applied[#applied][1].value)
end)

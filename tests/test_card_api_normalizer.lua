local Test = require("tests/support/Test")
local CardApiNormalizer = require("src/cards/CardApiNormalizer")
local CardDefinition = require("src/cards/CardDefinition")

Test.case("card definitions normalize canonical values and titles", function()
    local types = {"Undead", "Hero"}
    local features = {"rotate90"}
    local definition = CardDefinition.new({
        id = 42,
        name = "Manfred",
        description = "A hero",
        types = types,
        images = {front = "front.png", back = "back.png"},
        quantity = "2.9",
        featureIds = features
    })

    Test.equal("42", definition.id)
    Test.equal("Manfred", definition.name)
    Test.equal("A hero", definition.description)
    Test.equal("front.png", definition.images.front)
    Test.equal("back.png", definition.images.back)
    Test.equal(2, definition.quantity)
    Test.equal("rotate90", definition.featureIds[1])
    Test.equal("Manfred | Undead, Hero", CardDefinition.title(definition))

    types[1] = "changed"
    features[1] = "changed"
    Test.equal("Undead", definition.types[1])
    Test.equal("rotate90", definition.featureIds[1])
end)

Test.case("card definitions reject incomplete canonical values", function()
    local valid = {
        id = "card",
        images = {front = "front.png", back = "back.png"},
        quantity = 1
    }

    local definition, errorMessage = CardDefinition.new({})
    Test.nilValue(definition)
    Test.contains(errorMessage, "stable identity")

    definition, errorMessage = CardDefinition.new({
        id = valid.id,
        images = {back = valid.images.back},
        quantity = valid.quantity
    })
    Test.nilValue(definition)
    Test.contains(errorMessage, "front image")

    definition, errorMessage = CardDefinition.new({
        id = valid.id,
        images = valid.images,
        quantity = 0
    })
    Test.nilValue(definition)
    Test.contains(errorMessage, "positive quantity")
end)

Test.case("card API normalization preserves accepted aliases", function()
    local definitions, errorMessage, deckSize = CardApiNormalizer.normalize({
        backImageUrl = "back.png",
        cards = {
            {
                id = "skeleton-id",
                name = "Skeleton",
                description = "A minion",
                frontImageURL = "skeleton.png",
                types = {"Undead"},
                quantity = "2.9"
            },
            {
                index = 7,
                nickname = "Fallback Hero",
                frontImageURL = "hero.png",
                quantity = 1
            },
            {
                name = "Skipped",
                frontImageURL = "skipped.png",
                quantity = 0
            }
        }
    })

    Test.nilValue(errorMessage)
    Test.equal(3, deckSize)
    Test.equal(2, #definitions)
    Test.equal("skeleton-id", definitions[1].id)
    Test.equal("Skeleton", definitions[1].name)
    Test.equal("skeleton.png", definitions[1].images.front)
    Test.equal("back.png", definitions[1].images.back)
    Test.equal(2, definitions[1].quantity)
    Test.equal("7", definitions[2].id)
    Test.equal("Fallback Hero", definitions[2].name)
    Test.equal(0, #definitions[2].types)
    Test.equal("rotate90", definitions[2].featureIds[1])
    Test.equal("destroyToPurgatory", definitions[2].featureIds[2])
end)

Test.case("card API normalization applies card-specific features", function()
    local definitions = CardApiNormalizer.normalize({
        backImageUrl = "back.png",
        cards = {
            {
                id = "rotate-only",
                name = "Spinner",
                frontImageURL = "spinner.png",
                quantity = 1
            },
            {
                name = "No Mechanics",
                frontImageURL = "plain.png",
                quantity = 1
            },
            {
                name = "Default Card",
                frontImageURL = "default.png",
                quantity = 1
            }
        }
    }, {
        defaultFeatureIds = {"defaultFeature"},
        cards = {
            {id = "rotate-only", featureIds = {"rotate90"}},
            {name = "No Mechanics", featureIds = {}}
        }
    })

    Test.deepEqual({"rotate90"}, definitions[1].featureIds)
    Test.deepEqual({}, definitions[2].featureIds)
    Test.deepEqual({"defaultFeature"}, definitions[3].featureIds)
end)

Test.case("card API normalization reports the compatibility errors", function()
    local invalidResponses = {
        {
            data = {},
            message = "API response did not contain any cards."
        },
        {
            data = {cards = {{quantity = 1}}},
            message = "API response did not contain a card back image."
        },
        {
            data = {
                backImageUrl = "back.png",
                cards = {
                    {frontImageURL = "front.png", quantity = 0},
                    {quantity = 2}
                }
            },
            message = "API response did not contain any spawnable cards."
        }
    }

    for _, invalid in ipairs(invalidResponses) do
        local definitions, errorMessage =
            CardApiNormalizer.normalize(invalid.data)
        Test.nilValue(definitions)
        Test.equal(invalid.message, errorMessage)
    end
end)

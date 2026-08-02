local Test = require("tests/support/Test")
local CardLogic = require("src/cards/CardLogic")
local CardDefinitions = require("data/CardDefinitions")

local function assertBuildableFeatureIds(featureIds, registered, label)
    Test.truthy(type(featureIds) == "table", label .. " must be a table.")

    local seen = {}

    for index, featureId in ipairs(featureIds) do
        Test.truthy(
            type(featureId) == "string" and featureId ~= "",
            label .. " feature " .. tostring(index)
                .. " must be a non-empty string."
        )
        Test.truthy(
            registered[featureId] == true,
            label .. " references unknown feature "
                .. tostring(featureId) .. "."
        )
        Test.falsy(
            seen[featureId],
            label .. " repeats feature " .. featureId .. "."
        )
        seen[featureId] = true
    end

    local script = CardLogic.build(featureIds)
    Test.truthy(type(script) == "string" and script ~= "")

    local loader = load or loadstring
    local chunk, loadError = loader(script, label)
    Test.truthy(chunk ~= nil, loadError)
end

Test.case("configured card definitions are unique and buildable", function()
    local registered = {}

    for _, descriptor in ipairs(CardLogic.getFeatureDescriptors()) do
        Test.falsy(
            registered[descriptor.id],
            "Registered card feature IDs must be unique: "
                .. tostring(descriptor.id) .. "."
        )
        registered[descriptor.id] = true
    end

    assertBuildableFeatureIds(
        CardDefinitions.defaultFeatureIds,
        registered,
        "CardDefinitions.defaultFeatureIds"
    )

    Test.truthy(
        type(CardDefinitions.cards) == "table",
        "CardDefinitions.cards must be a table."
    )

    local cardIds = {}

    for index, definition in ipairs(CardDefinitions.cards) do
        local label = "CardDefinitions.cards[" .. tostring(index) .. "]"

        Test.truthy(type(definition) == "table", label .. " must be a table.")
        Test.truthy(
            type(definition.id) == "string" and definition.id ~= "",
            label .. " must have a non-empty id."
        )
        Test.falsy(
            cardIds[definition.id],
            "Configured card IDs must be unique: " .. definition.id .. "."
        )
        cardIds[definition.id] = true

        local featureIds = definition.featureIds

        if featureIds == nil then
            featureIds = CardDefinitions.defaultFeatureIds
        end

        assertBuildableFeatureIds(
            featureIds,
            registered,
            label .. ".featureIds"
        )
    end
end)

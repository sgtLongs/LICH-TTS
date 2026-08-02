local Test = require("tests/support/Test")
local GameSaveCodec = require("src/persistence/GameSaveCodec")
local LegacySave = require("tests/fixtures/legacy_game_save")

Test.case("game save codec migrates the unversioned root envelope", function()
    local normalized, validationError = GameSaveCodec.normalize(LegacySave)

    Test.nilValue(validationError)
    Test.equal(1, normalized.schemaVersion)
    Test.equal("cards", normalized.cardFields.legacy)
    Test.equal("dungeon", normalized.dungeonMap.legacy)
    Test.equal("hex", normalized.hexGrid.legacy)
    Test.equal("settings", normalized.settings.legacy)
    Test.equal("turns", normalized.turnSystem.legacy)
end)

Test.case("game save codec accepts its current numeric string version", function()
    local normalized, validationError = GameSaveCodec.normalize({
        schemaVersion = "1",
        hexGrid = {selectedCells = {}}
    })

    Test.nilValue(validationError)
    Test.equal(1, normalized.schemaVersion)
    Test.truthy(normalized.hexGrid)
end)

Test.case("game save codec rejects unknown versions without partial load", function()
    local normalized, validationError = GameSaveCodec.normalize({
        schemaVersion = 99,
        cardFields = {mustNotLoad = true}
    })

    Test.contains(validationError, "Unsupported")
    Test.nilValue(normalized.cardFields)
    Test.equal(1, normalized.schemaVersion)
end)

Test.case("game save codec handles empty and malformed JSON", function()
    local empty = GameSaveCodec.decode("", {})
    Test.equal(1, empty.schemaVersion)

    local malformed, decodeError = GameSaveCodec.decode("bad", {
        decode = function()
            error("bad JSON")
        end
    })

    Test.contains(decodeError, "not valid JSON")
    Test.nilValue(malformed.hexGrid)
end)

Test.case("game save codec writes only the versioned public envelope", function()
    local encodedValue = nil
    local encoded = GameSaveCodec.encode({
        cardFields = {value = 1},
        extraInternalValue = "not persisted"
    }, {
        encode = function(value)
            encodedValue = value
            return "encoded"
        end
    })

    Test.equal("encoded", encoded)
    Test.equal(1, encodedValue.schemaVersion)
    Test.equal(1, encodedValue.cardFields.value)
    Test.nilValue(encodedValue.extraInternalValue)
end)

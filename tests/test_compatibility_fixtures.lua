local Test = require("tests/support/Test")
local Fixtures = require("tests/fixtures/compatibility_states")
local ActionZoneState = require("src/card_fields/zones/ActionZoneState")
local CardApiNormalizer = require("src/cards/CardApiNormalizer")
local DungeonMapState = require("src/dungeon/DungeonMapState")
local HexBoardCodec = require("src/hex/HexBoardCodec")
local HexGeometry = require("src/hex/HexGeometry")
local SpawnDefinitions = require("src/hex/HexSpawnDefinitions")
local SavedBoardCatalog = require("src/boards/SavedBoardCatalog")

local function newCatalog(decodeJson)
    return SavedBoardCatalog.new({
        schemaVersion = 2,
        legacySchemaVersion = 1,
        decodeJson = decodeJson
    })
end

Test.case("settings schema-one fixture migrates into stable board IDs", function()
    local catalog = newCatalog(function(value)
        Test.equal("fixture-board-json", value)
        return {fixture = "legacy"}
    end)

    catalog:load(Fixtures.settingsV1)
    local saved = catalog:serialize()

    Test.equal(2, saved.schemaVersion)
    Test.equal("board-1", saved.selectedBoardId)
    Test.equal("legacy", saved.savedBoards[1].boardState.fixture)
end)

Test.case("settings schema-two fixture round-trips IDs and selection", function()
    local catalog = newCatalog()
    catalog:load(Fixtures.settingsV2)
    local saved = catalog:serialize()

    Test.equal("board-2", saved.selectedBoardId)
    Test.equal(3, saved.nextBoardId)
    Test.equal("Crypt", saved.savedBoards[1].name)
    Test.equal("Vault", saved.savedBoards[2].name)
end)

Test.case("dungeon schema-one fixture round-trips assignments", function()
    local cells, cellsByKey = DungeonMapState.buildCells(3)
    local loaded = DungeonMapState.load(
        Fixtures.dungeonV1,
        cellsByKey,
        1
    )
    local saved = DungeonMapState.serialize(
        cells,
        cellsByKey,
        loaded.assignmentsByCellKey,
        loaded.currentCellKey,
        1
    )

    Test.equal("board-1", loaded.assignmentsByCellKey["0:0"])
    Test.equal("board-2", loaded.assignmentsByCellKey["1:0"])
    Test.equal(2, #saved.tiles)
    Test.equal(0, saved.currentTile.q)
end)

Test.case("legacy action-stack fixture preserves depth and locks", function()
    local fields = {{fieldId = "field-a"}}
    local loaded = ActionZoneState.load(fields, Fixtures.actionZoneLegacy)
    local firstStack = loaded.fields["field-a"].stacks[1]

    Test.equal("card-b", firstStack.selectedKey)
    Test.truthy(loaded.originalLocks["card-a"])
    Test.falsy(loaded.originalLocks["card-b"])

    local saved = ActionZoneState.save(loaded, fields)
    Test.equal(2, saved.fields["field-a"].stacks[1].selectedIndex)
    Test.equal("card-d", saved.fields["field-a"].stacks[2].cards[1])
end)

Test.case("board fixture validates every configured placement type", function()
    local cells = HexGeometry.buildCells({
        sideLength = 3,
        hexRadius = 1,
        rotationDegrees = 0,
        offsetX = 0,
        offsetZ = 0,
        hitEdgePadding = 0
    })
    local templatesByKey = {}

    for _, template in ipairs(SpawnDefinitions) do
        templatesByKey[template.key] = template
    end

    local normalized, validationError = HexBoardCodec.normalize(
        Fixtures.boardStateForTemplates(
            SpawnDefinitions,
            1,
            "fixture-board"
        ),
        {
            schemaVersion = 1,
            boardGuid = "fixture-board",
            cellsByKey = HexGeometry.indexCells(cells),
            templatesByKey = templatesByKey
        }
    )

    Test.nilValue(validationError)
    Test.equal(#SpawnDefinitions, #normalized.placements)
end)

Test.case("deck API fixtures preserve valid and partial aliases", function()
    local valid, validError, validSize = CardApiNormalizer.normalize(
        Fixtures.deckApi.valid
    )
    local partial, partialError, partialSize = CardApiNormalizer.normalize(
        Fixtures.deckApi.partial
    )

    Test.nilValue(validError)
    Test.equal(1, validSize)
    Test.equal("hero-a", valid[1].id)
    Test.nilValue(partialError)
    Test.equal(2, partialSize)
    Test.equal("17", partial[1].id)
    Test.equal("Legacy Minion", partial[1].name)
end)

Test.case("malformed deck API fixture is rejected atomically", function()
    local definitions, validationError = CardApiNormalizer.normalize(
        Fixtures.deckApi.malformed
    )

    Test.nilValue(definitions)
    Test.contains(validationError, "cards")
end)

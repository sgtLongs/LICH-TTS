local Test = require("tests/support/Test")
local DungeonMapState = require("src/dungeon/DungeonMapState")

Test.case("dungeon state builds a radius-three map", function()
    local cells, cellsByKey = DungeonMapState.buildCells(3)

    Test.equal(37, #cells)
    Test.truthy(cellsByKey["0:0"])
    Test.truthy(cellsByKey["-3:3"])
end)

Test.case("dungeon traversal permits only touching cells", function()
    local _, cellsByKey = DungeonMapState.buildCells(3)

    Test.truthy(DungeonMapState.canTraverse(
        cellsByKey,
        nil,
        cellsByKey["2:0"]
    ))
    Test.truthy(DungeonMapState.canTraverse(
        cellsByKey,
        "0:0",
        cellsByKey["1:0"]
    ))
    Test.falsy(DungeonMapState.canTraverse(
        cellsByKey,
        "0:0",
        cellsByKey["2:0"]
    ))
end)

Test.case("dungeon state filters invalid saved assignments", function()
    local cells, cellsByKey = DungeonMapState.buildCells(1)
    local loaded = DungeonMapState.load({
        schemaVersion = 1,
        tiles = {
            {q = 0, r = 0, boardSaveId = "first"},
            {q = 0, r = 0, boardSaveId = "duplicate"},
            {q = 8, r = 8, boardSaveId = "outside"},
            {q = 1.5, r = 0, boardSaveId = "fractional"},
            {q = 1, r = 0, boardSaveId = ""}
        },
        currentTile = {q = 0, r = 0}
    }, cellsByKey, 1)

    Test.equal("first", loaded.assignmentsByCellKey["0:0"])
    Test.equal("0:0", loaded.currentCellKey)

    local serialized = DungeonMapState.serialize(
        cells,
        cellsByKey,
        loaded.assignmentsByCellKey,
        loaded.currentCellKey,
        1
    )

    Test.equal(1, #serialized.tiles)
    Test.equal("first", serialized.tiles[1].boardSaveId)
    Test.equal(0, serialized.currentTile.q)
    Test.equal(0, serialized.currentTile.r)
end)

Test.case("dungeon state ignores unsupported versions", function()
    local _, cellsByKey = DungeonMapState.buildCells(1)
    local loaded = DungeonMapState.load({
        schemaVersion = 99,
        tiles = {{q = 0, r = 0, boardSaveId = "board"}}
    }, cellsByKey, 1)

    Test.truthy(loaded.unsupportedVersion)
    Test.nilValue(loaded.assignmentsByCellKey["0:0"])
end)

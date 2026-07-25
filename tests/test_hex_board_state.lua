local Test = require("tests/support/Test")
local HexBoardState = require("src/hex/HexBoardState")
local HexGeometry = require("src/hex/HexGeometry")

local cells = HexGeometry.buildCells({
    sideLength = 3,
    hexRadius = 1,
    rotationDegrees = 0,
    offsetX = 0,
    offsetZ = 0,
    hitEdgePadding = 0
})
local options = {
    schemaVersion = 2,
    boardGuid = "board-a",
    cellsByKey = HexGeometry.indexCells(cells),
    templatesByKey = {
        token = {occupiesFacingCell = false},
        wall = {occupiesFacingCell = true}
    }
}

local function validState()
    return {
        schemaVersion = 2,
        boardGuid = "board-a",
        selectedHexes = {
            {row = 0, column = 0},
            {row = 0, column = 0}
        },
        hexObjects = {
            {
                type = "wall",
                hex = {row = 0, column = 0},
                facing = {row = 0, column = 1},
                occupiedHexes = {
                    {row = 0, column = 0},
                    {row = 0, column = 1}
                }
            }
        }
    }
end

Test.case("board-state validation normalizes valid data", function()
    local normalized, validationError = HexBoardState.normalize(
        validState(),
        options
    )

    Test.nilValue(validationError)
    Test.equal(1, normalized.selectedHexCount)
    Test.truthy(normalized.selectedCells["0:0"])
    Test.equal(1, #normalized.placements)
    Test.equal("wall", normalized.placements[1].templateKey)
end)

Test.case("board-state validation rejects the wrong board", function()
    local state = validState()
    state.boardGuid = "board-b"

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "different board")
end)

Test.case("board-state validation rejects non-adjacent facing", function()
    local state = validState()
    state.hexObjects[1].facing = {row = 1, column = 1}

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "must be adjacent")
end)

Test.case("board-state validation verifies occupied hexes", function()
    local state = validState()
    state.hexObjects[1].occupiedHexes[2] = {row = 1, column = 0}

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "does not match")
end)

Test.case("board-state validation rejects sparse arrays", function()
    local state = validState()
    state.selectedHexes = {
        [1] = {row = 0, column = 0},
        [3] = {row = 1, column = 0}
    }

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "missing entries")
end)

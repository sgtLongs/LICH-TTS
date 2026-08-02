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

Test.case("board-state validation requires an object", function()
    local normalized, validationError = HexBoardState.normalize(
        "not-a-board",
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "must contain an object")
end)

Test.case("board-state validation accepts numeric schema strings", function()
    local state = validState()
    state.schemaVersion = "2"

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.truthy(normalized)
    Test.nilValue(validationError)
end)

Test.case("board-state validation rejects unsupported schemas", function()
    local state = validState()
    state.schemaVersion = 3

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "Unsupported")
end)

Test.case("board-state validation requires both arrays", function()
    local state = validState()
    state.selectedHexes = nil

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "selectedHexes must be an array")

    state = validState()
    state.hexObjects = nil
    normalized, validationError = HexBoardState.normalize(state, options)

    Test.nilValue(normalized)
    Test.contains(validationError, "hexObjects must be an array")
end)

Test.case("board-state validation rejects keyed array entries", function()
    local state = validState()
    state.selectedHexes = {
        center = {row = 0, column = 0}
    }

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "must be an array")
end)

Test.case("board-state validation requires integer in-bounds cells", function()
    local state = validState()
    state.selectedHexes = {{row = 0.5, column = 0}}

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "integer row and column")

    state = validState()
    state.hexObjects[1].hex = {row = 99, column = 99}
    normalized, validationError = HexBoardState.normalize(state, options)

    Test.nilValue(normalized)
    Test.contains(validationError, "outside the hex grid")
end)

Test.case("board-state validation rejects unknown object types", function()
    local state = validState()
    state.hexObjects[1].type = "dragon"

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "unknown object type")
end)

Test.case("occupied hex metadata is optional", function()
    local state = validState()
    state.hexObjects[1].occupiedHexes = nil

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(validationError)
    Test.equal(1, #normalized.placements)
    Test.equal(0, normalized.placements[1].cell.row)
    Test.equal(1, normalized.placements[1].facingCell.column)
end)

Test.case("single-cell objects validate one occupied hex", function()
    local state = validState()
    state.hexObjects[1] = {
        type = "token",
        hex = {row = 0, column = 0},
        facing = {row = 0, column = 1},
        occupiedHexes = {{row = 0, column = 0}}
    }

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(validationError)
    Test.equal("token", normalized.placements[1].templateKey)

    state.hexObjects[1].occupiedHexes[2] = {row = 0, column = 1}
    normalized, validationError = HexBoardState.normalize(state, options)

    Test.nilValue(normalized)
    Test.contains(validationError, "must contain 1 hex")
end)

Test.case("occupied hex arrays must preserve canonical order", function()
    local state = validState()
    state.hexObjects[1].occupiedHexes = {
        {row = 0, column = 1},
        {row = 0, column = 0}
    }

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "does not match")
end)

Test.case("facing must be a distinct adjacent cell", function()
    local state = validState()
    state.hexObjects[1].facing = {row = 0, column = 0}

    local normalized, validationError = HexBoardState.normalize(
        state,
        options
    )

    Test.nilValue(normalized)
    Test.contains(validationError, "must be adjacent")
end)

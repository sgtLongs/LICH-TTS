local Test = require("tests/support/Test")
local DungeonMapState = require("src/dungeon/DungeonMapState")
local DungeonMapRules = require("src/dungeon/DungeonMapRules")

local cells, cellsByKey = DungeonMapState.buildCells(2)

local function cell(q, r)
    return cellsByKey[DungeonMapState.cellKey(q, r)]
end

Test.case("dungeon rules assign and clear without mutating input", function()
    local original = {['0:0'] = "entrance"}
    local assigned, current = DungeonMapRules.assign(
        original,
        "0:0",
        "0:0",
        "replacement"
    )

    Test.equal("entrance", original["0:0"])
    Test.equal("replacement", assigned["0:0"])
    Test.nilValue(current)

    local cleared, clearedCurrent, changed = DungeonMapRules.clear(
        assigned,
        "0:0",
        "0:0"
    )
    Test.truthy(changed)
    Test.equal("replacement", assigned["0:0"])
    Test.nilValue(cleared["0:0"])
    Test.nilValue(clearedCurrent)
end)

Test.case("dungeon traversal validation has stable rejection ordering", function()
    local parameters = {
        assignmentsByCellKey = {},
        cellsByKey = cellsByKey,
        currentCellKey = "0:0",
        cell = cell(1, 0),
        savedBoards = {{id = "hall", name = "Hall"}},
        traversalLocked = true,
        loaderAvailable = false
    }

    Test.equal(
        "unassigned",
        DungeonMapRules.validateTraversal(parameters).reason
    )
    parameters.assignmentsByCellKey["1:0"] = "hall"
    Test.equal("locked", DungeonMapRules.validateTraversal(parameters).reason)
    parameters.traversalLocked = false
    parameters.cell = cell(2, 0)
    parameters.assignmentsByCellKey["2:0"] = "hall"
    Test.equal(
        "notAdjacent",
        DungeonMapRules.validateTraversal(parameters).reason
    )
    parameters.cell = cell(1, 0)
    parameters.assignmentsByCellKey["1:0"] = "missing"
    Test.equal(
        "missingSave",
        DungeonMapRules.validateTraversal(parameters).reason
    )
    parameters.assignmentsByCellKey["1:0"] = "hall"
    Test.equal(
        "unavailable",
        DungeonMapRules.validateTraversal(parameters).reason
    )
    parameters.loaderAvailable = true

    local accepted = DungeonMapRules.validateTraversal(parameters)
    Test.truthy(accepted.accepted)
    Test.equal("hall", accepted.boardSaveId)
    Test.equal("Hall", accepted.savedBoard.name)
end)

Test.case("dungeon rules count valid and missing assignments", function()
    local assignments = {
        ["0:0"] = "one",
        ["1:0"] = "missing",
        ["0:1"] = "two"
    }
    local savedBoards = {
        {id = "one", name = "One"},
        {id = "two", name = "Two"}
    }

    Test.equal(3, DungeonMapRules.countAssignments(assignments))
    Test.equal(
        2,
        DungeonMapRules.countValidAssignments(assignments, savedBoards)
    )
    Test.equal(
        "Missing save (missing)",
        DungeonMapRules.getAssignmentDescription(
            assignments,
            cell(1, 0),
            savedBoards
        )
    )
end)

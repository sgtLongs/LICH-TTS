local Test = require("tests/support/Test")
local HexGeometry = require("src/hex/HexGeometry")

local function makeConfig(sideLength)
    return {
        sideLength = sideLength,
        hexRadius = 1.5,
        rotationDegrees = 0,
        offsetX = 0,
        offsetZ = 0,
        hitEdgePadding = 0.12
    }
end

Test.case("hex geometry builds the expected number of cells", function()
    local cells = HexGeometry.buildCells(makeConfig(6))

    Test.equal(91, #cells)

    local cellsByKey = HexGeometry.indexCells(cells)
    Test.near(0, cellsByKey["0:0"].x, 0.000001)
    Test.near(0, cellsByKey["0:0"].z, 0.000001)
end)

Test.case("hex geometry applies rotation and offsets", function()
    local config = makeConfig(2)
    config.rotationDegrees = 90
    config.offsetX = 4
    config.offsetZ = -3

    local cellsByKey = HexGeometry.indexCells(
        HexGeometry.buildCells(config)
    )
    local cell = cellsByKey["0:1"]

    Test.near(4, cell.x, 0.000001)
    Test.near(-3 + math.sqrt(3) * 1.5, cell.z, 0.000001)
end)

Test.case("hex geometry identifies adjacent cells", function()
    local cells = HexGeometry.buildCells(makeConfig(3))
    local cellsByKey = HexGeometry.indexCells(cells)

    local centerAdjacent = HexGeometry.getAdjacentCells(
        cellsByKey["0:0"],
        cellsByKey
    )
    local edgeAdjacent = HexGeometry.getAdjacentCells(
        cellsByKey["0:2"],
        cellsByKey
    )
    local centerCount = 0
    local edgeCount = 0

    for _, _ in pairs(centerAdjacent) do
        centerCount = centerCount + 1
    end

    for _, _ in pairs(edgeAdjacent) do
        edgeCount = edgeCount + 1
    end

    Test.equal(6, centerCount)
    Test.equal(3, edgeCount)
end)

Test.case("hex hit testing returns the nearest containing cell", function()
    local config = makeConfig(2)
    local cells = HexGeometry.buildCells(config)
    local center = HexGeometry.findCellAt(
        cells,
        {x = 0.1, z = -0.1},
        config
    )
    local outside = HexGeometry.findCellAt(
        cells,
        {x = 100, z = 100},
        config
    )

    Test.equal(0, center.row)
    Test.equal(0, center.column)
    Test.nilValue(outside)
end)

Test.case("hex geometry follows the centered-hex size formula", function()
    local expectedCounts = {1, 7, 19, 37}

    for sideLength, expectedCount in ipairs(expectedCounts) do
        Test.equal(
            expectedCount,
            #HexGeometry.buildCells(makeConfig(sideLength))
        )
    end
end)

Test.case("hex cell keys are stable for negative coordinates", function()
    Test.equal("-3:2", HexGeometry.cellKey(-3, 2))

    local cellsByKey = HexGeometry.indexCells({
        {row = -3, column = 2, marker = "expected"}
    })

    Test.equal("expected", cellsByKey["-3:2"].marker)
end)

Test.case("adjacency returns the six canonical axial directions", function()
    local cellsByKey = HexGeometry.indexCells(
        HexGeometry.buildCells(makeConfig(3))
    )
    local adjacent = HexGeometry.getAdjacentCells(
        cellsByKey["0:0"],
        cellsByKey
    )

    for _, key in ipairs({
        "0:1", "-1:1", "-1:0", "0:-1", "1:-1", "1:0"
    }) do
        Test.truthy(adjacent[key], "Expected adjacent cell " .. key .. ".")
    end
end)

Test.case("hex hit testing includes padded edges", function()
    local config = makeConfig(1)
    local cells = HexGeometry.buildCells(config)
    local paddedEdge = math.sqrt(3) * (config.hexRadius + 0.05) * 0.5

    Test.truthy(HexGeometry.findCellAt(
        cells,
        {x = paddedEdge, z = 0},
        config
    ))

    config.hitEdgePadding = 0
    Test.nilValue(HexGeometry.findCellAt(
        cells,
        {x = paddedEdge, z = 0},
        config
    ))
end)

Test.case("empty geometry has no hit target", function()
    Test.nilValue(HexGeometry.findCellAt(
        {},
        {x = 0, z = 0},
        makeConfig(1)
    ))
end)

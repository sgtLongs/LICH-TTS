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

local Test = require("tests/support/Test")
local DeathFogRules = require("src/turns/DeathFogRules")
local HexGeometry = require("src/hex/HexGeometry")

local templatesByKey = {
    deathFog = {key = "deathFog", isDeathFog = true},
    token = {key = "token"},
    wall = {key = "wall", isWall = true, occupiesFacingCell = true}
}

local function placement(templateKey, row, column, facingRow, facingColumn)
    return {
        templateKey = templateKey,
        cell = {row = row, column = column},
        facingCell = {row = facingRow, column = facingColumn}
    }
end

local function buildCells(sideLength)
    return HexGeometry.buildCells({
        sideLength = sideLength,
        hexRadius = 1,
        rotationDegrees = 0,
        offsetX = 0,
        offsetZ = 0,
        hitEdgePadding = 0
    })
end

Test.case("death fog candidates use every open hex in the outer ring", function()
    local candidates = DeathFogRules.getCandidates(
        buildCells(3),
        {
            placement("token", 0, 2, 0, 1),
            placement("deathFog", -2, 0, -1, 0),
            placement("wall", 2, -2, 1, -1)
        },
        templatesByKey,
        HexGeometry.cellKey
    )

    Test.truthy(candidates["0:2"])
    Test.nilValue(candidates["-2:0"])
    Test.nilValue(candidates["2:-2"])
    Test.nilValue(candidates["1:-1"])
end)

Test.case("death fog advances inward only after a ring is blocked", function()
    local cells = buildCells(3)
    local placements = {}

    for _, cell in ipairs(cells) do
        local distance = math.max(
            math.abs(cell.row),
            math.abs(cell.column),
            math.abs(cell.row + cell.column)
        )

        if distance == 2 then
            placements[#placements + 1] = placement(
                "deathFog",
                cell.row,
                cell.column,
                cell.row == 0 and 1 or cell.row - 1,
                cell.column
            )
        end
    end

    local candidates = DeathFogRules.getCandidates(
        cells,
        placements,
        templatesByKey,
        HexGeometry.cellKey
    )
    local count = 0

    for _, _ in pairs(candidates) do
        count = count + 1
    end

    Test.equal(6, count)
    Test.truthy(candidates["0:1"])
    Test.nilValue(candidates["0:0"])
end)


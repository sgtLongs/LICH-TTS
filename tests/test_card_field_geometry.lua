local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local CardFieldGeometry =
    require("src/card_fields/CardFieldGeometry")

Test.case("card fields build six 7 by 3 sectioned grids", function()
    local result = CardFieldGeometry.buildAll(Config)

    Test.equal(6, #result.fields)
    Test.equal(21, #result.fields[1].cells)
    Test.equal(144, #result.lines)
    Test.equal(Config.deckSlot.row, result.fields[1].deckSlot.row)
    Test.equal(Config.deckSlot.column, result.fields[1].deckSlot.column)
    Test.equal("3c4e81", result.fields[1].surfaceObjectGuid)

    local sectionCounts = {}

    for _, cell in ipairs(result.fields[1].cells) do
        sectionCounts[cell.section] =
            (sectionCounts[cell.section] or 0) + 1
    end

    Test.equal(6, sectionCounts.skillLeft)
    Test.equal(9, sectionCounts.source)
    Test.equal(6, sectionCounts.skillRight)
end)

Test.case("card field position rotation and size affect drawing", function()
    local field = {
        playerColor = "Test",
        position = {x = 10, z = 20},
        rotationDegrees = 90,
        size = {x = 14, z = 6}
    }
    local result = CardFieldGeometry.buildField(field, Config)
    local firstLine = result.lines[1]

    Test.near(7, firstLine.points[1].x, 0.0001)
    Test.near(27, firstLine.points[1].z, 0.0001)
    Test.near(13, firstLine.points[2].x, 0.0001)
    Test.near(27, firstLine.points[2].z, 0.0001)
end)

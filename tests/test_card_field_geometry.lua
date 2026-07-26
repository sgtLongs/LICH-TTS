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
    Test.equal(Config.heroSlot.row, result.fields[1].heroSlot.row)
    Test.equal(Config.heroSlot.column, result.fields[1].heroSlot.column)
    Test.equal("3c4e81", result.fields[1].surfaceObjectGuid)
    Test.equal("Red", result.fields[1].ownerColor)
    Test.equal("Brown", result.fields[2].ownerColor)
    Test.equal("White", result.fields[3].ownerColor)
    Test.equal("Blue", result.fields[4].ownerColor)
    Test.equal("Teal", result.fields[5].ownerColor)
    Test.equal("Green", result.fields[6].ownerColor)

    local firstField = result.fields[1]
    local deckSpawnX =
        2 * firstField.position.x - firstField.deckSlot.x

    Test.near(
        2 * firstField.position.x - deckSpawnX,
        firstField.heroSlot.x,
        0.0001
    )
    Test.near(
        2 * firstField.position.z - firstField.deckSlot.z,
        firstField.heroSlot.z,
        0.0001
    )

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

    Test.equal(90, result.downRotationDegrees)
    Test.near(7, firstLine.points[1].x, 0.0001)
    Test.near(27, firstLine.points[1].z, 0.0001)
    Test.near(13, firstLine.points[2].x, 0.0001)
    Test.near(27, firstLine.points[2].z, 0.0001)
    Test.near(12, result.heroSlot.x, 0.0001)
    Test.near(14, result.heroSlot.z, 0.0001)
end)

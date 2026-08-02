local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local CardFieldGeometry =
    require("src/card_fields/CardFieldGeometry")

Test.case("card fields build six 7 by 3 sectioned grids", function()
    local result = CardFieldGeometry.buildAll(Config)

    Test.equal(6, #result.fields)
    Test.equal(21, #result.fields[1].cells)
    Test.equal(192, #result.lines)
    Test.equal(Config.deckSlot.row, result.fields[1].deckSlot.row)
    Test.equal(Config.deckSlot.column, result.fields[1].deckSlot.column)
    Test.equal(Config.heroSlot.row, result.fields[1].heroSlot.row)
    Test.equal(Config.heroSlot.column, result.fields[1].heroSlot.column)
    Test.equal(5, result.fields[1].actionZone.defaultSlots)
    Test.near(-10, result.fields[1].actionZone.localLeft, 0.0001)
    Test.near(10, result.fields[1].actionZone.localRight, 0.0001)
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

    local zoneCounts = {}
    local zonesByCell = {}

    for _, cell in ipairs(result.fields[1].cells) do
        zoneCounts[cell.zoneType] =
            (zoneCounts[cell.zoneType] or 0) + 1
        zonesByCell[cell.row .. ":" .. cell.column] =
            cell.zoneType
    end

    Test.equal(1, zoneCounts.abyss)
    Test.equal(5, zoneCounts.action)
    Test.equal(1, zoneCounts.hero)
    Test.equal(1, zoneCounts.purgatory)
    Test.equal(10, zoneCounts.source)
    Test.equal(2, zoneCounts.skill)
    Test.equal(1, zoneCounts.deck)

    -- Geometry rows run opposite the CSV's display order.
    Test.equal("deck", zonesByCell["1:1"])
    Test.equal("source", zonesByCell["1:2"])
    Test.equal("skill", zonesByCell["1:7"])
    Test.equal("purgatory", zonesByCell["2:1"])
    Test.truthy(result.fields[1].zoneCenters.purgatory)
    Test.equal("abyss", zonesByCell["3:1"])
    Test.equal("action", zonesByCell["3:2"])
    Test.equal("hero", zonesByCell["3:7"])

    local firstFieldLines = result.fields[1].lines
    local deckRightX = firstFieldLines[2].points[1].x
    local sourceLeftX = firstFieldLines[8].points[1].x

    Test.near(
        Config.zoneInset * 2,
        sourceLeftX - deckRightX,
        0.0001
    )
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
    Test.equal(Config.fieldY, result.position.y)
    Test.equal(Config.fieldY, result.deckSlot.y)
    Test.equal(Config.fieldY, result.heroSlot.y)
    Test.near(
        Config.fieldY + 0.01,
        firstLine.points[1].y,
        0.0001
    )
    Test.near(7.12, firstLine.points[1].x, 0.0001)
    Test.near(26.88, firstLine.points[1].z, 0.0001)
    Test.near(7.12, firstLine.points[2].x, 0.0001)
    Test.near(25.12, firstLine.points[2].z, 0.0001)
    Test.near(12, result.heroSlot.x, 0.0001)
    Test.near(14, result.heroSlot.z, 0.0001)
end)

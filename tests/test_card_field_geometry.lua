local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local CardFieldGeometry =
    require("src/card_fields/CardFieldGeometry")

Test.case("card fields build six 7 by 3 sectioned grids", function()
    local result = CardFieldGeometry.buildAll(Config)

    Test.equal(6, #result.fields)
    Test.equal(21, #result.fields[1].cells)
    Test.equal(192, #result.lines)
    Test.equal(4, #result.fields[1].deckZoneLines)
    Test.equal(result.fields[1].lines[1], result.fields[1].deckZoneLines[1])
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

Test.case("card field zones cover every configured cell exactly once", function()
    local field = CardFieldGeometry.buildField(Config.fields[1], Config)
    local cellsByCoordinate = {}

    for _, cell in ipairs(field.cells) do
        local key = cell.row .. ":" .. cell.column
        Test.nilValue(
            cellsByCoordinate[key],
            "Cell " .. key .. " belongs to more than one zone."
        )
        cellsByCoordinate[key] = cell
    end

    for row = 1, Config.rows do
        for column = 1, Config.columns do
            Test.truthy(
                cellsByCoordinate[row .. ":" .. column],
                "Missing configured card-field cell."
            )
        end
    end
end)

Test.case("card field geometry supports optional special slots", function()
    local config = {
        columns = 2,
        rows = 1,
        fieldY = 3,
        zoneInset = 0,
        zoneLineThickness = 0.1,
        gridColor = {1, 1, 1, 1},
        zones = {
            {
                key = "source",
                firstColumn = 1,
                lastColumn = 2,
                firstRow = 1,
                lastRow = 1
            }
        }
    }
    local built = CardFieldGeometry.buildField({
        playerColor = "Purple",
        position = {x = 5, z = 6},
        size = {x = 8, z = 4}
    }, config)

    Test.nilValue(built.deckSlot)
    Test.nilValue(built.heroSlot)
    Test.nilValue(built.actionZone)
    Test.equal("Purple", built.ownerColor)
    Test.equal(0, built.downRotationDegrees)
    Test.equal(2, #built.cells)
    Test.equal(4, #built.lines)
end)

Test.case("action geometry supplies stable defaults", function()
    local config = {
        columns = 3,
        rows = 1,
        fieldY = 0,
        zoneInset = 0,
        zoneLineThickness = 0.1,
        gridColor = {1, 1, 1, 1},
        zones = {
            {
                key = "actions",
                type = "action",
                firstColumn = 1,
                lastColumn = 3,
                firstRow = 1,
                lastRow = 1
            }
        }
    }
    local built = CardFieldGeometry.buildField({
        playerColor = "Orange",
        position = {x = 0, z = 0},
        size = {x = 12, z = 6}
    }, config)

    Test.equal(3, built.actionZone.defaultSlots)
    Test.equal(0.2, built.actionZone.cardCenterHeight)
    Test.equal(-6, built.actionZone.localLeft)
    Test.equal(6, built.actionZone.localRight)
    Test.equal(0, built.actionZone.localCenterZ)
end)

Test.case("buildAll preserves field order and aggregates line identity", function()
    local first = {
        playerColor = "First",
        surfaceObjectGuid = "first-guid",
        position = {x = 0, z = 0},
        size = {x = 28, z = 16.5}
    }
    local second = {
        playerColor = "Second",
        surfaceObjectGuid = "second-guid",
        position = {x = 50, z = 0},
        size = {x = 28, z = 16.5}
    }
    local config = {}

    for key, value in pairs(Config) do
        config[key] = value
    end

    config.fields = {first, second}
    local built = CardFieldGeometry.buildAll(config)

    Test.equal("First", built.fields[1].playerColor)
    Test.equal("Second", built.fields[2].playerColor)
    Test.equal(
        #built.fields[1].lines + #built.fields[2].lines,
        #built.lines
    )
    Test.equal(built.fields[1].lines[1], built.lines[1])
    Test.equal(
        built.fields[2].lines[1],
        built.lines[#built.fields[1].lines + 1]
    )
end)

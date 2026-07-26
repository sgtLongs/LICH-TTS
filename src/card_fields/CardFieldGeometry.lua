local CardFieldGeometry = {}

local function rotatePoint(localX, localZ, field)
    local radians = math.rad(field.rotationDegrees or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return {
        x = field.position.x + localX * cosine + localZ * sine,
        z = field.position.z - localX * sine + localZ * cosine
    }
end

local function makeLine(
    field,
    surfaceY,
    startX,
    startZ,
    endX,
    endZ,
    color,
    thickness
)
    local startPoint = rotatePoint(startX, startZ, field)
    local endPoint = rotatePoint(endX, endZ, field)

    return {
        points = {
            {x = startPoint.x, y = surfaceY, z = startPoint.z},
            {x = endPoint.x, y = surfaceY, z = endPoint.z}
        },
        color = color,
        thickness = thickness
    }
end

local function addRectangle(
    lines,
    field,
    surfaceY,
    left,
    top,
    right,
    bottom,
    color,
    thickness
)
    lines[#lines + 1] = makeLine(
        field, surfaceY, left, top, right, top, color, thickness
    )
    lines[#lines + 1] = makeLine(
        field, surfaceY, right, top, right, bottom, color, thickness
    )
    lines[#lines + 1] = makeLine(
        field, surfaceY, right, bottom, left, bottom, color, thickness
    )
    lines[#lines + 1] = makeLine(
        field, surfaceY, left, bottom, left, top, color, thickness
    )
end

local function makeCellPoint(
    field,
    config,
    cellWidth,
    cellHeight,
    gridColumn,
    gridRow,
    runRightToLeft
)
    if runRightToLeft == true then
        gridColumn = config.columns - gridColumn + 1
    end

    local left = -field.size.x * 0.5
    local top = -field.size.z * 0.5
    local localX = left + (gridColumn - 0.5) * cellWidth
    local localZ = top + (gridRow - 0.5) * cellHeight
    local point = rotatePoint(localX, localZ, field)
    point.y = config.fieldY
    return point
end

function CardFieldGeometry.buildField(field, config)
    local lines = {}
    local cells = {}
    local cellWidth = field.size.x / config.columns
    local cellHeight = field.size.z / config.rows
    local left = -field.size.x * 0.5
    local top = -field.size.z * 0.5
    local surfaceY = config.fieldY
    local deckSlot = config.deckSlot
    local deckSlotPoint = nil
    local heroSlot = config.heroSlot
    local heroSlotPoint = nil

    if deckSlot ~= nil then
        deckSlotPoint = makeCellPoint(
            field,
            config,
            cellWidth,
            cellHeight,
            deckSlot.column,
            deckSlot.row,
            deckSlot.columnsRunRightToLeft
        )
        deckSlotPoint.row = deckSlot.row
        deckSlotPoint.column = deckSlot.column
    end

    if heroSlot ~= nil then
        -- Player-facing coordinates call the seven-wide axis "row" and the
        -- three-deep axis "column", opposite the geometry's internal names.
        heroSlotPoint = makeCellPoint(
            field,
            config,
            cellWidth,
            cellHeight,
            heroSlot.row,
            heroSlot.column,
            heroSlot.rowsRunRightToLeft
        )
        heroSlotPoint.row = heroSlot.row
        heroSlotPoint.column = heroSlot.column
    end

    for _, zone in ipairs(config.zones) do
        local zoneLeft = left
            + (zone.firstColumn - 1) * cellWidth
            + config.zoneInset
        local zoneTop = top
            + (zone.firstRow - 1) * cellHeight
            + config.zoneInset
        local zoneRight = left
            + zone.lastColumn * cellWidth
            - config.zoneInset
        local zoneBottom = top
            + zone.lastRow * cellHeight
            - config.zoneInset

        addRectangle(
            lines,
            field,
            surfaceY + 0.01,
            zoneLeft,
            zoneTop,
            zoneRight,
            zoneBottom,
            zone.color or config.gridColor,
            config.zoneLineThickness
        )

        for row = zone.firstRow, zone.lastRow do
            for column = zone.firstColumn, zone.lastColumn do
                cells[#cells + 1] = {
                    row = row,
                    column = column,
                    section = zone.key,
                    zone = zone.key,
                    zoneType = zone.type or zone.key,
                    playerColor = field.playerColor
                }
            end
        end
    end

    return {
        lines = lines,
        cells = cells,
        playerColor = field.playerColor,
        ownerColor = field.ownerColor or field.playerColor,
        surfaceObjectGuid = field.surfaceObjectGuid,
        -- The field rotation also defines "down": from row 1 toward
        -- subsequent rows.
        downRotationDegrees = field.rotationDegrees or 0,
        position = {
            x = field.position.x,
            y = surfaceY,
            z = field.position.z
        },
        deckSlot = deckSlotPoint,
        heroSlot = heroSlotPoint,
        cellWidth = cellWidth,
        cellHeight = cellHeight
    }
end

function CardFieldGeometry.buildAll(config)
    local result = {
        fields = {},
        lines = {}
    }

    for _, field in ipairs(config.fields) do
        local builtField = CardFieldGeometry.buildField(field, config)
        result.fields[#result.fields + 1] = builtField

        for _, line in ipairs(builtField.lines) do
            result.lines[#result.lines + 1] = line
        end
    end

    return result
end

return CardFieldGeometry

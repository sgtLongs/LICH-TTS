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

function CardFieldGeometry.buildField(field, config)
    local lines = {}
    local cells = {}
    local cellWidth = field.size.x / config.columns
    local cellHeight = field.size.z / config.rows
    local left = -field.size.x * 0.5
    local top = -field.size.z * 0.5

    for boundary = 0, config.columns do
        local x = left + boundary * cellWidth
        lines[#lines + 1] = makeLine(
            field,
            config.surfaceY,
            x,
            top,
            x,
            top + field.size.z,
            config.gridColor,
            config.lineThickness
        )
    end

    for boundary = 0, config.rows do
        local z = top + boundary * cellHeight
        lines[#lines + 1] = makeLine(
            field,
            config.surfaceY,
            left,
            z,
            left + field.size.x,
            z,
            config.gridColor,
            config.lineThickness
        )
    end

    for _, section in ipairs(config.sections) do
        local sectionLeft = left
            + (section.firstColumn - 1) * cellWidth
        local sectionTop = top
            + (section.firstRow - 1) * cellHeight
        local sectionRight = left + section.lastColumn * cellWidth
        local sectionBottom = top + section.lastRow * cellHeight

        addRectangle(
            lines,
            field,
            config.surfaceY + 0.01,
            sectionLeft,
            sectionTop,
            sectionRight,
            sectionBottom,
            section.color,
            config.sectionLineThickness
        )

        for row = section.firstRow, section.lastRow do
            for column = section.firstColumn, section.lastColumn do
                cells[#cells + 1] = {
                    row = row,
                    column = column,
                    section = section.key,
                    playerColor = field.playerColor
                }
            end
        end
    end

    return {
        lines = lines,
        cells = cells,
        playerColor = field.playerColor
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

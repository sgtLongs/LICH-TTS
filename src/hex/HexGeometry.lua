local HexGeometry = {}
local SQRT_3 = math.sqrt(3)
local ADJACENT_OFFSETS = {
    {row = 0, column = 1},
    {row = -1, column = 1},
    {row = -1, column = 0},
    {row = 0, column = -1},
    {row = 1, column = -1},
    {row = 1, column = 0}
}

function HexGeometry.cellKey(row, column)
    return tostring(row) .. ":" .. tostring(column)
end

local function rotatePoint(x, z, config)
    local radians = math.rad(config.rotationDegrees)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return {
        x = x * cosine - z * sine + config.offsetX,
        z = x * sine + z * cosine + config.offsetZ
    }
end

function HexGeometry.buildCells(config)
    local gridRadius = config.sideLength - 1
    local cells = {}

    for q = -gridRadius, gridRadius do
        local minimumR = math.max(-gridRadius, -q - gridRadius)
        local maximumR = math.min(gridRadius, -q + gridRadius)

        for r = minimumR, maximumR do
            local center = rotatePoint(
                SQRT_3 * config.hexRadius * (q + r * 0.5),
                1.5 * config.hexRadius * r,
                config
            )

            cells[#cells + 1] = {
                row = r,
                column = q,
                x = center.x,
                z = center.z
            }
        end
    end

    return cells
end

function HexGeometry.indexCells(cells)
    local cellsByKey = {}

    for _, cell in ipairs(cells) do
        cellsByKey[HexGeometry.cellKey(cell.row, cell.column)] = cell
    end

    return cellsByKey
end

function HexGeometry.getAdjacentCells(targetCell, cellsByKey)
    local adjacentCells = {}

    for _, offset in ipairs(ADJACENT_OFFSETS) do
        local key = HexGeometry.cellKey(
            targetCell.row + offset.row,
            targetCell.column + offset.column
        )
        local adjacentCell = cellsByKey[key]

        if adjacentCell ~= nil then
            adjacentCells[key] = adjacentCell
        end
    end

    return adjacentCells
end

local function pointIsInsideCell(localPointer, cell, config)
    local deltaX = localPointer.x - cell.x
    local deltaZ = localPointer.z - cell.z
    local radians = math.rad(-config.rotationDegrees)
    local localX = math.abs(
        deltaX * math.cos(radians) - deltaZ * math.sin(radians)
    )
    local localZ = math.abs(
        deltaX * math.sin(radians) + deltaZ * math.cos(radians)
    )
    local hitRadius = config.hexRadius + config.hitEdgePadding

    return localX <= SQRT_3 * hitRadius * 0.5
        and SQRT_3 * localZ + localX <= SQRT_3 * hitRadius
end

function HexGeometry.findCellAt(cells, localPointer, config)
    local nearest = nil
    local nearestDistanceSquared = nil

    for _, cell in ipairs(cells) do
        local deltaX = localPointer.x - cell.x
        local deltaZ = localPointer.z - cell.z
        local distanceSquared = deltaX * deltaX + deltaZ * deltaZ

        if nearestDistanceSquared == nil
            or distanceSquared < nearestDistanceSquared
        then
            nearest = cell
            nearestDistanceSquared = distanceSquared
        end
    end

    if nearest ~= nil
        and pointIsInsideCell(localPointer, nearest, config)
    then
        return nearest
    end

    return nil
end

return HexGeometry

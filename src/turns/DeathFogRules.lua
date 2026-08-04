local HexPlacementRules = require("src/hex/HexPlacementRules")

local DeathFogRules = {}

local function distanceFromCenter(cell)
    return math.max(
        math.abs(cell.row),
        math.abs(cell.column),
        math.abs(cell.row + cell.column)
    )
end

function DeathFogRules.getCandidates(
    cells,
    placements,
    templatesByKey,
    cellKey
)
    local blockedCells = {}

    for _, placement in ipairs(placements or {}) do
        local template = templatesByKey[placement.templateKey]

        if template == nil or template.allowsDeathFog ~= true then
            for _, occupiedCell in ipairs(
                HexPlacementRules.getOccupiedCells(
                    placement,
                    templatesByKey
                )
            ) do
                blockedCells[
                    cellKey(occupiedCell.row, occupiedCell.column)
                ] = true
            end
        end
    end

    local outermostAvailableDistance = nil

    for _, cell in ipairs(cells or {}) do
        local key = cellKey(cell.row, cell.column)

        if not blockedCells[key] then
            local distance = distanceFromCenter(cell)

            if outermostAvailableDistance == nil
                or distance > outermostAvailableDistance
            then
                outermostAvailableDistance = distance
            end
        end
    end

    local candidates = {}

    if outermostAvailableDistance == nil then
        return candidates
    end

    for _, cell in ipairs(cells or {}) do
        local key = cellKey(cell.row, cell.column)

        if not blockedCells[key]
            and distanceFromCenter(cell) == outermostAvailableDistance
        then
            candidates[key] = cell
        end
    end

    return candidates
end

return DeathFogRules

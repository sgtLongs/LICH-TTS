local HexPlacementRules = require("src/hex/HexPlacementRules")

local SurfaceRules = {}

local function isSurface(template)
    return template ~= nil
        and (template.isSurface == true
            or template.isDeathFog == true)
end

local function blocksSurfaces(template)
    return template ~= nil
        and (template.blocksSurfacePlacement == true
            or template.isDeathFog == true)
end

local function isSourceStone(template)
    return template ~= nil
        and (template.isSourceStone == true
            or template.allowsDeathFog == true)
end

local function distanceFromCenter(cell)
    return math.max(
        math.abs(cell.row),
        math.abs(cell.column),
        math.abs(cell.row + cell.column)
    )
end

function SurfaceRules.canPlace(
    surfaceDefinition,
    cell,
    placements,
    templatesByKey
)
    if surfaceDefinition == nil or cell == nil then
        return false
    end

    for _, placement in ipairs(placements or {}) do
        if HexPlacementRules.occupiesCell(
            placement,
            cell,
            templatesByKey
        ) then
            local template = templatesByKey[placement.templateKey]

            if isSurface(template) then
                if blocksSurfaces(template) then
                    return false
                end
            elseif not isSourceStone(template) then
                return false
            end
        end
    end

    return true
end

function SurfaceRules.getReplacedPlacements(
    cell,
    placements,
    templatesByKey
)
    local replaced = {}

    for _, placement in ipairs(placements or {}) do
        local template = templatesByKey[placement.templateKey]

        if isSurface(template)
            and HexPlacementRules.occupiesCell(
                placement,
                cell,
                templatesByKey
            )
        then
            replaced[#replaced + 1] = placement
        end
    end

    return replaced
end

function SurfaceRules.getCandidates(
    surfaceDefinition,
    cells,
    placements,
    templatesByKey,
    cellKey
)
    local candidates = {}

    for _, cell in ipairs(cells or {}) do
        if SurfaceRules.canPlace(
            surfaceDefinition,
            cell,
            placements,
            templatesByKey
        ) then
            candidates[cellKey(cell.row, cell.column)] = cell
        end
    end

    return candidates
end

function SurfaceRules.getOutermostCandidates(
    surfaceDefinition,
    cells,
    placements,
    templatesByKey,
    cellKey
)
    local available = SurfaceRules.getCandidates(
        surfaceDefinition,
        cells,
        placements,
        templatesByKey,
        cellKey
    )
    local outermostDistance = nil

    for _, cell in pairs(available) do
        local distance = distanceFromCenter(cell)

        if outermostDistance == nil or distance > outermostDistance then
            outermostDistance = distance
        end
    end

    local candidates = {}

    if outermostDistance == nil then
        return candidates
    end

    for key, cell in pairs(available) do
        if distanceFromCenter(cell) == outermostDistance then
            candidates[key] = cell
        end
    end

    return candidates
end

return SurfaceRules

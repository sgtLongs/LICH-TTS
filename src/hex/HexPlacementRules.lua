local HexBoardModel = require("src/hex/HexBoardModel")

local HexPlacementRules = {}

local function cellsMatch(left, right)
    return left ~= nil
        and right ~= nil
        and left.row == right.row
        and left.column == right.column
end

function HexPlacementRules.getOccupiedCells(placement, templatesByKey)
    local occupiedCells = {placement.cell}
    local template = templatesByKey[placement.templateKey]

    if template ~= nil
        and template.occupiesFacingCell == true
        and placement.facingCell ~= nil
    then
        occupiedCells[#occupiedCells + 1] = placement.facingCell
    end

    return occupiedCells
end

function HexPlacementRules.occupiesCell(
    placement,
    cell,
    templatesByKey
)
    if placement == nil or cell == nil then
        return false
    end

    for _, occupiedCell in ipairs(
        HexPlacementRules.getOccupiedCells(placement, templatesByKey)
    ) do
        if cellsMatch(occupiedCell, cell) then
            return true
        end
    end

    return false
end

function HexPlacementRules.findAt(placements, cell, templatesByKey)
    for _, placement in ipairs(placements or {}) do
        if HexPlacementRules.occupiesCell(
            placement,
            cell,
            templatesByKey
        ) then
            return placement
        end
    end

    return nil
end

function HexPlacementRules.findConflicts(
    placements,
    candidate,
    templatesByKey,
    ignoredPlacement
)
    local conflicts = {}
    local seen = {}

    for _, occupiedCell in ipairs(
        HexPlacementRules.getOccupiedCells(candidate, templatesByKey)
    ) do
        local placement = HexPlacementRules.findAt(
            placements,
            occupiedCell,
            templatesByKey
        )

        if placement ~= nil
            and placement ~= ignoredPlacement
            and not seen[placement]
        then
            seen[placement] = true
            conflicts[#conflicts + 1] = placement
        end
    end

    return conflicts
end

function HexPlacementRules.begin(
    template,
    targetCell,
    playerColor,
    adjacentCells,
    replacementPlacement
)
    if template == nil or targetCell == nil then
        return nil
    end

    return {
        template = template,
        targetCell = targetCell,
        playerColor = playerColor,
        adjacentCells = adjacentCells or {},
        replacementPlacement = replacementPlacement
    }
end

function HexPlacementRules.complete(pendingPlacement, facingCell)
    if pendingPlacement == nil or facingCell == nil then
        return nil
    end

    return {
        templateKey = pendingPlacement.template.key,
        cell = HexBoardModel.copyCell(pendingPlacement.targetCell),
        facingCell = HexBoardModel.copyCell(facingCell)
    }
end

return HexPlacementRules

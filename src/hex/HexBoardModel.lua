local HexBoardModel = {}

local function copyCell(cell)
    if type(cell) ~= "table" then
        return nil
    end

    return {
        row = cell.row,
        column = cell.column
    }
end

local function copyPlacement(placement)
    return {
        id = placement.id,
        templateKey = placement.templateKey,
        cell = copyCell(placement.cell),
        facingCell = copyCell(placement.facingCell),
        guid = placement.guid
    }
end

function HexBoardModel.new(initialState)
    local model = {
        selectedCells = {},
        placements = {}
    }

    if type(initialState) == "table" then
        for key, selected in pairs(initialState.selectedCells or {}) do
            if selected == true then
                model.selectedCells[tostring(key)] = true
            end
        end

        for _, placement in ipairs(
            initialState.placements or initialState.placedObjects or {}
        ) do
            if type(placement) == "table" then
                model.placements[#model.placements + 1] =
                    copyPlacement(placement)
            end
        end
    end

    return model
end

function HexBoardModel.clear(model)
    model.selectedCells = {}
    model.placements = {}
end

function HexBoardModel.replace(model, selectedCells, placements)
    local replacement = HexBoardModel.new({
        selectedCells = selectedCells,
        placements = placements
    })
    model.selectedCells = replacement.selectedCells
    model.placements = replacement.placements
    return model
end

function HexBoardModel.isSelected(model, cellKey)
    return model.selectedCells[cellKey] == true
end

function HexBoardModel.setSelected(model, cellKey, selected)
    model.selectedCells[cellKey] = selected == true and true or nil
    return model.selectedCells[cellKey] == true
end

function HexBoardModel.toggleSelected(model, cellKey)
    return HexBoardModel.setSelected(
        model,
        cellKey,
        not HexBoardModel.isSelected(model, cellKey)
    )
end

function HexBoardModel.addPlacement(model, placement)
    model.placements[#model.placements + 1] = placement
    return placement
end

function HexBoardModel.hasPlacement(model, targetPlacement)
    for _, placement in ipairs(model.placements) do
        if placement == targetPlacement then
            return true
        end
    end

    return false
end

function HexBoardModel.removePlacement(model, targetPlacement)
    for index = #model.placements, 1, -1 do
        if model.placements[index] == targetPlacement then
            table.remove(model.placements, index)
            return true
        end
    end

    return false
end

function HexBoardModel.findPlacementByGuid(model, guid)
    if type(guid) ~= "string" then
        return nil
    end

    for _, placement in ipairs(model.placements) do
        if placement.guid == guid then
            return placement
        end
    end

    return nil
end

function HexBoardModel.copyCell(cell)
    return copyCell(cell)
end

function HexBoardModel.copyPlacement(placement)
    return copyPlacement(placement)
end

return HexBoardModel

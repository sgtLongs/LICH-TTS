local HexBoardValidator = require("src/hex/HexBoardState")
local HexPlacementRules = require("src/hex/HexPlacementRules")

local HexBoardCodec = {}

function HexBoardCodec.normalize(boardState, options)
    return HexBoardValidator.normalize(boardState, options)
end

function HexBoardCodec.serialize(model, cells, options)
    local selectedHexes = {}
    local hexObjects = {}

    for _, cell in ipairs(cells or {}) do
        local key = options.cellKey(cell.row, cell.column)

        if model.selectedCells[key] then
            selectedHexes[#selectedHexes + 1] = {
                row = cell.row,
                column = cell.column
            }
        end
    end

    for _, placement in ipairs(model.placements or {}) do
        local occupiedHexes = {}

        for _, occupiedCell in ipairs(
            HexPlacementRules.getOccupiedCells(
                placement,
                options.templatesByKey
            )
        ) do
            occupiedHexes[#occupiedHexes + 1] = {
                row = occupiedCell.row,
                column = occupiedCell.column
            }
        end

        hexObjects[#hexObjects + 1] = {
            type = placement.templateKey,
            hex = {
                row = placement.cell.row,
                column = placement.cell.column
            },
            facing = {
                row = placement.facingCell.row,
                column = placement.facingCell.column
            },
            occupiedHexes = occupiedHexes
        }
    end

    return {
        schemaVersion = options.schemaVersion,
        boardGuid = options.boardGuid,
        selectedHexes = selectedHexes,
        hexObjects = hexObjects
    }
end

return HexBoardCodec

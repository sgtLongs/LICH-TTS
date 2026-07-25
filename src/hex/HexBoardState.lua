local HexGeometry = require("src/hex/HexGeometry")

local HexBoardState = {}

local function copyCell(cell)
    return {
        row = cell.row,
        column = cell.column
    }
end

local function normalizeCell(value, fieldName, cellsByKey)
    if type(value) ~= "table" then
        return nil, fieldName .. " must be an object."
    end

    local row = tonumber(value.row)
    local column = tonumber(value.column)

    if row == nil or column == nil
        or row ~= math.floor(row)
        or column ~= math.floor(column)
    then
        return nil, fieldName .. " must contain integer row and column values."
    end

    local cell = cellsByKey[HexGeometry.cellKey(row, column)]

    if cell == nil then
        return nil, fieldName .. " is outside the hex grid."
    end

    return copyCell(cell)
end

local function cellsMatch(firstCell, secondCell)
    return firstCell.row == secondCell.row
        and firstCell.column == secondCell.column
end

local function getArrayLength(value, fieldName)
    local entryCount = 0
    local highestIndex = 0

    for key, _ in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key ~= math.floor(key)
        then
            return nil, fieldName .. " must be an array."
        end

        entryCount = entryCount + 1
        highestIndex = math.max(highestIndex, key)
    end

    if entryCount ~= highestIndex then
        return nil, fieldName .. " must not contain missing entries."
    end

    return entryCount
end

function HexBoardState.normalize(boardState, options)
    if type(boardState) ~= "table" then
        return nil, "Board-state JSON must contain an object."
    end

    if tonumber(boardState.schemaVersion) ~= options.schemaVersion then
        return nil, "Unsupported board-state schema version."
    end

    if boardState.boardGuid ~= options.boardGuid then
        return nil, "This board state belongs to a different board."
    end

    if type(boardState.selectedHexes) ~= "table" then
        return nil, "selectedHexes must be an array."
    end

    if type(boardState.hexObjects) ~= "table" then
        return nil, "hexObjects must be an array."
    end

    local selectedHexCount, selectedHexesError = getArrayLength(
        boardState.selectedHexes,
        "selectedHexes"
    )

    if selectedHexCount == nil then
        return nil, selectedHexesError
    end

    local hexObjectCount, hexObjectsError = getArrayLength(
        boardState.hexObjects,
        "hexObjects"
    )

    if hexObjectCount == nil then
        return nil, hexObjectsError
    end

    local normalized = {
        selectedCells = {},
        selectedHexCount = 0,
        placements = {}
    }

    for index = 1, selectedHexCount do
        local cell, cellError = normalizeCell(
            boardState.selectedHexes[index],
            "selectedHexes[" .. index .. "]",
            options.cellsByKey
        )

        if cell == nil then
            return nil, cellError
        end

        local key = HexGeometry.cellKey(cell.row, cell.column)

        if not normalized.selectedCells[key] then
            normalized.selectedCells[key] = true
            normalized.selectedHexCount =
                normalized.selectedHexCount + 1
        end
    end

    for index = 1, hexObjectCount do
        local objectState = boardState.hexObjects[index]

        if type(objectState) ~= "table"
            or type(objectState.type) ~= "string"
            or options.templatesByKey[objectState.type] == nil
        then
            return nil,
                "hexObjects[" .. index .. "] has an unknown object type."
        end

        local cell, cellError = normalizeCell(
            objectState.hex,
            "hexObjects[" .. index .. "].hex",
            options.cellsByKey
        )

        if cell == nil then
            return nil, cellError
        end

        local facingCell, facingError = normalizeCell(
            objectState.facing,
            "hexObjects[" .. index .. "].facing",
            options.cellsByKey
        )

        if facingCell == nil then
            return nil, facingError
        end

        local facingKey = HexGeometry.cellKey(
            facingCell.row,
            facingCell.column
        )
        local adjacentCells = HexGeometry.getAdjacentCells(
            cell,
            options.cellsByKey
        )

        if adjacentCells[facingKey] == nil then
            return nil,
                "hexObjects[" .. index
                    .. "].facing must be adjacent to its hex."
        end

        local template = options.templatesByKey[objectState.type]
        local expectedOccupiedCells = {cell}

        if template.occupiesFacingCell == true then
            expectedOccupiedCells[#expectedOccupiedCells + 1] = facingCell
        end

        if objectState.occupiedHexes ~= nil then
            if type(objectState.occupiedHexes) ~= "table" then
                return nil,
                    "hexObjects[" .. index
                        .. "].occupiedHexes must be an array."
            end

            local occupiedHexCount, occupiedHexesError = getArrayLength(
                objectState.occupiedHexes,
                "hexObjects[" .. index .. "].occupiedHexes"
            )

            if occupiedHexCount == nil then
                return nil, occupiedHexesError
            end

            if occupiedHexCount ~= #expectedOccupiedCells then
                return nil,
                    "hexObjects[" .. index .. "].occupiedHexes must contain "
                        .. #expectedOccupiedCells .. " "
                        .. (#expectedOccupiedCells == 1 and "hex." or "hexes.")
            end

            for occupiedIndex, expectedCell in ipairs(
                expectedOccupiedCells
            ) do
                local occupiedCell, occupiedCellError = normalizeCell(
                    objectState.occupiedHexes[occupiedIndex],
                    "hexObjects[" .. index .. "].occupiedHexes["
                        .. occupiedIndex .. "]",
                    options.cellsByKey
                )

                if occupiedCell == nil then
                    return nil, occupiedCellError
                end

                if not cellsMatch(occupiedCell, expectedCell) then
                    return nil,
                        "hexObjects[" .. index
                            .. "].occupiedHexes does not match its hex"
                            .. (template.occupiesFacingCell == true
                                and " and facing hex." or ".")
                end
            end
        end

        normalized.placements[#normalized.placements + 1] = {
            templateKey = objectState.type,
            cell = cell,
            facingCell = facingCell
        }
    end

    return normalized
end

return HexBoardState

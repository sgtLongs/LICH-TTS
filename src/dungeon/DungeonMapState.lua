local DungeonMapState = {}

function DungeonMapState.cellKey(q, r)
    return tostring(q) .. ":" .. tostring(r)
end

function DungeonMapState.buildCells(radius)
    local cells = {}
    local cellsByKey = {}

    for r = -radius, radius do
        local minimumQ = math.max(-radius, -r - radius)
        local maximumQ = math.min(radius, -r + radius)

        for q = minimumQ, maximumQ do
            local cell = {
                index = #cells + 1,
                q = q,
                r = r,
                key = DungeonMapState.cellKey(q, r)
            }

            cells[#cells + 1] = cell
            cellsByKey[cell.key] = cell
        end
    end

    return cells, cellsByKey
end

function DungeonMapState.canTraverse(
    cellsByKey,
    currentCellKey,
    targetCell
)
    if currentCellKey == nil or targetCell.key == currentCellKey then
        return true
    end

    local currentCell = cellsByKey[currentCellKey]

    if currentCell == nil then
        return true
    end

    local differenceQ = targetCell.q - currentCell.q
    local differenceR = targetCell.r - currentCell.r
    local distance = math.max(
        math.abs(differenceQ),
        math.abs(differenceR),
        math.abs(differenceQ + differenceR)
    )

    return distance == 1
end

local function normalizeInteger(value)
    local number = tonumber(value)

    if number == nil or number ~= math.floor(number) then
        return nil
    end

    return number
end

function DungeonMapState.load(savedState, cellsByKey, schemaVersion)
    local loaded = {
        assignmentsByCellKey = {},
        currentCellKey = nil,
        unsupportedVersion = false
    }

    if type(savedState) ~= "table" then
        return loaded
    end

    if savedState.schemaVersion ~= nil
        and tonumber(savedState.schemaVersion) ~= schemaVersion
    then
        loaded.unsupportedVersion = true
        return loaded
    end

    if type(savedState.tiles) == "table" then
        for _, savedTile in ipairs(savedState.tiles) do
            local q = type(savedTile) == "table"
                and normalizeInteger(savedTile.q) or nil
            local r = type(savedTile) == "table"
                and normalizeInteger(savedTile.r) or nil
            local boardSaveId = type(savedTile) == "table"
                and savedTile.boardSaveId or nil
            local key = q ~= nil and r ~= nil
                and DungeonMapState.cellKey(q, r) or nil

            if cellsByKey[key] ~= nil
                and type(boardSaveId) == "string"
                and boardSaveId ~= ""
                and loaded.assignmentsByCellKey[key] == nil
            then
                loaded.assignmentsByCellKey[key] = boardSaveId
            end
        end
    end

    local currentTile = savedState.currentTile
    local currentQ = type(currentTile) == "table"
        and normalizeInteger(currentTile.q) or nil
    local currentR = type(currentTile) == "table"
        and normalizeInteger(currentTile.r) or nil
    local savedCurrentKey = currentQ ~= nil and currentR ~= nil
        and DungeonMapState.cellKey(currentQ, currentR) or nil

    if loaded.assignmentsByCellKey[savedCurrentKey] ~= nil then
        loaded.currentCellKey = savedCurrentKey
    end

    return loaded
end

function DungeonMapState.serialize(
    cells,
    cellsByKey,
    assignmentsByCellKey,
    currentCellKey,
    schemaVersion
)
    local savedTiles = {}

    for _, cell in ipairs(cells) do
        local boardSaveId = assignmentsByCellKey[cell.key]

        if boardSaveId ~= nil then
            savedTiles[#savedTiles + 1] = {
                q = cell.q,
                r = cell.r,
                boardSaveId = boardSaveId
            }
        end
    end

    local currentCell = currentCellKey ~= nil
        and cellsByKey[currentCellKey] or nil

    return {
        schemaVersion = schemaVersion,
        currentTile = currentCell ~= nil and {
            q = currentCell.q,
            r = currentCell.r
        } or nil,
        tiles = savedTiles
    }
end

return DungeonMapState

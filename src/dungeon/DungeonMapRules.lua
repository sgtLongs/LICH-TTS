local DungeonMapState = require("src/dungeon/DungeonMapState")

local DungeonMapRules = {}

local function copyAssignments(assignmentsByCellKey)
    local copied = {}

    for key, boardSaveId in pairs(assignmentsByCellKey or {}) do
        copied[key] = boardSaveId
    end

    return copied
end

function DungeonMapRules.findBoardById(savedBoards, boardSaveId)
    if type(boardSaveId) ~= "string" then
        return nil, nil
    end

    for index, savedBoard in ipairs(savedBoards or {}) do
        if savedBoard.id == boardSaveId then
            return savedBoard, index
        end
    end

    return nil, nil
end

function DungeonMapRules.getPage(savedBoards, page, pageSize)
    savedBoards = type(savedBoards) == "table" and savedBoards or {}
    local normalizedPageSize = math.max(1, math.floor(tonumber(pageSize) or 1))
    local pageCount = math.max(
        1,
        math.ceil(#savedBoards / normalizedPageSize)
    )
    local normalizedPage = math.floor(tonumber(page) or 1)
    normalizedPage = math.max(1, math.min(normalizedPage, pageCount))
    local firstIndex = (normalizedPage - 1) * normalizedPageSize + 1
    local rows = {}

    for row = 1, normalizedPageSize do
        rows[row] = savedBoards[firstIndex + row - 1]
    end

    return {
        page = normalizedPage,
        pageCount = pageCount,
        firstIndex = firstIndex,
        rows = rows
    }
end

function DungeonMapRules.getAssignmentDescription(
    assignmentsByCellKey,
    cell,
    savedBoards
)
    local boardSaveId = assignmentsByCellKey[cell.key]

    if boardSaveId == nil then
        return "Unassigned"
    end

    local savedBoard = DungeonMapRules.findBoardById(
        savedBoards,
        boardSaveId
    )

    if savedBoard == nil then
        return "Missing save (" .. boardSaveId .. ")"
    end

    return savedBoard.name
end

function DungeonMapRules.canTraverse(cellsByKey, currentCellKey, cell)
    return DungeonMapState.canTraverse(cellsByKey, currentCellKey, cell)
end

function DungeonMapRules.assign(
    assignmentsByCellKey,
    currentCellKey,
    selectedCellKey,
    boardSaveId
)
    if selectedCellKey == nil or type(boardSaveId) ~= "string" then
        return assignmentsByCellKey, currentCellKey, false
    end

    local nextAssignments = copyAssignments(assignmentsByCellKey)

    if currentCellKey == selectedCellKey
        and nextAssignments[selectedCellKey] ~= boardSaveId
    then
        currentCellKey = nil
    end

    nextAssignments[selectedCellKey] = boardSaveId
    return nextAssignments, currentCellKey, true
end

function DungeonMapRules.clear(
    assignmentsByCellKey,
    currentCellKey,
    selectedCellKey
)
    if selectedCellKey == nil
        or assignmentsByCellKey[selectedCellKey] == nil
    then
        return assignmentsByCellKey, currentCellKey, false
    end

    local nextAssignments = copyAssignments(assignmentsByCellKey)
    nextAssignments[selectedCellKey] = nil

    if currentCellKey == selectedCellKey then
        currentCellKey = nil
    end

    return nextAssignments, currentCellKey, true
end

function DungeonMapRules.countAssignments(assignmentsByCellKey)
    local count = 0

    for _ in pairs(assignmentsByCellKey or {}) do
        count = count + 1
    end

    return count
end

function DungeonMapRules.countValidAssignments(
    assignmentsByCellKey,
    savedBoards
)
    local count = 0

    for _, boardSaveId in pairs(assignmentsByCellKey or {}) do
        if DungeonMapRules.findBoardById(savedBoards, boardSaveId) ~= nil then
            count = count + 1
        end
    end

    return count
end

function DungeonMapRules.validateTraversal(parameters)
    local boardSaveId = parameters.assignmentsByCellKey[
        parameters.cell.key
    ]

    if boardSaveId == nil then
        return {accepted = false, reason = "unassigned"}
    end

    if parameters.traversalLocked then
        return {accepted = false, reason = "locked"}
    end

    if not DungeonMapRules.canTraverse(
        parameters.cellsByKey,
        parameters.currentCellKey,
        parameters.cell
    ) then
        return {accepted = false, reason = "notAdjacent"}
    end

    local savedBoard = DungeonMapRules.findBoardById(
        parameters.savedBoards,
        boardSaveId
    )

    if savedBoard == nil then
        return {
            accepted = false,
            reason = "missingSave",
            boardSaveId = boardSaveId
        }
    end

    if not parameters.loaderAvailable then
        return {accepted = false, reason = "unavailable"}
    end

    return {
        accepted = true,
        boardSaveId = boardSaveId,
        savedBoard = savedBoard
    }
end

return DungeonMapRules

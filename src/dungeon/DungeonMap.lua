local Config = require("src/dungeon/DungeonMapConfig")

local DungeonMap = {}
local cells = {}
local cellsByKey = {}
local assignmentsByCellKey = {}
local currentCellKey = nil
local activePlayerColor = nil
local editMode = false
local selectedCellKey = nil
local boardListPage = 1
local traversalLocked = false
local boardLoadGeneration = 0
local externalLoadState = nil
local context = {
    getSavedBoardSummaries = nil,
    loadSavedBoardById = nil,
    persistState = nil
}

local function cellKey(q, r)
    return tostring(q) .. ":" .. tostring(r)
end

local function buildCells()
    cells = {}
    cellsByKey = {}

    for r = -Config.radius, Config.radius do
        local minimumQ = math.max(-Config.radius, -r - Config.radius)
        local maximumQ = math.min(Config.radius, -r + Config.radius)

        for q = minimumQ, maximumQ do
            local cell = {
                index = #cells + 1,
                q = q,
                r = r,
                key = cellKey(q, r)
            }

            cells[#cells + 1] = cell
            cellsByKey[cell.key] = cell
        end
    end
end

buildCells()

local function isAdmin(playerColor)
    local player = Player[playerColor]
    return player ~= nil and player.admin == true
end

local function requireAdmin(playerColor)
    if isAdmin(playerColor) then
        return true
    end

    broadcastToColor(
        "Only an admin can edit the dungeon map.",
        playerColor,
        Config.chatColors.denied
    )
    return false
end

local function setStatus(message, color)
    UI.setAttribute(Config.ui.statusId, "text", message or "")
    UI.setAttribute(
        Config.ui.statusId,
        "color",
        color or Config.statusColors.normal
    )
end

local function getSavedBoards()
    if context.getSavedBoardSummaries == nil then
        return {}
    end

    local savedBoards = context.getSavedBoardSummaries()

    if type(savedBoards) ~= "table" then
        return {}
    end

    return savedBoards
end

local function findBoardById(savedBoards, boardSaveId)
    if type(boardSaveId) ~= "string" then
        return nil, nil
    end

    for index, savedBoard in ipairs(savedBoards) do
        if savedBoard.id == boardSaveId then
            return savedBoard, index
        end
    end

    return nil, nil
end

local function getPageCount(savedBoards)
    return math.max(
        1,
        math.ceil(#savedBoards / Config.boardListPageSize)
    )
end

local function setMode(isEditing)
    editMode = isEditing
    UI.setAttribute(
        Config.ui.browsePageId,
        "active",
        isEditing and "false" or "true"
    )
    UI.setAttribute(
        Config.ui.editPageId,
        "active",
        isEditing and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.modeTitleId,
        "text",
        isEditing and "EDIT DUNGEON" or "DUNGEON MAP"
    )
end

local function getAssignmentDescription(cell, savedBoards)
    local boardSaveId = assignmentsByCellKey[cell.key]

    if boardSaveId == nil then
        return "Unassigned"
    end

    local savedBoard = findBoardById(savedBoards, boardSaveId)

    if savedBoard == nil then
        return "Missing save (" .. boardSaveId .. ")"
    end

    return savedBoard.name
end

local function canTraverseToCell(cell)
    if currentCellKey == nil or cell.key == currentCellKey then
        return true
    end

    local currentCell = cellsByKey[currentCellKey]

    if currentCell == nil then
        return true
    end

    local differenceQ = cell.q - currentCell.q
    local differenceR = cell.r - currentCell.r
    local distance = math.max(
        math.abs(differenceQ),
        math.abs(differenceR),
        math.abs(differenceQ + differenceR)
    )

    return distance == 1
end

local function refreshTiles(savedBoards)
    for _, cell in ipairs(cells) do
        local buttonId = Config.ui.tileButtonPrefix .. cell.index
        local boardSaveId = assignmentsByCellKey[cell.key]
        local savedBoard = findBoardById(savedBoards, boardSaveId)
        local tileColors = Config.tileColors.empty
        local textColor = Config.tileTextColor

        if boardSaveId ~= nil and savedBoard == nil then
            tileColors = Config.tileColors.missing
        elseif boardSaveId ~= nil
            and not editMode
            and not canTraverseToCell(cell)
        then
            tileColors = Config.tileColors.unreachable
        elseif boardSaveId ~= nil then
            tileColors = Config.tileColors.assigned
        end

        if cell.key == currentCellKey then
            tileColors = Config.tileColors.current
            textColor = Config.currentTileTextColor
        end

        if editMode and cell.key == selectedCellKey then
            tileColors = Config.tileColors.selected
            textColor = Config.tileTextColor
        end

        UI.setAttribute(buttonId, "colors", tileColors)
        UI.setAttribute(buttonId, "textColor", textColor)
        UI.setAttribute(
            buttonId,
            "text",
            cell.q .. ", " .. cell.r
        )
        UI.setAttribute(
            buttonId,
            "active",
            (editMode or boardSaveId ~= nil) and "true" or "false"
        )
        UI.setAttribute(
            buttonId,
            "tooltip",
            "Hex " .. cell.q .. ", " .. cell.r .. ": "
                .. getAssignmentDescription(cell, savedBoards)
                .. (
                    boardSaveId ~= nil
                    and not editMode
                    and not canTraverseToCell(cell)
                    and " (not adjacent to the current level)"
                    or ""
                )
        )
    end
end

local function refreshCurrentLevel(savedBoards)
    local currentCell = currentCellKey ~= nil
        and cellsByKey[currentCellKey] or nil

    if currentCell == nil then
        UI.setAttribute(
            Config.ui.currentLevelLabelId,
            "text",
            "Current level: none"
        )
        return
    end

    UI.setAttribute(
        Config.ui.currentLevelLabelId,
        "text",
        "Current: " .. getAssignmentDescription(
            currentCell,
            savedBoards
        ) .. "  (" .. currentCell.q .. ", " .. currentCell.r .. ")"
    )
end

local function refreshSelectedTile(savedBoards)
    local selectedCell = selectedCellKey ~= nil
        and cellsByKey[selectedCellKey] or nil

    if selectedCell == nil then
        UI.setAttribute(
            Config.ui.selectedTileLabelId,
            "text",
            "Select a hex, then click a board save to assign it."
        )
        return
    end

    UI.setAttribute(
        Config.ui.selectedTileLabelId,
        "text",
        "Hex " .. selectedCell.q .. ", " .. selectedCell.r
            .. "\nAssigned: "
            .. getAssignmentDescription(selectedCell, savedBoards)
    )
end

local function refreshBoardList(savedBoards)
    local pageCount = getPageCount(savedBoards)
    boardListPage = math.max(1, math.min(boardListPage, pageCount))
    local firstIndex = (boardListPage - 1)
        * Config.boardListPageSize + 1
    local selectedBoardSaveId = selectedCellKey ~= nil
        and assignmentsByCellKey[selectedCellKey] or nil

    for row = 1, Config.boardListPageSize do
        local boardIndex = firstIndex + row - 1
        local savedBoard = savedBoards[boardIndex]
        local buttonId = Config.ui.boardButtonPrefix .. row

        if savedBoard ~= nil then
            UI.setAttribute(buttonId, "active", "true")
            UI.setAttribute(buttonId, "text", savedBoard.name)
            UI.setAttribute(buttonId, "tooltip", savedBoard.name)
            UI.setAttribute(
                buttonId,
                "colors",
                savedBoard.id == selectedBoardSaveId
                    and Config.uiColors.assignedBoard
                    or Config.uiColors.board
            )
        else
            UI.setAttribute(buttonId, "active", "false")
        end
    end

    UI.setAttribute(
        Config.ui.noBoardsLabelId,
        "active",
        #savedBoards == 0 and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.boardPageLabelId,
        "text",
        "Page " .. boardListPage .. " / " .. pageCount
    )
    UI.setAttribute(
        Config.ui.previousPageButtonId,
        "interactable",
        boardListPage > 1 and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.nextPageButtonId,
        "interactable",
        boardListPage < pageCount and "true" or "false"
    )
end

local function refreshUi()
    local savedBoards = getSavedBoards()

    refreshTiles(savedBoards)
    refreshCurrentLevel(savedBoards)
    refreshSelectedTile(savedBoards)
    refreshBoardList(savedBoards)

    return savedBoards
end

local function close()
    activePlayerColor = nil
    editMode = false
    selectedCellKey = nil
    boardListPage = 1
    UI.setAttribute(Config.ui.rootId, "active", "false")
end

local function countAssignments()
    local assignmentCount = 0

    for _ in pairs(assignmentsByCellKey) do
        assignmentCount = assignmentCount + 1
    end

    return assignmentCount
end

local function countValidAssignments(savedBoards)
    local validAssignmentCount = 0

    for _, boardSaveId in pairs(assignmentsByCellKey) do
        if findBoardById(savedBoards, boardSaveId) ~= nil then
            validAssignmentCount = validAssignmentCount + 1
        end
    end

    return validAssignmentCount
end

local function setBrowseStatus(savedBoards)
    if traversalLocked then
        setStatus(
            "A board setup is loading. Dungeon traversal is paused.",
            Config.statusColors.warning
        )
    elseif countValidAssignments(savedBoards) > 0 then
        setStatus(
            "Click the current level or a glowing touching hex to load it.",
            Config.statusColors.normal
        )
    elseif #savedBoards == 0 then
        setStatus(
            "No levels yet. Save a board in Settings, then edit the map.",
            Config.statusColors.warning
        )
    elseif countAssignments() > 0 then
        setStatus(
            "Dungeon assignments reference missing saves. An admin can "
                .. "repair them in EDIT MAP.",
            Config.statusColors.warning
        )
    else
        setStatus(
            "No levels assigned yet. An admin can choose EDIT MAP.",
            Config.statusColors.warning
        )
    end
end

local function open(playerColor)
    activePlayerColor = playerColor
    selectedCellKey = nil
    boardListPage = 1
    setMode(false)
    UI.setAttribute(Config.ui.rootId, "visibility", playerColor)
    UI.setAttribute(Config.ui.rootId, "active", "true")

    setBrowseStatus(refreshUi())
end

local function persistState()
    if context.persistState == nil then
        return false
    end

    return context.persistState()
end

local function beginBoardLoad()
    boardLoadGeneration = boardLoadGeneration + 1
    return boardLoadGeneration
end

local function selectCellForEditing(cell)
    selectedCellKey = cell.key
    local savedBoards = getSavedBoards()
    local assignedBoardId = assignmentsByCellKey[cell.key]
    local _, assignedBoardIndex = findBoardById(
        savedBoards,
        assignedBoardId
    )

    if assignedBoardIndex ~= nil then
        boardListPage = math.ceil(
            assignedBoardIndex / Config.boardListPageSize
        )
    end

    refreshUi()
    setStatus(
        "Choose a saved board to assign to this hex.",
        Config.statusColors.normal
    )
end

local function assignBoard(playerColor, row)
    if selectedCellKey == nil then
        setStatus(
            "Select a dungeon hex before choosing a board save.",
            Config.statusColors.failure
        )
        return
    end

    local savedBoards = getSavedBoards()
    local boardIndex = (boardListPage - 1)
        * Config.boardListPageSize + row
    local savedBoard = savedBoards[boardIndex]

    if savedBoard == nil then
        return
    end

    if currentCellKey == selectedCellKey
        and assignmentsByCellKey[selectedCellKey] ~= savedBoard.id
    then
        currentCellKey = nil
    end

    assignmentsByCellKey[selectedCellKey] = savedBoard.id
    local persistedImmediately = persistState()
    refreshUi()
    setStatus(
        "Assigned " .. savedBoard.name .. " to the selected hex."
            .. (persistedImmediately
                and ""
                or " Save the TTS game to make it permanent."),
        persistedImmediately
            and Config.statusColors.success
            or Config.statusColors.warning
    )
end

local function clearSelectedCell()
    if selectedCellKey == nil then
        setStatus(
            "Select a dungeon hex before clearing it.",
            Config.statusColors.failure
        )
        return
    end

    if assignmentsByCellKey[selectedCellKey] == nil then
        setStatus(
            "The selected hex is already unassigned.",
            Config.statusColors.warning
        )
        return
    end

    assignmentsByCellKey[selectedCellKey] = nil

    if currentCellKey == selectedCellKey then
        currentCellKey = nil
    end

    local persistedImmediately = persistState()
    refreshUi()
    setStatus(
        "The selected dungeon hex was cleared."
            .. (persistedImmediately
                and ""
                or " Save the TTS game to make it permanent."),
        persistedImmediately
            and Config.statusColors.success
            or Config.statusColors.warning
    )
end

local function traverseToCell(playerColor, cell)
    local boardSaveId = assignmentsByCellKey[cell.key]

    if boardSaveId == nil then
        setStatus(
            "That dungeon hex does not have a board save yet.",
            Config.statusColors.failure
        )
        return
    end

    if traversalLocked then
        setStatus(
            "A dungeon level is already loading.",
            Config.statusColors.warning
        )
        return
    end

    if not canTraverseToCell(cell) then
        setStatus(
            "You can only traverse to the current level or a touching hex.",
            Config.statusColors.warning
        )
        return
    end

    local savedBoard = findBoardById(getSavedBoards(), boardSaveId)

    if savedBoard == nil then
        setStatus(
            "That hex references a missing board save. Edit it to repair "
                .. "the assignment.",
            Config.statusColors.failure
        )
        return
    end

    if context.loadSavedBoardById == nil then
        setStatus(
            "Dungeon traversal is not available.",
            Config.statusColors.failure
        )
        return
    end

    traversalLocked = true
    local loadGeneration = beginBoardLoad()
    local loadAccepted = false
    local completionArrived = false
    local completionSucceeded = false
    local correctionWindowElapsed = false
    local traversalFinalized = false
    local loadMessage = nil

    local function finalizeTraversal(succeeded)
        if traversalFinalized then
            return
        end

        traversalFinalized = true

        if loadGeneration ~= boardLoadGeneration then
            return
        end

        traversalLocked = false

        if not succeeded then
            currentCellKey = nil
            broadcastToColor(
                (loadMessage or "The dungeon level loaded.")
                    .. " Some objects did not finish loading, so the "
                    .. "dungeon position was not saved.",
                playerColor,
                Config.chatColors.failure
            )
            return
        end

        currentCellKey = cell.key
        local persistedImmediately = persistState()
        local persistenceWarning = persistedImmediately
            and ""
            or " Save the TTS game to keep this position."

        broadcastToColor(
            loadMessage .. persistenceWarning,
            playerColor,
            persistedImmediately
                and Config.chatColors.success
                or Config.chatColors.failure
        )
    end

    local function finalizeTraversalIfReady()
        if loadAccepted
            and loadGeneration == boardLoadGeneration
            and completionArrived
            and correctionWindowElapsed
        then
            finalizeTraversal(completionSucceeded)
        end
    end

    local function onLoadCompleted(succeeded)
        if completionArrived or traversalFinalized then
            return
        end

        completionArrived = true
        completionSucceeded = succeeded == true

        Wait.frames(function()
            correctionWindowElapsed = true
            finalizeTraversalIfReady()
        end, Config.traversalLockFrames)
    end

    local callSucceeded, loaded, message = pcall(
        context.loadSavedBoardById,
        boardSaveId,
        playerColor,
        onLoadCompleted
    )

    if not callSucceeded then
        loaded = false
        message = "Could not load that dungeon level."
    end

    if not loaded then
        traversalFinalized = true

        if loadGeneration == boardLoadGeneration then
            traversalLocked = false
        end

        setStatus(message, Config.statusColors.failure)
        broadcastToColor(
            message,
            playerColor,
            Config.chatColors.failure
        )
        return
    end

    loadAccepted = true
    loadMessage = type(message) == "string"
        and message
        or "Loaded " .. savedBoard.name .. "."
    currentCellKey = nil
    close()

    Wait.frames(function()
        if not traversalFinalized and not completionArrived then
            finalizeTraversal(false)
        end
    end, Config.traversalTimeoutFrames)

    finalizeTraversalIfReady()
end

local function normalizeInteger(value)
    local number = tonumber(value)

    if number == nil or number ~= math.floor(number) then
        return nil
    end

    return number
end

local function loadSavedState(savedState)
    assignmentsByCellKey = {}
    currentCellKey = nil

    if type(savedState) ~= "table" then
        return
    end

    if savedState.schemaVersion ~= nil
        and tonumber(savedState.schemaVersion) ~= Config.schemaVersion
    then
        print("DungeonMap: ignored an unsupported saved-state version.")
        return
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
                and cellKey(q, r) or nil

            if cellsByKey[key] ~= nil
                and type(boardSaveId) == "string"
                and boardSaveId ~= ""
                and assignmentsByCellKey[key] == nil
            then
                assignmentsByCellKey[key] = boardSaveId
            end
        end
    end

    local currentTile = savedState.currentTile
    local currentQ = type(currentTile) == "table"
        and normalizeInteger(currentTile.q) or nil
    local currentR = type(currentTile) == "table"
        and normalizeInteger(currentTile.r) or nil
    local savedCurrentKey = currentQ ~= nil and currentR ~= nil
        and cellKey(currentQ, currentR) or nil

    if assignmentsByCellKey[savedCurrentKey] ~= nil then
        currentCellKey = savedCurrentKey
    end
end

function DungeonMap.initialize(parameters, savedState)
    context.getSavedBoardSummaries = parameters.getSavedBoardSummaries
    context.loadSavedBoardById = parameters.loadSavedBoardById
    context.persistState = parameters.persistState
    activePlayerColor = nil
    editMode = false
    selectedCellKey = nil
    boardListPage = 1
    traversalLocked = false
    boardLoadGeneration = 0
    externalLoadState = nil

    loadSavedState(savedState)
    setMode(false)
    close()
end

function DungeonMap.getSaveState()
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
        schemaVersion = Config.schemaVersion,
        currentTile = currentCell ~= nil and {
            q = currentCell.q,
            r = currentCell.r
        } or nil,
        tiles = savedTiles
    }
end

function DungeonMap.handleAction(playerColor, action)
    if action == "toggle" then
        if activePlayerColor == playerColor then
            close()
        else
            open(playerColor)
        end

        return
    end

    if activePlayerColor ~= playerColor then
        return
    end

    if action == "close" then
        close()
        return
    end

    if action == "edit" then
        if not requireAdmin(playerColor) then
            return
        end

        selectedCellKey = nil
        boardListPage = 1
        setMode(true)
        refreshUi()
        setStatus(
            "Select any hex to assign or clear its board save.",
            Config.statusColors.normal
        )
        return
    end

    if action == "done" then
        selectedCellKey = nil
        boardListPage = 1
        setMode(false)
        setBrowseStatus(refreshUi())
        return
    end

    if action == "previous" and editMode then
        boardListPage = boardListPage - 1
        refreshUi()
        return
    end

    if action == "next" and editMode then
        boardListPage = boardListPage + 1
        refreshUi()
        return
    end

    if action == "clear" and editMode then
        if requireAdmin(playerColor) then
            clearSelectedCell()
        end

        return
    end

    local tileIndex = tonumber(string.match(action, "^tile(%d+)$"))

    if tileIndex ~= nil and cells[tileIndex] ~= nil then
        if editMode then
            if requireAdmin(playerColor) then
                selectCellForEditing(cells[tileIndex])
            end
        else
            traverseToCell(playerColor, cells[tileIndex])
        end

        return
    end

    local boardRow = tonumber(string.match(action, "^board(%d+)$"))

    if boardRow ~= nil and editMode and requireAdmin(playerColor) then
        assignBoard(playerColor, boardRow)
    end
end

function DungeonMap.onSavedBoardsChanged()
    if activePlayerColor ~= nil then
        local savedBoards = refreshUi()

        if not editMode then
            setBrowseStatus(savedBoards)
        end
    end
end

function DungeonMap.onExternalBoardLoadStarted(boardSaveId)
    local loadGeneration = beginBoardLoad()

    externalLoadState = {
        generation = loadGeneration,
        boardSaveId = boardSaveId,
        previousCellKey = currentCellKey,
        completionArrived = false
    }
    currentCellKey = nil
    traversalLocked = true

    if activePlayerColor ~= nil then
        refreshUi()
        setStatus(
            "A board setup is loading. Dungeon traversal is paused.",
            Config.statusColors.warning
        )
    end

    Wait.frames(function()
        if externalLoadState ~= nil
            and externalLoadState.generation == loadGeneration
            and boardLoadGeneration == loadGeneration
            and not externalLoadState.completionArrived
        then
            externalLoadState = nil
            traversalLocked = false

            if activePlayerColor ~= nil then
                setBrowseStatus(refreshUi())
            end
        end
    end, Config.traversalTimeoutFrames)

    return loadGeneration
end

function DungeonMap.onExternalBoardLoadCompleted(
    loadGeneration,
    boardSaveId,
    succeeded
)
    local loadState = externalLoadState

    if loadState == nil
        or loadState.generation ~= loadGeneration
        or boardLoadGeneration ~= loadGeneration
    then
        return false
    end

    loadState.completionArrived = true

    Wait.frames(function()
        if externalLoadState ~= loadState
            or boardLoadGeneration ~= loadGeneration
        then
            return
        end

        externalLoadState = nil
        traversalLocked = false

        if succeeded
            and loadState.boardSaveId == boardSaveId
            and loadState.previousCellKey ~= nil
            and assignmentsByCellKey[loadState.previousCellKey]
                == boardSaveId
        then
            currentCellKey = loadState.previousCellKey
        else
            currentCellKey = nil
        end

        if succeeded then
            persistState()
        end

        if activePlayerColor ~= nil then
            setBrowseStatus(refreshUi())
        end
    end, Config.traversalLockFrames)

    return true
end

return DungeonMap

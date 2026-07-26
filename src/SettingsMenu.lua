local Config = require("src/config/SettingsConfig")

local SettingsMenu = {}
local activePlayerColor = nil
local jsonDraftsByPlayerColor = {}
local nameDraftsByPlayerColor = {}
local savedBoards = {}
local selectedBoardIndex = nil
local nextBoardId = 1
local boardListPage = 1
local editMode = false
local context = {
    getBoardState = nil,
    getBoardStateJson = nil,
    loadBoardState = nil,
    loadBoardStateJson = nil,
    persistState = nil,
    onSavedBoardsChanged = nil,
    onBoardLoadStarted = nil,
    onBoardLoadCompleted = nil,
    setEditMode = nil,
    renewDeckSlotButton = nil
}

local function isAdmin(playerColor)
    local player = Player[playerColor]
    return player ~= nil and player.admin == true
end

local function setStatus(message, color)
    UI.setAttribute(Config.ui.statusId, "text", message or "")

    if color ~= nil then
        UI.setAttribute(Config.ui.statusId, "color", color)
    end
end

local function close()
    activePlayerColor = nil
    UI.setAttribute(Config.ui.rootId, "active", "false")
end

local function setPage(pageId)
    UI.setAttribute(
        Config.ui.generalPageId,
        "active",
        pageId == Config.ui.generalPageId and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.savePageId,
        "active",
        pageId == Config.ui.savePageId and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.jsonPageId,
        "active",
        pageId == Config.ui.jsonPageId and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.generalTabButtonId,
        "colors",
        pageId == Config.ui.generalPageId
            and Config.uiColors.selectedTab
            or Config.uiColors.tab
    )
    UI.setAttribute(
        Config.ui.saveTabButtonId,
        "colors",
        pageId ~= Config.ui.generalPageId
            and Config.uiColors.selectedTab
            or Config.uiColors.tab
    )
end

local function requireAdmin(playerColor)
    if isAdmin(playerColor) then
        return true
    end

    broadcastToColor(
        "Only an admin can change board settings.",
        playerColor,
        Config.colors.denied
    )
    return false
end

local function trim(value)
    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function findBoardByName(name)
    local normalizedName = string.lower(name)

    for index, savedBoard in ipairs(savedBoards) do
        if string.lower(savedBoard.name) == normalizedName then
            return index
        end
    end

    return nil
end

local function isValidBoardId(boardId)
    return type(boardId) == "string" and trim(boardId) ~= ""
end

local function findBoardById(boardId)
    if not isValidBoardId(boardId) then
        return nil
    end

    for index, savedBoard in ipairs(savedBoards) do
        if savedBoard.id == boardId then
            return index
        end
    end

    return nil
end

local function normalizeNextBoardId(value)
    local normalizedValue = tonumber(value)

    if normalizedValue == nil
        or normalizedValue < 1
        or normalizedValue ~= math.floor(normalizedValue)
    then
        return nil
    end

    return normalizedValue
end

local function advanceNextBoardIdPast(boardId)
    local numericId = tonumber(string.match(boardId, "^board%-(%d+)$"))

    if numericId ~= nil and numericId >= nextBoardId then
        nextBoardId = numericId + 1
    end
end

local function allocateBoardId(reservedBoardIds)
    local boardId = "board-" .. nextBoardId

    while findBoardById(boardId)
        or (reservedBoardIds ~= nil and reservedBoardIds[boardId])
    do
        nextBoardId = nextBoardId + 1
        boardId = "board-" .. nextBoardId
    end

    nextBoardId = nextBoardId + 1
    return boardId
end

local function isSavedBoardCandidate(savedBoard)
    return type(savedBoard) == "table"
        and type(savedBoard.name) == "string"
        and trim(savedBoard.name) ~= ""
        and type(savedBoard.boardState) == "table"
end

local function loadSavedBoard(savedBoard, playerColor, onCompleted)
    if savedBoard == nil then
        return false, "Select a saved board before loading."
    end

    if context.loadBoardState == nil then
        return false, "Board loading is unavailable."
    end

    local succeeded, message = context.loadBoardState(
        savedBoard.boardState,
        playerColor,
        onCompleted
    )

    if succeeded then
        message = "Loaded " .. savedBoard.name .. ". " .. message
    end

    return succeeded, message
end

local function createExternalLoadTracker(boardSaveId, playerColor)
    local loadAccepted = false
    local completionArrived = false
    local completionSucceeded = false
    local completionReported = false
    local loadGeneration = nil

    local function reportCompletionIfReady()
        if completionReported
            or not loadAccepted
            or not completionArrived
        then
            return
        end

        completionReported = true

        local completionAccepted = true

        if context.onBoardLoadCompleted ~= nil then
            completionAccepted = context.onBoardLoadCompleted(
                loadGeneration,
                boardSaveId,
                completionSucceeded
            ) ~= false
        end

        if not completionSucceeded and completionAccepted then
            local failureMessage =
                "The board changed, but one or more objects did not "
                    .. "finish loading."

            setStatus(failureMessage, "#FCA5A5")
            broadcastToColor(
                failureMessage,
                playerColor,
                Config.colors.failure
            )
        end
    end

    local function onCompleted(succeeded)
        if completionArrived then
            return
        end

        completionArrived = true
        completionSucceeded = succeeded == true
        reportCompletionIfReady()
    end

    local function markAccepted()
        loadAccepted = true

        if context.onBoardLoadStarted ~= nil then
            loadGeneration = context.onBoardLoadStarted(boardSaveId)
        end

        reportCompletionIfReady()
    end

    return onCompleted, markAccepted
end

local function getPageCount()
    return math.max(
        1,
        math.ceil(#savedBoards / Config.boardListPageSize)
    )
end

local function refreshBoardList(playerColor)
    local pageCount = getPageCount()
    boardListPage = math.max(1, math.min(boardListPage, pageCount))
    local firstIndex = (boardListPage - 1)
        * Config.boardListPageSize + 1

    for row = 1, Config.boardListPageSize do
        local boardIndex = firstIndex + row - 1
        local savedBoard = savedBoards[boardIndex]
        local buttonId = Config.ui.boardButtonPrefix .. row

        if savedBoard ~= nil then
            UI.setAttribute(buttonId, "active", "true")
            UI.setAttribute(buttonId, "text", savedBoard.name)
            UI.setAttribute(
                buttonId,
                "colors",
                boardIndex == selectedBoardIndex
                    and Config.uiColors.selectedBoard
                    or Config.uiColors.board
            )
        else
            UI.setAttribute(buttonId, "active", "false")
        end
    end

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

    local selectedBoard = selectedBoardIndex ~= nil
        and savedBoards[selectedBoardIndex] or nil

    UI.setAttribute(
        Config.ui.selectedBoardLabelId,
        "text",
        selectedBoard ~= nil
            and "Selected: " .. selectedBoard.name
            or "No saved board selected"
    )

    if playerColor ~= nil and nameDraftsByPlayerColor[playerColor] == nil then
        nameDraftsByPlayerColor[playerColor] = selectedBoard ~= nil
            and selectedBoard.name or ""
    end
end

local function selectBoard(playerColor, boardIndex)
    if savedBoards[boardIndex] == nil then
        return
    end

    selectedBoardIndex = boardIndex
    nameDraftsByPlayerColor[playerColor] = savedBoards[boardIndex].name
    UI.setAttribute(
        Config.ui.boardNameInputId,
        "text",
        savedBoards[boardIndex].name
    )
    refreshBoardList(playerColor)
    setStatus("Board selected. Choose LOAD SELECTED to restore it.", "#CBD5E1")
end

local function open(playerColor)
    activePlayerColor = playerColor
    local playerIsAdmin = isAdmin(playerColor)
    setPage(Config.ui.generalPageId)
    refreshBoardList(playerColor)
    UI.setAttribute(Config.ui.rootId, "visibility", playerColor)
    UI.setAttribute(
        Config.ui.boardNameInputId,
        "text",
        nameDraftsByPlayerColor[playerColor] or ""
    )
    UI.setAttribute(
        Config.ui.editModeToggleId,
        "isOn",
        editMode and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.editModeToggleId,
        "interactable",
        playerIsAdmin and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.saveTabButtonId,
        "interactable",
        playerIsAdmin and "true" or "false"
    )
    setStatus(
        "Enable Edit mode to add objects to the hex grid.",
        "#CBD5E1"
    )
    UI.setAttribute(Config.ui.rootId, "active", "true")
end

function SettingsMenu.initialize(parameters, savedState)
    context.getBoardState = parameters.getBoardState
    context.getBoardStateJson = parameters.getBoardStateJson
    context.loadBoardState = parameters.loadBoardState
    context.loadBoardStateJson = parameters.loadBoardStateJson
    context.persistState = parameters.persistState
    context.onSavedBoardsChanged = parameters.onSavedBoardsChanged
    context.onBoardLoadStarted = parameters.onBoardLoadStarted
    context.onBoardLoadCompleted = parameters.onBoardLoadCompleted
    context.setEditMode = parameters.setEditMode
    context.renewDeckSlotButton = parameters.renewDeckSlotButton
    activePlayerColor = nil
    jsonDraftsByPlayerColor = {}
    nameDraftsByPlayerColor = {}
    savedBoards = {}
    selectedBoardIndex = nil
    nextBoardId = 1
    boardListPage = 1
    editMode = true

    if type(savedState) == "table"
        and savedState.schemaVersion ~= nil
        and tonumber(savedState.schemaVersion)
            ~= Config.legacySettingsSchemaVersion
        and tonumber(savedState.schemaVersion)
            ~= Config.settingsSchemaVersion
    then
        print("SettingsMenu: ignored an unsupported saved-state version.")
        savedState = {}
    end

    editMode = type(savedState) ~= "table"
        or savedState.editMode ~= false

    if type(savedState) == "table"
        and type(savedState.savedBoards) == "table"
    then
        nextBoardId = normalizeNextBoardId(savedState.nextBoardId) or 1
        local reservedBoardIds = {}

        for _, savedBoard in ipairs(savedState.savedBoards) do
            if isSavedBoardCandidate(savedBoard)
                and isValidBoardId(savedBoard.id)
            then
                reservedBoardIds[savedBoard.id] = true
                advanceNextBoardIdPast(savedBoard.id)
            end
        end

        local usedBoardIds = {}

        for _, savedBoard in ipairs(savedState.savedBoards) do
            if isSavedBoardCandidate(savedBoard) then
                local boardId = savedBoard.id

                if not isValidBoardId(boardId) or usedBoardIds[boardId] then
                    boardId = allocateBoardId(reservedBoardIds)
                end

                usedBoardIds[boardId] = true
                savedBoards[#savedBoards + 1] = {
                    id = boardId,
                    name = trim(savedBoard.name),
                    boardState = savedBoard.boardState
                }
            end
        end
    end

    if #savedBoards == 0
        and type(savedState) == "table"
        and type(savedState.boardStateJson) == "string"
    then
        local succeeded, legacyBoardState = pcall(
            JSON.decode,
            savedState.boardStateJson
        )

        if succeeded and type(legacyBoardState) == "table" then
            savedBoards[1] = {
                id = allocateBoardId(),
                name = "Imported Saved Board",
                boardState = legacyBoardState
            }
        end
    end

    if type(savedState) == "table"
        and isValidBoardId(savedState.selectedBoardId)
    then
        selectedBoardIndex = findBoardById(savedState.selectedBoardId)
    end

    if selectedBoardIndex == nil
        and type(savedState) == "table"
        and type(savedState.selectedBoardName) == "string"
    then
        selectedBoardIndex = findBoardByName(
            savedState.selectedBoardName
        )
    end

    if selectedBoardIndex == nil and #savedBoards > 0 then
        selectedBoardIndex = 1
    end

    if context.setEditMode ~= nil then
        context.setEditMode(editMode)
    end

    close()
end

function SettingsMenu.getSaveState()
    local selectedBoard = selectedBoardIndex ~= nil
        and savedBoards[selectedBoardIndex] or nil

    return {
        schemaVersion = Config.settingsSchemaVersion,
        savedBoards = savedBoards,
        nextBoardId = nextBoardId,
        editMode = editMode,
        selectedBoardId = selectedBoard ~= nil
            and selectedBoard.id or nil,
        selectedBoardName = selectedBoard ~= nil
            and selectedBoard.name or nil
    }
end

function SettingsMenu.getSavedBoardSummaries()
    local summaries = {}

    for index, savedBoard in ipairs(savedBoards) do
        summaries[index] = {
            id = savedBoard.id,
            name = savedBoard.name
        }
    end

    return summaries
end

function SettingsMenu.loadSavedBoardById(
    boardId,
    playerColor,
    onCompleted
)
    local boardIndex = findBoardById(boardId)

    if boardIndex == nil then
        return false, "Select a saved board before loading."
    end

    local succeeded, message = loadSavedBoard(
        savedBoards[boardIndex],
        playerColor,
        onCompleted
    )

    if succeeded then
        selectedBoardIndex = boardIndex
        nameDraftsByPlayerColor = {}
        nameDraftsByPlayerColor[playerColor] =
            savedBoards[boardIndex].name
        UI.setAttribute(
            Config.ui.boardNameInputId,
            "text",
            savedBoards[boardIndex].name
        )
        refreshBoardList(playerColor)
    end

    return succeeded, message
end

function SettingsMenu.handleAction(playerColor, action)
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

    if action == "generalTab" then
        setPage(Config.ui.generalPageId)
        setStatus(
            "Enable Edit mode to add objects to the hex grid.",
            "#CBD5E1"
        )
        return
    end

    if action == "renewDeckSpawns" then
        if context.renewDeckSlotButton == nil
            or not context.renewDeckSlotButton(playerColor)
        then
            setStatus("Your deck spawn button could not be renewed.", "#FCA5A5")
            return
        end

        setStatus(
            "Your deck spawn button was renewed. You may spawn another deck.",
            "#86EFAC"
        )
        return
    end

    if not requireAdmin(playerColor) then
        return
    end

    if action == "saveTab" or action == "main" then
        setPage(Config.ui.savePageId)
        refreshBoardList(playerColor)
        setStatus(
            "Name the current board to save it, or select one to load.",
            "#CBD5E1"
        )
        return
    end

    if action == "json" then
        if jsonDraftsByPlayerColor[playerColor] == nil
            and context.getBoardStateJson ~= nil
        then
            jsonDraftsByPlayerColor[playerColor] =
                context.getBoardStateJson()
        end

        UI.setAttribute(
            Config.ui.jsonInputId,
            "text",
            jsonDraftsByPlayerColor[playerColor] or ""
        )
        setPage(Config.ui.jsonPageId)
        setStatus(
            "Export the current board or paste JSON to import it.",
            "#CBD5E1"
        )
        return
    end

    if action == "previous" then
        boardListPage = boardListPage - 1
        refreshBoardList(playerColor)
        return
    end

    if action == "next" then
        boardListPage = boardListPage + 1
        refreshBoardList(playerColor)
        return
    end

    local selectedRow = tonumber(string.match(action, "^select(%d+)$"))

    if selectedRow ~= nil then
        selectBoard(
            playerColor,
            (boardListPage - 1) * Config.boardListPageSize + selectedRow
        )
        return
    end

    if action == "save" and context.getBoardState ~= nil then
        local boardName = trim(nameDraftsByPlayerColor[playerColor] or "")

        if boardName == "" then
            setStatus("Enter a board name before saving.", "#FCA5A5")
            return
        end

        local existingIndex = findBoardByName(boardName)
        local savedBoard = {
            id = existingIndex ~= nil
                and savedBoards[existingIndex].id
                or allocateBoardId(),
            name = boardName,
            boardState = context.getBoardState()
        }

        if existingIndex ~= nil then
            savedBoards[existingIndex] = savedBoard
            selectedBoardIndex = existingIndex
        else
            savedBoards[#savedBoards + 1] = savedBoard
            selectedBoardIndex = #savedBoards
        end

        nameDraftsByPlayerColor[playerColor] = boardName
        UI.setAttribute(Config.ui.boardNameInputId, "text", boardName)
        boardListPage = math.ceil(
            selectedBoardIndex / Config.boardListPageSize
        )
        refreshBoardList(playerColor)
        if context.onSavedBoardsChanged ~= nil then
            context.onSavedBoardsChanged()
        end
        local persistedImmediately = context.persistState ~= nil
            and context.persistState() or false
        setStatus(
            (existingIndex ~= nil
                and "Saved board updated: " .. boardName
                or "Board saved: " .. boardName)
                .. (persistedImmediately
                    and ""
                    or " Save the TTS game to make it permanent."),
            persistedImmediately and "#86EFAC" or "#FDE68A"
        )
        return
    end

    if action == "load" and context.loadBoardState ~= nil then
        local savedBoard = selectedBoardIndex ~= nil
            and savedBoards[selectedBoardIndex] or nil
        local onCompleted, markAccepted = createExternalLoadTracker(
            savedBoard ~= nil and savedBoard.id or nil,
            playerColor
        )

        local succeeded, message = loadSavedBoard(
            savedBoard,
            playerColor,
            onCompleted
        )

        setStatus(message, succeeded and "#86EFAC" or "#FCA5A5")
        broadcastToColor(
            message,
            playerColor,
            succeeded and Config.colors.success or Config.colors.failure
        )

        if succeeded then
            markAccepted()
        end

        return
    end

    if action == "export" and context.getBoardStateJson ~= nil then
        local boardStateJson = context.getBoardStateJson()
        jsonDraftsByPlayerColor[playerColor] = boardStateJson
        UI.setAttribute(Config.ui.jsonInputId, "text", boardStateJson)
        setStatus("Current board exported to JSON.", "#86EFAC")
        return
    end

    if action ~= "import" or context.loadBoardStateJson == nil then
        return
    end

    local boardStateJson = jsonDraftsByPlayerColor[playerColor]

    if type(boardStateJson) ~= "string" or boardStateJson == "" then
        setStatus("Paste board-state JSON before importing.", "#FCA5A5")
        return
    end

    local onCompleted, markAccepted = createExternalLoadTracker(
        nil,
        playerColor
    )
    local succeeded, message = context.loadBoardStateJson(
        boardStateJson,
        playerColor,
        onCompleted
    )

    if not succeeded then
        setStatus(message, "#FCA5A5")
        broadcastToColor(message, playerColor, Config.colors.failure)
        return
    end

    local normalizedJson = context.getBoardStateJson()
    jsonDraftsByPlayerColor[playerColor] = normalizedJson
    UI.setAttribute(Config.ui.jsonInputId, "text", normalizedJson)
    setStatus(message, "#86EFAC")
    broadcastToColor(message, playerColor, Config.colors.success)
    markAccepted()
end

function SettingsMenu.onJsonEdited(playerColor, value)
    if activePlayerColor ~= playerColor or not isAdmin(playerColor) then
        return
    end

    jsonDraftsByPlayerColor[playerColor] = value
    setStatus("JSON edited. Choose IMPORT JSON to apply it.", "#FDE68A")
end

function SettingsMenu.onBoardNameEdited(playerColor, value)
    if activePlayerColor ~= playerColor or not isAdmin(playerColor) then
        return
    end

    nameDraftsByPlayerColor[playerColor] = value
end

function SettingsMenu.onEditModeChanged(playerColor, value)
    if activePlayerColor ~= playerColor or not requireAdmin(playerColor) then
        return
    end

    local enabled = value == true
        or value == "true"
        or value == "True"

    if editMode == enabled then
        return
    end

    editMode = enabled

    if context.setEditMode ~= nil then
        context.setEditMode(editMode)
    end

    local persistedImmediately = context.persistState ~= nil
        and context.persistState() or false
    setStatus(
        editMode
            and "Edit mode enabled. Click an empty hex to add an object."
            or "Edit mode disabled.",
        persistedImmediately and "#86EFAC" or "#FDE68A"
    )
end

return SettingsMenu

local Config = require("src/dungeon/DungeonMapConfig")
local DungeonMapState = require("src/dungeon/DungeonMapState")
local DungeonMapRules = require("src/dungeon/DungeonMapRules")
local DungeonMapView = require("src/dungeon/DungeonMapView")
local BoardLoadCoordinator = require("src/boards/BoardLoadCoordinator")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local UiAdapter = require("src/tts/UiAdapter")

local DungeonMapController = {}

local function makeContext(parameters)
    return {
        savedBoardCatalog = parameters.savedBoardCatalog,
        getSavedBoardSummaries = parameters.getSavedBoardSummaries,
        loadSavedBoardById = parameters.loadSavedBoardById,
        persistState = parameters.persistState
    }
end

function DungeonMapController.new(dependencies)
    dependencies = dependencies or {}

    local config = dependencies.config or Config
    local stateApi = dependencies.state or DungeonMapState
    local rules = dependencies.rules or DungeonMapRules
    local view = dependencies.view or DungeonMapView
    local coordinatorApi = dependencies.coordinatorApi
        or BoardLoadCoordinator
    local baseRuntime = dependencies.runtime or Runtime.default()
    local baseScheduler = dependencies.scheduler or Scheduler.default()
    local baseUiAdapter = dependencies.uiAdapter or UiAdapter.default()
    local injectedCoordinator = dependencies.boardLoadCoordinator

    local controller = {}
    local runtime = baseRuntime
    local scheduler = baseScheduler
    local uiAdapter = baseUiAdapter
    local cells, cellsByKey = stateApi.buildCells(config.radius)
    local assignmentsByCellKey = {}
    local currentCellKey = nil
    local activePlayerColor = nil
    local editMode = false
    local selectedCellKey = nil
    local boardListPage = 1
    local traversalLocked = false
    local boardLoadCoordinator = nil
    local context = makeContext({})

    local function createCoordinator()
        return coordinatorApi.new({
            schedule = function(callback, frameCount)
                return scheduler.frames(callback, frameCount)
            end
        })
    end

    local function isAdmin(playerColor)
        local player = runtime.getPlayer(playerColor)
        return player ~= nil and player.admin == true
    end

    local function requireAdmin(playerColor)
        if isAdmin(playerColor) then
            return true
        end

        runtime.broadcastToColor(
            "Only an admin can edit the dungeon map.",
            playerColor,
            config.chatColors.denied
        )
        return false
    end

    local function setStatus(message, color)
        uiAdapter.setAttribute(
            config.ui.statusId,
            "text",
            message or ""
        )
        uiAdapter.setAttribute(
            config.ui.statusId,
            "color",
            color or config.statusColors.normal
        )
    end

    local function applyUiPatch(patches)
        uiAdapter.apply(patches)
    end

    local function getSavedBoards()
        if context.savedBoardCatalog ~= nil then
            local summaries = context.savedBoardCatalog:getSummaries()

            if type(summaries) == "table" then
                return summaries
            end

            return {}
        end

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
        return rules.findBoardById(savedBoards, boardSaveId)
    end

    local function setMode(isEditing)
        editMode = isEditing
        applyUiPatch(view.buildModePatch(config, editMode))
    end

    local function refreshUi()
        local savedBoards = getSavedBoards()
        local patches, normalizedPage = view.buildPatch(config, {
            cells = cells,
            cellsByKey = cellsByKey,
            assignmentsByCellKey = assignmentsByCellKey,
            currentCellKey = currentCellKey,
            selectedCellKey = selectedCellKey,
            editMode = editMode,
            boardListPage = boardListPage,
            savedBoards = savedBoards
        })
        boardListPage = normalizedPage
        applyUiPatch(patches)

        return savedBoards
    end

    local function close()
        activePlayerColor = nil
        editMode = false
        selectedCellKey = nil
        boardListPage = 1
        uiAdapter.setAttribute(config.ui.rootId, "active", "false")
    end

    local function countAssignments()
        return rules.countAssignments(assignmentsByCellKey)
    end

    local function countValidAssignments(savedBoards)
        return rules.countValidAssignments(
            assignmentsByCellKey,
            savedBoards
        )
    end

    local function setBrowseStatus(savedBoards)
        if traversalLocked then
            setStatus(
                "A board setup is loading. Dungeon traversal is paused.",
                config.statusColors.warning
            )
        elseif countValidAssignments(savedBoards) > 0 then
            setStatus(
                "Click the current level or a glowing touching hex to load it.",
                config.statusColors.normal
            )
        elseif #savedBoards == 0 then
            setStatus(
                "No levels yet. Save a board in Settings, then edit the map.",
                config.statusColors.warning
            )
        elseif countAssignments() > 0 then
            setStatus(
                "Dungeon assignments reference missing saves. An admin can "
                    .. "repair them in EDIT MAP.",
                config.statusColors.warning
            )
        else
            setStatus(
                "No levels assigned yet. An admin can choose EDIT MAP.",
                config.statusColors.warning
            )
        end
    end

    local function open(playerColor)
        activePlayerColor = playerColor
        selectedCellKey = nil
        boardListPage = 1
        setMode(false)
        uiAdapter.setAttribute(
            config.ui.rootId,
            "visibility",
            playerColor
        )
        uiAdapter.setAttribute(config.ui.rootId, "active", "true")

        setBrowseStatus(refreshUi())
    end

    local function persistState()
        if context.persistState == nil then
            return false
        end

        return context.persistState()
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
                assignedBoardIndex / config.boardListPageSize
            )
        end

        refreshUi()
        setStatus(
            "Choose a saved board to assign to this hex.",
            config.statusColors.normal
        )
    end

    local function assignBoard(playerColor, row)
        if selectedCellKey == nil then
            setStatus(
                "Select a dungeon hex before choosing a board save.",
                config.statusColors.failure
            )
            return
        end

        local savedBoards = getSavedBoards()
        local boardIndex = (boardListPage - 1)
            * config.boardListPageSize + row
        local savedBoard = savedBoards[boardIndex]

        if savedBoard == nil then
            return
        end

        assignmentsByCellKey, currentCellKey = rules.assign(
            assignmentsByCellKey,
            currentCellKey,
            selectedCellKey,
            savedBoard.id
        )
        local persistedImmediately = persistState()
        refreshUi()
        setStatus(
            "Assigned " .. savedBoard.name .. " to the selected hex."
                .. (persistedImmediately
                    and ""
                    or " Save the TTS game to make it permanent."),
            persistedImmediately
                and config.statusColors.success
                or config.statusColors.warning
        )
    end

    local function clearSelectedCell()
        if selectedCellKey == nil then
            setStatus(
                "Select a dungeon hex before clearing it.",
                config.statusColors.failure
            )
            return
        end

        if assignmentsByCellKey[selectedCellKey] == nil then
            setStatus(
                "The selected hex is already unassigned.",
                config.statusColors.warning
            )
            return
        end

        assignmentsByCellKey, currentCellKey = rules.clear(
            assignmentsByCellKey,
            currentCellKey,
            selectedCellKey
        )

        local persistedImmediately = persistState()
        refreshUi()
        setStatus(
            "The selected dungeon hex was cleared."
                .. (persistedImmediately
                    and ""
                    or " Save the TTS game to make it permanent."),
            persistedImmediately
                and config.statusColors.success
                or config.statusColors.warning
        )
    end

    local function traverseToCell(playerColor, cell)
        local traversal = rules.validateTraversal({
            assignmentsByCellKey = assignmentsByCellKey,
            cellsByKey = cellsByKey,
            currentCellKey = currentCellKey,
            cell = cell,
            savedBoards = getSavedBoards(),
            traversalLocked = traversalLocked,
            loaderAvailable = context.loadSavedBoardById ~= nil
        })

        if traversal.reason == "unassigned" then
            setStatus(
                "That dungeon hex does not have a board save yet.",
                config.statusColors.failure
            )
            return
        end

        if traversal.reason == "locked" then
            setStatus(
                "A dungeon level is already loading.",
                config.statusColors.warning
            )
            return
        end

        if traversal.reason == "notAdjacent" then
            setStatus(
                "You can only traverse to the current level or a touching hex.",
                config.statusColors.warning
            )
            return
        end

        if traversal.reason == "missingSave" then
            setStatus(
                "That hex references a missing board save. Edit it to repair "
                    .. "the assignment.",
                config.statusColors.failure
            )
            return
        end

        if traversal.reason == "unavailable" then
            setStatus(
                "Dungeon traversal is not available.",
                config.statusColors.failure
            )
            return
        end

        local boardSaveId = traversal.boardSaveId
        local savedBoard = traversal.savedBoard
        traversalLocked = true
        local loadMessage = nil
        local loadGeneration = boardLoadCoordinator:begin({
            requestedId = boardSaveId,
            timeoutFrames = config.traversalTimeoutFrames,
            completionDelayFrames = config.traversalLockFrames,
            onFinished = function(result)
                traversalLocked = false

                if not result.succeeded then
                    currentCellKey = nil
                    runtime.broadcastToColor(
                        (loadMessage or "The dungeon level loaded.")
                            .. " Some objects did not finish loading, so the "
                            .. "dungeon position was not saved.",
                        playerColor,
                        config.chatColors.failure
                    )
                    return
                end

                currentCellKey = cell.key
                local persistedImmediately = persistState()
                local persistenceWarning = persistedImmediately
                    and ""
                    or " Save the TTS game to keep this position."

                runtime.broadcastToColor(
                    loadMessage .. persistenceWarning,
                    playerColor,
                    persistedImmediately
                        and config.chatColors.success
                        or config.chatColors.failure
                )
            end
        })

        local function onLoadCompleted(succeeded)
            boardLoadCoordinator:complete(
                loadGeneration,
                boardSaveId,
                succeeded
            )
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
            boardLoadCoordinator:cancel(loadGeneration)
            traversalLocked = false

            setStatus(message, config.statusColors.failure)
            runtime.broadcastToColor(
                message,
                playerColor,
                config.chatColors.failure
            )
            return
        end

        loadMessage = type(message) == "string"
            and message
            or "Loaded " .. savedBoard.name .. "."
        currentCellKey = nil
        close()
        boardLoadCoordinator:accept(loadGeneration, loadMessage)
    end

    local function loadSavedState(savedState)
        local loadedState = stateApi.load(
            savedState,
            cellsByKey,
            config.schemaVersion
        )
        assignmentsByCellKey = loadedState.assignmentsByCellKey
        currentCellKey = loadedState.currentCellKey

        if loadedState.unsupportedVersion then
            runtime.log(
                "DungeonMap: ignored an unsupported saved-state version."
            )
        end
    end

    function controller.initialize(parameters, savedState)
        parameters = parameters or {}
        context = makeContext(parameters)
        runtime = parameters.runtime or baseRuntime
        scheduler = parameters.scheduler or baseScheduler
        uiAdapter = parameters.uiAdapter or baseUiAdapter
        cells, cellsByKey = stateApi.buildCells(config.radius)
        activePlayerColor = nil
        editMode = false
        selectedCellKey = nil
        boardListPage = 1
        traversalLocked = false
        boardLoadCoordinator = parameters.boardLoadCoordinator
            or injectedCoordinator
            or createCoordinator()
        boardLoadCoordinator:reset()

        loadSavedState(savedState)
        setMode(false)
        close()
    end

    function controller.getSaveState()
        return stateApi.serialize(
            cells,
            cellsByKey,
            assignmentsByCellKey,
            currentCellKey,
            config.schemaVersion
        )
    end

    function controller.handleAction(playerColor, action)
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
                config.statusColors.normal
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

    function controller.onSavedBoardsChanged()
        if activePlayerColor ~= nil then
            local savedBoards = refreshUi()

            if not editMode then
                setBrowseStatus(savedBoards)
            end
        end
    end

    function controller.onExternalBoardLoadStarted(boardSaveId)
        local previousCellKey = currentCellKey
        local loadGeneration = boardLoadCoordinator:begin({
            requestedId = boardSaveId,
            timeoutFrames = config.traversalTimeoutFrames,
            completionDelayFrames = config.traversalLockFrames,
            onFinished = function(result)
                traversalLocked = false

                if result.succeeded
                    and result.requestedId == result.completedId
                    and previousCellKey ~= nil
                    and assignmentsByCellKey[previousCellKey]
                        == result.completedId
                then
                    currentCellKey = previousCellKey
                else
                    currentCellKey = nil
                end

                if result.succeeded then
                    persistState()
                end

                if activePlayerColor ~= nil then
                    setBrowseStatus(refreshUi())
                end
            end
        })
        currentCellKey = nil
        traversalLocked = true

        if activePlayerColor ~= nil then
            refreshUi()
            setStatus(
                "A board setup is loading. Dungeon traversal is paused.",
                config.statusColors.warning
            )
        end

        boardLoadCoordinator:accept(loadGeneration)

        return loadGeneration
    end

    function controller.onExternalBoardLoadCompleted(
        loadGeneration,
        boardSaveId,
        succeeded
    )
        return boardLoadCoordinator:complete(
            loadGeneration,
            boardSaveId,
            succeeded
        )
    end

    return controller
end

return DungeonMapController

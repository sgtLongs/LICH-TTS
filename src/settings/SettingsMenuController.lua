local Config = require("src/config/SettingsConfig")
local SavedBoardCatalog = require("src/boards/SavedBoardCatalog")
local BoardLoadCoordinator = require("src/boards/BoardLoadCoordinator")
local SettingsView = require("src/settings/SettingsView")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local UiAdapter = require("src/tts/UiAdapter")

local SettingsMenuController = {}

local function makeContext(parameters)
    return {
        getBoardState = parameters.getBoardState,
        getBoardStateJson = parameters.getBoardStateJson,
        loadBoardState = parameters.loadBoardState,
        loadBoardStateJson = parameters.loadBoardStateJson,
        persistState = parameters.persistState,
        onSavedBoardsChanged = parameters.onSavedBoardsChanged,
        onBoardLoadStarted = parameters.onBoardLoadStarted,
        onBoardLoadCompleted = parameters.onBoardLoadCompleted,
        setEditMode = parameters.setEditMode,
        addMockPlayer = parameters.addMockPlayer,
        disconnectMockPlayer = parameters.disconnectMockPlayer,
        removeMockPlayer = parameters.removeMockPlayer,
        renewDeckSlotButton = parameters.renewDeckSlotButton,
        restartGame = parameters.restartGame
    }
end

function SettingsMenuController.new(dependencies)
    dependencies = dependencies or {}

    local config = dependencies.config or Config
    local catalogApi = dependencies.catalogApi or SavedBoardCatalog
    local coordinatorApi = dependencies.coordinatorApi
        or BoardLoadCoordinator
    local view = dependencies.view or SettingsView
    local baseRuntime = dependencies.runtime or Runtime.default()
    local baseScheduler = dependencies.scheduler or Scheduler.default()
    local baseUiAdapter = dependencies.uiAdapter or UiAdapter.default()
    local injectedCatalog = dependencies.savedBoardCatalog
    local injectedCoordinator = dependencies.boardLoadCoordinator
    local jsonApi = dependencies.json

    local controller = {}
    local runtime = baseRuntime
    local scheduler = baseScheduler
    local uiAdapter = baseUiAdapter
    local savedBoardCatalog = nil
    local boardLoadCoordinator = nil
    local activePlayerColor = nil
    local jsonDraftsByPlayerColor = {}
    local nameDraftsByPlayerColor = {}
    local boardListPage = 1
    local editMode = false
    local context = makeContext({})

    local function decodeJson(value)
        local decoder = jsonApi or JSON
        return decoder.decode(value)
    end

    local function createCatalog()
        return catalogApi.new({
            schemaVersion = config.settingsSchemaVersion,
            legacySchemaVersion = config.legacySettingsSchemaVersion,
            decodeJson = decodeJson
        })
    end

    local function createCoordinator()
        return coordinatorApi.new({
            schedule = function(callback, frameCount)
                return scheduler.frames(callback, frameCount)
            end
        })
    end

    -- TTS normally calls onLoad before onSave, but the legacy facade could
    -- still serialize an empty state if save was requested first. Keep that
    -- lifecycle edge safe while allowing initialize to replace these ports.
    savedBoardCatalog = injectedCatalog or createCatalog()
    boardLoadCoordinator = injectedCoordinator or createCoordinator()

    local function isAdmin(playerColor)
        local player = runtime.getPlayer(playerColor)
        return player ~= nil and player.admin == true
    end

    local function setStatus(message, color)
        uiAdapter.setAttribute(
            config.ui.statusId,
            "text",
            message or ""
        )

        if color ~= nil then
            uiAdapter.setAttribute(config.ui.statusId, "color", color)
        end
    end

    local function applyUiPatch(patches)
        uiAdapter.apply(patches)
    end

    local function getEditModeStatus()
        if editMode then
            return "Edit mode: use number keys 1-9 to select an object, "
                .. "then click an empty hex."
        end

        return "Enable Edit mode to add objects to the hex grid."
    end

    local function close()
        activePlayerColor = nil
        uiAdapter.setAttribute(config.ui.rootId, "active", "false")
    end

    local function setPage(pageId)
        applyUiPatch(view.buildPagePatch(config, pageId))
    end

    local function requireAdmin(playerColor)
        if isAdmin(playerColor) then
            return true
        end

        runtime.broadcastToColor(
            "Only an admin can change board settings.",
            playerColor,
            config.colors.denied
        )
        return false
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
        local request = boardLoadCoordinator:createRequest({
            requestedId = boardSaveId,
            onStarted = context.onBoardLoadStarted,
            onCompleted = context.onBoardLoadCompleted,
            onReported = function(succeeded, completionAccepted)
                if not succeeded and completionAccepted then
                    local failureMessage =
                        "The board changed, but one or more objects did not "
                            .. "finish loading."

                    setStatus(failureMessage, "#FCA5A5")
                    runtime.broadcastToColor(
                        failureMessage,
                        playerColor,
                        config.colors.failure
                    )
                end
            end
        })

        local function onCompleted(succeeded)
            request:complete(succeeded)
        end

        local function markAccepted()
            request:accept()
        end

        return onCompleted, markAccepted
    end

    local function refreshBoardList(playerColor)
        local pageInfo = savedBoardCatalog:getPage(
            boardListPage,
            config.boardListPageSize
        )
        boardListPage = pageInfo.page
        pageInfo.selectedBoard = savedBoardCatalog:getSelected()
        applyUiPatch(view.buildBoardListPatch(config, pageInfo))

        if playerColor ~= nil
            and nameDraftsByPlayerColor[playerColor] == nil
        then
            nameDraftsByPlayerColor[playerColor] =
                pageInfo.selectedBoard ~= nil
                    and pageInfo.selectedBoard.name or ""
        end
    end

    local function selectBoard(playerColor, boardIndex)
        local savedBoard = savedBoardCatalog:selectByIndex(boardIndex)

        if savedBoard == nil then
            return
        end

        nameDraftsByPlayerColor[playerColor] = savedBoard.name
        uiAdapter.setAttribute(
            config.ui.boardNameInputId,
            "text",
            savedBoard.name
        )
        refreshBoardList(playerColor)
        setStatus(
            "Board selected. Choose LOAD SELECTED to restore it.",
            "#CBD5E1"
        )
    end

    local function open(playerColor)
        activePlayerColor = playerColor
        local playerIsAdmin = isAdmin(playerColor)
        setPage(config.ui.generalPageId)
        refreshBoardList(playerColor)
        uiAdapter.setAttribute(
            config.ui.rootId,
            "visibility",
            playerColor
        )
        uiAdapter.setAttribute(
            config.ui.boardNameInputId,
            "text",
            nameDraftsByPlayerColor[playerColor] or ""
        )
        uiAdapter.setAttribute(
            config.ui.editModeToggleId,
            "isOn",
            editMode and "true" or "false"
        )
        uiAdapter.setAttribute(
            config.ui.editModeToggleId,
            "interactable",
            playerIsAdmin and "true" or "false"
        )
        uiAdapter.setAttribute(
            config.ui.addMockPlayerButtonId,
            "interactable",
            playerIsAdmin and "true" or "false"
        )
        uiAdapter.setAttribute(
            config.ui.removeMockPlayerButtonId,
            "interactable",
            playerIsAdmin and "true" or "false"
        )
        uiAdapter.setAttribute(
            config.ui.disconnectMockPlayerButtonId,
            "interactable",
            playerIsAdmin and "true" or "false"
        )
        uiAdapter.setAttribute(
            config.ui.saveTabButtonId,
            "interactable",
            playerIsAdmin and "true" or "false"
        )
        uiAdapter.setAttribute(
            config.ui.restartGameButtonId,
            "interactable",
            playerIsAdmin and "true" or "false"
        )
        setStatus(getEditModeStatus(), "#CBD5E1")
        uiAdapter.setAttribute(config.ui.rootId, "active", "true")
    end

    function controller.initialize(parameters, savedState)
        parameters = parameters or {}
        context = makeContext(parameters)
        runtime = parameters.runtime or baseRuntime
        scheduler = parameters.scheduler or baseScheduler
        uiAdapter = parameters.uiAdapter or baseUiAdapter
        activePlayerColor = nil
        jsonDraftsByPlayerColor = {}
        nameDraftsByPlayerColor = {}
        boardListPage = 1
        editMode = false
        savedBoardCatalog = parameters.savedBoardCatalog
            or injectedCatalog
            or savedBoardCatalog
        boardLoadCoordinator = parameters.boardLoadCoordinator
            or injectedCoordinator
            or boardLoadCoordinator

        local catalogLoadResult = savedBoardCatalog:load(savedState)

        if catalogLoadResult.unsupportedVersion then
            runtime.log(
                "SettingsMenu: ignored an unsupported saved-state version."
            )
            savedState = {}
        end

        editMode = type(savedState) == "table"
            and savedState.editMode == true

        if context.setEditMode ~= nil then
            context.setEditMode(editMode)
        end

        close()
    end

    function controller.getSaveState()
        local savedState = savedBoardCatalog:serialize(
            config.settingsSchemaVersion
        )
        savedState.editMode = editMode
        return savedState
    end

    function controller.getSavedBoardSummaries()
        return savedBoardCatalog:getSummaries()
    end

    function controller.loadSavedBoardById(
        boardId,
        playerColor,
        onCompleted
    )
        local savedBoard, boardIndex = savedBoardCatalog:getById(boardId)

        if savedBoard == nil then
            return false, "Select a saved board before loading."
        end

        local succeeded, message = loadSavedBoard(
            savedBoard,
            playerColor,
            onCompleted
        )

        if succeeded then
            savedBoardCatalog:selectByIndex(boardIndex)
            nameDraftsByPlayerColor = {}
            nameDraftsByPlayerColor[playerColor] = savedBoard.name
            uiAdapter.setAttribute(
                config.ui.boardNameInputId,
                "text",
                savedBoard.name
            )
            refreshBoardList(playerColor)
        end

        return succeeded, message
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

        if action == "generalTab" then
            setPage(config.ui.generalPageId)
            setStatus(getEditModeStatus(), "#CBD5E1")
            return
        end

        if action == "renewDeckSpawns" then
            if context.renewDeckSlotButton == nil
                or not context.renewDeckSlotButton(playerColor)
            then
                setStatus(
                    "Your deck spawn button could not be renewed.",
                    "#FCA5A5"
                )
                return
            end

            setStatus(
                "Your deck spawn button was renewed. You may spawn another deck.",
                "#86EFAC"
            )
            return
        end

        if action == "restartGame" then
            if not requireAdmin(playerColor) then
                return
            end

            if context.restartGame == nil
                or not context.restartGame(playerColor)
            then
                setStatus(
                    "The game could not be restarted.",
                    "#FCA5A5"
                )
                return
            end

            setStatus(
                "Game restarted. The current map was preserved and all surfaces were removed.",
                "#86EFAC"
            )
            return
        end

        if not requireAdmin(playerColor) then
            return
        end

        if action == "addMockPlayer" then
            local succeeded, mockColor, deckName, failureMessage =
                false, nil, nil, nil

            if context.addMockPlayer ~= nil then
                succeeded, mockColor, deckName, failureMessage =
                    context.addMockPlayer()
            end

            if not succeeded then
                setStatus(
                    failureMessage
                        or "Mock player deck generation is unavailable.",
                    "#FCA5A5"
                )
                return
            end

            local persistedImmediately = context.persistState ~= nil
                and context.persistState() or false
            setStatus(
                "Added Mock " .. mockColor
                    .. (deckName ~= nil
                        and " with " .. deckName or " with a random deck")
                    .. " to the turn rotation."
                    .. (persistedImmediately
                        and ""
                        or " Save the TTS game to make it permanent."),
                persistedImmediately and "#86EFAC" or "#FDE68A"
            )
            return
        end

        if action == "removeMockPlayer" then
            local succeeded, mockColor = false, nil

            if context.removeMockPlayer ~= nil then
                succeeded, mockColor = context.removeMockPlayer()
            end

            if not succeeded then
                setStatus(
                    "There are no mock players to remove.",
                    "#FCA5A5"
                )
                return
            end

            local persistedImmediately = context.persistState ~= nil
                and context.persistState() or false
            setStatus(
                "Removed Mock " .. mockColor .. " from the turn rotation."
                    .. (persistedImmediately
                        and ""
                        or " Save the TTS game to make it permanent."),
                persistedImmediately and "#86EFAC" or "#FDE68A"
            )
            return
        end

        if action == "disconnectMockPlayer" then
            local succeeded, mockColor = false, nil

            if context.disconnectMockPlayer ~= nil then
                succeeded, mockColor = context.disconnectMockPlayer()
            end

            if not succeeded then
                setStatus(
                    "There are no connected mock players to disconnect.",
                    "#FCA5A5"
                )
                return
            end

            local persistedImmediately = context.persistState ~= nil
                and context.persistState() or false
            setStatus(
                "Disconnected Mock " .. mockColor
                    .. " without removing it from the turn rotation."
                    .. (persistedImmediately
                        and ""
                        or " Save the TTS game to make it permanent."),
                persistedImmediately and "#86EFAC" or "#FDE68A"
            )
            return
        end

        if action == "saveTab" or action == "main" then
            setPage(config.ui.savePageId)
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

            uiAdapter.setAttribute(
                config.ui.jsonInputId,
                "text",
                jsonDraftsByPlayerColor[playerColor] or ""
            )
            setPage(config.ui.jsonPageId)
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
                (boardListPage - 1)
                    * config.boardListPageSize + selectedRow
            )
            return
        end

        if action == "save" and context.getBoardState ~= nil then
            local boardName = catalogApi.trimName(
                nameDraftsByPlayerColor[playerColor] or ""
            )

            if boardName == "" then
                setStatus("Enter a board name before saving.", "#FCA5A5")
                return
            end

            local _, savedBoardIndex, updatedExisting =
                savedBoardCatalog:upsert(
                    boardName,
                    context.getBoardState()
                )

            nameDraftsByPlayerColor[playerColor] = boardName
            uiAdapter.setAttribute(
                config.ui.boardNameInputId,
                "text",
                boardName
            )
            boardListPage = math.ceil(
                savedBoardIndex / config.boardListPageSize
            )
            refreshBoardList(playerColor)
            if context.onSavedBoardsChanged ~= nil then
                context.onSavedBoardsChanged()
            end
            local persistedImmediately = context.persistState ~= nil
                and context.persistState() or false
            setStatus(
                (updatedExisting
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
            local savedBoard = savedBoardCatalog:getSelected()
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
            runtime.broadcastToColor(
                message,
                playerColor,
                succeeded
                    and config.colors.success
                    or config.colors.failure
            )

            if succeeded then
                markAccepted()
            end

            return
        end

        if action == "export" and context.getBoardStateJson ~= nil then
            local boardStateJson = context.getBoardStateJson()
            jsonDraftsByPlayerColor[playerColor] = boardStateJson
            uiAdapter.setAttribute(
                config.ui.jsonInputId,
                "text",
                boardStateJson
            )
            setStatus("Current board exported to JSON.", "#86EFAC")
            return
        end

        if action ~= "import" or context.loadBoardStateJson == nil then
            return
        end

        local boardStateJson = jsonDraftsByPlayerColor[playerColor]

        if type(boardStateJson) ~= "string" or boardStateJson == "" then
            setStatus(
                "Paste board-state JSON before importing.",
                "#FCA5A5"
            )
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
            runtime.broadcastToColor(
                message,
                playerColor,
                config.colors.failure
            )
            return
        end

        local normalizedJson = context.getBoardStateJson()
        jsonDraftsByPlayerColor[playerColor] = normalizedJson
        uiAdapter.setAttribute(
            config.ui.jsonInputId,
            "text",
            normalizedJson
        )
        setStatus(message, "#86EFAC")
        runtime.broadcastToColor(
            message,
            playerColor,
            config.colors.success
        )
        markAccepted()
    end

    function controller.onJsonEdited(playerColor, value)
        if activePlayerColor ~= playerColor or not isAdmin(playerColor) then
            return
        end

        jsonDraftsByPlayerColor[playerColor] = value
        setStatus(
            "JSON edited. Choose IMPORT JSON to apply it.",
            "#FDE68A"
        )
    end

    function controller.onBoardNameEdited(playerColor, value)
        if activePlayerColor ~= playerColor or not isAdmin(playerColor) then
            return
        end

        nameDraftsByPlayerColor[playerColor] = value
    end

    function controller.onEditModeChanged(playerColor, value)
        if activePlayerColor ~= playerColor
            or not requireAdmin(playerColor)
        then
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
            context.setEditMode(editMode, playerColor)
        end

        local persistedImmediately = context.persistState ~= nil
            and context.persistState() or false
        setStatus(
            editMode and getEditModeStatus() or "Edit mode disabled.",
            persistedImmediately and "#86EFAC" or "#FDE68A"
        )
    end

    return controller
end

return SettingsMenuController

local Test = require("tests/support/Test")
local SettingsMenu = require("src/SettingsMenu")
local SettingsConfig = require("src/config/SettingsConfig")

local attributes = {}
local messages = {}
local editModeChanges = {}
local editModePlayerColors = {}
local persistCalls = 0
local persistSucceeded = true
local renewedPlayerColor = nil
local renewSucceeded = true
local restartedPlayerColor = nil
local restartSucceeded = true
local addedMockPlayerCalls = 0
local addMockPlayerSucceeded = true
local removedMockPlayerCalls = 0
local removeMockPlayerSucceeded = true
local savedBoardsChangedCalls = 0
local currentBoardState = nil
local currentBoardJson = nil
local normalizedBoardJson = nil
local boardLoadCalls = {}
local jsonLoadCalls = {}
local pendingBoardCompletion = nil
local pendingJsonCompletion = nil
local loadBoardSucceeded = true
local loadJsonSucceeded = true
local loadStartedCalls = {}
local loadCompletedCalls = {}
local nextLoadGeneration = 1

local function board(id, name, marker)
    return {
        id = id,
        name = name,
        boardState = {marker = marker or name}
    }
end

local function initialize(savedState, options)
    options = options or {}
    attributes = {}
    messages = {}
    editModeChanges = {}
    editModePlayerColors = {}
    persistCalls = 0
    persistSucceeded = options.persistSucceeded ~= false
    renewedPlayerColor = nil
    renewSucceeded = options.renewSucceeded ~= false
    restartedPlayerColor = nil
    restartSucceeded = options.restartSucceeded ~= false
    addedMockPlayerCalls = 0
    addMockPlayerSucceeded = options.addMockPlayerSucceeded ~= false
    removedMockPlayerCalls = 0
    removeMockPlayerSucceeded = options.removeMockPlayerSucceeded ~= false
    savedBoardsChangedCalls = 0
    currentBoardState = options.currentBoardState or {marker = "current"}
    currentBoardJson = options.currentBoardJson or "current-json"
    normalizedBoardJson = options.normalizedBoardJson or "normalized-json"
    boardLoadCalls = {}
    jsonLoadCalls = {}
    pendingBoardCompletion = nil
    pendingJsonCompletion = nil
    loadBoardSucceeded = options.loadBoardSucceeded ~= false
    loadJsonSucceeded = options.loadJsonSucceeded ~= false
    loadStartedCalls = {}
    loadCompletedCalls = {}
    nextLoadGeneration = 1

    Player = {
        Red = {admin = true},
        Teal = {admin = true},
        Blue = {admin = false}
    }
    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    broadcastToColor = function(message, playerColor, color)
        messages[#messages + 1] = {
            message = message,
            playerColor = playerColor,
            color = color
        }
    end

    SettingsMenu.initialize({
        getBoardState = function()
            return currentBoardState
        end,
        getBoardStateJson = function()
            return currentBoardJson
        end,
        loadBoardState = function(state, playerColor, onCompleted)
            boardLoadCalls[#boardLoadCalls + 1] = {
                state = state,
                playerColor = playerColor
            }
            pendingBoardCompletion = onCompleted

            if options.syncBoardCompletion ~= nil then
                onCompleted(options.syncBoardCompletion)
            end

            return loadBoardSucceeded,
                loadBoardSucceeded and "Board setup loaded." or "Load failed."
        end,
        loadBoardStateJson = function(value, playerColor, onCompleted)
            jsonLoadCalls[#jsonLoadCalls + 1] = {
                value = value,
                playerColor = playerColor
            }
            pendingJsonCompletion = onCompleted

            if options.syncJsonCompletion ~= nil then
                onCompleted(options.syncJsonCompletion)
            end

            return loadJsonSucceeded,
                loadJsonSucceeded and "Imported board JSON." or "Import failed."
        end,
        onSavedBoardsChanged = function()
            savedBoardsChangedCalls = savedBoardsChangedCalls + 1
        end,
        onBoardLoadStarted = function(boardSaveId)
            local generation = nextLoadGeneration
            nextLoadGeneration = nextLoadGeneration + 1
            loadStartedCalls[#loadStartedCalls + 1] = {
                boardSaveId = boardSaveId,
                generation = generation
            }
            return generation
        end,
        onBoardLoadCompleted = function(
            generation,
            boardSaveId,
            succeeded
        )
            loadCompletedCalls[#loadCompletedCalls + 1] = {
                generation = generation,
                boardSaveId = boardSaveId,
                succeeded = succeeded
            }
            return options.completionAccepted ~= false
        end,
        setEditMode = function(enabled, playerColor)
            editModeChanges[#editModeChanges + 1] = enabled
            editModePlayerColors[#editModePlayerColors + 1] = playerColor
        end,
        persistState = function()
            persistCalls = persistCalls + 1
            return persistSucceeded
        end,
        renewDeckSlotButton = function(playerColor)
            renewedPlayerColor = playerColor
            return renewSucceeded
        end,
        restartGame = function(playerColor)
            restartedPlayerColor = playerColor
            return restartSucceeded
        end,
        addMockPlayer = function()
            addedMockPlayerCalls = addedMockPlayerCalls + 1
            return addMockPlayerSucceeded,
                addMockPlayerSucceeded and "White" or nil,
                addMockPlayerSucceeded and "Arysa Andrews" or nil,
                addMockPlayerSucceeded and nil
                    or "A random deck could not be generated."
        end,
        removeMockPlayer = function()
            removedMockPlayerCalls = removedMockPlayerCalls + 1
            return removeMockPlayerSucceeded,
                removeMockPlayerSucceeded and "White" or nil
        end
    }, savedState)
end

local function openSavePage(playerColor)
    SettingsMenu.handleAction(playerColor, "toggle")
    SettingsMenu.handleAction(playerColor, "saveTab")
end

Test.case("settings opens on the general tab", function()
    initialize(nil)
    SettingsMenu.handleAction("Red", "toggle")

    Test.equal("true", attributes["settingsGeneralPage.active"])
    Test.equal("false", attributes["settingsSavePage.active"])
    Test.equal("false", attributes["settingsEditMode.isOn"])
    Test.equal("Red", attributes["settingsMenuRoot.visibility"])
end)

Test.case("players can renew only their own deck spawn button", function()
    initialize(nil)
    SettingsMenu.handleAction("Blue", "toggle")
    SettingsMenu.handleAction("Blue", "renewDeckSpawns")

    Test.equal("Blue", renewedPlayerColor)
    Test.equal(
        "Your deck spawn button was renewed. You may spawn another deck.",
        attributes["settingsMenuStatus.text"]
    )
    Test.equal("false", attributes["settingsEditMode.interactable"])
    Test.equal("false", attributes["settingsSaveTab.interactable"])
    Test.equal("false", attributes["settingsRestartGame.interactable"])
    Test.equal("false", attributes["settingsAddMockPlayer.interactable"])
    Test.equal("false", attributes["settingsRemoveMockPlayer.interactable"])
end)

Test.case("only admins can add mock players from settings", function()
    initialize(nil)
    SettingsMenu.handleAction("Blue", "toggle")
    SettingsMenu.handleAction("Blue", "addMockPlayer")

    Test.equal(0, addedMockPlayerCalls)
    Test.contains(messages[#messages].message, "Only an admin")

    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.handleAction("Red", "addMockPlayer")

    Test.equal(1, addedMockPlayerCalls)
    Test.equal(1, persistCalls)
    Test.equal("true", attributes["settingsAddMockPlayer.interactable"])
    Test.equal("true", attributes["settingsRemoveMockPlayer.interactable"])
    Test.equal(
        "Added Mock White with Arysa Andrews to the turn rotation.",
        attributes["settingsMenuStatus.text"]
    )
end)

Test.case("only admins can remove the most recent mock player", function()
    initialize(nil)
    SettingsMenu.handleAction("Blue", "toggle")
    SettingsMenu.handleAction("Blue", "removeMockPlayer")

    Test.equal(0, removedMockPlayerCalls)
    Test.contains(messages[#messages].message, "Only an admin")

    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.handleAction("Red", "removeMockPlayer")

    Test.equal(1, removedMockPlayerCalls)
    Test.equal(1, persistCalls)
    Test.equal(
        "Removed Mock White from the turn rotation.",
        attributes["settingsMenuStatus.text"]
    )
end)

Test.case("settings reports when there is no mock player to remove", function()
    initialize(nil, {removeMockPlayerSucceeded = false})
    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.handleAction("Red", "removeMockPlayer")

    Test.equal(1, removedMockPlayerCalls)
    Test.equal(0, persistCalls)
    Test.equal(
        "There are no mock players to remove.",
        attributes["settingsMenuStatus.text"]
    )
end)

Test.case("settings reports when no mock player color is available", function()
    initialize(nil, {addMockPlayerSucceeded = false})
    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.handleAction("Red", "addMockPlayer")

    Test.equal(1, addedMockPlayerCalls)
    Test.equal(0, persistCalls)
    Test.contains(
        attributes["settingsMenuStatus.text"],
        "random deck could not be generated"
    )
end)

Test.case("only admins can restart the game from settings", function()
    initialize(nil)
    SettingsMenu.handleAction("Blue", "toggle")
    SettingsMenu.handleAction("Blue", "restartGame")

    Test.nilValue(restartedPlayerColor)
    Test.contains(messages[#messages].message, "Only an admin")

    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.handleAction("Red", "restartGame")

    Test.equal("Red", restartedPlayerColor)
    Test.equal(
        "Game restarted. The current map was preserved and all surfaces were removed.",
        attributes["settingsMenuStatus.text"]
    )
    Test.equal("true", attributes["settingsRestartGame.interactable"])
end)

Test.case("settings reports restart failures", function()
    initialize(nil, {restartSucceeded = false})
    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.handleAction("Red", "restartGame")

    Test.equal("Red", restartedPlayerColor)
    Test.equal(
        "The game could not be restarted.",
        attributes["settingsMenuStatus.text"]
    )
end)

Test.case("edit mode defaults off and is forwarded to the hex grid", function()
    initialize(nil)
    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.onEditModeChanged("Red", "True")

    Test.truthy(SettingsMenu.getSaveState().editMode)
    Test.equal(true, editModeChanges[#editModeChanges])
    Test.equal("Red", editModePlayerColors[#editModePlayerColors])
    Test.equal(1, persistCalls)
end)

Test.case("saved edit mode is restored during initialization", function()
    initialize({
        schemaVersion = 2,
        editMode = true
    })

    Test.equal(true, editModeChanges[1])
    Test.truthy(SettingsMenu.getSaveState().editMode)
end)

Test.case("settings normalizes saved board IDs and filters bad saves", function()
    initialize({
        schemaVersion = 2,
        nextBoardId = 2,
        selectedBoardId = "board-5",
        savedBoards = {
            board("board-4", "  Alpha  "),
            board("board-4", "Beta"),
            board(nil, "Gamma"),
            {id = "bad", name = "   ", boardState = {}},
            {id = "also-bad", name = "No State"}
        }
    })

    local state = SettingsMenu.getSaveState()
    local summaries = SettingsMenu.getSavedBoardSummaries()

    Test.equal(3, #state.savedBoards)
    Test.equal("board-4", summaries[1].id)
    Test.equal("Alpha", summaries[1].name)
    Test.equal("board-5", summaries[2].id)
    Test.equal("board-6", summaries[3].id)
    Test.equal(7, state.nextBoardId)
    Test.equal("board-5", state.selectedBoardId)
end)

Test.case("settings migrates legacy JSON and rejects unknown versions", function()
    local previousJson = JSON
    JSON = {
        decode = function(value)
            Test.equal("legacy-json", value)
            return {legacy = true}
        end
    }

    initialize({
        schemaVersion = 1,
        boardStateJson = "legacy-json"
    })
    JSON = previousJson

    local migrated = SettingsMenu.getSaveState()
    Test.equal(1, #migrated.savedBoards)
    Test.equal("Imported Saved Board", migrated.savedBoards[1].name)
    Test.truthy(migrated.savedBoards[1].boardState.legacy)
    Test.equal("board-1", migrated.selectedBoardId)

    initialize({
        schemaVersion = 99,
        editMode = true,
        savedBoards = {board("board-1", "Ignored")}
    })

    local rejected = SettingsMenu.getSaveState()
    Test.equal(0, #rejected.savedBoards)
    Test.falsy(rejected.editMode)
end)

Test.case("settings saves new boards and updates names case-insensitively", function()
    initialize(nil, {persistSucceeded = false})
    openSavePage("Red")
    SettingsMenu.onBoardNameEdited("Red", "  Alpha  ")
    SettingsMenu.handleAction("Red", "save")

    local firstSave = SettingsMenu.getSaveState()
    Test.equal(1, #firstSave.savedBoards)
    Test.equal("board-1", firstSave.savedBoards[1].id)
    Test.equal("Alpha", firstSave.savedBoards[1].name)
    Test.equal("current", firstSave.savedBoards[1].boardState.marker)
    Test.equal(1, savedBoardsChangedCalls)
    Test.equal(1, persistCalls)
    Test.contains(attributes["settingsMenuStatus.text"], "Save the TTS game")

    persistSucceeded = true
    currentBoardState = {marker = "updated"}
    SettingsMenu.onBoardNameEdited("Red", "alpha")
    SettingsMenu.handleAction("Red", "save")

    local updated = SettingsMenu.getSaveState()
    Test.equal(1, #updated.savedBoards)
    Test.equal("board-1", updated.savedBoards[1].id)
    Test.equal("alpha", updated.savedBoards[1].name)
    Test.equal("updated", updated.savedBoards[1].boardState.marker)
    Test.equal(2, savedBoardsChangedCalls)
    Test.equal("Saved board updated: alpha", attributes["settingsMenuStatus.text"])
end)

Test.case("settings gates board actions but permits personal renewal", function()
    initialize(nil, {renewSucceeded = false})
    SettingsMenu.handleAction("Blue", "toggle")
    SettingsMenu.handleAction("Blue", "saveTab")
    SettingsMenu.onBoardNameEdited("Blue", "Forbidden")
    SettingsMenu.handleAction("Blue", "save")

    Test.equal(0, #SettingsMenu.getSaveState().savedBoards)
    Test.equal(2, #messages)
    Test.contains(messages[1].message, "Only an admin")

    SettingsMenu.handleAction("Blue", "renewDeckSpawns")
    Test.equal("Blue", renewedPlayerColor)
    Test.contains(attributes["settingsMenuStatus.text"], "could not be renewed")

    openSavePage("Red")
    SettingsMenu.handleAction("Red", "save")
    Test.contains(attributes["settingsMenuStatus.text"], "Enter a board name")
end)

Test.case("settings paginates and selects saved boards", function()
    local savedBoards = {}

    for index = 1, 7 do
        savedBoards[index] = board(
            "saved-" .. index,
            "Board " .. index
        )
    end

    initialize({
        schemaVersion = 2,
        savedBoards = savedBoards
    })
    openSavePage("Red")
    SettingsMenu.handleAction("Red", "next")

    Test.equal("Page 2 / 2", attributes["settingsBoardPageLabel.text"])
    Test.equal("Board 6", attributes["settingsSavedBoard1.text"])
    Test.equal("Board 7", attributes["settingsSavedBoard2.text"])
    Test.equal("false", attributes["settingsSavedBoard3.active"])
    Test.equal("false", attributes["settingsNextPage.interactable"])

    SettingsMenu.handleAction("Red", "select2")
    Test.equal("saved-7", SettingsMenu.getSaveState().selectedBoardId)
    Test.equal("Board 7", attributes["settingsBoardName.text"])

    SettingsMenu.handleAction("Red", "previous")
    SettingsMenu.handleAction("Red", "previous")
    Test.equal("Page 1 / 2", attributes["settingsBoardPageLabel.text"])
end)

Test.case("settings reports synchronous board-load completion", function()
    initialize({
        schemaVersion = 2,
        savedBoards = {board("board-8", "Crypt")}
    }, {
        syncBoardCompletion = true
    })
    openSavePage("Red")
    SettingsMenu.handleAction("Red", "load")

    Test.equal(1, #boardLoadCalls)
    Test.equal("Crypt", boardLoadCalls[1].state.marker)
    Test.equal("Red", boardLoadCalls[1].playerColor)
    Test.equal("board-8", loadStartedCalls[1].boardSaveId)
    Test.equal(1, loadCompletedCalls[1].generation)
    Test.equal("board-8", loadCompletedCalls[1].boardSaveId)
    Test.truthy(loadCompletedCalls[1].succeeded)
    Test.contains(attributes["settingsMenuStatus.text"], "Loaded Crypt")

    local missing, missingMessage = SettingsMenu.loadSavedBoardById(
        "missing",
        "Red"
    )
    Test.falsy(missing)
    Test.contains(missingMessage, "Select a saved board")
end)

Test.case("settings reports asynchronous board-load object failures once", function()
    initialize({
        schemaVersion = 2,
        savedBoards = {board("board-2", "Ruins")}
    })
    openSavePage("Red")
    SettingsMenu.handleAction("Red", "load")

    Test.equal(1, #loadStartedCalls)
    Test.equal(0, #loadCompletedCalls)
    pendingBoardCompletion(false)
    pendingBoardCompletion(true)

    Test.equal(1, #loadCompletedCalls)
    Test.falsy(loadCompletedCalls[1].succeeded)
    Test.contains(
        attributes["settingsMenuStatus.text"],
        "one or more objects did not finish loading"
    )
    Test.equal(2, #messages)
end)

Test.case("settings exports and imports normalized board JSON", function()
    initialize(nil, {
        currentBoardJson = "pretty-current",
        normalizedBoardJson = "pretty-normalized"
    })
    openSavePage("Red")
    SettingsMenu.handleAction("Red", "json")
    SettingsMenu.handleAction("Red", "export")
    Test.equal("pretty-current", attributes["settingsBoardStateJson.text"])

    SettingsMenu.onJsonEdited("Red", "raw-import")
    currentBoardJson = normalizedBoardJson
    SettingsMenu.handleAction("Red", "import")

    Test.equal(1, #jsonLoadCalls)
    Test.equal("raw-import", jsonLoadCalls[1].value)
    Test.equal("Red", jsonLoadCalls[1].playerColor)
    Test.equal("pretty-normalized", attributes["settingsBoardStateJson.text"])
    Test.nilValue(loadStartedCalls[1].boardSaveId)

    pendingJsonCompletion(true)
    Test.equal(1, #loadCompletedCalls)
    Test.truthy(loadCompletedCalls[1].succeeded)
end)

Test.case("settings rejects empty and failed JSON imports", function()
    initialize(nil)
    openSavePage("Red")
    SettingsMenu.handleAction("Red", "json")
    SettingsMenu.onJsonEdited("Red", "")
    SettingsMenu.handleAction("Red", "import")
    Test.contains(attributes["settingsMenuStatus.text"], "Paste board-state JSON")
    Test.equal(0, #jsonLoadCalls)

    loadJsonSucceeded = false
    SettingsMenu.onJsonEdited("Red", "bad-json")
    SettingsMenu.handleAction("Red", "import")
    Test.equal(1, #jsonLoadCalls)
    Test.equal("Import failed.", attributes["settingsMenuStatus.text"])
    Test.equal(1, #messages)
end)

local function makeSettingsControllerHarness(runtimeEvents, uiEvents)
    runtimeEvents = runtimeEvents or {}
    uiEvents = uiEvents or {}
    local runtime = {
        getPlayer = function(playerColor)
            runtimeEvents[#runtimeEvents + 1] = "player:" .. playerColor
            return {admin = playerColor ~= "Blue"}
        end,
        broadcastToColor = function(message, playerColor)
            runtimeEvents[#runtimeEvents + 1] =
                "broadcast:" .. playerColor .. ":" .. message
        end,
        log = function(message)
            runtimeEvents[#runtimeEvents + 1] = "log:" .. message
        end
    }
    local uiAdapter = {
        setAttribute = function(id, attribute, value)
            uiEvents[#uiEvents + 1] =
                "set:" .. id .. "." .. attribute .. "=" .. value
            return true
        end,
        apply = function(patches)
            uiEvents[#uiEvents + 1] = "apply:" .. #(patches or {})
            return #(patches or {})
        end
    }
    local scheduler = {
        frames = function(callback)
            callback()
        end
    }

    return SettingsMenu.new({
        runtime = runtime,
        scheduler = scheduler,
        uiAdapter = uiAdapter
    })
end

local function initializeConstructedSettings(controller, savedState, marker)
    controller.initialize({
        getBoardState = function()
            return {marker = marker}
        end,
        persistState = function()
            return true
        end,
        setEditMode = function()
        end
    }, savedState)
end

Test.case("constructed settings can save before initialization", function()
    local controller = makeSettingsControllerHarness()
    local savedState = controller.getSaveState()

    Test.equal(SettingsConfig.settingsSchemaVersion, savedState.schemaVersion)
    Test.equal(0, #savedState.savedBoards)
    Test.falsy(savedState.editMode)
end)

Test.case("constructed settings controllers isolate state and drafts", function()
    local first = makeSettingsControllerHarness()
    local second = makeSettingsControllerHarness()
    initializeConstructedSettings(first, nil, "first")
    initializeConstructedSettings(second, nil, "second")

    first.handleAction("Red", "toggle")
    first.handleAction("Red", "saveTab")
    first.onBoardNameEdited("Red", "First Board")
    first.handleAction("Red", "save")
    first.onEditModeChanged("Red", true)

    Test.equal(1, #first.getSaveState().savedBoards)
    Test.equal("first", first.getSaveState().savedBoards[1].boardState.marker)
    Test.truthy(first.getSaveState().editMode)
    Test.equal(0, #second.getSaveState().savedBoards)
    Test.falsy(second.getSaveState().editMode)
end)

Test.case("constructed settings routes TTS effects through adapters", function()
    local runtimeEvents = {}
    local uiEvents = {}
    local controller = makeSettingsControllerHarness(
        runtimeEvents,
        uiEvents
    )

    Test.withGlobals({
        Player = Test.NIL,
        UI = Test.NIL,
        broadcastToColor = Test.NIL,
        Wait = Test.NIL
    }, function()
        initializeConstructedSettings(controller, nil, "trace")
        controller.handleAction("Blue", "toggle")
        controller.handleAction("Blue", "saveTab")
    end)

    Test.equal("player:Blue", runtimeEvents[1])
    Test.equal("player:Blue", runtimeEvents[2])
    Test.contains(runtimeEvents[3], "broadcast:Blue:Only an admin")
    Test.equal("set:settingsMenuRoot.active=false", uiEvents[1])
    Test.contains(uiEvents[2], "apply:")
end)

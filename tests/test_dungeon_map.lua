local Test = require("tests/support/Test")
local Config = require("src/dungeon/DungeonMapConfig")
local DungeonMapState = require("src/dungeon/DungeonMapState")
local DungeonMap = require("src/dungeon/DungeonMap")

local cells, cellsByKey = DungeonMapState.buildCells(Config.radius)
local attributes = {}
local messages = {}
local scheduledFrames = {}
local savedBoards = {}
local persistCalls = 0
local persistSucceeded = true
local loadCalls = {}
local pendingLoadCompletion = nil
local loadMode = "async"
local loadMessage = "Loaded dungeon level."

local function board(id, name)
    return {id = id, name = name}
end

local function tileIndex(q, r)
    return cellsByKey[DungeonMapState.cellKey(q, r)].index
end

local function tileAction(q, r)
    return "tile" .. tileIndex(q, r)
end

local function tileAttribute(q, r, attribute)
    return attributes[
        Config.ui.tileButtonPrefix .. tileIndex(q, r) .. "." .. attribute
    ]
end

local function makeSavedState(assignments, current)
    local tiles = {}

    for index, assignment in ipairs(assignments or {}) do
        tiles[index] = {
            q = assignment.q,
            r = assignment.r,
            boardSaveId = assignment.boardSaveId
        }
    end

    return {
        schemaVersion = Config.schemaVersion,
        tiles = tiles,
        currentTile = current ~= nil and {
            q = current.q,
            r = current.r
        } or nil
    }
end

local function findSavedTile(state, q, r)
    for _, tile in ipairs(state.tiles or {}) do
        if tile.q == q and tile.r == r then
            return tile
        end
    end

    return nil
end

local function runScheduled(frameCount)
    local ran = 0
    local index = 1

    while index <= #scheduledFrames do
        local scheduled = scheduledFrames[index]

        if scheduled.frameCount == frameCount then
            table.remove(scheduledFrames, index)
            scheduled.callback()
            ran = ran + 1
        else
            index = index + 1
        end
    end

    return ran
end

local function initialize(savedState, options)
    options = options or {}
    attributes = {}
    messages = {}
    scheduledFrames = {}
    savedBoards = options.savedBoards or {}
    persistCalls = 0
    persistSucceeded = options.persistSucceeded ~= false
    loadCalls = {}
    pendingLoadCompletion = nil
    loadMode = options.loadMode or "async"
    loadMessage = options.loadMessage or "Loaded dungeon level."

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
    Wait = {
        frames = function(callback, frameCount)
            scheduledFrames[#scheduledFrames + 1] = {
                callback = callback,
                frameCount = frameCount
            }
        end
    }

    DungeonMap.initialize({
        getSavedBoardSummaries = function()
            return savedBoards
        end,
        loadSavedBoardById = function(boardSaveId, playerColor, onCompleted)
            loadCalls[#loadCalls + 1] = {
                boardSaveId = boardSaveId,
                playerColor = playerColor
            }
            pendingLoadCompletion = onCompleted

            if loadMode == "throw" then
                error("loader exploded")
            end

            if loadMode == "sync-success" then
                onCompleted(true)
            elseif loadMode == "sync-failure" then
                onCompleted(false)
            end

            if loadMode == "reject" then
                return false, loadMessage
            end

            return true, loadMessage
        end,
        persistState = function()
            persistCalls = persistCalls + 1
            return persistSucceeded
        end
    }, savedState)
end

local function open(playerColor)
    DungeonMap.handleAction(playerColor, "toggle")
end

local function enterEditMode(playerColor)
    open(playerColor)
    DungeonMap.handleAction(playerColor, "edit")
end

local function dungeonCase(name, testFunction)
    Test.case(name, function()
        local previousPlayer = Player
        local previousUI = UI
        local previousBroadcastToColor = broadcastToColor
        local previousWait = Wait
        local succeeded, failure = pcall(testFunction)

        Player = previousPlayer
        UI = previousUI
        broadcastToColor = previousBroadcastToColor
        Wait = previousWait

        if not succeeded then
            error(failure)
        end
    end)
end

dungeonCase("dungeon map restores assignments and renders browse states", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"},
        {q = 1, r = 0, boardSaveId = "board-b"},
        {q = 3, r = 0, boardSaveId = "board-b"},
        {q = -1, r = 0, boardSaveId = "missing"}
    }, {q = 0, r = 0}), {
        savedBoards = {
            board("board-a", "Entrance"),
            board("board-b", "Hall")
        }
    })
    open("Red")

    Test.equal("true", attributes[Config.ui.rootId .. ".active"])
    Test.equal("Red", attributes[Config.ui.rootId .. ".visibility"])
    Test.equal(Config.tileColors.current, tileAttribute(0, 0, "colors"))
    Test.equal(Config.tileColors.assigned, tileAttribute(1, 0, "colors"))
    Test.equal(Config.tileColors.unreachable, tileAttribute(3, 0, "colors"))
    Test.equal(Config.tileColors.missing, tileAttribute(-1, 0, "colors"))
    Test.contains(tileAttribute(-1, 0, "tooltip"), "Missing save")
    Test.contains(
        attributes[Config.ui.currentLevelLabelId .. ".text"],
        "Entrance"
    )

    savedBoards = {}
    DungeonMap.onSavedBoardsChanged()
    Test.contains(attributes[Config.ui.statusId .. ".text"], "No levels yet")
end)

dungeonCase("only admins can enter dungeon edit mode", function()
    initialize(nil, {savedBoards = {board("board-a", "Entrance")}})
    open("Blue")
    DungeonMap.handleAction("Blue", "edit")

    Test.equal("false", attributes[Config.ui.editPageId .. ".active"])
    Test.equal(1, #messages)
    Test.contains(messages[1].message, "Only an admin")

    enterEditMode("Red")
    Test.equal("true", attributes[Config.ui.editPageId .. ".active"])
    Test.equal("EDIT DUNGEON", attributes[Config.ui.modeTitleId .. ".text"])
    Test.equal("true", tileAttribute(0, 0, "active"))

    DungeonMap.handleAction("Blue", tileAction(0, 0))
    Test.equal(1, #messages)
end)

dungeonCase("admins assign a board save to a selected dungeon hex", function()
    initialize(nil, {
        savedBoards = {board("board-a", "Entrance")}
    })
    enterEditMode("Red")
    DungeonMap.handleAction("Red", "board1")
    Test.contains(
        attributes[Config.ui.statusId .. ".text"],
        "Select a dungeon hex"
    )

    DungeonMap.handleAction("Red", tileAction(0, 0))
    DungeonMap.handleAction("Red", "board1")

    local state = DungeonMap.getSaveState()
    local assigned = findSavedTile(state, 0, 0)
    Test.equal("board-a", assigned.boardSaveId)
    Test.equal(1, persistCalls)
    Test.equal(Config.tileColors.selected, tileAttribute(0, 0, "colors"))
    Test.contains(attributes[Config.ui.statusId .. ".text"], "Assigned Entrance")
end)

dungeonCase("clearing a dungeon assignment also clears its current level", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"}
    }, {q = 0, r = 0}), {
        savedBoards = {board("board-a", "Entrance")}
    })
    enterEditMode("Red")
    DungeonMap.handleAction("Red", tileAction(0, 0))
    DungeonMap.handleAction("Red", "clear")

    local cleared = DungeonMap.getSaveState()
    Test.equal(0, #cleared.tiles)
    Test.nilValue(cleared.currentTile)
    Test.equal(1, persistCalls)
    Test.contains(attributes[Config.ui.statusId .. ".text"], "was cleared")

    DungeonMap.handleAction("Red", "clear")
    Test.equal(1, persistCalls)
    Test.contains(attributes[Config.ui.statusId .. ".text"], "already unassigned")
end)

dungeonCase("dungeon board assignment uses the selected pagination page", function()
    local boards = {}

    for index = 1, 7 do
        boards[index] = board("board-" .. index, "Level " .. index)
    end

    initialize(nil, {savedBoards = boards})
    enterEditMode("Red")
    DungeonMap.handleAction("Red", tileAction(0, 0))
    DungeonMap.handleAction("Red", "next")

    Test.equal("Page 2 / 2", attributes[Config.ui.boardPageLabelId .. ".text"])
    Test.equal("Level 6", attributes[Config.ui.boardButtonPrefix .. "1.text"])
    Test.equal("Level 7", attributes[Config.ui.boardButtonPrefix .. "2.text"])
    Test.equal("false", attributes[Config.ui.boardButtonPrefix .. "3.active"])

    DungeonMap.handleAction("Red", "board2")
    Test.equal(
        "board-7",
        findSavedTile(DungeonMap.getSaveState(), 0, 0).boardSaveId
    )
end)

dungeonCase("dungeon traversal rejects unassigned, distant, and missing levels", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"},
        {q = 3, r = 0, boardSaveId = "board-b"},
        {q = -1, r = 0, boardSaveId = "missing"}
    }, {q = 0, r = 0}), {
        savedBoards = {
            board("board-a", "Entrance"),
            board("board-b", "Far Hall")
        }
    })
    open("Red")

    DungeonMap.handleAction("Red", tileAction(0, 1))
    Test.contains(attributes[Config.ui.statusId .. ".text"], "does not have")
    DungeonMap.handleAction("Red", tileAction(3, 0))
    Test.contains(attributes[Config.ui.statusId .. ".text"], "touching hex")
    DungeonMap.handleAction("Red", tileAction(-1, 0))
    Test.contains(attributes[Config.ui.statusId .. ".text"], "missing board save")
    Test.equal(0, #loadCalls)
end)

dungeonCase("successful dungeon traversal waits for placement correction", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"},
        {q = 1, r = 0, boardSaveId = "board-b"}
    }, {q = 0, r = 0}), {
        savedBoards = {
            board("board-a", "Entrance"),
            board("board-b", "Hall")
        }
    })
    open("Red")
    DungeonMap.handleAction("Red", tileAction(1, 0))

    Test.equal(1, #loadCalls)
    Test.equal("board-b", loadCalls[1].boardSaveId)
    Test.nilValue(DungeonMap.getSaveState().currentTile)

    open("Red")
    DungeonMap.handleAction("Red", tileAction(0, 0))
    Test.equal(1, #loadCalls)
    Test.contains(attributes[Config.ui.statusId .. ".text"], "already loading")

    pendingLoadCompletion(true)
    Test.equal(1, runScheduled(Config.traversalLockFrames))

    local completed = DungeonMap.getSaveState()
    Test.equal(1, completed.currentTile.q)
    Test.equal(0, completed.currentTile.r)
    Test.equal(1, persistCalls)
    Test.contains(messages[#messages].message, "Loaded dungeon level")
end)

dungeonCase("failed dungeon object completion does not save traversal", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"},
        {q = 1, r = 0, boardSaveId = "board-b"}
    }, {q = 0, r = 0}), {
        savedBoards = {
            board("board-a", "Entrance"),
            board("board-b", "Hall")
        }
    })
    open("Red")
    DungeonMap.handleAction("Red", tileAction(1, 0))
    pendingLoadCompletion(false)
    runScheduled(Config.traversalLockFrames)

    Test.nilValue(DungeonMap.getSaveState().currentTile)
    Test.equal(0, persistCalls)
    Test.contains(messages[#messages].message, "objects did not finish loading")
end)

dungeonCase("rejected and throwing dungeon loaders preserve current level", function()
    local savedState = makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"},
        {q = 1, r = 0, boardSaveId = "board-b"}
    }, {q = 0, r = 0})
    local boards = {
        board("board-a", "Entrance"),
        board("board-b", "Hall")
    }

    initialize(savedState, {
        savedBoards = boards,
        loadMode = "reject",
        loadMessage = "Rejected level."
    })
    open("Red")
    DungeonMap.handleAction("Red", tileAction(1, 0))
    Test.equal(0, DungeonMap.getSaveState().currentTile.q)
    Test.equal("Rejected level.", attributes[Config.ui.statusId .. ".text"])

    initialize(savedState, {
        savedBoards = boards,
        loadMode = "throw"
    })
    open("Red")
    DungeonMap.handleAction("Red", tileAction(1, 0))
    Test.equal(0, DungeonMap.getSaveState().currentTile.q)
    Test.equal(
        "Could not load that dungeon level.",
        attributes[Config.ui.statusId .. ".text"]
    )
end)

dungeonCase("dungeon traversal times out and unlocks future loads", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"},
        {q = 1, r = 0, boardSaveId = "board-b"}
    }, {q = 0, r = 0}), {
        savedBoards = {
            board("board-a", "Entrance"),
            board("board-b", "Hall")
        }
    })
    open("Red")
    DungeonMap.handleAction("Red", tileAction(1, 0))
    Test.equal(1, runScheduled(Config.traversalTimeoutFrames))

    Test.nilValue(DungeonMap.getSaveState().currentTile)
    Test.equal(0, persistCalls)
    Test.contains(messages[#messages].message, "position was not saved")

    open("Red")
    DungeonMap.handleAction("Red", tileAction(0, 0))
    Test.equal(2, #loadCalls)
end)

dungeonCase("matching external board loads restore the dungeon position", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"}
    }, {q = 0, r = 0}), {
        savedBoards = {board("board-a", "Entrance")}
    })

    local generation = DungeonMap.onExternalBoardLoadStarted("board-a")
    Test.nilValue(DungeonMap.getSaveState().currentTile)
    Test.truthy(DungeonMap.onExternalBoardLoadCompleted(
        generation,
        "board-a",
        true
    ))
    runScheduled(Config.traversalLockFrames)

    local restored = DungeonMap.getSaveState()
    Test.equal(0, restored.currentTile.q)
    Test.equal(0, restored.currentTile.r)
    Test.equal(1, persistCalls)
end)

dungeonCase("new external load generations reject stale completion", function()
    initialize(makeSavedState({
        {q = 0, r = 0, boardSaveId = "board-a"}
    }, {q = 0, r = 0}), {
        savedBoards = {board("board-a", "Entrance")}
    })

    local firstGeneration = DungeonMap.onExternalBoardLoadStarted("board-a")
    local secondGeneration = DungeonMap.onExternalBoardLoadStarted("board-a")

    Test.falsy(DungeonMap.onExternalBoardLoadCompleted(
        firstGeneration,
        "board-a",
        true
    ))
    Test.truthy(DungeonMap.onExternalBoardLoadCompleted(
        secondGeneration,
        "different-board",
        true
    ))
    runScheduled(Config.traversalLockFrames)

    Test.nilValue(DungeonMap.getSaveState().currentTile)
    Test.equal(1, persistCalls)
end)

local function makeDungeonControllerHarness(options)
    options = options or {}
    local runtimeEvents = options.runtimeEvents or {}
    local uiEvents = options.uiEvents or {}
    local scheduled = options.scheduled or {}
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
        frames = function(callback, frameCount)
            scheduled[#scheduled + 1] = {
                callback = callback,
                frameCount = frameCount
            }
        end
    }

    return DungeonMap.new({
        runtime = runtime,
        scheduler = scheduler,
        uiAdapter = uiAdapter
    }), runtimeEvents, uiEvents, scheduled
end

local function initializeConstructedDungeon(
    controller,
    savedState,
    controllerBoards,
    loadSavedBoardById
)
    controller.initialize({
        getSavedBoardSummaries = function()
            return controllerBoards or {}
        end,
        loadSavedBoardById = loadSavedBoardById,
        persistState = function()
            return true
        end
    }, savedState)
end

Test.case("constructed dungeon controllers isolate map sessions", function()
    local first = makeDungeonControllerHarness()
    local second = makeDungeonControllerHarness()
    initializeConstructedDungeon(
        first,
        nil,
        {board("board-a", "Entrance")}
    )
    initializeConstructedDungeon(second, nil, {})

    first.handleAction("Red", "toggle")
    first.handleAction("Red", "edit")
    first.handleAction("Red", tileAction(0, 0))
    first.handleAction("Red", "board1")

    Test.equal(1, #first.getSaveState().tiles)
    Test.equal("board-a", first.getSaveState().tiles[1].boardSaveId)
    Test.equal(0, #second.getSaveState().tiles)
end)

Test.case("constructed dungeon traces runtime scheduler and UI ports", function()
    local runtimeEvents = {}
    local uiEvents = {}
    local scheduled = {}
    local controller = makeDungeonControllerHarness({
        runtimeEvents = runtimeEvents,
        uiEvents = uiEvents,
        scheduled = scheduled
    })
    local controllerBoards = {
        board("board-a", "Entrance"),
        board("board-b", "Hall")
    }

    Test.withGlobals({
        Player = Test.NIL,
        UI = Test.NIL,
        broadcastToColor = Test.NIL,
        Wait = Test.NIL
    }, function()
        initializeConstructedDungeon(controller, makeSavedState({
            {q = 0, r = 0, boardSaveId = "board-a"},
            {q = 1, r = 0, boardSaveId = "board-b"}
        }, {q = 0, r = 0}), controllerBoards,
        function(_, _, onCompleted)
            onCompleted(true)
            return true, "Loaded dungeon level."
        end)

        controller.handleAction("Blue", "toggle")
        controller.handleAction("Blue", "edit")
        controller.handleAction("Blue", "toggle")
        controller.handleAction("Red", "toggle")
        controller.handleAction("Red", tileAction(1, 0))
    end)

    Test.equal("player:Blue", runtimeEvents[1])
    Test.contains(runtimeEvents[2], "broadcast:Blue:Only an admin")
    Test.equal(2, #scheduled)
    Test.equal(Config.traversalTimeoutFrames, scheduled[1].frameCount)
    Test.equal(Config.traversalLockFrames, scheduled[2].frameCount)
    Test.equal(
        "set:dungeonMapRoot.active=false",
        uiEvents[#uiEvents]
    )

    scheduled[2].callback()
    Test.contains(runtimeEvents[#runtimeEvents], "broadcast:Red:Loaded")
end)

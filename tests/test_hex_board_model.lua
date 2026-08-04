local Test = require("tests/support/Test")
local HexBoardCodec = require("src/hex/HexBoardCodec")
local HexBoardModel = require("src/hex/HexBoardModel")
local DeathFogDefinition = require("src/hex/DeathFogDefinition")
local HexGeometry = require("src/hex/HexGeometry")
local HexGridController = require("src/hex/HexGridController")
local HexGridView = require("src/hex/HexGridView")
local HexPlacementRules = require("src/hex/HexPlacementRules")

local templatesByKey = {
    token = {key = "token", occupiesFacingCell = false},
    wall = {key = "wall", occupiesFacingCell = true}
}

local function placement(templateKey, row, column, facingColumn, guid)
    return {
        templateKey = templateKey,
        cell = {row = row, column = column},
        facingCell = {row = row, column = facingColumn},
        guid = guid
    }
end

Test.case("hex board models isolate restored state from input mutation", function()
    local original = {
        selectedCells = {['0:0'] = true},
        placements = {placement("wall", 0, 0, 1, "wall-a")}
    }
    local model = HexBoardModel.new(original)

    original.selectedCells['0:0'] = nil
    original.placements[1].cell.row = 9

    Test.truthy(model.selectedCells['0:0'])
    Test.equal(0, model.placements[1].cell.row)
    Test.equal("wall-a", model.placements[1].guid)
end)

Test.case("hex board selection mutations have explicit semantics", function()
    local model = HexBoardModel.new()

    Test.truthy(HexBoardModel.toggleSelected(model, "0:0"))
    Test.truthy(HexBoardModel.isSelected(model, "0:0"))
    Test.truthy(HexBoardModel.setSelected(model, "1:-1", true))
    Test.nilValue(model.selectedCells["0:0"])
    Test.truthy(model.selectedCells["1:-1"])

    Test.falsy(HexBoardModel.toggleSelected(model, "1:-1"))
    Test.nilValue(model.selectedCells["1:-1"])

    HexBoardModel.setSelected(model, "0:0", true)
    HexBoardModel.clear(model)
    Test.nilValue(model.selectedCells["0:0"])
    Test.equal(0, #model.placements)
end)

Test.case("hex board placement identity supports add find and remove", function()
    local model = HexBoardModel.new()
    local first = placement("token", 0, 0, 1, "token-a")

    Test.equal(first, HexBoardModel.addPlacement(model, first))
    Test.truthy(HexBoardModel.hasPlacement(model, first))
    Test.equal(first, HexBoardModel.findPlacementByGuid(model, "token-a"))
    Test.nilValue(HexBoardModel.findPlacementByGuid(model, 12))
    Test.truthy(HexBoardModel.removePlacement(model, first))
    Test.falsy(HexBoardModel.removePlacement(model, first))
end)

Test.case("placement rules account for multi-cell templates", function()
    local token = placement("token", 0, 0, 1)
    local wall = placement("wall", 1, 0, 1)

    Test.equal(1, #HexPlacementRules.getOccupiedCells(
        token,
        templatesByKey
    ))
    Test.equal(2, #HexPlacementRules.getOccupiedCells(
        wall,
        templatesByKey
    ))
    Test.truthy(HexPlacementRules.occupiesCell(
        wall,
        {row = 1, column = 1},
        templatesByKey
    ))
    Test.falsy(HexPlacementRules.occupiesCell(
        token,
        {row = 0, column = 1},
        templatesByKey
    ))
end)

Test.case("placement conflict detection reports each object once", function()
    local existing = placement("wall", 0, 0, 1, "wall-a")
    local candidate = placement("wall", 0, 1, 0, "wall-b")
    local conflicts = HexPlacementRules.findConflicts(
        {existing},
        candidate,
        templatesByKey
    )

    Test.equal(1, #conflicts)
    Test.equal(existing, conflicts[1])

    for key, _ in pairs(conflicts) do
        Test.equal("number", type(key))
    end

    Test.equal(0, #HexPlacementRules.findConflicts(
        {existing},
        candidate,
        templatesByKey,
        existing
    ))
end)

Test.case("placement sessions produce copied domain placements", function()
    local target = {row = 0, column = 0}
    local facing = {row = 0, column = 1}
    local pending = HexPlacementRules.begin(
        templatesByKey.wall,
        target,
        "White",
        {['0:1'] = facing}
    )
    local completed = HexPlacementRules.complete(pending, facing)

    target.row = 3
    facing.column = 3

    Test.equal("wall", completed.templateKey)
    Test.equal(0, completed.cell.row)
    Test.equal(1, completed.facingCell.column)
end)

Test.case("hex board codec serializes in grid and placement order", function()
    local model = HexBoardModel.new({
        selectedCells = {['0:0'] = true, ['0:1'] = true},
        placements = {placement("wall", 0, 0, 1)}
    })
    local cells = {
        {row = 0, column = 1},
        {row = 0, column = 0},
        {row = 1, column = 0}
    }
    local state = HexBoardCodec.serialize(model, cells, {
        schemaVersion = 4,
        boardGuid = "board-a",
        cellKey = HexGeometry.cellKey,
        templatesByKey = templatesByKey
    })

    Test.equal(4, state.schemaVersion)
    Test.equal("board-a", state.boardGuid)
    Test.equal(1, state.selectedHexes[1].column)
    Test.equal(0, state.selectedHexes[2].column)
    Test.equal(2, #state.hexObjects[1].occupiedHexes)
end)

Test.case("hex board codec delegates validation into model-ready state", function()
    local cells = HexGeometry.buildCells({
        sideLength = 2,
        hexRadius = 1,
        rotationDegrees = 0,
        offsetX = 0,
        offsetZ = 0,
        hitEdgePadding = 0
    })
    local normalized, validationError = HexBoardCodec.normalize({
        schemaVersion = 1,
        boardGuid = "board-a",
        selectedHexes = {{row = 0, column = 0}},
        hexObjects = {}
    }, {
        schemaVersion = 1,
        boardGuid = "board-a",
        cellsByKey = HexGeometry.indexCells(cells),
        templatesByKey = templatesByKey
    })

    Test.nilValue(validationError)
    Test.truthy(normalized.selectedCells['0:0'])
    Test.equal(1, normalized.selectedHexCount)
end)

Test.case("hex grid view builds render state and delegates drawing", function()
    local model = HexBoardModel.new({
        selectedCells = {['0:0'] = true}
    })
    local captured = nil
    local builder = {
        draw = function(board, cells, surfaceY, renderState)
            captured = {
                board = board,
                cells = cells,
                surfaceY = surfaceY,
                renderState = renderState
            }
            return "drawn"
        end
    }
    local board = {}
    local cells = {{row = 0, column = 0}}

    Test.equal("drawn", HexGridView.draw(
        builder,
        board,
        cells,
        1.5,
        model,
        {hoveredCells = {['0:0'] = true}}
    ))
    Test.equal(board, captured.board)
    Test.equal(cells, captured.cells)
    Test.truthy(captured.renderState.selectedCells['0:0'])
    Test.truthy(captured.renderState.hoveredCells['0:0'])
end)

local function newController()
    return HexGridController.new({
        schemaVersion = 1,
        boardGuid = "board-a",
        cellKey = HexGeometry.cellKey,
        templatesByKey = templatesByKey
    })
end

Test.case("hex grid controllers own isolated board models", function()
    local first = newController()
    local second = newController()

    HexBoardModel.setSelected(first:getModel(), "0:0", true)
    HexBoardModel.addPlacement(
        first:getModel(),
        placement("token", 0, 0, 1, "token-a")
    )

    Test.truthy(first:getModel().selectedCells["0:0"])
    Test.nilValue(second:getModel().selectedCells["0:0"])
    Test.equal(0, #second:getModel().placements)
end)

Test.case("hex grid controller restores legacy save envelopes", function()
    local controller = newController()
    local pending = controller:loadSaveState({
        selectedCells = {['0:0'] = true},
        placedObjects = {placement("wall", 0, 0, 1, "wall-a")}
    })

    Test.truthy(controller:getModel().selectedCells['0:0'])
    Test.equal("wall-a", pending[1].guid)
    Test.equal(0, #controller:getModel().placements)

    controller:loadSaveState("malformed")
    Test.nilValue(controller:getModel().selectedCells['0:0'])
end)

Test.case("hex grid controller save snapshots cannot mutate runtime", function()
    local controller = newController()
    local model = controller:getModel()
    HexBoardModel.setSelected(model, "0:0", true)
    HexBoardModel.addPlacement(
        model,
        placement("token", 0, 0, 1, "token-a")
    )
    local saved = controller:getSaveState()

    saved.selectedCells['0:0'] = nil
    saved.placedObjects[1].cell.row = 9

    Test.truthy(model.selectedCells['0:0'])
    Test.equal(0, model.placements[1].cell.row)
end)

Test.case("hex grid controller owns import and export configuration", function()
    local controller = newController()
    local cells = HexGeometry.buildCells({
        sideLength = 2,
        hexRadius = 1,
        rotationDegrees = 0,
        offsetX = 0,
        offsetZ = 0,
        hitEdgePadding = 0
    })
    controller:configureGrid(cells, HexGeometry.indexCells(cells))
    HexBoardModel.setSelected(controller:getModel(), "0:0", true)

    local exported = controller:getBoardState()
    local imported, validationError =
        controller:normalizeBoardState(exported)

    Test.nilValue(validationError)
    Test.equal(1, imported.selectedHexCount)
    controller:applyLoadedSelection(imported)
    Test.truthy(controller:getModel().selectedCells['0:0'])
end)

local function makeGridHarness(name, surfaceY, options)
    options = options or {}
    local callbacks = {}
    local destroyed = {}
    local objectsByGuid = {}
    local trace = {}
    local player = {
        admin = true,
        color = "Red",
        getPointerPosition = function()
            return {x = 0, y = 0, z = 0}
        end
    }
    local board = {
        name = name,
        positionToLocal = function(position)
            return position
        end,
        positionToWorld = function(position)
            return position
        end
    }
    local cells = {
        {row = 0, column = 0, x = 0, z = 0},
        {row = 0, column = 1, x = 1, z = 0}
    }
    local menuContext = nil
    local spawnedParameters = nil
    local spawnedObject = {
        addTag = function()
        end,
        getBounds = function()
            return {
                center = {x = 1, y = 1, z = 0},
                size = {x = 1, y = 2, z = 1}
            }
        end,
        getGUID = function()
            return name .. "-spawned"
        end
    }
    local menu = {
        initialize = function(parameters)
            menuContext = parameters
        end,
        showSpawnSelector = function()
        end,
        hideSpawnSelector = function()
        end,
        open = function()
        end,
        handleAction = function()
        end,
        close = function()
        end
    }
    local runtime = {
        getObject = function(guid)
            trace[#trace + 1] = "getObject:" .. tostring(guid)

            if guid == name .. "-board" then
                return board
            end

            return objectsByGuid[guid]
        end,
        getPlayer = function(playerColor)
            trace[#trace + 1] = "getPlayer:" .. playerColor
            return player
        end,
        getPlayers = function()
            trace[#trace + 1] = "getPlayers"
            return {player}
        end,
        getSelectAction = function()
            return "select"
        end,
        getObjectsWithTag = function()
            return {}
        end,
        destroyObject = function(object)
            destroyed[#destroyed + 1] = object
        end,
        broadcastToColor = function()
        end,
        getGlobalOwner = function()
            return {}
        end,
        log = function(message)
            trace[#trace + 1] = "log:" .. message
        end
    }
    local scheduler = {
        frames = function(callback, frameCount)
            callbacks[#callbacks + 1] = {
                callback = callback,
                frameCount = frameCount
            }
            return name .. "-frame-" .. #callbacks
        end,
        time = function(_, delay, repetitions)
            trace[#trace + 1] = "time:" .. delay .. ":"
                .. repetitions
            return name .. "-hover"
        end,
        stop = function(identifier)
            trace[#trace + 1] = "stop:" .. identifier
        end
    }
    local builder = {
        cellKey = HexGeometry.cellKey,
        build = function(targetBoard)
            Test.equal(board, targetBoard)
            return {cells = cells, surfaceY = surfaceY}
        end,
        draw = function()
        end,
        findCellAt = function()
            return cells[1]
        end
    }
    local controller = HexGridController.new({
        boardGuid = name .. "-board",
        schemaVersion = 1,
        runtime = runtime,
        scheduler = scheduler,
        builder = builder,
        menu = menu,
        objectSpawner = {
            spawn = function(parameters)
                spawnedParameters = parameters

                if options.spawn ~= nil then
                    return options.spawn(parameters)
                end

                parameters.onSpawned(spawnedObject)
                return true
            end,
            place = function()
                return true
            end
        },
        surfaceDefinitions = options.surfaceDefinitions
    })

    return {
        board = board,
        callbacks = callbacks,
        cells = cells,
        controller = controller,
        destroyed = destroyed,
        getMenuContext = function()
            return menuContext
        end,
        objectsByGuid = objectsByGuid,
        spawnedObject = spawnedObject,
        getSpawnedParameters = function()
            return spawnedParameters
        end,
        trace = trace
    }
end

Test.case("full hex grid controllers isolate every board session", function()
    local first = makeGridHarness("first", 1.25)
    local second = makeGridHarness("second", 2.5)

    first.controller.onLoad({
        selectedCells = {['0:0'] = true},
        placedObjects = {{templateKey = "invalid"}}
    })
    second.controller.onLoad(nil)

    Test.equal(1, #first.controller.getSessionSnapshot()
        .pendingSavedPlacements)
    Test.equal(0, #second.controller.getSessionSnapshot()
        .pendingSavedPlacements)

    first.callbacks[1].callback()
    second.callbacks[1].callback()

    first.controller.setEditMode(true)
    Test.truthy(first.controller.onScriptingButtonDown(1, "Red"))
    Test.falsy(second.controller.onScriptingButtonDown(1, "Red"))
    first.controller.onClicked("Red", false)
    first.controller.onObjectHover()
    first.getMenuContext().onTargetChanged(first.cells[1])

    local firstState = first.controller.getSessionSnapshot()
    local secondState = second.controller.getSessionSnapshot()

    Test.equal(first.board, firstState.board)
    Test.equal(second.board, secondState.board)
    Test.falsy(firstState.cells == secondState.cells)
    Test.equal(1.25, firstState.resolvedSurfaceY)
    Test.equal(2.5, secondState.resolvedSurfaceY)
    Test.equal("first-hover", firstState.hoverWaitId)
    Test.equal("second-hover", secondState.hoverWaitId)
    Test.truthy(firstState.hoveredCells['0:0'])
    Test.nilValue(secondState.hoveredCells['0:0'])
    Test.equal(first.cells[1], firstState.menuTargetCell)
    Test.nilValue(secondState.menuTargetCell)
    Test.truthy(firstState.rotationCandidateCells['0:1'])
    Test.nilValue(secondState.rotationCandidateCells['0:1'])
    Test.truthy(firstState.pendingSpawn ~= nil)
    Test.nilValue(secondState.pendingSpawn)
    Test.equal("tree", firstState.selectedTemplate.key)
    Test.nilValue(secondState.selectedTemplate)
    Test.truthy(firstState.editMode)
    Test.falsy(secondState.editMode)
    Test.equal("0:0", firstState.recentClickCells.Red)
    Test.nilValue(secondState.recentClickCells.Red)
    Test.truthy(first.controller.getModel().selectedCells['0:0'])
    Test.nilValue(second.controller.getModel().selectedCells['0:0'])
end)

Test.case("hex grid places death fog only on its outer candidates", function()
    local harness = makeGridHarness("fog", 1.25)
    local completed = nil
    local sourcePosition = {x = 1.65, y = 1, z = 0.19}
    local sourceStone = {
        getBounds = function()
            return {
                center = {x = 1.65, y = 1.5, z = 0.19},
                size = {x = 1, y = 1, z = 1}
            }
        end,
        getPosition = function()
            return sourcePosition
        end,
        setPosition = function(position)
            sourcePosition = position
        end
    }

    harness.controller.onLoad(nil)
    harness.callbacks[1].callback()
    harness.objectsByGuid["source-stone"] = sourceStone
    HexBoardModel.addPlacement(harness.controller.getModel(), {
        templateKey = "sourceStone",
        cell = {row = 0, column = 1},
        facingCell = {row = 0, column = 0},
        guid = "source-stone"
    })
    Test.truthy(harness.controller.beginDeathFogPlacement(
        "Red",
        function(succeeded)
            completed = succeeded
        end
    ))

    local candidates = harness.controller.getSessionSnapshot()
        .deathFogCandidateCells
    Test.truthy(candidates["0:1"])
    Test.nilValue(candidates["0:0"])

    harness.cells[1], harness.cells[2] =
        harness.cells[2], harness.cells[1]
    harness.controller.onClicked("Red", false)

    Test.truthy(completed)
    local fogPlacement = nil

    for _, placement in ipairs(
        harness.controller.getModel().placements
    ) do
        if placement.templateKey == "deathFog" then
            fogPlacement = placement
        end
    end

    Test.truthy(fogPlacement ~= nil)
    Test.equal(
        "dcc277",
        harness.getSpawnedParameters().template.sourceGuid
    )
    harness.getSpawnedParameters().onPlacementFinalized(
        harness.spawnedObject
    )
    Test.equal(1.65, sourcePosition.x)
    Test.equal(2, sourcePosition.y)
    Test.equal(0.19, sourcePosition.z)
    Test.equal(2, #harness.controller.getModel().placements)
    Test.nilValue(
        harness.controller.getSessionSnapshot().deathFogRequest
    )
end)

Test.case("normal tile clicks open the surface picker and place death fog", function()
    local harness = makeGridHarness("surface-picker", 1.25)

    harness.controller.onLoad(nil)
    harness.callbacks[1].callback()
    harness.controller.onClicked("Red", false)

    local activeMenu = harness.controller.getSessionSnapshot().surfaceMenu
    Test.truthy(activeMenu ~= nil)
    Test.equal("Red", activeMenu.playerColor)
    Test.equal(0, activeMenu.cell.row)
    Test.falsy(
        harness.controller.onSurfaceUiClicked("Blue", "deathFog")
    )
    Test.truthy(
        harness.controller.onSurfaceUiClicked("Red", "deathFog")
    )

    local placements = harness.controller.getModel().placements
    Test.equal(1, #placements)
    Test.equal("deathFog", placements[1].templateKey)
    Test.nilValue(harness.controller.getSessionSnapshot().surfaceMenu)
end)

Test.case("normal surface picker places configured surface variants", function()
    local harness = makeGridHarness("configured-surface", 1.25)

    harness.controller.onLoad(nil)
    harness.callbacks[1].callback()
    harness.controller.onClicked("Red", false)

    Test.truthy(harness.controller.onSurfaceUiClicked("Red", "fire"))
    Test.equal(
        "fire",
        harness.controller.getModel().placements[1].templateKey
    )
    Test.equal("Fire", harness.getSpawnedParameters().template.label)
    Test.contains(
        harness.getSpawnedParameters().template.json,
        '"ColorDiffuse":{"r":0.85,"g":0.08,"b":0.04,"a":0.65}'
    )
end)

Test.case("rejected surface spawns preserve the picker and board state", function()
    local harness = makeGridHarness("surface-rejected", 1.25, {
        spawn = function()
            return false
        end
    })

    harness.controller.onLoad(nil)
    harness.callbacks[1].callback()
    harness.controller.onClicked("Red", false)

    Test.falsy(
        harness.controller.onSurfaceUiClicked("Red", "deathFog")
    )
    Test.equal(0, #harness.controller.getModel().placements)
    Test.truthy(
        harness.controller.getSessionSnapshot().surfaceMenu ~= nil
    )
end)

Test.case("surface picker excludes ordinary objects but allows source stones", function()
    local harness = makeGridHarness("surface-availability", 1.25)

    harness.controller.onLoad(nil)
    harness.callbacks[1].callback()
    HexBoardModel.addPlacement(harness.controller.getModel(), {
        templateKey = "tree",
        cell = {row = 0, column = 0},
        facingCell = {row = 0, column = 1}
    })
    harness.controller.onClicked("Red", false)
    Test.nilValue(harness.controller.getSessionSnapshot().surfaceMenu)

    harness.controller.getModel().placements = {
        {
            templateKey = "sourceStone",
            cell = {row = 0, column = 0},
            facingCell = {row = 0, column = 1}
        }
    }
    harness.callbacks[#harness.callbacks].callback()
    harness.controller.onClicked("Red", false)
    Test.truthy(
        harness.controller.getSessionSnapshot().surfaceMenu ~= nil
    )
end)

Test.case("placing a surface atomically replaces the previous surface", function()
    local mudTemplate = {
        key = "mud",
        label = "Mud",
        json = "mud-json",
        isSurface = true,
        addEditButtons = false
    }
    local fireTemplate = {
        key = "fire",
        label = "Fire",
        json = "fire-json",
        isSurface = true,
        addEditButtons = false
    }
    local harness = makeGridHarness("surface-replacement", 1.25, {
        surfaceDefinitions = {
            {
                key = "deathFog",
                label = "Death Fog",
                placementTemplate = DeathFogDefinition
            },
            {
                key = "mud",
                label = "Mud",
                placementTemplate = mudTemplate
            },
            {
                key = "fire",
                label = "Fire",
                placementTemplate = fireTemplate
            }
        }
    })
    local oldObject = {}

    harness.controller.onLoad(nil)
    harness.callbacks[1].callback()
    harness.objectsByGuid["old-mud"] = oldObject
    HexBoardModel.addPlacement(harness.controller.getModel(), {
        templateKey = "mud",
        cell = {row = 0, column = 0},
        facingCell = {row = 0, column = 1},
        guid = "old-mud"
    })
    harness.controller.onClicked("Red", false)
    Test.truthy(harness.controller.onSurfaceUiClicked("Red", "fire"))

    local placements = harness.controller.getModel().placements
    Test.equal(1, #placements)
    Test.equal("fire", placements[1].templateKey)
    Test.equal(1, #harness.destroyed)
    Test.equal(oldObject, harness.destroyed[1])
end)

Test.case("death fog prevents reopening the surface picker", function()
    local harness = makeGridHarness("protected-fog", 1.25)

    harness.controller.onLoad(nil)
    harness.callbacks[1].callback()
    HexBoardModel.addPlacement(harness.controller.getModel(), {
        templateKey = "deathFog",
        cell = {row = 0, column = 0},
        facingCell = {row = 0, column = 1}
    })
    harness.controller.onClicked("Red", false)
    Test.nilValue(harness.controller.getSessionSnapshot().surfaceMenu)
end)

Test.case("constructed hex grid supports bound dot calls", function()
    local controller = newController()
    local cells = {{row = 0, column = 0}}

    controller.configureGrid(
        cells,
        {['0:0'] = cells[1]}
    )
    HexBoardModel.setSelected(controller.getModel(), "0:0", true)

    Test.equal(1, #controller.getBoardState().selectedHexes)
    Test.truthy(controller.getSaveState().selectedCells['0:0'])
end)

Test.case("hex grid orchestration follows injected adapter order", function()
    local trace = {}
    local board = {
        positionToLocal = function(position)
            return position
        end,
        positionToWorld = function(position)
            return position
        end
    }
    local cell = {row = 0, column = 0, x = 0, z = 0}
    local player = {
        admin = true,
        getPointerPosition = function()
            return {x = 0, y = 0, z = 0}
        end
    }
    local runtime = {
        getObject = function(guid)
            trace[#trace + 1] = "runtime.getObject:" .. guid
            return board
        end,
        getPlayer = function(color)
            trace[#trace + 1] = "runtime.getPlayer:" .. color
            return player
        end,
        getPlayers = function()
            trace[#trace + 1] = "runtime.getPlayers"
            return {player}
        end,
        getSelectAction = function()
            return "select"
        end,
        getObjectsWithTag = function()
            return {}
        end,
        destroyObject = function()
        end,
        broadcastToColor = function(_, color)
            trace[#trace + 1] = "runtime.broadcast:" .. color
        end,
        getGlobalOwner = function()
            return {}
        end,
        log = function()
            trace[#trace + 1] = "runtime.log"
        end
    }
    local scheduler = {
        frames = function(callback, count)
            trace[#trace + 1] = "scheduler.frames:" .. count
            callback()
            return "frame-id"
        end,
        time = function(_, delay, repetitions)
            trace[#trace + 1] = "scheduler.time:" .. delay .. ":"
                .. repetitions
            return "hover-id"
        end,
        stop = function(identifier)
            trace[#trace + 1] = "scheduler.stop:" .. identifier
        end
    }
    local menu = {
        initialize = function()
            trace[#trace + 1] = "menu.initialize"
        end,
        showSpawnSelector = function(template)
            trace[#trace + 1] = "menu.show:"
                .. (template and template.key or "none")
        end,
        hideSpawnSelector = function()
        end,
        open = function()
        end,
        handleAction = function()
        end,
        close = function()
            trace[#trace + 1] = "menu.close"
        end
    }
    local builder = {
        cellKey = HexGeometry.cellKey,
        build = function()
            trace[#trace + 1] = "builder.build"
            return {cells = {cell}, surfaceY = 3}
        end,
        draw = function()
            trace[#trace + 1] = "builder.draw"
        end,
        findCellAt = function()
            trace[#trace + 1] = "builder.findCellAt"
            return cell
        end
    }
    local controller = HexGridController.new({
        boardGuid = "trace-board",
        runtime = runtime,
        scheduler = scheduler,
        builder = builder,
        menu = menu,
        objectSpawner = {
            spawn = function()
                return false
            end,
            place = function()
                return true
            end
        }
    })

    Test.withGlobals({
        Player = Test.NIL,
        Wait = Test.NIL,
        getObjectFromGUID = Test.NIL,
        broadcastToColor = Test.NIL
    }, function()
        controller.onLoad(nil)
        controller.onObjectHover()
        controller.setEditMode(true)
        controller.onScriptingButtonDown(1, "Red")
        controller.onLoad(nil)
    end)

    Test.deepEqual({
        "scheduler.frames:2",
        "runtime.getObject:trace-board",
        "builder.build",
        "builder.draw",
        "menu.initialize",
        "scheduler.time:0.05:-1",
        "runtime.log",
        "runtime.getPlayers",
        "builder.findCellAt",
        "builder.draw",
        "menu.show:none",
        "runtime.getPlayer:Red",
        "menu.close",
        "menu.show:tree",
        "runtime.broadcast:Red",
        "scheduler.frames:2",
        "runtime.getObject:trace-board",
        "builder.build",
        "builder.draw",
        "menu.initialize",
        "menu.show:none",
        "scheduler.stop:hover-id",
        "scheduler.time:0.05:-1",
        "runtime.log"
    }, trace)
end)

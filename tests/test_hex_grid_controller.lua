local Test = require("tests/support/Test")
local HexBoardModel = require("src/hex/HexBoardModel")
local HexGeometry = require("src/hex/HexGeometry")
local HexGridController = require("src/hex/HexGridController")

local function makePlacement(templateKey, row, column, facingRow,
    facingColumn, guid)
    return {
        templateKey = templateKey,
        cell = {row = row, column = column},
        facingCell = {row = facingRow, column = facingColumn},
        guid = guid
    }
end

local function makeBoardState(objects, selectedHexes)
    local hexObjects = {}

    for index, object in ipairs(objects or {}) do
        hexObjects[index] = {
            type = object.templateKey,
            hex = {
                row = object.cell.row,
                column = object.cell.column
            },
            facing = {
                row = object.facingCell.row,
                column = object.facingCell.column
            },
            occupiedHexes = {
                {
                    row = object.cell.row,
                    column = object.cell.column
                }
            }
        }
    end

    return {
        schemaVersion = 1,
        boardGuid = "test-board",
        selectedHexes = selectedHexes or {},
        hexObjects = hexObjects
    }
end

local function makeSpawnedObject(guid, options)
    options = options or {}
    local object = {tags = {}}

    object.getGUID = function()
        return guid
    end
    object.addTag = function(tag)
        if options.addTagError ~= nil then
            error(options.addTagError)
        end

        object.tags[#object.tags + 1] = tag
    end

    return object
end

local function newHarness(options)
    options = options or {}
    local harness = {
        destroyed = {},
        logs = {},
        objectsByGuid = {},
        pointerPosition = {x = 0, y = 0, z = 0},
        scheduledFrames = {},
        spawnCalls = {},
        taggedObjects = {}
    }
    local geometryConfig = {
        sideLength = 2,
        hexRadius = 1,
        rotationDegrees = 0,
        offsetX = 0,
        offsetZ = 0,
        hitEdgePadding = 0
    }
    local cells = HexGeometry.buildCells(geometryConfig)
    local board = {
        positionToLocal = function(position)
            return position
        end,
        positionToWorld = function(position)
            return position
        end
    }
    local player = {
        admin = true,
        color = "Red",
        getPointerPosition = function()
            return harness.pointerPosition
        end
    }
    local templates = {
        {
            key = "tree",
            label = "Tree",
            json = "tree-json",
            editClickArea = {}
        },
        {
            key = "rock",
            label = "Rock",
            json = "rock-json",
            editClickArea = {}
        }
    }
    local templatesByKey = {}

    for _, template in ipairs(templates) do
        templatesByKey[template.key] = template
    end

    local runtime = {
        getObject = function(guid)
            if guid == "test-board" then
                return board
            end

            return harness.objectsByGuid[guid]
        end,
        getObjectsWithTag = function()
            return harness.taggedObjects
        end,
        destroyObject = function(object)
            harness.destroyed[#harness.destroyed + 1] = object
        end,
        getPlayer = function()
            return player
        end,
        getPlayers = function()
            return {player}
        end,
        getSelectAction = function()
            return "Select"
        end,
        getGlobalOwner = function()
            return {}
        end,
        broadcastToColor = function()
        end,
        log = function(message)
            harness.logs[#harness.logs + 1] = message
        end
    }
    local scheduler = {
        frames = function(callback, frameCount)
            harness.scheduledFrames[#harness.scheduledFrames + 1] =
                frameCount
            callback()
            return "frame-" .. #harness.scheduledFrames
        end,
        time = function()
            return "hover-loop"
        end,
        stop = function()
        end
    }
    local menu = {
        initialize = function(context)
            harness.menuContext = context
        end,
        close = function()
            harness.menuCloseCount = (harness.menuCloseCount or 0) + 1
        end,
        open = function()
        end,
        handleAction = function()
        end,
        showSpawnSelector = function()
        end,
        hideSpawnSelector = function()
        end
    }
    local builder = {
        cellKey = HexGeometry.cellKey,
        build = function(targetBoard)
            Test.equal(board, targetBoard)
            return {cells = cells, surfaceY = 0}
        end,
        findCellAt = function()
            return harness.pointerCell
        end
    }
    local objectSpawner = {
        place = function(parameters)
            harness.placeCall = parameters
            return true
        end,
        spawn = function(parameters)
            harness.spawnCalls[#harness.spawnCalls + 1] = parameters

            if options.spawn ~= nil then
                return options.spawn(parameters, harness)
            end

            if harness.spawn ~= nil then
                return harness.spawn(parameters, harness)
            end

            return true
        end
    }
    local json = {
        decode = function(value)
            if harness.decode ~= nil then
                return harness.decode(value)
            end

            return value
        end,
        encodePretty = function(value)
            return value
        end
    }

    harness.board = board
    harness.cells = cells
    harness.cellsByKey = HexGeometry.indexCells(cells)
    harness.player = player
    harness.templates = templates
    harness.templatesByKey = templatesByKey
    harness.controller = HexGridController.new({
        boardGuid = "test-board",
        schemaVersion = 1,
        spawnDefinitions = templates,
        templatesByKey = templatesByKey,
        runtime = runtime,
        scheduler = scheduler,
        builder = builder,
        view = {draw = function() end},
        menu = menu,
        objectSpawner = objectSpawner,
        debugConfig = options.debugConfig,
        json = json
    })

    return harness
end

Test.case("surfaces receive three selectable top hitboxes", function()
    local harness = newHarness({
        debugConfig = {
            drawEditObjectButtons = false,
            drawSurfaceHitboxes = true
        }
    })
    local buttons = {}
    local surfaceObject = {
        addTag = function()
        end,
        createButton = function(parameters)
            buttons[#buttons + 1] = parameters
        end,
        getBounds = function()
            return {
                center = {x = 0, y = 0.1, z = 0},
                size = {x = 3, y = 0.2, z = 3}
            }
        end,
        getButtons = function()
            return {}
        end,
        getGUID = function()
            return "fire-surface"
        end,
        positionToLocal = function(position)
            return {
                x = position.x * 0.5,
                y = position.y,
                z = position.z * 0.5
            }
        end
    }
    harness.objectsByGuid["fire-surface"] = surfaceObject

    harness.controller:onLoad({
        placedObjects = {
            makePlacement("fire", 0, 0, 0, 1, "fire-surface")
        }
    })

    Test.equal(3, #buttons)
    Test.equal("onHexGridObjectClicked", buttons[1].click_function)
    Test.equal(640, buttons[1].width)
    Test.equal(400, buttons[1].height)
    Test.near(0, buttons[1].rotation[2], 0.0001)
    Test.near(60, buttons[2].rotation[2], 0.0001)
    Test.near(120, buttons[3].rotation[2], 0.0001)
    Test.equal("0", buttons[1].label)
    Test.contains(buttons[1].tooltip, "surface hitbox")

    harness.pointerCell = harness.cellsByKey["0:0"]
    harness.controller:onObjectClicked(surfaceObject, "Red", false)
    Test.truthy(
        harness.controller:getModel().selectedCells["0:0"]
    )
end)

Test.case("hex hover polling ignores players without a pointer", function()
    local harness = newHarness()
    harness.controller:onLoad(nil)
    harness.pointerCell = harness.cellsByKey["0:0"]

    harness.controller:onObjectHover()
    Test.truthy(
        harness.controller:getSessionSnapshot().hoveredCells["0:0"]
    )

    harness.pointerPosition = nil
    harness.controller:onObjectHover()
    Test.nilValue(
        harness.controller:getSessionSnapshot().hoveredCells["0:0"]
    )
end)

Test.case("restart removes surfaces while preserving map objects", function()
    local harness = newHarness()
    local surfaceObject = makeSpawnedObject("surface-guid")
    local treeObject = makeSpawnedObject("tree-guid")
    local surfacePlacement = makePlacement(
        "mist-surface", 0, 0, 0, 1, "surface-guid"
    )
    local treePlacement = makePlacement(
        "tree", 0, 0, 0, 1, "tree-guid"
    )

    harness.controller.templatesByKey["mist-surface"] = {
        key = "mist-surface",
        isSurface = true
    }
    harness.objectsByGuid["surface-guid"] = surfaceObject
    harness.objectsByGuid["tree-guid"] = treeObject
    HexBoardModel.addPlacement(
        harness.controller:getModel(),
        surfacePlacement
    )
    HexBoardModel.addPlacement(
        harness.controller:getModel(),
        treePlacement
    )

    Test.truthy(harness.controller:clearSurfacesForRestart())
    Test.equal(1, #harness.destroyed)
    Test.equal(surfaceObject, harness.destroyed[1])

    local state = harness.controller:getSaveState()
    Test.equal(1, #state.placedObjects)
    Test.equal("tree", state.placedObjects[1].templateKey)
end)

local function addPlacement(harness, placement)
    HexBoardModel.addPlacement(
        harness.controller:getModel(),
        placement
    )
end

Test.case("hex board loads validate before destroying live objects", function()
    local harness = newHarness()
    harness.controller:onLoad(nil)
    local oldObject = {getGUID = function() return "old-guid" end}
    local oldPlacement = makePlacement(
        "tree",
        0,
        0,
        0,
        1,
        "old-guid"
    )
    harness.taggedObjects = {oldObject}
    harness.objectsByGuid["old-guid"] = oldObject
    addPlacement(harness, oldPlacement)
    HexBoardModel.setSelected(
        harness.controller:getModel(),
        "0:0",
        true
    )

    local accepted, message = harness.controller:loadBoardState({
        schemaVersion = 99,
        boardGuid = "test-board",
        selectedHexes = {},
        hexObjects = {}
    }, "Red")

    Test.falsy(accepted)
    Test.contains(message, "Unsupported")
    Test.equal(0, #harness.destroyed)
    Test.equal(1, #harness.controller:getModel().placements)
    Test.equal(oldPlacement, harness.controller:getModel().placements[1])
    Test.truthy(harness.controller:getModel().selectedCells["0:0"])

    harness.decode = function()
        error("invalid JSON")
    end
    accepted, message = harness.controller:loadBoardStateJson(
        "not-json",
        "Red"
    )
    Test.falsy(accepted)
    Test.contains(message, "not valid JSON")
    Test.equal(0, #harness.destroyed)
    Test.equal(oldPlacement, harness.controller:getModel().placements[1])
end)

Test.case("hex JSON loads delegate and complete empty boards synchronously", function()
    local harness = newHarness()
    harness.controller:onLoad(nil)
    local completions = {}
    local decoded = makeBoardState({}, {{row = 0, column = 0}})
    harness.decode = function(value)
        Test.equal("valid-board", value)
        return decoded
    end

    local accepted, message = harness.controller:loadBoardStateJson(
        "valid-board",
        "Red",
        function(succeeded)
            completions[#completions + 1] = succeeded
        end
    )

    Test.truthy(accepted)
    Test.contains(message, "1 selected hexes and 0 objects")
    Test.deepEqual({true}, completions)
    Test.truthy(harness.controller:getModel().selectedCells["0:0"])
end)

Test.case("hex board loads report asynchronous partial failure exactly once", function()
    local harness = newHarness()
    harness.controller:onLoad(nil)
    local taggedObject = {
        getGUID = function() return "tagged-old" end
    }
    local modelObject = {
        getGUID = function() return "model-old" end
    }
    harness.taggedObjects = {taggedObject}
    harness.objectsByGuid["model-old"] = modelObject
    addPlacement(harness, makePlacement(
        "tree",
        -1,
        0,
        -1,
        1,
        "model-old"
    ))
    local completions = {}
    local state = makeBoardState({
        makePlacement("tree", 0, 0, 0, 1),
        makePlacement("rock", 1, 0, 0, 0)
    }, {{row = 0, column = 1}})

    local accepted, message = harness.controller:loadBoardState(
        state,
        "Red",
        function(succeeded)
            completions[#completions + 1] = succeeded
        end
    )

    Test.truthy(accepted)
    Test.contains(message, "2 objects")
    Test.equal(2, #harness.destroyed)
    Test.equal(taggedObject, harness.destroyed[1])
    Test.equal(modelObject, harness.destroyed[2])
    Test.equal(2, #harness.spawnCalls)
    Test.equal(0, #completions)

    local goodObject = makeSpawnedObject("new-tree")
    local failedObject = makeSpawnedObject("new-rock", {
        addTagError = "tagging failed"
    })
    harness.spawnCalls[1].onSpawned(goodObject)
    harness.spawnCalls[1].onSpawned(goodObject)
    Test.equal(0, #completions)
    harness.spawnCalls[2].onSpawned(failedObject)
    harness.spawnCalls[2].onSpawned(failedObject)

    Test.deepEqual({false}, completions)
    Test.equal(2, #harness.controller:getModel().placements)
    Test.equal(
        "new-tree",
        harness.controller:getModel().placements[1].guid
    )
end)

Test.case("missing saved hex objects respawn and receive their new GUID", function()
    local harness = newHarness()
    local spawnedObject = makeSpawnedObject("restored-guid")
    harness.spawn = function(parameters)
        Test.truthy(parameters.silent)
        parameters.onSpawned(spawnedObject)
        return true
    end

    harness.controller:onLoad({
        placedObjects = {
            makePlacement("tree", 0, 0, 0, 1, "missing-guid")
        }
    })

    local saved = harness.controller:getSaveState()
    Test.equal(1, #harness.spawnCalls)
    Test.equal(1, #saved.placedObjects)
    Test.equal("restored-guid", saved.placedObjects[1].guid)
    Test.equal("LichHexGridObject", spawnedObject.tags[1])
end)

Test.case("failed hex replacement preserves the old object until success", function()
    local harness = newHarness()
    harness.controller:onLoad(nil)
    local oldObject = {getGUID = function() return "old-tree" end}
    local oldPlacement = makePlacement(
        "tree",
        0,
        0,
        0,
        1,
        "old-tree"
    )
    harness.objectsByGuid["old-tree"] = oldObject
    addPlacement(harness, oldPlacement)
    local targetCell = harness.cellsByKey["0:0"]
    harness.pointerCell = harness.cellsByKey["0:1"]
    harness.spawn = function()
        return false
    end

    Test.truthy(harness.menuContext.onObjectChoice(
        harness.templatesByKey.rock,
        targetCell,
        "Red",
        oldPlacement
    ))
    harness.controller:onClicked("Red", false)

    Test.equal(0, #harness.destroyed)
    Test.equal(1, #harness.controller:getModel().placements)
    Test.equal(oldPlacement, harness.controller:getModel().placements[1])

    local acceptedSpawn = nil
    harness.spawn = function(parameters)
        acceptedSpawn = parameters
        return true
    end
    Test.truthy(harness.menuContext.onObjectChoice(
        harness.templatesByKey.rock,
        targetCell,
        "Red",
        oldPlacement
    ))
    harness.controller:onClicked("Red", false)

    Test.equal(0, #harness.destroyed)
    Test.equal(2, #harness.controller:getModel().placements)
    acceptedSpawn.onSpawned(makeSpawnedObject("new-rock"))

    Test.equal(1, #harness.destroyed)
    Test.equal(oldObject, harness.destroyed[1])
    Test.equal(1, #harness.controller:getModel().placements)
    Test.equal(
        "new-rock",
        harness.controller:getModel().placements[1].guid
    )
end)

Test.case("hex object destruction removes only its persisted placement", function()
    local harness = newHarness()
    harness.controller:onLoad(nil)
    local first = makePlacement("tree", 0, 0, 0, 1, "first")
    local second = makePlacement("rock", 1, 0, 0, 0, "second")
    addPlacement(harness, first)
    addPlacement(harness, second)
    HexBoardModel.setSelected(
        harness.controller:getModel(),
        "0:0",
        true
    )

    harness.controller:onObjectDestroy(nil)
    harness.controller:onObjectDestroy({
        getGUID = function() return "unknown" end
    })
    Test.equal(2, #harness.controller:getModel().placements)

    harness.controller:onObjectDestroy({
        getGUID = function() return "first" end
    })
    Test.equal(1, #harness.controller:getModel().placements)
    Test.equal(second, harness.controller:getModel().placements[1])
    Test.truthy(harness.controller:getModel().selectedCells["0:0"])
end)

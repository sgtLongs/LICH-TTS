local Test = require("tests/support/Test")
local HexObjectSpawner = require("src/hex/HexObjectSpawner")

Test.case("hex spawner can read a live GUID-backed template", function()
    local spawnedJson = nil
    local source = {
        getJSON = function()
            return "source-json"
        end
    }
    local spawner = HexObjectSpawner.new({
        runtime = {
            getObject = function(guid)
                Test.equal("dcc277", guid)
                return source
            end,
            spawnObjectJson = function(parameters)
                spawnedJson = parameters.json
            end,
            broadcastToColor = function()
            end
        },
        scheduler = {frames = function()
        end}
    })

    Test.truthy(spawner.spawn({
        board = {positionToWorld = function(position) return position end},
        surfaceY = 0,
        template = {
            label = "Death Fog",
            sourceGuid = "dcc277"
        },
        cell = {row = 0, column = 0, x = 0, z = 0},
        facingCell = {row = 0, column = 1}
    }))
    Test.equal("source-json", spawnedJson)
end)
local Config = require("src/config/HexSpawnConfig")

Test.case("object position offset moves the placed object", function()
    local placedPosition = nil
    local object = {
        getBounds = function()
            return {
                center = {x = 4, y = 9, z = 6},
                size = {x = 2, y = 2, z = 2}
            }
        end,
        getPosition = function()
            return {x = 4, y = 10, z = 6}
        end,
        setLock = function()
        end,
        setLuaScript = function()
        end,
        setPosition = function(position)
            placedPosition = position
        end
    }

    Test.truthy(HexObjectSpawner.place({
        board = {
            positionToWorld = function(position)
                return position
            end
        },
        surfaceY = 2,
        object = object,
        cell = {x = 10, z = 20},
        template = {
            objectPositionOffset = {x = 2, y = 0.5, z = 1}
        },
        localRotationY = 90
    }))

    Test.near(11, placedPosition.x, 0.0001)
    Test.near(4.5, placedPosition.y, 0.0001)
    Test.near(18, placedPosition.z, 0.0001)
end)

Test.case("placing an object clears scripts and locks it", function()
    local script = "unchanged"
    local locked = false
    local object = {
        script_state = "saved",
        getBounds = function()
            return {
                center = {x = 0, y = 2, z = 0},
                size = {x = 1, y = 2, z = 1}
            }
        end,
        getPosition = function()
            return {x = 0, y = 3, z = 0}
        end,
        setPosition = function()
        end,
        setLuaScript = function(value)
            script = value
        end,
        setLock = function(value)
            locked = value
        end
    }

    Test.truthy(HexObjectSpawner.place({
        board = {positionToWorld = function(value) return value end},
        surfaceY = 0,
        object = object,
        cell = {x = 0, z = 0},
        template = {}
    }))
    Test.equal("", script)
    Test.equal("", object.script_state)
    Test.truthy(locked)
end)

Test.case("spawning rejects templates without saved JSON", function()
    local previousBroadcastToColor = broadcastToColor
    local notification = nil

    broadcastToColor = function(message, playerColor)
        notification = {message = message, playerColor = playerColor}
    end

    Test.falsy(HexObjectSpawner.spawn({
        template = {label = "Missing"},
        playerColor = "Red"
    }))
    Test.contains(notification.message, "No saved template")
    Test.equal("Red", notification.playerColor)

    broadcastToColor = previousBroadcastToColor
end)

Test.case("spawn failures are reported without escaping", function()
    local previousBroadcastToColor = broadcastToColor
    local previousSpawnObjectJson = spawnObjectJSON
    local notification = nil

    broadcastToColor = function(message)
        notification = message
    end
    spawnObjectJSON = function()
        error("TTS spawn failure")
    end

    Test.falsy(HexObjectSpawner.spawn({
        board = {positionToWorld = function(value) return value end},
        surfaceY = 0,
        cell = {row = 0, column = 0, x = 0, z = 0},
        facingCell = {row = 0, column = 1},
        template = {label = "Tree", json = "{}"},
        playerColor = "Blue"
    }))
    Test.contains(notification, "Could not spawn the Tree")

    broadcastToColor = previousBroadcastToColor
    spawnObjectJSON = previousSpawnObjectJson
end)

Test.case("spawn applies rotation and every placement correction", function()
    local previousBroadcastToColor = broadcastToColor
    local previousSpawnObjectJson = spawnObjectJSON
    local previousWait = Wait
    local scheduled = {}
    local notifications = {}
    local spawnPosition = nil
    local spawnedCount = 0
    local finalizedCount = 0
    local positionCount = 0
    local currentPosition = {x = 0, y = 5, z = 0}
    local finalRotation = nil
    local object = {
        script_state = "saved",
        getBounds = function()
            return {
                center = {x = currentPosition.x, y = 4, z = currentPosition.z},
                size = {x = 2, y = 2, z = 2}
            }
        end,
        getPosition = function()
            return currentPosition
        end,
        getRotation = function()
            return {x = 10, y = 20, z = 30}
        end,
        isDestroyed = function()
            return false
        end,
        setPosition = function(position)
            positionCount = positionCount + 1
            currentPosition = position
        end,
        setRotation = function(rotation)
            finalRotation = rotation
        end,
        setLuaScript = function()
        end,
        setLock = function()
        end
    }

    Wait = {
        frames = function(callback, frameCount)
            scheduled[#scheduled + 1] = {
                callback = callback,
                frameCount = frameCount
            }
        end
    }
    broadcastToColor = function(message)
        notifications[#notifications + 1] = message
    end
    spawnObjectJSON = function(parameters)
        spawnPosition = parameters.position
        parameters.callback_function(object)
    end

    Test.truthy(HexObjectSpawner.spawn({
        board = {
            positionToWorld = function(position)
                return {x = position.x + 100, y = position.y, z = position.z}
            end
        },
        surfaceY = 2,
        cell = {row = 1, column = -1, x = 10, z = 20},
        facingCell = {row = 0, column = 0},
        localRotationY = 90,
        rotationY = 135,
        template = {
            label = "Crystal",
            json = "{}",
            objectPositionOffset = {x = 2, y = 0.5, z = 1}
        },
        playerColor = "Teal",
        onSpawned = function(spawnedObject)
            Test.equal(object, spawnedObject)
            spawnedCount = spawnedCount + 1
        end,
        onPlacementFinalized = function(spawnedObject)
            Test.equal(object, spawnedObject)
            finalizedCount = finalizedCount + 1
        end
    }))

    Test.near(111, spawnPosition.x, 0.0001)
    Test.near(3.5, spawnPosition.y, 0.0001)
    Test.near(18, spawnPosition.z, 0.0001)
    Test.equal(135, finalRotation.y)
    Test.equal(10, finalRotation.x)
    Test.equal(30, finalRotation.z)
    Test.equal(1, spawnedCount)
    Test.equal(#Config.placementCorrectionFrames, #scheduled)
    Test.equal(0, positionCount)

    for index, scheduledCorrection in ipairs(scheduled) do
        Test.equal(
            Config.placementCorrectionFrames[index],
            scheduledCorrection.frameCount
        )
        scheduledCorrection.callback()
    end

    Test.equal(#Config.placementCorrectionFrames, positionCount)
    Test.equal(1, finalizedCount)
    Test.contains(notifications[1], "Crystal added at hex 1, -1")

    broadcastToColor = previousBroadcastToColor
    spawnObjectJSON = previousSpawnObjectJson
    Wait = previousWait
end)

Test.case("silent spawns omit chat notifications", function()
    local previousBroadcastToColor = broadcastToColor
    local previousSpawnObjectJson = spawnObjectJSON
    local previousWait = Wait
    local notificationCount = 0
    local object = {
        script_state = "",
        getBounds = function()
            return {center = {x = 0, y = 1, z = 0}, size = {x = 1, y = 2, z = 1}}
        end,
        getPosition = function()
            return {x = 0, y = 2, z = 0}
        end,
        getRotation = function()
            return {x = 0, y = 0, z = 0}
        end,
        isDestroyed = function()
            return true
        end,
        setLock = function()
        end,
        setLuaScript = function()
        end,
        setRotation = function()
        end,
        setPosition = function()
            error("Destroyed objects must not be corrected.")
        end
    }

    broadcastToColor = function()
        notificationCount = notificationCount + 1
    end
    Wait = {frames = function(callback) callback() end}
    spawnObjectJSON = function(parameters)
        parameters.callback_function(object)
    end

    Test.truthy(HexObjectSpawner.spawn({
        board = {positionToWorld = function(value) return value end},
        surfaceY = 0,
        cell = {row = 0, column = 0, x = 0, z = 0},
        facingCell = {row = 0, column = 1},
        template = {label = "Tree", json = "{}"},
        silent = true
    }))
    Test.equal(0, notificationCount)

    broadcastToColor = previousBroadcastToColor
    spawnObjectJSON = previousSpawnObjectJson
    Wait = previousWait
end)

Test.case("constructed spawners trace runtime before scheduler effects", function()
    local trace = {}
    local currentPosition = {x = 0, y = 2, z = 0}
    local object = {
        script_state = "saved",
        getBounds = function()
            return {
                center = {x = 0, y = 1, z = 0},
                size = {x = 1, y = 2, z = 1}
            }
        end,
        getPosition = function()
            return currentPosition
        end,
        getRotation = function()
            return {x = 0, y = 0, z = 0}
        end,
        isDestroyed = function()
            return false
        end,
        setLock = function()
        end,
        setLuaScript = function()
        end,
        setRotation = function()
        end,
        setPosition = function(position)
            currentPosition = position
        end
    }
    local runtime = {
        spawnObjectJson = function(parameters)
            trace[#trace + 1] = "runtime.spawn"
            parameters.callback_function(object)
        end,
        broadcastToColor = function(_, playerColor)
            trace[#trace + 1] = "runtime.broadcast:"
                .. playerColor
        end
    }
    local scheduler = {
        frames = function(callback, count)
            trace[#trace + 1] = "scheduler.frames:" .. count
            callback()
        end
    }
    local spawner = HexObjectSpawner.new({
        runtime = runtime,
        scheduler = scheduler,
        config = {
            initialHeightAboveSurface = 1,
            placementCorrectionFrames = {2, 5},
            missingTemplateColor = {},
            failureColor = {},
            successColor = {}
        }
    })

    Test.withGlobals({
        Wait = Test.NIL,
        spawnObjectJSON = Test.NIL,
        broadcastToColor = Test.NIL
    }, function()
        Test.truthy(spawner.spawn({
            board = {
                positionToWorld = function(position)
                    return position
                end
            },
            surfaceY = 0,
            cell = {row = 0, column = 0, x = 0, z = 0},
            facingCell = {row = 0, column = 1},
            template = {label = "Tree", json = "{}"},
            playerColor = "Red"
        }))
    end)

    Test.deepEqual({
        "runtime.spawn",
        "scheduler.frames:2",
        "scheduler.frames:5",
        "runtime.broadcast:Red"
    }, trace)
end)

local Runtime = {}
local defaultRuntime = nil

local function callGlobal(name, ...)
    local callback = _G[name]

    if type(callback) ~= "function" then
        return nil
    end

    return callback(...)
end

function Runtime.new(overrides)
    overrides = overrides or {}
    local runtime = {}

    runtime.getPlayer = overrides.getPlayer or function(playerColor)
        return Player ~= nil and Player[playerColor] or nil
    end
    runtime.getPlayers = overrides.getPlayers or function()
        if Player ~= nil and type(Player.getPlayers) == "function" then
            return Player.getPlayers() or {}
        end

        return {}
    end
    runtime.getSelectAction = overrides.getSelectAction or function()
        return Player ~= nil and Player.Action ~= nil
            and Player.Action.Select or nil
    end
    runtime.getGlobal = overrides.getGlobal or function()
        return Global
    end
    runtime.getGlobalOwner = overrides.getGlobalOwner or runtime.getGlobal
    runtime.setVectorLines = overrides.setVectorLines or function(lines)
        local global = runtime.getGlobal()

        if global ~= nil and type(global.setVectorLines) == "function" then
            return global.setVectorLines(lines)
        end

        return false
    end
    runtime.getObject = overrides.getObject or function(guid)
        return callGlobal("getObjectFromGUID", guid)
    end
    runtime.getObjectFromGUID = overrides.getObjectFromGUID
        or runtime.getObject
    runtime.getAllObjects = overrides.getAllObjects or function()
        return callGlobal("getAllObjects") or {}
    end
    runtime.getObjectsWithTag = overrides.getObjectsWithTag
        or function(tag)
            return callGlobal("getObjectsWithTag", tag) or {}
        end
    runtime.spawnObjectData = overrides.spawnObjectData
        or function(parameters)
            return callGlobal("spawnObjectData", parameters)
        end
    runtime.spawnObjectJson = overrides.spawnObjectJson
        or function(parameters)
            return callGlobal("spawnObjectJSON", parameters)
        end
    runtime.destroyObject = overrides.destroyObject or function(object)
        return callGlobal("destroyObject", object)
    end
    runtime.broadcastToColor = overrides.broadcastToColor
        or function(message, playerColor, color)
            return callGlobal(
                "broadcastToColor",
                message,
                playerColor,
                color
            )
        end
    runtime.printToAll = overrides.printToAll
        or function(message, color)
            return callGlobal("printToAll", message, color)
        end
    runtime.log = overrides.log or function(message)
        return callGlobal("print", message)
    end
    runtime.storeRewindState = overrides.storeRewindState
        or function(callback, includeCurrentState)
            return callGlobal(
                "storeRewindState",
                callback,
                includeCurrentState
            )
        end
    runtime.getGlobalScriptState = overrides.getGlobalScriptState
        or function()
            return Global ~= nil and Global.script_state or nil
        end
    runtime.setGlobalScriptState = overrides.setGlobalScriptState
        or function(value)
            if Global == nil then
                error("The TTS Global object is unavailable.")
            end

            Global.script_state = value
            return Global.script_state == value
        end

    return runtime
end

function Runtime.default()
    if defaultRuntime == nil then
        defaultRuntime = Runtime.new()
    end

    return defaultRuntime
end

function Runtime.setDefault(runtime)
    defaultRuntime = runtime or Runtime.new()
end

return Runtime

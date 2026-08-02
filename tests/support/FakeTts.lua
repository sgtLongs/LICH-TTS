local FakeWait = require("tests/support/FakeWait")

local FakeTts = {}

function FakeTts.new()
    local fixture = {
        attributes = {},
        broadcasts = {},
        objects = {},
        objectsByGuid = {},
        objectsByTag = {},
        players = {},
        wait = FakeWait.new(),
        destroyedObjects = {},
        spawnedData = {},
        spawnedJson = {}
    }

    fixture.ui = {
        setAttribute = function(id, attribute, value)
            fixture.attributes[id .. "." .. attribute] = value
        end
    }
    fixture.playerApi = {
        Action = {Select = "Select"},
        getPlayers = function()
            local result = {}

            for _, player in pairs(fixture.players) do
                result[#result + 1] = player
            end

            return result
        end
    }

    function fixture.addPlayer(color, player)
        player = player or {}
        player.color = player.color or color
        fixture.players[color] = player
        fixture.playerApi[color] = player
        return player
    end

    function fixture.addObject(object, tags)
        fixture.objects[#fixture.objects + 1] = object

        if type(object.getGUID) == "function" then
            fixture.objectsByGuid[object.getGUID()] = object
        end

        for _, tag in ipairs(tags or {}) do
            fixture.objectsByTag[tag] = fixture.objectsByTag[tag] or {}
            fixture.objectsByTag[tag][#fixture.objectsByTag[tag] + 1] = object
        end

        return object
    end

    function fixture.globals()
        return {
            UI = fixture.ui,
            Wait = fixture.wait,
            Player = fixture.playerApi,
            getObjectFromGUID = function(guid)
                return fixture.objectsByGuid[guid]
            end,
            getAllObjects = function()
                return fixture.objects
            end,
            getObjectsWithTag = function(tag)
                return fixture.objectsByTag[tag] or {}
            end,
            destroyObject = function(object)
                fixture.destroyedObjects[#fixture.destroyedObjects + 1] = object
            end,
            spawnObjectData = function(parameters)
                fixture.spawnedData[#fixture.spawnedData + 1] = parameters
                return parameters.result
            end,
            spawnObjectJSON = function(parameters)
                fixture.spawnedJson[#fixture.spawnedJson + 1] = parameters
                return parameters.result
            end,
            broadcastToColor = function(message, playerColor, color)
                fixture.broadcasts[#fixture.broadcasts + 1] = {
                    message = message,
                    playerColor = playerColor,
                    color = color
                }
            end
        }
    end

    return fixture
end

return FakeTts

local Test = require("tests/support/Test")
local HexObjectSpawner = require("src/hex/HexObjectSpawner")

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

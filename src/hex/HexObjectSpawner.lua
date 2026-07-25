local Config = require("src/config/HexSpawnConfig")

local HexObjectSpawner = {}

local function getLocalPosition(surfaceY, cell, heightAboveSurface, offset)
    local positionOffset = offset or {}

    return {
        x = cell.x + (positionOffset.x or 0),
        y = surfaceY
            + (heightAboveSurface or 0)
            + (positionOffset.y or 0),
        z = cell.z + (positionOffset.z or 0)
    }
end

local function placeObject(board, surfaceY, object, cell, offset)
    if object == nil or board == nil then
        return
    end

    local targetSurface = board.positionToWorld(
        getLocalPosition(surfaceY, cell, 0, offset)
    )
    local currentPosition = object.getPosition()
    local bounds = object.getBounds()
    local boundsBottom = bounds.center.y - bounds.size.y * 0.5

    object.setPosition({
        x = targetSurface.x,
        y = currentPosition.y + targetSurface.y - boundsBottom,
        z = targetSurface.z
    })
    object.setLuaScript("")
    object.script_state = ""
    object.setLock(true)
end

function HexObjectSpawner.spawn(parameters)
    local template = parameters.template
    local playerColor = parameters.playerColor

    if type(template.json) ~= "string" or template.json == "" then
        broadcastToColor(
            "No saved template exists for " .. template.label .. ".",
            playerColor,
            Config.missingTemplateColor
        )
        return false
    end

    local spawnPosition = parameters.board.positionToWorld(
        getLocalPosition(
            parameters.surfaceY,
            parameters.cell,
            Config.initialHeightAboveSurface,
            template.positionOffset
        )
    )

    local succeeded = pcall(function()
        spawnObjectJSON({
            json = template.json,
            position = spawnPosition,
            callback_function = function(spawnedObject)
                spawnedObject.setLuaScript("")
                spawnedObject.script_state = ""
                spawnedObject.setLock(true)

                Wait.frames(function()
                    placeObject(
                        parameters.board,
                        parameters.surfaceY,
                        spawnedObject,
                        parameters.cell,
                        template.positionOffset
                    )
                end, 2)

                broadcastToColor(
                    template.label .. " added at hex "
                        .. parameters.cell.row .. ", "
                        .. parameters.cell.column .. ".",
                    playerColor,
                    Config.successColor
                )
            end
        })
    end)

    if not succeeded then
        broadcastToColor(
            "Could not spawn the " .. template.label .. ".",
            playerColor,
            Config.failureColor
        )
        return false
    end

    return true
end

return HexObjectSpawner

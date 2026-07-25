local Config = require("src/config/HexSpawnConfig")

local HexObjectSpawner = {}

local function getRotatedOffset(offset, rotationY)
    local positionOffset = offset or {}
    local radians = math.rad(rotationY or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    local offsetX = positionOffset.x or 0
    local offsetZ = positionOffset.z or 0

    return {
        x = offsetX * cosine + offsetZ * sine,
        y = positionOffset.y or 0,
        z = -offsetX * sine + offsetZ * cosine
    }
end

local function getLocalPosition(
    surfaceY,
    cell,
    heightAboveSurface,
    offset,
    rotationY
)
    local positionOffset = getRotatedOffset(offset, rotationY)

    return {
        x = cell.x + positionOffset.x,
        y = surfaceY
            + (heightAboveSurface or 0)
            + positionOffset.y,
        z = cell.z + positionOffset.z
    }
end

local function placeObject(
    board,
    surfaceY,
    object,
    cell,
    offset,
    localRotationY
)
    if object == nil or board == nil then
        return
    end

    local targetSurface = board.positionToWorld(
        getLocalPosition(surfaceY, cell, 0, offset, localRotationY)
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

local function applyRotation(object, rotationY)
    if rotationY == nil then
        return
    end

    local currentRotation = object.getRotation()

    object.setRotation({
        x = currentRotation.x,
        y = rotationY,
        z = currentRotation.z
    })
end

local function schedulePlacementCorrections(parameters, spawnedObject)
    for _, frameCount in ipairs(Config.placementCorrectionFrames) do
        Wait.frames(function()
            if spawnedObject == nil or spawnedObject.isDestroyed() then
                return
            end

            placeObject(
                parameters.board,
                parameters.surfaceY,
                spawnedObject,
                parameters.cell,
                parameters.template.positionOffset,
                parameters.localRotationY
            )
        end, frameCount)
    end
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
            template.positionOffset,
            parameters.localRotationY
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
                applyRotation(spawnedObject, parameters.rotationY)

                schedulePlacementCorrections(parameters, spawnedObject)

                broadcastToColor(
                    template.label .. " added at hex "
                        .. parameters.cell.row .. ", "
                        .. parameters.cell.column
                        .. " facing hex "
                        .. parameters.facingCell.row .. ", "
                        .. parameters.facingCell.column .. ".",
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

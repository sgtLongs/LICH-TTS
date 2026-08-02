local Config = require("src/config/HexSpawnConfig")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")

local HexObjectSpawner = {}
local defaultSpawner = nil

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

function HexObjectSpawner.new(dependencies)
    dependencies = dependencies or {}

    local config = dependencies.config or Config
    local runtime = dependencies.runtime or Runtime.default()
    local scheduler = dependencies.scheduler or Scheduler.default()
    local spawner = {}

    local function notify(playerColor, message, color, silent)
        if not silent then
            runtime.broadcastToColor(message, playerColor, color)
        end
    end

    local function schedulePlacementCorrections(parameters, spawnedObject)
        for index, frameCount in ipairs(
            config.placementCorrectionFrames
        ) do
            local isFinalCorrection =
                index == #config.placementCorrectionFrames

            scheduler.frames(function()
                if spawnedObject == nil or spawnedObject.isDestroyed() then
                    return
                end

                placeObject(
                    parameters.board,
                    parameters.surfaceY,
                    spawnedObject,
                    parameters.cell,
                    parameters.template.objectPositionOffset,
                    parameters.localRotationY
                )

                if isFinalCorrection
                    and parameters.onPlacementFinalized ~= nil
                then
                    parameters.onPlacementFinalized(spawnedObject)
                end
            end, frameCount)
        end
    end

    function spawner.place(parameters)
        if type(parameters) ~= "table"
            or parameters.object == nil
            or parameters.template == nil
        then
            return false
        end

        placeObject(
            parameters.board,
            parameters.surfaceY,
            parameters.object,
            parameters.cell,
            parameters.template.objectPositionOffset,
            parameters.localRotationY
        )
        return true
    end

    function spawner.spawn(parameters)
        local template = parameters.template
        local playerColor = parameters.playerColor

        if type(template.json) ~= "string" or template.json == "" then
            notify(
                playerColor,
                "No saved template exists for " .. template.label .. ".",
                config.missingTemplateColor,
                parameters.silent
            )
            return false
        end

        local spawnPosition = parameters.board.positionToWorld(
            getLocalPosition(
                parameters.surfaceY,
                parameters.cell,
                config.initialHeightAboveSurface,
                template.objectPositionOffset,
                parameters.localRotationY
            )
        )

        local succeeded = pcall(function()
            runtime.spawnObjectJson({
                json = template.json,
                position = spawnPosition,
                callback_function = function(spawnedObject)
                    spawnedObject.setLuaScript("")
                    spawnedObject.script_state = ""
                    spawnedObject.setLock(true)
                    applyRotation(spawnedObject, parameters.rotationY)

                    if parameters.onSpawned ~= nil then
                        parameters.onSpawned(spawnedObject)
                    end

                    schedulePlacementCorrections(
                        parameters,
                        spawnedObject
                    )

                    notify(
                        playerColor,
                        template.label .. " added at hex "
                            .. parameters.cell.row .. ", "
                            .. parameters.cell.column
                            .. " facing hex "
                            .. parameters.facingCell.row .. ", "
                            .. parameters.facingCell.column .. ".",
                        config.successColor,
                        parameters.silent
                    )
                end
            })
        end)

        if not succeeded then
            notify(
                playerColor,
                "Could not spawn the " .. template.label .. ".",
                config.failureColor,
                parameters.silent
            )
            return false
        end

        return true
    end

    return spawner
end

local function getDefaultSpawner()
    if defaultSpawner == nil then
        defaultSpawner = HexObjectSpawner.new()
    end

    return defaultSpawner
end

function HexObjectSpawner.place(parameters)
    return getDefaultSpawner().place(parameters)
end

function HexObjectSpawner.spawn(parameters)
    return getDefaultSpawner().spawn(parameters)
end

function HexObjectSpawner.setDefault(spawner)
    defaultSpawner = spawner or HexObjectSpawner.new()
end

return HexObjectSpawner

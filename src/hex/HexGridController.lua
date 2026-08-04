local Config = require("src/config/HexGridConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local HexBoardCodec = require("src/hex/HexBoardCodec")
local HexBoardModel = require("src/hex/HexBoardModel")
local HexGeometry = require("src/hex/HexGeometry")
local HexGridBuilder = require("src/hex/HexGridBuilder")
local HexGridMenu = require("src/hex/HexGridMenu")
local HexGridView = require("src/hex/HexGridView")
local HexObjectSpawner = require("src/hex/HexObjectSpawner")
local HexPlacementRules = require("src/hex/HexPlacementRules")
local SpawnDefinitions = require("src/hex/HexSpawnDefinitions")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local SurfaceController = require("src/surfaces/SurfaceController")
local SurfaceDefinitions = require("src/surfaces/SurfaceDefinitions")

local HexGridController = {}
local Controller = {}
Controller.__index = Controller

local publicMethodNames = {
    "configureGrid",
    "getModel",
    "loadSaveState",
    "getSaveState",
    "normalizeBoardState",
    "getBoardState",
    "applyLoadedSelection",
    "getSessionSnapshot",
    "onLoad",
    "onObjectHover",
    "getBoardStateJson",
    "loadBoardState",
    "loadBoardStateJson",
    "onObjectDestroy",
    "onClicked",
    "onObjectClicked",
    "onPlayerAction",
    "onMenuUiClicked",
    "onSurfaceUiClicked",
    "onSpawnSelectorUiClicked",
    "onScriptingButtonDown",
    "onObjectNumberTyped",
    "setEditMode",
    "clearSurfacesForRestart",
    "beginDeathFogPlacement",
    "cancelDeathFogPlacement"
}

local function defaultJson()
    return {
        encodePretty = function(value)
            return JSON.encode_pretty(value)
        end,
        decode = function(value)
            return JSON.decode(value)
        end
    }
end

local function copyMap(source)
    local copy = {}

    for key, value in pairs(source or {}) do
        copy[key] = value
    end

    return copy
end

function HexGridController.new(options)
    options = options or {}

    local config = options.config or Config
    local builder = options.builder or HexGridBuilder
    local cellKey = options.cellKey or builder.cellKey

    if type(cellKey) ~= "function" then
        error("HexGridController requires cellKey.", 2)
    end

    local runtime = options.runtime or Runtime.default()
    local scheduler = options.scheduler or Scheduler.default()
    local spawnDefinitions = options.spawnDefinitions
        or SpawnDefinitions
    local templatesByKey = {}

    for _, template in ipairs(spawnDefinitions) do
        templatesByKey[template.key] = template
    end

    if options.templatesByKey ~= nil then
        templatesByKey = copyMap(options.templatesByKey)
    end

    local surfaceDefinitions = options.surfaceDefinitions
        or SurfaceDefinitions
    local deathFogTemplate = options.deathFogTemplate

    for _, definition in ipairs(surfaceDefinitions) do
        local template = definition.placementTemplate

        if definition.key == "deathFog"
            and deathFogTemplate ~= nil
        then
            template = deathFogTemplate
        end

        if template ~= nil then
            templatesByKey[template.key] = template

            if definition.key == "deathFog" then
                deathFogTemplate = template
            end
        end
    end

    local surfaces = options.surfaces

    if surfaces == nil then
        local surfaceDependencies = {
            definitions = surfaceDefinitions,
            templatesByKey = templatesByKey,
            cellKey = cellKey
        }

        if options.uiAdapter ~= nil then
            surfaceDependencies.uiAdapter = options.uiAdapter
        end

        surfaces = (options.surfaceControllerFactory
            or SurfaceController).new(surfaceDependencies)
    end

    local menu = options.menu

    if menu == nil then
        local menuDependencies = {
            spawnDefinitions = spawnDefinitions,
            getObjectsWithTag = runtime.getObjectsWithTag,
            destroyObject = runtime.destroyObject
        }

        if options.uiAdapter ~= nil then
            menuDependencies.uiAdapter = options.uiAdapter
        end

        menu = (options.menuFactory or HexGridMenu).new(
            menuDependencies
        )
    end

    local objectSpawner = options.objectSpawner

    if objectSpawner == nil then
        objectSpawner = (options.objectSpawnerFactory
            or HexObjectSpawner).new({
                runtime = runtime,
                scheduler = scheduler,
                config = options.spawnConfig
            })
    end

    local controller = setmetatable({
        config = config,
        debugConfig = options.debugConfig or DebugConfig,
        runtime = runtime,
        scheduler = scheduler,
        json = options.json or defaultJson(),
        geometry = options.geometry or HexGeometry,
        builder = builder,
        view = options.view or HexGridView,
        placementRules = options.placementRules or HexPlacementRules,
        modelApi = options.modelApi or HexBoardModel,
        codec = options.codec or HexBoardCodec,
        menu = menu,
        surfaces = surfaces,
        objectSpawner = objectSpawner,
        schemaVersion = options.schemaVersion
            or config.boardStateSchemaVersion,
        boardGuid = options.boardGuid or config.boardGuid,
        cellKey = cellKey,
        spawnDefinitions = spawnDefinitions,
        templatesByKey = templatesByKey,
        model = (options.modelApi or HexBoardModel).new(
            options.initialState
        ),
        board = nil,
        cells = {},
        cellsByKey = {},
        hoveredCells = {},
        menuTargetCell = nil,
        rotationCandidateCells = {},
        pendingSpawn = nil,
        pendingSavedPlacements = {},
        resolvedSurfaceY = 0,
        hoverWaitId = nil,
        recentClickCells = {},
        selectedTemplate = nil,
        editMode = false,
        deathFogSurface = surfaces.getDefinition("deathFog"),
        deathFogTemplate = deathFogTemplate,
        deathFogRequest = nil,
        deathFogCandidateCells = {}
    }, Controller)

    -- TTS subsystem consumers call methods with dot syntax, while domain
    -- tests and Lua callers commonly use colon syntax. Bind both forms to
    -- this instance so an injected controller never loses its receiver.
    for _, methodName in ipairs(publicMethodNames) do
        local boundMethodName = methodName

        controller[boundMethodName] = function(first, ...)
            if first == controller then
                return Controller[boundMethodName](controller, ...)
            end

            return Controller[boundMethodName](
                controller,
                first,
                ...
            )
        end
    end

    return controller
end

function Controller:configureGrid(cells, cellsByKey)
    self.cells = cells or {}
    self.cellsByKey = cellsByKey or {}
    return self
end

function Controller:getModel()
    return self.model
end

function Controller:loadSaveState(savedState)
    local selectedCells = type(savedState) == "table"
        and type(savedState.selectedCells) == "table"
        and savedState.selectedCells or {}
    local pendingPlacements = type(savedState) == "table"
        and type(savedState.placedObjects) == "table"
        and savedState.placedObjects or {}

    self.modelApi.replace(self.model, selectedCells, {})
    return pendingPlacements
end

function Controller:getSaveState()
    local placements = {}
    local selectedCells = {}

    for _, placement in ipairs(self.model.placements) do
        placements[#placements + 1] =
            self.modelApi.copyPlacement(placement)
    end

    for key, selected in pairs(self.model.selectedCells) do
        if selected == true then
            selectedCells[key] = true
        end
    end

    return {
        selectedCells = selectedCells,
        placedObjects = placements
    }
end

function Controller:normalizeBoardState(boardState)
    return self.codec.normalize(boardState, {
        schemaVersion = self.schemaVersion,
        boardGuid = self.boardGuid,
        cellsByKey = self.cellsByKey,
        templatesByKey = self.templatesByKey
    })
end

function Controller:getBoardState()
    return self.codec.serialize(self.model, self.cells, {
        schemaVersion = self.schemaVersion,
        boardGuid = self.boardGuid,
        cellKey = self.cellKey,
        templatesByKey = self.templatesByKey
    })
end

function Controller:applyLoadedSelection(normalizedState)
    self.modelApi.replace(
        self.model,
        normalizedState and normalizedState.selectedCells or {},
        {}
    )
end

function Controller:getSessionSnapshot()
    return {
        board = self.board,
        cells = self.cells,
        cellsByKey = self.cellsByKey,
        hoveredCells = copyMap(self.hoveredCells),
        menuTargetCell = self.menuTargetCell,
        rotationCandidateCells = copyMap(
            self.rotationCandidateCells
        ),
        deathFogCandidateCells = copyMap(
            self.deathFogCandidateCells
        ),
        deathFogRequest = self.deathFogRequest,
        surfaceMenu = self.surfaces.getActiveMenu(),
        pendingSpawn = self.pendingSpawn,
        pendingSavedPlacements = self.pendingSavedPlacements,
        resolvedSurfaceY = self.resolvedSurfaceY,
        hoverWaitId = self.hoverWaitId,
        recentClickCells = copyMap(self.recentClickCells),
        selectedTemplate = self.selectedTemplate,
        editMode = self.editMode
    }
end

local function getPlacementHotkeyHelp(self)
    local choices = {}

    for index, template in ipairs(self.spawnDefinitions) do
        choices[#choices + 1] = tostring(index) .. " "
            .. template.label
    end

    return table.concat(choices, ", ")
end

local function drawGrid(self)
    return self.view.draw(
        self.builder,
        self.board,
        self.cells,
        self.resolvedSurfaceY,
        self.model,
        {
            hoveredCells = self.hoveredCells,
            menuTargetCell = self.menuTargetCell,
            rotationCandidateCells = self.rotationCandidateCells,
            deathFogCandidateCells = self.deathFogCandidateCells
        }
    )
end

local function isAdmin(self, playerColor)
    local player = self.runtime.getPlayer(playerColor)
    return player ~= nil and player.admin == true
end

local function spawnObject(
    self,
    template,
    targetCell,
    facingCell,
    rotationY,
    localRotationY,
    playerColor,
    onSpawned,
    onPlacementFinalized,
    silent
)
    return self.objectSpawner.spawn({
        board = self.board,
        surfaceY = self.resolvedSurfaceY,
        template = template,
        cell = targetCell,
        facingCell = facingCell,
        rotationY = rotationY,
        localRotationY = localRotationY,
        playerColor = playerColor,
        onSpawned = onSpawned,
        onPlacementFinalized = onPlacementFinalized,
        silent = silent
    })
end

local function getAdjacentCells(self, targetCell)
    return self.geometry.getAdjacentCells(
        targetCell,
        self.cellsByKey
    )
end

local function beginRotationSelection(
    self,
    template,
    targetCell,
    playerColor,
    replacementPlacement
)
    local adjacentCells = getAdjacentCells(self, targetCell)

    self.pendingSpawn = self.placementRules.begin(
        template,
        targetCell,
        playerColor,
        adjacentCells,
        replacementPlacement
    )
    self.rotationCandidateCells = {}

    for key, _ in pairs(adjacentCells) do
        self.rotationCandidateCells[key] = true
    end

    drawGrid(self)
    return true
end

local function cancelPendingSpawn(self, playerColor, closeMenu)
    if self.pendingSpawn == nil
        or self.pendingSpawn.playerColor ~= playerColor
    then
        return false
    end

    local label = self.pendingSpawn.template.label
    self.pendingSpawn = nil
    self.rotationCandidateCells = {}

    if closeMenu ~= false then
        self.menu.close()
    else
        drawGrid(self)
    end

    self.runtime.broadcastToColor(
        label .. " spawn canceled.",
        playerColor,
        self.config.rotationCancelColor
    )

    return true
end

local function selectPlacementTemplate(self, index, playerColor)
    if not self.editMode or not isAdmin(self, playerColor) then
        return false
    end

    local hotkeyIndex = tonumber(index)

    if hotkeyIndex == nil
        or hotkeyIndex ~= math.floor(hotkeyIndex)
    then
        return false
    end

    local template = self.spawnDefinitions[hotkeyIndex]

    if template == nil then
        return false
    end

    if self.pendingSpawn ~= nil
        and self.pendingSpawn.playerColor == playerColor
    then
        cancelPendingSpawn(self, playerColor)
    else
        self.menu.close()
    end

    self.selectedTemplate = template
    self.menu.showSpawnSelector(self.selectedTemplate)
    self.runtime.broadcastToColor(
        tostring(hotkeyIndex) .. ": " .. template.label
            .. " selected. Click an empty hex to place it.",
        playerColor,
        self.config.selectedColor
    )

    return true
end

local function getFacingRotations(
    self,
    targetCell,
    facingCell,
    template
)
    local targetWorld = self.board.positionToWorld({
        x = targetCell.x,
        y = self.resolvedSurfaceY,
        z = targetCell.z
    })
    local facingWorld = self.board.positionToWorld({
        x = facingCell.x,
        y = self.resolvedSurfaceY,
        z = facingCell.z
    })
    local rotationOffsetY = template.rotationOffsetY or 0
    local worldRotationY = math.deg(
        math.atan2(
            facingWorld.x - targetWorld.x,
            facingWorld.z - targetWorld.z
        )
    ) + rotationOffsetY
    local localRotationY = math.deg(
        math.atan2(
            facingCell.x - targetCell.x,
            facingCell.z - targetCell.z
        )
    ) + rotationOffsetY

    return (worldRotationY + 360) % 360,
        (localRotationY + 360) % 360
end

local function removePlacement(self, targetPlacement)
    return self.modelApi.removePlacement(
        self.model,
        targetPlacement
    )
end

local function hasPlacement(self, targetPlacement)
    return self.modelApi.hasPlacement(self.model, targetPlacement)
end

local function getPlacementOccupiedCells(self, placement)
    return self.placementRules.getOccupiedCells(
        placement,
        self.templatesByKey
    )
end

local function placementOccupiesCell(self, placement, cell)
    return self.placementRules.occupiesCell(
        placement,
        cell,
        self.templatesByKey
    )
end

local function getPlacementAtCell(self, cell)
    return self.placementRules.findAt(
        self.model.placements,
        cell,
        self.templatesByKey
    )
end

local function getPlacementByGuid(self, guid)
    return self.modelApi.findPlacementByGuid(self.model, guid)
end

local function findPlacementAtCell(self, cell, predicate)
    for _, placement in ipairs(self.model.placements) do
        local template = self.templatesByKey[placement.templateKey]

        if predicate(template)
            and placementOccupiesCell(self, placement, cell)
        then
            return placement
        end
    end

    return nil
end

local function getPlacementObject(self, placement)
    return placement ~= nil
        and type(placement.guid) == "string"
        and self.runtime.getObject(placement.guid) or nil
end

local function moveSourceStoneOnTop(sourceStone, surfaceObject)
    if sourceStone == nil or surfaceObject == nil then
        return false
    end

    return pcall(function()
        local sourcePosition = sourceStone.getPosition()
        local sourceBounds = sourceStone.getBounds()
        local surfaceBounds = surfaceObject.getBounds()
        local sourceBottom = sourceBounds.center.y
            - sourceBounds.size.y * 0.5
        local surfaceTop = surfaceBounds.center.y
            + surfaceBounds.size.y * 0.5

        sourceStone.setPosition({
            x = sourcePosition.x,
            y = sourcePosition.y + surfaceTop - sourceBottom,
            z = sourcePosition.z
        })
    end)
end

local function stackSourceStoneForPlacement(
    self,
    placement,
    placementObject
)
    local template = self.templatesByKey[placement.templateKey]
    local sourcePlacement = nil
    local surfacePlacement = nil
    local sourceObject = nil
    local surfaceObject = nil

    if template ~= nil and template.isSurface == true then
        surfacePlacement = placement
        surfaceObject = placementObject
        sourcePlacement = findPlacementAtCell(
            self,
            placement.cell,
            function(candidate)
                return candidate ~= nil
                    and candidate.isSourceStone == true
            end
        )
    elseif template ~= nil and template.isSourceStone == true then
        sourcePlacement = placement
        sourceObject = placementObject
        surfacePlacement = findPlacementAtCell(
            self,
            placement.cell,
            function(candidate)
                return candidate ~= nil and candidate.isSurface == true
            end
        )
    end

    sourceObject = sourceObject or getPlacementObject(
        self,
        sourcePlacement
    )
    surfaceObject = surfaceObject or getPlacementObject(
        self,
        surfacePlacement
    )

    return moveSourceStoneOnTop(sourceObject, surfaceObject)
end

local function stackRestoredSourceStones(self)
    for _, placement in ipairs(self.model.placements) do
        local template = self.templatesByKey[placement.templateKey]

        if template ~= nil and template.isSourceStone == true then
            stackSourceStoneForPlacement(
                self,
                placement,
                getPlacementObject(self, placement)
            )
        end
    end
end

local function addObjectClickButton(self, object, placement)
    if object == nil or placement == nil or self.board == nil then
        return
    end

    local existingButtons = object.getButtons() or {}

    for index = #existingButtons, 1, -1 do
        if existingButtons[index].click_function
            == self.config.objectButtonClickFunction
        then
            object.removeButton(existingButtons[index].index)
        end
    end

    local bounds = object.getBounds()
    local boundsCenter = bounds.center
    local boundsSize = bounds.size or {}
    local showDebug = self.debugConfig.drawEditObjectButtons == true
    local template = self.templatesByKey[placement.templateKey]
    local clickArea = template ~= nil
        and template.editClickArea or {}

    local function createClickPrism(groupCenter, groupTop)
        for _, surface in ipairs(self.config.objectButtonSurfaces) do
            local area = clickArea[surface.group] or {}
            local areaPosition = area.positionOffset or {}
            local surfacePosition = surface.position or {}
            local rotationOffset = area.rotationOffset or {}
            local positionRotation = math.rad(
                area.positionRotationDegrees or 0
            )
            local positionCosine = math.cos(positionRotation)
            local positionSine = math.sin(positionRotation)
            local rotatedSurfaceX = (surfacePosition.x or 0)
                    * positionCosine
                + (surfacePosition.z or 0) * positionSine
            local rotatedSurfaceZ = -(surfacePosition.x or 0)
                    * positionSine
                + (surfacePosition.z or 0) * positionCosine
            local anchor = surface.group == "top"
                and groupTop or groupCenter
            local distance = area.distance or 0
            local debugColor = {
                surface.debugColor[1],
                surface.debugColor[2],
                surface.debugColor[3],
                self.config.objectButtonOpacity
            }
            local position = {
                x = anchor.x + (areaPosition.x or 0)
                    + rotatedSurfaceX * distance,
                y = anchor.y + (areaPosition.y or 0)
                    + (surfacePosition.y or 0) * distance,
                z = anchor.z + (areaPosition.z or 0)
                    + rotatedSurfaceZ * distance
            }
            local rotation = surface.rotation
            rotation = {
                (rotation[1] or 0) + (rotationOffset.x or 0)
                    + (surface.group == "side"
                        and (area.positionRotationDegrees or 0) or 0),
                (rotation[2] or 0) + (rotationOffset.y or 0),
                (rotation[3] or 0) + (rotationOffset.z or 0)
            }
            local buttonWidth = surface.group == "side"
                and area.height or area.width
            local buttonHeight = surface.group == "side"
                and area.width or area.height

            object.createButton({
                label = showDebug and surface.label .. " - "
                    .. surface.colorName or "",
                click_function = self.config.objectButtonClickFunction,
                function_owner = self.runtime.getGlobalOwner(),
                position = position,
                rotation = rotation,
                width = buttonWidth,
                height = buttonHeight,
                font_size = showDebug
                    and self.config.objectButtonDebugFontSize or 1,
                color = showDebug
                    and debugColor or self.config.invisibleButtonColor,
                font_color = showDebug
                    and self.config.buttonFontColor
                    or self.config.invisibleButtonColor,
                hover_color = showDebug
                    and debugColor or self.config.invisibleButtonColor,
                press_color = showDebug
                    and debugColor or self.config.invisibleButtonColor,
                tooltip = "Select or edit hex"
            })
        end
    end

    local occupiedCells = getPlacementOccupiedCells(self, placement)

    if #occupiedCells > 1 then
        local occupiedWorldCenters = {}
        local centroid = {x = 0, y = 0, z = 0}

        for _, occupiedCell in ipairs(occupiedCells) do
            local cell = self.cellsByKey[
                self.cellKey(
                    occupiedCell.row,
                    occupiedCell.column
                )
            ]

            if cell ~= nil then
                local cellWorldCenter = self.board.positionToWorld({
                    x = cell.x,
                    y = self.resolvedSurfaceY,
                    z = cell.z
                })
                occupiedWorldCenters[#occupiedWorldCenters + 1] =
                    cellWorldCenter
                centroid.x = centroid.x + cellWorldCenter.x
                centroid.y = centroid.y + cellWorldCenter.y
                centroid.z = centroid.z + cellWorldCenter.z
            end
        end

        local centerCount = #occupiedWorldCenters

        if centerCount > 0 then
            centroid.x = centroid.x / centerCount
            centroid.y = centroid.y / centerCount
            centroid.z = centroid.z / centerCount

            local centroidLocal = object.positionToLocal(centroid)
            local objectCenterLocal = object.positionToLocal(boundsCenter)
            local objectTopLocal = object.positionToLocal({
                x = boundsCenter.x,
                y = boundsCenter.y + (boundsSize.y or 0) * 0.5,
                z = boundsCenter.z
            })

            for _, worldCenter in ipairs(occupiedWorldCenters) do
                local cellLocal = object.positionToLocal(worldCenter)
                local offsetX = cellLocal.x - centroidLocal.x
                local offsetZ = cellLocal.z - centroidLocal.z

                createClickPrism(
                    {
                        x = objectCenterLocal.x + offsetX,
                        y = objectCenterLocal.y,
                        z = objectCenterLocal.z + offsetZ
                    },
                    {
                        x = objectTopLocal.x + offsetX,
                        y = objectTopLocal.y,
                        z = objectTopLocal.z + offsetZ
                    }
                )
            end
        end
    else
        createClickPrism(
            object.positionToLocal(boundsCenter),
            object.positionToLocal({
                x = boundsCenter.x,
                y = boundsCenter.y + (boundsSize.y or 0) * 0.5,
                z = boundsCenter.z
            })
        )
    end

    if object.setVectorLines ~= nil then
        object.setVectorLines({})
    end
end

local function getPlayerPointerCell(self, playerColor)
    if self.board == nil then
        return nil
    end

    local player = self.runtime.getPlayer(playerColor)

    if player == nil or player.getPointerPosition == nil then
        return nil
    end

    local localPointer = self.board.positionToLocal(
        player.getPointerPosition()
    )
    return self.builder.findCellAt(self.cells, localPointer)
end

local function getPlacementTargetCell(self, placement, targetCell)
    local cell = targetCell

    if not placementOccupiesCell(self, placement, cell) then
        cell = self.cellsByKey[
            self.cellKey(
                placement.cell.row,
                placement.cell.column
            )
        ]
    end

    return cell
end

local function toggleCellSelection(self, cell, playerColor)
    if cell == nil then
        return false
    end

    local key = self.cellKey(cell.row, cell.column)

    self.menu.close()
    self.surfaces.close()
    local selected = self.modelApi.toggleSelected(self.model, key)
    drawGrid(self)

    self.runtime.broadcastToColor(
        "Hex " .. cell.row .. ", " .. cell.column
            .. (selected and " selected." or " cleared."),
        playerColor,
        self.config.selectedColor
    )

    return true
end

local function openPlacementMenu(
    self,
    placement,
    playerColor,
    targetCell
)
    if placement == nil or not isAdmin(self, playerColor) then
        return false
    end

    local template = self.templatesByKey[placement.templateKey]

    if template ~= nil and template.isSurface == true then
        return false
    end

    local player = self.runtime.getPlayer(playerColor)
    local cell = getPlacementTargetCell(
        self,
        placement,
        targetCell
    )

    if player == nil or cell == nil then
        return false
    end

    self.modelApi.setSelected(
        self.model,
        self.cellKey(cell.row, cell.column),
        true
    )
    self.menu.open(playerColor, player, cell, placement)
    return true
end

local function deletePlacement(self, placement, playerColor)
    if not hasPlacement(self, placement) then
        self.menu.close()
        return false
    end

    local template = self.templatesByKey[placement.templateKey]
    local object = type(placement.guid) == "string"
        and self.runtime.getObject(placement.guid) or nil

    removePlacement(self, placement)
    self.menu.close()

    if object ~= nil then
        self.runtime.destroyObject(object)
    end

    self.runtime.broadcastToColor(
        (template ~= nil and template.label or "Object")
            .. " deleted from hex " .. placement.cell.row
            .. ", " .. placement.cell.column .. ".",
        playerColor,
        self.config.rotationCancelColor
    )

    return true
end

local function spawnPlacement(
    self,
    placement,
    playerColor,
    silent,
    onCompleted
)
    local completionReported = false

    local function reportCompletion(succeeded)
        if completionReported then
            return
        end

        completionReported = true

        if onCompleted ~= nil then
            pcall(onCompleted, succeeded)
        end
    end

    local template = self.templatesByKey[placement.templateKey]
    local targetCell = self.cellsByKey[
        self.cellKey(
            placement.cell.row,
            placement.cell.column
        )
    ]
    local facingCell = self.cellsByKey[
        self.cellKey(
            placement.facingCell.row,
            placement.facingCell.column
        )
    ]

    local facingKey = facingCell ~= nil
        and self.cellKey(
            facingCell.row,
            facingCell.column
        ) or nil

    if template == nil
        or targetCell == nil
        or facingCell == nil
        or getAdjacentCells(self, targetCell)[facingKey] == nil
    then
        reportCompletion(false)
        return false
    end

    local rotationY, localRotationY = getFacingRotations(
        self,
        targetCell,
        facingCell,
        template
    )

    self.modelApi.addPlacement(self.model, placement)

    local accepted = spawnObject(
        self,
        template,
        targetCell,
        facingCell,
        rotationY,
        localRotationY,
        playerColor,
        function(spawnedObject)
            if not hasPlacement(self, placement) then
                self.runtime.destroyObject(spawnedObject)
                reportCompletion(false)
                return
            end

            local completedSuccessfully = pcall(function()
                placement.guid = spawnedObject.getGUID()
                spawnedObject.addTag(self.config.placedObjectTag)
            end)

            reportCompletion(completedSuccessfully)
        end,
        function(spawnedObject)
            if template.addEditButtons ~= false then
                addObjectClickButton(self, spawnedObject, placement)
            end

            stackSourceStoneForPlacement(
                self,
                placement,
                spawnedObject
            )
        end,
        silent
    )

    if not accepted then
        removePlacement(self, placement)
        reportCompletion(false)
    end

    return accepted
end

local function completePendingSpawn(self, facingCell)
    local spawn = self.pendingSpawn
    local replacementPlacement = spawn.replacementPlacement

    self.pendingSpawn = nil
    self.rotationCandidateCells = {}
    self.menu.close()

    return spawnPlacement(
        self,
        self.placementRules.complete(spawn, facingCell),
        spawn.playerColor,
        false,
        function(succeeded)
            if succeeded and replacementPlacement ~= nil
                and hasPlacement(self, replacementPlacement)
            then
                local replacedObject =
                    type(replacementPlacement.guid) == "string"
                    and self.runtime.getObject(
                        replacementPlacement.guid
                    ) or nil

                removePlacement(self, replacementPlacement)

                if replacedObject ~= nil then
                    self.runtime.destroyObject(replacedObject)
                end
            end
        end
    )
end

local function updateHoveredCells(self)
    if self.board == nil then
        return
    end

    local nextHoveredCells = {}

    for _, player in ipairs(self.runtime.getPlayers()) do
        local localPointer = self.board.positionToLocal(
            player.getPointerPosition()
        )
        local cell = self.builder.findCellAt(
            self.cells,
            localPointer
        )

        if cell ~= nil then
            nextHoveredCells[
                self.cellKey(cell.row, cell.column)
            ] = true
        end
    end

    local changed = false

    for key, _ in pairs(self.hoveredCells) do
        if not nextHoveredCells[key] then
            changed = true
            break
        end
    end

    if not changed then
        for key, _ in pairs(nextHoveredCells) do
            if not self.hoveredCells[key] then
                changed = true
                break
            end
        end
    end

    if changed then
        self.hoveredCells = nextHoveredCells
        drawGrid(self)
    end
end

local function finishDeathFogPlacement(self, succeeded)
    local request = self.deathFogRequest

    if request == nil then
        return
    end

    self.deathFogRequest = nil
    self.deathFogCandidateCells = {}
    drawGrid(self)

    if request.onCompleted ~= nil then
        pcall(request.onCompleted, succeeded == true)
    end
end

local function refreshDeathFogCandidates(self)
    if self.deathFogRequest == nil
        or self.board == nil
        or #self.cells == 0
    then
        return
    end

    self.deathFogCandidateCells = self.surfaces.getCandidates(
        self.deathFogSurface,
        self.cells,
        self.model.placements,
        true
    )

    if next(self.deathFogCandidateCells) == nil then
        self.runtime.broadcastToColor(
            "No hex remains available for death fog.",
            self.deathFogRequest.playerColor,
            self.config.selectedColor
        )
        finishDeathFogPlacement(self, true)
    else
        drawGrid(self)
    end
end

function Controller:clearSurfacesForRestart()
    local succeeded = true
    local surfacePlacements = {}

    self.surfaces.close()
    finishDeathFogPlacement(self, false)

    for _, placement in ipairs(self.model.placements) do
        local template = self.templatesByKey[placement.templateKey]

        if template ~= nil and template.isSurface == true then
            surfacePlacements[#surfacePlacements + 1] = placement
        end
    end

    for _, placement in ipairs(surfacePlacements) do
        local object = getPlacementObject(self, placement)
        removePlacement(self, placement)

        if object ~= nil then
            local destroyed, destroyError = pcall(
                self.runtime.destroyObject,
                object
            )

            if not destroyed then
                succeeded = false
                self.runtime.log(
                    "HexGrid: could not remove a surface during restart: "
                        .. tostring(destroyError)
                )
            end
        end
    end

    if self.board ~= nil then
        for _, placement in ipairs(self.model.placements) do
            local template = self.templatesByKey[placement.templateKey]
            local object = getPlacementObject(self, placement)
            local targetCell = self.cellsByKey[
                self.cellKey(
                    placement.cell.row,
                    placement.cell.column
                )
            ]
            local facingCell = self.cellsByKey[
                self.cellKey(
                    placement.facingCell.row,
                    placement.facingCell.column
                )
            ]

            if template ~= nil
                and template.isSourceStone == true
                and object ~= nil
                and targetCell ~= nil
                and facingCell ~= nil
            then
                local _, localRotationY = getFacingRotations(
                    self,
                    targetCell,
                    facingCell,
                    template
                )

                self.objectSpawner.place({
                    board = self.board,
                    surfaceY = self.resolvedSurfaceY,
                    object = object,
                    cell = targetCell,
                    template = template,
                    localRotationY = localRotationY
                })
            end
        end
    end

    self.deathFogCandidateCells = {}
    drawGrid(self)
    return succeeded
end

local function getDeathFogFacingCell(self, targetCell)
    local adjacentCells = getAdjacentCells(self, targetCell)

    for _, cell in ipairs(self.cells) do
        local key = self.cellKey(cell.row, cell.column)

        if adjacentCells[key] ~= nil then
            return cell
        end
    end

    return nil
end

local function removeReplacedSurfaces(self, replacedPlacements)
    for _, replacedPlacement in ipairs(replacedPlacements or {}) do
        if hasPlacement(self, replacedPlacement) then
            local replacedObject = getPlacementObject(
                self,
                replacedPlacement
            )

            removePlacement(self, replacedPlacement)

            if replacedObject ~= nil then
                self.runtime.destroyObject(replacedObject)
            end
        end
    end
end

local function placeSurface(
    self,
    surfaceDefinition,
    targetCell,
    playerColor,
    onCompleted
)
    local facingCell = getDeathFogFacingCell(self, targetCell)

    if surfaceDefinition == nil
        or facingCell == nil
        or not self.surfaces.canPlace(
            surfaceDefinition,
            targetCell,
            self.model.placements
        )
    then
        return false
    end

    local template = surfaceDefinition.placementTemplate ~= nil
        and self.templatesByKey[
            surfaceDefinition.placementTemplate.key
        ] or nil

    if template == nil then
        return false
    end

    local replacedPlacements = self.surfaces.getReplacedPlacements(
        targetCell,
        self.model.placements
    )
    local placement = {
        templateKey = template.key,
        cell = self.modelApi.copyCell(targetCell),
        facingCell = self.modelApi.copyCell(facingCell)
    }

    return spawnPlacement(
        self,
        placement,
        playerColor,
        false,
        function(succeeded)
            if succeeded then
                removeReplacedSurfaces(self, replacedPlacements)
                refreshDeathFogCandidates(self)
            elseif hasPlacement(self, placement) then
                removePlacement(self, placement)
            end

            if onCompleted ~= nil then
                pcall(onCompleted, succeeded == true)
            end
        end
    )
end

local function placeDeathFog(self, targetCell)
    local request = self.deathFogRequest

    if request == nil then
        return false
    end

    return placeSurface(
        self,
        self.deathFogSurface,
        targetCell,
        request.playerColor,
        function(succeeded)
            if succeeded then
                finishDeathFogPlacement(self, true)
            end
        end
    )
end

local function restoreSavedPlacements(self)
    self.model.placements = {}

    for index, savedPlacement in ipairs(
        self.pendingSavedPlacements
    ) do
        local templateKey = savedPlacement.templateKey
            or savedPlacement.type
        local cell = savedPlacement.cell or savedPlacement.hex
        local facingCell = savedPlacement.facingCell
            or savedPlacement.facing
        local guid = savedPlacement.guid
        local existingObject = type(guid) == "string"
            and self.runtime.getObject(guid) or nil
        local row = type(cell) == "table"
            and tonumber(cell.row) or nil
        local column = type(cell) == "table"
            and tonumber(cell.column) or nil
        local facingRow = type(facingCell) == "table"
            and tonumber(facingCell.row) or nil
        local facingColumn = type(facingCell) == "table"
            and tonumber(facingCell.column) or nil
        local targetCell = row ~= nil and column ~= nil
            and self.cellsByKey[self.cellKey(row, column)] or nil
        local targetFacingCell = facingRow ~= nil
            and facingColumn ~= nil
            and self.cellsByKey[
                self.cellKey(facingRow, facingColumn)
            ] or nil
        local facingKey = targetFacingCell ~= nil
            and self.cellKey(
                targetFacingCell.row,
                targetFacingCell.column
            ) or nil

        if self.templatesByKey[templateKey] ~= nil
            and targetCell ~= nil
            and targetFacingCell ~= nil
            and getAdjacentCells(self, targetCell)[facingKey] ~= nil
        then
            local placement = {
                templateKey = templateKey,
                cell = self.modelApi.copyCell(targetCell),
                facingCell = self.modelApi.copyCell(
                    targetFacingCell
                ),
                guid = guid
            }

            if existingObject ~= nil then
                local _, localRotationY = getFacingRotations(
                    self,
                    targetCell,
                    targetFacingCell,
                    self.templatesByKey[templateKey]
                )

                self.objectSpawner.place({
                    board = self.board,
                    surfaceY = self.resolvedSurfaceY,
                    object = existingObject,
                    cell = targetCell,
                    template = self.templatesByKey[templateKey],
                    localRotationY = localRotationY
                })
                existingObject.addTag(self.config.placedObjectTag)
                addObjectClickButton(self, existingObject, placement)
                self.modelApi.addPlacement(self.model, placement)
            elseif not spawnPlacement(
                self,
                placement,
                nil,
                true
            ) then
                self.runtime.log(
                    "HexGrid: could not restore saved object "
                        .. tostring(index) .. "."
                )
            end
        else
            self.runtime.log(
                "HexGrid: ignored invalid saved object "
                    .. tostring(index) .. "."
            )
        end
    end

    self.pendingSavedPlacements = {}
    stackRestoredSourceStones(self)
end

local function buildGrid(self)
    self.board = self.runtime.getObject(self.boardGuid)

    if self.board == nil then
        self.runtime.log(
            "HexGrid: could not find board GUID " .. self.boardGuid
        )
        return
    end

    local buildResult = self.builder.build(self.board, {
        functionOwner = self.runtime.getGlobalOwner()
    })
    self.cells = buildResult.cells
    self.cellsByKey = {}

    for _, cell in ipairs(self.cells) do
        self.cellsByKey[
            self.cellKey(cell.row, cell.column)
        ] = cell
    end

    self.resolvedSurfaceY = buildResult.surfaceY
    self.menuTargetCell = nil
    self.pendingSpawn = nil
    self.rotationCandidateCells = {}

    drawGrid(self)

    self.menu.initialize({
        board = self.board,
        isAdmin = function(playerColor)
            return isAdmin(self, playerColor)
        end,
        onObjectChoice = function(
            template,
            targetCell,
            playerColor,
            replacementPlacement
        )
            return beginRotationSelection(
                self,
                template,
                targetCell,
                playerColor,
                replacementPlacement
            )
        end,
        onDeleteObject = function(placement, playerColor)
            return deletePlacement(self, placement, playerColor)
        end,
        onTargetChanged = function(cell)
            self.menuTargetCell = cell
            drawGrid(self)
        end,
        onCancelRotation = function(playerColor)
            cancelPendingSpawn(self, playerColor, false)
        end
    })
    self.surfaces.initialize({
        getPlacements = function()
            return self.model.placements
        end,
        onSurfaceChoice = function(
            definition,
            targetCell,
            playerColor
        )
            return placeSurface(
                self,
                definition,
                targetCell,
                playerColor
            )
        end
    })

    if self.editMode then
        self.menu.showSpawnSelector(self.selectedTemplate)
    end

    restoreSavedPlacements(self)
    refreshDeathFogCandidates(self)

    if self.hoverWaitId ~= nil then
        self.scheduler.stop(self.hoverWaitId)
    end

    self.hoverWaitId = self.scheduler.time(
        function()
            updateHoveredCells(self)
        end,
        self.config.hoverPollInterval,
        -1
    )

    self.runtime.log(
        "HexGrid: drew " .. #self.cells .. " hexes on "
            .. self.boardGuid .. " at local surface Y "
            .. string.format("%.3f", self.resolvedSurfaceY)
    )
end

function Controller:onLoad(savedState)
    self.selectedTemplate = nil
    self.hoveredCells = {}
    self.recentClickCells = {}
    self.rotationCandidateCells = {}
    self.pendingSpawn = nil
    self.deathFogRequest = nil
    self.deathFogCandidateCells = {}
    self.surfaces.close()
    self.pendingSavedPlacements = self:loadSaveState(savedState)

    self.scheduler.frames(function()
        buildGrid(self)
    end, 2)
end

function Controller:onObjectHover()
    return updateHoveredCells(self)
end

function Controller:getBoardStateJson()
    return self.json.encodePretty(self:getBoardState())
end

function Controller:loadBoardState(
    boardState,
    playerColor,
    onCompleted
)
    if self.board == nil or #self.cells == 0 then
        return false, "The hex board is not ready yet."
    end

    local normalizedState, validationError =
        self:normalizeBoardState(boardState)

    if normalizedState == nil then
        return false, validationError
    end

    if self.pendingSpawn ~= nil then
        self.pendingSpawn = nil
        self.rotationCandidateCells = {}
    end

    self.menu.close()
    self.surfaces.close()

    local objectsToDestroy = {}
    local guidsToDestroy = {}

    for _, object in ipairs(
        self.runtime.getObjectsWithTag(
            self.config.placedObjectTag
        )
    ) do
        local guid = object.getGUID()
        objectsToDestroy[#objectsToDestroy + 1] = object
        guidsToDestroy[guid] = true
    end

    for _, placement in ipairs(self.model.placements) do
        if type(placement.guid) == "string"
            and not guidsToDestroy[placement.guid]
        then
            local object = self.runtime.getObject(placement.guid)

            if object ~= nil then
                objectsToDestroy[#objectsToDestroy + 1] = object
                guidsToDestroy[placement.guid] = true
            end
        end
    end

    self:applyLoadedSelection(normalizedState)

    for _, object in ipairs(objectsToDestroy) do
        self.runtime.destroyObject(object)
    end

    local spawnedCount = 0
    local completedSpawnCount = 0
    local successfulSpawnCount = 0
    local spawningFinished = false
    local completionReported = false

    local function reportLoadCompletionIfReady()
        if completionReported
            or not spawningFinished
            or completedSpawnCount < #normalizedState.placements
        then
            return
        end

        completionReported = true

        if onCompleted ~= nil then
            pcall(
                onCompleted,
                successfulSpawnCount
                    == #normalizedState.placements
            )
        end
    end

    local function onPlacementCompleted(succeeded)
        completedSpawnCount = completedSpawnCount + 1

        if succeeded then
            successfulSpawnCount = successfulSpawnCount + 1
        end

        reportLoadCompletionIfReady()
    end

    for _, placement in ipairs(normalizedState.placements) do
        if spawnPlacement(
            self,
            placement,
            playerColor,
            true,
            onPlacementCompleted
        ) then
            spawnedCount = spawnedCount + 1
        end
    end

    drawGrid(self)
    refreshDeathFogCandidates(self)
    spawningFinished = true
    reportLoadCompletionIfReady()

    return true,
        "Board setup loaded: "
            .. normalizedState.selectedHexCount
            .. " selected hexes and "
            .. spawnedCount .. " objects."
end

function Controller:loadBoardStateJson(
    boardStateJson,
    playerColor,
    onCompleted
)
    local decodedSuccessfully, boardState = pcall(
        self.json.decode,
        boardStateJson
    )

    if not decodedSuccessfully then
        return false, "The board-state JSON is not valid JSON."
    end

    return self:loadBoardState(
        boardState,
        playerColor,
        onCompleted
    )
end

function Controller:onObjectDestroy(object)
    if object == nil then
        return
    end

    local guid = object.getGUID()
    local placement = getPlacementByGuid(self, guid)

    if placement ~= nil then
        self.modelApi.removePlacement(self.model, placement)
        refreshDeathFogCandidates(self)
    end
end

local function handlePointerClick(self, playerColor, altClick)
    if self.board == nil then
        return false
    end

    local player = self.runtime.getPlayer(playerColor)

    if player == nil then
        return false
    end

    local cell = getPlayerPointerCell(self, playerColor)
    local key = cell ~= nil
        and self.cellKey(cell.row, cell.column) or nil

    if key ~= nil
        and self.recentClickCells[playerColor] == key
    then
        return true
    end

    if key ~= nil then
        self.recentClickCells[playerColor] = key

        self.scheduler.frames(function()
            if self.recentClickCells[playerColor] == key then
                self.recentClickCells[playerColor] = nil
            end
        end, 2)
    end

    if self.deathFogRequest ~= nil then
        if playerColor ~= self.deathFogRequest.playerColor then
            return true
        end

        if not altClick
            and cell ~= nil
            and self.deathFogCandidateCells[key] ~= nil
        then
            placeDeathFog(self, cell)
        else
            self.runtime.broadcastToColor(
                "Choose a highlighted hex in the outermost available ring.",
                playerColor,
                self.config.rotationCancelColor
            )
        end

        return true
    end

    if self.pendingSpawn ~= nil then
        if self.pendingSpawn.playerColor ~= playerColor then
            return true
        end

        local facingCell = key ~= nil
            and self.pendingSpawn.adjacentCells[key] or nil

        if not altClick and facingCell ~= nil then
            completePendingSpawn(self, facingCell)
        else
            cancelPendingSpawn(self, playerColor)
        end

        return true
    end

    if cell == nil or altClick then
        return false
    end

    local placement = getPlacementAtCell(self, cell)

    if placement ~= nil then
        if self.editMode and isAdmin(self, playerColor) then
            openPlacementMenu(self, placement, playerColor, cell)
        else
            toggleCellSelection(self, cell, playerColor)
            self.surfaces.open(playerColor, cell)
        end

        return true
    end

    if isAdmin(self, playerColor) and self.editMode then
        if self.selectedTemplate == nil then
            self.menu.showSpawnSelector(nil)
            self.runtime.broadcastToColor(
                "Choose an object with a number key first: "
                    .. getPlacementHotkeyHelp(self) .. ".",
                playerColor,
                self.config.rotationCancelColor
            )
            return true
        end

        beginRotationSelection(
            self,
            self.selectedTemplate,
            cell,
            playerColor,
            nil
        )
        self.runtime.broadcastToColor(
            "Click a highlighted adjacent hex to choose which way "
                .. self.selectedTemplate.label .. " faces.",
            playerColor,
            self.config.rotationCandidateColor
        )
        return true
    end

    local handled = toggleCellSelection(self, cell, playerColor)
    self.surfaces.open(playerColor, cell)
    return handled
end

function Controller:onClicked(playerColor, altClick)
    handlePointerClick(self, playerColor, altClick)
end

function Controller:onObjectClicked(object, playerColor, altClick)
    if object == nil or altClick then
        return
    end

    if getPlacementByGuid(self, object.getGUID()) == nil then
        return
    end

    handlePointerClick(self, playerColor, false)
end

function Controller:onPlayerAction(player, action, targets)
    local target = type(targets) == "table"
        and #targets == 1 and targets[1] or nil
    local targetGuid = target ~= nil and target.getGUID() or nil
    local targetsHex = targetGuid == self.boardGuid
        or getPlacementByGuid(self, targetGuid) ~= nil
    local selectAction = self.runtime.getSelectAction()

    if self.pendingSpawn ~= nil
        and action == selectAction
        and player.color == self.pendingSpawn.playerColor
        and not targetsHex
    then
        cancelPendingSpawn(self, player.color)
        return true
    end

    if self.board == nil
        or action ~= selectAction
        or not targetsHex
    then
        return true
    end

    if handlePointerClick(self, player.color, false) then
        return false
    end

    return true
end

function Controller:onMenuUiClicked(playerColor, action)
    self.menu.handleAction(playerColor, action)
end

function Controller:onSurfaceUiClicked(playerColor, action)
    return self.surfaces.handleAction(playerColor, action)
end

function Controller:onSpawnSelectorUiClicked(playerColor, action)
    return selectPlacementTemplate(self, action, playerColor)
end

function Controller:onScriptingButtonDown(index, playerColor)
    return selectPlacementTemplate(self, index, playerColor)
end

function Controller:onObjectNumberTyped(object, playerColor, number)
    if object == nil or self.board == nil then
        return false
    end

    local guid = object.getGUID()

    if guid ~= self.boardGuid
        and getPlacementByGuid(self, guid) == nil
    then
        return false
    end

    return selectPlacementTemplate(self, number, playerColor)
end

function Controller:setEditMode(enabled, playerColor)
    self.editMode = enabled == true
    self.surfaces.close()

    if not self.editMode then
        self.pendingSpawn = nil
        self.rotationCandidateCells = {}
        self.selectedTemplate = nil
        self.menu.close()
        self.menu.hideSpawnSelector()

        if self.board ~= nil then
            drawGrid(self)
        end
    else
        self.menu.showSpawnSelector(self.selectedTemplate)

        if playerColor ~= nil and isAdmin(self, playerColor) then
            self.runtime.broadcastToColor(
                "Edit mode object keys: "
                    .. getPlacementHotkeyHelp(self)
                    .. ". Select one, then click an empty hex.",
                playerColor,
                self.config.selectedColor
            )
        end
    end
end

function Controller:beginDeathFogPlacement(playerColor, onCompleted)
    if type(playerColor) ~= "string"
        or self.deathFogSurface == nil
        or self.deathFogTemplate == nil
    then
        return false
    end

    self.pendingSpawn = nil
    self.rotationCandidateCells = {}
    self.menu.close()
    self.surfaces.close()
    self.deathFogRequest = {
        playerColor = playerColor,
        onCompleted = onCompleted
    }
    self.deathFogCandidateCells = {}
    refreshDeathFogCandidates(self)

    if self.deathFogRequest ~= nil then
        self.runtime.broadcastToColor(
            "Place death fog on a highlighted hex in the outermost "
                .. "available ring.",
            playerColor,
            self.config.deathFogCandidateColor
        )
    end

    return true
end

function Controller:cancelDeathFogPlacement(playerColor)
    if self.deathFogRequest == nil
        or (playerColor ~= nil
            and self.deathFogRequest.playerColor ~= playerColor)
    then
        return false
    end

    self.deathFogRequest = nil
    self.deathFogCandidateCells = {}

    if self.board ~= nil then
        drawGrid(self)
    end

    return true
end

return HexGridController

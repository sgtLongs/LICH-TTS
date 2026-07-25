local Config = require("src/config/HexGridConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local HexBoardState = require("src/hex/HexBoardState")
local HexGeometry = require("src/hex/HexGeometry")
local HexGridBuilder = require("src/hex/HexGridBuilder")
local HexGridMenu = require("src/hex/HexGridMenu")
local HexObjectSpawner = require("src/hex/HexObjectSpawner")
local SettingsConfig = require("src/config/SettingsConfig")
local SpawnDefinitions = require("src/hex/HexSpawnDefinitions")

local HexGrid = {}
local board = nil
local cells = {}
local cellsByKey = {}
local selectedCells = {}
local hoveredCells = {}
local menuTargetCell = nil
local rotationCandidateCells = {}
local pendingSpawn = nil
local placedObjects = {}
local pendingSavedPlacements = {}
local resolvedSurfaceY = 0
local hoverWaitId = nil
local recentClickCells = {}
local templatesByKey = {}
local editMode = false

for _, template in ipairs(SpawnDefinitions) do
    templatesByKey[template.key] = template
end

local function drawGrid()
    HexGridBuilder.draw(board, cells, resolvedSurfaceY, {
        selectedCells = selectedCells,
        hoveredCells = hoveredCells,
        menuTargetCell = menuTargetCell,
        rotationCandidateCells = rotationCandidateCells
    })
end

local function isAdmin(playerColor)
    local player = Player[playerColor]
    return player ~= nil and player.admin == true
end

local function spawnObject(
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
    return HexObjectSpawner.spawn({
        board = board,
        surfaceY = resolvedSurfaceY,
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

local function getAdjacentCells(targetCell)
    return HexGeometry.getAdjacentCells(targetCell, cellsByKey)
end

local function beginRotationSelection(
    template,
    targetCell,
    playerColor,
    replacementPlacement
)
    local adjacentCells = getAdjacentCells(targetCell)

    pendingSpawn = {
        template = template,
        targetCell = targetCell,
        playerColor = playerColor,
        adjacentCells = adjacentCells,
        replacementPlacement = replacementPlacement
    }
    rotationCandidateCells = {}

    for key, _ in pairs(adjacentCells) do
        rotationCandidateCells[key] = true
    end

    drawGrid()
    return true
end

local function cancelPendingSpawn(playerColor, closeMenu)
    if pendingSpawn == nil
        or pendingSpawn.playerColor ~= playerColor
    then
        return false
    end

    local label = pendingSpawn.template.label
    pendingSpawn = nil
    rotationCandidateCells = {}

    if closeMenu ~= false then
        HexGridMenu.close()
    else
        drawGrid()
    end

    broadcastToColor(
        label .. " spawn canceled.",
        playerColor,
        Config.rotationCancelColor
    )

    return true
end

local function getFacingRotations(targetCell, facingCell, template)
    local targetWorld = board.positionToWorld({
        x = targetCell.x,
        y = resolvedSurfaceY,
        z = targetCell.z
    })
    local facingWorld = board.positionToWorld({
        x = facingCell.x,
        y = resolvedSurfaceY,
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

local function copyCell(cell)
    return {
        row = cell.row,
        column = cell.column
    }
end

local function removePlacement(targetPlacement)
    for index = #placedObjects, 1, -1 do
        if placedObjects[index] == targetPlacement then
            table.remove(placedObjects, index)
            return
        end
    end
end

local function hasPlacement(targetPlacement)
    for _, placement in ipairs(placedObjects) do
        if placement == targetPlacement then
            return true
        end
    end

    return false
end

local function getPlacementOccupiedCells(placement)
    local occupiedCells = {placement.cell}
    local template = templatesByKey[placement.templateKey]

    if template ~= nil
        and template.occupiesFacingCell == true
        and placement.facingCell ~= nil
    then
        occupiedCells[#occupiedCells + 1] = placement.facingCell
    end

    return occupiedCells
end

local function placementOccupiesCell(placement, cell)
    if cell == nil then
        return false
    end

    for _, occupiedCell in ipairs(
        getPlacementOccupiedCells(placement)
    ) do
        if occupiedCell.row == cell.row
            and occupiedCell.column == cell.column
        then
            return true
        end
    end

    return false
end

local function getPlacementAtCell(cell)
    if cell == nil then
        return nil
    end

    for _, placement in ipairs(placedObjects) do
        if placementOccupiesCell(placement, cell) then
            return placement
        end
    end

    return nil
end

local function getPlacementByGuid(guid)
    if type(guid) ~= "string" then
        return nil
    end

    for _, placement in ipairs(placedObjects) do
        if placement.guid == guid then
            return placement
        end
    end

    return nil
end

local function addObjectClickButton(object, placement)
    if object == nil or placement == nil or board == nil then
        return
    end

    local existingButtons = object.getButtons() or {}

    for index = #existingButtons, 1, -1 do
        if existingButtons[index].click_function
            == Config.objectButtonClickFunction
        then
            object.removeButton(existingButtons[index].index)
        end
    end

    local boundsCenter = object.getBounds().center
    local showDebug = DebugConfig.drawEditObjectButtons == true
    local template = templatesByKey[placement.templateKey]
    local clickArea = template ~= nil
        and template.editClickArea or {}
    local clickAreaOffset = clickArea.positionOffset or {}

    for groupIndex, occupiedCell in ipairs(
        getPlacementOccupiedCells(placement)
    ) do
        local cell = cellsByKey[
            HexGridBuilder.cellKey(
                occupiedCell.row,
                occupiedCell.column
            )
        ]

        if cell ~= nil then
            local cellWorldCenter = board.positionToWorld({
                x = cell.x,
                y = resolvedSurfaceY,
                z = cell.z
            })
            local groupCenter = object.positionToLocal({
                x = cellWorldCenter.x,
                y = boundsCenter.y,
                z = cellWorldCenter.z
            })

            for _, surface in ipairs(Config.objectButtonSurfaces) do
                local debugColor = {
                    surface.debugColor[1],
                    surface.debugColor[2],
                    surface.debugColor[3],
                    Config.objectButtonOpacity
                }
                local position = {
                    x = groupCenter.x
                        + (clickAreaOffset.x or 0),
                    y = groupCenter.y
                        + (clickAreaOffset.y or 0),
                    z = groupCenter.z
                        + (clickAreaOffset.z or 0)
                }
                local rotations = {surface.rotation}

                if surface.doubleSided then
                    rotations[#rotations + 1] = {
                        (surface.rotation[1] or 0) + 180,
                        surface.rotation[2] or 0,
                        surface.rotation[3] or 0
                    }
                end

                for faceIndex, rotation in ipairs(rotations) do
                    object.createButton({
                        label = showDebug and faceIndex == 1
                            and surface.label .. " " .. groupIndex or "",
                        click_function = Config.objectButtonClickFunction,
                        function_owner = Global,
                        position = position,
                        rotation = rotation,
                        width = clickArea.height,
                        height = clickArea.width,
                        font_size = showDebug
                            and Config.objectButtonDebugFontSize or 1,
                        color = showDebug
                            and debugColor
                            or Config.invisibleButtonColor,
                        font_color = showDebug
                            and Config.buttonFontColor
                            or Config.invisibleButtonColor,
                        hover_color = showDebug
                            and debugColor
                            or Config.invisibleButtonColor,
                        press_color = showDebug
                            and debugColor
                            or Config.invisibleButtonColor,
                        tooltip = "Edit object"
                    })
                end
            end
        end
    end
end

local function openPlacementMenu(placement, playerColor)
    if placement == nil or not isAdmin(playerColor) then
        return false
    end

    local player = Player[playerColor]
    local cell = cellsByKey[
        HexGridBuilder.cellKey(
            placement.cell.row,
            placement.cell.column
        )
    ]

    if player == nil or cell == nil then
        return false
    end

    HexGridMenu.open(playerColor, player, cell, placement)
    return true
end

local function deletePlacement(placement, playerColor)
    if not hasPlacement(placement) then
        HexGridMenu.close()
        return false
    end

    local template = templatesByKey[placement.templateKey]
    local object = type(placement.guid) == "string"
        and getObjectFromGUID(placement.guid) or nil

    removePlacement(placement)
    HexGridMenu.close()

    if object ~= nil then
        destroyObject(object)
    end

    broadcastToColor(
        (template ~= nil and template.label or "Object")
            .. " deleted from hex " .. placement.cell.row
            .. ", " .. placement.cell.column .. ".",
        playerColor,
        Config.rotationCancelColor
    )

    return true
end

local function spawnPlacement(
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

    local template = templatesByKey[placement.templateKey]
    local targetCell = cellsByKey[
        HexGridBuilder.cellKey(
            placement.cell.row,
            placement.cell.column
        )
    ]
    local facingCell = cellsByKey[
        HexGridBuilder.cellKey(
            placement.facingCell.row,
            placement.facingCell.column
        )
    ]

    local facingKey = facingCell ~= nil
        and HexGridBuilder.cellKey(
            facingCell.row,
            facingCell.column
        ) or nil

    if template == nil
        or targetCell == nil
        or facingCell == nil
        or getAdjacentCells(targetCell)[facingKey] == nil
    then
        reportCompletion(false)
        return false
    end

    local rotationY, localRotationY = getFacingRotations(
        targetCell,
        facingCell,
        template
    )

    placedObjects[#placedObjects + 1] = placement

    local accepted = spawnObject(
        template,
        targetCell,
        facingCell,
        rotationY,
        localRotationY,
        playerColor,
        function(spawnedObject)
            if not hasPlacement(placement) then
                destroyObject(spawnedObject)
                reportCompletion(false)
                return
            end

            local completedSuccessfully = pcall(function()
                placement.guid = spawnedObject.getGUID()
                spawnedObject.addTag(SettingsConfig.placedObjectTag)
            end)

            reportCompletion(completedSuccessfully)
        end,
        function(spawnedObject)
            addObjectClickButton(spawnedObject, placement)
        end,
        silent
    )

    if not accepted then
        removePlacement(placement)
        reportCompletion(false)
    end

    return accepted
end

local function completePendingSpawn(facingCell)
    local spawn = pendingSpawn
    local replacementPlacement = spawn.replacementPlacement

    pendingSpawn = nil
    rotationCandidateCells = {}
    HexGridMenu.close()

    return spawnPlacement({
        templateKey = spawn.template.key,
        cell = copyCell(spawn.targetCell),
        facingCell = copyCell(facingCell)
    }, spawn.playerColor, false, function(succeeded)
        if succeeded and replacementPlacement ~= nil
            and hasPlacement(replacementPlacement)
        then
            local replacedObject =
                type(replacementPlacement.guid) == "string"
                and getObjectFromGUID(replacementPlacement.guid) or nil

            removePlacement(replacementPlacement)

            if replacedObject ~= nil then
                destroyObject(replacedObject)
            end
        end
    end)
end

local function updateHoveredCells()
    if board == nil then
        return
    end

    local nextHoveredCells = {}

    for _, player in ipairs(Player.getPlayers()) do
        local localPointer = board.positionToLocal(player.getPointerPosition())
        local cell = HexGridBuilder.findCellAt(cells, localPointer)

        if cell ~= nil then
            nextHoveredCells[
                HexGridBuilder.cellKey(cell.row, cell.column)
            ] = true
        end
    end

    local changed = false

    for key, _ in pairs(hoveredCells) do
        if not nextHoveredCells[key] then
            changed = true
            break
        end
    end

    if not changed then
        for key, _ in pairs(nextHoveredCells) do
            if not hoveredCells[key] then
                changed = true
                break
            end
        end
    end

    if changed then
        hoveredCells = nextHoveredCells
        drawGrid()
    end
end

local function buildGrid()
    board = getObjectFromGUID(Config.boardGuid)

    if board == nil then
        print("HexGrid: could not find board GUID " .. Config.boardGuid)
        return
    end

    local buildResult = HexGridBuilder.build(board)
    cells = buildResult.cells
    cellsByKey = {}

    for _, cell in ipairs(cells) do
        cellsByKey[
            HexGridBuilder.cellKey(cell.row, cell.column)
        ] = cell
    end

    resolvedSurfaceY = buildResult.surfaceY
    menuTargetCell = nil
    pendingSpawn = nil
    rotationCandidateCells = {}

    drawGrid()

    HexGridMenu.initialize({
        board = board,
        isAdmin = isAdmin,
        onObjectChoice = beginRotationSelection,
        onDeleteObject = deletePlacement,
        onTargetChanged = function(cell)
            menuTargetCell = cell
            drawGrid()
        end,
        onCancelRotation = function(playerColor)
            cancelPendingSpawn(playerColor, false)
        end
    })

    placedObjects = {}

    for index, savedPlacement in ipairs(pendingSavedPlacements) do
        local templateKey = savedPlacement.templateKey
            or savedPlacement.type
        local cell = savedPlacement.cell or savedPlacement.hex
        local facingCell = savedPlacement.facingCell
            or savedPlacement.facing
        local guid = savedPlacement.guid
        local existingObject = type(guid) == "string"
            and getObjectFromGUID(guid) or nil
        local row = type(cell) == "table" and tonumber(cell.row) or nil
        local column = type(cell) == "table"
            and tonumber(cell.column) or nil
        local facingRow = type(facingCell) == "table"
            and tonumber(facingCell.row) or nil
        local facingColumn = type(facingCell) == "table"
            and tonumber(facingCell.column) or nil
        local targetCell = row ~= nil and column ~= nil
            and cellsByKey[HexGridBuilder.cellKey(row, column)] or nil
        local targetFacingCell = facingRow ~= nil and facingColumn ~= nil
            and cellsByKey[
                HexGridBuilder.cellKey(facingRow, facingColumn)
            ] or nil
        local facingKey = targetFacingCell ~= nil
            and HexGridBuilder.cellKey(
                targetFacingCell.row,
                targetFacingCell.column
            ) or nil

        if templatesByKey[templateKey] ~= nil
            and targetCell ~= nil
            and targetFacingCell ~= nil
            and getAdjacentCells(targetCell)[facingKey] ~= nil
        then
            local placement = {
                templateKey = templateKey,
                cell = copyCell(targetCell),
                facingCell = copyCell(targetFacingCell),
                guid = guid
            }

            if existingObject ~= nil then
                existingObject.addTag(SettingsConfig.placedObjectTag)
                addObjectClickButton(existingObject, placement)
                placedObjects[#placedObjects + 1] = placement
            elseif not spawnPlacement(placement, nil, true) then
                print(
                    "HexGrid: could not restore saved object "
                        .. tostring(index) .. "."
                )
            end
        else
            print(
                "HexGrid: ignored invalid saved object "
                    .. tostring(index) .. "."
            )
        end
    end

    pendingSavedPlacements = {}

    if hoverWaitId ~= nil then
        Wait.stop(hoverWaitId)
    end

    hoverWaitId = Wait.time(
        updateHoveredCells,
        Config.hoverPollInterval,
        -1
    )

    print(
        "HexGrid: drew " .. #cells .. " hexes on " .. Config.boardGuid
            .. " at local surface Y "
            .. string.format("%.3f", resolvedSurfaceY)
    )
end

function HexGrid.onLoad(savedState)
    selectedCells = {}
    hoveredCells = {}
    recentClickCells = {}
    rotationCandidateCells = {}
    pendingSpawn = nil
    placedObjects = {}
    pendingSavedPlacements = {}

    if type(savedState) == "table"
        and type(savedState.selectedCells) == "table"
    then
        selectedCells = savedState.selectedCells
    end

    if type(savedState) == "table"
        and type(savedState.placedObjects) == "table"
    then
        pendingSavedPlacements = savedState.placedObjects
    end

    Wait.frames(buildGrid, 2)
end

function HexGrid.onObjectHover()
    updateHoveredCells()
end

function HexGrid.getSaveState()
    local savedPlacements = {}

    for _, placement in ipairs(placedObjects) do
        savedPlacements[#savedPlacements + 1] = {
            templateKey = placement.templateKey,
            cell = copyCell(placement.cell),
            facingCell = copyCell(placement.facingCell),
            guid = placement.guid
        }
    end

    return {
        selectedCells = selectedCells,
        placedObjects = savedPlacements
    }
end

local function normalizeBoardState(boardState)
    return HexBoardState.normalize(boardState, {
        schemaVersion = SettingsConfig.boardStateSchemaVersion,
        boardGuid = Config.boardGuid,
        cellsByKey = cellsByKey,
        templatesByKey = templatesByKey
    })
end

function HexGrid.getBoardState()
    local selectedHexes = {}
    local hexObjects = {}

    for _, cell in ipairs(cells) do
        local key = HexGridBuilder.cellKey(cell.row, cell.column)

        if selectedCells[key] then
            selectedHexes[#selectedHexes + 1] = copyCell(cell)
        end
    end

    for _, placement in ipairs(placedObjects) do
        local occupiedHexes = {}

        for _, occupiedCell in ipairs(
            getPlacementOccupiedCells(placement)
        ) do
            occupiedHexes[#occupiedHexes + 1] =
                copyCell(occupiedCell)
        end

        hexObjects[#hexObjects + 1] = {
            type = placement.templateKey,
            hex = copyCell(placement.cell),
            facing = copyCell(placement.facingCell),
            occupiedHexes = occupiedHexes
        }
    end

    return {
        schemaVersion = SettingsConfig.boardStateSchemaVersion,
        boardGuid = Config.boardGuid,
        selectedHexes = selectedHexes,
        hexObjects = hexObjects
    }
end

function HexGrid.getBoardStateJson()
    return JSON.encode_pretty(HexGrid.getBoardState())
end

function HexGrid.loadBoardState(boardState, playerColor, onCompleted)
    if board == nil or #cells == 0 then
        return false, "The hex board is not ready yet."
    end

    local normalizedState, validationError = normalizeBoardState(boardState)

    if normalizedState == nil then
        return false, validationError
    end

    if pendingSpawn ~= nil then
        pendingSpawn = nil
        rotationCandidateCells = {}
    end

    HexGridMenu.close()

    local objectsToDestroy = {}
    local guidsToDestroy = {}

    for _, object in ipairs(
        getObjectsWithTag(SettingsConfig.placedObjectTag)
    ) do
        local guid = object.getGUID()
        objectsToDestroy[#objectsToDestroy + 1] = object
        guidsToDestroy[guid] = true
    end

    for _, placement in ipairs(placedObjects) do
        if type(placement.guid) == "string"
            and not guidsToDestroy[placement.guid]
        then
            local object = getObjectFromGUID(placement.guid)

            if object ~= nil then
                objectsToDestroy[#objectsToDestroy + 1] = object
                guidsToDestroy[placement.guid] = true
            end
        end
    end

    placedObjects = {}

    for _, object in ipairs(objectsToDestroy) do
        destroyObject(object)
    end

    selectedCells = normalizedState.selectedCells
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
                successfulSpawnCount == #normalizedState.placements
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
            placement,
            playerColor,
            true,
            onPlacementCompleted
        ) then
            spawnedCount = spawnedCount + 1
        end
    end

    drawGrid()
    spawningFinished = true
    reportLoadCompletionIfReady()

    return true,
        "Board setup loaded: "
            .. normalizedState.selectedHexCount .. " selected hexes and "
            .. spawnedCount .. " objects."
end

function HexGrid.loadBoardStateJson(
    boardStateJson,
    playerColor,
    onCompleted
)
    local decodedSuccessfully, boardState = pcall(
        JSON.decode,
        boardStateJson
    )

    if not decodedSuccessfully then
        return false, "The board-state JSON is not valid JSON."
    end

    return HexGrid.loadBoardState(
        boardState,
        playerColor,
        onCompleted
    )
end

function HexGrid.onObjectDestroy(object)
    if object == nil then
        return
    end

    local guid = object.getGUID()

    for index = #placedObjects, 1, -1 do
        if placedObjects[index].guid == guid then
            table.remove(placedObjects, index)
        end
    end
end

local function handlePointerClick(playerColor, altClick)
    if board == nil then
        return false
    end

    local player = Player[playerColor]

    if player == nil then
        return false
    end

    local localPointer = board.positionToLocal(player.getPointerPosition())
    local cell = HexGridBuilder.findCellAt(cells, localPointer)

    local key = cell ~= nil
        and HexGridBuilder.cellKey(cell.row, cell.column) or nil

    if key ~= nil and recentClickCells[playerColor] == key then
        return true
    end

    if key ~= nil then
        recentClickCells[playerColor] = key

        Wait.frames(function()
            if recentClickCells[playerColor] == key then
                recentClickCells[playerColor] = nil
            end
        end, 2)
    end

    if pendingSpawn ~= nil then
        if pendingSpawn.playerColor ~= playerColor then
            return true
        end

        local facingCell = key ~= nil
            and pendingSpawn.adjacentCells[key] or nil

        if not altClick and facingCell ~= nil then
            completePendingSpawn(facingCell)
        else
            cancelPendingSpawn(playerColor)
        end

        return true
    end

    if cell == nil or altClick then
        return false
    end

    local placement = getPlacementAtCell(cell)

    if placement ~= nil then
        openPlacementMenu(placement, playerColor)
        return true
    end

    if isAdmin(playerColor) and editMode then
        HexGridMenu.open(playerColor, player, cell)
        return true
    end

    HexGridMenu.close()
    selectedCells[key] = not selectedCells[key] or nil
    drawGrid()

    broadcastToColor(
        "Hex " .. cell.row .. ", " .. cell.column
            .. (selectedCells[key] and " selected." or " cleared."),
        playerColor,
        Config.selectedColor
    )

    return true
end

function HexGrid.onClicked(playerColor, altClick)
    handlePointerClick(playerColor, altClick)
end

function HexGrid.onObjectClicked(object, playerColor, altClick)
    if object == nil or altClick then
        return
    end

    if pendingSpawn ~= nil then
        if pendingSpawn.playerColor == playerColor then
            cancelPendingSpawn(playerColor)
        end

        return
    end

    local placement = getPlacementByGuid(object.getGUID())
    openPlacementMenu(placement, playerColor)
end

function HexGrid.onPlayerAction(player, action, targets)
    if pendingSpawn ~= nil
        and action == Player.Action.Select
        and player.color == pendingSpawn.playerColor
        and (
            type(targets) ~= "table"
            or #targets ~= 1
            or targets[1] == nil
            or targets[1].getGUID() ~= Config.boardGuid
        )
    then
        cancelPendingSpawn(player.color)
        return true
    end

    if board == nil
        or action ~= Player.Action.Select
        or type(targets) ~= "table"
        or #targets ~= 1
        or targets[1] == nil
    then
        return true
    end

    local targetGuid = targets[1].getGUID()

    if targetGuid == Config.boardGuid then
        if handlePointerClick(player.color, false) then
            return false
        end

        return true
    end

    local placement = getPlacementByGuid(targetGuid)

    if placement == nil then
        return true
    end

    return not openPlacementMenu(placement, player.color)
end

function HexGrid.onMenuUiClicked(playerColor, action)
    HexGridMenu.handleAction(playerColor, action)
end

function HexGrid.setEditMode(enabled)
    editMode = enabled == true

    if not editMode then
        pendingSpawn = nil
        rotationCandidateCells = {}
        HexGridMenu.close()

        if board ~= nil then
            drawGrid()
        end
    end
end

return HexGrid

local Config = require("src/config/HexGridConfig")
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
        silent = silent
    })
end

local adjacentOffsets = {
    {row = 0, column = 1},
    {row = -1, column = 1},
    {row = -1, column = 0},
    {row = 0, column = -1},
    {row = 1, column = -1},
    {row = 1, column = 0}
}

local function getAdjacentCells(targetCell)
    local adjacentCells = {}

    for _, offset in ipairs(adjacentOffsets) do
        local key = HexGridBuilder.cellKey(
            targetCell.row + offset.row,
            targetCell.column + offset.column
        )
        local adjacentCell = cellsByKey[key]

        if adjacentCell ~= nil then
            adjacentCells[key] = adjacentCell
        end
    end

    return adjacentCells
end

local function beginRotationSelection(template, targetCell, playerColor)
    local adjacentCells = getAdjacentCells(targetCell)

    pendingSpawn = {
        template = template,
        targetCell = targetCell,
        playerColor = playerColor,
        adjacentCells = adjacentCells
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

    pendingSpawn = nil
    rotationCandidateCells = {}
    HexGridMenu.close()

    return spawnPlacement({
        templateKey = spawn.template.key,
        cell = copyCell(spawn.targetCell),
        facingCell = copyCell(facingCell)
    }, spawn.playerColor, false)
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

local function normalizeCell(value, fieldName)
    if type(value) ~= "table" then
        return nil, fieldName .. " must be an object."
    end

    local row = tonumber(value.row)
    local column = tonumber(value.column)

    if row == nil or column == nil
        or row ~= math.floor(row)
        or column ~= math.floor(column)
    then
        return nil, fieldName .. " must contain integer row and column values."
    end

    local cell = cellsByKey[HexGridBuilder.cellKey(row, column)]

    if cell == nil then
        return nil, fieldName .. " is outside the hex grid."
    end

    return copyCell(cell)
end

local function getArrayLength(value, fieldName)
    local entryCount = 0
    local highestIndex = 0

    for key, _ in pairs(value) do
        if type(key) ~= "number"
            or key < 1
            or key ~= math.floor(key)
        then
            return nil, fieldName .. " must be an array."
        end

        entryCount = entryCount + 1
        highestIndex = math.max(highestIndex, key)
    end

    if entryCount ~= highestIndex then
        return nil, fieldName .. " must not contain missing entries."
    end

    return entryCount
end

local function normalizeBoardState(boardState)
    if type(boardState) ~= "table" then
        return nil, "Board-state JSON must contain an object."
    end

    if tonumber(boardState.schemaVersion)
        ~= SettingsConfig.boardStateSchemaVersion
    then
        return nil, "Unsupported board-state schema version."
    end

    if boardState.boardGuid ~= Config.boardGuid then
        return nil, "This board state belongs to a different board."
    end

    if type(boardState.selectedHexes) ~= "table" then
        return nil, "selectedHexes must be an array."
    end

    if type(boardState.hexObjects) ~= "table" then
        return nil, "hexObjects must be an array."
    end

    local selectedHexCount, selectedHexesError = getArrayLength(
        boardState.selectedHexes,
        "selectedHexes"
    )

    if selectedHexCount == nil then
        return nil, selectedHexesError
    end

    local hexObjectCount, hexObjectsError = getArrayLength(
        boardState.hexObjects,
        "hexObjects"
    )

    if hexObjectCount == nil then
        return nil, hexObjectsError
    end

    local normalized = {
        selectedCells = {},
        selectedHexCount = 0,
        placements = {}
    }

    for index = 1, selectedHexCount do
        local selectedHex = boardState.selectedHexes[index]
        local cell, cellError = normalizeCell(
            selectedHex,
            "selectedHexes[" .. index .. "]"
        )

        if cell == nil then
            return nil, cellError
        end

        local key = HexGridBuilder.cellKey(cell.row, cell.column)

        if not normalized.selectedCells[key] then
            normalized.selectedCells[key] = true
            normalized.selectedHexCount =
                normalized.selectedHexCount + 1
        end
    end

    for index = 1, hexObjectCount do
        local objectState = boardState.hexObjects[index]
        if type(objectState) ~= "table"
            or type(objectState.type) ~= "string"
            or templatesByKey[objectState.type] == nil
        then
            return nil,
                "hexObjects[" .. index .. "] has an unknown object type."
        end

        local cell, cellError = normalizeCell(
            objectState.hex,
            "hexObjects[" .. index .. "].hex"
        )

        if cell == nil then
            return nil, cellError
        end

        local facingCell, facingError = normalizeCell(
            objectState.facing,
            "hexObjects[" .. index .. "].facing"
        )

        if facingCell == nil then
            return nil, facingError
        end

        local facingKey = HexGridBuilder.cellKey(
            facingCell.row,
            facingCell.column
        )

        if getAdjacentCells(cell)[facingKey] == nil then
            return nil,
                "hexObjects[" .. index
                    .. "].facing must be adjacent to its hex."
        end

        normalized.placements[#normalized.placements + 1] = {
            templateKey = objectState.type,
            cell = cell,
            facingCell = facingCell
        }
    end

    return normalized
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
        hexObjects[#hexObjects + 1] = {
            type = placement.templateKey,
            hex = copyCell(placement.cell),
            facing = copyCell(placement.facingCell)
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

    if isAdmin(playerColor) then
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
        or targets[1].getGUID() ~= Config.boardGuid
    then
        return true
    end

    if handlePointerClick(player.color, false) then
        return false
    end

    return true
end

function HexGrid.onMenuUiClicked(playerColor, action)
    HexGridMenu.handleAction(playerColor, action)
end

return HexGrid

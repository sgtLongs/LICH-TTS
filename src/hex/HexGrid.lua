local Config = require("src/config/HexGridConfig")
local HexGridBuilder = require("src/hex/HexGridBuilder")
local HexGridMenu = require("src/hex/HexGridMenu")
local HexObjectSpawner = require("src/hex/HexObjectSpawner")

local HexGrid = {}
local board = nil
local cells = {}
local selectedCells = {}
local hoveredCells = {}
local menuTargetCell = nil
local rotationCandidateCells = {}
local pendingSpawn = nil
local resolvedSurfaceY = 0
local hoverWaitId = nil
local recentClickCells = {}

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
    playerColor
)
    return HexObjectSpawner.spawn({
        board = board,
        surfaceY = resolvedSurfaceY,
        template = template,
        cell = targetCell,
        facingCell = facingCell,
        rotationY = rotationY,
        localRotationY = localRotationY,
        playerColor = playerColor
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
    local cellsByKey = {}
    local adjacentCells = {}

    for _, cell in ipairs(cells) do
        cellsByKey[HexGridBuilder.cellKey(cell.row, cell.column)] = cell
    end

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

local function completePendingSpawn(facingCell)
    local spawn = pendingSpawn
    local rotationY, localRotationY = getFacingRotations(
        spawn.targetCell,
        facingCell,
        spawn.template
    )

    pendingSpawn = nil
    rotationCandidateCells = {}
    HexGridMenu.close()

    return spawnObject(
        spawn.template,
        spawn.targetCell,
        facingCell,
        rotationY,
        localRotationY,
        spawn.playerColor
    )
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

    if type(savedState) == "table"
        and type(savedState.selectedCells) == "table"
    then
        selectedCells = savedState.selectedCells
    end

    Wait.frames(buildGrid, 2)
end

function HexGrid.onObjectHover()
    updateHoveredCells()
end

function HexGrid.getSaveState()
    return {
        selectedCells = selectedCells
    }
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

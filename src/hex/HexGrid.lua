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
local resolvedSurfaceY = 0
local hoverWaitId = nil
local recentClickCells = {}

local function drawGrid()
    HexGridBuilder.draw(board, cells, resolvedSurfaceY, {
        selectedCells = selectedCells,
        hoveredCells = hoveredCells,
        menuTargetCell = menuTargetCell
    })
end

local function isAdmin(playerColor)
    local player = Player[playerColor]
    return player ~= nil and player.admin == true
end

local function spawnObject(template, targetCell, playerColor)
    return HexObjectSpawner.spawn({
        board = board,
        surfaceY = resolvedSurfaceY,
        template = template,
        cell = targetCell,
        playerColor = playerColor
    })
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

    drawGrid()

    HexGridMenu.initialize({
        board = board,
        isAdmin = isAdmin,
        onObjectChoice = spawnObject,
        onTargetChanged = function(cell)
            menuTargetCell = cell
            drawGrid()
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

    if cell == nil or altClick then
        return false
    end

    local key = HexGridBuilder.cellKey(cell.row, cell.column)

    if recentClickCells[playerColor] == key then
        return true
    end

    recentClickCells[playerColor] = key

    Wait.frames(function()
        if recentClickCells[playerColor] == key then
            recentClickCells[playerColor] = nil
        end
    end, 2)

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

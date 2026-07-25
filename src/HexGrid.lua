local HexGrid = {}
local HexGridMenu = require("src/HexGridMenu")

-- Hex-grid alignment config for board GUID 068885.
-- All distances are in the board object's local coordinates.
local CONFIG = {
    boardGuid = "068885",
    -- A side length of 6 produces a regular hexagon containing 91 cells.
    sideLength = 6,

    -- Change these values to align the generated grid with the artwork.
    hexRadius = 1.5,
    rotationDegrees = 0,
    offsetX = 0,
    offsetZ = 0,

    -- Leave nil to detect the top of the object automatically. Set a number
    -- here only if the model has unusual bounds and needs a manual override.
    surfaceY = nil,
    surfaceOffset = -4.302,

    lineColor = {0, 0.8, 1},
    hoverColor = {1, 1, 0},
    selectedColor = {1, 0.75, 0.1},
    menuTargetColor = {0.95, 0.2, 1},
    lineThickness = 0.10,
    hoverLineThickness = 0.28,
    hoverSurfaceOffset = 0.04,
    selectedLineThickness = 0.18,
    menuTargetLineThickness = 0.34,
    menuTargetSurfaceOffset = 0.07,
    spawnedObjectSurfaceOffset = 0.03
}

local GRID_CLICK_FUNCTION = "onHexGridClicked"

local SQRT_3 = math.sqrt(3)
local board = nil
local cells = {}
local selectedCells = {}
local hoveredCells = {}
local menuTargetCell = nil
local resolvedSurfaceY = 0
local hoverWaitId = nil
local spawnObjectFromTemplate = nil

local function cellKey(row, column)
    return tostring(row) .. ":" .. tostring(column)
end

local function rotatePoint(x, z)
    local radians = math.rad(CONFIG.rotationDegrees)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return {
        x = x * cosine - z * sine + CONFIG.offsetX,
        z = x * sine + z * cosine + CONFIG.offsetZ
    }
end

local function makeCells()
    local gridRadius = CONFIG.sideLength - 1
    cells = {}

    -- Axial coordinates constrained to a radius form a regular hexagon.
    for q = -gridRadius, gridRadius do
        local minimumR = math.max(-gridRadius, -q - gridRadius)
        local maximumR = math.min(gridRadius, -q + gridRadius)

        for r = minimumR, maximumR do
            local center = rotatePoint(
                SQRT_3 * CONFIG.hexRadius * (q + r * 0.5),
                1.5 * CONFIG.hexRadius * r
            )

            table.insert(cells, {
                row = r,
                column = q,
                x = center.x,
                z = center.z
            })
        end
    end
end

local function makeHexLine(cell, color, thickness, surfaceOffset)
    local points = {}
    local lineY = resolvedSurfaceY + (surfaceOffset or 0)

    for corner = 0, 6 do
        -- Starting at 30 degrees creates a pointy-top hex.
        local angle = math.rad(30 + (corner % 6) * 60 + CONFIG.rotationDegrees)
        table.insert(points, {
            x = cell.x + CONFIG.hexRadius * math.cos(angle),
            y = lineY,
            z = cell.z + CONFIG.hexRadius * math.sin(angle)
        })
    end

    return {
        points = points,
        color = color,
        thickness = thickness
    }
end

local function drawLines()
    if board == nil then
        return
    end

    local lines = {}

    for _, cell in ipairs(cells) do
        table.insert(lines, makeHexLine(cell, CONFIG.lineColor, CONFIG.lineThickness))

        if selectedCells[cellKey(cell.row, cell.column)] then
            table.insert(
                lines,
                makeHexLine(cell, CONFIG.selectedColor, CONFIG.selectedLineThickness)
            )
        end

        if hoveredCells[cellKey(cell.row, cell.column)] then
            table.insert(
                lines,
                makeHexLine(
                    cell,
                    CONFIG.hoverColor,
                    CONFIG.hoverLineThickness,
                    CONFIG.hoverSurfaceOffset
                )
            )
        end

        if menuTargetCell ~= nil
            and menuTargetCell.row == cell.row
            and menuTargetCell.column == cell.column
        then
            table.insert(
                lines,
                makeHexLine(
                    cell,
                    CONFIG.menuTargetColor,
                    CONFIG.menuTargetLineThickness,
                    CONFIG.menuTargetSurfaceOffset
                )
            )
        end
    end

    board.setVectorLines(lines)
end

local function removeGridButtons()
    local existingButtons = board.getButtons() or {}

    for index = #existingButtons, 1, -1 do
        local button = existingButtons[index]

        if button.click_function == GRID_CLICK_FUNCTION then
            board.removeButton(button.index)
        end
    end
end

local function createButtons()
    -- Remove only controls created by this grid, preserving any board controls.
    removeGridButtons()

    -- Large TTS buttons stop receiving clicks reliably far from their center.
    -- Give every cell its own inset control. The controls are slightly smaller
    -- than the center-to-center spacing, so neighboring hit boxes do not
    -- overlap and the pointer-based exact hex test remains deterministic.
    for _, cell in ipairs(cells) do
        board.createButton({
            label = "",
            click_function = GRID_CLICK_FUNCTION,
            function_owner = Global,
            position = {cell.x, resolvedSurfaceY + 0.02, cell.z},
            rotation = {0, CONFIG.rotationDegrees, 0},
            width = math.floor(SQRT_3 * CONFIG.hexRadius * 0.96 * 100),
            height = math.floor(1.5 * CONFIG.hexRadius * 0.96 * 100),
            font_size = 1,
            color = {0, 0, 0, 0},
            hover_color = {0, 0, 0, 0},
            press_color = {0, 0, 0, 0},
            tooltip = "Hex grid"
        })
    end
end

local function isAdmin(playerColor)
    local player = Player[playerColor]
    return player ~= nil and player.admin == true
end

local function placeSpawnedObject(spawnedObject, cell)
    if spawnedObject == nil or board == nil then
        return
    end

    local targetSurface = board.positionToWorld({
        x = cell.x,
        y = resolvedSurfaceY + CONFIG.spawnedObjectSurfaceOffset,
        z = cell.z
    })
    local currentPosition = spawnedObject.getPosition()
    local bounds = spawnedObject.getBounds()
    local boundsBottom = bounds.center.y - bounds.size.y * 0.5

    spawnedObject.setPosition({
        x = targetSurface.x,
        y = currentPosition.y + targetSurface.y - boundsBottom,
        z = targetSurface.z
    })
    spawnedObject.setLuaScript("")
    spawnedObject.script_state = ""
    spawnedObject.setLock(true)
end

local function pointIsInsideCell(localPointer, cell)
    local deltaX = localPointer.x - cell.x
    local deltaZ = localPointer.z - cell.z
    local radians = math.rad(-CONFIG.rotationDegrees)
    local localX = math.abs(deltaX * math.cos(radians) - deltaZ * math.sin(radians))
    local localZ = math.abs(deltaX * math.sin(radians) + deltaZ * math.cos(radians))

    -- Exact pointy-top regular-hex containment test.
    return localX <= SQRT_3 * CONFIG.hexRadius * 0.5
        and SQRT_3 * localZ + localX <= SQRT_3 * CONFIG.hexRadius
end

local function findCellAt(localPointer)
    local nearest = nil
    local nearestDistanceSquared = nil

    for _, cell in ipairs(cells) do
        local deltaX = localPointer.x - cell.x
        local deltaZ = localPointer.z - cell.z
        local distanceSquared = deltaX * deltaX + deltaZ * deltaZ

        if nearestDistanceSquared == nil or distanceSquared < nearestDistanceSquared then
            nearest = cell
            nearestDistanceSquared = distanceSquared
        end
    end

    if nearest ~= nil and pointIsInsideCell(localPointer, nearest) then
        return nearest
    end

    return nil
end

local function updateHoveredCells()
    if board == nil then
        return
    end

    local nextHoveredCells = {}

    for _, player in ipairs(Player.getPlayers()) do
        local localPointer = board.positionToLocal(player.getPointerPosition())
        local cell = findCellAt(localPointer)

        if cell ~= nil then
            nextHoveredCells[cellKey(cell.row, cell.column)] = true
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
        drawLines()
    end
end

local function resolveSurfaceY()
    if CONFIG.surfaceY ~= nil then
        return CONFIG.surfaceY
    end

    local bounds = board.getBounds()
    local worldTop = {
        x = bounds.center.x,
        y = bounds.center.y + bounds.size.y * 0.5 + CONFIG.surfaceOffset,
        z = bounds.center.z
    }

    return board.positionToLocal(worldTop).y
end

local function buildGrid()
    board = getObjectFromGUID(CONFIG.boardGuid)

    if board == nil then
        print("HexGrid: could not find board GUID " .. CONFIG.boardGuid)
        return
    end

    resolvedSurfaceY = resolveSurfaceY()
    makeCells()
    menuTargetCell = nil
    drawLines()
    HexGridMenu.initialize({
        board = board,
        isAdmin = isAdmin,
        onObjectChoice = spawnObjectFromTemplate,
        onTargetChanged = function(cell)
            menuTargetCell = cell
            drawLines()
        end
    })

    createButtons()

    if hoverWaitId ~= nil then
        Wait.stop(hoverWaitId)
    end

    -- getPointerPosition is TTS's native cursor-ray hit position. Poll it
    -- directly here so hover tracking does not depend on a forwarded Global
    -- onUpdate callback.
    hoverWaitId = Wait.time(updateHoveredCells, 0.05, -1)

    print(
        "HexGrid: drew " .. #cells .. " hexes on " .. CONFIG.boardGuid
            .. " at local surface Y " .. string.format("%.3f", resolvedSurfaceY)
    )
end

function HexGrid.onLoad(savedState)
    selectedCells = {}
    hoveredCells = {}

    if type(savedState) == "table" and type(savedState.selectedCells) == "table" then
        selectedCells = savedState.selectedCells
    end

    -- Objects may not all be available during Global's first onLoad frame.
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

function HexGrid.onClicked(playerColor, altClick)
    if board == nil then
        return
    end

    local player = Player[playerColor]

    if player == nil then
        return
    end

    local localPointer = board.positionToLocal(player.getPointerPosition())
    local cell = findCellAt(localPointer)

    if cell == nil then
        return
    end

    -- Leave right-click available for TTS's native object context menu.
    if altClick then
        return
    end

    if isAdmin(playerColor) then
        HexGridMenu.open(playerColor, player, cell)
        return
    end

    HexGridMenu.close()

    local key = cellKey(cell.row, cell.column)
    selectedCells[key] = not selectedCells[key] or nil
    drawLines()

    broadcastToColor(
        "Hex " .. cell.row .. ", " .. cell.column
            .. (selectedCells[key] and " selected." or " cleared."),
        playerColor,
        CONFIG.selectedColor
    )
end

function HexGrid.onMenuUiClicked(playerColor, action)
    HexGridMenu.handleAction(playerColor, action)
end

spawnObjectFromTemplate = function(template, targetCell, playerColor)
    if type(template.json) ~= "string" or template.json == "" then
        broadcastToColor(
            "No saved template exists for " .. template.label .. ".",
            playerColor,
            {1, 0.35, 0.25}
        )
        return false
    end

    local spawnPosition = board.positionToWorld({
        x = targetCell.x,
        y = resolvedSurfaceY + 1,
        z = targetCell.z
    })

    local spawnSucceeded = pcall(function()
        spawnObjectJSON({
            json = template.json,
            position = spawnPosition,
            callback_function = function(spawnedObject)
                -- Templates contain no script fields. Reapply the runtime
                -- guarantees after creation too.
                spawnedObject.setLuaScript("")
                spawnedObject.script_state = ""
                spawnedObject.setLock(true)

                Wait.frames(function()
                    placeSpawnedObject(spawnedObject, targetCell)
                end, 2)

                broadcastToColor(
                    template.label .. " added at hex "
                        .. targetCell.row .. ", " .. targetCell.column .. ".",
                    playerColor,
                    {0.25, 0.9, 0.55}
                )
            end
        })
    end)

    if not spawnSucceeded then
        broadcastToColor(
            "Could not spawn the " .. template.label .. ".",
            playerColor,
            {1, 0.35, 0.25}
        )
        return false
    end

    return true
end

return HexGrid

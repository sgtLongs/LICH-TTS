local HexGrid = {}

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
    lineThickness = 0.10,
    hoverLineThickness = 0.28,
    hoverSurfaceOffset = 0.04,
    selectedLineThickness = 0.18
}

local SQRT_3 = math.sqrt(3)
local board = nil
local cells = {}
local selectedCells = {}
local hoveredCells = {}
local resolvedSurfaceY = 0
local hoverWaitId = nil

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
    end

    board.setVectorLines(lines)
end

local function createButtons()
    -- Remove only controls created by this grid, preserving any board controls.
    local existingButtons = board.getButtons() or {}

    for index = #existingButtons, 1, -1 do
        local button = existingButtons[index]

        if button.click_function == "onHexGridClicked" then
            board.removeButton(button.index)
        end
    end

    local gridRadius = CONFIG.sideLength - 1

    -- One control spans the whole grid. Per-cell bounding boxes overlap at
    -- every sloped edge, which makes TTS choose controls inconsistently.
    -- The callback below performs the exact per-hex hit test.
    board.createButton({
        label = "",
        click_function = "onHexGridClicked",
        function_owner = Global,
        position = {CONFIG.offsetX, resolvedSurfaceY + 0.02, CONFIG.offsetZ},
        rotation = {0, CONFIG.rotationDegrees, 0},
        width = math.ceil(
            SQRT_3 * CONFIG.hexRadius * (2 * gridRadius + 1) * 100
        ),
        height = math.ceil(
            CONFIG.hexRadius * (3 * gridRadius + 2) * 100
        ),
        font_size = 1,
        color = {0, 0, 0, 0},
        hover_color = {0, 0, 0, 0},
        press_color = {0, 0, 0, 0},
        tooltip = "Hex grid"
    })
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
    drawLines()
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

function HexGrid.onClicked(playerColor)
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

return HexGrid

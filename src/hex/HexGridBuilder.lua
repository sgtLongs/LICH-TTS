local Config = require("src/config/HexGridConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local HexGeometry = require("src/hex/HexGeometry")
local Runtime = require("src/tts/Runtime")

local HexGridBuilder = {}
local SQRT_3 = math.sqrt(3)

function HexGridBuilder.cellKey(row, column)
    return HexGeometry.cellKey(row, column)
end

local function resolveSurfaceY(board)
    if Config.surfaceY ~= nil then
        return Config.surfaceY
    end

    local bounds = board.getBounds()
    local worldTop = {
        x = bounds.center.x,
        y = bounds.center.y + bounds.size.y * 0.5 + Config.surfaceOffset,
        z = bounds.center.z
    }

    return board.positionToLocal(worldTop).y
end

local function makeHexLine(cell, surfaceY, color, thickness, surfaceOffset)
    local points = {}
    local lineY = surfaceY + (surfaceOffset or 0)

    for corner = 0, 6 do
        local angle = math.rad(
            30 + (corner % 6) * 60 + Config.rotationDegrees
        )

        table.insert(points, {
            x = cell.x + Config.hexRadius * math.cos(angle),
            y = lineY,
            z = cell.z + Config.hexRadius * math.sin(angle)
        })
    end

    return {
        points = points,
        color = color,
        thickness = thickness
    }
end

local function makeHexFillLines(
    cell,
    surfaceY,
    color,
    thickness,
    surfaceOffset
)
    local lines = {}
    local fillY = surfaceY + surfaceOffset
    local radians = math.rad(Config.rotationDegrees)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    local stripeCount = math.ceil(2 * Config.hexRadius / thickness)
    local stripeHeight = 2 * Config.hexRadius / stripeCount

    for stripe = 0, stripeCount - 1 do
        local localZ = -Config.hexRadius + (stripe + 0.5) * stripeHeight
        local absoluteZ = math.abs(localZ)
        local halfWidth = SQRT_3 * Config.hexRadius * 0.5

        if absoluteZ > Config.hexRadius * 0.5 then
            halfWidth = SQRT_3 * (Config.hexRadius - absoluteZ)
        end

        local startX = -halfWidth
        local endX = halfWidth

        table.insert(lines, {
            points = {
                {
                    x = cell.x + startX * cosine - localZ * sine,
                    y = fillY,
                    z = cell.z + startX * sine + localZ * cosine
                },
                {
                    x = cell.x + endX * cosine - localZ * sine,
                    y = fillY,
                    z = cell.z + endX * sine + localZ * cosine
                }
            },
            color = color,
            thickness = stripeHeight
        })
    end

    return lines
end

function HexGridBuilder.draw(board, cells, surfaceY, state)
    if board == nil then
        return
    end

    local lines = {}

    for _, cell in ipairs(cells) do
        local key = HexGridBuilder.cellKey(cell.row, cell.column)

        table.insert(
            lines,
            makeHexLine(
                cell,
                surfaceY,
                Config.lineColor,
                Config.lineThickness
            )
        )

        if state.selectedCells[key] then
            table.insert(
                lines,
                makeHexLine(
                    cell,
                    surfaceY,
                    Config.selectedColor,
                    Config.selectedLineThickness
                )
            )
        end

        if state.rotationCandidateCells[key] then
            for _, fillLine in ipairs(
                makeHexFillLines(
                    cell,
                    surfaceY,
                    Config.rotationCandidateFillColor,
                    Config.rotationCandidateFillLineThickness,
                    Config.rotationCandidateFillSurfaceOffset
                )
            ) do
                table.insert(lines, fillLine)
            end

            table.insert(
                lines,
                makeHexLine(
                    cell,
                    surfaceY,
                    Config.rotationCandidateColor,
                    Config.rotationCandidateLineThickness,
                    Config.rotationCandidateSurfaceOffset
                )
            )
        end

        if state.hoveredCells[key] then
            for _, fillLine in ipairs(
                makeHexFillLines(
                    cell,
                    surfaceY,
                    Config.hoverFillColor,
                    Config.hoverFillLineThickness,
                    Config.hoverFillSurfaceOffset
                )
            ) do
                table.insert(lines, fillLine)
            end

            table.insert(
                lines,
                makeHexLine(
                    cell,
                    surfaceY,
                    Config.hoverColor,
                    Config.hoverLineThickness,
                    Config.hoverSurfaceOffset
                )
            )
        end

        local target = state.menuTargetCell

        if target ~= nil
            and target.row == cell.row
            and target.column == cell.column
        then
            table.insert(
                lines,
                makeHexLine(
                    cell,
                    surfaceY,
                    Config.menuTargetColor,
                    Config.menuTargetLineThickness,
                    Config.menuTargetSurfaceOffset
                )
            )
        end
    end

    board.setVectorLines(lines)
end

local function getButtonDimensions()
    return {
        width = math.max(60, math.floor(Config.buttonLength * 100 + 0.5)),
        height = math.max(60, math.floor(Config.buttonThickness * 100 + 0.5))
    }
end

local function removeGridButtons(board)
    local existingButtons = board.getButtons() or {}

    for index = #existingButtons, 1, -1 do
        local button = existingButtons[index]

        if button.click_function == Config.buttonClickFunction then
            board.removeButton(button.index)
        end
    end
end

local function createButtons(board, cells, surfaceY, functionOwner)
    removeGridButtons(board)

    local dimensions = getButtonDimensions()
    local showDebug = DebugConfig.drawHexButtons == true

    for _, cell in ipairs(cells) do
        for buttonIndex, buttonConfig in ipairs(Config.buttons) do
            board.createButton({
                label = showDebug and buttonConfig.label or "",
                click_function = Config.buttonClickFunction,
                function_owner = functionOwner,
                position = {
                    cell.x,
                    surfaceY + Config.buttonSurfaceOffset
                        + buttonIndex * Config.buttonLayerSpacing,
                    cell.z
                },
                rotation = {
                    0,
                    Config.rotationDegrees + buttonConfig.rotation,
                    0
                },
                width = dimensions.width,
                height = dimensions.height,
                font_size = showDebug and Config.buttonFontSize or 1,
                color = showDebug
                    and buttonConfig.color or Config.invisibleButtonColor,
                font_color = showDebug
                    and Config.buttonFontColor or Config.invisibleButtonColor,
                hover_color = showDebug
                    and buttonConfig.hoverColor or Config.invisibleButtonColor,
                press_color = showDebug
                    and buttonConfig.pressColor or Config.invisibleButtonColor,
                tooltip = showDebug
                    and buttonConfig.label .. " degree hex button" or ""
            })
        end
    end
end

function HexGridBuilder.build(board, options)
    options = options or {}
    local cells = HexGeometry.buildCells(Config)
    local surfaceY = resolveSurfaceY(board)
    local functionOwner = options.functionOwner

    if functionOwner == nil then
        functionOwner = Runtime.default().getGlobalOwner()
    end

    createButtons(board, cells, surfaceY, functionOwner)

    return {
        cells = cells,
        surfaceY = surfaceY
    }
end

function HexGridBuilder.findCellAt(cells, localPointer)
    return HexGeometry.findCellAt(cells, localPointer, Config)
end

return HexGridBuilder

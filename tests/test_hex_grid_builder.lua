local Test = require("tests/support/Test")

Global = {}

local HexGridBuilder = require("src/hex/HexGridBuilder")

Test.case("hex grid builder creates TTS buttons and resolves the surface", function()
    local createdButtons = {}
    local removedButtons = {}
    local board = {
        getBounds = function()
            return {
                center = {x = 0, y = 10, z = 0},
                size = {x = 20, y = 2, z = 20}
            }
        end,
        positionToLocal = function(position)
            return position
        end,
        getButtons = function()
            return {
                {index = 4, click_function = "onHexGridClicked"},
                {index = 8, click_function = "unrelated"}
            }
        end,
        removeButton = function(index)
            removedButtons[#removedButtons + 1] = index
        end,
        createButton = function(button)
            createdButtons[#createdButtons + 1] = button
        end
    }

    local result = HexGridBuilder.build(board)

    Test.equal(91, #result.cells)
    Test.near(6.698, result.surfaceY, 0.000001)
    Test.equal(1, #removedButtons)
    Test.equal(4, removedButtons[1])
    Test.equal(273, #createdButtons)
    Test.equal("onHexGridClicked", createdButtons[1].click_function)
    Test.equal(Global, createdButtons[1].function_owner)
end)

Test.case("hex grid builder emits vector lines through the TTS board", function()
    local emittedLines = nil
    local board = {
        setVectorLines = function(lines)
            emittedLines = lines
        end
    }
    local cells = {
        {row = 0, column = 0, x = 0, z = 0}
    }

    HexGridBuilder.draw(board, cells, 2, {
        selectedCells = {},
        hoveredCells = {},
        menuTargetCell = nil,
        rotationCandidateCells = {}
    })

    Test.equal(1, #emittedLines)
    Test.equal(7, #emittedLines[1].points)
    Test.equal(2, emittedLines[1].points[1].y)
end)

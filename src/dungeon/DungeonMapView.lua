local DungeonMapRules = require("src/dungeon/DungeonMapRules")
local UiPatch = require("src/ui/UiPatch")

local DungeonMapView = {}

local function add(patches, id, attribute, value)
    UiPatch.append(patches, id, attribute, value)
end

function DungeonMapView.buildModePatch(config, editMode)
    local patches = {}

    add(
        patches,
        config.ui.browsePageId,
        "active",
        editMode and "false" or "true"
    )
    add(
        patches,
        config.ui.editPageId,
        "active",
        editMode and "true" or "false"
    )
    add(
        patches,
        config.ui.modeTitleId,
        "text",
        editMode and "EDIT DUNGEON" or "DUNGEON MAP"
    )

    return patches
end

function DungeonMapView.buildPatch(config, model)
    local patches = {}
    local assignments = model.assignmentsByCellKey
    local savedBoards = model.savedBoards

    for _, cell in ipairs(model.cells) do
        local buttonId = config.ui.tileButtonPrefix .. cell.index
        local boardSaveId = assignments[cell.key]
        local savedBoard = DungeonMapRules.findBoardById(
            savedBoards,
            boardSaveId
        )
        local canTraverse = DungeonMapRules.canTraverse(
            model.cellsByKey,
            model.currentCellKey,
            cell
        )
        local tileColors = config.tileColors.empty
        local textColor = config.tileTextColor

        if boardSaveId ~= nil and savedBoard == nil then
            tileColors = config.tileColors.missing
        elseif boardSaveId ~= nil and not model.editMode and not canTraverse then
            tileColors = config.tileColors.unreachable
        elseif boardSaveId ~= nil then
            tileColors = config.tileColors.assigned
        end

        if cell.key == model.currentCellKey then
            tileColors = config.tileColors.current
            textColor = config.currentTileTextColor
        end

        if model.editMode and cell.key == model.selectedCellKey then
            tileColors = config.tileColors.selected
            textColor = config.tileTextColor
        end

        add(patches, buttonId, "colors", tileColors)
        add(patches, buttonId, "textColor", textColor)
        add(patches, buttonId, "text", cell.q .. ", " .. cell.r)
        add(
            patches,
            buttonId,
            "active",
            (model.editMode or boardSaveId ~= nil) and "true" or "false"
        )
        add(
            patches,
            buttonId,
            "tooltip",
            "Hex " .. cell.q .. ", " .. cell.r .. ": "
                .. DungeonMapRules.getAssignmentDescription(
                    assignments,
                    cell,
                    savedBoards
                )
                .. (
                    boardSaveId ~= nil
                    and not model.editMode
                    and not canTraverse
                    and " (not adjacent to the current level)"
                    or ""
                )
        )
    end

    local currentCell = model.currentCellKey ~= nil
        and model.cellsByKey[model.currentCellKey] or nil

    add(
        patches,
        config.ui.currentLevelLabelId,
        "text",
        currentCell == nil
            and "Current level: none"
            or "Current: " .. DungeonMapRules.getAssignmentDescription(
                assignments,
                currentCell,
                savedBoards
            ) .. "  (" .. currentCell.q .. ", " .. currentCell.r .. ")"
    )

    local selectedCell = model.selectedCellKey ~= nil
        and model.cellsByKey[model.selectedCellKey] or nil

    add(
        patches,
        config.ui.selectedTileLabelId,
        "text",
        selectedCell == nil
            and "Select a hex, then click a board save to assign it."
            or "Hex " .. selectedCell.q .. ", " .. selectedCell.r
                .. "\nAssigned: "
                .. DungeonMapRules.getAssignmentDescription(
                    assignments,
                    selectedCell,
                    savedBoards
                )
    )

    local pageInfo = DungeonMapRules.getPage(
        savedBoards,
        model.boardListPage,
        config.boardListPageSize
    )
    local selectedBoardSaveId = model.selectedCellKey ~= nil
        and assignments[model.selectedCellKey] or nil

    for row = 1, config.boardListPageSize do
        local savedBoard = pageInfo.rows[row]
        local buttonId = config.ui.boardButtonPrefix .. row

        if savedBoard ~= nil then
            add(patches, buttonId, "active", "true")
            add(patches, buttonId, "text", savedBoard.name)
            add(patches, buttonId, "tooltip", savedBoard.name)
            add(
                patches,
                buttonId,
                "colors",
                savedBoard.id == selectedBoardSaveId
                    and config.uiColors.assignedBoard
                    or config.uiColors.board
            )
        else
            add(patches, buttonId, "active", "false")
        end
    end

    add(
        patches,
        config.ui.noBoardsLabelId,
        "active",
        #savedBoards == 0 and "true" or "false"
    )
    add(
        patches,
        config.ui.boardPageLabelId,
        "text",
        "Page " .. pageInfo.page .. " / " .. pageInfo.pageCount
    )
    add(
        patches,
        config.ui.previousPageButtonId,
        "interactable",
        pageInfo.page > 1 and "true" or "false"
    )
    add(
        patches,
        config.ui.nextPageButtonId,
        "interactable",
        pageInfo.page < pageInfo.pageCount and "true" or "false"
    )

    return patches, pageInfo.page
end

return DungeonMapView

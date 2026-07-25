local DungeonMapConfig = {
    schemaVersion = 1,
    radius = 3,
    boardListPageSize = 5,
    traversalLockFrames = 75,
    traversalTimeoutFrames = 600,
    ui = {
        rootId = "dungeonMapRoot",
        modeTitleId = "dungeonMapModeTitle",
        browsePageId = "dungeonMapBrowsePage",
        editPageId = "dungeonMapEditPage",
        tileButtonPrefix = "dungeonMapTile",
        currentLevelLabelId = "dungeonMapCurrentLevel",
        selectedTileLabelId = "dungeonMapSelectedTile",
        boardButtonPrefix = "dungeonMapBoard",
        noBoardsLabelId = "dungeonMapNoBoards",
        boardPageLabelId = "dungeonMapBoardPageLabel",
        previousPageButtonId = "dungeonMapPreviousPage",
        nextPageButtonId = "dungeonMapNextPage",
        statusId = "dungeonMapStatus"
    },
    tileColors = {
        empty = "#334155|#475569|#1E293B|#1E293B",
        assigned = "#0E7490|#0891B2|#155E75|#164E63",
        current = "#F59E0B|#FBBF24|#D97706|#92400E",
        selected = "#C026D3|#D946EF|#A21CAF|#701A75",
        unreachable = "#475569|#64748B|#334155|#334155",
        missing = "#B91C1C|#DC2626|#991B1B|#7F1D1D"
    },
    tileTextColor = "#F8FAFC",
    currentTileTextColor = "#111827",
    uiColors = {
        board = "#26364D|#344A69|#192638|#192638",
        assignedBoard = "#155E75|#0E7490|#164E63|#164E63"
    },
    statusColors = {
        normal = "#CBD5E1",
        success = "#86EFAC",
        warning = "#FDE68A",
        failure = "#FCA5A5"
    },
    chatColors = {
        denied = {1, 0.35, 0.35},
        failure = {1, 0.35, 0.35},
        success = {0.35, 1, 0.55}
    }
}

return DungeonMapConfig

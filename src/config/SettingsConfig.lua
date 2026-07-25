local SettingsConfig = {
    boardStateSchemaVersion = 1,
    legacySettingsSchemaVersion = 1,
    settingsSchemaVersion = 2,
    placedObjectTag = "LichHexGridObject",
    boardListPageSize = 5,
    ui = {
        rootId = "settingsMenuRoot",
        mainPageId = "settingsMainPage",
        jsonPageId = "settingsJsonPage",
        boardNameInputId = "settingsBoardName",
        boardButtonPrefix = "settingsSavedBoard",
        boardPageLabelId = "settingsBoardPageLabel",
        previousPageButtonId = "settingsPreviousPage",
        nextPageButtonId = "settingsNextPage",
        selectedBoardLabelId = "settingsSelectedBoard",
        jsonInputId = "settingsBoardStateJson",
        statusId = "settingsMenuStatus"
    },
    uiColors = {
        board = "#26364D|#344A69|#192638|#192638",
        selectedBoard = "#155E75|#0E7490|#164E63|#164E63"
    },
    colors = {
        denied = {1, 0.35, 0.35},
        failure = {1, 0.35, 0.35},
        success = {0.35, 1, 0.55}
    }
}

return SettingsConfig

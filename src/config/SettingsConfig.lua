local HexGridConfig = require("src/config/HexGridConfig")

local SettingsConfig = {
    -- Compatibility aliases. Hex-board persistence belongs to HexGridConfig;
    -- callers should migrate there without invalidating existing extensions.
    boardStateSchemaVersion = HexGridConfig.boardStateSchemaVersion,
    legacySettingsSchemaVersion = 1,
    settingsSchemaVersion = 2,
    placedObjectTag = HexGridConfig.placedObjectTag,
    boardListPageSize = 5,
    ui = {
        rootId = "settingsMenuRoot",
        generalPageId = "settingsGeneralPage",
        savePageId = "settingsSavePage",
        jsonPageId = "settingsJsonPage",
        editModeToggleId = "settingsEditMode",
        addMockPlayerButtonId = "settingsAddMockPlayer",
        disconnectMockPlayerButtonId = "settingsDisconnectMockPlayer",
        removeMockPlayerButtonId = "settingsRemoveMockPlayer",
        restartGameButtonId = "settingsRestartGame",
        generalTabButtonId = "settingsGeneralTab",
        saveTabButtonId = "settingsSaveTab",
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
        selectedBoard = "#155E75|#0E7490|#164E63|#164E63",
        tab = "#26364D|#344A69|#192638|#192638",
        selectedTab = "#155E75|#0E7490|#164E63|#164E63"
    },
    colors = {
        denied = {1, 0.35, 0.35},
        failure = {1, 0.35, 0.35},
        success = {0.35, 1, 0.55}
    }
}

return SettingsConfig

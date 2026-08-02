local Test = require("tests/support/Test")
local SettingsConfig = require("src/config/SettingsConfig")
local DungeonConfig = require("src/dungeon/DungeonMapConfig")
local DungeonMapState = require("src/dungeon/DungeonMapState")
local SettingsView = require("src/settings/SettingsView")
local DungeonMapView = require("src/dungeon/DungeonMapView")

local function indexPatches(patches)
    local indexed = {}

    for _, patch in ipairs(patches) do
        indexed[patch.id .. "." .. patch.attribute] = patch.value
    end

    return indexed
end

Test.case("settings view builds page and saved-board patches", function()
    local pagePatch = indexPatches(SettingsView.buildPagePatch(
        SettingsConfig,
        SettingsConfig.ui.savePageId
    ))
    Test.equal("false", pagePatch[SettingsConfig.ui.generalPageId .. ".active"])
    Test.equal("true", pagePatch[SettingsConfig.ui.savePageId .. ".active"])
    Test.equal(
        SettingsConfig.uiColors.selectedTab,
        pagePatch[SettingsConfig.ui.saveTabButtonId .. ".colors"]
    )

    local boardPatch = indexPatches(SettingsView.buildBoardListPatch(
        SettingsConfig,
        {
            page = 2,
            pageCount = 2,
            rows = {{id = "board-6", name = "Crypt"}},
            selectedBoardId = "board-6",
            selectedBoard = {id = "board-6", name = "Crypt"}
        }
    ))
    Test.equal(
        "Crypt",
        boardPatch[SettingsConfig.ui.boardButtonPrefix .. "1.text"]
    )
    Test.equal(
        SettingsConfig.uiColors.selectedBoard,
        boardPatch[SettingsConfig.ui.boardButtonPrefix .. "1.colors"]
    )
    Test.equal(
        "false",
        boardPatch[SettingsConfig.ui.nextPageButtonId .. ".interactable"]
    )
end)

Test.case("dungeon view describes current unreachable and missing tiles", function()
    local cells, cellsByKey = DungeonMapState.buildCells(2)
    local patches = indexPatches(DungeonMapView.buildPatch(DungeonConfig, {
        cells = cells,
        cellsByKey = cellsByKey,
        assignmentsByCellKey = {
            ["0:0"] = "entrance",
            ["2:0"] = "far",
            ["-1:0"] = "missing"
        },
        currentCellKey = "0:0",
        selectedCellKey = nil,
        editMode = false,
        boardListPage = 1,
        savedBoards = {
            {id = "entrance", name = "Entrance"},
            {id = "far", name = "Far Hall"}
        }
    }))
    local farIndex = cellsByKey["2:0"].index
    local missingIndex = cellsByKey["-1:0"].index

    Test.equal(
        DungeonConfig.tileColors.unreachable,
        patches[DungeonConfig.ui.tileButtonPrefix .. farIndex .. ".colors"]
    )
    Test.contains(
        patches[DungeonConfig.ui.tileButtonPrefix .. farIndex .. ".tooltip"],
        "not adjacent"
    )
    Test.equal(
        DungeonConfig.tileColors.missing,
        patches[DungeonConfig.ui.tileButtonPrefix .. missingIndex .. ".colors"]
    )
    Test.equal(
        "Current: Entrance  (0, 0)",
        patches[DungeonConfig.ui.currentLevelLabelId .. ".text"]
    )
end)

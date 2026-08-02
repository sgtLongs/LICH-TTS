local UiPatch = require("src/ui/UiPatch")

local SettingsView = {}

local function add(patches, id, attribute, value)
    UiPatch.append(patches, id, attribute, value)
end

function SettingsView.buildPagePatch(config, pageId)
    local patches = {}

    add(
        patches,
        config.ui.generalPageId,
        "active",
        pageId == config.ui.generalPageId and "true" or "false"
    )
    add(
        patches,
        config.ui.savePageId,
        "active",
        pageId == config.ui.savePageId and "true" or "false"
    )
    add(
        patches,
        config.ui.jsonPageId,
        "active",
        pageId == config.ui.jsonPageId and "true" or "false"
    )
    add(
        patches,
        config.ui.generalTabButtonId,
        "colors",
        pageId == config.ui.generalPageId
            and config.uiColors.selectedTab
            or config.uiColors.tab
    )
    add(
        patches,
        config.ui.saveTabButtonId,
        "colors",
        pageId ~= config.ui.generalPageId
            and config.uiColors.selectedTab
            or config.uiColors.tab
    )

    return patches
end

function SettingsView.buildBoardListPatch(config, pageInfo)
    local patches = {}

    for row = 1, config.boardListPageSize do
        local savedBoard = pageInfo.rows[row]
        local buttonId = config.ui.boardButtonPrefix .. row

        if savedBoard ~= nil then
            add(patches, buttonId, "active", "true")
            add(patches, buttonId, "text", savedBoard.name)
            add(
                patches,
                buttonId,
                "colors",
                savedBoard.id == pageInfo.selectedBoardId
                    and config.uiColors.selectedBoard
                    or config.uiColors.board
            )
        else
            add(patches, buttonId, "active", "false")
        end
    end

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
    add(
        patches,
        config.ui.selectedBoardLabelId,
        "text",
        pageInfo.selectedBoard ~= nil
            and "Selected: " .. pageInfo.selectedBoard.name
            or "No saved board selected"
    )

    return patches
end

return SettingsView

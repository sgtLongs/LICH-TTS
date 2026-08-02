local UiPatch = require("src/ui/UiPatch")

local HexGridMenuView = {}

function HexGridMenuView.buildPagePatch(config, pageId)
    return {
        UiPatch.set(
            config.ui.addPageId,
            "active",
            pageId == config.ui.addPageId and "true" or "false"
        ),
        UiPatch.set(
            config.ui.objectPageId,
            "active",
            pageId == config.ui.objectPageId and "true" or "false"
        ),
        UiPatch.set(
            config.ui.rotationPageId,
            "active",
            pageId == config.ui.rotationPageId and "true" or "false"
        )
    }
end

function HexGridMenuView.buildHiddenPatch(config)
    return {
        UiPatch.set(config.ui.rootId, "active", "false")
    }
end

function HexGridMenuView.buildSpawnSelectorHiddenPatch(config)
    return {
        UiPatch.set(
            config.ui.spawnSelectorRootId,
            "active",
            "false"
        )
    }
end

function HexGridMenuView.buildSpawnSelectorPatch(
    config,
    spawnDefinitions,
    selectedTemplate
)
    local patches = {}
    local selectedKey = selectedTemplate ~= nil
        and selectedTemplate.key or nil

    UiPatch.append(
        patches,
        config.ui.spawnSelectorStatusId,
        "text",
        selectedTemplate ~= nil
            and "SELECTED: " .. string.upper(selectedTemplate.label)
            or "PRESS 1-9 OR CHOOSE AN OBJECT"
    )

    for index, template in ipairs(spawnDefinitions) do
        UiPatch.append(
            patches,
            config.ui.spawnSelectorButtonPrefix .. tostring(index),
            "colors",
            template.key == selectedKey
                and config.ui.spawnSelectorSelectedColors
                or config.ui.spawnSelectorButtonColors
        )
    end

    UiPatch.append(
        patches,
        config.ui.spawnSelectorRootId,
        "active",
        "true"
    )
    return patches
end

function HexGridMenuView.buildOpenPatch(
    config,
    templatesByKey,
    activeMenu
)
    local patches = {}
    local placement = activeMenu.placement
    local cell = activeMenu.cell

    UiPatch.append(
        patches,
        config.ui.rootId,
        "visibility",
        activeMenu.playerColor
    )
    UiPatch.append(
        patches,
        config.ui.titleId,
        "text",
        placement ~= nil
            and "Edit " .. templatesByKey[placement.templateKey].label
            or "Selected Hex " .. cell.row .. ", " .. cell.column
    )
    UiPatch.append(
        patches,
        config.ui.deleteButtonId,
        "active",
        placement ~= nil and "true" or "false"
    )
    UiPatch.extend(
        patches,
        HexGridMenuView.buildPagePatch(config, config.ui.objectPageId)
    )
    UiPatch.append(patches, config.ui.rootId, "active", "true")
    return patches
end

function HexGridMenuView.buildRotationPatch(config, template)
    local patches = {
        UiPatch.set(
            config.ui.titleId,
            "text",
            "Rotate " .. template.label
        ),
        UiPatch.set(
            config.ui.rotationPromptId,
            "text",
            "Click a highlighted adjacent hex to choose which way "
                .. template.label .. " faces."
        )
    }

    UiPatch.extend(
        patches,
        HexGridMenuView.buildPagePatch(config, config.ui.rotationPageId)
    )
    return patches
end

return HexGridMenuView

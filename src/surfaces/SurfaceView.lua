local UiPatch = require("src/ui/UiPatch")

local SurfaceView = {}

function SurfaceView.buildHiddenPatch(config)
    return {
        UiPatch.set(config.ui.rootId, "active", "false")
    }
end

function SurfaceView.buildOpenPatch(config, definitions, activeMenu)
    local patches = {
        UiPatch.set(
            config.ui.rootId,
            "visibility",
            activeMenu.playerColor
        ),
        UiPatch.set(
            config.ui.titleId,
            "text",
            "SURFACES  " .. activeMenu.cell.row
                .. ", " .. activeMenu.cell.column
        )
    }

    for index, definition in ipairs(definitions) do
        UiPatch.append(
            patches,
            config.ui.buttonPrefix .. tostring(index),
            "interactable",
            activeMenu.availableSurfaceKeys[definition.key]
                and "true" or "false"
        )
    end

    UiPatch.append(patches, config.ui.rootId, "active", "true")
    return patches
end

return SurfaceView

local SurfaceConfig = {
    surfaces = {
        {
            key = "deathFog",
            name = "Death Fog",
            color = {r = 0.188235, g = 1, b = 0},
            opacity = 0.784314,
            isDeathFog = true,
            blocksSurfacePlacement = true,
            sourceGuid = "dcc277"
        },
        {
            key = "fire",
            name = "Fire",
            color = {r = 0.85, g = 0.08, b = 0.04},
            opacity = 0.65
        },
        {
            key = "smoke",
            name = "Smoke",
            color = {r = 0, g = 0, b = 0},
            opacity = 0.95
        },
        {
            key = "water",
            name = "Water",
            color = {r = 0.05, g = 0.3, b = 0.95},
            opacity = 0.55
        },
        {
            key = "steam",
            name = "Steam",
            color = {r = 1, g = 1, b = 1},
            opacity = 0.5
        },
        {
            key = "sludge",
            name = "Sludge",
            color = {r = 0.45, g = 0.25, b = 0.05},
            opacity = 0.8
        },
        {
            key = "vines",
            name = "Vines",
            color = {r = 0.03, g = 0.25, b = 0.06},
            opacity = 1
        }
    },
    ui = {
        rootId = "surfaceMenuRoot",
        titleId = "surfaceMenuTitle",
        buttonPrefix = "surfaceMenuChoice",
        removeSourceStoneButtonId = "surfaceMenuRemoveSourceStone"
    },
    removeSourceStoneAction = {
        key = "removeSourceStone",
        label = "Remove Source Stone"
    }
}

return SurfaceConfig

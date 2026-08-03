local HexGridConfig = {
    boardGuid = "068885",
    boardStateSchemaVersion = 1,
    placedObjectTag = "LichHexGridObject",
    sideLength = 6,

    -- Grid alignment in board-local units.
    hexRadius = 1.5,
    rotationDegrees = 0,
    offsetX = 0,
    offsetZ = 0,

    -- Leave nil to derive the surface from the board bounds.
    surfaceY = nil,
    surfaceOffset = -4.302,

    -- Three overlapping buttons cover each hex at 0, 60, and 120 degrees.
    buttonLength = 12.8,
    buttonThickness = 8,
    buttonSurfaceOffset = 0.02,
    buttonLayerSpacing = 0.002,
    buttonClickFunction = "onHexGridClicked",
    objectButtonClickFunction = "onHexGridObjectClicked",
    objectButtonDebugFontSize = 28,
    objectButtonOpacity = 0.6,
    objectButtonSurfaces = {
        {
            label = "SIDE 1",
            group = "side",
            position = {x = -0.5, y = 0, z = 0.8660254},
            rotation = {60, 0, 90},
            colorName = "RED",
            debugColor = {1, 0.25, 0.25}
        },
        {
            label = "SIDE 2",
            group = "side",
            position = {x = 0.5, y = 0, z = 0.8660254},
            rotation = {120, 0, 90},
            colorName = "GREEN",
            debugColor = {0.25, 1, 0.35}
        },
        {
            label = "SIDE 3",
            group = "side",
            position = {x = 1, y = 0, z = 0},
            rotation = {180, 0, 90},
            colorName = "BLUE",
            debugColor = {0.1, 0.7, 1}
        },
        {
            label = "SIDE 4",
            group = "side",
            position = {x = 0.5, y = 0, z = -0.8660254},
            rotation = {240, 0, 90},
            colorName = "ORANGE",
            debugColor = {1, 0.55, 0.1}
        },
        {
            label = "SIDE 5",
            group = "side",
            position = {x = -0.5, y = 0, z = -0.8660254},
            rotation = {300, 0, 90},
            colorName = "PURPLE",
            debugColor = {0.7, 0.25, 1}
        },
        {
            label = "SIDE 6",
            group = "side",
            position = {x = -1, y = 0, z = 0},
            rotation = {0, 0, 90},
            colorName = "CYAN",
            debugColor = {0.1, 0.9, 0.9}
        },
        {
            label = "TOP 1",
            group = "top",
            position = {x = 0, y = 0, z = 0},
            rotation = {0, 0, 0},
            colorName = "RED",
            debugColor = {1, 0.25, 0.25}
        },
        {
            label = "TOP 2",
            group = "top",
            position = {x = 0, y = 0, z = 0},
            rotation = {0, 60, 0},
            colorName = "GREEN",
            debugColor = {0.25, 1, 0.35}
        },
        {
            label = "TOP 3",
            group = "top",
            position = {x = 0, y = 0, z = 0},
            rotation = {0, 120, 0},
            colorName = "BLUE",
            debugColor = {0.1, 0.7, 1}
        }
    },
    buttonFontSize = 34,
    buttonFontColor = {1, 1, 1, 0.95},
    invisibleButtonColor = {0, 0, 0, 0},
    buttons = {
        {
            rotation = 0,
            label = "0",
            color = {1, 0.15, 0.15, 1},
            hoverColor = {1, 0.35, 0.35, 0.62},
            pressColor = {0.8, 0.05, 0.05, 0.72}
        },
        {
            rotation = 60,
            label = "60",
            color = {0.15, 1, 0.25, 1},
            hoverColor = {0.35, 1, 0.45, 0.62},
            pressColor = {0.05, 0.8, 0.15, 0.72}
        },
        {
            rotation = 120,
            label = "120",
            color = {0.2, 0.35, 1, 1},
            hoverColor = {0.4, 0.55, 1, 0.62},
            pressColor = {0.1, 0.2, 0.8, 0.72}
        }
    },

    hitEdgePadding = 0.12,
    hoverPollInterval = 0.05,

    lineColor = {0, 0.8, 1},
    hoverColor = {1, 1, 0},
    hoverFillColor = {1, 1, 0, 0.18},
    selectedColor = {1, 0.75, 0.1},
    menuTargetColor = {0.95, 0.2, 1},
    rotationCandidateColor = {0.2, 1, 0.35},
    rotationCandidateFillColor = {0.2, 1, 0.35, 0.2},
    deathFogCandidateColor = {0.55, 0.1, 0.75},
    deathFogCandidateFillColor = {0.35, 0.05, 0.5, 0.3},
    rotationCancelColor = {1, 0.45, 0.25},
    lineThickness = 0.0,
    hoverFillLineThickness = 0.12,
    hoverFillSurfaceOffset = 0.02,
    hoverLineThickness = 0.0,
    hoverSurfaceOffset = 0.04,
    selectedLineThickness = 0.18,
    menuTargetLineThickness = 0.34,
    menuTargetSurfaceOffset = 0.07,
    rotationCandidateFillLineThickness = 0.12,
    rotationCandidateFillSurfaceOffset = 0.03,
    rotationCandidateLineThickness = 0.28,
    rotationCandidateSurfaceOffset = 0.08,
    deathFogCandidateFillLineThickness = 0.14,
    deathFogCandidateFillSurfaceOffset = 0.035,
    deathFogCandidateLineThickness = 0.3,
    deathFogCandidateSurfaceOffset = 0.085
}

return HexGridConfig

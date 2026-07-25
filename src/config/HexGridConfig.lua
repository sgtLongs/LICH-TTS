local HexGridConfig = {
    boardGuid = "068885",
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
    showButtonDebug = false,
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
    rotationCandidateSurfaceOffset = 0.08
}

return HexGridConfig

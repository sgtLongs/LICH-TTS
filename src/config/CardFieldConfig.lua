local CardFieldConfig = {
    columns = 7,
    rows = 3,

    -- World-space height used for the debug lines.
    surfaceY = 1.72,
    lineThickness = 0.08,
    sectionLineThickness = 0.18,
    gridColor = {0.75, 0.75, 0.75, 0.8},

    -- Rectangles use inclusive, one-based grid coordinates. Keeping the
    -- layout here makes it easy to replace with the final CSV mapping.
    sections = {
        {
            key = "skillLeft",
            label = "Skill 1",
            firstColumn = 1,
            lastColumn = 2,
            firstRow = 1,
            lastRow = 3,
            color = {0.25, 0.75, 1, 1}
        },
        {
            key = "source",
            label = "Source",
            firstColumn = 3,
            lastColumn = 5,
            firstRow = 1,
            lastRow = 3,
            color = {0.9, 0.35, 0.95, 1}
        },
        {
            key = "skillRight",
            label = "Skill 2",
            firstColumn = 6,
            lastColumn = 7,
            firstRow = 1,
            lastRow = 3,
            color = {0.25, 0.75, 1, 1}
        }
    },

    -- Positions line up with the six cabinet/table-extension spaces.
    -- Size is the complete 7-by-3 field size in world units.
    fields = {
        {
            playerColor = "White",
            position = {x = -36, z = -41},
            rotationDegrees = 0,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Brown",
            position = {x = 0, z = -41},
            rotationDegrees = 0,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Red",
            position = {x = 36, z = -41},
            rotationDegrees = 0,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Green",
            position = {x = 36, z = 41},
            rotationDegrees = 180,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Teal",
            position = {x = 0, z = 41},
            rotationDegrees = 180,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Blue",
            position = {x = -36, z = 41},
            rotationDegrees = 180,
            size = {x = 28, z = 16.5}
        }
    }
}

return CardFieldConfig

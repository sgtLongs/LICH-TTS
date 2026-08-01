local CardLogicConfig = {
    buttons = {
        -- Positions are local to each card, so they continue to follow the
        -- card when it moves or rotates.
        tap = {
            position = {x = 0, y = 0.3, z = 0},
            width = 1200,
            height = 1600
        },
        destroy = {
            position = {x = 1.8, y = 0.3, z = 0},
            width = 900,
            height = 500
        }
    },

    debug = {
        tapLabel = "tap",
        tapColor = {0.1, 0.65, 1, 0.45},
        tapHoverColor = {0.2, 0.8, 1, 0.6},
        tapPressColor = {0.05, 0.45, 0.8, 0.7},
        tapFontColor = {1, 1, 1, 1}
    }
}

return CardLogicConfig

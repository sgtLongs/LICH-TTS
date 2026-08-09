local CardLogicConfig = {
    tap = {
        sideRotationDegrees = 90,
        rotationToleranceDegrees = 5
    },

    buttons = {
        -- Positions are local to each card, so they continue to follow the
        -- card when it moves or rotates.
        actions = {
            position = {x = 0, y = 0.3, z = -2.2},
            width = 1200,
            height = 500,
            -- World-space distance the card rises while its actions are open.
            liftHeight = 1.5
        }
    },

    preview = {
        rootId = "cardPreviewRoot",
        imageId = "cardPreviewImage",
        -- Persistent TTS highlight shown around the previewed physical card.
        glowColor = {r = 0.15, g = 0.7, b = 1}
    }
}

return CardLogicConfig

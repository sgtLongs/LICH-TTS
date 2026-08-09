local CardLogicConfig = {
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
        imageId = "cardPreviewImage"
    }
}

return CardLogicConfig

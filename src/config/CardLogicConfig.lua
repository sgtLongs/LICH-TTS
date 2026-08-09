local actionList = {
    width = 900,
    height = 1000,
    startPosition = {x = 0, y = 0.3, z = -1},
    xOffset = 2,
    zOffset = 2
}

local function actionButtonPosition(side, row)
    return {
        x = actionList.startPosition.x + (side * actionList.xOffset),
        y = actionList.startPosition.y,
        z = actionList.startPosition.z + (row * actionList.zOffset)
    }
end

local CardLogicConfig = {
    buttons = {
        -- Positions are local to each card, so they continue to follow the
        -- card when it moves or rotates.
        actionList = actionList,
        actions = {
            position = {x = 0, y = 0.3, z = -2.2},
            width = 1200,
            height = 500,
            -- World-space distance the card rises while its actions are open.
            liftHeight = 1.5
        },
        destroy = {
            position = actionButtonPosition(-1, 1)
        },
        damn = {
            position = actionButtonPosition(-1, 0)
        },
        unequip = {
            position = actionButtonPosition(1, 1)
        },
        returnToHand = {
            position = actionButtonPosition(1, 0)
        }
    },

    preview = {
        rootId = "cardPreviewRoot",
        imageId = "cardPreviewImage"
    }
}

return CardLogicConfig

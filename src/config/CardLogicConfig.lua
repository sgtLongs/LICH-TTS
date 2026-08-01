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
        tap = {
            position = {x = 0, y = 0.3, z = 0},
            width = 1200,
            height = 1600
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

    debug = {
        tapLabel = "tap",
        tapColor = {0.1, 0.65, 1, 0.45},
        tapHoverColor = {0.2, 0.8, 1, 0.6},
        tapPressColor = {0.05, 0.45, 0.8, 0.7},
        tapFontColor = {1, 1, 1, 1}
    }
}

return CardLogicConfig

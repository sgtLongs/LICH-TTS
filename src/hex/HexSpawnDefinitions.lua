local SavedObjectData = require("data/HexGridObjectTemplates")

local function makeHexPrismClickArea(settings)
    return {
        side = {
            width = settings.sideWidth,
            height = settings.sideHeight,
            distance = settings.sideDistance,
            positionRotationDegrees =
                settings.sidePositionRotationDegrees or 0,
            positionOffset = settings.sidePositionOffset
                or settings.positionOffset or {}
        },
        top = {
            width = settings.topWidth,
            height = settings.topHeight,
            positionOffset = settings.topPositionOffset
                or settings.positionOffset or {},
            rotationOffset = settings.topRotationOffset or {}
        }
    }
end

-- objectPositionOffset moves the spawned object in board-local units and
-- rotates with its facing. editClickArea position offsets move only buttons
-- in the spawned object's local axes.
-- Rotation offsets are degrees added to the direction selected on the grid.
-- Click-area dimensions are measured in Tabletop Simulator button units.
-- Positions and rotation offsets use the spawned object's local axes. Side
-- distance moves each of the six faces away from its occupied hex's center;
-- sidePositionRotationDegrees rotates all six positions symmetrically around
-- that center. Top position offsets are relative to the object's upper world
-- bound.
local HexSpawnDefinitions = {
    {
        key = "tree",
        label = "Tree",
        json = SavedObjectData.tree,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 1000,
            sideHeight = 9000,
            sideDistance = 1.5,
            sidePositionRotationDegrees = 0,
            topWidth = 1600,
            topHeight = 1000,
            topPositionOffset = {x = 0, y = 0.05, z = 0}
        })
    },
    {
        key = "throne",
        label = "Throne",
        json = SavedObjectData.throne,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 150,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 800,
            sideHeight = 900,
            sideDistance = -1.3,
            sidePositionRotationDegrees = 0,
            topWidth = 1400,
            topHeight = 800,
            topPositionOffset = {x = 0, y = 0, z = 0}
        })
    },
    {
        key = "rock1",
        label = "Rock 1",
        json = SavedObjectData.rock1,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 900,
            sideHeight = 1100,
            sideDistance = -1.4,
            sidePositionRotationDegrees = 0,
            topWidth = 1400,
            topHeight = 900,
            topPositionOffset = {x = 0, y = 0.05, z = 0}
        })
    },
    {
        key = "rock2",
        label = "Rock 2",
        json = SavedObjectData.rock2,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 900,
            sideHeight = 1100,
            sideDistance = -1.4,
            sidePositionRotationDegrees = 0,
            topWidth = 1400,
            topHeight = 900,
            topPositionOffset = {x = 0, y = 0.05, z = 0}
        })
    },
    {
        key = "doubleRock",
        label = "Double Rock",
        json = SavedObjectData.doubleRock,
        objectPositionOffset = {x = -1.3, y = 0, z = 0},
        rotationOffsetY = 90,
        occupiesFacingCell = true,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 1000,
            sideHeight = 1100,
            sideDistance = -1.4,
            sidePositionRotationDegrees = 0,
            topWidth = 1500,
            topHeight = 900,
            topPositionOffset = {x = 0, y = 0.05, z = 0}
        })
    },
    {
        key = "crystal",
        label = "Crystal",
        json = SavedObjectData.crystal,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 700,
            sideHeight = 1700,
            sideDistance = -1.2,
            sidePositionRotationDegrees = 0,
            topWidth = 1200,
            topHeight = 800,
            topPositionOffset = {x = 0, y = 0.05, z = 0}
        })
    },
    {
        key = "chest",
        label = "Chest",
        json = SavedObjectData.chest,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 800,
            sideHeight = 1700,
            sideDistance = -1.3,
            sidePositionRotationDegrees = 0,
            topWidth = 1300,
            topHeight = 900,
            topPositionOffset = {x = 0, y = 0.05, z = 0}
        })
    },
    {
        key = "cage",
        label = "Cage",
        json = SavedObjectData.cage,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 700,
            sideHeight = 1400,
            sideDistance = -1.2,
            sidePositionRotationDegrees = 0,
            topWidth = 1200,
            topHeight = 700,
            topPositionOffset = {x = 0, y = 0.05, z = 0}
        })
    },
    {
        key = "sourceStone",
        label = "Source Stone",
        json = SavedObjectData.sourceStone,
        allowsDeathFog = true,
        isSourceStone = true,
        objectPositionOffset = {x = 0.65, y = 0, z = 0.19},
        rotationOffsetY = 30,
        editClickArea = makeHexPrismClickArea({
            sideWidth = 2450,
            sideHeight = 1600,
            sideDistance = -4.3,
            sidePositionRotationDegrees = 0,
            topWidth = 4200,
            topHeight = 2300,
            -- Moves both button groups without moving the Source Stone.
            positionOffset = {x = 5.6, y = -0.6, z = 0.25}
        })
    }
}

return HexSpawnDefinitions

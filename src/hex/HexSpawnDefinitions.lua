local SavedObjectData = require("data/HexGridObjectTemplates")

-- Position offsets use each object's local axes and rotate with the object.
-- They intentionally live beside each object definition because every spawned
-- object can require different alignment.
-- Rotation offsets are degrees added to the direction selected on the grid.
local HexSpawnDefinitions = {
    {
        key = "tree",
        label = "Tree",
        json = SavedObjectData.tree,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30
    },
    {
        key = "throne",
        label = "Throne",
        json = SavedObjectData.throne,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 150
    },
    {
        key = "rock1",
        label = "Rock 1",
        json = SavedObjectData.rock1,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30
    },
    {
        key = "rock2",
        label = "Rock 2",
        json = SavedObjectData.rock2,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30
    },
    {
        key = "doubleRock",
        label = "Double Rock",
        json = SavedObjectData.doubleRock,
        positionOffset = {x = -1.3, y = 0.03, z = 0},
        rotationOffsetY = 90,
        occupiesFacingCell = true
    },
    {
        key = "crystal",
        label = "Crystal",
        json = SavedObjectData.crystal,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30
    },
    {
        key = "chest",
        label = "Chest",
        json = SavedObjectData.chest,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30
    },
    {
        key = "cage",
        label = "Cage",
        json = SavedObjectData.cage,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30
    },
    {
        key = "sourceStone",
        label = "Source Stone",
        json = SavedObjectData.sourceStone,
        positionOffset = {x = 0.65, y = 0.2, z = 0.25},
        rotationOffsetY = 30
    }
}

return HexSpawnDefinitions

local SavedObjectData = require("data/HexGridObjectTemplates")

-- Position offsets are board-local and intentionally live beside each object
-- definition because every spawned object can require different alignment.
local HexSpawnDefinitions = {
    {
        key = "tree",
        label = "Tree",
        json = SavedObjectData.tree,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "throne",
        label = "Throne",
        json = SavedObjectData.throne,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "rock1",
        label = "Rock 1",
        json = SavedObjectData.rock1,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "rock2",
        label = "Rock 2",
        json = SavedObjectData.rock2,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "doubleRock",
        label = "Double Rock",
        json = SavedObjectData.doubleRock,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "crystal",
        label = "Crystal",
        json = SavedObjectData.crystal,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "chest",
        label = "Chest",
        json = SavedObjectData.chest,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "cage",
        label = "Cage",
        json = SavedObjectData.cage,
        positionOffset = {x = 0, y = 0.03, z = 0}
    },
    {
        key = "sourceStone",
        label = "Source Stone",
        json = SavedObjectData.sourceStone,
        positionOffset = {x = 0, y = 0.03, z = 0}
    }
}

return HexSpawnDefinitions

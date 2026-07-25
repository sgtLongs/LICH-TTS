local SavedObjectData = require("data/HexGridObjectTemplates")

-- Position offsets use each object's local axes and rotate with the object.
-- They intentionally live beside each object definition because every spawned
-- object can require different alignment.
-- Rotation offsets are degrees added to the direction selected on the grid.
-- Edit click areas are measured in Tabletop Simulator button units. Their
-- position offsets use the spawned object's local axes. Width and height use
-- the object's perspective, so they map to the opposite TTS button fields.
local HexSpawnDefinitions = {
    {
        key = "tree",
        label = "Tree",
        json = SavedObjectData.tree,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = {
            width = 1500,
            height = 9000,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "throne",
        label = "Throne",
        json = SavedObjectData.throne,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 150,
        editClickArea = {
            width = 1400,
            height = 800,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "rock1",
        label = "Rock 1",
        json = SavedObjectData.rock1,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = {
            width = 1400,
            height = 1200,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "rock2",
        label = "Rock 2",
        json = SavedObjectData.rock2,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = {
            width = 1500,
            height = 1200,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "doubleRock",
        label = "Double Rock",
        json = SavedObjectData.doubleRock,
        positionOffset = {x = -1.3, y = 0, z = 0},
        rotationOffsetY = 90,
        occupiesFacingCell = true,
        editClickArea = {
            width = 1500,
            height = 1200,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "crystal",
        label = "Crystal",
        json = SavedObjectData.crystal,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = {
            width = 1400,
            height = 1750,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "chest",
        label = "Chest",
        json = SavedObjectData.chest,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = {
            width = 1400,
            height = 1750,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "cage",
        label = "Cage",
        json = SavedObjectData.cage,
        positionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        editClickArea = {
            width = 1300,
            height = 1500,
            positionOffset = {x = 0, y = 0, z = 0}
        }
    },
    {
        key = "sourceStone",
        label = "Source Stone",
        json = SavedObjectData.sourceStone,
        positionOffset = {x = 0.65, y = 0.2, z = 0.25},
        rotationOffsetY = 30,
        editClickArea = {
            width = 5000,
            height = 1250,
            positionOffset = {x = 5.25, y = -0.5, z = 0}
        }
    }
}

return HexSpawnDefinitions

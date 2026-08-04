local SavedObjectData = require("data/HexGridObjectTemplates")

return {
    key = "deathFog",
    label = "Death Fog",
    json = SavedObjectData.deathFog,
    sourceGuid = "dcc277",
    objectPositionOffset = {x = 0, y = 0.03, z = 0},
    rotationOffsetY = 30,
    isDeathFog = true,
    addEditButtons = false
}

local SurfaceDefinitions = require("src/surfaces/SurfaceDefinitions")
local SurfaceRules = require("src/surfaces/SurfaceRules")

local DeathFogRules = {}
local deathFogSurface = nil

for _, definition in ipairs(SurfaceDefinitions) do
    if definition.key == "deathFog" then
        deathFogSurface = definition
        break
    end
end

function DeathFogRules.getCandidates(
    cells,
    placements,
    templatesByKey,
    cellKey
)
    return SurfaceRules.getOutermostCandidates(
        deathFogSurface,
        cells,
        placements,
        templatesByKey,
        cellKey
    )
end

return DeathFogRules

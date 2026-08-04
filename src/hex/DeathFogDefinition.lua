local SurfaceDefinitions = require("src/surfaces/SurfaceDefinitions")

for _, definition in ipairs(SurfaceDefinitions) do
    if definition.key == "deathFog" then
        return definition.placementTemplate
    end
end

error("SurfaceConfig must define deathFog.")

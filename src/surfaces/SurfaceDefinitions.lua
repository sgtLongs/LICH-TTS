local Config = require("src/config/SurfaceConfig")
local SurfaceTemplateFactory = require(
    "src/surfaces/SurfaceTemplateFactory"
)

local definitions = {}
local keys = {}

for _, settings in ipairs(Config.surfaces) do
    if keys[settings.key] then
        error("Duplicate surface key: " .. tostring(settings.key))
    end

    keys[settings.key] = true
    definitions[#definitions + 1] = {
        key = settings.key,
        label = settings.name,
        color = settings.color,
        opacity = settings.opacity,
        placementTemplate = SurfaceTemplateFactory.build(settings)
    }
end

return definitions

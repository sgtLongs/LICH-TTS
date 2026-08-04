local SavedObjectData = require("data/HexGridObjectTemplates")

local SurfaceTemplateFactory = {}

local function requireUnitValue(value, description)
    if type(value) ~= "number" or value < 0 or value > 1 then
        error(description .. " must be a number from 0 to 1.", 3)
    end

    return value
end

local function formatNumber(value)
    local formatted = string.format("%.6f", value)
    formatted = string.gsub(formatted, "0+$", "")
    formatted = string.gsub(formatted, "%.$", "")
    return formatted
end

local function buildColorJson(settings)
    local color = settings.color

    if type(color) ~= "table" then
        error("Surface " .. tostring(settings.key)
            .. " requires a color table.", 3)
    end

    return '{"r":' .. formatNumber(requireUnitValue(
            color.r,
            "Surface red"
        ))
        .. ',"g":' .. formatNumber(requireUnitValue(
            color.g,
            "Surface green"
        ))
        .. ',"b":' .. formatNumber(requireUnitValue(
            color.b,
            "Surface blue"
        ))
        .. ',"a":' .. formatNumber(requireUnitValue(
            settings.opacity,
            "Surface opacity"
        )) .. "}"
end

local function buildTintedJson(settings)
    local tintedJson, replacementCount = string.gsub(
        SavedObjectData.deathFog,
        '"ColorDiffuse":%b{}',
        '"ColorDiffuse":' .. buildColorJson(settings),
        1
    )

    if replacementCount ~= 1 then
        error("The shared surface model has no root ColorDiffuse.", 3)
    end

    return tintedJson
end

function SurfaceTemplateFactory.build(settings)
    if type(settings) ~= "table"
        or type(settings.key) ~= "string"
        or settings.key == ""
        or type(settings.name) ~= "string"
        or settings.name == ""
    then
        error("Surface settings require a stable key and name.", 2)
    end

    return {
        key = settings.key,
        label = settings.name,
        json = buildTintedJson(settings),
        sourceGuid = settings.sourceGuid,
        objectPositionOffset = {x = 0, y = 0.03, z = 0},
        rotationOffsetY = 30,
        color = settings.color,
        opacity = settings.opacity,
        isSurface = true,
        isDeathFog = settings.isDeathFog == true,
        blocksSurfacePlacement =
            settings.blocksSurfacePlacement == true,
        addEditButtons = false
    }
end

return SurfaceTemplateFactory

local CardFieldDefinitions = {}

local function copyValue(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}

    if seen[value] ~= nil then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy

    for key, child in pairs(value) do
        copy[copyValue(key, seen)] = copyValue(child, seen)
    end

    return copy
end

local function fieldId(field)
    return tostring(
        field.fieldId
            or field.surfaceObjectGuid
            or field.ownerColor
            or field.playerColor
            or field
    )
end

function CardFieldDefinitions.fromConfig(config)
    local snapshot = copyValue(type(config) == "table" and config or {})
    local definitions = {
        config = snapshot,
        fields = {},
        zones = snapshot.zones or {}
    }

    for index, field in ipairs(snapshot.fields or {}) do
        definitions.fields[index] = {
            fieldId = fieldId(field),
            layoutColor = field.playerColor,
            ownerColor = field.ownerColor or field.playerColor,
            surfaceObjectGuid = field.surfaceObjectGuid,
            position = field.position,
            rotationDegrees = field.rotationDegrees or 0,
            size = field.size
        }
    end

    return definitions
end

function CardFieldDefinitions.fieldId(field)
    return fieldId(field)
end

function CardFieldDefinitions.ownerColor(field)
    return field and (field.ownerColor or field.playerColor) or nil
end

return CardFieldDefinitions

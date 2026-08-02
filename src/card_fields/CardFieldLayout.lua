local CardFieldDefinitions =
    require("src/card_fields/CardFieldDefinitions")
local CardFieldGeometry = require("src/card_fields/CardFieldGeometry")

local CardFieldLayout = {}

local function rotateToLocal(field, position)
    local radians = math.rad(field.downRotationDegrees or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)
    local offsetX = position.x - field.position.x
    local offsetZ = position.z - field.position.z

    return {
        x = offsetX * cosine - offsetZ * sine,
        z = offsetX * sine + offsetZ * cosine
    }
end

local function attachZoneLayouts(field, fieldDefinition, config)
    field.zones = {}

    if type(fieldDefinition) ~= "table"
        or type(fieldDefinition.size) ~= "table"
    then
        return
    end

    local columns = tonumber(config.columns)
    local rows = tonumber(config.rows)

    if columns == nil or rows == nil or columns == 0 or rows == 0 then
        return
    end

    local cellWidth = fieldDefinition.size.x / columns
    local cellHeight = fieldDefinition.size.z / rows
    local left = -fieldDefinition.size.x * 0.5
    local top = -fieldDefinition.size.z * 0.5

    for _, zoneDefinition in ipairs(config.zones or {}) do
        local zone = {
            key = zoneDefinition.key,
            type = zoneDefinition.type or zoneDefinition.key,
            label = zoneDefinition.label,
            localLeft = left
                + (zoneDefinition.firstColumn - 1) * cellWidth,
            localTop = top
                + (zoneDefinition.firstRow - 1) * cellHeight,
            localRight = left + zoneDefinition.lastColumn * cellWidth,
            localBottom = top + zoneDefinition.lastRow * cellHeight,
            center = field.zoneCenters
                and field.zoneCenters[zoneDefinition.key] or nil,
            definition = zoneDefinition
        }
        field.zones[#field.zones + 1] = zone
    end
end

function CardFieldLayout.buildAll(definitions)
    if type(definitions) ~= "table" or definitions.config == nil then
        definitions = CardFieldDefinitions.fromConfig(definitions)
    end

    local built = CardFieldGeometry.buildAll(definitions.config)

    for index, field in ipairs(built.fields or {}) do
        local fieldDefinition = definitions.fields[index]
        field.fieldId = fieldDefinition
            and fieldDefinition.fieldId
            or CardFieldDefinitions.fieldId(field)
        field.layoutColor = field.playerColor
        field.ownerColor = field.ownerColor or field.playerColor
        field.definition = fieldDefinition
        attachZoneLayouts(field, fieldDefinition, definitions.config)
    end

    return built
end

function CardFieldLayout.containsZone(field, zone, position)
    if type(field) ~= "table"
        or type(field.position) ~= "table"
        or type(zone) ~= "table"
        or type(position) ~= "table"
        or tonumber(position.x) == nil
        or tonumber(position.z) == nil
    then
        return false
    end

    local localPosition = rotateToLocal(field, position)
    return localPosition.x >= zone.localLeft
        and localPosition.x <= zone.localRight
        and localPosition.z >= zone.localTop
        and localPosition.z <= zone.localBottom
end

function CardFieldLayout.findZone(fields, position, zoneType)
    for _, field in ipairs(fields or {}) do
        for _, zone in ipairs(field.zones or {}) do
            if (zoneType == nil or zone.type == zoneType)
                and CardFieldLayout.containsZone(field, zone, position)
            then
                return field, zone
            end
        end
    end

    return nil, nil
end

function CardFieldLayout.findFieldBySurface(fields, surfaceGuid)
    for _, field in ipairs(fields or {}) do
        if field.surfaceObjectGuid == surfaceGuid then
            return field
        end
    end

    return nil
end

function CardFieldLayout.findFieldById(fields, fieldId)
    if fieldId == nil then
        return nil
    end

    local targetId = tostring(fieldId)

    for _, field in ipairs(fields or {}) do
        if CardFieldDefinitions.fieldId(field) == targetId then
            return field
        end
    end

    return nil
end

function CardFieldLayout.buttonAlignedDeckSpawnPosition(field)
    -- The cabinet's button X axis is mirrored relative to field world X.
    return {
        x = 2 * field.position.x - field.deckSlot.x,
        y = field.deckSlot.y,
        z = field.deckSlot.z
    }
end

return CardFieldLayout

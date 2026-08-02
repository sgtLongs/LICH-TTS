local CardDefinition = {}

local function copyStrings(values)
    local copied = {}

    for _, value in ipairs(values or {}) do
        if type(value) == "string" then
            copied[#copied + 1] = value
        end
    end

    return copied
end

local function nonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

function CardDefinition.new(values)
    values = type(values) == "table" and values or {}
    local identity = values.id
    local images = type(values.images) == "table" and values.images or {}
    local quantity = math.floor(tonumber(values.quantity) or 0)

    if identity == nil or tostring(identity) == "" then
        return nil, "Card definitions require a stable identity."
    end

    if not nonEmptyString(images.front) then
        return nil, "Card definitions require a front image."
    end

    if not nonEmptyString(images.back) then
        return nil, "Card definitions require a back image."
    end

    if quantity <= 0 then
        return nil, "Card definitions require a positive quantity."
    end

    local definition = {
        id = tostring(identity),
        name = tostring(values.name or ""),
        description = tostring(values.description or ""),
        types = copyStrings(values.types),
        images = {
            front = images.front,
            back = images.back
        },
        quantity = quantity,
        featureIds = copyStrings(values.featureIds)
    }

    return definition
end

function CardDefinition.title(definition)
    local types = type(definition.types) == "table"
        and table.concat(definition.types, ", ") or ""

    -- The delimiter is part of the existing TTS container metadata contract;
    -- Hero extraction parses the type list from this exact title shape.
    return tostring(definition.name or "") .. " | " .. types
end

return CardDefinition

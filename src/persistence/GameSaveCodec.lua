local GameSaveCodec = {
    currentSchemaVersion = 1,
    legacySchemaVersion = 0
}

local subsystemKeys = {
    "cardFields",
    "dungeonMap",
    "hexGrid",
    "settings",
    "turnSystem"
}

local function copySubsystems(value)
    local normalized = {
        schemaVersion = GameSaveCodec.currentSchemaVersion
    }

    for _, key in ipairs(subsystemKeys) do
        normalized[key] = type(value) == "table" and value[key] or nil
    end

    return normalized
end

function GameSaveCodec.normalize(value)
    if type(value) ~= "table" then
        return copySubsystems({}), nil
    end

    local rawVersion = value.schemaVersion
    local schemaVersion = rawVersion == nil
        and GameSaveCodec.legacySchemaVersion
        or tonumber(rawVersion)

    if schemaVersion ~= GameSaveCodec.legacySchemaVersion
        and schemaVersion ~= GameSaveCodec.currentSchemaVersion
    then
        return copySubsystems({}), "Unsupported game-save schema version."
    end

    return copySubsystems(value), nil
end

function GameSaveCodec.decode(encodedState, json)
    if encodedState == nil or encodedState == "" then
        return GameSaveCodec.normalize({})
    end

    if json == nil or type(json.decode) ~= "function" then
        return copySubsystems({}), "The JSON decoder is unavailable."
    end

    local succeeded, decoded = pcall(json.decode, encodedState)

    if not succeeded or type(decoded) ~= "table" then
        return copySubsystems({}), "The saved game state is not valid JSON."
    end

    return GameSaveCodec.normalize(decoded)
end

function GameSaveCodec.encode(state, json)
    if json == nil or type(json.encode) ~= "function" then
        error("The JSON encoder is unavailable.", 2)
    end

    local normalized = GameSaveCodec.normalize(state)
    return json.encode(normalized)
end

return GameSaveCodec

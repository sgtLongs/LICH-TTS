local CardFieldDefinitions =
    require("src/card_fields/CardFieldDefinitions")

local CardFieldState = {}

function CardFieldState.new(fields, savedState)
    local state = {deckSpawnedByField = {}}
    local spawnedByPlayer = type(savedState) == "table"
        and savedState.deckSpawnedByPlayer or {}

    if type(spawnedByPlayer) ~= "table" then
        spawnedByPlayer = {}
    end

    for _, field in ipairs(fields or {}) do
        local fieldId = CardFieldDefinitions.fieldId(field)
        local ownerColor = CardFieldDefinitions.ownerColor(field)
        local deckSpawned = spawnedByPlayer[ownerColor] == true
        state.deckSpawnedByField[fieldId] = deckSpawned
        -- Keep this established runtime property for DeckGenerator and callers
        -- that inspect the legacy field value directly.
        field.deckSpawned = deckSpawned
    end

    return state
end

function CardFieldState.isDeckSpawned(state, field)
    local fieldId = CardFieldDefinitions.fieldId(field)
    return state.deckSpawnedByField[fieldId] == true
end

function CardFieldState.setDeckSpawned(state, field, deckSpawned)
    local value = deckSpawned == true
    local fieldId = CardFieldDefinitions.fieldId(field)
    state.deckSpawnedByField[fieldId] = value
    field.deckSpawned = value
    return value
end

function CardFieldState.save(state, fields)
    local deckSpawnedByPlayer = {}

    for _, field in ipairs(fields or {}) do
        local ownerColor = CardFieldDefinitions.ownerColor(field)
        local fieldId = CardFieldDefinitions.fieldId(field)
        local value = field.deckSpawned == true
        state.deckSpawnedByField[fieldId] = value
        deckSpawnedByPlayer[ownerColor] = value
    end

    return {deckSpawnedByPlayer = deckSpawnedByPlayer}
end

return CardFieldState

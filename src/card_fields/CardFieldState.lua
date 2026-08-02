local CardFieldDefinitions =
    require("src/card_fields/CardFieldDefinitions")

local CardFieldState = {}

function CardFieldState.new(fields, savedState)
    local state = {
        deckSpawnedByField = {},
        heroStatsByField = {}
    }
    local spawnedByPlayer = type(savedState) == "table"
        and savedState.deckSpawnedByPlayer or {}
    local statsByPlayer = type(savedState) == "table"
        and savedState.heroStatsByPlayer or {}

    if type(spawnedByPlayer) ~= "table" then
        spawnedByPlayer = {}
    end

    if type(statsByPlayer) ~= "table" then
        statsByPlayer = {}
    end

    for _, field in ipairs(fields or {}) do
        local fieldId = CardFieldDefinitions.fieldId(field)
        local ownerColor = CardFieldDefinitions.ownerColor(field)
        local deckSpawned = spawnedByPlayer[ownerColor] == true
        state.deckSpawnedByField[fieldId] = deckSpawned
        local savedStats = statsByPlayer[ownerColor]
        local heroStats = nil

        if type(savedStats) == "table" then
            local intelligence = tonumber(savedStats.intelligence)
            local health = tonumber(savedStats.health)

            if intelligence ~= nil and health ~= nil then
                heroStats = {
                    intelligence = intelligence,
                    health = health
                }
            end
        end

        state.heroStatsByField[fieldId] = heroStats
        -- Keep this established runtime property for DeckGenerator and callers
        -- that inspect the legacy field value directly.
        field.deckSpawned = deckSpawned
        field.heroStats = heroStats
    end

    return state
end


function CardFieldState.getHeroStats(state, field)
    local fieldId = CardFieldDefinitions.fieldId(field)
    return state.heroStatsByField[fieldId]
end


function CardFieldState.setHeroStats(state, field, heroStats)
    local value = nil

    if type(heroStats) == "table" then
        local intelligence = tonumber(heroStats.intelligence)
        local health = tonumber(heroStats.health)

        if intelligence ~= nil and health ~= nil then
            value = {
                intelligence = intelligence,
                health = health
            }
        end
    end

    local fieldId = CardFieldDefinitions.fieldId(field)
    state.heroStatsByField[fieldId] = value
    field.heroStats = value
    return value
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
    local heroStatsByPlayer = {}

    for _, field in ipairs(fields or {}) do
        local ownerColor = CardFieldDefinitions.ownerColor(field)
        local fieldId = CardFieldDefinitions.fieldId(field)
        local value = field.deckSpawned == true
        state.deckSpawnedByField[fieldId] = value
        deckSpawnedByPlayer[ownerColor] = value

        local heroStats = CardFieldState.getHeroStats(state, field)

        if heroStats ~= nil then
            heroStatsByPlayer[ownerColor] = {
                intelligence = heroStats.intelligence,
                health = heroStats.health
            }
        end
    end

    return {
        deckSpawnedByPlayer = deckSpawnedByPlayer,
        heroStatsByPlayer = heroStatsByPlayer
    }
end

return CardFieldState

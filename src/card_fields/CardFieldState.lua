local CardFieldDefinitions =
    require("src/card_fields/CardFieldDefinitions")

local CardFieldState = {}

function CardFieldState.new(fields, savedState, actionPointCount)
    local state = {
        deckSpawnedByField = {},
        heroStatsByField = {},
        actionPointsUsedByField = {}
    }
    local spawnedByPlayer = type(savedState) == "table"
        and savedState.deckSpawnedByPlayer or {}
    local statsByPlayer = type(savedState) == "table"
        and savedState.heroStatsByPlayer or {}
    local actionPointsByPlayer = type(savedState) == "table"
        and savedState.actionPointsUsedByPlayer or {}

    if type(spawnedByPlayer) ~= "table" then
        spawnedByPlayer = {}
    end

    if type(statsByPlayer) ~= "table" then
        statsByPlayer = {}
    end

    if type(actionPointsByPlayer) ~= "table" then
        actionPointsByPlayer = {}
    end

    actionPointCount = math.max(0, math.floor(
        tonumber(actionPointCount) or 0
    ))

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
        local savedActionPoints = actionPointsByPlayer[ownerColor]
        local actionPointsUsed = {}

        for index = 1, actionPointCount do
            actionPointsUsed[index] = type(savedActionPoints) == "table"
                and savedActionPoints[index] == true or false
        end

        state.actionPointsUsedByField[fieldId] = actionPointsUsed
        -- Keep this established runtime property for DeckGenerator and callers
        -- that inspect the legacy field value directly.
        field.deckSpawned = deckSpawned
        field.heroStats = heroStats
    end

    return state
end

function CardFieldState.getActionPointsUsed(state, field)
    local fieldId = CardFieldDefinitions.fieldId(field)
    return state.actionPointsUsedByField[fieldId] or {}
end

function CardFieldState.toggleActionPoint(state, field, index)
    local actionPointsUsed = CardFieldState.getActionPointsUsed(state, field)

    if type(index) ~= "number" or actionPointsUsed[index] == nil then
        return false
    end

    actionPointsUsed[index] = not actionPointsUsed[index]
    return true
end

function CardFieldState.renewActionPoints(state, field)
    local actionPointsUsed = CardFieldState.getActionPointsUsed(state, field)

    for index = 1, #actionPointsUsed do
        actionPointsUsed[index] = false
    end
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
    local actionPointsUsedByPlayer = {}

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

        local actionPointsUsed = CardFieldState.getActionPointsUsed(
            state,
            field
        )
        local savedActionPoints = {}

        for index = 1, #actionPointsUsed do
            savedActionPoints[index] = actionPointsUsed[index] == true
        end

        actionPointsUsedByPlayer[ownerColor] = savedActionPoints
    end

    return {
        deckSpawnedByPlayer = deckSpawnedByPlayer,
        heroStatsByPlayer = heroStatsByPlayer,
        actionPointsUsedByPlayer = actionPointsUsedByPlayer
    }
end

return CardFieldState

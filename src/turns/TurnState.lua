local TurnState = {}

local phases = {
    "start",
    "main",
    "draw",
    "status",
    "end"
}

local function normalizeSavedIndex(savedState, playerColors)
    local playerCount = #playerColors

    if playerCount == 0 then
        return 0
    end

    if type(savedState) ~= "table" then
        return 1
    end

    if type(savedState.currentTurnColor) == "string" then
        for index, playerColor in ipairs(playerColors) do
            if playerColor == savedState.currentTurnColor then
                return index
            end
        end
    end

    local savedIndex = tonumber(savedState.currentTurnIndex)

    if savedIndex == nil
        or savedIndex < 1
        or savedIndex > playerCount
    then
        return 1
    end

    return math.floor(savedIndex)
end

local function normalizeSavedPhaseIndex(savedState)
    if type(savedState) ~= "table" then
        return 1
    end

    if type(savedState.currentPhase) == "string" then
        for index, phase in ipairs(phases) do
            if phase == savedState.currentPhase then
                return index
            end
        end
    end

    local savedIndex = tonumber(savedState.currentPhaseIndex)

    if savedIndex == nil
        or savedIndex < 1
        or savedIndex > #phases
    then
        return 1
    end

    return math.floor(savedIndex)
end

function TurnState.new(playerColors, savedState)
    local state = {
        playerColors = playerColors,
        currentTurnIndex = normalizeSavedIndex(
            savedState,
            playerColors
        ),
        currentPhaseIndex = normalizeSavedPhaseIndex(savedState)
    }

    return state
end

function TurnState.getCurrentPhase(state)
    return phases[state.currentPhaseIndex]
end

function TurnState.getPhases()
    local result = {}

    for index, phase in ipairs(phases) do
        result[index] = phase
    end

    return result
end

function TurnState.advancePhase(state, playerColor)
    if playerColor ~= TurnState.getCurrentColor(state) then
        return false
    end

    if state.currentPhaseIndex < #phases then
        state.currentPhaseIndex = state.currentPhaseIndex + 1
        return true
    end

    return TurnState.endTurn(state, playerColor)
end

function TurnState.getCurrentColor(state)
    if state.currentTurnIndex == 0 then
        return nil
    end

    return state.playerColors[state.currentTurnIndex]
end

function TurnState.endTurn(state, playerColor)
    local playerCount = #state.playerColors

    if playerCount == 0
        or playerColor ~= TurnState.getCurrentColor(state)
    then
        return false
    end

    state.currentTurnIndex =
        (state.currentTurnIndex % playerCount) + 1
    state.currentPhaseIndex = 1
    return true
end

function TurnState.setPlayerColors(state, playerColors)
    local currentColor = TurnState.getCurrentColor(state)
    local previousColors = state.playerColors
    local previousIndex = state.currentTurnIndex
    state.playerColors = playerColors

    if #playerColors == 0 then
        state.currentTurnIndex = 0
        state.currentPhaseIndex = 1
        return
    end

    state.currentTurnIndex = 1

    for index, playerColor in ipairs(playerColors) do
        if playerColor == currentColor then
            state.currentTurnIndex = index
            return
        end
    end

    state.currentPhaseIndex = 1

    for offset = 1, #previousColors do
        local previousColor = previousColors[
            ((previousIndex + offset - 1) % #previousColors) + 1
        ]

        for index, playerColor in ipairs(playerColors) do
            if playerColor == previousColor then
                state.currentTurnIndex = index
                return
            end
        end
    end
end

function TurnState.setCurrentColor(state, playerColor)
    for index, activeColor in ipairs(state.playerColors) do
        if activeColor == playerColor then
            state.currentTurnIndex = index
            state.currentPhaseIndex = 1
            return true
        end
    end

    return false
end

function TurnState.getSaveState(state)
    return {
        currentTurnIndex = state.currentTurnIndex,
        currentTurnColor = TurnState.getCurrentColor(state),
        currentPhaseIndex = state.currentPhaseIndex,
        currentPhase = TurnState.getCurrentPhase(state)
    }
end

return TurnState

local TurnState = {}

local function normalizeSavedIndex(savedState, playerCount)
    if type(savedState) ~= "table" then
        return 1
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

function TurnState.new(playerColors, savedState)
    local state = {
        playerColors = playerColors,
        currentTurnIndex = normalizeSavedIndex(
            savedState,
            #playerColors
        )
    }

    return state
end

function TurnState.getCurrentColor(state)
    return state.playerColors[state.currentTurnIndex]
end

function TurnState.endTurn(state, playerColor)
    if playerColor ~= TurnState.getCurrentColor(state) then
        return false
    end

    state.currentTurnIndex =
        (state.currentTurnIndex % #state.playerColors) + 1
    return true
end

function TurnState.getSaveState(state)
    return {
        currentTurnIndex = state.currentTurnIndex
    }
end

return TurnState

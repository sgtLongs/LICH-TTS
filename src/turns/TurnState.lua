local TurnState = {}

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

function TurnState.new(playerColors, savedState)
    local state = {
        playerColors = playerColors,
        currentTurnIndex = normalizeSavedIndex(
            savedState,
            playerColors
        )
    }

    return state
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
    return true
end

function TurnState.setPlayerColors(state, playerColors)
    local currentColor = TurnState.getCurrentColor(state)
    state.playerColors = playerColors

    if #playerColors == 0 then
        state.currentTurnIndex = 0
        return
    end

    state.currentTurnIndex = 1

    for index, playerColor in ipairs(playerColors) do
        if playerColor == currentColor then
            state.currentTurnIndex = index
            return
        end
    end
end

function TurnState.getSaveState(state)
    return {
        currentTurnIndex = state.currentTurnIndex,
        currentTurnColor = TurnState.getCurrentColor(state)
    }
end

return TurnState

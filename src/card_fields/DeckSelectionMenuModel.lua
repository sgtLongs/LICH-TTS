local DeckSelectionMenuModel = {}

function DeckSelectionMenuModel.new()
    return {
        activeSelection = nil
    }
end

function DeckSelectionMenuModel.clear(model)
    model.activeSelection = nil
end

function DeckSelectionMenuModel.open(
    model,
    playerColor,
    field,
    spawnPosition
)
    local ownerColor = field ~= nil
        and (field.ownerColor or field.playerColor)

    if playerColor == nil
        or field == nil
        or playerColor ~= ownerColor
    then
        return false
    end

    model.activeSelection = {
        playerColor = playerColor,
        field = field,
        spawnPosition = spawnPosition
    }
    return true
end

function DeckSelectionMenuModel.getSelection(model, playerColor)
    local selection = model.activeSelection

    if selection == nil or selection.playerColor ~= playerColor then
        return nil
    end

    return selection
end

function DeckSelectionMenuModel.takeSelection(model, playerColor)
    local selection = DeckSelectionMenuModel.getSelection(
        model,
        playerColor
    )

    if selection ~= nil then
        model.activeSelection = nil
    end

    return selection
end

return DeckSelectionMenuModel

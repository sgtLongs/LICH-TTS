local HexGridMenuModel = {}

function HexGridMenuModel.new()
    return {
        activeMenu = nil
    }
end

function HexGridMenuModel.clear(model)
    model.activeMenu = nil
end

function HexGridMenuModel.open(
    model,
    playerColor,
    cell,
    placement
)
    model.activeMenu = {
        playerColor = playerColor,
        cell = cell,
        placement = placement
    }

    return model.activeMenu
end

function HexGridMenuModel.getActive(model)
    return model.activeMenu
end

function HexGridMenuModel.belongsToAdmin(
    model,
    playerColor,
    isAdmin
)
    return model.activeMenu ~= nil
        and model.activeMenu.playerColor == playerColor
        and isAdmin ~= nil
        and isAdmin(playerColor)
end

function HexGridMenuModel.markRotationPending(model)
    if model.activeMenu == nil then
        return false
    end

    model.activeMenu.rotationPending = true
    return true
end

return HexGridMenuModel

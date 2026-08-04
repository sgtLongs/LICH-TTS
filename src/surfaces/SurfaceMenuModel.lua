local SurfaceMenuModel = {}

function SurfaceMenuModel.new()
    return {
        activeMenu = nil
    }
end

function SurfaceMenuModel.open(model, playerColor, cell)
    model.activeMenu = {
        playerColor = playerColor,
        cell = cell
    }
    return model.activeMenu
end

function SurfaceMenuModel.clear(model)
    model.activeMenu = nil
end

function SurfaceMenuModel.getActive(model)
    return model.activeMenu
end

function SurfaceMenuModel.belongsTo(model, playerColor)
    return model.activeMenu ~= nil
        and model.activeMenu.playerColor == playerColor
end

return SurfaceMenuModel

local ObjectAdapter = {}

local function invoke(object, methodName, ...)
    if object == nil or type(object[methodName]) ~= "function" then
        return false, nil
    end

    local succeeded, result = pcall(object[methodName], ...)
    return succeeded, result
end

function ObjectAdapter.getButtons(object)
    local succeeded, buttons = invoke(object, "getButtons")
    return succeeded and type(buttons) == "table" and buttons or {}
end

function ObjectAdapter.createButton(object, parameters)
    return invoke(object, "createButton", parameters)
end

function ObjectAdapter.editButton(object, parameters)
    return invoke(object, "editButton", parameters)
end

function ObjectAdapter.removeButton(object, index)
    return invoke(object, "removeButton", index)
end

function ObjectAdapter.clearButtons(object)
    return invoke(object, "clearButtons")
end

function ObjectAdapter.setVectorLines(object, lines)
    local succeeded = invoke(object, "setVectorLines", lines)
    return succeeded
end

function ObjectAdapter.moveSmooth(object, position, collide, fast)
    local succeeded = invoke(
        object,
        "setPositionSmooth",
        position,
        collide,
        fast
    )

    if succeeded then
        return true
    end

    succeeded = invoke(object, "setPosition", position)
    return succeeded
end

function ObjectAdapter.setLock(object, locked)
    local succeeded = invoke(object, "setLock", locked == true)
    return succeeded
end

return ObjectAdapter

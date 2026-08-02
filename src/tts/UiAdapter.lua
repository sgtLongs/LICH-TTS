local UiAdapter = {}
local defaultAdapter = nil

function UiAdapter.patch(id, attribute, value)
    return {
        id = id,
        attribute = attribute,
        value = value
    }
end

function UiAdapter.new(uiApi)
    local adapter = {}

    local function getUi()
        return uiApi or UI
    end

    function adapter.setAttribute(id, attribute, value)
        local ui = getUi()

        if ui == nil or type(ui.setAttribute) ~= "function" then
            return false
        end

        ui.setAttribute(id, attribute, value)
        return true
    end

    function adapter.apply(patches)
        local applied = 0

        for _, patch in ipairs(patches or {}) do
            if adapter.setAttribute(
                patch.id,
                patch.attribute,
                patch.value
            ) then
                applied = applied + 1
            end
        end

        return applied
    end

    return adapter
end


function UiAdapter.default()
    if defaultAdapter == nil then
        defaultAdapter = UiAdapter.new()
    end

    return defaultAdapter
end

function UiAdapter.setDefault(adapter)
    defaultAdapter = adapter or UiAdapter.new()
end

return UiAdapter

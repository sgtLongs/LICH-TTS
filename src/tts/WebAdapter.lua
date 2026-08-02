local WebAdapter = {}
local defaultAdapter = nil

function WebAdapter.new(webRequestApi)
    local adapter = {}

    function adapter.get(url, callback)
        local web = webRequestApi or WebRequest

        if web == nil or type(web.get) ~= "function" then
            callback({
                is_error = true,
                error = "The TTS WebRequest API is unavailable."
            })
            return false
        end

        web.get(url, callback)
        return true
    end

    return adapter
end

function WebAdapter.default()
    if defaultAdapter == nil then
        defaultAdapter = WebAdapter.new()
    end

    return defaultAdapter
end

function WebAdapter.setDefault(adapter)
    defaultAdapter = adapter or WebAdapter.new()
end

return WebAdapter

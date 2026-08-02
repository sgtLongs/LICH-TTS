local Test = {}
local tests = {}
local activeCleanups = nil
local NIL = {}
Test.NIL = NIL

local function describe(value)
    if type(value) == "string" then
        return '"' .. value .. '"'
    end

    return tostring(value)
end

function Test.case(name, testFunction)
    tests[#tests + 1] = {
        name = name,
        run = testFunction
    }
end

function Test.equal(expected, actual, message)
    if expected ~= actual then
        error(
            message
                or "Expected " .. describe(expected)
                    .. ", got " .. describe(actual) .. ".",
            2
        )
    end
end

function Test.near(expected, actual, tolerance, message)
    if math.abs(expected - actual) > tolerance then
        error(
            message
                or "Expected " .. describe(actual) .. " to be within "
                    .. tolerance .. " of " .. describe(expected) .. ".",
            2
        )
    end
end

function Test.truthy(value, message)
    if not value then
        error(message or "Expected a truthy value.", 2)
    end
end

function Test.falsy(value, message)
    if value then
        error(message or "Expected a falsy value.", 2)
    end
end

function Test.nilValue(value, message)
    if value ~= nil then
        error(
            message or "Expected nil, got " .. describe(value) .. ".",
            2
        )
    end
end

function Test.contains(value, expectedFragment, message)
    if type(value) ~= "string"
        or string.find(value, expectedFragment, 1, true) == nil
    then
        error(
            message
                or "Expected " .. describe(value) .. " to contain "
                    .. describe(expectedFragment) .. ".",
            2
        )
    end
end

local function valuesMatch(expected, actual, visited)
    if expected == actual then
        return true
    end

    if type(expected) ~= type(actual) or type(expected) ~= "table" then
        return false
    end

    visited[expected] = visited[expected] or {}

    if visited[expected][actual] then
        return true
    end

    visited[expected][actual] = true

    for key, expectedValue in pairs(expected) do
        if not valuesMatch(expectedValue, actual[key], visited) then
            return false
        end
    end

    for key, _ in pairs(actual) do
        if expected[key] == nil then
            return false
        end
    end

    return true
end

function Test.deepEqual(expected, actual, message)
    if not valuesMatch(expected, actual, {}) then
        error(
            message
                or "Expected deeply equal tables/values, got "
                    .. describe(expected) .. " and " .. describe(actual)
                    .. ".",
            2
        )
    end
end

function Test.raises(callback, expectedFragment, message)
    local succeeded, failure = pcall(callback)

    if succeeded then
        error(message or "Expected the callback to raise an error.", 2)
    end

    if expectedFragment ~= nil then
        Test.contains(tostring(failure), expectedFragment, message)
    end

    return failure
end

function Test.spy(returnValue)
    local calls = {}
    local function spy(...)
        calls[#calls + 1] = {...}
        return returnValue
    end

    return spy, calls
end

function Test.cleanup(callback)
    if activeCleanups == nil then
        error("Test.cleanup must be called from inside a test case.", 2)
    end

    activeCleanups[#activeCleanups + 1] = callback
end

function Test.withGlobals(overrides, callback)
    local previous = {}

    for name, value in pairs(overrides or {}) do
        if _G[name] == nil then
            previous[name] = NIL
        else
            previous[name] = _G[name]
        end

        if value == NIL then
            _G[name] = nil
        else
            _G[name] = value
        end
    end

    local succeeded, first, second, third = pcall(callback)

    for name, value in pairs(previous) do
        if value == NIL then
            _G[name] = nil
        else
            _G[name] = value
        end
    end

    if not succeeded then
        error(first, 0)
    end

    return first, second, third
end

local function snapshotTable(value)
    local snapshot = {}

    for key, child in pairs(value) do
        snapshot[key] = child
    end

    return snapshot
end


local function restoreTable(value, snapshot)
    for key, _ in pairs(value) do
        if snapshot[key] == nil then
            value[key] = nil
        end
    end

    for key, child in pairs(snapshot) do
        value[key] = child
    end
end

function Test.run()
    local failed = 0

    for _, test in ipairs(tests) do
        local globalsBefore = snapshotTable(_G)
        local loadedModules = package.loaded
        local loadedModulesBefore = snapshotTable(loadedModules)
        activeCleanups = {}
        local succeeded, failure = pcall(test.run)
        local cleanupsSucceeded = true
        local cleanupFailure = nil

        for index = #activeCleanups, 1, -1 do
            local cleanupSucceeded, currentFailure = pcall(
                activeCleanups[index]
            )

            if not cleanupSucceeded and cleanupsSucceeded then
                cleanupsSucceeded = false
                cleanupFailure = currentFailure
            end
        end

        activeCleanups = nil
        restoreTable(loadedModules, loadedModulesBefore)
        restoreTable(_G, globalsBefore)

        if succeeded and not cleanupsSucceeded then
            succeeded = false
            failure = cleanupFailure
        end

        if succeeded then
            print("PASS " .. test.name)
        else
            failed = failed + 1
            print("FAIL " .. test.name)
            print("     " .. tostring(failure))
        end
    end

    print("")
    print(#tests .. " tests, " .. failed .. " failures")

    if failed > 0 then
        error(tostring(failed) .. " automated tests failed.")
    end
end

return Test

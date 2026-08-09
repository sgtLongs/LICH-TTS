local Test = {}
local tests = {}
local activeCleanups = nil
local activeModule = nil
local NIL = {}
local MISSING = {}
Test.NIL = NIL

local function describe(value, visited, depth)
    if value == MISSING then
        return "<missing>"
    end

    if type(value) == "string" then
        return '"' .. value .. '"'
    end

    if type(value) ~= "table" then
        return tostring(value)
    end

    visited = visited or {}
    depth = depth or 0

    if visited[value] then
        return "<cycle>"
    end

    if depth >= 2 then
        return "<table>"
    end

    visited[value] = true
    local parts = {}

    for key, child in pairs(value) do
        parts[#parts + 1] = {
            key = key,
            value = describe(child, visited, depth + 1),
        }
    end

    table.sort(parts, function(left, right)
        return tostring(left.key) < tostring(right.key)
    end)

    local rendered = {}

    for _, part in ipairs(parts) do
        rendered[#rendered + 1] = "["
            .. describe(part.key)
            .. "]="
            .. part.value
    end

    visited[value] = nil
    return "{" .. table.concat(rendered, ", ") .. "}"
end

local function copyTags(tags)
    local result = {}

    if type(tags) == "string" then
        result[tags] = true
    elseif type(tags) == "table" then
        for key, value in pairs(tags) do
            if type(key) == "number" then
                result[value] = true
            elseif value then
                result[key] = true
            end
        end
    end

    return result
end

function Test.beginModule(name, tags)
    activeModule = {
        name = name,
        tags = copyTags(tags),
    }
end

function Test.endModule()
    activeModule = nil
end

function Test.case(name, testFunction, tags)
    local caseTags = copyTags(activeModule and activeModule.tags or nil)

    for tag, enabled in pairs(copyTags(tags)) do
        caseTags[tag] = enabled
    end

    local moduleName = activeModule and activeModule.name or "<unknown>"

    tests[#tests + 1] = {
        name = name,
        qualifiedName = moduleName .. " :: " .. name,
        module = moduleName,
        tags = caseTags,
        run = testFunction,
    }
end

function Test.equal(expected, actual, message)
    if expected ~= actual then
        error(
            message
                or "Expected "
                    .. describe(expected)
                    .. ", got "
                    .. describe(actual)
                    .. ".",
            2
        )
    end
end

function Test.near(expected, actual, tolerance, message)
    if math.abs(expected - actual) > tolerance then
        error(
            message
                or "Expected "
                    .. describe(actual)
                    .. " to be within "
                    .. tolerance
                    .. " of "
                    .. describe(expected)
                    .. ".",
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
        error(message or "Expected nil, got " .. describe(value) .. ".", 2)
    end
end

function Test.contains(value, expectedFragment, message)
    if
        type(value) ~= "string"
        or string.find(value, expectedFragment, 1, true) == nil
    then
        error(
            message
                or "Expected "
                    .. describe(value)
                    .. " to contain "
                    .. describe(expectedFragment)
                    .. ".",
            2
        )
    end
end

local function sortedKeys(value)
    local keys = {}

    for key, _ in pairs(value) do
        keys[#keys + 1] = key
    end

    table.sort(keys, function(left, right)
        if type(left) == type(right) then
            return tostring(left) < tostring(right)
        end

        return type(left) < type(right)
    end)

    return keys
end

local function childPath(path, key)
    if type(key) == "string" and string.match(key, "^[%a_][%w_]*$") then
        return path .. "." .. key
    end

    return path .. "[" .. describe(key) .. "]"
end

local function findDifference(expected, actual, path, visited)
    if expected == actual then
        return nil
    end

    if type(expected) ~= type(actual) or type(expected) ~= "table" then
        return path, expected, actual
    end

    visited[expected] = visited[expected] or {}

    if visited[expected][actual] then
        return nil
    end

    visited[expected][actual] = true

    for _, key in ipairs(sortedKeys(expected)) do
        if actual[key] == nil and expected[key] ~= nil then
            return childPath(path, key), expected[key], MISSING
        end

        local differencePath, expectedValue, actualValue = findDifference(
            expected[key],
            actual[key],
            childPath(path, key),
            visited
        )

        if differencePath ~= nil then
            return differencePath, expectedValue, actualValue
        end
    end

    for _, key in ipairs(sortedKeys(actual)) do
        if expected[key] == nil and actual[key] ~= nil then
            return childPath(path, key), MISSING, actual[key]
        end
    end

    return nil
end

function Test.deepEqual(expected, actual, message)
    local path, expectedValue, actualValue =
        findDifference(expected, actual, "$", {})

    if path ~= nil then
        error(
            message
                or "Values differ at "
                    .. path
                    .. ".\n       expected: "
                    .. describe(expectedValue)
                    .. "\n       actual:   "
                    .. describe(actualValue),
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
        calls[#calls + 1] = { ... }
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

local function containsIgnoringCase(value, fragment)
    return string.find(string.lower(value), string.lower(fragment), 1, true)
        ~= nil
end

local function matchesAny(value, fragments)
    if fragments == nil or #fragments == 0 then
        return true
    end

    for _, fragment in ipairs(fragments) do
        if containsIgnoringCase(value, fragment) then
            return true
        end
    end

    return false
end

local function hasAnyTag(test, tags)
    if tags == nil or #tags == 0 then
        return true
    end

    for _, tag in ipairs(tags) do
        if test.tags[tag] then
            return true
        end
    end

    return false
end

local function isSelected(test, options)
    if not matchesAny(test.module, options.files) then
        return false
    end

    if not matchesAny(test.name, options.filters) then
        return false
    end

    if not hasAnyTag(test, options.tags) then
        return false
    end

    if options.excludeTags ~= nil then
        for _, tag in ipairs(options.excludeTags) do
            if test.tags[tag] then
                return false
            end
        end
    end

    if options.failedTests ~= nil and #options.failedTests > 0 then
        local matched = false

        for _, qualifiedName in ipairs(options.failedTests) do
            if test.qualifiedName == qualifiedName then
                matched = true
                break
            end
        end

        if not matched then
            return false
        end
    end

    return true
end

local function writeFailures(path, failures)
    if path == nil then
        return
    end

    local file, openFailure = io.open(path, "w")

    if file == nil then
        print("WARN Could not record failed tests: " .. tostring(openFailure))
        return
    end

    for _, failure in ipairs(failures) do
        file:write(failure.qualifiedName .. "\n")
    end

    file:close()
end

local function clock()
    if type(TEST_CLOCK) == "function" then
        return TEST_CLOCK()
    end

    if os ~= nil and type(os.clock) == "function" then
        local value = os.clock()

        if type(value) == "number" then
            return value
        end
    end

    return 0
end

local function printSlowest(results, count)
    if count == nil or count <= 0 or #results == 0 then
        return
    end

    table.sort(results, function(left, right)
        return left.elapsed > right.elapsed
    end)

    print("")
    print("Slowest tests:")

    for index = 1, math.min(count, #results) do
        local result = results[index]
        print(
            string.format(
                "  %7.2f ms  %s",
                result.elapsed * 1000,
                result.qualifiedName
            )
        )
    end
end

function Test.run(options)
    options = options or {}
    local failed = {}
    local selected = {}
    local timings = {}

    for _, test in ipairs(tests) do
        if isSelected(test, options) then
            selected[#selected + 1] = test
        end
    end

    if #selected == 0 then
        error("No tests matched the requested filters.")
    end

    for _, test in ipairs(selected) do
        local globalsBefore = snapshotTable(_G)
        local loadedModules = package.loaded
        local loadedModulesBefore = snapshotTable(loadedModules)
        activeCleanups = {}
        local startedAt = clock()
        local succeeded, failure = pcall(test.run)
        local elapsed = clock() - startedAt
        local cleanupsSucceeded = true
        local cleanupFailure = nil

        for index = #activeCleanups, 1, -1 do
            local cleanupSucceeded, currentFailure =
                pcall(activeCleanups[index])

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

        timings[#timings + 1] = {
            elapsed = elapsed,
            qualifiedName = test.qualifiedName,
        }

        local timingSuffix = ""

        if options.timing then
            timingSuffix = string.format(" (%.2f ms)", elapsed * 1000)
        end

        if succeeded then
            print("PASS " .. test.name .. timingSuffix)
        else
            failed[#failed + 1] = test
            print("FAIL " .. test.name .. timingSuffix)
            print("     " .. tostring(failure))

            if options.failFast then
                break
            end
        end
    end

    writeFailures(options.failureFile, failed)
    printSlowest(timings, options.slowest)

    print("")
    print(#selected .. " selected tests, " .. #failed .. " failures")

    if #failed > 0 then
        error(tostring(#failed) .. " automated tests failed.")
    end
end

return Test

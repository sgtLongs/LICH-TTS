local Test = {}
local tests = {}

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

function Test.run()
    local failed = 0

    for _, test in ipairs(tests) do
        local succeeded, failure = pcall(test.run)

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

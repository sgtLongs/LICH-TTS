local Test = require("tests/support/Test")

Test.case("deep table assertions identify the mismatched value path", function()
    local succeeded, failure = pcall(function()
        Test.deepEqual(
            { boards = { { rotation = 90 } } },
            { boards = { { rotation = 180 } } }
        )
    end)

    Test.falsy(succeeded)
    Test.contains(tostring(failure), "$.boards[1].rotation")
    Test.contains(tostring(failure), "expected: 90")
    Test.contains(tostring(failure), "actual:   180")
end)

Test.case("deep table assertions report missing and additional keys", function()
    local missingSucceeded, missingFailure = pcall(function()
        Test.deepEqual({ board = { name = "A" } }, { board = {} })
    end)
    local additionalSucceeded, additionalFailure = pcall(function()
        Test.deepEqual({ board = {} }, { board = { name = "A" } })
    end)

    Test.falsy(missingSucceeded)
    Test.contains(tostring(missingFailure), "actual:   <missing>")
    Test.falsy(additionalSucceeded)
    Test.contains(tostring(additionalFailure), "expected: <missing>")
end)

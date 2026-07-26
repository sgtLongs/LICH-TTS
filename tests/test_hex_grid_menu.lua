local Test = require("tests/support/Test")
local HexGridMenu = require("src/hex/HexGridMenu")

Test.case("object editing opens the replacement picker", function()
    local attributes = {}
    local previousUi = UI
    local previousGetObjectsWithTag = getObjectsWithTag

    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    getObjectsWithTag = function()
        return {}
    end

    local board = {
        getButtons = function()
            return {}
        end
    }

    HexGridMenu.initialize({
        board = board,
        isAdmin = function()
            return true
        end
    })
    HexGridMenu.open(
        "Red",
        {},
        {row = 2, column = 3},
        {templateKey = "tree"}
    )

    local addPageActive = attributes["hexGridMenuAddPage.active"]
    local objectPageActive = attributes["hexGridMenuObjectPage.active"]
    UI = previousUi
    getObjectsWithTag = previousGetObjectsWithTag

    Test.equal("false", addPageActive)
    Test.equal("true", objectPageActive)
end)

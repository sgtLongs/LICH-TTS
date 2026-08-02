local Test = require("tests/support/Test")
local FakeTts = require("tests/support/FakeTts")

Test.case("real Global Game and subsystem facades compose on fake TTS", function()
    for moduleName, _ in pairs(package.loaded) do
        if type(moduleName) == "string"
            and string.sub(moduleName, 1, 4) == "src/"
        then
            package.loaded[moduleName] = nil
        end
    end

    local fixture = FakeTts.new()
    local globals = fixture.globals()
    local encodedState = nil
    local vectorLines = nil
    globals.Global = {
        script_state = "",
        setVectorLines = function(lines)
            vectorLines = lines
        end
    }
    globals.JSON = {
        encode = function(value)
            encodedState = value
            return "composition-save"
        end,
        encode_pretty = function()
            return "composition-board"
        end,
        decode = function()
            return {}
        end
    }
    globals.storeRewindState = function(callback)
        callback()
    end

    Test.withGlobals(globals, function()
        dofile(TEST_REPOSITORY_ROOT .. "/Global.lua")
        onLoad("")

        Test.equal("composition-save", onSave())
        Test.equal(1, encodedState.schemaVersion)
        Test.truthy(encodedState.cardFields)
        Test.truthy(encodedState.hexGrid)
        Test.truthy(encodedState.settings)
        Test.truthy(encodedState.dungeonMap)
        Test.truthy(encodedState.turnSystem)
        Test.truthy(type(vectorLines) == "table")

        local config = require("src/config/CardFieldConfig")
        local fieldId = config.fields[1].surfaceObjectGuid
        local destination = getCardFieldDestination({
            fieldId = fieldId,
            destination = "deck"
        })

        Test.truthy(type(destination) == "table")
        Test.truthy(type(destination.x) == "number")
        Test.truthy(type(destination.z) == "number")
        Test.nilValue(getCardFieldDestination("invalid"))
    end)
end)

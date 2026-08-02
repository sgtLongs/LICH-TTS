local Test = require("tests/support/Test")

local objectScriptGlobals = {
    self = Test.NIL,
    JSON = Test.NIL,
    Timer = Test.NIL,
    getAllObjects = Test.NIL,
    onSave = Test.NIL,
    onLoad = Test.NIL,
    onAfterLoad = Test.NIL,
    onButtonClick = Test.NIL,
    HideObjectsAbove = Test.NIL,
    PointToAABBIntersect = Test.NIL,
    IsInRange = Test.NIL,
    Store = Test.NIL,
    Dispense = Test.NIL
}

local function withObjectScript(globals, relativePath, callback)
    local overrides = {}

    for name, value in pairs(objectScriptGlobals) do
        overrides[name] = value
    end

    for name, value in pairs(globals or {}) do
        overrides[name] = value
    end

    Test.withGlobals(overrides, function()
        dofile(TEST_REPOSITORY_ROOT .. "/" .. relativePath)
        callback()
    end)
end

Test.case("cabinet storage preserves legacy lock-state saves", function()
    local encodedState = nil
    local createdButton = nil
    local cabinet = {
        interactable = true,
        guid = "cabinet"
    }

    cabinet.createButton = function(button)
        createdButton = button
    end
    cabinet.getStateId = function()
        return 1
    end

    withObjectScript({
        self = cabinet,
        JSON = {
            decode = function(savedState)
                Test.equal("legacy-lock-state", savedState)
                return {
                    lockedCard = true,
                    unlockedCard = false
                }
            end,
            encode = function(state)
                encodedState = state
                return "encoded-lock-state"
            end
        }
    }, "object_logic/CabinetStorage.lua", function()
        onLoad("legacy-lock-state")

        Test.falsy(cabinet.interactable)
        Test.equal("onButtonClick", createdButton.click_function)
        Test.equal(1000, createdButton.width)
        Test.equal("encoded-lock-state", onSave())
        Test.equal(true, encodedState.lockedCard)
        Test.equal(false, encodedState.unlockedCard)
    end)
end)

Test.case("cabinet storage restores object positions and lock state", function()
    local encodedState = nil
    local lockChanges = {}
    local object = {
        interactable = true,
        position = {x = 2, y = 5, z = 7},
        locked = false
    }

    object.getPosition = function()
        return object.position
    end
    object.getLock = function()
        return object.locked
    end
    object.getGUID = function()
        return "card-guid"
    end
    object.setLock = function(value)
        object.locked = value
        lockChanges[#lockChanges + 1] = value
    end
    object.setPosition = function(position)
        object.position = position
    end

    withObjectScript({
        JSON = {
            encode = function(state)
                encodedState = state
                return "saved"
            end
        }
    }, "object_logic/CabinetStorage.lua", function()
        Store(object)

        Test.falsy(object.interactable)
        Test.equal(-9995, object.position.y)
        Test.equal(true, lockChanges[1])
        onSave()
        Test.equal(false, encodedState["card-guid"])

        Dispense(object)

        Test.truthy(object.interactable)
        Test.equal(5, object.position.y)
        Test.equal(false, lockChanges[2])
        onSave()
        Test.nilValue(encodedState["card-guid"])
    end)
end)

Test.case("board script keeps its customize and lock interaction", function()
    local createdButton = nil
    local editedLabels = {}
    local tint = nil
    local board = {interactable = true}

    board.createButton = function(button)
        createdButton = button
    end
    board.editButton = function(button)
        editedLabels[#editedLabels + 1] = button.label
    end
    board.setColorTint = function(color)
        tint = color
    end

    withObjectScript({self = board}, "object_logic/Board.lua", function()
        onLoad()
        Test.falsy(board.interactable)
        Test.equal("CUSTOMIZE BOARD", createdButton.label)

        onButtonClick()
        Test.truthy(board.interactable)
        Test.deepEqual({1, 1, 1}, tint)
        Test.equal("LOCK BOARD", editedLabels[1])

        onButtonClick()
        Test.falsy(board.interactable)
        Test.equal("CUSTOMIZE BOARD", editedLabels[2])
    end)
end)

Test.case("small object variants retain their distinct behavior", function()
    local createdButton = nil
    local state = 1
    local cabinet = {interactable = true}

    cabinet.createButton = function(button)
        createdButton = button
    end
    cabinet.getStateId = function()
        return state
    end
    cabinet.setState = function(nextState)
        state = nextState
    end

    withObjectScript(
        {self = cabinet},
        "object_logic/CabinetStateToggle.lua",
        function()
            onLoad()
            Test.falsy(cabinet.interactable)
            Test.equal(5000, createdButton.width)
            onButtonClick()
            Test.equal(2, state)
        end
    )

    local decoration = {interactable = true}

    withObjectScript(
        {self = decoration},
        "object_logic/StaticDecoration.lua",
        function()
            onLoad()
            Test.falsy(decoration.interactable)
        end
    )
end)

return true

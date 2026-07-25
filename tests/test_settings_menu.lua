local Test = require("tests/support/Test")
local SettingsMenu = require("src/SettingsMenu")

local attributes = {}
local editModeChanges = {}
local persistCalls = 0

local function initialize(savedState)
    attributes = {}
    editModeChanges = {}
    persistCalls = 0
    Player = {
        Red = {admin = true},
        Blue = {admin = false}
    }
    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    broadcastToColor = function()
    end

    SettingsMenu.initialize({
        setEditMode = function(enabled)
            editModeChanges[#editModeChanges + 1] = enabled
        end,
        persistState = function()
            persistCalls = persistCalls + 1
            return true
        end
    }, savedState)
end

Test.case("settings opens on the general tab", function()
    initialize(nil)
    SettingsMenu.handleAction("Red", "toggle")

    Test.equal("true", attributes["settingsGeneralPage.active"])
    Test.equal("false", attributes["settingsSavePage.active"])
    Test.equal("false", attributes["settingsEditMode.isOn"])
end)

Test.case("edit mode is saved and forwarded to the hex grid", function()
    initialize(nil)
    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.onEditModeChanged("Red", "True")

    Test.truthy(SettingsMenu.getSaveState().editMode)
    Test.equal(true, editModeChanges[#editModeChanges])
    Test.equal(1, persistCalls)
end)

Test.case("saved edit mode is restored during initialization", function()
    initialize({
        schemaVersion = 2,
        editMode = true
    })

    Test.equal(true, editModeChanges[1])
    Test.truthy(SettingsMenu.getSaveState().editMode)
end)

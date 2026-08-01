local Test = require("tests/support/Test")
local SettingsMenu = require("src/SettingsMenu")

local attributes = {}
local editModeChanges = {}
local editModePlayerColors = {}
local persistCalls = 0
local renewedPlayerColor = nil

local function initialize(savedState)
    attributes = {}
    editModeChanges = {}
    editModePlayerColors = {}
    persistCalls = 0
    renewedPlayerColor = nil
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
        setEditMode = function(enabled, playerColor)
            editModeChanges[#editModeChanges + 1] = enabled
            editModePlayerColors[#editModePlayerColors + 1] = playerColor
        end,
        persistState = function()
            persistCalls = persistCalls + 1
            return true
        end,
        renewDeckSlotButton = function(playerColor)
            renewedPlayerColor = playerColor
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

Test.case("players can renew only their own deck spawn button", function()
    initialize(nil)
    SettingsMenu.handleAction("Blue", "toggle")
    SettingsMenu.handleAction("Blue", "renewDeckSpawns")

    Test.equal("Blue", renewedPlayerColor)
    Test.equal(
        "Your deck spawn button was renewed. You may spawn another deck.",
        attributes["settingsMenuStatus.text"]
    )
    Test.equal("false", attributes["settingsEditMode.interactable"])
    Test.equal("false", attributes["settingsSaveTab.interactable"])
end)

Test.case("edit mode defaults off and is forwarded to the hex grid", function()
    initialize(nil)
    SettingsMenu.handleAction("Red", "toggle")
    SettingsMenu.onEditModeChanged("Red", "True")

    Test.truthy(SettingsMenu.getSaveState().editMode)
    Test.equal(true, editModeChanges[#editModeChanges])
    Test.equal("Red", editModePlayerColors[#editModePlayerColors])
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

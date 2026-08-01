local Test = require("tests/support/Test")
local HexGrid = require("src/hex/HexGrid")

Test.case("edit mode number keys select placement objects", function()
    local previousPlayer = Player
    local previousUi = UI
    local previousBroadcastToColor = broadcastToColor
    local messages = {}
    local attributes = {}

    Player = {
        Red = {admin = true},
        Blue = {admin = false}
    }
    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    broadcastToColor = function(message, playerColor)
        messages[#messages + 1] = {
            message = message,
            playerColor = playerColor
        }
    end

    HexGrid.setEditMode(true)

    Test.truthy(HexGrid.onScriptingButtonDown(2, "Red"))
    Test.contains(messages[#messages].message, "Throne selected")
    Test.equal("Red", messages[#messages].playerColor)
    Test.equal(
        "SELECTED: THRONE",
        attributes["hexGridSpawnSelectorStatus.text"]
    )
    Test.equal(
        "#167C5A|#22A878|#105A43|#105A43",
        attributes["hexGridSpawnSelector2.colors"]
    )
    Test.equal("true", attributes["hexGridSpawnSelectorRoot.active"])
    Test.falsy(HexGrid.onScriptingButtonDown(10, "Red"))
    Test.falsy(HexGrid.onScriptingButtonDown(1, "Blue"))

    Test.truthy(HexGrid.onSpawnSelectorUiClicked("Red", "6"))
    Test.equal(
        "SELECTED: CRYSTAL",
        attributes["hexGridSpawnSelectorStatus.text"]
    )

    HexGrid.setEditMode(false)
    Test.equal("false", attributes["hexGridSpawnSelectorRoot.active"])
    Test.falsy(HexGrid.onScriptingButtonDown(1, "Red"))

    Player = previousPlayer
    UI = previousUi
    broadcastToColor = previousBroadcastToColor
end)

Test.case("an empty hex directly starts the selected placement", function()
    local previousBroadcastToColor = broadcastToColor
    local previousGetObjectFromGuid = getObjectFromGUID
    local previousGetObjectsWithTag = getObjectsWithTag
    local previousGlobal = Global
    local previousPlayer = Player
    local previousUi = UI
    local previousWait = Wait
    local attributes = {}
    local vectorLines = {}
    local board = {
        createButton = function()
        end,
        getBounds = function()
            return {
                center = {x = 0, y = 5, z = 0},
                size = {x = 20, y = 2, z = 20}
            }
        end,
        getButtons = function()
            return {}
        end,
        positionToLocal = function(position)
            return position
        end,
        positionToWorld = function(position)
            return position
        end,
        setVectorLines = function(lines)
            vectorLines = lines
        end
    }

    Global = {}
    Player = {
        Red = {
            admin = true,
            getPointerPosition = function()
                return {x = 0, y = 0, z = 0}
            end
        }
    }
    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    Wait = {
        frames = function(callback)
            callback()
        end,
        stop = function()
        end,
        time = function()
            return 1
        end
    }
    broadcastToColor = function()
    end
    getObjectFromGUID = function(guid)
        if guid == "068885" then
            return board
        end
    end
    getObjectsWithTag = function()
        return {}
    end

    HexGrid.onLoad(nil)
    HexGrid.setEditMode(true)
    Test.truthy(HexGrid.onScriptingButtonDown(1, "Red"))
    HexGrid.onClicked("Red", false)

    Test.equal("false", attributes["hexGridMenuRoot.active"])
    Test.truthy(#vectorLines > 91)

    HexGrid.setEditMode(false)
    broadcastToColor = previousBroadcastToColor
    getObjectFromGUID = previousGetObjectFromGuid
    getObjectsWithTag = previousGetObjectsWithTag
    Global = previousGlobal
    Player = previousPlayer
    UI = previousUi
    Wait = previousWait
end)

Test.case("placed object edit menu is limited to edit mode", function()
    local previousBroadcastToColor = broadcastToColor
    local previousDestroyObject = destroyObject
    local previousGetObjectFromGuid = getObjectFromGUID
    local previousGetObjectsWithTag = getObjectsWithTag
    local previousGlobal = Global
    local previousPlayer = Player
    local previousUi = UI
    local previousWait = Wait
    local attributes = {}
    local vectorLines = {}
    local board = {
        createButton = function()
        end,
        getBounds = function()
            return {
                center = {x = 0, y = 5, z = 0},
                size = {x = 20, y = 2, z = 20}
            }
        end,
        getButtons = function()
            return {}
        end,
        positionToLocal = function(position)
            return position
        end,
        positionToWorld = function(position)
            return position
        end,
        setVectorLines = function(lines)
            vectorLines = lines
        end
    }
    local placedObject = {
        addTag = function()
        end,
        createButton = function()
        end,
        getBounds = function()
            return {
                center = {x = 0, y = 1, z = 0}
            }
        end,
        getButtons = function()
            return {}
        end,
        getGUID = function()
            return "tree-guid"
        end,
        positionToLocal = function(position)
            return position
        end
    }

    Global = {}
    Player = {
        Red = {
            admin = true,
            getPointerPosition = function()
                return {x = 0, y = 0, z = 0}
            end
        }
    }
    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    Wait = {
        frames = function(callback)
            callback()
        end,
        stop = function()
        end,
        time = function()
            return 1
        end
    }
    broadcastToColor = function()
    end
    destroyObject = function(object)
    end
    getObjectFromGUID = function(guid)
        if guid == "068885" then
            return board
        end

        if guid == "tree-guid" then
            return placedObject
        end
    end
    getObjectsWithTag = function()
        return {}
    end

    HexGrid.onLoad({
        placedObjects = {
            {
                templateKey = "tree",
                cell = {row = 0, column = 0},
                facingCell = {row = 0, column = 1},
                guid = "tree-guid"
            }
        }
    })
    HexGrid.setEditMode(false)
    HexGrid.onObjectClicked(placedObject, "Red", false)

    Test.equal("false", attributes["hexGridMenuRoot.active"])
    Test.truthy(HexGrid.getSaveState().selectedCells["0:0"])

    HexGrid.onObjectClicked(placedObject, "Red", false)
    Test.falsy(HexGrid.getSaveState().selectedCells["0:0"])

    HexGrid.setEditMode(true)
    HexGrid.onObjectClicked(placedObject, "Red", false)

    Test.equal("true", attributes["hexGridMenuRoot.active"])
    Test.equal("Edit Tree", attributes["hexGridMenuTitle.text"])
    Test.equal(1, #HexGrid.getSaveState().placedObjects)
    Test.truthy(HexGrid.getSaveState().selectedCells["0:0"])
    Test.truthy(#vectorLines > 91)

    HexGrid.setEditMode(false)
    broadcastToColor = previousBroadcastToColor
    destroyObject = previousDestroyObject
    getObjectFromGUID = previousGetObjectFromGuid
    getObjectsWithTag = previousGetObjectsWithTag
    Global = previousGlobal
    Player = previousPlayer
    UI = previousUi
    Wait = previousWait
end)

local Test = require("tests/support/Test")
local Config = require("src/config/HexMenuConfig")
local HexGridMenu = require("src/hex/HexGridMenu")
local HexGridMenuModel = require("src/hex/HexGridMenuModel")
local HexGridMenuView = require("src/hex/HexGridMenuView")
local SpawnDefinitions = require("src/hex/HexSpawnDefinitions")

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

local function withMenu(testFunction)
    local previousDestroyObject = destroyObject
    local previousGetObjectsWithTag = getObjectsWithTag
    local previousUi = UI
    local attributes = {}
    local removedButtons = {}
    local destroyedObjects = {}
    local targetChanges = {}
    local board = {
        getButtons = function()
            return {
                {index = 2, click_function = "onHexGridSpawnTreeClicked"},
                {index = 3, click_function = "unrelated"}
            }
        end,
        removeButton = function(index)
            removedButtons[#removedButtons + 1] = index
        end
    }
    local legacyAnchor = {}

    UI = {
        setAttribute = function(id, attribute, value)
            attributes[id .. "." .. attribute] = value
        end
    }
    getObjectsWithTag = function()
        return {legacyAnchor}
    end
    destroyObject = function(object)
        destroyedObjects[#destroyedObjects + 1] = object
    end

    local context = {
        attributes = attributes,
        board = board,
        destroyedObjects = destroyedObjects,
        removedButtons = removedButtons,
        targetChanges = targetChanges
    }

    HexGridMenu.initialize({
        board = board,
        isAdmin = function(playerColor)
            return playerColor == "Red"
        end,
        onTargetChanged = function(cell)
            targetChanges[#targetChanges + 1] = cell or false
        end,
        onObjectChoice = function()
            return false
        end
    })

    testFunction(context)

    destroyObject = previousDestroyObject
    getObjectsWithTag = previousGetObjectsWithTag
    UI = previousUi
end

Test.case("hex menu initialization removes legacy controls", function()
    withMenu(function(context)
        Test.equal("false", context.attributes["hexGridMenuRoot.active"])
        Test.equal(
            "false",
            context.attributes["hexGridSpawnSelectorRoot.active"]
        )
        Test.equal(1, #context.destroyedObjects)
        Test.equal(1, #context.removedButtons)
        Test.equal(2, context.removedButtons[1])
        Test.equal(false, context.targetChanges[1])
    end)
end)

Test.case("spawn selector highlights the chosen template", function()
    withMenu(function(context)
        HexGridMenu.showSpawnSelector(SpawnDefinitions[3])

        Test.equal(
            "SELECTED: ROCK 1",
            context.attributes["hexGridSpawnSelectorStatus.text"]
        )
        Test.equal(
            "#167C5A|#22A878|#105A43|#105A43",
            context.attributes["hexGridSpawnSelector3.colors"]
        )
        Test.equal(
            "#1A2638|#263A55|#111A28|#111A28",
            context.attributes["hexGridSpawnSelector2.colors"]
        )

        HexGridMenu.hideSpawnSelector()
        Test.equal(
            "false",
            context.attributes["hexGridSpawnSelectorRoot.active"]
        )
    end)
end)

Test.case("hex menu opens a selected empty cell for one player", function()
    withMenu(function(context)
        local cell = {row = -2, column = 3}
        HexGridMenu.open("Red", {}, cell, nil)

        Test.equal("Red", context.attributes["hexGridMenuRoot.visibility"])
        Test.equal("true", context.attributes["hexGridMenuRoot.active"])
        Test.equal(
            "Selected Hex -2, 3",
            context.attributes["hexGridMenuTitle.text"]
        )
        Test.equal(
            "false",
            context.attributes["hexGridMenuDeleteObject.active"]
        )
        Test.equal(cell, context.targetChanges[#context.targetChanges])
    end)
end)

Test.case("hex menu ignores actions from other players and non-admins", function()
    withMenu(function(context)
        local cell = {row = 0, column = 0}
        HexGridMenu.open("Red", {}, cell, nil)
        local before = context.attributes["hexGridMenuRoot.active"]

        HexGridMenu.handleAction("Blue", "close")
        Test.equal(before, context.attributes["hexGridMenuRoot.active"])

        HexGridMenu.open("Blue", {}, cell, nil)
        HexGridMenu.handleAction("Blue", "close")
        Test.equal("true", context.attributes["hexGridMenuRoot.active"])
    end)
end)

Test.case("choosing an object enters rotation selection", function()
    withMenu(function(context)
        local chosen = nil
        local canceledColor = nil
        local cell = {row = 1, column = -1}
        local placement = {templateKey = "tree"}

        HexGridMenu.initialize({
            board = context.board,
            isAdmin = function()
                return true
            end,
            onTargetChanged = function(changedCell)
                context.targetChanges[#context.targetChanges + 1] =
                    changedCell or false
            end,
            onObjectChoice = function(
                template,
                targetCell,
                playerColor,
                replacement
            )
                chosen = {
                    template = template,
                    cell = targetCell,
                    playerColor = playerColor,
                    replacement = replacement
                }
                return true
            end,
            onCancelRotation = function(playerColor)
                canceledColor = playerColor
            end
        })
        HexGridMenu.open("Red", {}, cell, placement)
        HexGridMenu.handleAction("Red", "crystal")

        Test.equal("crystal", chosen.template.key)
        Test.equal(cell, chosen.cell)
        Test.equal("Red", chosen.playerColor)
        Test.equal(placement, chosen.replacement)
        Test.equal(
            "true",
            context.attributes["hexGridMenuRotationPage.active"]
        )
        Test.equal(
            "Rotate Crystal",
            context.attributes["hexGridMenuTitle.text"]
        )

        HexGridMenu.handleAction("Red", "close")
        Test.equal("Red", canceledColor)
        Test.equal("false", context.attributes["hexGridMenuRoot.active"])
        Test.equal(false, context.targetChanges[#context.targetChanges])
    end)
end)

Test.case("delete actions preserve the placement identity", function()
    withMenu(function(context)
        local deleted = nil
        local placement = {templateKey = "throne", guid = "placed-guid"}

        HexGridMenu.initialize({
            board = context.board,
            isAdmin = function()
                return true
            end,
            onDeleteObject = function(value, playerColor)
                deleted = {placement = value, playerColor = playerColor}
            end
        })
        HexGridMenu.open(
            "Red",
            {},
            {row = 0, column = 0},
            placement
        )
        HexGridMenu.handleAction("Red", "delete")

        Test.equal(placement, deleted.placement)
        Test.equal("Red", deleted.playerColor)
    end)
end)

Test.case("hex menu model owns target and permission state", function()
    local model = HexGridMenuModel.new()
    local cell = {row = 2, column = -1}
    local placement = {templateKey = "tree"}

    HexGridMenuModel.open(model, "Red", cell, placement)
    Test.falsy(HexGridMenuModel.belongsToAdmin(
        model,
        "Blue",
        function() return true end
    ))
    Test.falsy(HexGridMenuModel.belongsToAdmin(
        model,
        "Red",
        function() return false end
    ))
    Test.truthy(HexGridMenuModel.belongsToAdmin(
        model,
        "Red",
        function() return true end
    ))
    Test.truthy(HexGridMenuModel.markRotationPending(model))
    Test.truthy(HexGridMenuModel.getActive(model).rotationPending)

    HexGridMenuModel.clear(model)
    Test.equal(nil, HexGridMenuModel.getActive(model))
end)

Test.case("hex menu view snapshots page and open patches", function()
    Test.deepEqual({
        {
            id = Config.ui.addPageId,
            attribute = "active",
            value = "false"
        },
        {
            id = Config.ui.objectPageId,
            attribute = "active",
            value = "true"
        },
        {
            id = Config.ui.rotationPageId,
            attribute = "active",
            value = "false"
        }
    }, HexGridMenuView.buildPagePatch(
        Config,
        Config.ui.objectPageId
    ))

    local templatesByKey = {}

    for _, template in ipairs(SpawnDefinitions) do
        templatesByKey[template.key] = template
    end

    local patches = HexGridMenuView.buildOpenPatch(
        Config,
        templatesByKey,
        {
            playerColor = "Red",
            cell = {row = -2, column = 3},
            placement = nil
        }
    )

    Test.equal(7, #patches)
    Test.deepEqual({
        id = Config.ui.titleId,
        attribute = "text",
        value = "Selected Hex -2, 3"
    }, patches[2])
    Test.deepEqual({
        id = Config.ui.rootId,
        attribute = "active",
        value = "true"
    }, patches[7])
end)

Test.case("constructed hex menu controllers isolate permissions", function()
    local firstPatches = {}
    local secondPatches = {}
    local firstChoices = 0
    local board = {
        getButtons = function() return {} end,
        removeButton = function() end
    }
    local function makeAdapter(target)
        return {
            apply = function(patches)
                target[#target + 1] = patches
            end
        }
    end
    local first = HexGridMenu.new({
        uiAdapter = makeAdapter(firstPatches),
        getObjectsWithTag = function() return {} end,
        destroyObject = function() end
    })
    local second = HexGridMenu.new({
        uiAdapter = makeAdapter(secondPatches),
        getObjectsWithTag = function() return {} end,
        destroyObject = function() end
    })

    first.initialize({
        board = board,
        isAdmin = function(color) return color == "Red" end,
        onObjectChoice = function()
            firstChoices = firstChoices + 1
            return false
        end
    })
    second.initialize({
        board = board,
        isAdmin = function() return true end
    })
    first.open("Red", {}, {row = 0, column = 0}, nil)
    first.handleAction("Blue", "tree")
    second.handleAction("Red", "tree")
    Test.equal(0, firstChoices)

    first.handleAction("Red", "add")
    Test.deepEqual(
        HexGridMenuView.buildPagePatch(Config, Config.ui.objectPageId),
        firstPatches[#firstPatches]
    )
    Test.truthy(#secondPatches > 0)
end)

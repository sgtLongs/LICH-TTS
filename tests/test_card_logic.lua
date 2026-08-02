local Test = require("tests/support/Test")
local CardLogic = require("src/cards/CardLogic")
local Config = require("src/config/CardLogicConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")

Test.case("standalone cards include the tap rotation feature", function()
    local script = CardLogic.build()

    Test.contains(script, 'self.tag == "Card"')
    Test.contains(script, 'tooltip = "tap"')
    Test.contains(script, '"getCardButtonConfig"')
    Test.contains(script, "JSON.decode, encodedConfig")
    Test.contains(script, "refreshButtonConfig()")
    Test.contains(script, "removeExistingFeatureButtons()")
    Test.contains(script, 'button.click_function == "onCardTapped"')
    Test.contains(script, "function refreshCardButtons()")
    Test.contains(script, "self.editButton(parameters)")
    Test.contains(script, "position = cardContext.tapButtonPosition")
    Test.contains(script, "width = cardContext.tapButtonWidth")
    Test.contains(script, "height = cardContext.tapButtonHeight")
    Test.contains(script, 'click_function = "onCardTapped"')
    Test.contains(script, "local actionZoneTapEnabled = true")
    Test.contains(script, "function setActionZoneTapEnabled(parameters)")
    Test.contains(script, "or not actionZoneTapEnabled")
    Test.contains(script, 'state.rotated = not state.rotated')
    Test.contains(script, "local amount = state.rotated and 90 or -90")
    Test.contains(script, "local rotation = self.getRotation()")
    Test.contains(script, "self.setRotationSmooth({")
    Test.contains(script, "y = rotation.y + amount")
    Test.contains(script, "}, false, true)")
    Test.contains(script, "notifyActionZoneRotationChanged(state.rotated)")
    Test.contains(script, '"onActionZoneCardRotationChanged"')
    Test.contains(script, "function getActionZoneTapRotation()")
end)

Test.case("cards in player hands have no scripted buttons", function()
    local script = CardLogic.build()

    Test.contains(script, "local function isCardInHand()")
    Test.contains(script, "player.getHandObjects()")
    Test.contains(script, "if isCardInHand() then")
    Test.contains(script, "and actionZoneTapEnabled")
    Test.contains(script, "and not isCardInHand()")
    Test.contains(script, "if actionButtonsVisible or isCardInHand() then")
    Test.contains(script, "function onPickUp(playerColor)")
    Test.contains(script, "function onDrop(playerColor)")
    Test.contains(script, "Wait.frames(refreshCardButtons, 2)")
end)

Test.case("existing standalone cards receive button config refreshes", function()
    local originalGetAllObjects = getAllObjects
    local editedButtons = {}
    local removedButtons = {}

    getAllObjects = function()
        return {
            {
                tag = "Card",
                getButtons = function()
                    return {
                        {index = 3, click_function = "onCardTapped"},
                        {
                            index = 4,
                            click_function = "onDestroyCardClicked"
                        },
                        {
                            index = 5,
                            click_function = "onDamnCardClicked"
                        },
                        {
                            index = 6,
                            click_function = "onUnequipCardClicked"
                        },
                        {
                            index = 7,
                            click_function = "onReturnCardClicked"
                        },
                        {
                            index = 8,
                            click_function = "onActionButtonAreaClicked"
                        }
                    }
                end,
                editButton = function(parameters)
                    editedButtons[#editedButtons + 1] = parameters
                end,
                removeButton = function(index)
                    removedButtons[#removedButtons + 1] = index
                end
            },
            {
                tag = "Deck",
                getButtons = function()
                    error("Decks should not receive card button refreshes.")
                end
            }
        }
    end

    CardLogic.refreshExistingButtons()
    Test.equal(1, #removedButtons)
    Test.equal(8, removedButtons[1])
    Test.equal(5, #editedButtons)
    Test.equal(3, editedButtons[1].index)
    Test.equal(Config.buttons.tap.width, editedButtons[1].width)
    Test.equal(Config.buttons.tap.height, editedButtons[1].height)
    Test.equal(Config.buttons.tap.position, editedButtons[1].position)
    Test.equal(4, editedButtons[2].index)
    Test.equal(Config.buttons.actionList.width, editedButtons[2].width)
    Test.equal(Config.buttons.actionList.height, editedButtons[2].height)
    Test.equal(Config.buttons.damn.position, editedButtons[3].position)
    Test.equal(Config.buttons.actionList.width, editedButtons[4].width)
    Test.equal(
        Config.buttons.actionList.height,
        editedButtons[5].height
    )
    getAllObjects = originalGetAllObjects
end)

Test.case("card button runtime config exposes current dimensions", function()
    local config = CardLogic.getButtonConfig()

    Test.equal(Config.buttons.tap.width, config.tap.width)
    Test.equal(Config.buttons.tap.height, config.tap.height)
    Test.equal(Config.buttons.actionList.width, config.destroy.width)
    Test.equal(Config.buttons.actionList.height, config.destroy.height)
    Test.equal(Config.buttons.damn.position, config.damn.position)
    Test.equal(Config.buttons.actionList.width, config.unequip.width)
    Test.equal(
        Config.buttons.actionList.height,
        config.returnToHand.height
    )
end)

Test.case("card actions use a two by two layout around the card", function()
    local offset = Config.buttons.actionList.zOffset
    local destroy = Config.buttons.destroy.position
    local damn = Config.buttons.damn.position
    local unequip = Config.buttons.unequip.position
    local returnToHand = Config.buttons.returnToHand.position

    Test.equal(damn.x, destroy.x)
    Test.equal(returnToHand.x, unequip.x)
    Test.equal(damn.z, returnToHand.z)
    Test.equal(destroy.z, unequip.z)
    Test.near(offset, destroy.z - damn.z, 0.000001)
    Test.truthy(damn.x < 0)
    Test.truthy(returnToHand.x > 0)
end)

Test.case("card logic can be extended with opt-in features", function()
    CardLogic.registerFeature(
        "testFeature",
        "registerCardFeature({id = \"testFeature\"})",
        false
    )

    local script = CardLogic.build({"testFeature"})
    Test.contains(script, 'id = "testFeature"')
    Test.falsy(string.find(script, 'id = "rotate90"', 1, true))
end)

Test.case("hovered cards offer movement to their purgatory", function()
    local script = CardLogic.build(nil, {
        purgatoryPosition = {x = 11, y = -1, z = 29},
        abyssPosition = {x = 14, y = -1, z = 29},
        deckPosition = {x = 8, y = 1, z = 29}
    })

    Test.contains(script, "function onHover(playerColor)")
    Test.contains(script, '"destroy", "onDestroyCardClicked"')
    Test.contains(script, "cardContext.destroyButtonPosition")
    Test.contains(script, "cardContext.destroyButtonWidth")
    Test.contains(script, "cardContext.destroyButtonHeight")
    Test.contains(script, '"Move to purgatory"')
    Test.contains(script, '"damn", "onDamnCardClicked"')
    Test.contains(script, '"Move to abyss"')
    Test.contains(script, '"unequip", "onUnequipCardClicked"')
    Test.contains(script, '"Return to bottom of deck"')
    Test.contains(script, '"return", "onReturnCardClicked"')
    Test.contains(script, '"Return to hand"')
    Test.contains(script, "local function isCardTapRotated()")
    Test.contains(script, "position = actionButtonPosition(position)")
    Test.contains(script, "rotation = actionButtonRotation()")
    Test.contains(script, "x = position.z")
    Test.contains(script, "z = -position.x")
    Test.contains(script, "hideActionButtonsDuringCardRotation()")
    Test.contains(script, "return not self.isSmoothMoving()")
    Test.contains(script, "Wait.frames(restoreAfterRotation, 1)")
    Test.contains(script, "function onDamnCardClicked")
    Test.contains(script, "cardContext.abyssPosition")
    Test.contains(script, "function onUnequipCardClicked")
    Test.contains(script, "deck.putObject(self)")
    Test.contains(script, "function onReturnCardClicked")
    Test.contains(script, "self.deal(1, playerColor)")
    Test.contains(script, "local function notifyActionZoneCardLeaving()")
    Test.contains(script, '"onCardLeavesActionZone"')
    local _, actionZoneNotificationCount = string.gsub(
        script,
        "notifyActionZoneCardLeaving%(%s*%)",
        ""
    )
    -- One declaration plus the shared destroy/damn move, unequip, and return.
    Test.equal(4, actionZoneNotificationCount)
    Test.contains(script, "player.getHoverObject() ~= self")
    Test.contains(script, "x = destination.x")
    Test.contains(script, "y = destination.y")
    Test.contains(script, "z = destination.z")
    Test.contains(
        script,
        "purgatoryPosition = {x = 11.000000, y = -1.000000, "
            .. "z = 29.000000}"
    )
    Test.contains(
        script,
        "abyssPosition = {x = 14.000000, y = -1.000000, "
            .. "z = 29.000000}"
    )
    Test.contains(
        script,
        "deckPosition = {x = 8.000000, y = 1.000000, "
            .. "z = 29.000000}"
    )
end)

Test.case("card button positions and debug drawing come from config", function()
    local previousDebug = DebugConfig.drawCardButtons
    local previousTapX = Config.buttons.tap.position.x
    local previousDestroyX = Config.buttons.destroy.position.x
    local previousDestroyZ = Config.buttons.destroy.position.z
    local previousTapWidth = Config.buttons.tap.width
    local previousActionHeight = Config.buttons.actionList.height

    DebugConfig.drawCardButtons = true
    Config.buttons.tap.position.x = 2.25
    Config.buttons.destroy.position.x = 1.8
    Config.buttons.destroy.position.z = -1.5
    Config.buttons.tap.width = 2100
    Config.buttons.actionList.height = 650

    local script = CardLogic.build()

    Test.contains(script, "drawButtons = true")
    Test.contains(
        script,
        "tapButtonPosition = {x = 2.250000, y = 0.300000, "
            .. "z = 0.000000}"
    )
    Test.contains(
        script,
        "destroyButtonPosition = {x = 1.800000, y = 0.300000, "
            .. "z = -1.500000}"
    )
    Test.contains(script, "tapButtonWidth = 2100")
    Test.contains(
        script,
        "tapButtonHeight = " .. tostring(Config.buttons.tap.height)
    )
    Test.contains(script, "destroyButtonWidth = 900")
    Test.contains(script, "destroyButtonHeight = 650")
    Test.contains(script, "label = showDebug and cardContext.tapDebugLabel")

    DebugConfig.drawCardButtons = previousDebug
    Config.buttons.tap.position.x = previousTapX
    Config.buttons.destroy.position.x = previousDestroyX
    Config.buttons.destroy.position.z = previousDestroyZ
    Config.buttons.tap.width = previousTapWidth
    Config.buttons.actionList.height = previousActionHeight
end)

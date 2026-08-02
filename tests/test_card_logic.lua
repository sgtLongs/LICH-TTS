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
    Test.contains(script, "local cardButtonsSuppressed = true")
    Test.contains(script, 'type(self.getZones) == "function"')
    Test.contains(script, "pcall(self.getZones)")
    Test.contains(script, 'zone.tag == "Hand"')
    Test.contains(script, "player.getHandObjects()")
    Test.contains(script, "if isCardInHand() then")
    Test.contains(script, "local function removeAllCardButtons()")
    Test.contains(script, "self.clearButtons()")
    Test.contains(script, "if actionButtonsVisible")
    Test.contains(script, "or cardButtonsSuppressed")
    Test.contains(script, "or isCardInHand()")
    Test.contains(script, "function onPickUp(playerColor)")
    Test.contains(script, "function onDrop(playerColor)")
    Test.contains(script, "local function cardIsReadyForButtons()")
    Test.contains(script, "cardButtonsSuppressed = isCardInHand()")
    Test.contains(script, "self.held_by_color ~= nil")
    Test.contains(script, 'type(self.isSmoothMoving) ~= "function"')
    Test.contains(script, "cardIsReadyForButtons,")
    Test.contains(script, "if hasTapFeature then")
    Test.contains(script, "refreshButtonsAfterMovement()")
    Test.contains(script, "Wait.frames(completeRefresh, 10)")
    Test.contains(script, "Wait.condition(")
    Test.contains(script, 'button.click_function == "onActionStackUpClicked"')
    Test.contains(script, 'button.click_function == "onActionStackDownClicked"')
end)

Test.case("hand zones are detected without waiting for player hand lists", function()
    local previousPlayer = Player
    local cleared = false
    local card = {
        tag = "Card",
        getZones = function()
            return {{tag = "Hand"}}
        end,
        clearButtons = function()
            cleared = true
        end
    }

    Player = nil
    Test.truthy(CardLogic.removeButtonsIfInHand(card))
    Test.truthy(cleared)
    Player = previousPlayer
end)

Test.case("deck exit cleanup removes buttons before hand placement", function()
    local cleared = false
    local card = {
        tag = "Card",
        clearButtons = function()
            cleared = true
        end
    }

    Test.truthy(CardLogic.removeAllButtons(card))
    Test.truthy(cleared)
end)

Test.case("deck draw suppression repeatedly clears buttons until hand entry", function()
    local previousPlayer = Player
    local previousWait = Wait
    local clearCount = 0
    local card = {
        tag = "Card",
        getZones = function()
            return {{tag = "Hand"}}
        end,
        clearButtons = function()
            clearCount = clearCount + 1
        end
    }

    Player = nil
    Wait = {
        frames = function(callback)
            callback()
        end
    }

    CardLogic.suppressButtonsUntilPlaced(card)
    Test.equal(2, clearCount)
    Player = previousPlayer
    Wait = previousWait
end)

Test.case("returned cards are dealt from the bottom of their original deck", function()
    local previousWait = Wait
    local movedPosition = nil
    local dealtArguments = nil
    local clearCount = 0
    local events = {}
    local card = {
        tag = "Card",
        getGUID = function()
            return "return-guid"
        end,
        clearButtons = function()
            clearCount = clearCount + 1
            events[#events + 1] = "clear"
        end,
        setPosition = function(position)
            movedPosition = position
            events[#events + 1] = "move"
        end
    }
    local resultingDeck = {
        tag = "Deck",
        spawning = false,
        loading_custom = false,
        getQuantity = function()
            return 6
        end,
        getObjects = function()
            return {{guid = "return-guid"}}
        end,
        deal = function(...)
            dealtArguments = {...}
            events[#events + 1] = "deal"
            return true
        end
    }
    local deck = {
        tag = "Deck",
        getQuantity = function()
            return 5
        end,
        getPosition = function()
            return {x = 4, y = 2, z = 9}
        end,
        putObject = function(insertedCard)
            Test.equal(card, insertedCard)
            events[#events + 1] = "put"
            return resultingDeck
        end
    }

    Wait = {
        condition = function(callback, condition)
            Test.truthy(condition())
            callback()
        end,
        frames = function(callback)
            callback()
        end
    }

    Test.truthy(CardLogic.returnToHandThroughDeck(card, deck, "Blue"))
    Test.equal(1, clearCount)
    Test.equal(4, movedPosition.x)
    Test.equal(1, movedPosition.y)
    Test.equal(9, movedPosition.z)
    Test.equal(1, dealtArguments[1])
    Test.equal("Blue", dealtArguments[2])
    Test.equal(1, dealtArguments[3])
    Test.equal(true, dealtArguments[4])
    Test.equal("clear", events[1])
    Test.equal("move", events[2])
    Test.equal("put", events[3])
    Test.equal("deal", events[4])
    Wait = previousWait
end)

Test.case("returning beside one remaining card uses the new deck object", function()
    local previousWait = Wait
    local dealCount = 0
    local card = {
        tag = "Card",
        clearButtons = function()
        end,
        setPosition = function()
        end
    }
    local newDeck = {
        tag = "Deck",
        getQuantity = function()
            return 2
        end,
        deal = function(number, color, handIndex, fromBottom)
            Test.equal(1, number)
            Test.equal("Red", color)
            Test.equal(1, handIndex)
            Test.truthy(fromBottom)
            dealCount = dealCount + 1
            return true
        end
    }
    local lastCard = {
        tag = "Card",
        getQuantity = function()
            return -1
        end,
        getPosition = function()
            return {x = 1, y = 1, z = 1}
        end,
        putObject = function()
            return newDeck
        end
    }

    Wait = {
        condition = function(callback, condition)
            Test.truthy(condition())
            callback()
        end,
        frames = function(callback)
            callback()
        end
    }

    Test.truthy(CardLogic.returnToHandThroughDeck(card, lastCard, "Red"))
    Test.equal(1, dealCount)
    Wait = previousWait
end)

Test.case("return-through-deck refuses an unverified bottom insertion", function()
    local putCount = 0
    local card = {
        tag = "Card",
        clearButtons = function()
        end,
        setPosition = function()
            return false
        end
    }
    local deck = {
        tag = "Deck",
        getPosition = function()
            return {x = 1, y = 2, z = 3}
        end,
        putObject = function()
            putCount = putCount + 1
        end
    }

    Test.falsy(CardLogic.returnToHandThroughDeck(card, deck, "Blue"))
    Test.equal(0, putCount)
end)

Test.case("return-through-deck timeout makes a bottom-deal recovery", function()
    local previousWait = Wait
    local dealCount = 0
    local card = {
        tag = "Card",
        clearButtons = function()
        end,
        setPosition = function()
        end
    }
    local resultingDeck = {
        tag = "Deck",
        getQuantity = function()
            return 1
        end,
        deal = function(number, color, handIndex, fromBottom)
            Test.equal(1, number)
            Test.equal("Blue", color)
            Test.equal(1, handIndex)
            Test.truthy(fromBottom)
            dealCount = dealCount + 1
            return true
        end
    }
    local deck = {
        tag = "Deck",
        getQuantity = function()
            return 5
        end,
        getPosition = function()
            return {x = 1, y = 2, z = 3}
        end,
        putObject = function()
            return resultingDeck
        end
    }

    Wait = {
        condition = function(callback, condition, timeout, timeoutCallback)
            Test.falsy(condition())
            timeoutCallback()
        end,
        frames = function(callback)
            callback()
        end
    }

    Test.truthy(CardLogic.returnToHandThroughDeck(card, deck, "Blue"))
    Test.equal(1, dealCount)
    Wait = previousWait
end)

Test.case("an absent deck reloads the card before returning it", function()
    local previousWait = Wait
    local dealtArguments = nil
    local freshCard = {
        tag = "Card",
        getZones = function()
            return {{tag = "Hand"}}
        end,
        clearButtons = function()
        end,
        setLock = function()
        end,
        setScale = function()
        end,
        deal = function(...)
            dealtArguments = {...}
            return true
        end
    }
    local oldCard = {
        tag = "Card",
        clearButtons = function()
        end,
        reload = function()
            return freshCard
        end
    }

    Wait = {
        frames = function(callback)
            callback()
        end
    }

    Test.truthy(CardLogic.reloadAndReturnToHand(oldCard, "Teal"))
    Test.equal(1, dealtArguments[1])
    Test.equal("Teal", dealtArguments[2])
    Test.equal(1, dealtArguments[3])
    Wait = previousWait
end)

Test.case("global cleanup clears every button from cards in hands", function()
    local previousPlayer = Player
    local previousWait = Wait
    local cleared = false
    local card = {
        tag = "Card",
        clearButtons = function()
            cleared = true
        end
    }

    Player = {
        getPlayers = function()
            return {
                {
                    getHandObjects = function()
                        return {card}
                    end
                }
            }
        end
    }
    Wait = {
        frames = function(callback)
            callback()
        end
    }

    CardLogic.scheduleHandButtonCleanup(card)
    Test.truthy(cleared)
    Player = previousPlayer
    Wait = previousWait
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
    Test.contains(script, "local returnToHandInProgress = false")
    Test.contains(script, "or returnToHandInProgress")
    Test.contains(script, "returnToHandInProgress = true")
    Test.falsy(string.find(script, "self.deal(1, playerColor)", 1, true))
    Test.contains(script, "local function normalizeCardBeforeHand()")
    Test.contains(script, "self.setLock(false)")
    Test.contains(script, "self.use_hands = true")
    Test.contains(script, "self.setScale(cardContext.cardScale")
    Test.contains(script, "self.setVelocity({0, 0, 0})")
    Test.contains(script, "self.setAngularVelocity({0, 0, 0})")
    Test.contains(script, '"returnCardToHandThroughDeck"')
    Test.contains(script, "card = self")
    Test.contains(script, "deck = deck")
    Test.contains(script, "playerColor = playerColor")
    Test.contains(script, "Wait.frames(returnAfterBoundsRefresh, 2)")
    Test.contains(script, "local function resetCardTapRotation()")
    Test.contains(script, "rotateState.rotated = false")
    Test.contains(script, "y = rotation.y - 90")
    local returnStart = string.find(
        script,
        "function onReturnCardClicked",
        1,
        true
    )
    local returnCleanup = string.find(
        script,
        "removeAllCardButtons()",
        returnStart,
        true
    )
    local returnSuppression = string.find(
        script,
        "cardButtonsSuppressed = true",
        returnStart,
        true
    )
    local returnRoute = string.find(
        script,
        '"returnCardToHandThroughDeck"',
        returnStart,
        true
    )
    Test.truthy(returnSuppression < returnCleanup)
    Test.truthy(returnCleanup < returnRoute)
    Test.contains(script, "or cardButtonsSuppressed")
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

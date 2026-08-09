local Test = require("tests/support/Test")
local CardLogic = require("src/cards/CardLogic")
local CardFeatureRegistry = require("src/cards/CardFeatureRegistry")
local CardHostService = require("src/cards/CardHostService")
local CardScriptBuilder = require("src/cards/CardScriptBuilder")
local Rotate90 = require("src/cards/features/Rotate90")
local FieldActions = require("src/cards/features/FieldActions")
local Config = require("src/config/CardLogicConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")

Test.case("standalone cards expose actions without a tap button", function()
    local script = CardLogic.build()

    Test.contains(script, 'self.tag == "Card"')
    Test.contains(script, '"actions", "onActionsClicked"')
    Test.contains(script, '"Show or hide card actions"')
    Test.contains(script, '"getCardButtonConfig"')
    Test.contains(script, "JSON.decode, encodedConfig")
    Test.contains(script, "refreshButtonConfig()")
    Test.contains(script, "removeExistingFeatureButtons()")
    Test.contains(script, 'button.click_function == "onCardTapped"')
    Test.contains(script, "function refreshCardButtons(parameters)")
    Test.contains(script, "preserveCardPreview")
    Test.contains(script, "position = actionButtonPosition(position)")
    Test.contains(script, "cardContext.actionsButtonPosition")
    Test.contains(script, "cardContext.actionsButtonWidth")
    Test.contains(script, "cardContext.actionsButtonHeight")
    Test.contains(script, "local actionZoneTapEnabled = true")
    Test.contains(script, "function setActionZoneTapEnabled(parameters)")
    Test.contains(script, "or not actionZoneTapEnabled")
    Test.contains(script, "local function cardTapRotationDegrees(spin)")
    Test.contains(script, "local rotated = not readCardTapRotation()")
    Test.contains(script, "local targetSpin = cardTapRotationTarget(rotated)")
    Test.contains(script, "local rotation = self.getRotation()")
    Test.contains(script, "self.setRotationSmooth({")
    Test.contains(script, "y = targetSpin")
    Test.contains(script, "}, false, true)")
    Test.contains(script, "notifyActionZoneRotationChanged(rotated)")
    Test.contains(script, '"onActionZoneCardRotationChanged"')
    Test.contains(script, "function getActionZoneTapRotation()")
    Test.contains(script, "function onRotate(")
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
                        {index = 9, click_function = "onActionsClicked"},
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
    Test.equal(6, #removedButtons)
    Test.equal(3, removedButtons[1])
    Test.equal(4, removedButtons[2])
    Test.equal(5, removedButtons[3])
    Test.equal(6, removedButtons[4])
    Test.equal(7, removedButtons[5])
    Test.equal(8, removedButtons[6])
    Test.equal(1, #editedButtons)
    Test.equal(9, editedButtons[1].index)
    Test.equal(Config.buttons.actions.width, editedButtons[1].width)
    Test.equal(Config.buttons.actions.height, editedButtons[1].height)
    Test.equal(Config.buttons.actions.position, editedButtons[1].position)
    getAllObjects = originalGetAllObjects
end)

Test.case("host tap rotation supports both side orientations", function()
    Test.truthy(CardLogic.isTappedRotation(90))
    Test.truthy(CardLogic.isTappedRotation(270))
    Test.falsy(CardLogic.isTappedRotation(75))
end)

Test.case("card button runtime config exposes current dimensions", function()
    local config = CardLogic.getButtonConfig()

    Test.equal(Config.buttons.actions.width, config.actions.width)
    Test.equal(Config.buttons.actions.height, config.actions.height)
    Test.equal(
        Config.buttons.actions.liftHeight,
        config.actions.liftHeight
    )
    Test.nilValue(config.destroy)
    Test.nilValue(config.damn)
    Test.nilValue(config.unequip)
    Test.nilValue(config.returnToHand)
end)

Test.case("only the actions trigger has physical button config", function()
    Test.truthy(Config.buttons.actions)
    Test.nilValue(Config.buttons.destroy)
    Test.nilValue(Config.buttons.damn)
    Test.nilValue(Config.buttons.unequip)
    Test.nilValue(Config.buttons.returnToHand)
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

Test.case("card logic accepts first-class feature descriptors", function()
    local registered = CardLogic.registerFeatureDescriptor({
        id = "descriptorFeature",
        stateVersion = 2,
        source = "registerCardFeature({id = \"descriptorFeature\"})"
    })
    local script = CardLogic.build({"descriptorFeature"})

    Test.equal(2, registered.stateVersion)
    Test.contains(script, 'id = "descriptorFeature"')

    local found = false

    for _, descriptor in ipairs(CardLogic.getFeatureDescriptors()) do
        if descriptor.id == "descriptorFeature" then
            found = true
        end
    end

    Test.truthy(found)
end)

Test.case("preview card actions offer movement to their purgatory", function()
    local script = CardLogic.build(nil, {
        purgatoryPosition = {x = 11, y = -1, z = 29},
        abyssPosition = {x = 14, y = -1, z = 29},
        deckPosition = {x = 8, y = 1, z = 29}
    })

    Test.contains(script, "function onActionsClicked")
    Test.contains(script, "function onPreviewCardActionClicked")
    Test.contains(script, "destroy = onDestroyCardClicked")
    Test.contains(script, "damn = onDamnCardClicked")
    Test.contains(script, "unequip = onUnequipCardClicked")
    Test.contains(script, "returnToHand = onReturnCardClicked")
    Test.contains(script, "local function readCardTapRotation(spin)")
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
    Test.contains(script, "writeCardTapRotation(false)")
    Test.contains(script, "local targetSpin = cardTapRotationTarget(false)")
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
    Test.contains(script, "if actionButtonsVisible then")
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

Test.case("card button positions come from config", function()
    local previousDebug = DebugConfig.drawCardButtons
    local previousActionsX = Config.buttons.actions.position.x
    local previousActionsWidth = Config.buttons.actions.width

    Test.cleanup(function()
        DebugConfig.drawCardButtons = previousDebug
        Config.buttons.actions.position.x = previousActionsX
        Config.buttons.actions.width = previousActionsWidth
    end)

    DebugConfig.drawCardButtons = true
    Config.buttons.actions.position.x = 2.25
    Config.buttons.actions.width = 2100

    local script = CardLogic.build()

    Test.contains(script, "drawButtons = true")
    Test.contains(
        script,
        "actionsButtonPosition = {x = 2.250000, y = 0.300000, "
            .. "z = -2.200000}"
    )
    Test.contains(script, "actionsButtonWidth = 2100")
    Test.contains(
        script,
        "actionsButtonHeight = " .. tostring(Config.buttons.actions.height)
    )
    Test.falsy(string.find(script, "destroyButtonPosition", 1, true))
end)

Test.case("card logic preserves its host-side compatibility facade", function()
    Test.equal(
        CardHostService.removeAllButtons,
        CardLogic.removeAllButtons
    )
    Test.equal(
        CardHostService.scheduleHandButtonCleanup,
        CardLogic.scheduleHandButtonCleanup
    )
    Test.equal(
        CardHostService.suppressButtonsUntilPlaced,
        CardLogic.suppressButtonsUntilPlaced
    )
    Test.equal(
        CardHostService.returnToHandThroughDeck,
        CardLogic.returnToHandThroughDeck
    )
    Test.equal(
        CardHostService.reloadAndReturnToHand,
        CardLogic.reloadAndReturnToHand
    )
    Test.equal(CardHostService.isTappedRotation, CardLogic.isTappedRotation)
end)

Test.case("card feature registry owns stable feature descriptors", function()
    local registry = CardFeatureRegistry.new()
    registry:register(Rotate90)
    registry:register(FieldActions)

    local defaults = registry:getDefaultIds()
    Test.equal("rotate90", defaults[1])
    Test.equal("destroyToPurgatory", defaults[2])
    Test.equal(1, registry:get("rotate90").stateVersion)
    Test.equal(1, registry:get("destroyToPurgatory").stateVersion)

    defaults[1] = "changed-outside-registry"
    Test.equal("rotate90", registry:getDefaultIds()[1])

    Test.raises(function()
        registry:register(Rotate90)
    end, "Card feature already registered: rotate90")
end)

Test.case("card script builder derives cleanup from feature descriptors", function()
    local registry = CardFeatureRegistry.new()
    registry:register({
        id = "customButton",
        source = [=[
registerCardFeature({
    id = "customButton"
})
]=],
        buttonCallbacks = {"onCustomCardClicked"}
    })
    local builder = CardScriptBuilder.new({registry = registry})
    local script = builder:build({"customButton"})

    Test.contains(script, 'button.click_function == "onCustomCardClicked"')
    Test.contains(script, 'id = "customButton"')
    Test.falsy(string.find(script, "onDestroyCardClicked", 1, true))
end)

Test.case("built-in card features remain isolated and unknown IDs fail", function()
    local rotateScript = CardLogic.build({"rotate90"})
    local actionsScript = CardLogic.build({"destroyToPurgatory"})

    Test.contains(rotateScript, "notifyActionZoneRotationChanged")
    Test.falsy(string.find(
        rotateScript,
        "onDestroyCardClicked",
        1,
        true
    ))
    Test.falsy(string.find(
        rotateScript,
        "type(config.destroy)",
        1,
        true
    ))
    Test.falsy(string.find(
        rotateScript,
        "type(config.actions)",
        1,
        true
    ))

    Test.contains(actionsScript, "function onDestroyCardClicked")
    Test.contains(actionsScript, "type(config.actions)")
    Test.falsy(string.find(
        actionsScript,
        "notifyActionZoneRotationChanged",
        1,
        true
    ))
    Test.raises(function()
        CardLogic.build({"notRegistered"})
    end, "Unknown card feature: notRegistered")
end)

local Test = require("tests/support/Test")
local CompatibilityFixtures = require(
    "tests/fixtures/compatibility_states"
)
local CardLogic = require("src/cards/CardLogic")

local runtimeGlobalNames = {
    "refreshCardButtons",
    "setActionZoneTapEnabled",
    "getActionZoneTapRotation",
    "onLoad",
    "onPickUp",
    "onDrop",
    "onHover",
    "onCardTapped",
    "onActionsClicked",
    "showCardActionsForPlayer",
    "getCardPreviewImageUrl",
    "releaseCardActionLiftForStackPreview",
    "onPreviewCardActionClicked",
    "hideCardActions",
    "onSave",
    "hideActionButtonsDuringCardRotation",
    "refreshCardActionButtons",
    "onDestroyCardClicked",
    "onDamnCardClicked",
    "onUnequipCardClicked",
    "onReturnCardClicked"
}

local function copyVector(value)
    return {
        x = value.x or value[1],
        y = value.y or value[2],
        z = value.z or value[3]
    }
end

local function runGenerated(options, testFunction)
    options = options or {}
    local savedGlobals = {
        self = self,
        Player = Player,
        Global = Global,
        Wait = Wait,
        JSON = JSON,
        getAllObjects = getAllObjects
    }

    for _, name in ipairs(runtimeGlobalNames) do
        savedGlobals[name] = _G[name]
    end

    local environment = {
        buttons = {},
        clearCount = 0,
        createdButtons = {},
        editedButtons = {},
        removedButtons = {},
        globalCalls = {},
        encodedState = nil,
        pendingConditions = {},
        pendingFrames = {},
        rotation = copyVector(options.rotation or {x = 0, y = 0, z = 0}),
        rotationTargets = {},
        relativeRotations = {},
        smoothPositions = {},
        events = {},
        zones = options.zones or {},
        objects = options.objects or {},
        moving = options.moving == true
    }
    environment.position = copyVector(
        options.position or {x = 0, y = 0, z = 0}
    )
    local nextButtonIndex = 1
    local card = {
        tag = options.tag or "Card",
        held_by_color = options.heldByColor,
        loading_custom = options.loadingCustom == true,
        spawning = options.spawning == true,
        use_hands = false,
        use_gravity = options.useGravity ~= false
    }

    environment.card = card

    card.getButtons = function()
        return environment.buttons
    end
    card.clearButtons = function()
        environment.clearCount = environment.clearCount + 1
        environment.buttons = {}
    end
    card.createButton = function(parameters)
        parameters.index = nextButtonIndex
        nextButtonIndex = nextButtonIndex + 1
        environment.buttons[#environment.buttons + 1] = parameters
        environment.createdButtons[#environment.createdButtons + 1] =
            parameters
    end
    card.removeButton = function(buttonIndex)
        environment.removedButtons[#environment.removedButtons + 1] =
            buttonIndex

        for index = #environment.buttons, 1, -1 do
            if environment.buttons[index].index == buttonIndex then
                table.remove(environment.buttons, index)
            end
        end
    end
    card.editButton = function(parameters)
        environment.editedButtons[#environment.editedButtons + 1] =
            parameters

        for _, button in ipairs(environment.buttons) do
            if button.index == parameters.index then
                for key, value in pairs(parameters) do
                    button[key] = value
                end
            end
        end
    end
    card.getZones = function()
        return environment.zones
    end
    card.isSmoothMoving = function()
        return environment.moving
    end
    card.getRotation = function()
        return copyVector(environment.rotation)
    end
    card.getPosition = function()
        return copyVector(environment.position)
    end
    if not options.noSmoothRotation then
        card.setRotationSmooth = function(rotation, collide, fast)
            environment.rotation = copyVector(rotation)
            environment.rotationTargets[#environment.rotationTargets + 1] = {
                rotation = copyVector(rotation),
                collide = collide,
                fast = fast
            }
        end
    end
    card.setRotation = function(rotation)
        environment.rotation = copyVector(rotation)
    end
    card.rotate = function(rotation)
        local copied = copyVector(rotation)
        environment.relativeRotations[#environment.relativeRotations + 1] =
            copied
        environment.rotation.y = environment.rotation.y + copied.y
    end
    card.setPositionSmooth = function(position, collide, fast)
        environment.position = copyVector(position)
        environment.events[#environment.events + 1] = "move"
        environment.smoothPositions[#environment.smoothPositions + 1] = {
            position = copyVector(position),
            collide = collide,
            fast = fast
        }
    end
    card.setPosition = function(position)
        environment.position = copyVector(position)
    end
    card.setLock = function(value)
        environment.locked = value
    end
    card.setScale = function(value)
        environment.scale = copyVector(value)
    end
    card.setVelocity = function(value)
        environment.velocity = value
    end
    card.setAngularVelocity = function(value)
        environment.angularVelocity = value
    end
    local players = options.players or {}
    Player = {
        getPlayers = function()
            return options.playerList or {}
        end
    }

    for color, player in pairs(players) do
        Player[color] = player
    end

    Wait = {
        condition = function(callback, condition)
            if condition() then
                callback()
            else
                environment.pendingConditions[
                    #environment.pendingConditions + 1
                ] = {callback = callback, condition = condition}
            end
        end,
        frames = function(callback, frameCount)
            if options.deferFrames then
                environment.pendingFrames[#environment.pendingFrames + 1] = {
                    callback = callback,
                    frameCount = frameCount
                }
            else
                callback()
            end
        end
    }

    environment.runConditions = function()
        local pending = environment.pendingConditions
        environment.pendingConditions = {}

        for _, scheduled in ipairs(pending) do
            if scheduled.condition() then
                scheduled.callback()
            else
                environment.pendingConditions[
                    #environment.pendingConditions + 1
                ] = scheduled
            end
        end
    end

    environment.runFrames = function(frameCount)
        local pending = environment.pendingFrames
        environment.pendingFrames = {}

        for _, scheduled in ipairs(pending) do
            if frameCount == nil or scheduled.frameCount == frameCount then
                scheduled.callback()
            else
                environment.pendingFrames[
                    #environment.pendingFrames + 1
                ] = scheduled
            end
        end
    end

    JSON = {
        decode = function(value)
            if value == "invalid" then
                error("invalid JSON")
            end

            if value == "saved-card-state" then
                return options.savedState or {}
            end

            if value == "button-config" then
                return options.buttonConfig or {}
            end

            return {}
        end,
        encode = function(value)
            environment.encodedState = value
            return "encoded-card-state"
        end
    }

    Global = {
        call = function(functionName, parameters)
            environment.globalCalls[#environment.globalCalls + 1] = {
                functionName = functionName,
                parameters = parameters
            }

            if functionName == "getCardButtonConfig" then
                return options.buttonConfig ~= nil
                    and "button-config" or nil
            end

            if functionName == "getCardFieldDestination" then
                local destinations = options.fieldDestinations or {}
                return destinations[parameters.destination]
            end

            if functionName == "showCardPreview"
                or functionName == "hideCardPreview"
            then
                return true
            end

            environment.events[#environment.events + 1] = functionName

            if functionName == "returnCardToHandThroughDeck" then
                return options.returnStarted ~= false
            end
        end
    }

    if options.fieldDestinations ~= nil then
        Global.getVar = function(functionName)
            if functionName == "getCardFieldDestination" then
                return function()
                end
            end
        end
    end
    getAllObjects = function()
        return environment.objects
    end
    self = card

    local succeeded, failure = pcall(function()
        local loader = load or loadstring
        local chunk, loadError = loader(
            CardLogic.build(options.featureNames, options.context),
            "generated-card-runtime"
        )

        if chunk == nil then
            error(loadError)
        end

        chunk()
        testFunction(environment)
    end)

    self = savedGlobals.self
    Player = savedGlobals.Player
    Global = savedGlobals.Global
    Wait = savedGlobals.Wait
    JSON = savedGlobals.JSON
    getAllObjects = savedGlobals.getAllObjects

    for _, name in ipairs(runtimeGlobalNames) do
        _G[name] = savedGlobals[name]
    end

    if not succeeded then
        error(failure, 0)
    end
end

local function findButton(environment, clickFunction)
    for _, button in ipairs(environment.buttons) do
        if button.click_function == clickFunction then
            return button
        end
    end

    return nil
end

Test.case("generated cards restore and persist feature state", function()
    runGenerated({
        savedState = {
            features = {
                rotate90 = {rotated = true},
                destroyToPurgatory = {marker = "kept"}
            }
        }
    }, function(environment)
        onLoad("saved-card-state")

        Test.truthy(getActionZoneTapRotation())
        Test.truthy(findButton(environment, "onActionsClicked"))
        Test.nilValue(findButton(environment, "onCardTapped"))
        Test.equal("encoded-card-state", onSave())
        Test.truthy(environment.encodedState.features.rotate90.rotated)
        Test.equal(
            1,
            environment.encodedState.features.rotate90.stateVersion
        )
        Test.equal(
            "kept",
            environment.encodedState.features.destroyToPurgatory.marker
        )
        Test.equal(
            1,
            environment.encodedState.features.destroyToPurgatory.stateVersion
        )
        Test.equal(
            "onActionZoneCardRotationChanged",
            environment.globalCalls[2].functionName
        )
        Test.truthy(environment.globalCalls[2].parameters.rotated)
    end)
end)

Test.case("generated cards recover from invalid saved state", function()
    runGenerated({}, function(environment)
        onLoad("invalid")
        onSave()

        Test.falsy(environment.encodedState.features.rotate90.rotated)
        Test.truthy(
            type(environment.encodedState.features.destroyToPurgatory)
                == "table"
        )
    end)
end)

Test.case("generated card load ignores non-card objects", function()
    runGenerated({tag = "Deck"}, function(environment)
        onLoad("")

        Test.equal(0, environment.clearCount)
        Test.equal(0, #environment.buttons)
    end)
end)

Test.case("generated cards suppress every button in hand zones", function()
    runGenerated({zones = {{tag = "Hand"}}}, function(environment)
        environment.buttons = {
            {index = 40, click_function = "unrelated"}
        }
        onLoad("")

        Test.equal(0, #environment.buttons)
        Test.truthy(environment.clearCount > 0)
    end)
end)

Test.case("generated pickup and drop restore buttons after movement", function()
    runGenerated({}, function(environment)
        onLoad("")
        Test.truthy(findButton(environment, "onActionsClicked"))
        Test.nilValue(findButton(environment, "onCardTapped"))

        environment.card.held_by_color = "Red"
        environment.moving = true
        onPickUp("Red")

        Test.equal(0, #environment.buttons)
        Test.equal(1, #environment.pendingConditions)

        environment.card.held_by_color = nil
        onDrop("Red")
        Test.equal(2, #environment.pendingConditions)

        environment.runConditions()
        Test.equal(0, #environment.buttons)
        Test.equal(2, #environment.pendingConditions)

        environment.moving = false
        environment.runConditions()

        Test.equal(0, #environment.pendingConditions)
        Test.equal(1, #environment.buttons)
        Test.truthy(findButton(environment, "onActionsClicked"))
        Test.nilValue(findButton(environment, "onCardTapped"))
    end)
end)

Test.case("mechanic-free generated cards preserve load and save state", function()
    runGenerated({
        featureNames = {},
        savedState = {
            rootMarker = "mechanic-free",
            features = {
                futureFeature = {
                    marker = "preserved",
                    stateVersion = 7
                }
            }
        }
    }, function(environment)
        environment.buttons = {
            {index = 41, click_function = "unrelated"}
        }

        onLoad("saved-card-state")

        Test.equal(0, #environment.buttons)
        Test.equal(0, #environment.pendingConditions)
        Test.falsy(getActionZoneTapRotation())
        Test.nilValue(_G.onDestroyCardClicked)
        Test.nilValue(_G.onDamnCardClicked)

        Test.equal("encoded-card-state", onSave())
        Test.equal("mechanic-free", environment.encodedState.rootMarker)
        Test.equal(
            "preserved",
            environment.encodedState.features.futureFeature.marker
        )
        Test.equal(
            7,
            environment.encodedState.features.futureFeature.stateVersion
        )
    end)
end)

Test.case("generated tap toggles exact rotation and saved state", function()
    runGenerated({}, function(environment)
        onLoad("")
        local notificationsBefore = #environment.globalCalls

        onCardTapped({}, "Red", false)
        Test.equal(0, #environment.rotationTargets)

        onCardTapped(environment.card, "Red", false)
        Test.equal(90, environment.rotationTargets[1].rotation.y)
        Test.falsy(environment.rotationTargets[1].collide)
        Test.truthy(environment.rotationTargets[1].fast)
        Test.truthy(getActionZoneTapRotation())

        onCardTapped(environment.card, "Red", true)
        Test.equal(0, environment.rotationTargets[2].rotation.y)
        Test.falsy(getActionZoneTapRotation())
        Test.equal(notificationsBefore + 2, #environment.globalCalls)

        onSave()
        Test.falsy(environment.encodedState.features.rotate90.rotated)
    end)
end)

Test.case("covered generated cards disable and restore their actions", function()
    runGenerated({}, function(environment)
        onLoad("")
        Test.truthy(findButton(environment, "onActionsClicked"))

        setActionZoneTapEnabled({enabled = false})
        Test.nilValue(findButton(environment, "onActionsClicked"))
        onCardTapped(environment.card, "Red", false)
        Test.equal(0, #environment.rotationTargets)

        setActionZoneTapEnabled({enabled = true})
        Test.truthy(findButton(environment, "onActionsClicked"))
    end)
end)

Test.case("generated cards consume runtime button configuration", function()
    runGenerated({
        context = {previewImageUrl = "https://example.test/card.png"},
        buttonConfig = {
            actions = {
                position = {x = 4, y = 5, z = 6},
                width = 777,
                height = 888,
                liftHeight = 2.25
            }
        }
    }, function(environment)
        onLoad("")
        local actions = findButton(environment, "onActionsClicked")

        Test.equal(4, actions.position.x)
        Test.equal(5, actions.position.y)
        Test.equal(6, actions.position.z)
        Test.equal(777, actions.width)
        Test.equal(888, actions.height)
        onActionsClicked(environment.card, "Red", false)
        Test.equal(2.25, environment.position.y)
    end)
end)

Test.case("generated actions button toggles the preview", function()
    runGenerated({
        context = {previewImageUrl = "https://example.test/card.png"},
        position = {x = 2, y = 3, z = 4}
    }, function(environment)
        onLoad("")

        Test.truthy(findButton(environment, "onActionsClicked"))
        Test.nilValue(findButton(environment, "onDestroyCardClicked"))

        onActionsClicked({}, "Red", false)
        Test.equal(1, #environment.buttons)

        onActionsClicked(environment.card, "Red", false)

        Test.nilValue(findButton(environment, "onDestroyCardClicked"))
        Test.nilValue(findButton(environment, "onDamnCardClicked"))
        Test.nilValue(findButton(environment, "onUnequipCardClicked"))
        Test.nilValue(findButton(environment, "onReturnCardClicked"))
        Test.equal(1, #environment.buttons)
        Test.equal(4.5, environment.position.y)
        Test.falsy(environment.card.use_gravity)
        Test.equal(
            "showCardPreview",
            environment.globalCalls[#environment.globalCalls].functionName
        )
        Test.equal(
            "https://example.test/card.png",
            environment.globalCalls[#environment.globalCalls]
                .parameters.imageUrl
        )

        onActionsClicked(environment.card, "Red", false)
        Test.equal(1, #environment.buttons)
        Test.equal(3, environment.position.y)
        Test.truthy(environment.card.use_gravity)
        Test.truthy(findButton(environment, "onActionsClicked"))
        Test.equal(
            "hideCardPreview",
            environment.globalCalls[#environment.globalCalls].functionName
        )

        onActionsClicked(environment.card, "Red", false)
        Test.equal(4.5, environment.position.y)
        Test.truthy(onPreviewCardActionClicked({
            action = "destroy",
            playerColor = "Red"
        }))
        Test.equal(3, environment.position.y)
        Test.nilValue(findButton(environment, "onDestroyCardClicked"))
        Test.equal(
            "hideCardPreview",
            environment.globalCalls[#environment.globalCalls].functionName
        )
    end)
end)

Test.case("generated action previews preserve disabled card gravity", function()
    runGenerated({useGravity = false}, function(environment)
        onLoad("")
        onActionsClicked(environment.card, "Red", false)
        Test.falsy(environment.card.use_gravity)

        onActionsClicked(environment.card, "Red", false)
        Test.falsy(environment.card.use_gravity)
    end)
end)

Test.case("generated cards can open actions from preview navigation", function()
    runGenerated({
        context = {previewImageUrl = "https://example.test/selected.png"},
        position = {x = 1, y = 2, z = 3}
    }, function(environment)
        onLoad("")

        Test.truthy(showCardActionsForPlayer({playerColor = "Blue"}))
        Test.equal(
            "https://example.test/selected.png",
            getCardPreviewImageUrl()
        )
        local showCall = environment.globalCalls[#environment.globalCalls]
        Test.equal(
            "showCardPreview",
            showCall.functionName
        )
        Test.equal(
            "https://example.test/selected.png",
            showCall.parameters.imageUrl
        )

        setActionZoneTapEnabled({
            enabled = false,
            preserveCardPreview = true
        })
        Test.truthy(environment.card.use_gravity)
        Test.equal(2, environment.position.y)
        for _, call in ipairs(environment.globalCalls) do
            Test.falsy(call.functionName == "hideCardPreview")
        end
        Test.truthy(releaseCardActionLiftForStackPreview())
    end)
end)

Test.case("generated destroy and damn actions notify before moving", function()
    runGenerated({
        context = {
            purgatoryPosition = {x = 1, y = 2, z = 3},
            abyssPosition = {x = 4, y = 5, z = 6}
        }
    }, function(environment)
        onLoad("")
        onDestroyCardClicked(environment.card, "Red", false)
        onDamnCardClicked(environment.card, "Red", false)

        Test.equal("onCardLeavesActionZone", environment.events[2])
        Test.equal("move", environment.events[3])
        Test.equal("onCardLeavesActionZone", environment.events[4])
        Test.equal("move", environment.events[5])
        Test.equal(1, environment.smoothPositions[1].position.x)
        Test.equal(3, environment.smoothPositions[1].position.z)
        Test.equal(4, environment.smoothPositions[2].position.x)
        Test.equal(6, environment.smoothPositions[2].position.z)
    end)
end)

Test.case("generated actions resolve a moved field by stable identity", function()
    runGenerated({
        context = {
            fieldId = "field-guid",
            purgatoryPosition = {x = 1, y = 2, z = 3}
        },
        fieldDestinations = {
            purgatory = {x = 40, y = 50, z = 60}
        }
    }, function(environment)
        onLoad("")
        onDestroyCardClicked(environment.card, "Red", false)

        Test.equal(40, environment.smoothPositions[1].position.x)
        Test.equal(50, environment.smoothPositions[1].position.y)
        Test.equal(60, environment.smoothPositions[1].position.z)

        local resolverCall = nil

        for _, call in ipairs(environment.globalCalls) do
            if call.functionName == "getCardFieldDestination" then
                resolverCall = call
                break
            end
        end

        Test.truthy(resolverCall ~= nil)
        Test.equal("field-guid", resolverCall.parameters.fieldId)
        Test.equal("purgatory", resolverCall.parameters.destination)
    end)
end)

Test.case("generated unequip returns below the closest deck", function()
    local acceptedCard = nil
    local nearDeck = {
        tag = "Deck",
        getPosition = function()
            return {x = 10.5, y = 4, z = 10}
        end,
        putObject = function(card)
            acceptedCard = card
        end
    }
    local fartherDeck = {
        tag = "Deck",
        getPosition = function()
            return {x = 11.5, y = 8, z = 10}
        end,
        putObject = function()
            error("The farther deck must not be used.")
        end
    }

    runGenerated({
        savedState = {features = {rotate90 = {rotated = true}}},
        rotation = {x = 0, y = 90, z = 0},
        objects = {fartherDeck, nearDeck},
        context = {deckPosition = {x = 10, y = 4, z = 10}}
    }, function(environment)
        onLoad("saved-card-state")
        onUnequipCardClicked(environment.card, "Red", false)

        Test.equal(environment.card, acceptedCard)
        Test.equal(10.5, environment.position.x)
        Test.equal(3, environment.position.y)
        Test.equal(10, environment.position.z)
        Test.equal(0, environment.rotation.y)
        Test.falsy(getActionZoneTapRotation())
    end)
end)

Test.case("generated return normalizes once and routes after two frames", function()
    local deck = {
        tag = "Deck",
        getPosition = function()
            return {x = 2, y = 3, z = 4}
        end
    }

    runGenerated({
        deferFrames = true,
        objects = {deck},
        players = {Red = {}},
        context = {
            deckPosition = {x = 2, y = 3, z = 4},
            cardScale = {x = 1.2, y = 1.3, z = 1.4}
        }
    }, function(environment)
        onLoad("")
        onReturnCardClicked(environment.card, "Red", false)
        onReturnCardClicked(environment.card, "Red", false)

        Test.equal(1, #environment.pendingFrames)
        Test.equal(2, environment.pendingFrames[1].frameCount)
        Test.equal(0, #environment.smoothPositions)
        Test.falsy(environment.locked)
        Test.truthy(environment.card.use_hands)
        Test.equal(1.2, environment.scale.x)

        environment.runFrames(2)
        local returnCalls = 0

        for _, call in ipairs(environment.globalCalls) do
            if call.functionName == "returnCardToHandThroughDeck" then
                returnCalls = returnCalls + 1
                Test.equal(environment.card, call.parameters.card)
                Test.equal(deck, call.parameters.deck)
                Test.equal("Red", call.parameters.playerColor)
            end
        end

        Test.equal(1, returnCalls)
        Test.equal(0, environment.velocity[1])
        Test.equal(0, environment.angularVelocity[1])
    end)
end)

Test.case("failed generated returns recover their buttons and can retry", function()
    runGenerated({
        deferFrames = true,
        returnStarted = false,
        objects = {},
        players = {Blue = {}},
        context = {deckPosition = {x = 0, y = 0, z = 0}}
    }, function(environment)
        onLoad("")
        onReturnCardClicked(environment.card, "Blue", false)
        environment.runFrames(2)

        Test.truthy(findButton(environment, "onActionsClicked"))
        Test.nilValue(findButton(environment, "onCardTapped"))
        onReturnCardClicked(environment.card, "Blue", false)
        Test.equal(1, #environment.pendingFrames)
    end)
end)

Test.case("generated tap falls back to relative rotation", function()
    runGenerated({noSmoothRotation = true}, function(environment)
        onLoad("")
        onCardTapped(environment.card, "Red", false)

        Test.equal(1, #environment.relativeRotations)
        Test.equal(90, environment.relativeRotations[1].y)
        Test.equal(90, environment.rotation.y)
    end)
end)

Test.case("generated cards migrate legacy feature state without loss", function()
    runGenerated({
        savedState = CompatibilityFixtures.generatedCardLegacy
    }, function(environment)
        onLoad("saved-card-state")
        onSave()

        Test.equal("preserve-root", environment.encodedState.rootMarker)
        Test.equal(
            "rotate",
            environment.encodedState.features.rotate90.marker
        )
        Test.equal(1, environment.encodedState.features.rotate90.stateVersion)
        Test.equal(
            "actions",
            environment.encodedState.features.destroyToPurgatory.marker
        )
        Test.equal(
            1,
            environment.encodedState.features.destroyToPurgatory.stateVersion
        )
        Test.equal(
            "future",
            environment.encodedState.features.futureFeature.marker
        )
    end)
end)

Test.case("generated rotate feature is isolated from field actions", function()
    runGenerated({featureNames = {"rotate90"}}, function(environment)
        onLoad("")
        onHover("Red")

        Test.nilValue(findButton(environment, "onCardTapped"))
        Test.nilValue(findButton(environment, "onActionsClicked"))
        Test.nilValue(findButton(environment, "onDestroyCardClicked"))
        Test.nilValue(_G.onDestroyCardClicked)
    end)
end)

Test.case("generated field actions work without the rotate feature", function()
    runGenerated({
        featureNames = {"destroyToPurgatory"}
    }, function(environment)
        onLoad("")

        Test.nilValue(findButton(environment, "onCardTapped"))
        Test.truthy(findButton(environment, "onActionsClicked"))
        Test.nilValue(findButton(environment, "onDestroyCardClicked"))
        onActionsClicked(environment.card, "Red", false)
        Test.nilValue(findButton(environment, "onDestroyCardClicked"))
        Test.nilValue(findButton(environment, "onDamnCardClicked"))
        Test.equal(1, #environment.buttons)
        onCardTapped(environment.card, "Red", false)
        Test.equal(0, #environment.rotationTargets)
    end)
end)

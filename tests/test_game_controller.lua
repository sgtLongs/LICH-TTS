local Test = require("tests/support/Test")
local CardFields = require("src/card_fields/CardFields")
local GameController = require("src/GameController")

local function subsystem(state)
    return {
        getSaveState = function()
            return state
        end,
        onLoad = function()
        end,
        initialize = function()
        end
    }
end

local function dependencies(overrides)
    local values = {
        cardFields = subsystem({name = "cards"}),
        cardLogic = {
            getButtonConfig = function()
                return {}
            end,
            refreshExistingButtons = function()
            end
        },
        dungeonMap = subsystem({name = "dungeon"}),
        hexGrid = subsystem({name = "hex"}),
        settingsMenu = subsystem({name = "settings"}),
        turnSystem = subsystem({name = "turns"}),
        runtime = {
            setGlobalScriptState = function()
                return true
            end,
            storeRewindState = function()
            end,
            log = function()
            end
        },
        json = {
            encode = function(value)
                return value
            end,
            decode = function(value)
                return value
            end
        }
    }

    values.cardFields.refreshDeckSlotGlow = function()
    end
    values.turnSystem.refreshUi = function()
    end

    for key, value in pairs(overrides or {}) do
        values[key] = value
    end

    return values
end

Test.case("game controller requires its subsystem boundaries", function()
    local values = dependencies()
    values.hexGrid = nil

    Test.raises(function()
        GameController.new(values)
    end, "requires hexGrid")
end)

Test.case("game controller emits the versioned aggregate save", function()
    local controller = GameController.new(dependencies())
    local state = controller:onSave()

    Test.equal(1, state.schemaVersion)
    Test.equal("cards", state.cardFields.name)
    Test.equal("dungeon", state.dungeonMap.name)
    Test.equal("hex", state.hexGrid.name)
    Test.equal("settings", state.settings.name)
    Test.equal("turns", state.turnSystem.name)
end)

Test.case("game controller accepts a constructed card-fields port", function()
    local values = dependencies()
    values.cardFields = CardFields.new()
    local state = GameController.new(values):onSave()

    Test.equal(1, state.schemaVersion)
    Test.deepEqual({}, state.cardFields.deckSpawnedByPlayer)
end)

Test.case("card previews are player scoped and owned by the opening card", function()
    local attributes = {}
    local hiddenCards = {}
    local highlights = {}
    local card = {
        highlightOn = function(color, duration)
            highlights.card = {color = color, duration = duration}
        end,
        highlightOff = function()
            highlights.card = nil
        end,
        call = function(functionName)
            Test.equal("hideCardActions", functionName)
            hiddenCards[#hiddenCards + 1] = "card"
        end
    }
    local otherCard = {
        highlightOn = function(color, duration)
            highlights.other = {color = color, duration = duration}
        end,
        highlightOff = function()
            highlights.other = nil
        end,
        call = function(functionName)
            Test.equal("hideCardActions", functionName)
            hiddenCards[#hiddenCards + 1] = "other"
        end
    }
    local values = dependencies({
        uiAdapter = {
            setAttribute = function(id, attribute, value)
                attributes[id .. "." .. attribute] = value
            end
        }
    })
    values.cardLogic.getPreviewConfig = function()
        return {
            rootId = "preview",
            imageId = "previewImage",
            glowColor = {r = 0.8, g = 0.3, b = 0.1}
        }
    end
    values.hexGrid.onPlayerAction = function()
        return "player-action-result"
    end
    local controller = GameController.new(values)

    Test.truthy(controller:showCardPreview(
        card,
        "Red",
        "https://example.test/card.png"
    ))
    Test.equal(
        "https://example.test/card.png",
        attributes["previewImage.image"]
    )
    Test.equal("Red", attributes["preview.visibility"])
    Test.equal("true", attributes["preview.active"])
    Test.equal(0.8, highlights.card.color.r)
    Test.equal(0.3, highlights.card.color.g)
    Test.equal(0.1, highlights.card.color.b)
    Test.nilValue(highlights.card.duration)

    Test.falsy(controller:hideCardPreview(otherCard, "Red"))
    Test.equal("true", attributes["preview.active"])
    Test.truthy(highlights.card)
    Test.truthy(controller:hideCardPreview(card, "Red"))
    Test.equal("false", attributes["preview.active"])
    Test.nilValue(highlights.card)
    Test.equal("card", hiddenCards[1])

    Test.truthy(controller:showCardPreview(card, "Red", "red.png"))
    Test.truthy(controller:showCardPreview(otherCard, "Blue", "blue.png"))
    Test.equal("card", hiddenCards[2])
    Test.nilValue(highlights.card)
    Test.truthy(highlights.other)
    Test.equal("Blue", attributes["preview.visibility"])

    Test.equal(
        "player-action-result",
        controller:onPlayerAction({color = "Red"}, "Select", {})
    )
    Test.equal("true", attributes["preview.active"])
    Test.equal(
        "player-action-result",
        controller:onPlayerAction({color = "Blue"}, "Select", {})
    )
    Test.equal("false", attributes["preview.active"])
    Test.equal("other", hiddenCards[3])
    Test.nilValue(highlights.other)
end)

Test.case("preview action buttons invoke only the owning player's card", function()
    local calls = {}
    local attributes = {}
    local card = {
        call = function(functionName, parameters)
            calls[#calls + 1] = {
                functionName = functionName,
                parameters = parameters
            }
            return functionName == "onPreviewCardActionClicked"
        end
    }
    local values = dependencies({
        uiAdapter = {
            setAttribute = function(id, attribute, value)
                attributes[id .. "." .. attribute] = value
            end
        }
    })
    values.cardLogic.getPreviewConfig = function()
        return {rootId = "preview", imageId = "previewImage"}
    end
    local controller = GameController.new(values)

    Test.truthy(controller:showCardPreview(card, "Red", "card.png"))
    Test.falsy(controller:onCardPreviewActionClicked("Blue", "destroy"))
    Test.falsy(controller:onCardPreviewActionClicked("Red", "unknown"))
    Test.truthy(controller:onCardPreviewActionClicked("Red", "damn"))
    Test.equal("false", attributes["preview.active"])
    Test.equal("hideCardActions", calls[1].functionName)
    Test.equal("onPreviewCardActionClicked", calls[2].functionName)
    Test.equal("damn", calls[2].parameters.action)
    Test.equal("Red", calls[2].parameters.playerColor)
end)

Test.case("preview arrows move the preview to the selected stack card", function()
    local scheduled = {}
    local calls = {}
    local movedCards = {}
    local controller = nil
    local currentPosition = {x = 0, y = 2, z = 0}
    local currentCard = {
        tag = "Card",
        use_gravity = true,
        highlightOn = function()
        end,
        highlightOff = function()
        end,
        call = function(functionName)
            if functionName == "getCardPreviewImageUrl" then
                return "current.png"
            end

            if functionName == "releaseCardActionLiftForStackPreview" then
                -- Older saved scripts may not acknowledge this callback.
                return nil
            end

            calls[#calls + 1] = {card = "current", name = functionName}
        end,
        getPosition = function()
            return currentPosition
        end,
        setPositionSmooth = function(position)
            currentPosition = position
            movedCards[#movedCards + 1] = "current"
        end
    }
    local selectedCard = nil
    local selectedPosition = {x = 0, y = 2, z = 0}
    selectedCard = {
        tag = "Card",
        use_gravity = true,
        highlightOn = function()
        end,
        highlightOff = function()
        end,
        call = function(functionName, parameters)
            if functionName == "getCardPreviewImageUrl" then
                return "selected.png"
            end

            calls[#calls + 1] = {
                card = "selected",
                name = functionName,
                parameters = parameters
            }
        end,
        getPosition = function()
            return selectedPosition
        end,
        setPositionSmooth = function(position)
            selectedPosition = position
            movedCards[#movedCards + 1] = "selected"
        end
    }
    local attributes = {}
    local values = dependencies({
        uiAdapter = {
            setAttribute = function(id, attribute, value)
                attributes[id .. "." .. attribute] = value
            end
        },
        scheduleFrames = function(callback, frameCount)
            scheduled[#scheduled + 1] = {
                callback = callback,
                frameCount = frameCount
            }
        end
    })
    values.cardLogic.getPreviewConfig = function()
        return {rootId = "preview", imageId = "previewImage"}
    end
    values.cardLogic.getButtonConfig = function()
        return {actions = {liftHeight = 1.5}}
    end
    values.hexGrid.onPlayerAction = function()
    end
    local selectedIndex = 1
    local navigationContexts = {}
    values.cardFields.getActionStackCards = function(card)
        Test.truthy(card == currentCard or card == selectedCard)
        local positions = selectedIndex == 1 and {
            {x = 0, y = 2.4, z = 0},
            {x = 0, y = 2, z = 0}
        } or {
            {x = 0, y = 2, z = 0},
            {x = 0, y = 2.4, z = 0}
        }
        return {currentCard, selectedCard}, selectedIndex, positions
    end
    values.cardFields.navigateActionStack = function(
        card,
        direction,
        context
    )
        Test.equal(
            selectedIndex == 1 and currentCard or selectedCard,
            card
        )
        navigationContexts[#navigationContexts + 1] = context
        selectedIndex = selectedIndex + direction
        return selectedIndex == 1 and currentCard or selectedCard
    end
    controller = GameController.new(values)

    Test.truthy(controller:showCardPreview(
        currentCard,
        "Red",
        "current.png"
    ))
    Test.falsy(controller:onCardPreviewStackClicked("Blue", "down"))
    Test.falsy(controller:onCardPreviewStackClicked("Red", "sideways"))
    Test.equal(1, scheduled[1].frameCount)
    scheduled[1].callback()
    Test.equal(3.5, selectedPosition.y)
    Test.falsy(selectedCard.use_gravity)

    controller:onPlayerAction({color = "Red"}, "Select", {})
    Test.truthy(controller:onCardPreviewStackClicked("Red", "down"))
    Test.equal("true", attributes["preview.active"])
    Test.equal(0, #calls)
    Test.truthy(navigationContexts[1].preserveCardPreview)
    Test.falsy(controller:hideCardPreview(currentCard, "Red"))
    Test.equal("true", attributes["preview.active"])
    Test.equal(1, scheduled[2].frameCount)
    Test.equal(2, scheduled[3].frameCount)
    Test.equal(2, scheduled[4].frameCount)
    controller:onPlayerAction({color = "Red"}, "Select", {})
    Test.equal(4, #scheduled)
    scheduled[2].callback()
    Test.equal(0, #calls)
    scheduled[3].callback()
    scheduled[4].callback()
    Test.equal(3.5, currentPosition.y)
    Test.equal(3.9, selectedPosition.y)
    Test.equal("selected.png", attributes["previewImage.image"])
    Test.equal("true", attributes["preview.active"])

    Test.truthy(controller:onActionStackUpClicked(selectedCard, "Red"))
    Test.equal("current.png", attributes["previewImage.image"])
    Test.equal("true", attributes["preview.active"])
    Test.equal(1, selectedIndex)
    Test.truthy(navigationContexts[2].preserveCardPreview)
    Test.equal(2, scheduled[5].frameCount)
    Test.equal(2, scheduled[6].frameCount)
    movedCards = {}
    scheduled[6].callback()
    Test.equal(3.9, currentPosition.y)
    Test.equal(3.5, selectedPosition.y)
    Test.deepEqual({"selected", "current"}, movedCards)

    Test.truthy(controller:onCardPreviewStackClicked("Red", "down"))
    scheduled[8].callback()
    Test.equal(3.5, currentPosition.y)
    Test.equal(3.9, selectedPosition.y)

    local scheduledBeforeStackSelection = #scheduled
    controller:onPlayerAction(
        {color = "Red"},
        "Select",
        {selectedCard}
    )
    controller:onPlayerAction({color = "Red"}, "Select", {})
    controller:onPlayerAction({color = "Red"}, "Select", {})
    Test.equal(scheduledBeforeStackSelection, #scheduled)
end)

Test.case("preview arrows support cards from older generated saves", function()
    local scheduled = nil
    local position = {x = 1, y = 2, z = 3}
    local highlighted = false
    local currentCard = {
        call = function()
        end
    }
    local legacyCard = {
        tag = "Card",
        use_gravity = true,
        call = function()
            return nil
        end,
        getData = function()
            return {
                CardID = 400,
                CustomDeck = {
                    [4] = {FaceURL = "legacy.png"}
                }
            }
        end,
        getPosition = function()
            return position
        end,
        setPositionSmooth = function(target)
            position = target
        end,
        highlightOn = function()
            highlighted = true
        end,
        highlightOff = function()
            highlighted = false
        end
    }
    local attributes = {}
    local values = dependencies({
        uiAdapter = {
            setAttribute = function(id, attribute, value)
                attributes[id .. "." .. attribute] = value
            end
        },
        scheduleFrames = function(callback)
            scheduled = callback
        end
    })
    values.cardLogic.getPreviewConfig = function()
        return {rootId = "preview", imageId = "previewImage"}
    end
    values.cardLogic.getButtonConfig = function()
        return {actions = {liftHeight = 2}}
    end
    values.cardFields.getActionStackCards = function()
        return {currentCard, legacyCard}, 1
    end
    values.cardFields.onActionStackNavigationClicked = function()
        return legacyCard
    end
    local controller = GameController.new(values)

    Test.truthy(controller:showCardPreview(
        currentCard,
        "Red",
        "current.png"
    ))
    scheduled()
    Test.equal(4, position.y)
    Test.falsy(legacyCard.use_gravity)

    Test.truthy(controller:onCardPreviewStackClicked("Red", "down"))
    scheduled()

    Test.equal("legacy.png", attributes["previewImage.image"])
    Test.equal(4, position.y)
    Test.falsy(legacyCard.use_gravity)
    Test.truthy(highlighted)

    Test.truthy(controller:hideCardPreview(legacyCard, "Red"))
    Test.equal(2, position.y)
    Test.truthy(legacyCard.use_gravity)
    Test.falsy(highlighted)
end)

Test.case("game controller loads legacy saves through injected ports", function()
    local loaded = {}
    local values = dependencies()
    local catalog = {}
    local coordinator = {}
    values.savedBoardCatalog = catalog
    values.boardLoadCoordinator = coordinator
    values.turnSystem.onLoad = function(value)
        loaded.turns = value
    end
    values.cardFields.onLoad = function(value)
        loaded.cards = value
    end
    values.hexGrid.onLoad = function(value)
        loaded.hex = value
    end
    values.settingsMenu.initialize = function(context, value)
        loaded.settings = value
        loaded.settingsContext = context
    end
    values.dungeonMap.initialize = function(context, value)
        loaded.dungeon = value
        loaded.dungeonContext = context
    end

    GameController.new(values):onLoad({
        cardFields = {name = "cards"},
        dungeonMap = {name = "dungeon"},
        hexGrid = {name = "hex"},
        settings = {name = "settings"},
        turnSystem = {name = "turns"}
    })

    Test.equal("cards", loaded.cards.name)
    Test.equal("dungeon", loaded.dungeon.name)
    Test.equal("hex", loaded.hex.name)
    Test.equal("settings", loaded.settings.name)
    Test.equal("turns", loaded.turns.name)
    Test.truthy(loaded.settingsContext.persistState)
    Test.equal(
        loaded.settingsContext.persistState,
        loaded.dungeonContext.persistState
    )
    Test.equal(catalog, loaded.settingsContext.savedBoardCatalog)
    Test.equal(catalog, loaded.dungeonContext.savedBoardCatalog)
    Test.equal(coordinator, loaded.settingsContext.boardLoadCoordinator)
    Test.equal(coordinator, loaded.dungeonContext.boardLoadCoordinator)
    Test.truthy(type(loaded.settingsContext.restartGame) == "function")
end)

Test.case("game controller persistence uses only its runtime port", function()
    local capturedState = nil
    local capturedIncludeCurrent = nil
    local values = dependencies({
        runtime = {
            setGlobalScriptState = function(value)
                capturedState = value
                return true
            end,
            storeRewindState = function(_, includeCurrentState)
                capturedIncludeCurrent = includeCurrentState
            end,
            log = function()
            end
        },
        json = {
            encode = function()
                return "encoded-game"
            end,
            decode = function()
                return {}
            end
        }
    })

    Test.truthy(GameController.new(values):persistState())
    Test.equal("encoded-game", capturedState)
    Test.falsy(capturedIncludeCurrent)
end)

Test.case("game restart clears play objects and preserves the map", function()
    local card = {tag = "Card"}
    local deck = {tag = "Deck"}
    local handOnlyObject = {tag = "Card"}
    local mapObject = {tag = "Tile"}
    local destroyed = {}
    local cardFieldsReset = 0
    local turnsReset = 0
    local surfacesCleared = 0
    local hexLoads = 0
    local values = dependencies()

    values.cardFields.resetForRestart = function()
        cardFieldsReset = cardFieldsReset + 1
    end
    values.turnSystem.resetForRestart = function()
        turnsReset = turnsReset + 1
    end
    values.hexGrid.onLoad = function()
        hexLoads = hexLoads + 1
    end
    values.hexGrid.clearSurfacesForRestart = function()
        surfacesCleared = surfacesCleared + 1
        return true
    end
    values.runtime = {
        getAllObjects = function()
            return {card, deck, mapObject}
        end,
        getPlayers = function()
            return {
                {
                    getHandObjects = function()
                        return {card, handOnlyObject}
                    end
                }
            }
        end,
        destroyObject = function(object)
            destroyed[#destroyed + 1] = object
        end,
        setGlobalScriptState = function()
            return true
        end,
        storeRewindState = function()
        end,
        log = function()
        end
    }

    Test.truthy(GameController.new(values):restartGame())
    Test.equal(3, #destroyed)
    Test.equal(card, destroyed[1])
    Test.equal(deck, destroyed[2])
    Test.equal(handOnlyObject, destroyed[3])
    Test.equal(1, cardFieldsReset)
    Test.equal(1, turnsReset)
    Test.equal(1, surfacesCleared)
    Test.equal(0, hexLoads)
end)

Test.case("game controller reports but contains persistence failures", function()
    local logged = nil
    local values = dependencies({
        runtime = {
            setGlobalScriptState = function()
                error("read-only")
            end,
            storeRewindState = function()
            end,
            log = function(message)
                logged = message
            end
        }
    })

    Test.falsy(GameController.new(values):persistState())
    Test.contains(logged, "read-only")
end)

Test.case("game controller preserves nil returns from legacy event wrappers", function()
    local returnedBySubsystem = {}
    local function sentinel()
        return returnedBySubsystem
    end

    local values = dependencies()
    values.cardFields.onDeckSlotClicked = sentinel
    values.cardFields.onDeckMenuUiClicked = sentinel
    values.cardFields.refreshDeckSlotGlow = sentinel
    values.cardLogic.refreshExistingButtons = sentinel
    values.cardLogic.suppressButtonsUntilPlaced = sentinel
    values.cardLogic.removeAllButtons = sentinel
    values.cardLogic.scheduleHandButtonCleanup = sentinel
    values.dungeonMap.handleAction = sentinel
    values.hexGrid.onObjectHover = sentinel
    values.hexGrid.onClicked = sentinel
    values.hexGrid.onObjectClicked = sentinel
    values.hexGrid.onMenuUiClicked = sentinel
    values.hexGrid.onObjectDestroy = sentinel
    values.settingsMenu.handleAction = sentinel
    values.settingsMenu.onJsonEdited = sentinel
    values.settingsMenu.onBoardNameEdited = sentinel
    values.settingsMenu.onEditModeChanged = sentinel
    values.turnSystem.endTurn = sentinel
    values.turnSystem.refreshUi = sentinel
    values.turnSystem.registerPlayer = sentinel

    local controller = GameController.new(values)
    local calls = {
        function()
            return controller:onObjectHover()
        end,
        function()
            return controller:onEndTurnClicked("Blue")
        end,
        function()
            return controller:refreshCardButtons()
        end,
        function()
            return controller:onHexGridClicked("Blue", false)
        end,
        function()
            return controller:onCardFieldDeckSlotClicked({}, "Blue")
        end,
        function()
            return controller:onDeckSelectionUiClicked("Blue", "deck")
        end,
        function()
            return controller:onObjectLeaveContainer({}, {})
        end,
        function()
            return controller:onObjectEnterZone({tag = "Hand"}, {})
        end,
        function()
            return controller:onHexGridObjectClicked({}, "Blue", false)
        end,
        function()
            return controller:onHexGridMenuUiClicked("Blue", "tile")
        end,
        function()
            return controller:onSettingsUiClicked("Blue", "save")
        end,
        function()
            return controller:onSettingsJsonEdited("Blue", "{}")
        end,
        function()
            return controller:onSettingsBoardNameEdited("Blue", "Crypt")
        end,
        function()
            return controller:onSettingsEditModeChanged("Blue", "True")
        end,
        function()
            return controller:onDungeonMapUiClicked("Blue", "tile1")
        end,
        function()
            return controller:onObjectDestroy({})
        end,
        function()
            return controller:onPlayerConnect()
        end,
        function()
            return controller:onPlayerDisconnect("Blue")
        end
    }

    for _, call in ipairs(calls) do
        Test.equal(nil, call())
    end
end)

Test.case("game controller returns surface picker results", function()
    local expected = {}
    local values = dependencies()
    values.hexGrid.onSurfaceUiClicked = function(playerColor, action)
        Test.equal("Red", playerColor)
        Test.equal("deathFog", action)
        return expected
    end

    Test.equal(
        expected,
        GameController.new(values):onSurfaceUiClicked(
            "Red",
            "deathFog"
        )
    )
end)

Test.case("game controller preserves turns across player connections", function()
    local registeredPlayer = nil
    local turnRefreshes = 0
    local glowRefreshes = 0
    local values = dependencies()
    values.cardFields.refreshDeckSlotGlow = function()
        glowRefreshes = glowRefreshes + 1
    end
    values.turnSystem.registerPlayer = function(player)
        registeredPlayer = player
        return true
    end
    values.turnSystem.refreshUi = function()
        turnRefreshes = turnRefreshes + 1
    end

    local controller = GameController.new(values)
    local player = {color = "Red", steam_name = "Rhea"}
    local connectResult = controller:onPlayerConnect(player)
    local disconnectResult = controller:onPlayerDisconnect("Red")

    Test.nilValue(connectResult)
    Test.nilValue(disconnectResult)
    Test.equal(player, registeredPlayer)
    Test.equal(1, turnRefreshes)
    Test.equal(2, glowRefreshes)
end)

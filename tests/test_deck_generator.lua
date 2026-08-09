local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")
local ConfiguredCards = require("data/CardDefinitions")

Test.case("deck slot fetches its API and spawns the returned cards", function()
    local originalWebRequest = WebRequest
    local originalJson = JSON
    local originalSpawnObjectData = spawnObjectData
    local originalWait = Wait
    local requestedUrl = nil
    local requestCallback = nil
    local spawnParameters = nil
    local spawnedDeck = nil
    local spawnedHero = nil
    local takeParameters = nil
    local spawnCallCount = 0
    local decodedQuantity = 2
    local includeHero = true
    local loadedObjectCount = 0
    local waitParameters = nil
    local deckSpawnedCallbackCount = 0

    Wait = {
        condition = function(
            callback,
            condition,
            timeout,
            timeoutCallback
        )
            waitParameters = {
                callback = callback,
                condition = condition,
                timeout = timeout,
                timeoutCallback = timeoutCallback
            }
        end
    }

    WebRequest = {
        get = function(url, callback)
            requestedUrl = url
            requestCallback = callback
        end
    }
    JSON = {
        decode = function()
            local cards = {
                {
                    name = "Skeleton",
                    description = "A test card",
                    frontImageURL = "front.png",
                    types = {"Undead"},
                    quantity = decodedQuantity
                }
            }

            if includeHero then
                cards[#cards + 1] = {
                    name = "Manfred Schneider",
                    description = "The deck hero",
                    frontImageURL = "hero.png",
                    types = {"Undead", "Hero"},
                    quantity = 1
                }
            end

            return {
                backImageUrl = "back.png",
                cards = cards
            }
        end
    }
    spawnObjectData = function(parameters)
        spawnCallCount = spawnCallCount + 1
        spawnParameters = parameters
        spawnedDeck = {}

        spawnedDeck.setPosition = function(position)
            spawnedDeck.finishedPosition = position
        end
        spawnedDeck.setVelocity = function(velocity)
            spawnedDeck.velocity = velocity
        end
        spawnedDeck.setAngularVelocity = function(velocity)
            spawnedDeck.angularVelocity = velocity
        end
        spawnedDeck.spawning = false
        spawnedDeck.loading_custom = true
        spawnedDeck.getObjects = function()
            if not includeHero then
                return {}
            end

            local allObjects = {
                {
                    guid = "wrong-hero",
                    name = "Not Manfred | Undead, Hero"
                },
                {
                    guid = "skeleton-one",
                    name = "Skeleton | Undead"
                },
                {
                    guid = "skeleton-two",
                    name = "Skeleton | Undead"
                },
                {
                    guid = "hero-guid",
                    name = "Manfred Schneider | Undead, Hero"
                }
            }
            local loadedObjects = {}

            for index = 1, loadedObjectCount do
                loadedObjects[index] = allObjects[index]
            end

            return loadedObjects
        end
        spawnedDeck.takeObject = function(parameters)
            takeParameters = parameters
            spawnedHero = {}
            spawnedHero.setPosition = function(position)
                spawnedHero.finishedPosition = position
            end
            spawnedHero.setVelocity = function(velocity)
                spawnedHero.velocity = velocity
            end
            spawnedHero.setAngularVelocity = function(velocity)
                spawnedHero.angularVelocity = velocity
            end

            if parameters.callback_function then
                parameters.callback_function(spawnedHero)
            end

            return spawnedHero
        end

        if parameters.callback_function then
            parameters.callback_function(spawnedDeck)
        end

        return spawnedDeck
    end

    local field = {
        playerColor = "Green",
        surfaceObjectGuid = "test-field",
        downRotationDegrees = 180,
        deckSlot = {x = 10, y = 2, z = 20},
        heroSlot = {x = 40, y = 4, z = 50},
        zoneCenters = {
            purgatory = {x = 12, y = -1, z = 34},
            abyss = {x = 16, y = -1, z = 34}
        },
        onDeckSpawned = function(deck)
            Test.equal(spawnedDeck, deck)
            deckSpawnedCallbackCount =
                deckSpawnedCallbackCount + 1
        end
    }

    Test.truthy(DeckGenerator.fetch(
        field,
        {x = 70, y = 3, z = 80},
        10853
    ))
    Test.equal(Config.deckSlot.apiUrl .. "?lootId=10853", requestedUrl)
    Test.falsy(DeckGenerator.fetch(field, nil, 10853))

    requestCallback({
        is_error = false,
        text = "{}"
    })

    Test.equal(1, spawnCallCount)
    Test.equal("DeckCustom", spawnParameters.data.Name)
    Test.equal(3, #spawnParameters.data.DeckIDs)
    Test.equal(3, #spawnParameters.data.ContainedObjects)
    Test.equal(100, spawnParameters.data.DeckIDs[1])
    Test.equal(100, spawnParameters.data.DeckIDs[2])
    Test.equal(
        "front.png",
        spawnParameters.data.CustomDeck[1].FaceURL
    )
    Test.equal(
        "back.png",
        spawnParameters.data.CustomDeck[1].BackURL
    )
    Test.equal(
        "Skeleton | Undead",
        spawnParameters.data.ContainedObjects[1].Nickname
    )
    Test.equal(
        "A test card",
        spawnParameters.data.ContainedObjects[1].Description
    )
    Test.equal("Card", spawnParameters.data.ContainedObjects[1].Name)
    Test.contains(
        spawnParameters.data.ContainedObjects[1].LuaScript,
        'id = "rotate90"'
    )
    Test.equal(
        "",
        spawnParameters.data.ContainedObjects[1].LuaScriptState
    )
    Test.contains(
        spawnParameters.data.ContainedObjects[1].LuaScript,
        'fieldId = "test-field"'
    )
    Test.contains(
        spawnParameters.data.ContainedObjects[1].LuaScript,
        "purgatoryPosition = {x = 12.000000, y = 1.000000, "
            .. "z = 34.000000}"
    )
    Test.contains(
        spawnParameters.data.ContainedObjects[1].LuaScript,
        "abyssPosition = {x = 16.000000, y = 1.000000, "
            .. "z = 34.000000}"
    )
    Test.contains(
        spawnParameters.data.ContainedObjects[1].LuaScript,
        "deckPosition = {x = 70.000000, y = 5.000000, "
            .. "z = 80.000000}"
    )
    Test.equal(
        1,
        spawnParameters.data.ContainedObjects[1].Transform.scaleX
    )
    Test.equal(
        Config.deckSlot.cardScale.x,
        spawnParameters.data.ContainedObjects[1].Transform.scaleX
    )
    Test.contains(
        spawnParameters.data.ContainedObjects[1].LuaScript,
        "cardScale = {x = 1.000000, y = 1.000000, z = 1.000000}"
    )
    Test.contains(
        spawnParameters.data.ContainedObjects[1].LuaScript,
        "untappedRotationY = 360"
    )
    Test.equal(1, spawnParameters.data.Transform.scaleX)
    Test.equal(70, spawnParameters.position[1])
    Test.equal(80, spawnParameters.position[3])
    Test.equal(
        Config.deckSlot.deckSpawnRotation[1],
        spawnParameters.rotation[1]
    )
    Test.equal(
        Config.deckSlot.deckSpawnRotation[2] + 180,
        spawnParameters.rotation[2]
    )
    Test.equal(
        Config.deckSlot.deckSpawnRotation[3],
        spawnParameters.rotation[3]
    )
    Test.equal(70, spawnedDeck.finishedPosition[1])
    Test.equal(80, spawnedDeck.finishedPosition[3])
    Test.equal(1, deckSpawnedCallbackCount)
    Test.falsy(takeParameters)
    Test.equal(
        Config.heroSlot.loadTimeoutSeconds,
        waitParameters.timeout
    )
    Test.falsy(waitParameters.condition())

    spawnedDeck.loading_custom = false
    loadedObjectCount = 3
    Test.falsy(waitParameters.condition())
    Test.falsy(takeParameters)

    loadedObjectCount = 4
    Test.truthy(waitParameters.condition())
    waitParameters.callback()

    Test.equal("hero-guid", takeParameters.guid)
    Test.equal(40, takeParameters.position[1])
    Test.equal(6, takeParameters.position[2])
    Test.equal(50, takeParameters.position[3])
    Test.equal(false, takeParameters.smooth)
    Test.equal(
        Config.deckSlot.heroSpawnRotation[2] + 180,
        takeParameters.rotation[2]
    )
    Test.equal(
        Config.deckSlot.heroSpawnRotation[3],
        takeParameters.rotation[3]
    )
    Test.equal(40, spawnedHero.finishedPosition[1])
    Test.equal(50, spawnedHero.finishedPosition[3])

    decodedQuantity = 1
    includeHero = false
    loadedObjectCount = 0
    Test.truthy(DeckGenerator.fetch(field, nil, 10853))
    requestCallback({
        is_error = false,
        text = "{}"
    })

    Test.equal(2, spawnCallCount)
    Test.equal(2, deckSpawnedCallbackCount)
    Test.equal("CardCustom", spawnParameters.data.Name)
    Test.contains(
        spawnParameters.data.LuaScript,
        '"actions", "onActionsClicked"'
    )
    Test.contains(
        spawnParameters.data.LuaScript,
        'previewImageUrl = "front.png"'
    )
    Test.falsy(string.find(
        spawnParameters.data.LuaScript,
        'tooltip = "tap"',
        1,
        true
    ))
    Test.equal(1, spawnParameters.data.Transform.scaleX)

    WebRequest = originalWebRequest
    JSON = originalJson
    spawnObjectData = originalSpawnObjectData
    Wait = originalWait
end)

local nextFailureFieldId = 0

local function makeFailureField()
    nextFailureFieldId = nextFailureFieldId + 1

    return {
        playerColor = "Red",
        surfaceObjectGuid = "deck-failure-field-"
            .. tostring(nextFailureFieldId),
        downRotationDegrees = 0,
        deckSlot = {x = 1, y = 2, z = 3},
        heroSlot = {x = 4, y = 5, z = 6},
        zoneCenters = {
            purgatory = {x = 7, y = -1, z = 8},
            abyss = {x = 9, y = -1, z = 10}
        },
        onDeckSpawned = function()
        end
    }
end

local function makeValidApiData()
    return {
        backImageUrl = "back.png",
        cards = {
            {
                name = "Skeleton",
                description = "A minion",
                frontImageURL = "skeleton.png",
                types = {"Undead"},
                quantity = 1
            },
            {
                name = "Arysa Andrews",
                description = "The hero",
                frontImageURL = "hero.png",
                types = {"Undead", "Hero"},
                quantity = 1
            }
        }
    }
end

local function withGeneratorGlobals(testFunction)
    local originalWebRequest = WebRequest
    local originalJson = JSON
    local originalSpawnObjectData = spawnObjectData
    local originalWait = Wait
    local succeeded, failure = pcall(testFunction)

    WebRequest = originalWebRequest
    JSON = originalJson
    spawnObjectData = originalSpawnObjectData
    Wait = originalWait

    if not succeeded then
        error(failure, 0)
    end
end

local function captureRequests()
    local requests = {}

    WebRequest = {
        get = function(url, callback)
            requests[#requests + 1] = {
                url = url,
                callback = callback
            }
        end
    }

    return requests
end

local function failRequest(request)
    request.callback({
        is_error = true,
        error = "cleanup failure"
    })
end

local function succeedRequest(request)
    request.callback({
        is_error = false,
        text = "{}"
    })
end

local function makeSettledDeck()
    return {
        spawning = false,
        loading_custom = false,
        setPosition = function()
        end,
        setVelocity = function()
        end,
        setAngularVelocity = function()
        end
    }
end

Test.case("deck generation rejects invalid loot IDs before requesting", function()
    withGeneratorGlobals(function()
        local requestCount = 0
        local field = makeFailureField()

        WebRequest = {
            get = function()
                requestCount = requestCount + 1
            end
        }

        Test.falsy(DeckGenerator.fetch(field, nil, nil))
        Test.falsy(DeckGenerator.fetch(field, nil, "not-a-number"))
        Test.equal(0, requestCount)
    end)
end)

Test.case("HTTP failures release the field for another request", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()

        Test.truthy(DeckGenerator.fetch(field, nil, 101))
        Test.falsy(DeckGenerator.fetch(field, nil, 101))
        requests[1].callback({is_error = true, error = "offline"})

        Test.truthy(DeckGenerator.fetch(field, nil, 101))
        Test.equal(2, #requests)
        failRequest(requests[2])
    end)
end)

Test.case("JSON decode failures release the field for retry", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()

        JSON = {
            decode = function()
                error("invalid JSON")
            end
        }

        Test.truthy(DeckGenerator.fetch(field, nil, 102))
        succeedRequest(requests[1])
        Test.truthy(DeckGenerator.fetch(field, nil, 102))
        failRequest(requests[2])
    end)
end)

Test.case("missing loot IDs report Deck not found and allow retry", function()
    local requests = {}
    local logs = {}
    local messages = {}
    local field = makeFailureField()
    local generator = DeckGenerator.new({
        runtime = {
            log = function(message)
                logs[#logs + 1] = message
            end,
            broadcastToColor = function(message, playerColor)
                messages[#messages + 1] = {message, playerColor}
            end
        },
        web = {
            get = function(_, callback)
                requests[#requests + 1] = callback
                return true
            end
        },
        decodeJson = function()
            return nil
        end
    })

    Test.truthy(generator:fetch(field, nil, 999999999))
    requests[1]({is_error = false, text = "null"})

    Test.equal("Deck not found", logs[#logs])
    Test.deepEqual({"Deck not found", "Red"}, messages[1])
    Test.truthy(generator:fetch(field, nil, 999999999))
end)

Test.case("invalid API response shapes never reach the spawner", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()
        local decoded = nil
        local spawnCount = 0
        local invalidResponses = {
            {},
            {backImageUrl = "back.png", cards = {}},
            {
                cards = {
                    {
                        name = "Skeleton",
                        frontImageURL = "front.png",
                        quantity = 1
                    }
                }
            },
            {
                backImageUrl = "back.png",
                cards = {
                    {name = "Zero", frontImageURL = "zero.png", quantity = 0},
                    {name = "No face", quantity = 2}
                }
            }
        }

        JSON = {
            decode = function()
                return decoded
            end
        }
        spawnObjectData = function()
            spawnCount = spawnCount + 1
        end

        for index, response in ipairs(invalidResponses) do
            decoded = response
            Test.truthy(DeckGenerator.fetch(field, nil, 200 + index))
            succeedRequest(requests[#requests])
        end

        Test.equal(0, spawnCount)
        Test.truthy(DeckGenerator.fetch(field, nil, 299))
        failRequest(requests[#requests])
    end)
end)

Test.case("spawn exceptions and nil results both release the mutex", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()

        JSON = {
            decode = function()
                return makeValidApiData()
            end
        }
        spawnObjectData = function()
            error("TTS spawn failed")
        end

        Test.truthy(DeckGenerator.fetch(field, nil, 301))
        succeedRequest(requests[1])

        spawnObjectData = function()
            return nil
        end
        Test.truthy(DeckGenerator.fetch(field, nil, 301))
        succeedRequest(requests[2])

        Test.truthy(DeckGenerator.fetch(field, nil, 301))
        failRequest(requests[3])
    end)
end)

Test.case("Hero load timeout releases the field for retry", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()
        local timeoutCallback = nil
        local waitTimeout = nil
        local deck = makeSettledDeck()

        JSON = {
            decode = function()
                return makeValidApiData()
            end
        }
        Wait = {
            condition = function(callback, condition, timeout, onTimeout)
                waitTimeout = timeout
                timeoutCallback = onTimeout
            end
        }
        deck.getObjects = function()
            return {}
        end
        spawnObjectData = function(parameters)
            parameters.callback_function(deck)
            return deck
        end

        Test.truthy(DeckGenerator.fetch(field, nil, 401))
        succeedRequest(requests[1])
        Test.falsy(DeckGenerator.fetch(field, nil, 401))
        Test.equal(Config.heroSlot.loadTimeoutSeconds, waitTimeout)
        Test.truthy(type(timeoutCallback) == "function")

        timeoutCallback()
        Test.truthy(DeckGenerator.fetch(field, nil, 401))
        failRequest(requests[2])
    end)
end)

Test.case("failed Hero extraction releases the field for retry", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()
        local deck = makeSettledDeck()

        JSON = {
            decode = function()
                return makeValidApiData()
            end
        }
        Wait = {
            condition = function(callback, condition)
                Test.truthy(condition())
                callback()
            end
        }
        deck.getObjects = function()
            return {
                {guid = "skeleton", name = "Skeleton | Undead"},
                {guid = "hero", name = "Arysa Andrews | Human, Hero"}
            }
        end
        deck.takeObject = function()
            return nil
        end
        spawnObjectData = function(parameters)
            parameters.callback_function(deck)
            return deck
        end

        Test.truthy(DeckGenerator.fetch(field, nil, 501))
        succeedRequest(requests[1])
        Test.truthy(DeckGenerator.fetch(field, nil, 501))
        failRequest(requests[2])
    end)
end)

Test.case("Hero metadata supports nickname and index fallbacks", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()
        local deck = makeSettledDeck()
        local takeParameters = nil
        local hero = {
            setPosition = function()
            end,
            setVelocity = function()
            end,
            setAngularVelocity = function()
            end
        }

        JSON = {
            decode = function()
                return makeValidApiData()
            end
        }
        Wait = {
            condition = function(callback, condition)
                Test.truthy(condition())
                callback()
            end
        }
        deck.getObjects = function()
            return {
                {index = 2, nickname = "Skeleton | Undead"},
                {index = 7, nickname = "Arysa Andrews | Human, Hero"}
            }
        end
        deck.takeObject = function(parameters)
            takeParameters = parameters

            if parameters.callback_function ~= nil then
                parameters.callback_function(hero)
            end

            return hero
        end
        spawnObjectData = function(parameters)
            parameters.callback_function(deck)
            return deck
        end

        Test.truthy(DeckGenerator.fetch(field, nil, 601))
        succeedRequest(requests[1])
        Test.equal(7, takeParameters.index)
        Test.nilValue(takeParameters.guid)
        Test.equal(field.heroSlot.x, takeParameters.position[1])
        Test.equal(
            field.heroSlot.y + Config.deckSlot.cardSpawnHeight,
            takeParameters.position[2]
        )

        Test.truthy(DeckGenerator.fetch(field, nil, 601))
        failRequest(requests[2])
    end)
end)

Test.case("deck generation builds scripts from card feature data", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()
        local spawnedData = nil
        local configuredIndex = #ConfiguredCards.cards + 1

        ConfiguredCards.cards[configuredIndex] = {
            id = "rotate-only-card",
            featureIds = {"rotate90"}
        }
        Test.cleanup(function()
            table.remove(ConfiguredCards.cards, configuredIndex)
        end)

        JSON = {
            decode = function()
                return {
                    backImageUrl = "back.png",
                    cards = {
                        {
                            id = "rotate-only-card",
                            name = "Spinner",
                            frontImageURL = "spinner.png",
                            quantity = 1
                        },
                        {
                            id = "default-card",
                            name = "Default",
                            frontImageURL = "default.png",
                            quantity = 1
                        }
                    }
                }
            end
        }
        spawnObjectData = function(parameters)
            spawnedData = parameters.data
            -- Returning nil exercises the existing spawn-failure cleanup and
            -- avoids needing an unrelated Hero-loading fake in this test.
            return nil
        end

        Test.truthy(DeckGenerator.fetch(field, nil, 701))
        succeedRequest(requests[1])

        Test.equal("DeckCustom", spawnedData.Name)
        Test.equal(2, #spawnedData.ContainedObjects)
        Test.contains(
            spawnedData.ContainedObjects[1].LuaScript,
            'id = "rotate90"'
        )
        Test.falsy(string.find(
            spawnedData.ContainedObjects[1].LuaScript,
            "function onDestroyCardClicked",
            1,
            true
        ))
        Test.contains(
            spawnedData.ContainedObjects[2].LuaScript,
            "function onDestroyCardClicked"
        )
    end)
end)

Test.case("invalid configured card features release generation", function()
    withGeneratorGlobals(function()
        local field = makeFailureField()
        local requests = captureRequests()
        local spawnCount = 0
        local configuredIndex = #ConfiguredCards.cards + 1

        ConfiguredCards.cards[configuredIndex] = {
            id = "invalid-feature-card",
            featureIds = {"not-registered"}
        }
        Test.cleanup(function()
            table.remove(ConfiguredCards.cards, configuredIndex)
        end)

        JSON = {
            decode = function()
                return {
                    backImageUrl = "back.png",
                    cards = {
                        {
                            id = "invalid-feature-card",
                            name = "Invalid",
                            frontImageURL = "invalid.png",
                            quantity = 1
                        }
                    }
                }
            end
        }
        spawnObjectData = function()
            spawnCount = spawnCount + 1
        end

        Test.truthy(DeckGenerator.fetch(field, nil, 702))
        succeedRequest(requests[1])
        Test.equal(0, spawnCount)

        Test.truthy(DeckGenerator.fetch(field, nil, 702))
        failRequest(requests[2])
    end)
end)

Test.case("deck generator instances isolate in-flight fields", function()
    local requestsA = {}
    local requestsB = {}
    local runtime = {
        log = function()
        end,
        spawnObjectData = function()
            error("A pending request must not spawn.")
        end
    }
    local scheduler = {
        condition = function()
            error("A pending request must not schedule.")
        end
    }
    local generatorA = DeckGenerator.new({
        runtime = runtime,
        scheduler = scheduler,
        web = {
            get = function(url, callback)
                requestsA[#requestsA + 1] = callback
            end
        }
    })
    local generatorB = DeckGenerator.new({
        runtime = runtime,
        scheduler = scheduler,
        webAdapter = {
            get = function(url, callback)
                requestsB[#requestsB + 1] = callback
            end
        }
    })
    local field = makeFailureField()

    Test.truthy(generatorA:fetch(field, nil, 801))
    Test.falsy(generatorA:fetch(field, nil, 801))
    Test.truthy(generatorB:fetch(field, nil, 801))
    Test.falsy(generatorB:fetch(field, nil, 801))
    Test.equal(1, #requestsA)
    Test.equal(1, #requestsB)

    requestsA[1]({is_error = true, error = "done-a"})
    requestsB[1]({is_error = true, error = "done-b"})
    Test.truthy(generatorA:fetch(field, nil, 801))
    Test.truthy(generatorB:fetch(field, nil, 801))
end)

Test.case("cancelled deck requests cannot spawn after restart", function()
    local pendingRequest = nil
    local spawnCount = 0
    local spawnParameters = nil
    local destroyedObject = nil
    local generator = DeckGenerator.new({
        runtime = {
            log = function()
            end,
            broadcastToColor = function()
            end,
            spawnObjectData = function(parameters)
                spawnCount = spawnCount + 1
                spawnParameters = parameters
                return {}
            end,
            destroyObject = function(object)
                destroyedObject = object
            end
        },
        scheduler = {
            condition = function()
            end
        },
        web = {
            get = function(_, callback)
                pendingRequest = callback
            end
        },
        decodeJson = function()
            return {
                backImageUrl = "back.png",
                cards = {
                    {
                        name = "Arysa Andrews",
                        frontImageURL = "front.png",
                        quantity = 1
                    }
                }
            }
        end
    })
    local field = makeFailureField()

    Test.truthy(generator:fetch(field, nil, 802))
    generator:cancelAll()
    pendingRequest({is_error = false, text = "ignored"})

    Test.equal(0, spawnCount)
    Test.truthy(generator:fetch(field, nil, 802))
    pendingRequest({is_error = false, text = "valid"})
    Test.equal(1, spawnCount)

    local lateDeck = {}
    generator:cancelAll()
    spawnParameters.callback_function(lateDeck)
    Test.equal(lateDeck, destroyedObject)
end)

Test.case("deck generator uses injected adapters in order", function()
    local events = {}
    local takenParameters = nil
    local hero = {
        setPosition = function()
        end,
        setVelocity = function()
        end,
        setAngularVelocity = function()
        end
    }
    local deck = {
        spawning = false,
        loading_custom = false,
        setPosition = function()
        end,
        setVelocity = function()
        end,
        setAngularVelocity = function()
        end,
        getObjects = function()
            return {
                {guid = "skeleton-guid", name = "Skeleton | Undead"},
                {
                    guid = "hero-guid",
                    name = "Arysa Andrews | Human, Hero"
                }
            }
        end,
        takeObject = function(parameters)
            events[#events + 1] = "deck:take"
            takenParameters = parameters
            parameters.callback_function(hero)
            return hero
        end
    }
    local runtime = {
        log = function(message)
            events[#events + 1] = "log:" .. message
        end,
        spawnObjectData = function(parameters)
            events[#events + 1] = "runtime:spawn"
            parameters.callback_function(deck)
            return deck
        end
    }
    local scheduler = {
        condition = function(callback, predicate, timeout)
            events[#events + 1] = "scheduler:" .. tostring(timeout)
            Test.truthy(predicate())
            callback()
        end
    }
    local web = {
        get = function(url, callback)
            events[#events + 1] = "web:" .. url
            callback({is_error = false, text = "payload"})
            return true
        end
    }
    local field = makeFailureField()
    field.onDeckSpawned = function()
        events[#events + 1] = "field:onDeckSpawned"
    end
    local displayedStats = nil
    field.onHeroStatsAvailable = function(heroStats)
        events[#events + 1] = "field:onHeroStatsAvailable"
        displayedStats = heroStats
    end
    local generator = DeckGenerator.new({
        runtime = runtime,
        scheduler = scheduler,
        web = web,
        decodeJson = function(value)
            events[#events + 1] = "decode:" .. value
            return makeValidApiData()
        end
    })

    Test.withGlobals({
        WebRequest = Test.NIL,
        Wait = Test.NIL,
        spawnObjectData = Test.NIL,
        JSON = Test.NIL
    }, function()
        Test.truthy(generator:fetch(field, nil, 802))
    end)

    Test.deepEqual({
        "log:Fetching deck data for Red...",
        "web:" .. Config.deckSlot.apiUrl .. "?lootId=802",
        "decode:payload",
        "runtime:spawn",
        "field:onDeckSpawned",
        "scheduler:" .. tostring(Config.heroSlot.loadTimeoutSeconds),
        "deck:take",
        "field:onHeroStatsAvailable",
        "log:Hero placed for Red at row "
            .. Config.heroSlot.row .. ", column "
            .. Config.heroSlot.column .. ".",
        "log:Deck generated for Red."
    }, events)
    Test.equal("hero-guid", takenParameters.guid)
    Test.nilValue(takenParameters.index)
    Test.equal(5, displayedStats.intelligence)
    Test.equal(60, displayedStats.health)

    -- Hero completion released this instance's per-field mutex.
    Test.truthy(generator:fetch(field, nil, 802))
end)

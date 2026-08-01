local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")

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
                    name = "Manfred",
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
                    guid = "skeleton-one",
                    name = "Skeleton | Undead"
                },
                {
                    guid = "skeleton-two",
                    name = "Skeleton | Undead"
                },
                {
                    guid = "hero-guid",
                    name = "Manfred | Undead, Hero"
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
    loadedObjectCount = 2
    Test.falsy(waitParameters.condition())
    Test.falsy(takeParameters)

    loadedObjectCount = 3
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
    Test.contains(spawnParameters.data.LuaScript, 'tooltip = "tap"')
    Test.equal(1, spawnParameters.data.Transform.scaleX)

    WebRequest = originalWebRequest
    JSON = originalJson
    spawnObjectData = originalSpawnObjectData
    Wait = originalWait
end)

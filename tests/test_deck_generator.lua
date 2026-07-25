local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")

Test.case("deck slot fetches its API and spawns the returned cards", function()
    local originalWebRequest = WebRequest
    local originalJson = JSON
    local originalSpawnObjectData = spawnObjectData
    local requestedUrl = nil
    local requestCallback = nil
    local spawnParameters = nil
    local spawnedDeck = nil
    local spawnCallCount = 0
    local decodedQuantity = 2

    WebRequest = {
        get = function(url, callback)
            requestedUrl = url
            requestCallback = callback
        end
    }
    JSON = {
        decode = function()
            return {
                backImageUrl = "back.png",
                cards = {
                    {
                        name = "Skeleton",
                        description = "A test card",
                        frontImageURL = "front.png",
                        types = {"Undead"},
                        quantity = decodedQuantity
                    }
                }
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

        if parameters.callback_function then
            parameters.callback_function(spawnedDeck)
        end

        return spawnedDeck
    end

    local field = {
        playerColor = "Green",
        surfaceObjectGuid = "test-field",
        downRotationDegrees = 180,
        deckSlot = {x = 10, y = 2, z = 20}
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
    Test.equal(2, #spawnParameters.data.DeckIDs)
    Test.equal(2, #spawnParameters.data.ContainedObjects)
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
        "Skeleton | Undead ",
        spawnParameters.data.ContainedObjects[1].Nickname
    )
    Test.equal(
        "A test card",
        spawnParameters.data.ContainedObjects[1].Description
    )
    Test.equal("Card", spawnParameters.data.ContainedObjects[1].Name)
    Test.equal(
        1,
        spawnParameters.data.ContainedObjects[1].Transform.scaleX
    )
    Test.equal(1, spawnParameters.data.Transform.scaleX)
    Test.equal(70, spawnParameters.position[1])
    Test.equal(80, spawnParameters.position[3])
    Test.equal(
        Config.deckSlot.cardSpawnRotation[1],
        spawnParameters.rotation[1]
    )
    Test.equal(
        Config.deckSlot.cardSpawnRotation[2] + 180,
        spawnParameters.rotation[2]
    )
    Test.equal(
        Config.deckSlot.cardSpawnRotation[3],
        spawnParameters.rotation[3]
    )
    Test.equal(70, spawnedDeck.finishedPosition[1])
    Test.equal(80, spawnedDeck.finishedPosition[3])

    decodedQuantity = 1
    Test.truthy(DeckGenerator.fetch(field, nil, 10853))
    requestCallback({
        is_error = false,
        text = "{}"
    })

    Test.equal(2, spawnCallCount)
    Test.equal("CardCustom", spawnParameters.data.Name)
    Test.equal(1, spawnParameters.data.Transform.scaleX)

    WebRequest = originalWebRequest
    JSON = originalJson
    spawnObjectData = originalSpawnObjectData
end)

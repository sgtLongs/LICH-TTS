local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local DeckGenerator = require("src/card_fields/DeckGenerator")

Test.case("deck slot fetches its API and spawns the returned cards", function()
    local originalWebRequest = WebRequest
    local originalJson = JSON
    local originalWait = Wait
    local originalSpawnObject = spawnObject
    local requestedUrl = nil
    local requestCallback = nil
    local spawnedCards = {}

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
                        quantity = 2
                    }
                }
            }
        end
    }
    Wait = {
        time = function(callback)
            callback()
        end
    }
    spawnObject = function(parameters)
        local spawned = {
            parameters = parameters
        }

        spawned.setCustomObject = function(customObject)
            spawned.customObject = customObject
        end
        spawned.setName = function(name)
            spawned.name = name
        end
        spawned.setDescription = function(description)
            spawned.description = description
        end
        spawned.setPosition = function(position)
            spawned.finishedPosition = position
        end
        spawned.setVelocity = function(velocity)
            spawned.velocity = velocity
        end
        spawned.setAngularVelocity = function(velocity)
            spawned.angularVelocity = velocity
        end

        spawnedCards[#spawnedCards + 1] = spawned

        if parameters.callback_function then
            parameters.callback_function(spawned)
        end

        return spawned
    end

    local field = {
        playerColor = "White",
        surfaceObjectGuid = "test-field",
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

    Test.equal(2, #spawnedCards)
    Test.equal("front.png", spawnedCards[1].customObject.face)
    Test.equal("back.png", spawnedCards[1].customObject.back)
    Test.equal("Skeleton | Undead ", spawnedCards[1].name)
    Test.equal(70, spawnedCards[1].parameters.position[1])
    Test.equal(80, spawnedCards[1].parameters.position[3])
    Test.equal(70, spawnedCards[1].finishedPosition[1])
    Test.equal(80, spawnedCards[1].finishedPosition[3])

    WebRequest = originalWebRequest
    JSON = originalJson
    Wait = originalWait
    spawnObject = originalSpawnObject
end)

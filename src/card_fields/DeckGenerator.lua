local Config = require("src/config/CardFieldConfig")

local DeckGenerator = {}
local generatingByField = {}

local function fieldKey(field)
    return field.surfaceObjectGuid or field.playerColor
end

local function finish(field)
    generatingByField[fieldKey(field)] = nil
end

local function makeCardDefinitions(data)
    if type(data) ~= "table"
        or type(data.cards) ~= "table"
        or #data.cards == 0
    then
        return nil, "API response did not contain any cards."
    end

    local definitions = {}
    local deckSize = 0

    for _, card in ipairs(data.cards) do
        local quantity = math.floor(tonumber(card.quantity) or 0)

        if quantity > 0 and type(card.frontImageURL) == "string" then
            local typesString = ""

            if type(card.types) == "table" and #card.types > 0 then
                typesString = table.concat(card.types, ", ") .. " "
            end

            definitions[#definitions + 1] = {
                name = tostring(card.name or "") .. " | " .. typesString,
                description = tostring(card.description or ""),
                face = card.frontImageURL,
                back = data.backImageUrl,
                type = 0,
                quantity = quantity
            }
            deckSize = deckSize + quantity
        end
    end

    if deckSize == 0 then
        return nil, "API response did not contain any spawnable cards."
    end

    return definitions, nil, deckSize
end

local function createCard(card, position, downRotationDegrees)
    local configuredRotation = Config.deckSlot.cardSpawnRotation
    local rotation = {
        configuredRotation[1],
        configuredRotation[2] + (downRotationDegrees or 0),
        configuredRotation[3]
    }

    local newCard = spawnObject({
        type = "CardCustom",
        position = position,
        rotation = rotation,
        snap_to_grid = false,
        callback_function = function(spawnedCard)
            -- Custom objects finish spawning asynchronously. Reapply the
            -- requested position once initialization completes so loading the
            -- images cannot move the card to a previous/default spawn point.
            spawnedCard.setPosition(position)
            spawnedCard.setVelocity({0, 0, 0})
            spawnedCard.setAngularVelocity({0, 0, 0})
        end
    })

    if newCard == nil then
        print("Deck slot card creation failed.")
        return
    end

    newCard.setCustomObject({
        name = card.name,
        description = card.description,
        face = card.face,
        back = card.back,
        type = card.type
    })
    newCard.setName(card.name)
    newCard.setDescription(card.description)
end

local function spawnDeck(field, spawnPosition, definitions, deckSize)
    local definitionIndex = 1
    local duplicateIndex = 1
    local generatedCount = 0
    local slot = spawnPosition

    local function spawnNext()
        local definition = definitions[definitionIndex]

        if definition == nil then
            finish(field)
            print("Deck generated for " .. field.playerColor .. ".")
            return
        end

        generatedCount = generatedCount + 1

        createCard(
            definition,
            {
                slot.x,
                slot.y + Config.deckSlot.cardSpawnHeight
                    + (generatedCount / deckSize)
                        * Config.deckSlot.cardDropHeight,
                slot.z
            },
            field.downRotationDegrees
        )

        duplicateIndex = duplicateIndex + 1

        if duplicateIndex > definition.quantity then
            definitionIndex = definitionIndex + 1
            duplicateIndex = 1
        end

        Wait.time(spawnNext, Config.deckSlot.spawnDelay)
    end

    spawnNext()
end

local function getApiUrl(lootId)
    return Config.deckSlot.apiUrl
        .. "?lootId=" .. tostring(lootId)
end

function DeckGenerator.fetch(field, spawnPosition, lootId)
    lootId = tonumber(lootId)

    if lootId == nil then
        print("Deck generation requires a loot ID.")
        return false
    end

    local key = fieldKey(field)

    if generatingByField[key] then
        return false
    end

    generatingByField[key] = true
    print("Fetching deck data for " .. field.playerColor .. "...")

    WebRequest.get(getApiUrl(lootId), function(response)
        if response.is_error then
            print("Deck API request failed: " .. tostring(response.error))
            finish(field)
            return
        end

        local decoded, data = pcall(JSON.decode, response.text)

        if not decoded then
            print("Failed to parse deck API response.")
            finish(field)
            return
        end

        local definitions, errorMessage, deckSize =
            makeCardDefinitions(data)

        if definitions == nil then
            print(errorMessage)
            finish(field)
            return
        end

        spawnDeck(
            field,
            spawnPosition or field.deckSlot,
            definitions,
            deckSize
        )
    end)

    return true
end

return DeckGenerator

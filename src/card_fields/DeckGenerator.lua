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

    if type(data.backImageUrl) ~= "string"
        or data.backImageUrl == ""
    then
        return nil, "API response did not contain a card back image."
    end

    local definitions = {}
    local deckSize = 0

    for _, card in ipairs(data.cards) do
        local quantity = math.floor(tonumber(card.quantity) or 0)

        if quantity > 0
            and type(card.frontImageURL) == "string"
            and card.frontImageURL ~= ""
        then
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

local function makeTransform()
    return {
        posX = 0,
        posY = 0,
        posZ = 0,
        rotX = 0,
        rotY = 0,
        rotZ = 0,
        scaleX = 1,
        scaleY = 1,
        scaleZ = 1
    }
end

local function makeCustomDeckEntry(card)
    return {
        FaceURL = card.face,
        BackURL = card.back,
        NumWidth = 1,
        NumHeight = 1,
        BackIsHidden = true,
        UniqueBack = false,
        Type = card.type
    }
end

local function makeCardData(card, cardId, deckId, customDeckEntry)
    return {
        -- Cards inside a DeckCustom use the built-in Card name. CardCustom is
        -- only the standalone custom-card object type.
        Name = "Card",
        Transform = makeTransform(),
        Nickname = card.name,
        Description = card.description,
        CardID = cardId,
        SidewaysCard = false,
        CustomDeck = {
            [deckId] = customDeckEntry
        }
    }
end

local function makeDeckData(definitions, deckSize)
    local customDeck = {}
    local deckIds = {}
    local containedObjects = {}

    for deckId, definition in ipairs(definitions) do
        local cardId = deckId * 100
        local customDeckEntry = makeCustomDeckEntry(definition)

        customDeck[deckId] = customDeckEntry

        for _ = 1, definition.quantity do
            deckIds[#deckIds + 1] = cardId
            containedObjects[#containedObjects + 1] = makeCardData(
                definition,
                cardId,
                deckId,
                customDeckEntry
            )
        end
    end

    if deckSize == 1 then
        containedObjects[1].Name = "CardCustom"
        return containedObjects[1]
    end

    return {
        Name = "DeckCustom",
        Transform = makeTransform(),
        Nickname = "",
        Description = "",
        DeckIDs = deckIds,
        CustomDeck = customDeck,
        ContainedObjects = containedObjects
    }
end

local function spawnDeck(field, spawnPosition, definitions, deckSize)
    local configuredRotation = Config.deckSlot.cardSpawnRotation
    local rotation = {
        configuredRotation[1],
        configuredRotation[2] + (field.downRotationDegrees or 0),
        configuredRotation[3]
    }
    local slot = spawnPosition
    local position = {
        slot.x,
        slot.y + Config.deckSlot.cardSpawnHeight,
        slot.z
    }
    local succeeded, spawnedDeck = pcall(spawnObjectData, {
        data = makeDeckData(definitions, deckSize),
        position = position,
        rotation = rotation,
        callback_function = function(deck)
            -- Asset loading can slightly displace custom objects. Correct the
            -- one spawned deck after initialization rather than settling every
            -- card independently through the physics engine.
            deck.setPosition(position)
            deck.setVelocity({0, 0, 0})
            deck.setAngularVelocity({0, 0, 0})
            finish(field)
            print("Deck generated for " .. field.playerColor .. ".")
        end
    })

    if not succeeded or spawnedDeck == nil then
        finish(field)
        print("Deck slot card creation failed.")
    end
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

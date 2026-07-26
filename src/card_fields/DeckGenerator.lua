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
                typesString = table.concat(card.types, ", ")
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

local function titleHasType(title, expectedType)
    if type(title) ~= "string" then
        return false
    end

    local types = string.match(title, "^.- | (.-)%s*$")

    if types == nil then
        return false
    end

    for cardType in string.gmatch(types, "[^,]+") do
        local trimmed = string.match(cardType, "^%s*(.-)%s*$")

        if trimmed == expectedType then
            return true
        end
    end

    return false
end

local function findHeroCard(cards)
    for _, card in ipairs(cards or {}) do
        -- Container metadata exposes the visible card title as `name`.
        -- `nickname` remains as a fallback for older TTS versions.
        local title = card.name or card.nickname

        if titleHasType(title, "Hero") then
            return card
        end
    end

    return nil
end

local function settleObject(object, position)
    object.setPosition(position)
    object.setVelocity({0, 0, 0})
    object.setAngularVelocity({0, 0, 0})
end

local function placeHero(field, deck, rotation, heroCard)
    if field.heroSlot == nil then
        print("Card field did not contain a hero slot.")
        finish(field)
        return
    end

    local heroPosition = {
        field.heroSlot.x,
        field.heroSlot.y + Config.deckSlot.cardSpawnHeight,
        field.heroSlot.z
    }
    local takeParameters = {
        position = heroPosition,
        rotation = rotation,
        smooth = false,
        callback_function = function(takenHero)
            settleObject(takenHero, heroPosition)
            finish(field)
            print(
                "Hero placed for " .. field.playerColor
                    .. " at row " .. Config.heroSlot.row
                    .. ", column " .. Config.heroSlot.column .. "."
            )
        end
    }

    if heroCard.guid ~= nil and heroCard.guid ~= "" then
        takeParameters.guid = heroCard.guid
    else
        takeParameters.index = heroCard.index
    end

    local succeeded, hero = pcall(deck.takeObject, takeParameters)

    if not succeeded or hero == nil then
        print("Could not take the Hero card from the generated deck.")
        finish(field)
    end
end

local function waitForLoadedDeck(field, deck, rotation, deckSize)
    local loadedHeroCard = nil

    local function deckIsFullyLoaded()
        if deck.spawning == true or deck.loading_custom == true then
            return false
        end

        if type(deck.getObjects) ~= "function" then
            return false
        end

        local succeeded, cards = pcall(deck.getObjects)

        if not succeeded
            or type(cards) ~= "table"
            or #cards < deckSize
        then
            return false
        end

        loadedHeroCard = findHeroCard(cards)
        return loadedHeroCard ~= nil
            and (
                loadedHeroCard.guid ~= nil
                or loadedHeroCard.index ~= nil
            )
    end

    Wait.condition(
        function()
            placeHero(field, deck, rotation, loadedHeroCard)
        end,
        deckIsFullyLoaded,
        Config.heroSlot.loadTimeoutSeconds,
        function()
            print(
                "Timed out waiting for the complete deck and its Hero card "
                    .. "to load."
            )
            finish(field)
        end
    )
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
            settleObject(deck, position)

            if type(field.onDeckSpawned) == "function" then
                local notified = pcall(field.onDeckSpawned, deck)

                if not notified then
                    print("Could not remove the used deck spawn button.")
                end
            end

            waitForLoadedDeck(field, deck, rotation, deckSize)
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

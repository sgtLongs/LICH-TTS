local Config = require("src/config/CardFieldConfig")
local HeroConfig = require("src/config/HeroConfig")
local CardApiNormalizer = require("src/cards/CardApiNormalizer")
local CardDefinition = require("src/cards/CardDefinition")
local CardLogic = require("src/cards/CardLogic")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")
local WebAdapter = require("src/tts/WebAdapter")

local DeckGenerator = {}
local Controller = {}
Controller.__index = Controller
local defaultController = nil

local function fieldKey(field)
    return field.surfaceObjectGuid or field.playerColor
end

local function finish(controller, field)
    controller.generatingByField[fieldKey(field)] = nil
end

local function makeTransform()
    local scale = Config.deckSlot.cardScale or {x = 1, y = 1, z = 1}

    return {
        posX = 0,
        posY = 0,
        posZ = 0,
        rotX = 0,
        rotY = 0,
        rotZ = 0,
        scaleX = tonumber(scale.x or scale[1]) or 1,
        scaleY = tonumber(scale.y or scale[2]) or 1,
        scaleZ = tonumber(scale.z or scale[3]) or 1
    }
end

local function makeCustomDeckEntry(card)
    return {
        FaceURL = card.images.front,
        BackURL = card.images.back,
        NumWidth = 1,
        NumHeight = 1,
        BackIsHidden = true,
        UniqueBack = false,
        Type = 0
    }
end

local function makeCardData(
    card,
    cardId,
    deckId,
    customDeckEntry,
    cardScript
)
    return {
        -- Cards inside a DeckCustom use the built-in Card name. CardCustom is
        -- only the standalone custom-card object type.
        Name = "Card",
        Transform = makeTransform(),
        Nickname = CardDefinition.title(card),
        Description = card.description,
        CardID = cardId,
        SidewaysCard = false,
        LuaScript = cardScript,
        LuaScriptState = "",
        CustomDeck = {
            [deckId] = customDeckEntry
        }
    }
end

local function makeDeckData(definitions, deckSize, scriptContext)
    local customDeck = {}
    local deckIds = {}
    local containedObjects = {}

    for deckId, definition in ipairs(definitions) do
        local cardId = deckId * 100
        local customDeckEntry = makeCustomDeckEntry(definition)
        local cardScriptContext = {}

        for key, value in pairs(scriptContext or {}) do
            cardScriptContext[key] = value
        end

        cardScriptContext.previewImageUrl = definition.images.front
        local cardScript = CardLogic.build(
            definition.featureIds,
            cardScriptContext
        )

        customDeck[deckId] = customDeckEntry

        for _ = 1, definition.quantity do
            deckIds[#deckIds + 1] = cardId
            containedObjects[#containedObjects + 1] = makeCardData(
                definition,
                cardId,
                deckId,
                customDeckEntry,
                cardScript
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

local function findHeroCard(cards)
    for _, card in ipairs(cards or {}) do
        -- Container metadata exposes the visible card title as `name`.
        -- `nickname` remains as a fallback for older TTS versions.
        local title = card.name or card.nickname

        for _, hero in ipairs(HeroConfig.heroes or {}) do
            local titleContains = hero.titleContains

            if type(titleContains) == "string"
                and titleContains ~= ""
                and type(title) == "string"
                and string.find(title, titleContains, 1, true) ~= nil
            then
                return card, hero
            end
        end
    end

    return nil
end

local function settleObject(object, position)
    object.setPosition(position)
    object.setVelocity({0, 0, 0})
    object.setAngularVelocity({0, 0, 0})
end

local function placeHero(
    controller,
    generation,
    field,
    deck,
    rotation,
    heroCard,
    heroDefinition
)
    if generation ~= controller.generation then
        return
    end

    if field.heroSlot == nil then
        controller.runtime.log("Card field did not contain a hero slot.")
        finish(controller, field)
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
            if type(field.onHeroStatsAvailable) == "function" then
                local notified = pcall(
                    field.onHeroStatsAvailable,
                    heroDefinition
                )

                if not notified then
                    controller.runtime.log(
                        "Could not update the Hero stat displays."
                    )
                end
            end
            finish(controller, field)
            controller.runtime.log(
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
        controller.runtime.log(
            "Could not take the Hero card from the generated deck."
        )
        finish(controller, field)
    end
end

local function waitForLoadedDeck(
    controller,
    generation,
    field,
    deck,
    rotation,
    deckSize
)
    local loadedHeroCard = nil
    local loadedHeroDefinition = nil

    local function deckIsFullyLoaded()
        if generation ~= controller.generation then
            return true
        end

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

        loadedHeroCard, loadedHeroDefinition = findHeroCard(cards)
        return loadedHeroCard ~= nil
            and (
                loadedHeroCard.guid ~= nil
                or loadedHeroCard.index ~= nil
            )
    end

    controller.scheduler.condition(
        function()
            placeHero(
                controller,
                generation,
                field,
                deck,
                rotation,
                loadedHeroCard,
                loadedHeroDefinition
            )
        end,
        deckIsFullyLoaded,
        Config.heroSlot.loadTimeoutSeconds,
        function()
            if generation ~= controller.generation then
                return
            end

            controller.runtime.log(
                "Timed out waiting for the complete deck and its Hero card "
                    .. "to load."
            )
            finish(controller, field)
        end
    )
end

local function makeFieldRotation(configuredRotation, field)
    return {
        configuredRotation[1],
        configuredRotation[2] + (field.downRotationDegrees or 0),
        configuredRotation[3]
    }
end

local function spawnDeck(
    controller,
    generation,
    field,
    spawnPosition,
    definitions,
    deckSize
)
    local deckRotation = makeFieldRotation(
        Config.deckSlot.deckSpawnRotation,
        field
    )
    local heroRotation = makeFieldRotation(
        Config.deckSlot.heroSpawnRotation,
        field
    )
    local slot = spawnPosition
    local position = {
        slot.x,
        slot.y + Config.deckSlot.cardSpawnHeight,
        slot.z
    }
    local purgatoryCenter = field.zoneCenters
        and field.zoneCenters.purgatory or nil
    local abyssCenter = field.zoneCenters
        and field.zoneCenters.abyss or nil
    local purgatoryPosition = nil
    local abyssPosition = nil

    if purgatoryCenter ~= nil then
        purgatoryPosition = {
            x = purgatoryCenter.x,
            y = purgatoryCenter.y + Config.deckSlot.cardSpawnHeight,
            z = purgatoryCenter.z
        }
    end

    if abyssCenter ~= nil then
        abyssPosition = {
            x = abyssCenter.x,
            y = abyssCenter.y + Config.deckSlot.cardSpawnHeight,
            z = abyssCenter.z
        }
    end

    local scriptContext = {
        fieldId = field.surfaceObjectGuid or field.playerColor,
        purgatoryPosition = purgatoryPosition,
        abyssPosition = abyssPosition,
        deckPosition = position,
        cardScale = Config.deckSlot.cardScale
    }
    local built, deckData = pcall(
        makeDeckData,
        definitions,
        deckSize,
        scriptContext
    )

    if not built or type(deckData) ~= "table" then
        finish(controller, field)
        controller.runtime.log("Deck slot card creation failed.")
        return
    end

    local succeeded, spawnedDeck = pcall(controller.runtime.spawnObjectData, {
        data = deckData,
        position = position,
        rotation = deckRotation,
        callback_function = function(deck)
            if generation ~= controller.generation then
                controller.runtime.destroyObject(deck)
                return
            end

            -- Asset loading can slightly displace custom objects. Correct the
            -- one spawned deck after initialization rather than settling every
            -- card independently through the physics engine.
            settleObject(deck, position)

            if type(field.onDeckSpawned) == "function" then
                local notified = pcall(field.onDeckSpawned, deck)

                if not notified then
                    controller.runtime.log(
                        "Could not remove the used deck spawn button."
                    )
                end
            end

            waitForLoadedDeck(
                controller,
                generation,
                field,
                deck,
                heroRotation,
                deckSize
            )
            controller.runtime.log(
                "Deck generated for " .. field.playerColor .. "."
            )
        end
    })

    if not succeeded or spawnedDeck == nil then
        finish(controller, field)
        controller.runtime.log("Deck slot card creation failed.")
    end
end

local function getApiUrl(lootId)
    return Config.deckSlot.apiUrl
        .. "?lootId=" .. tostring(lootId)
end

local function defaultDecodeJson(value)
    return JSON.decode(value)
end

function DeckGenerator.new(dependencies)
    dependencies = dependencies or {}

    return setmetatable({
        runtime = dependencies.runtime or Runtime.default(),
        scheduler = dependencies.scheduler or Scheduler.default(),
        web = dependencies.web
            or dependencies.webAdapter
            or WebAdapter.default(),
        decodeJson = dependencies.decodeJson or defaultDecodeJson,
        generatingByField = {},
        generation = 0
    }, Controller)
end

function Controller:fetch(field, spawnPosition, lootId)
    lootId = tonumber(lootId)

    if lootId == nil then
        self.runtime.log("Deck generation requires a loot ID.")
        return false
    end

    local key = fieldKey(field)

    if self.generatingByField[key] then
        return false
    end

    self.generatingByField[key] = true
    local generation = self.generation
    self.runtime.log(
        "Fetching deck data for " .. field.playerColor .. "..."
    )

    local requested, requestFailure = pcall(
        self.web.get,
        getApiUrl(lootId),
        function(response)
            if generation ~= self.generation then
                return
            end

            if response.is_error then
                self.runtime.log(
                    "Deck API request failed: " .. tostring(response.error)
                )
                finish(self, field)
                return
            end

            local decoded, data = pcall(self.decodeJson, response.text)

            if not decoded then
                self.runtime.log("Failed to parse deck API response.")
                finish(self, field)
                return
            end

            if data == nil then
                self.runtime.log("Deck not found")
                self.runtime.broadcastToColor(
                    "Deck not found",
                    field.ownerColor or field.playerColor
                )
                finish(self, field)
                return
            end

            local definitions, errorMessage, deckSize =
                CardApiNormalizer.normalize(data)

            if definitions == nil then
                self.runtime.log(errorMessage)
                finish(self, field)
                return
            end

            spawnDeck(
                self,
                generation,
                field,
                spawnPosition or field.deckSlot,
                definitions,
                deckSize
            )
        end
    )

    if not requested then
        self.runtime.log(
            "Deck API request failed: " .. tostring(requestFailure)
        )
        finish(self, field)
    end

    return true
end

function Controller:cancelAll()
    self.generation = self.generation + 1
    self.generatingByField = {}
end

local function getDefaultController()
    if defaultController == nil then
        defaultController = DeckGenerator.new()
    end

    return defaultController
end


function DeckGenerator.setDefault(controller)
    defaultController = controller or DeckGenerator.new()
end


function DeckGenerator.fetch(field, spawnPosition, lootId)
    return getDefaultController():fetch(field, spawnPosition, lootId)
end

function DeckGenerator.cancelAll()
    return getDefaultController():cancelAll()
end

return DeckGenerator

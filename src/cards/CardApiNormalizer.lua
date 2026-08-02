local CardDefinition = require("src/cards/CardDefinition")
local ConfiguredCards = require("data/CardDefinitions")

local CardApiNormalizer = {}

local function copyFeatureIds(values)
    local copied = {}

    for _, value in ipairs(values or {}) do
        if type(value) == "string" and value ~= "" then
            copied[#copied + 1] = value
        end
    end

    return copied
end

local function cardName(card)
    if card.name ~= nil then
        return tostring(card.name)
    end

    if card.nickname ~= nil then
        return tostring(card.nickname)
    end

    return ""
end

local function cardIdentity(card, name, responseIndex)
    for _, key in ipairs({"id", "cardId", "guid", "index"}) do
        local value = card[key]

        if value ~= nil and tostring(value) ~= "" then
            return tostring(value)
        end
    end

    if name ~= "" then
        return "name:" .. name
    end

    -- This is the legacy-compatible last resort for API entries without any
    -- identity metadata. Explicit IDs and names remain stable across ordering.
    return "index:" .. tostring(responseIndex)
end

local function findConfiguredCard(catalog, identity, name)
    if type(catalog.byId) == "table"
        and type(catalog.byId[identity]) == "table"
    then
        return catalog.byId[identity]
    end

    if type(catalog.byName) == "table"
        and type(catalog.byName[name]) == "table"
    then
        return catalog.byName[name]
    end

    for _, configured in ipairs(catalog.cards or {}) do
        if type(configured) == "table"
            and (
                tostring(configured.id or "") == identity
                or (
                    configured.name ~= nil
                    and tostring(configured.name) == name
                )
            )
        then
            return configured
        end
    end

    return nil
end

local function selectedFeatureIds(catalog, identity, name)
    local configured = findConfiguredCard(catalog, identity, name)

    if configured ~= nil and type(configured.featureIds) == "table" then
        return copyFeatureIds(configured.featureIds)
    end

    return copyFeatureIds(
        catalog.defaultFeatureIds or catalog.defaultFeatures
    )
end

local function normalizeTypes(types)
    local normalized = {}

    if type(types) ~= "table" then
        return normalized
    end

    for _, cardType in ipairs(types) do
        if type(cardType) == "string" then
            normalized[#normalized + 1] = cardType
        end
    end

    return normalized
end

function CardApiNormalizer.normalize(data, catalog)
    if type(data) ~= "table"
        or type(data.cards) ~= "table"
        or #data.cards == 0
    then
        return nil, "API response did not contain any cards."
    end

    local backImageUrl = data.backImageUrl

    if type(backImageUrl) ~= "string" or backImageUrl == "" then
        return nil, "API response did not contain a card back image."
    end

    catalog = type(catalog) == "table" and catalog or ConfiguredCards
    local definitions = {}
    local deckSize = 0

    for responseIndex, card in ipairs(data.cards) do
        if type(card) == "table" then
            local quantity = math.floor(tonumber(card.quantity) or 0)
            local frontImageUrl = card.frontImageURL

            if quantity > 0
                and type(frontImageUrl) == "string"
                and frontImageUrl ~= ""
            then
                local name = cardName(card)
                local identity = cardIdentity(card, name, responseIndex)
                local definition = CardDefinition.new({
                    id = identity,
                    name = name,
                    description = card.description,
                    types = normalizeTypes(card.types),
                    images = {
                        front = frontImageUrl,
                        back = backImageUrl
                    },
                    quantity = quantity,
                    featureIds = selectedFeatureIds(
                        catalog,
                        identity,
                        name
                    )
                })

                if definition ~= nil then
                    definitions[#definitions + 1] = definition
                    deckSize = deckSize + definition.quantity
                end
            end
        end
    end

    if deckSize == 0 then
        return nil, "API response did not contain any spawnable cards."
    end

    return definitions, nil, deckSize
end

CardApiNormalizer.normalizeResponse = CardApiNormalizer.normalize

return CardApiNormalizer

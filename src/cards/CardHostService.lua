local Config = require("src/config/CardLogicConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")

local CardHostService = {}

local function normalizeSignedRotation(degrees)
    return ((degrees + 180) % 360) - 180
end

local function rotationDistance(first, second)
    return math.abs(normalizeSignedRotation(first - second))
end

function CardHostService.isTappedRotation(spin)
    spin = tonumber(spin)

    if spin == nil then
        return false
    end

    local tapConfig = Config.tap or {}
    local side = tonumber(tapConfig.sideRotationDegrees) or 90
    local tolerance = tonumber(tapConfig.rotationToleranceDegrees) or 5

    return math.min(
        rotationDistance(spin, side),
        rotationDistance(spin, -side)
    ) <= tolerance
end

function CardHostService.isObjectInHand(object)
    if object == nil then
        return false
    end

    if type(object.getZones) == "function" then
        local succeeded, zones = pcall(object.getZones)

        if succeeded and type(zones) == "table" then
            for _, zone in ipairs(zones) do
                if zone ~= nil and zone.tag == "Hand" then
                    return true
                end
            end
        end
    end

    for _, player in ipairs(Runtime.default().getPlayers()) do
        if type(player.getHandObjects) == "function" then
            for _, handObject in ipairs(player.getHandObjects() or {}) do
                if handObject == object then
                    return true
                end
            end
        end
    end

    return false
end

function CardHostService.removeAllButtons(object)
    if object == nil or object.tag ~= "Card" then
        return false
    end

    if type(object.clearButtons) == "function" then
        pcall(object.clearButtons)
        return true
    end

    if type(object.getButtons) == "function"
        and type(object.removeButton) == "function"
    then
        local succeeded, buttons = pcall(object.getButtons)

        if succeeded and type(buttons) == "table" then
            for index = #buttons, 1, -1 do
                pcall(object.removeButton, buttons[index].index)
            end
        end
    end

    return true
end

function CardHostService.removeButtonsIfInHand(object)
    if not CardHostService.isObjectInHand(object) then
        return false
    end

    return CardHostService.removeAllButtons(object)
end

function CardHostService.scheduleHandButtonCleanup(object)
    if object == nil or object.tag ~= "Card" then
        return
    end

    local function cleanup()
        CardHostService.removeButtonsIfInHand(object)
    end
    local scheduler = Scheduler.default()

    if scheduler.hasFrames() then
        scheduler.frames(cleanup, 2)
        scheduler.frames(cleanup, 10)

        if scheduler.hasCondition() then
            scheduler.condition(
                cleanup,
                function()
                    return CardHostService.isObjectInHand(object)
                end,
                5
            )
        else
            scheduler.frames(cleanup, 60)
        end
    else
        cleanup()
    end
end

function CardHostService.suppressButtonsUntilPlaced(object)
    if object == nil or object.tag ~= "Card" then
        return
    end

    CardHostService.removeAllButtons(object)

    local scheduler = Scheduler.default()

    if not scheduler.hasFrames() then
        return
    end

    local elapsedFrames = 0

    local function isDestroyed()
        if type(object.isDestroyed) ~= "function" then
            return false
        end

        local succeeded, destroyed = pcall(object.isDestroyed)
        return succeeded and destroyed == true
    end

    local function isStillMoving()
        if object.spawning == true or object.loading_custom == true then
            return true
        end

        if type(object.held_by_color) == "string"
            and object.held_by_color ~= ""
        then
            return true
        end

        if type(object.isSmoothMoving) == "function" then
            local succeeded, moving = pcall(object.isSmoothMoving)

            if succeeded and moving == true then
                return true
            end
        end

        return false
    end

    local function refreshTableButtons()
        if CardHostService.isObjectInHand(object) then
            CardHostService.removeAllButtons(object)
        elseif type(object.call) == "function" then
            pcall(object.call, "refreshCardButtons")
        end
    end

    local function suppress()
        if isDestroyed() then
            return
        end

        elapsedFrames = elapsedFrames + 1
        CardHostService.removeAllButtons(object)

        if CardHostService.isObjectInHand(object) then
            return
        end

        -- Wait long enough for a deck draw to begin moving before deciding
        -- that a programmatically extracted card was placed directly nearby.
        if elapsedFrames >= 10 and not isStillMoving() then
            scheduler.frames(refreshTableButtons, 2)
            return
        end

        if elapsedFrames < 600 then
            scheduler.frames(suppress, 1)
        end
    end

    scheduler.frames(suppress, 1)
end

function CardHostService.returnToHandThroughDeck(card, deck, playerColor)
    if card == nil
        or card.tag ~= "Card"
        or deck == nil
        or (deck.tag ~= "Deck" and deck.tag ~= "Card")
        or type(deck.putObject) ~= "function"
        or type(deck.getPosition) ~= "function"
        or type(card.setPosition) ~= "function"
        or type(playerColor) ~= "string"
        or playerColor == ""
    then
        return false
    end

    local returnedCardGuid = nil

    if type(card.getGUID) == "function" then
        local succeeded, guid = pcall(card.getGUID)

        if succeeded and type(guid) == "string" and guid ~= "" then
            returnedCardGuid = guid
        end
    end

    local expectedQuantity = 2

    if type(deck.getQuantity) == "function" then
        local succeeded, quantity = pcall(deck.getQuantity)

        if succeeded and tonumber(quantity) ~= nil
            and tonumber(quantity) >= 1
        then
            expectedQuantity = tonumber(quantity) + 1
        end
    end

    CardHostService.removeAllButtons(card)

    if type(deck.getScale) == "function"
        and type(card.setScale) == "function"
    then
        local succeeded, scale = pcall(deck.getScale)

        if succeeded and type(scale) == "table" then
            pcall(card.setScale, scale)
        end
    end

    local positionRead, position = pcall(deck.getPosition)

    if not positionRead or type(position) ~= "table" then
        return false
    end

    local x = tonumber(position.x or position[1])
    local y = tonumber(position.y or position[2])
    local z = tonumber(position.z or position[3])

    if x == nil or y == nil or z == nil then
        return false
    end

    -- putObject inserts a card into the deck end closest to its Y elevation.
    -- A successful move below the deck is required before insertion; without
    -- it, a bottom deal could remove a different card.
    local moved, moveResult = pcall(
        card.setPosition,
        {x = x, y = y - 1, z = z}
    )

    if not moved or moveResult == false then
        return false
    end

    local inserted, resultingDeck = pcall(deck.putObject, card)

    if not inserted or resultingDeck == nil then
        return false
    end

    local function deckIsReady()
        if type(resultingDeck.isDestroyed) == "function" then
            local succeeded, destroyed = pcall(resultingDeck.isDestroyed)

            if succeeded and destroyed == true then
                return false
            end
        end

        if resultingDeck.spawning == true
            or resultingDeck.loading_custom == true
        then
            return false
        end

        local quantityReady = nil

        if type(resultingDeck.getQuantity) == "function" then
            local succeeded, quantity = pcall(resultingDeck.getQuantity)
            quantityReady = succeeded
                and tonumber(quantity) ~= nil
                and tonumber(quantity) >= expectedQuantity
        end

        if returnedCardGuid ~= nil
            and type(resultingDeck.getObjects) == "function"
        then
            local succeeded, objects = pcall(resultingDeck.getObjects)

            if not succeeded or type(objects) ~= "table" then
                return false
            end

            for _, containedObject in ipairs(objects) do
                if containedObject.guid == returnedCardGuid then
                    return true
                end
            end

            return false
        end

        if quantityReady ~= nil then
            return quantityReady
        end

        return type(resultingDeck.deal) == "function"
    end

    local function dealReturnedCard(bestEffort)
        if (bestEffort ~= true and not deckIsReady())
            or type(resultingDeck.deal) ~= "function"
        then
            Runtime.default().log(
                "Could not deal the returned card from its deck."
            )
            return
        end

        -- The returned card was inserted at the bottom. Dealing from the
        -- bottom removes that exact card while preserving the old deck order.
        local succeeded, dealt = pcall(
            resultingDeck.deal,
            1,
            playerColor,
            1,
            true
        )

        if not succeeded or dealt == false then
            Runtime.default().log(
                "Could not return the card through its deck: "
                    .. tostring(dealt)
            )
        end
    end

    local function dealAfterDeckRefresh()
        local scheduler = Scheduler.default()

        if scheduler.hasFrames() then
            -- Newly formed Deck objects need a frame before their methods are
            -- reliable even after their quantity/contents become visible.
            scheduler.frames(dealReturnedCard, 1)
        else
            dealReturnedCard()
        end
    end

    local scheduler = Scheduler.default()

    if scheduler.hasCondition() then
        scheduler.condition(
            dealAfterDeckRefresh,
            deckIsReady,
            5,
            function()
                Runtime.default().log(
                    "Timed out verifying the returned card; "
                        .. "attempting the documented bottom deal."
                )

                if scheduler.hasFrames() then
                    scheduler.frames(function()
                        dealReturnedCard(true)
                    end, 1)
                else
                    dealReturnedCard(true)
                end
            end
        )
    elseif scheduler.hasFrames() then
        scheduler.frames(dealReturnedCard, 2)
    else
        dealReturnedCard()
    end

    return true
end

function CardHostService.reloadAndReturnToHand(card, playerColor)
    if card == nil
        or card.tag ~= "Card"
        or type(card.reload) ~= "function"
        or type(playerColor) ~= "string"
        or playerColor == ""
    then
        return false
    end

    CardHostService.removeAllButtons(card)
    local reloaded, freshCard = pcall(card.reload)

    if not reloaded or freshCard == nil or freshCard.tag ~= "Card" then
        return false
    end

    CardHostService.removeAllButtons(freshCard)

    if type(freshCard.setLock) == "function" then
        pcall(freshCard.setLock, false)
    end

    freshCard.use_hands = true

    if type(freshCard.setScale) == "function" then
        pcall(freshCard.setScale, {x = 1, y = 1, z = 1})
    end

    if type(freshCard.deal) ~= "function" then
        return false
    end

    CardHostService.suppressButtonsUntilPlaced(freshCard)
    local dealt, dealResult = pcall(
        freshCard.deal,
        1,
        playerColor,
        1
    )

    if not dealt or dealResult == false then
        return false
    end

    CardHostService.scheduleHandButtonCleanup(freshCard)
    return true
end

local function indexHostButtons(featureDescriptors)
    local byCallback = {}

    for _, feature in ipairs(featureDescriptors or {}) do
        for _, button in ipairs(feature.hostButtons or {}) do
            if type(button.callback) == "string"
                and button.callback ~= ""
            then
                byCallback[button.callback] = button
            end
        end
    end

    return byCallback
end

local function makeRefreshParameters(button, descriptor)
    local buttonConfig = Config.buttons[descriptor.configKey]

    if type(buttonConfig) ~= "table" then
        return nil
    end

    local parameters = {
        index = button.index,
        position = buttonConfig.position
    }

    if descriptor.sizeSource == "actionList" then
        parameters.width = Config.buttons.actionList.width
        parameters.height = Config.buttons.actionList.height
    else
        parameters.width = buttonConfig.width
        parameters.height = buttonConfig.height
    end

    if descriptor.debugStyle == "tap" then
        local showDebug = DebugConfig.drawCardButtons == true

        parameters.label = showDebug and Config.debug.tapLabel or ""
        parameters.font_size = showDebug and 180 or 1
        parameters.color = showDebug
            and Config.debug.tapColor or {0, 0, 0, 0}
        parameters.font_color = showDebug
            and Config.debug.tapFontColor or {0, 0, 0, 0}
        parameters.hover_color = showDebug
            and Config.debug.tapHoverColor or {0, 0, 0, 0}
        parameters.press_color = showDebug
            and Config.debug.tapPressColor or {0, 0, 0, 0}
    end

    return parameters
end

local function refreshThroughCardScript(object)
    if type(object.getVar) ~= "function"
        or type(object.call) ~= "function"
    then
        return false
    end

    local found, refresh = pcall(object.getVar, "refreshCardButtons")

    if not found or type(refresh) ~= "function" then
        return false
    end

    -- Once this API exists, do not partially overwrite its transform even if
    -- the card-local refresh fails. A later lifecycle refresh can safely retry.
    pcall(object.call, "refreshCardButtons")
    return true
end

function CardHostService.refreshExistingButtons(featureDescriptors)
    local hostButtons = indexHostButtons(featureDescriptors)

    for _, object in ipairs(Runtime.default().getAllObjects()) do
        if object.tag == "Card"
            and not CardHostService.removeButtonsIfInHand(object)
        then
            -- Current generated cards own their complete button transform,
            -- including tap-dependent position and rotation. Keep the direct
            -- edit path below only for older saved cards without that API.
            local refreshed = refreshThroughCardScript(object)
            local succeeded, buttons = false, nil

            if not refreshed then
                succeeded, buttons = pcall(object.getButtons)
            end

            if succeeded and type(buttons) == "table" then
                for _, button in ipairs(buttons) do
                    local descriptor = hostButtons[button.click_function]

                    if descriptor ~= nil
                        and descriptor.removeOnRefresh == true
                    then
                        pcall(object.removeButton, button.index)
                    elseif descriptor ~= nil then
                        local parameters = makeRefreshParameters(
                            button,
                            descriptor
                        )

                        if parameters ~= nil then
                            pcall(object.editButton, parameters)
                        end
                    end
                end
            end
        end
    end
end

return CardHostService

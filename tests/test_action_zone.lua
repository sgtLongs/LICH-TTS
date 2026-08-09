local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")
local CardFieldGeometry =
    require("src/card_fields/CardFieldGeometry")
local ActionZone = require("src/card_fields/ActionZone")

local function copyPosition(position)
    return {
        x = position.x,
        y = position.y,
        z = position.z
    }
end

local function makeCard(guid, position)
    local currentPosition = copyPosition(position)
    local buttons = {
        {index = 1, click_function = "onCardTapped"}
    }
    local nextButtonIndex = 2
    local locked = false
    local card = {
        tag = "Card",
        lastCollide = nil,
        lastFast = nil,
        velocityStopped = false,
        angularVelocityStopped = false
    }

    card.getGUID = function()
        return guid
    end
    card.getPosition = function()
        return currentPosition
    end
    card.setPositionSmooth = function(target, collide, fast)
        currentPosition = copyPosition(target)
        card.lastCollide = collide
        card.lastFast = fast
    end
    card.setVelocity = function(velocity)
        card.velocityStopped = velocity[1] == 0
            and velocity[2] == 0
            and velocity[3] == 0
    end
    card.setAngularVelocity = function(velocity)
        card.angularVelocityStopped = velocity[1] == 0
            and velocity[2] == 0
            and velocity[3] == 0
    end
    card.getButtons = function()
        return buttons
    end
    card.createButton = function(parameters)
        parameters.index = nextButtonIndex
        nextButtonIndex = nextButtonIndex + 1
        buttons[#buttons + 1] = parameters
    end
    card.removeButton = function(buttonIndex)
        for index = #buttons, 1, -1 do
            if buttons[index].index == buttonIndex then
                table.remove(buttons, index)
                return
            end
        end
    end
    card.getLock = function()
        return locked
    end
    card.setLock = function(value)
        locked = value == true
    end
    card.isLocked = function()
        return locked
    end
    card.call = function(functionName, parameters)
        local tapButton = nil

        for _, button in ipairs(buttons) do
            if button.click_function == "onCardTapped" then
                tapButton = button
            end
        end

        if functionName == "setActionZoneTapEnabled" then
            if parameters.enabled == false and tapButton ~= nil then
                card.removeButton(tapButton.index)
            elseif parameters.enabled ~= false and tapButton == nil then
                card.createButton({click_function = "onCardTapped"})
            end
        elseif functionName == "refreshCardButtons"
            and tapButton == nil
        then
            card.createButton({click_function = "onCardTapped"})
        end
    end

    return card
end

local built = CardFieldGeometry.buildAll(Config)

Test.case("action zones expose five player-relative snap slots", function()
    local bottomField = built.fields[1]
    local bottomSlots = ActionZone.getSnapPositions(bottomField, 5)

    Test.equal(5, #bottomSlots)
    Test.near(-44, bottomSlots[1].x, 0.0001)
    Test.near(-40, bottomSlots[2].x, 0.0001)
    Test.near(-28, bottomSlots[5].x, 0.0001)
    Test.near(-35.5, bottomSlots[1].z, 0.0001)
    Test.near(-0.8, bottomSlots[1].y, 0.0001)
    Test.truthy(ActionZone.contains(bottomField, bottomSlots[1]))
    Test.falsy(ActionZone.contains(bottomField, {
        x = bottomField.position.x - 12,
        z = bottomSlots[1].z
    }))

    local topField = built.fields[4]
    local topSlots = ActionZone.getSnapPositions(topField, 5)

    -- A 180-degree field keeps slot one on that player's left, which is
    -- world-space right when viewed from the center of the table.
    Test.near(44, topSlots[1].x, 0.0001)
    Test.near(28, topSlots[5].x, 0.0001)
end)

Test.case("dropped action cards fill the next slot from the left", function()
    local field = built.fields[1]
    local slots = ActionZone.getSnapPositions(field, 5)
    local first = makeCard("first", slots[1])
    local second = makeCard("second", slots[2])
    local dropped = makeCard("dropped", {
        x = field.position.x,
        y = 3,
        z = slots[1].z
    })

    Test.truthy(ActionZone.onObjectDrop(
        built.fields,
        dropped,
        {first, second, dropped}
    ))

    Test.near(slots[1].x, first.getPosition().x, 0.0001)
    Test.near(slots[2].x, second.getPosition().x, 0.0001)
    Test.near(slots[3].x, dropped.getPosition().x, 0.0001)
    Test.near(slots[3].z, dropped.getPosition().z, 0.0001)
    Test.near(slots[3].y, dropped.getPosition().y, 0.0001)
    Test.falsy(dropped.lastCollide)
    Test.truthy(dropped.lastFast)
    Test.truthy(dropped.velocityStopped)
    Test.truthy(dropped.angularVelocityStopped)
end)

Test.case("more than five action cards redistribute evenly", function()
    local field = built.fields[1]
    local defaultSlots = ActionZone.getSnapPositions(field, 5)
    local cards = {}

    for index = 1, 5 do
        cards[index] = makeCard("card" .. index, defaultSlots[index])
    end

    local dropped = makeCard("card6", {
        -- The drop is just beyond the current last card. A drop directly on
        -- a card now intentionally joins that card's stack.
        x = defaultSlots[5].x + 1.8,
        y = 2,
        z = defaultSlots[1].z
    })
    cards[6] = dropped

    ActionZone.onObjectDrop(built.fields, dropped, cards)

    local overflowSlots = ActionZone.getSnapPositions(field, 6)
    Test.near(-44, cards[1].getPosition().x, 0.0001)
    Test.near(-40.8, cards[2].getPosition().x, 0.0001)
    Test.near(-28, cards[6].getPosition().x, 0.0001)

    for index, card in ipairs(cards) do
        Test.near(
            overflowSlots[index].x,
            card.getPosition().x,
            0.0001
        )
    end
end)

local function findButton(card, clickFunction)
    for _, button in ipairs(card.getButtons()) do
        if button.click_function == clickFunction then
            return button
        end
    end

    return nil
end

Test.case("cards dropped on action cards join an ordered stack", function()
    ActionZone.onLoad(built.fields, nil)
    local field = built.fields[1]
    local slot = ActionZone.getSnapPositions(field, 1)[1]
    local top = makeCard("stack-top", slot)
    local middle = makeCard("stack-middle", {
        x = slot.x,
        y = 2,
        z = slot.z
    })
    local bottom = makeCard("stack-bottom", {
        x = slot.x,
        y = 2,
        z = slot.z
    })
    local cards = {top, middle, bottom}

    Test.truthy(ActionZone.onObjectDrop(
        built.fields,
        middle,
        {top, middle}
    ))
    -- Drop the third card on the currently selected top card. It is inserted
    -- directly under that card without changing which card is selected.
    Test.truthy(ActionZone.onObjectDrop(built.fields, bottom, cards))

    local state = ActionZone.getSaveState(built.fields)
    local stack = state.fields[field.surfaceObjectGuid].stacks[1]
    Test.equal(1, #state.fields[field.surfaceObjectGuid].stacks)
    Test.equal("stack-top", stack.cards[1])
    Test.equal("stack-bottom", stack.cards[2])
    Test.equal("stack-middle", stack.cards[3])
    Test.equal(1, stack.selectedIndex)
    local stackCards, selectedIndex = ActionZone.getStackCards(
        built.fields,
        top,
        cards
    )
    Test.equal(top, stackCards[1])
    Test.equal(bottom, stackCards[2])
    Test.equal(middle, stackCards[3])
    Test.equal(1, selectedIndex)
    Test.truthy(top.getPosition().y > bottom.getPosition().y)
    Test.truthy(bottom.getPosition().y > middle.getPosition().y)
    local zOffset = Config.actionZone.stackCardZOffset
    Test.near(slot.z, top.getPosition().z, 0.0001)
    Test.near(slot.z + zOffset, bottom.getPosition().z, 0.0001)
    Test.near(slot.z + zOffset * 2, middle.getPosition().z, 0.0001)
    Test.falsy(top.isLocked())
    Test.truthy(bottom.isLocked())
    Test.truthy(middle.isLocked())
    Test.nilValue(findButton(top, "onActionStackUpClicked"))
    Test.truthy(findButton(top, "onActionStackDownClicked"))
    Test.truthy(findButton(top, "onCardTapped"))
    Test.nilValue(findButton(bottom, "onCardTapped"))
    Test.nilValue(findButton(middle, "onCardTapped"))
    Test.equal(0, #middle.getButtons())
    Test.equal(0, #bottom.getButtons())
end)

Test.case("stack arrows change the raised card without reordering", function()
    ActionZone.onLoad(built.fields, nil)
    local field = built.fields[1]
    local slot = ActionZone.getSnapPositions(field, 1)[1]
    local top = makeCard("navigate-top", slot)
    local middle = makeCard("navigate-middle", {
        x = slot.x,
        y = 2,
        z = slot.z
    })
    local bottom = makeCard("navigate-bottom", {
        x = slot.x,
        y = 2,
        z = slot.z
    })
    local cards = {top, middle, bottom}

    ActionZone.onObjectDrop(built.fields, middle, {top, middle})
    -- Select the lower card before adding another beneath it.
    ActionZone.onStackNavigationClicked(
        built.fields,
        top,
        1,
        {top, middle}
    )
    bottom.setPositionSmooth({
        x = middle.getPosition().x,
        y = 2,
        z = middle.getPosition().z
    }, false, true)
    ActionZone.onObjectDrop(built.fields, bottom, cards)
    local fixedTopZ = top.getPosition().z
    local fixedMiddleZ = middle.getPosition().z
    local fixedBottomZ = bottom.getPosition().z

    Test.equal(bottom, ActionZone.onStackNavigationClicked(
        built.fields,
        middle,
        1,
        cards
    ))
    Test.truthy(bottom.getPosition().y > top.getPosition().y)
    Test.truthy(top.getPosition().y > middle.getPosition().y)
    Test.near(fixedTopZ, top.getPosition().z, 0.0001)
    Test.near(fixedMiddleZ, middle.getPosition().z, 0.0001)
    Test.near(fixedBottomZ, bottom.getPosition().z, 0.0001)
    Test.truthy(top.isLocked())
    Test.truthy(middle.isLocked())
    Test.falsy(bottom.isLocked())
    Test.truthy(findButton(bottom, "onActionStackUpClicked"))
    Test.nilValue(findButton(bottom, "onActionStackDownClicked"))
    Test.nilValue(findButton(top, "onCardTapped"))
    Test.nilValue(findButton(middle, "onCardTapped"))
    Test.truthy(findButton(bottom, "onCardTapped"))

    Test.equal(middle, ActionZone.onStackNavigationClicked(
        built.fields,
        bottom,
        -1,
        cards
    ))
    Test.truthy(middle.getPosition().y > top.getPosition().y)
    Test.near(fixedTopZ, top.getPosition().z, 0.0001)
    Test.near(fixedMiddleZ, middle.getPosition().z, 0.0001)
    Test.near(fixedBottomZ, bottom.getPosition().z, 0.0001)
    Test.truthy(top.isLocked())
    Test.falsy(middle.isLocked())
    Test.truthy(bottom.isLocked())
    Test.truthy(findButton(middle, "onActionStackUpClicked"))
    Test.truthy(findButton(middle, "onActionStackDownClicked"))
    local upConfig = Config.actionZone.navigationButtons.up
    local downConfig = Config.actionZone.navigationButtons.down
    local configuredUp = findButton(middle, "onActionStackUpClicked")
    local configuredDown = findButton(middle, "onActionStackDownClicked")
    Test.equal(upConfig.width, configuredUp.width)
    Test.equal(upConfig.height, configuredUp.height)
    Test.equal(downConfig.width, configuredDown.width)
    Test.equal(downConfig.height, configuredDown.height)
    Test.equal(upConfig.position.z, configuredUp.position.z)
    Test.equal(downConfig.position.z, configuredDown.position.z)
    Test.nilValue(findButton(top, "onCardTapped"))
    Test.truthy(findButton(middle, "onCardTapped"))
    Test.nilValue(findButton(bottom, "onCardTapped"))

    Test.truthy(ActionZone.onCardRotationChanged(
        built.fields,
        middle,
        true,
        cards
    ))
    local rotatedUp = findButton(middle, "onActionStackUpClicked")
    local rotatedDown = findButton(middle, "onActionStackDownClicked")
    Test.equal(-90, rotatedUp.rotation[2])
    Test.equal(-90, rotatedDown.rotation[2])
    Test.near(upConfig.position.z, rotatedUp.position.x, 0.0001)
    Test.near(downConfig.position.z, rotatedDown.position.x, 0.0001)
    Test.near(-upConfig.position.x, rotatedUp.position.z, 0.0001)
    Test.near(-downConfig.position.x, rotatedDown.position.z, 0.0001)

    local state = ActionZone.getSaveState(built.fields)
    local stack = state.fields[field.surfaceObjectGuid].stacks[1]
    Test.equal("navigate-top", stack.cards[1])
    Test.equal("navigate-middle", stack.cards[2])
    Test.equal("navigate-bottom", stack.cards[3])
    Test.equal(2, stack.selectedIndex)
end)

Test.case("action rows compact after a card is removed", function()
    local field = built.fields[1]
    local slots = ActionZone.getSnapPositions(field, 5)
    local first = makeCard("remove-first", slots[1])
    local removed = makeCard("remove-middle", slots[2])
    local third = makeCard("remove-third", slots[3])
    local cards = {first, removed, third}

    Test.truthy(ActionZone.onObjectPickUp(built.fields, removed))
    removed.setPositionSmooth({
        x = field.position.x,
        y = 2,
        z = field.position.z
    }, false, true)
    Test.falsy(ActionZone.onObjectDrop(built.fields, removed, cards))

    Test.near(slots[1].x, first.getPosition().x, 0.0001)
    Test.near(slots[2].x, third.getPosition().x, 0.0001)
end)

Test.case("scripted card actions immediately compact action rows", function()
    local field = built.fields[1]
    local slots = ActionZone.getSnapPositions(field, 5)
    local first = makeCard("action-first", slots[1])
    local leaving = makeCard("action-leaving", slots[2])
    local third = makeCard("action-third", slots[3])

    Test.truthy(ActionZone.onCardLeaves(
        built.fields,
        leaving,
        {first, leaving, third}
    ))

    Test.near(slots[1].x, first.getPosition().x, 0.0001)
    Test.near(slots[2].x, third.getPosition().x, 0.0001)
    -- The action controller excludes the departing card without moving it;
    -- the card's own return/destroy/damn/unequip action owns its destination.
    Test.near(slots[2].x, leaving.getPosition().x, 0.0001)
end)

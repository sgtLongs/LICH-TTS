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
        x = field.position.x,
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

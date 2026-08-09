local Test = require("tests/support/Test")
local FakeWait = require("tests/support/FakeWait")
local Config = require("src/config/CardFieldConfig")
local CardFieldGeometry =
    require("src/card_fields/CardFieldGeometry")
local ActionZone = require("src/card_fields/ActionZone")
local ActionZoneLayout =
    require("src/card_fields/zones/ActionZoneLayout")
local ActionZoneRules =
    require("src/card_fields/zones/ActionZoneRules")
local ActionZoneState =
    require("src/card_fields/zones/ActionZoneState")
local ActionZoneController =
    require("src/card_fields/zones/ActionZoneController")

local function copyPosition(position)
    return {
        x = position.x,
        y = position.y,
        z = position.z
    }
end

local function makeCard(guid, position, options)
    options = options or {}
    local currentPosition = copyPosition(position)
    local buttons = {}
    local nextButtonIndex = 1
    local locked = options.locked == true
    local card = {
        tag = options.tag or "Card",
        lockHistory = {},
        tapEnableCalls = {},
        rotationQueryCount = 0,
        tapRotated = options.tapRotated == true,
        returnTapRotation = options.returnTapRotation ~= false
    }

    local function addButton(parameters)
        parameters.index = nextButtonIndex
        nextButtonIndex = nextButtonIndex + 1
        buttons[#buttons + 1] = parameters
    end

    if options.tapButton ~= false then
        addButton({click_function = "onCardTapped"})
    end

    card.getGUID = function()
        return guid
    end
    card.getPosition = function()
        return currentPosition
    end
    card.setTestPosition = function(target)
        currentPosition = copyPosition(target)
    end
    card.setPositionSmooth = function(target)
        currentPosition = copyPosition(target)
    end
    card.setVelocity = function()
    end
    card.setAngularVelocity = function()
    end
    card.getButtons = function()
        return buttons
    end
    card.createButton = function(parameters)
        addButton(parameters)
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
        card.lockHistory[#card.lockHistory + 1] = locked
    end
    card.isLocked = function()
        return locked
    end
    card.call = function(functionName, parameters)
        if functionName == "getActionZoneTapRotation" then
            card.rotationQueryCount = card.rotationQueryCount + 1

            if card.returnTapRotation then
                return card.tapRotated
            end

            return nil
        end

        local tapButton = nil

        for _, button in ipairs(buttons) do
            if button.click_function == "onCardTapped" then
                tapButton = button
                break
            end
        end

        if functionName == "setActionZoneTapEnabled" then
            card.tapEnableCalls[#card.tapEnableCalls + 1] = parameters

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

local function findButton(card, clickFunction)
    for _, button in ipairs(card.getButtons()) do
        if button.click_function == clickFunction then
            return button
        end
    end

    return nil
end

local function newFields(savedState)
    local built = CardFieldGeometry.buildAll(Config)
    ActionZone.onLoad(built.fields, savedState)
    return built.fields
end

local function localToWorld(field, localX, localZ)
    local radians = math.rad(field.downRotationDegrees or 0)
    local cosine = math.cos(radians)
    local sine = math.sin(radians)

    return {
        x = field.position.x + localX * cosine + localZ * sine,
        y = 123,
        z = field.position.z - localX * sine + localZ * cosine
    }
end

local function savedStack(fields, field, stackIndex)
    local saved = ActionZone.getSaveState(fields)
    return saved.fields[field.surfaceObjectGuid].stacks[stackIndex]
end

Test.case("rotated action-zone boundaries are inclusive", function()
    local field = CardFieldGeometry.buildField({
        playerColor = "Test",
        surfaceObjectGuid = "rotated-field",
        position = {x = 12, z = -7},
        rotationDegrees = 90,
        size = {x = 28, z = 16.5}
    }, Config)
    local zone = field.actionZone
    local topLeft = localToWorld(field, zone.localLeft, zone.localTop)
    local bottomRight = localToWorld(
        field,
        zone.localRight,
        zone.localBottom
    )

    Test.truthy(ActionZone.contains(field, topLeft))
    Test.truthy(ActionZone.contains(field, bottomRight))
    Test.equal(field, ActionZone.findField({field}, bottomRight))
    Test.falsy(ActionZone.contains(
        field,
        localToWorld(field, zone.localLeft - 0.0001, zone.localTop)
    ))
    Test.falsy(ActionZone.contains(
        field,
        localToWorld(field, zone.localRight, zone.localBottom + 0.0001)
    ))
    Test.falsy(ActionZone.contains(field, nil))
end)

Test.case("malformed action-zone save roots restore empty fields", function()
    local fields = newFields("not-a-save-table")
    local saved = ActionZone.getSaveState(fields)

    for _, field in ipairs(fields) do
        Test.equal(
            0,
            #saved.fields[field.surfaceObjectGuid].stacks
        )
    end

    fields = newFields({
        fields = "not-a-field-table",
        originalLocks = "not-a-lock-table"
    })
    saved = ActionZone.getSaveState(fields)
    Test.equal(0, #saved.fields[fields[1].surfaceObjectGuid].stacks)
    Test.equal(nil, next(saved.originalLocks))
end)

Test.case("saved stacks sanitize malformed and duplicate card keys", function()
    local built = CardFieldGeometry.buildAll(Config)
    local field = built.fields[1]
    local fieldId = field.surfaceObjectGuid
    local fields = newFields({
        fields = {
            [fieldId] = {
                stacks = {
                    "not-a-stack",
                    {cards = "not-an-array"},
                    {
                        cards = {"alpha", "alpha", "", 12},
                        selectedIndex = 99
                    },
                    {
                        cards = {"beta", "alpha", "gamma"},
                        selectedIndex = -4
                    },
                    {cards = {}}
                }
            }
        },
        originalLocks = {
            alpha = true,
            beta = false,
            [7] = true
        }
    })
    local saved = ActionZone.getSaveState(fields)
    local stacks = saved.fields[fieldId].stacks

    Test.equal(2, #stacks)
    Test.equal(2, #stacks[1].cards)
    Test.equal("alpha", stacks[1].cards[1])
    Test.equal("12", stacks[1].cards[2])
    Test.equal(2, stacks[1].selectedIndex)
    Test.equal(2, #stacks[2].cards)
    Test.equal("beta", stacks[2].cards[1])
    Test.equal("gamma", stacks[2].cards[2])
    Test.equal(1, stacks[2].selectedIndex)
    Test.equal(true, saved.originalLocks.alpha)
    Test.equal(false, saved.originalLocks.beta)
    Test.equal(true, saved.originalLocks["7"])
end)

Test.case("action-zone save state round-trips stack selections", function()
    local built = CardFieldGeometry.buildAll(Config)
    local fieldId = built.fields[1].surfaceObjectGuid
    local initialState = {
        fields = {
            [fieldId] = {
                stacks = {
                    {
                        cards = {"one", "two", "three"},
                        selectedIndex = 2
                    },
                    {
                        cards = {"four"},
                        selectedIndex = 1
                    }
                }
            }
        },
        originalLocks = {
            one = true,
            two = false
        }
    }
    local fields = newFields(initialState)
    local firstSave = ActionZone.getSaveState(fields)

    ActionZone.onLoad(fields, firstSave)
    local secondSave = ActionZone.getSaveState(fields)
    local stacks = secondSave.fields[fieldId].stacks

    Test.equal(2, #stacks)
    Test.equal(3, #stacks[1].cards)
    Test.equal("one", stacks[1].cards[1])
    Test.equal("two", stacks[1].cards[2])
    Test.equal("three", stacks[1].cards[3])
    Test.equal(2, stacks[1].selectedIndex)
    Test.equal("four", stacks[2].cards[1])
    Test.equal(1, stacks[2].selectedIndex)
    Test.equal(true, secondSave.originalLocks.one)
    Test.equal(false, secondSave.originalLocks.two)
end)

Test.case("a cross-field drop compacts the source and fills the target", function()
    local fields = newFields(nil)
    local sourceField = fields[1]
    local targetField = fields[4]
    local sourceSlots = ActionZone.getSnapPositions(sourceField, 2)
    local first = makeCard("cross-first", sourceSlots[1])
    local moving = makeCard("cross-moving", sourceSlots[2])
    local cards = {first, moving}

    ActionZone.refresh(fields, cards)
    Test.truthy(ActionZone.onObjectPickUp(fields, moving, cards))
    moving.setTestPosition(
        ActionZone.getSnapPositions(targetField, 1)[1]
    )

    Test.truthy(ActionZone.onObjectDrop(fields, moving, cards))

    local saved = ActionZone.getSaveState(fields)
    local sourceStacks =
        saved.fields[sourceField.surfaceObjectGuid].stacks
    local targetStacks =
        saved.fields[targetField.surfaceObjectGuid].stacks
    local sourceSnap = ActionZone.getSnapPositions(sourceField, 1)[1]
    local targetSnap = ActionZone.getSnapPositions(targetField, 1)[1]

    Test.equal(1, #sourceStacks)
    Test.equal("cross-first", sourceStacks[1].cards[1])
    Test.equal(1, #targetStacks)
    Test.equal("cross-moving", targetStacks[1].cards[1])
    Test.near(sourceSnap.x, first.getPosition().x, 0.0001)
    Test.near(targetSnap.x, moving.getPosition().x, 0.0001)
    Test.near(targetSnap.z, moving.getPosition().z, 0.0001)
end)

Test.case("dropping outside every action zone removes and compacts", function()
    local fields = newFields(nil)
    local field = fields[1]
    local slots = ActionZone.getSnapPositions(field, 2)
    local first = makeCard("outside-first", slots[1])
    local leaving = makeCard("outside-leaving", slots[2])
    local cards = {first, leaving}

    ActionZone.refresh(fields, cards)
    Test.truthy(ActionZone.onObjectPickUp(fields, leaving, cards))
    leaving.setTestPosition({
        x = field.position.x,
        y = 2,
        z = field.position.z
    })

    Test.falsy(ActionZone.onObjectDrop(fields, leaving, cards))

    local stack = savedStack(fields, field, 1)
    local compactedPosition = ActionZone.getSnapPositions(field, 1)[1]
    Test.equal(1, #stack.cards)
    Test.equal("outside-first", stack.cards[1])
    Test.near(compactedPosition.x, first.getPosition().x, 0.0001)
    Test.truthy(findButton(leaving, "onCardTapped"))
end)

Test.case("dissolving a stack restores each original lock", function()
    local built = CardFieldGeometry.buildAll(Config)
    local fieldId = built.fields[1].surfaceObjectGuid
    local fields = newFields({
        fields = {
            [fieldId] = {
                stacks = {
                    {
                        cards = {"locked-top", "free-bottom"},
                        selectedIndex = 1
                    }
                }
            }
        },
        originalLocks = {
            ["locked-top"] = true,
            ["free-bottom"] = false
        }
    })
    local field = fields[1]
    local slot = ActionZone.getSnapPositions(field, 1)[1]
    local top = makeCard("locked-top", slot, {locked = false})
    local bottom = makeCard("free-bottom", slot, {locked = false})
    local cards = {top, bottom}

    ActionZone.refresh(fields, cards)
    Test.truthy(top.isLocked())
    Test.truthy(bottom.isLocked())
    Test.truthy(ActionZone.onCardLeaves(fields, bottom, cards))

    Test.truthy(top.isLocked())
    Test.falsy(bottom.isLocked())
    Test.truthy(findButton(bottom, "onCardTapped"))
    Test.equal(nil, next(ActionZone.getSaveState(fields).originalLocks))
end)

Test.case("invalid stack navigation leaves selection unchanged", function()
    local built = CardFieldGeometry.buildAll(Config)
    local fieldId = built.fields[1].surfaceObjectGuid
    local fields = newFields({
        fields = {
            [fieldId] = {
                stacks = {
                    {
                        cards = {"nav-top", "nav-bottom"},
                        selectedIndex = 1
                    }
                }
            }
        }
    })
    local field = fields[1]
    local slot = ActionZone.getSnapPositions(field, 1)[1]
    local top = makeCard("nav-top", slot)
    local bottom = makeCard("nav-bottom", slot)
    local cards = {top, bottom}
    local nonCard = makeCard("not-a-card", slot, {tag = "Token"})

    ActionZone.refresh(fields, cards)
    Test.falsy(ActionZone.onStackNavigationClicked(
        fields,
        top,
        -1,
        cards
    ))
    Test.falsy(ActionZone.onStackNavigationClicked(
        fields,
        top,
        0,
        cards
    ))
    Test.falsy(ActionZone.onStackNavigationClicked(
        fields,
        top,
        "bad",
        cards
    ))
    Test.falsy(ActionZone.onStackNavigationClicked(
        fields,
        bottom,
        1,
        cards
    ))
    Test.falsy(ActionZone.onStackNavigationClicked(
        fields,
        nonCard,
        1,
        cards
    ))
    Test.equal(1, savedStack(fields, field, 1).selectedIndex)
end)

Test.case("the configured stack-drop boundary is inclusive", function()
    local function stackCountAtOffset(offset)
        local fields = newFields(nil)
        local field = fields[1]
        local zone = field.actionZone
        local target = makeCard(
            "threshold-target",
            localToWorld(field, 0, zone.localCenterZ)
        )
        local dropped = makeCard(
            "threshold-drop",
            localToWorld(field, offset, zone.localCenterZ)
        )

        ActionZone.onObjectDrop(fields, dropped, {target, dropped})
        return ActionZone.getSaveState(fields)
            .fields[field.surfaceObjectGuid].stacks
    end

    local halfWidth = Config.actionZone.stackDropHalfWidth
    local exactStacks = stackCountAtOffset(halfWidth)
    local outsideStacks = stackCountAtOffset(halfWidth + 0.0001)

    Test.equal(1, #exactStacks)
    Test.equal(2, #exactStacks[1].cards)
    Test.equal("threshold-target", exactStacks[1].cards[1])
    Test.equal("threshold-drop", exactStacks[1].cards[2])
    Test.equal(2, #outsideStacks)
end)

Test.case("a drop joins the nearest eligible card", function()
    local fields = newFields(nil)
    local field = fields[1]
    local zone = field.actionZone
    local farther = makeCard(
        "nearest-farther",
        localToWorld(field, -2, zone.localCenterZ)
    )
    local nearer = makeCard(
        "nearest-nearer",
        localToWorld(field, 0, zone.localCenterZ)
    )
    local dropped = makeCard(
        "nearest-drop",
        localToWorld(field, -0.8, zone.localCenterZ)
    )

    Test.truthy(ActionZone.onObjectDrop(
        fields,
        dropped,
        {farther, nearer, dropped}
    ))

    local stacks = ActionZone.getSaveState(fields)
        .fields[field.surfaceObjectGuid].stacks
    Test.equal(2, #stacks)
    Test.equal("nearest-farther", stacks[1].cards[1])
    Test.equal(1, #stacks[1].cards)
    Test.equal("nearest-nearer", stacks[2].cards[1])
    Test.equal("nearest-drop", stacks[2].cards[2])
end)

Test.case("refresh prunes stale stack cards and restores their lock", function()
    local built = CardFieldGeometry.buildAll(Config)
    local fieldId = built.fields[1].surfaceObjectGuid
    local fields = newFields({
        fields = {
            [fieldId] = {
                stacks = {
                    {
                        cards = {"fresh-card", "stale-card"},
                        selectedIndex = 1
                    }
                }
            }
        },
        originalLocks = {
            ["fresh-card"] = false,
            ["stale-card"] = false
        }
    })
    local field = fields[1]
    local slot = ActionZone.getSnapPositions(field, 1)[1]
    local fresh = makeCard("fresh-card", slot)
    local stale = makeCard("stale-card", slot)

    ActionZone.refresh(fields, {fresh, stale})
    Test.truthy(stale.isLocked())
    ActionZone.refresh(fields, {fresh})

    local stack = savedStack(fields, field, 1)
    Test.equal(1, #stack.cards)
    Test.equal("fresh-card", stack.cards[1])
    Test.falsy(fresh.isLocked())
    Test.falsy(stale.isLocked())
    Test.equal(nil, next(ActionZone.getSaveState(fields).originalLocks))
end)

Test.case("rotation reported outside a zone clears cached arrow rotation", function()
    local built = CardFieldGeometry.buildAll(Config)
    local fieldId = built.fields[1].surfaceObjectGuid
    local fields = newFields({
        fields = {
            [fieldId] = {
                stacks = {
                    {
                        cards = {"rotate-top", "rotate-bottom"},
                        selectedIndex = 1
                    }
                }
            }
        }
    })
    local field = fields[1]
    local slot = ActionZone.getSnapPositions(field, 1)[1]
    local top = makeCard("rotate-top", slot, {
        returnTapRotation = false
    })
    local bottom = makeCard("rotate-bottom", slot)
    local cards = {top, bottom}

    ActionZone.refresh(fields, cards)
    Test.truthy(ActionZone.onCardRotationChanged(
        fields,
        top,
        true,
        cards
    ))
    Test.equal(
        -90,
        findButton(top, "onActionStackDownClicked").rotation[2]
    )

    local insidePosition = copyPosition(top.getPosition())
    top.setTestPosition({
        x = field.position.x,
        y = 2,
        z = field.position.z
    })
    local queryCount = top.rotationQueryCount

    Test.falsy(ActionZone.onCardRotationChanged(
        fields,
        top,
        true,
        cards
    ))
    Test.equal(queryCount, top.rotationQueryCount)

    top.setTestPosition(insidePosition)
    ActionZone.refresh(fields, cards)
    Test.equal(
        0,
        findButton(top, "onActionStackDownClicked").rotation[2]
    )
end)

Test.case("malformed live objects are rejected without state changes", function()
    local fields = newFields(nil)
    local field = fields[1]
    local position = ActionZone.getSnapPositions(field, 1)[1]
    local token = makeCard("token", position, {tag = "Token"})
    local missingPosition = {
        tag = "Card",
        getGUID = function()
            return "missing-position"
        end
    }

    Test.falsy(ActionZone.onObjectPickUp(fields, nil, {}))
    Test.falsy(ActionZone.onObjectPickUp(fields, token, {token}))
    Test.falsy(ActionZone.onObjectDrop(
        fields,
        missingPosition,
        {missingPosition}
    ))
    Test.falsy(ActionZone.onCardLeaves(fields, token, {token}))
    Test.falsy(ActionZone.onStackNavigationClicked(
        fields,
        token,
        1,
        {token}
    ))
    Test.falsy(ActionZone.onCardRotationChanged(
        fields,
        missingPosition,
        true,
        {missingPosition}
    ))
    Test.falsy(ActionZone.arrange({}, nil, {}))
    Test.equal(0, #ActionZone.getSnapPositions(nil, 5))
    Test.equal(0, #ActionZone.getSaveState(fields)
        .fields[field.surfaceObjectGuid].stacks)
end)

Test.case("pure action rules insert after every target depth", function()
    local targetIds = {"top", "middle", "bottom"}
    local expectedOrders = {
        {"top", "new", "middle", "bottom"},
        {"top", "middle", "new", "bottom"},
        {"top", "middle", "bottom", "new"}
    }

    for index, targetId in ipairs(targetIds) do
        local fieldState = {
            stacks = {{
                cards = {"top", "middle", "bottom"},
                selectedKey = "middle"
            }}
        }
        local nextState, effects = ActionZoneRules.drop(
            fieldState,
            "new",
            targetId
        )

        Test.equal(fieldState, nextState)
        Test.deepEqual(expectedOrders[index], nextState.stacks[1].cards)
        Test.equal("middle", nextState.stacks[1].selectedKey)
        Test.equal("arrange", effects[1].type)
        Test.equal(targetId, effects[1].targetCardId)
    end
end)

Test.case("pure action state removes every selected depth predictably", function()
    local cases = {
        {
            selected = "top",
            removed = "top",
            cards = {"middle", "bottom"},
            nextSelected = "middle"
        },
        {
            selected = "middle",
            removed = "middle",
            cards = {"top", "bottom"},
            nextSelected = "bottom"
        },
        {
            selected = "bottom",
            removed = "bottom",
            cards = {"top", "middle"},
            nextSelected = "middle"
        }
    }

    for _, case in ipairs(cases) do
        local fieldState = {
            stacks = {{
                cards = {"top", "middle", "bottom"},
                selectedKey = case.selected
            }}
        }

        Test.truthy(ActionZoneState.removeCard(
            fieldState,
            case.removed
        ))
        Test.deepEqual(case.cards, fieldState.stacks[1].cards)
        Test.equal(case.nextSelected, fieldState.stacks[1].selectedKey)
    end
end)

Test.case("pure drop scoring preserves both inclusive thresholds", function()
    local field = CardFieldGeometry.buildAll(Config).fields[1]
    local zone = field.actionZone
    local dropped = ActionZoneLayout.toWorld(0, zone.localCenterZ, field)
    local exact = ActionZoneLayout.toWorld(
        zone.stackDropHalfWidth,
        zone.localCenterZ + zone.stackDropHalfDepth,
        field
    )
    local outside = ActionZoneLayout.toWorld(
        zone.stackDropHalfWidth + 0.0001,
        zone.localCenterZ,
        field
    )
    exact.y = 1
    outside.y = 3

    Test.equal("exact", ActionZoneLayout.findDropTarget(
        field,
        dropped,
        {{cardId = "exact", position = exact}}
    ))
    Test.nilValue(ActionZoneLayout.findDropTarget(
        field,
        dropped,
        {{cardId = "outside", position = outside}}
    ))

    local low = copyPosition(dropped)
    local high = copyPosition(dropped)
    low.y = 1
    high.y = 2
    Test.equal("high", ActionZoneLayout.findDropTarget(
        field,
        dropped,
        {
            {cardId = "low", position = low},
            {cardId = "high", position = high}
        }
    ))
end)

Test.case("pure action layout supports every configured field", function()
    local fields = CardFieldGeometry.buildAll(Config).fields

    Test.equal(6, #fields)

    for _, field in ipairs(fields) do
        local positions = ActionZoneLayout.getSnapPositions(field, 7)
        Test.equal(7, #positions)

        for _, position in ipairs(positions) do
            Test.truthy(ActionZoneLayout.contains(field, position))
        end

        local firstLocal = ActionZoneLayout.toLocal(positions[1], field)
        local lastLocal = ActionZoneLayout.toLocal(positions[7], field)
        Test.truthy(firstLocal.x < lastLocal.x)
        Test.near(
            field.actionZone.localCenterZ,
            firstLocal.z,
            0.0001
        )
    end
end)

Test.case("action-zone controller instances isolate their state", function()
    local fields = CardFieldGeometry.buildAll(Config).fields
    local fieldId = fields[1].surfaceObjectGuid
    local first = ActionZone.new()
    local second = ActionZone.new()

    first:onLoad(fields, {
        fields = {
            [fieldId] = {
                stacks = {{cards = {"only-first"}, selectedIndex = 1}}
            }
        }
    })
    second:onLoad(fields, nil)

    Test.equal(
        "only-first",
        first:getSaveState(fields).fields[fieldId].stacks[1].cards[1]
    )
    Test.equal(0, #second:getSaveState(fields).fields[fieldId].stacks)
end)

Test.case(
    "constructed action controllers repeat tap cleanup after three frames",
    function()
        local wait = FakeWait.new()
        local controller = ActionZoneController.new({scheduler = wait})
        local card = makeCard("legacy-tap", {x = 0, y = 1, z = 0})

        controller:setTapEnabled(card, false)
        Test.nilValue(findButton(card, "onCardTapped"))
        Test.equal(1, wait.pendingCount())

        -- Legacy card scripts recreate their tap button two frames after a
        -- drop. The controller's delayed cleanup must remove that button on
        -- frame three, without running early.
        card.call("refreshCardButtons")
        Test.truthy(findButton(card, "onCardTapped"))
        wait.advanceFrames(2)
        Test.truthy(findButton(card, "onCardTapped"))
        Test.equal(1, wait.pendingCount())

        wait.advanceFrames(1)
        Test.nilValue(findButton(card, "onCardTapped"))
        Test.equal(0, wait.pendingCount())
    end
)

Test.case(
    "constructed action controllers apply navigation effects next frame",
    function()
        local wait = FakeWait.new()
        local fields = CardFieldGeometry.buildAll(Config).fields
        local field = fields[1]
        local fieldId = field.surfaceObjectGuid
        local slot = ActionZoneLayout.getSnapPositions(field, 1)[1]
        local top = makeCard("scheduled-top", slot)
        local bottom = makeCard("scheduled-bottom", slot)
        local cards = {top, bottom}
        local controller = ActionZoneController.new({
            scheduler = wait,
            runtime = {
                getAllObjects = function()
                    return cards
                end,
                getGlobalOwner = function()
                    return {name = "test-global"}
                end
            }
        })

        controller:onLoad(fields, {
            fields = {
                [fieldId] = {
                    stacks = {{
                        cards = {"scheduled-top", "scheduled-bottom"},
                        selectedIndex = 1
                    }}
                }
            }
        })
        controller:refresh(fields, cards)

        Test.truthy(top.getPosition().y > bottom.getPosition().y)
        Test.truthy(findButton(top, "onActionStackDownClicked"))
        Test.nilValue(findButton(bottom, "onActionStackUpClicked"))

        Test.truthy(controller:navigateStack(
            fields,
            top,
            1,
            cards,
            {preserveCardPreview = true}
        ))

        -- Selection state changes during the click, but all object and button
        -- effects stay untouched until the scheduled next-frame callback.
        local selectedBeforeFrame = controller:getSaveState(fields)
            .fields[fieldId].stacks[1].selectedIndex
        Test.equal(2, selectedBeforeFrame)
        Test.truthy(top.getPosition().y > bottom.getPosition().y)
        Test.truthy(findButton(top, "onActionStackDownClicked"))
        Test.nilValue(findButton(bottom, "onActionStackUpClicked"))

        wait.advanceFrames(1)

        Test.truthy(bottom.getPosition().y > top.getPosition().y)
        Test.nilValue(findButton(top, "onActionStackDownClicked"))
        Test.truthy(findButton(bottom, "onActionStackUpClicked"))
        Test.truthy(top.isLocked())
        Test.falsy(bottom.isLocked())
        Test.truthy(
            top.tapEnableCalls[#top.tapEnableCalls].preserveCardPreview
        )
        Test.truthy(
            bottom.tapEnableCalls[#bottom.tapEnableCalls]
                .preserveCardPreview
        )
    end
)

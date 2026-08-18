local Test = require("tests/support/Test")
local Config = require("src/config/CardFieldConfig")

local records = nil
local makeBuiltFields = nil

local CardFieldGeometry = {}
local ActionZone = {}
local DeckSelectionMenu = {}

function CardFieldGeometry.buildAll(config)
    records.geometryConfig = config
    local built = makeBuiltFields()
    records.built = built
    return built
end

function ActionZone.onLoad(fields, savedState)
    records.actionLoad = {
        fields = fields,
        savedState = savedState
    }
end

function ActionZone.getSaveState(fields)
    records.actionSaveFields = fields
    return records.actionSaveState
end

function ActionZone.refresh(fields)
    records.actionRefreshFields = fields
end

function ActionZone.onObjectPickUp(fields, object)
    records.pickUp = {fields = fields, object = object}
    return records.actionReturns.pickUp
end

function ActionZone.onObjectDrop(fields, object)
    if records.eventOrder ~= nil then
        records.eventOrder[#records.eventOrder + 1] = "action"
    end

    records.drop = {fields = fields, object = object}
    return records.actionReturns.drop
end

function ActionZone.onCardLeaves(fields, object)
    records.cardLeaves = {fields = fields, object = object}
    return records.actionReturns.cardLeaves
end

function ActionZone.onStackNavigationClicked(fields, object, direction)
    records.navigation = {
        fields = fields,
        object = object,
        direction = direction
    }
    return records.actionReturns.navigation
end

function ActionZone.navigateStack(fields, object, direction, _, context)
    records.navigation = {
        fields = fields,
        object = object,
        direction = direction,
        context = context
    }
    return records.actionReturns.navigation
end

function ActionZone.onCardRotationChanged(fields, object, rotated)
    records.rotation = {
        fields = fields,
        object = object,
        rotated = rotated
    }
    return records.actionReturns.rotation
end

function DeckSelectionMenu.initialize()
    records.menuInitializeCount = records.menuInitializeCount + 1
end

function DeckSelectionMenu.open(playerColor, field, spawnPosition)
    records.menuOpen = {
        playerColor = playerColor,
        field = field,
        spawnPosition = spawnPosition
    }
    return records.menuOpenResult
end

function DeckSelectionMenu.handleAction(playerColor, action)
    records.menuAction = {
        playerColor = playerColor,
        action = action
    }
    return records.menuActionResult
end

function DeckSelectionMenu.generateRandom(field, spawnPosition)
    records.randomDeck = {
        field = field,
        spawnPosition = spawnPosition
    }
    return records.randomDeckResult, records.randomDeckChoice
end

local dependencyNames = {
    "src/card_fields/CardFieldGeometry",
    "src/card_fields/ActionZone",
    "src/action_points/ActionPoints",
    "src/card_fields/DeckSelectionMenu",
    "src/card_fields/CardFieldDefinitions",
    "src/card_fields/CardFieldLayout",
    "src/card_fields/CardFieldState",
    "src/card_fields/zones/ZoneBehaviorRegistry",
    "src/card_fields/CardFieldController",
    "src/card_fields/CardFields"
}
local savedDependencies = {}

for _, name in ipairs(dependencyNames) do
    savedDependencies[name] = package.loaded[name]
end

package.loaded["src/card_fields/CardFieldGeometry"] = CardFieldGeometry
package.loaded["src/card_fields/ActionZone"] = ActionZone
package.loaded["src/card_fields/DeckSelectionMenu"] = DeckSelectionMenu
package.loaded["src/card_fields/CardFieldDefinitions"] = nil
package.loaded["src/card_fields/CardFieldLayout"] = nil
package.loaded["src/card_fields/CardFieldState"] = nil
package.loaded["src/card_fields/zones/ZoneBehaviorRegistry"] = nil
package.loaded["src/card_fields/CardFieldController"] = nil
package.loaded["src/card_fields/CardFields"] = nil

local CardFields = require("src/card_fields/CardFields")

for _, name in ipairs(dependencyNames) do
    package.loaded[name] = savedDependencies[name]
end

local RealCardFieldDefinitions =
    require("src/card_fields/CardFieldDefinitions")
local RealCardFieldState = require("src/card_fields/CardFieldState")
local ZoneBehaviorRegistry =
    require("src/card_fields/zones/ZoneBehaviorRegistry")

local function makeFields()
    return {
        fields = {
            {
                playerColor = "White",
                ownerColor = "Red",
                surfaceObjectGuid = "red-surface",
                position = {x = 10, y = -1, z = 20},
                deckSlot = {x = 6, y = -1, z = 22}
            },
            {
                playerColor = "Green",
                ownerColor = "Blue",
                surfaceObjectGuid = "blue-surface",
                position = {x = -10, y = -1, z = -20},
                deckSlot = {x = -6, y = -1, z = -22}
            }
        },
        lines = {
            {points = {{0, 0, 0}, {1, 0, 1}}}
        }
    }
end

local function makeSurface(guid, initialButtons)
    local buttons = initialButtons or {}
    local nextButtonIndex = 100
    local surface = {
        createdButtons = {},
        editedButtons = {},
        localPositionInputs = {},
        removedButtonIndexes = {},
        vectorLineUpdates = 0,
        vectorLines = {}
    }

    surface.getGUID = function()
        return guid
    end
    surface.getButtons = function()
        return buttons
    end
    surface.removeButton = function(buttonIndex)
        surface.removedButtonIndexes[#surface.removedButtonIndexes + 1] =
            buttonIndex

        for index = #buttons, 1, -1 do
            if buttons[index].index == buttonIndex then
                table.remove(buttons, index)
                return
            end
        end
    end
    surface.positionToLocal = function(position)
        surface.localPositionInputs[#surface.localPositionInputs + 1] = position
        return {
            x = position.x + 100,
            y = position.y + 200,
            z = position.z + 300
        }
    end
    surface.createButton = function(parameters)
        parameters.index = parameters.index or nextButtonIndex
        nextButtonIndex = nextButtonIndex + 1
        buttons[#buttons + 1] = parameters
        surface.createdButtons[#surface.createdButtons + 1] = parameters
    end
    surface.editButton = function(parameters)
        surface.editedButtons[#surface.editedButtons + 1] = parameters

        for _, button in ipairs(buttons) do
            if button.index == parameters.index then
                for key, value in pairs(parameters) do
                    button[key] = value
                end
                return
            end
        end
    end
    surface.setVectorLines = function(lines)
        surface.vectorLines = lines
        surface.vectorLineUpdates = surface.vectorLineUpdates + 1
    end
    surface.buttons = buttons
    return surface
end

local function countDeckButtons(surface)
    local count = 0

    for _, button in ipairs(surface.getButtons()) do
        if button.click_function == Config.deckSlot.clickFunction then
            count = count + 1
        end
    end

    return count
end

local function findCreatedButton(surface, tooltip)
    for _, button in ipairs(surface.createdButtons) do
        if button.tooltip == tooltip then
            return button
        end
    end

    return nil
end

local function findCreatedButtonByClick(surface, clickFunction)
    for index = #surface.createdButtons, 1, -1 do
        local button = surface.createdButtons[index]

        if button.click_function == clickFunction then
            return button
        end
    end

    return nil
end

local function findCurrentButton(surface, tooltip)
    for _, button in ipairs(surface.getButtons()) do
        if button.tooltip == tooltip then
            return button
        end
    end

    return nil
end

local function withFixture(testFunction)
    local previousGlobal = Global
    local previousPlayer = Player
    local previousWait = Wait
    local previousGetObjectFromGuid = getObjectFromGUID
    local surfaces = {}
    local vectorLines = nil

    records = {
        actionReturns = {
            pickUp = "pick-up-result",
            drop = "drop-result",
            cardLeaves = "leaves-result",
            navigation = "navigation-result",
            rotation = "rotation-result"
        },
        actionSaveState = {marker = "action-state"},
        activatedPlayers = {},
        menuInitializeCount = 0,
        menuOpenResult = true,
        menuActionResult = "menu-result",
        randomDeckResult = true,
        randomDeckChoice = {lootId = 9636, name = "Arysa Andrews"},
        stoppedWaits = {},
        vectorLineUpdates = 0,
        waits = {}
    }
    makeBuiltFields = makeFields

    Global = {
        setVectorLines = function(lines)
            vectorLines = lines
            records.vectorLineUpdates = records.vectorLineUpdates + 1
        end
    }
    Player = {
        Red = {seated = true},
        Blue = {seated = true}
    }
    Wait = {
        time = function(callback, delay, repetitions)
            records.waits[#records.waits + 1] = {
                callback = callback,
                delay = delay,
                repetitions = repetitions
            }
            return #records.waits
        end,
        stop = function(identifier)
            records.stoppedWaits[#records.stoppedWaits + 1] = identifier
        end
    }
    getObjectFromGUID = function(guid)
        return surfaces[guid]
    end

    CardFields.configureDefaultDependencies({
        onDeckSpawned = function(ownerColor)
            records.activatedPlayers[#records.activatedPlayers + 1] =
                ownerColor
        end
    })

    local environment = {
        addSurface = function(guid, initialButtons)
            local surface = makeSurface(guid, initialButtons)
            surfaces[guid] = surface
            return surface
        end,
        getVectorLines = function()
            return vectorLines
        end,
        getVectorLineUpdateCount = function()
            return records.vectorLineUpdates
        end,
        setPlayerSeated = function(playerColor, seated)
            Player[playerColor] = Player[playerColor] or {}
            Player[playerColor].seated = seated == true
        end
    }
    local succeeded, failure = pcall(testFunction, environment)

    Global = previousGlobal
    Player = previousPlayer
    Wait = previousWait
    getObjectFromGUID = previousGetObjectFromGuid

    if not succeeded then
        error(failure, 0)
    end
end

local function addBothSurfaces(environment)
    return environment.addSurface("red-surface"),
        environment.addSurface("blue-surface")
end

Test.case("card fields load geometry, state, drawing, and action zones", function()
    withFixture(function(environment)
        local redSurface, blueSurface = addBothSurfaces(environment)
        local savedActionState = {stacks = {"saved"}}

        CardFields.onLoad({
            deckSpawnedByPlayer = {Red = true},
            actionZone = savedActionState
        })

        local fields = CardFields.getFields()
        Test.equal(Config.columns, records.geometryConfig.columns)
        Test.equal(Config.rows, records.geometryConfig.rows)
        Test.equal(
            Config.fields[1].surfaceObjectGuid,
            records.geometryConfig.fields[1].surfaceObjectGuid
        )
        Test.equal(1, records.menuInitializeCount)
        Test.equal(fields, records.actionLoad.fields)
        Test.equal(savedActionState, records.actionLoad.savedState)
        Test.truthy(fields[1].deckSpawned)
        Test.falsy(fields[2].deckSpawned)
        Test.deepEqual(records.built.lines, environment.getVectorLines())
        Test.equal(3, #records.waits)
        Test.equal(
            Config.deckSlot.glow.updateIntervalSeconds,
            records.waits[1].delay
        )
        Test.equal(-1, records.waits[1].repetitions)
        Test.equal(0.5, records.waits[2].delay)
        Test.equal(1, records.waits[3].delay)
        Test.equal(0, countDeckButtons(redSurface))
        Test.equal(1, countDeckButtons(blueSurface))
        Test.equal(
            "INT :  --",
            findCreatedButton(
                redSurface,
                Config.heroStatsDisplay.tooltipPrefix .. "intelligence"
            ).label
        )
        Test.equal(
            "HP  : --",
            findCreatedButton(
                redSurface,
                Config.heroStatsDisplay.tooltipPrefix .. "health"
            ).label
        )
        Test.equal(
            "none",
            findCreatedButton(
                redSurface,
                Config.heroStatsDisplay.tooltipPrefix .. "intelligence"
            ).click_function
        )
        local arrowCallbacks = {
            "onHeroIntelligenceIncreaseClicked",
            "onHeroIntelligenceDecreaseClicked",
            "onHeroHealthIncreaseClicked",
            "onHeroHealthDecreaseClicked",
            "onHeroHealthIncreaseFiveClicked",
            "onHeroHealthDecreaseFiveClicked"
        }

        for _, callback in ipairs(arrowCallbacks) do
            Test.truthy(findCreatedButtonByClick(redSurface, callback))
        end

        for index = 1, Config.actionPointsDisplay.count do
            local button = findCurrentButton(
                redSurface,
                Config.actionPointsDisplay.tooltipPrefix
                    .. index .. ": usable"
            )
            Test.truthy(button)
            Test.deepEqual(
                Config.actionPointsDisplay.usableColor,
                button.color
            )
        end

        records.waits[2].callback()
        Test.equal(fields, records.actionRefreshFields)
    end)
end)

Test.case("card fields resolve current destinations by stable field ID", function()
    withFixture(function(environment)
        addBothSurfaces(environment)
        makeBuiltFields = function()
            local built = makeFields()
            built.fields[1].zoneCenters = {
                purgatory = {x = 30, y = -1, z = 31},
                abyss = {x = 40, y = -1, z = 41}
            }
            return built
        end

        CardFields.onLoad(nil)
        local field = CardFields.getFields()[1]
        local purgatory = CardFields.getCardFieldDestination(
            field.fieldId,
            "purgatory"
        )
        local abyss = CardFields.getCardFieldDestination(
            field.fieldId,
            "abyss"
        )
        local deck = CardFields.getCardFieldDestination(
            field.fieldId,
            "deck"
        )

        Test.equal(30, purgatory.x)
        Test.equal(
            -1 + Config.deckSlot.cardSpawnHeight,
            purgatory.y
        )
        Test.equal(41, abyss.z)
        Test.equal(14, deck.x)
        Test.equal(22, deck.z)
        Test.nilValue(CardFields.getCardFieldDestination(
            "missing-field",
            "deck"
        ))
        Test.nilValue(CardFields.getCardFieldDestination(
            field.fieldId,
            "unknown"
        ))
    end)
end)

Test.case("card fields identify cards on a player's own field", function()
    withFixture(function(environment)
        addBothSurfaces(environment)
        CardFields.onLoad(nil)

        local redCard = {
            tag = "Card",
            getPosition = function()
                return {x = 10, z = 20}
            end
        }
        local blueCard = {
            tag = "Card",
            getPosition = function()
                return {x = -10, z = -20}
            end
        }

        Test.truthy(CardFields.isCardOnPlayerField("Red", redCard))
        Test.falsy(CardFields.isCardOnPlayerField("Red", blueCard))
        Test.truthy(CardFields.isCardOnPlayerField("Blue", blueCard))
        Test.falsy(CardFields.isCardOnPlayerField("Missing", redCard))
        Test.falsy(CardFields.isCardOnPlayerField("Red", {tag = "Deck"}))
    end)
end)

Test.case("card fields save owner deck flags and action state", function()
    withFixture(function(environment)
        addBothSurfaces(environment)
        CardFields.onLoad({
            deckSpawnedByPlayer = {Red = true, Blue = false}
        })

        local savedState = CardFields.getSaveState()

        Test.truthy(savedState.deckSpawnedByPlayer.Red)
        Test.falsy(savedState.deckSpawnedByPlayer.Blue)
        Test.nilValue(savedState.deckSpawnedByPlayer.White)
        Test.equal(records.actionSaveState, savedState.actionZone)
        Test.equal(CardFields.getFields(), records.actionSaveFields)
    end)
end)

Test.case("card fields replace duplicate deck buttons with configured one", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface", {
            {index = 3, click_function = "unrelated"},
            {index = 4, click_function = Config.deckSlot.clickFunction},
            {index = 8, click_function = Config.deckSlot.clickFunction}
        })
        environment.addSurface("blue-surface")

        CardFields.onLoad(nil)

        Test.equal(1, countDeckButtons(redSurface))
        Test.equal(13, #redSurface.createdButtons)
        Test.equal(2, #redSurface.removedButtonIndexes)
        Test.equal(8, redSurface.removedButtonIndexes[1])
        Test.equal(4, redSurface.removedButtonIndexes[2])

        local button = redSurface.createdButtons[9]
        local worldPosition = redSurface.localPositionInputs[9]
        Test.equal(Config.deckSlot.clickFunction, button.click_function)
        Test.equal(Global, button.function_owner)
        Test.equal(Config.deckSlot.buttonWidth * 100, button.width)
        Test.equal(Config.deckSlot.buttonHeight * 100, button.height)
        Test.equal(6, worldPosition.x)
        Test.equal(-1 + Config.deckSlot.buttonSurfaceOffset, worldPosition.y)
        Test.equal(22, worldPosition.z)
        Test.equal(106, button.position.x)
        Test.equal("Choose a deck", button.tooltip)
    end)
end)

Test.case("Hero stat displays update and use configured geometry", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)
        local field = CardFields.getFields()[1]

        field.onHeroStatsAvailable({intelligence = 5, health = 60})

        local intelligence = redSurface.createdButtons[14]
        local intelligenceUp = redSurface.createdButtons[15]
        local intelligenceDown = redSurface.createdButtons[16]
        local health = redSurface.createdButtons[17]
        local healthUp = redSurface.createdButtons[18]
        local healthUpFive = redSurface.createdButtons[19]
        local healthDown = redSurface.createdButtons[20]
        local healthDownFive = redSurface.createdButtons[21]
        local intelligenceWorld = redSurface.localPositionInputs[14]
        Test.equal("INT :  5", intelligence.label)
        Test.equal("HP  : 60", health.label)
        Test.equal("none", intelligence.click_function)
        Test.equal("none", health.click_function)
        Test.equal("▲", intelligenceUp.label)
        Test.equal("▼", intelligenceDown.label)
        Test.equal("▲", healthUp.label)
        Test.equal("▲▲", healthUpFive.label)
        Test.equal("▼", healthDown.label)
        Test.equal("▼▼", healthDownFive.label)
        Test.equal(
            "onHeroHealthIncreaseFiveClicked",
            healthUpFive.click_function
        )
        Test.equal(
            "onHeroHealthDecreaseFiveClicked",
            healthDownFive.click_function
        )
        Test.equal(Config.heroStatsDisplay.size.width * 100, intelligence.width)
        Test.equal(Config.heroStatsDisplay.size.height * 100, intelligence.height)
        Test.equal(
            Config.heroStatsDisplay.color,
            intelligence.color
        )
        Test.equal(
            Config.heroStatsDisplay.color,
            health.color
        )
        Test.equal(
            Config.heroStatsDisplay.intelligence.fontColor,
            intelligence.font_color
        )
        Test.equal(
            Config.heroStatsDisplay.health.fontColor,
            health.font_color
        )
        Test.falsy(intelligence.font_color == health.font_color)
        Test.equal(
            field.position.x
                + Config.heroStatsDisplay.intelligence.position.x,
            intelligenceWorld.x
        )
        Test.equal(
            Config.heroStatsDisplay.intelligence.position.y,
            intelligenceWorld.y
        )
        Test.equal(
            field.position.z
                + Config.heroStatsDisplay.intelligence.position.z,
            intelligenceWorld.z
        )

        local saved = CardFields.getSaveState()
        Test.equal(5, saved.heroStatsByPlayer.Red.intelligence)
        Test.equal(60, saved.heroStatsByPlayer.Red.health)
        local drawInfo = CardFields.getPlayerDrawInfo("Red")
        Test.equal(5, drawInfo.intelligence)
        Test.equal(14, drawInfo.deckPosition.x)
        Test.equal(22, drawInfo.deckPosition.z)
        Test.nilValue(CardFields.getPlayerDrawInfo("Green"))
    end)
end)

Test.case("action point buttons toggle for their owner and renew together", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)

        Test.falsy(CardFields.onActionPointClicked(2, redSurface, "Blue"))
        Test.truthy(CardFields.onActionPointClicked(2, redSurface, "Red"))
        local usedButton = findCurrentButton(
            redSurface,
            Config.actionPointsDisplay.tooltipPrefix .. "2: used"
        )
        Test.truthy(usedButton)
        Test.deepEqual(Config.actionPointsDisplay.usedColor, usedButton.color)
        Test.truthy(
            CardFields.getSaveState().actionPointsUsedByPlayer.Red[2]
        )

        Test.truthy(CardFields.renewActionPoints("Red"))
        local usableButton = findCurrentButton(
            redSurface,
            Config.actionPointsDisplay.tooltipPrefix .. "2: usable"
        )
        Test.truthy(usableButton)
        Test.deepEqual(
            Config.actionPointsDisplay.usableColor,
            usableButton.color
        )
        Test.falsy(
            CardFields.getSaveState().actionPointsUsedByPlayer.Red[2]
        )

        Test.truthy(CardFields.useActionPoint("Red", 3))
        Test.falsy(CardFields.useActionPoint("Red", 3))
        local status = CardFields.getActionPointStatus("Red")
        Test.equal(3, status.usableCount)
        Test.equal(4, status.total)
        Test.deepEqual({false, false, true, false}, status.used)
        Test.truthy(CardFields.restoreActionPoint("Red", 3))
        Test.falsy(CardFields.restoreActionPoint("Red", 3))
        Test.equal(4, CardFields.getActionPointStatus("Red").usableCount)
        Test.nilValue(CardFields.getActionPointStatus("Green"))
    end)
end)

Test.case("unchosen deck zones pulse yellow until a deck is chosen", function()
    withFixture(function(environment)
        makeBuiltFields = function()
            local built = makeFields()
            built.fields[1].deckZoneLines = {{
                points = {
                    {x = 1, y = 2, z = 3},
                    {x = 2, y = 3, z = 4}
                },
                thickness = Config.zoneLineThickness
            }}
            return built
        end
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad({deckSpawnedByPlayer = {Blue = true}})

        local glowLine = redSurface.vectorLines[1]
        Test.truthy(glowLine)
        Test.equal(1, glowLine.color[1])
        Test.equal(1, glowLine.color[2])
        Test.equal(0, glowLine.color[3])
        Test.equal(Config.deckSlot.glow.lineThickness, glowLine.thickness)
        Test.near(
            (Config.deckSlot.glow.minimumOpacity
                + Config.deckSlot.glow.maximumOpacity) * 0.5,
            glowLine.color[4],
            0.0001
        )
        Test.deepEqual(
            {x = 101, y = 202, z = 303},
            glowLine.points[1]
        )
        local initialOpacity = glowLine.color[4]

        records.waits[1].callback()
        glowLine = redSurface.vectorLines[1]
        Test.truthy(glowLine.color[4] > initialOpacity)

        CardFields.getFields()[1].onDeckSpawned()
        Test.equal(0, #redSurface.vectorLines)
        Test.deepEqual(records.built.lines, environment.getVectorLines())
    end)
end)

Test.case("deck glow follows whether the field owner is seated", function()
    withFixture(function(environment)
        makeBuiltFields = function()
            local built = makeFields()
            built.fields[1].deckZoneLines = {{
                points = {
                    {x = 1, y = 2, z = 3},
                    {x = 2, y = 3, z = 4}
                },
                thickness = Config.zoneLineThickness
            }}
            return built
        end
        environment.setPlayerSeated("Red", false)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad({deckSpawnedByPlayer = {Blue = true}})
        Test.equal(0, #redSurface.vectorLines)

        records.waits[1].callback()
        Test.equal(0, #redSurface.vectorLines)

        environment.setPlayerSeated("Red", true)
        records.waits[1].callback()
        Test.equal(1, #redSurface.vectorLines)

        environment.setPlayerSeated("Red", false)
        records.waits[1].callback()
        Test.equal(0, #redSurface.vectorLines)
    end)
end)

Test.case("deck glow pulses do not republish static vector lines", function()
    withFixture(function(environment)
        local redSurface = addBothSurfaces(environment)
        CardFields.onLoad(nil)
        local stalePulse = records.waits[1].callback

        CardFields.onLoad(nil)
        Test.equal(1, #records.stoppedWaits)
        Test.equal(1, records.stoppedWaits[1])

        local updateCount = environment.getVectorLineUpdateCount()
        local surfaceUpdateCount = redSurface.vectorLineUpdates
        stalePulse()
        Test.equal(updateCount, environment.getVectorLineUpdateCount())
        Test.equal(surfaceUpdateCount, redSurface.vectorLineUpdates)

        records.waits[4].callback()
        Test.equal(updateCount, environment.getVectorLineUpdateCount())
        Test.equal(surfaceUpdateCount + 1, redSurface.vectorLineUpdates)
    end)
end)

Test.case("Hero stat arrow buttons enforce ownership and adjust values", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)
        local field = CardFields.getFields()[1]

        Test.falsy(CardFields.onHeroHealthIncreaseClicked(
            redSurface, "Red"
        ))
        field.onHeroStatsAvailable({intelligence = 1, health = 4})
        Test.falsy(CardFields.onHeroHealthIncreaseFiveClicked(
            redSurface, "Blue"
        ))
        Test.truthy(CardFields.onHeroHealthIncreaseFiveClicked(
            redSurface, "Red"
        ))
        Test.truthy(CardFields.onHeroHealthDecreaseClicked(
            redSurface, "Red"
        ))
        Test.truthy(CardFields.onHeroIntelligenceDecreaseClicked(
            redSurface, "Red"
        ))
        Test.truthy(CardFields.onHeroIntelligenceDecreaseClicked(
            redSurface, "Red"
        ))

        local saved = CardFields.getSaveState().heroStatsByPlayer.Red
        Test.equal(-1, saved.intelligence)
        Test.equal(8, saved.health)
    end)
end)

Test.case("health dropping to zero removes the hero from turns", function()
    withFixture(function(environment)
        local depleted = {}
        CardFields.configureDefaultDependencies({
            onHeroHealthDepleted = function(playerColor, health)
                depleted[#depleted + 1] = {playerColor, health}
            end
        })
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)
        CardFields.getFields()[1].onHeroStatsAvailable({
            intelligence = 1,
            health = 1
        })

        Test.truthy(CardFields.onHeroHealthDecreaseClicked(
            redSurface,
            "Red"
        ))
        Test.deepEqual({{"Red", 0}}, depleted)

        Test.truthy(CardFields.onHeroHealthIncreaseClicked(
            redSurface,
            "Red"
        ))
        Test.equal(1, #depleted)

        Test.truthy(CardFields.onHeroHealthDecreaseFiveClicked(
            redSurface,
            "Red"
        ))
        Test.deepEqual({"Red", -4}, depleted[2])
    end)
end)

Test.case("deck spawn completion activates the owner and clears its button", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)
        local redField = CardFields.getFields()[1]

        Test.truthy(type(redField.onDeckSpawned) == "function")
        Test.equal(1, countDeckButtons(redSurface))
        redField.onDeckSpawned()

        Test.equal(0, countDeckButtons(redSurface))
        Test.equal(1, #records.activatedPlayers)
        Test.equal("Red", records.activatedPlayers[1])
        Test.truthy(
            CardFields.getSaveState().deckSpawnedByPlayer.Red
        )
    end)
end)

Test.case("deck slots reject players who do not own the field", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)

        Test.falsy(CardFields.onDeckSlotClicked(redSurface, "White"))
        Test.nilValue(records.menuOpen)
    end)
end)

Test.case("owned deck slots open at the button-aligned spawn position", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)

        Test.truthy(CardFields.onDeckSlotClicked(redSurface, "Red"))
        Test.equal("Red", records.menuOpen.playerColor)
        Test.equal(CardFields.getFields()[1], records.menuOpen.field)
        Test.equal(14, records.menuOpen.spawnPosition.x)
        Test.equal(-1, records.menuOpen.spawnPosition.y)
        Test.equal(22, records.menuOpen.spawnPosition.z)
    end)
end)

Test.case("renewing a deck slot uses owner color and resets spawn state", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad({deckSpawnedByPlayer = {Red = true}})

        Test.equal(0, countDeckButtons(redSurface))
        Test.falsy(CardFields.renewDeckSlotButton("White"))
        Test.truthy(CardFields.renewDeckSlotButton("Red"))
        Test.equal(1, countDeckButtons(redSurface))
        Test.falsy(
            CardFields.getSaveState().deckSpawnedByPlayer.Red
        )
    end)
end)

Test.case("renewing a deck slot reports a missing surface", function()
    withFixture(function(environment)
        environment.addSurface("blue-surface")
        CardFields.onLoad({deckSpawnedByPlayer = {Red = true}})

        Test.falsy(CardFields.renewDeckSlotButton("Red"))
    end)
end)

Test.case("mock players generate a random deck at their field", function()
    withFixture(function(environment)
        environment.addSurface("red-surface")
        environment.addSurface("blue-surface")
        CardFields.onLoad(nil)

        local accepted, deck = CardFields.spawnRandomDeck("Red")

        Test.truthy(accepted)
        Test.equal(records.randomDeckChoice, deck)
        Test.equal(CardFields.getFields()[1], records.randomDeck.field)
        Test.equal(14, records.randomDeck.spawnPosition.x)
        Test.equal(22, records.randomDeck.spawnPosition.z)
        Test.truthy(CardFields.getFields()[1].isMockPlayer)
        Test.falsy(CardFields.spawnRandomDeck("White"))
    end)
end)

Test.case("restart resets every deck spawn button and field state", function()
    withFixture(function(environment)
        local redSurface = environment.addSurface("red-surface")
        local blueSurface = environment.addSurface("blue-surface")
        CardFields.onLoad({
            deckSpawnedByPlayer = {Red = true, Blue = true},
            heroStatsByPlayer = {
                Red = {intelligence = 4, health = 10},
                Blue = {intelligence = 3, health = 8}
            }
        })

        Test.equal(0, countDeckButtons(redSurface))
        Test.equal(0, countDeckButtons(blueSurface))
        Test.truthy(CardFields.resetForRestart())

        local state = CardFields.getSaveState()
        Test.falsy(state.deckSpawnedByPlayer.Red)
        Test.falsy(state.deckSpawnedByPlayer.Blue)
        Test.nilValue(state.heroStatsByPlayer.Red)
        Test.nilValue(state.heroStatsByPlayer.Blue)
        Test.equal(1, countDeckButtons(redSurface))
        Test.equal(1, countDeckButtons(blueSurface))
    end)
end)

Test.case("card field events delegate to their focused collaborators", function()
    withFixture(function(environment)
        addBothSurfaces(environment)
        CardFields.onLoad(nil)
        local fields = CardFields.getFields()
        local card = {tag = "Card"}

        Test.equal(
            records.menuActionResult,
            CardFields.onDeckMenuUiClicked("Blue", "4371")
        )
        Test.equal("Blue", records.menuAction.playerColor)
        Test.equal("4371", records.menuAction.action)
        Test.equal(
            records.actionReturns.pickUp,
            CardFields.onObjectPickUp(card)
        )
        Test.equal(
            records.actionReturns.drop,
            CardFields.onObjectDrop(card)
        )
        Test.equal(
            records.actionReturns.cardLeaves,
            CardFields.onCardLeavesActionZone(card)
        )
        Test.equal(
            records.actionReturns.navigation,
            CardFields.navigateActionStack(
                card,
                -1,
                {preserveCardPreview = true}
            )
        )
        Test.equal(
            records.actionReturns.rotation,
            CardFields.onActionZoneCardRotationChanged(card, true)
        )
        Test.equal(fields, records.pickUp.fields)
        Test.equal(card, records.drop.object)
        Test.equal(card, records.cardLeaves.object)
        Test.equal(-1, records.navigation.direction)
        Test.truthy(records.navigation.context.preserveCardPreview)
        Test.truthy(records.rotation.rotated)
    end)
end)

Test.case("card field definitions snapshot mutable configuration", function()
    local source = {
        columns = 2,
        rows = 1,
        fields = {{
            playerColor = "Layout",
            ownerColor = "Owner",
            surfaceObjectGuid = "field-id",
            position = {x = 1, z = 2},
            size = {x = 4, z = 2}
        }},
        zones = {{key = "future", type = "future"}}
    }
    local definitions = RealCardFieldDefinitions.fromConfig(source)

    source.fields[1].ownerColor = "Changed"
    source.fields[1].position.x = 99
    source.zones[1].key = "changed"

    Test.equal("Owner", definitions.fields[1].ownerColor)
    Test.equal(1, definitions.fields[1].position.x)
    Test.equal("future", definitions.zones[1].key)
end)

Test.case("card field state keeps field and owner identities separate", function()
    local fields = {{
        fieldId = "physical-red-field",
        playerColor = "White",
        ownerColor = "Red"
    }}
    local state = RealCardFieldState.new(fields, {
        deckSpawnedByPlayer = {Red = true, White = false}
    })

    Test.truthy(RealCardFieldState.isDeckSpawned(state, fields[1]))
    Test.truthy(fields[1].deckSpawned)
    RealCardFieldState.setDeckSpawned(state, fields[1], false)
    local saved = RealCardFieldState.save(state, fields)
    Test.falsy(saved.deckSpawnedByPlayer.Red)
    Test.nilValue(saved.deckSpawnedByPlayer.White)
    Test.nilValue(saved.heroStatsByPlayer.Red)
end)

Test.case("card field state restores valid Hero stats by owner", function()
    local fields = {{
        fieldId = "physical-red-field",
        playerColor = "White",
        ownerColor = "Red"
    }}
    local state = RealCardFieldState.new(fields, {
        heroStatsByPlayer = {
            Red = {intelligence = "7", health = 40}
        }
    })

    Test.equal(7, fields[1].heroStats.intelligence)
    Test.equal(40, fields[1].heroStats.health)
    RealCardFieldState.setHeroStats(state, fields[1], nil)
    Test.nilValue(RealCardFieldState.getHeroStats(state, fields[1]))
end)

Test.case("a registered zone handles events without facade changes", function()
    withFixture(function(environment)
        addBothSurfaces(environment)
        local registry = ZoneBehaviorRegistry.new()
        local calls = {drops = 0}
        local restored = nil
        local fieldsSeen = nil
        registry:register("future", {
            saveKey = "futureZone",
            onLoad = function(currentFields, savedState)
                fieldsSeen = currentFields
                restored = savedState
            end,
            getSaveState = function()
                return {saved = true}
            end,
            onObjectDrop = function(_, object)
                calls.drops = calls.drops + 1
                calls.object = object
                return "future-zone-result"
            end
        })
        local controller = CardFields.new({
            zoneBehaviors = registry,
            onDeckSpawned = function()
            end
        })
        local savedFuture = {legacy = "kept"}
        local card = {tag = "Card"}

        controller:onLoad({futureZone = savedFuture})

        Test.equal(controller:getFields(), fieldsSeen)
        Test.equal(savedFuture, restored)
        Test.equal(
            "future-zone-result",
            controller:onObjectDrop(card)
        )
        Test.equal(1, calls.drops)
        Test.equal(card, calls.object)
        Test.truthy(controller:getSaveState().futureZone.saved)
    end)
end)

Test.case(
    "custom zones coexist with Action and preserve both save keys",
    function()
        withFixture(function(environment)
            addBothSurfaces(environment)
            local controller = CardFields.new({
                onDeckSpawned = function()
                end
            })
            local savedAction = {stacks = {"action-saved"}}
            local savedFuture = {charges = 4}
            local futureLoad = nil
            local futureLoadFields = nil
            local futureDropCount = 0
            local futureSave = {charges = 7}
            local card = {tag = "Card"}

            controller:registerZoneBehavior("future", {
                saveKey = "futureZone",
                onLoad = function(fields, savedState)
                    futureLoadFields = fields
                    futureLoad = savedState
                end,
                getSaveState = function()
                    return futureSave
                end,
                onObjectDrop = function(_, object)
                    records.eventOrder[#records.eventOrder + 1] =
                        "future"
                    futureDropCount = futureDropCount + 1
                    Test.equal(card, object)
                    return "future-handled"
                end
            })

            controller:onLoad({
                actionZone = savedAction,
                futureZone = savedFuture
            })

            Test.equal(savedAction, records.actionLoad.savedState)
            Test.equal(savedFuture, futureLoad)
            Test.equal(controller:getFields(), records.actionLoad.fields)
            Test.equal(controller:getFields(), futureLoadFields)

            local saved = controller:getSaveState()
            Test.equal(records.actionSaveState, saved.actionZone)
            Test.equal(futureSave, saved.futureZone)

            records.eventOrder = {}
            records.actionReturns.drop = false
            Test.equal("future-handled", controller:onObjectDrop(card))
            Test.deepEqual({"action", "future"}, records.eventOrder)
            Test.equal(1, futureDropCount)

            records.eventOrder = {}
            records.actionReturns.drop = "action-handled"
            Test.equal("action-handled", controller:onObjectDrop(card))
            Test.deepEqual({"action"}, records.eventOrder)
            Test.equal(1, futureDropCount)
        end)
    end
)

Test.case(
    "zone dispatch falls through false and nil in registration order",
    function()
        local registry = ZoneBehaviorRegistry.new()
        local order = {}
        local fields = {{fieldId = "dispatch-field"}}
        local object = {tag = "Card"}

        registry:register("action", {
            onObjectDrop = function(seenFields, seenObject)
                order[#order + 1] = "action"
                Test.equal(fields, seenFields)
                Test.equal(object, seenObject)
                return false
            end
        })
        registry:register("generic", {
            handle = function(eventName, seenFields, seenObject)
                order[#order + 1] = "generic"
                Test.equal("onObjectDrop", eventName)
                Test.equal(fields, seenFields)
                Test.equal(object, seenObject)
                return nil
            end
        })
        registry:register("terminal", {
            onObjectDrop = function()
                order[#order + 1] = "terminal"
                return "handled"
            end
        })
        registry:register("unreached", {
            onObjectDrop = function()
                order[#order + 1] = "unreached"
                return true
            end
        })

        Test.equal(
            "handled",
            registry:dispatch("onObjectDrop", fields, object)
        )
        Test.deepEqual(
            {"action", "generic", "terminal"},
            order
        )
    end
)

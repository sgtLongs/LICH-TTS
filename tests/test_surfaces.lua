local Test = require("tests/support/Test")
local Config = require("src/config/SurfaceConfig")
local HexGeometry = require("src/hex/HexGeometry")
local SurfaceController = require("src/surfaces/SurfaceController")
local SurfaceDefinitions = require("src/surfaces/SurfaceDefinitions")
local SurfaceMenuModel = require("src/surfaces/SurfaceMenuModel")
local SurfaceRules = require("src/surfaces/SurfaceRules")
local SurfaceTemplateFactory = require(
    "src/surfaces/SurfaceTemplateFactory"
)
local SurfaceView = require("src/surfaces/SurfaceView")

local definitions = {
    {key = "mud", label = "Mud"},
    {key = "fire", label = "Fire"}
}
local templatesByKey = {
    deathFog = {
        key = "deathFog",
        isSurface = true,
        blocksSurfacePlacement = true
    },
    mud = {key = "mud", isSurface = true},
    sourceStone = {key = "sourceStone", isSourceStone = true},
    token = {key = "token"},
    wall = {key = "wall", occupiesFacingCell = true}
}

local function placement(
    templateKey,
    row,
    column,
    facingRow,
    facingColumn
)
    return {
        templateKey = templateKey,
        cell = {row = row, column = column},
        facingCell = {
            row = facingRow or row,
            column = facingColumn or column + 1
        }
    }
end

Test.case("surface definitions derive names and rendering from config", function()
    local expected = {
        {"deathFog", "Death Fog", 0.784314},
        {"fire", "Fire", 0.65},
        {"smoke", "Smoke", 0.55},
        {"water", "Water", 0.55},
        {"steam", "Steam", 0.5},
        {"sludge", "Sludge", 0.7},
        {"vines", "Vines", 1}
    }

    Test.equal(#expected, #Config.surfaces)
    Test.equal(#expected, #SurfaceDefinitions)

    for index, definition in ipairs(SurfaceDefinitions) do
        local settings = Config.surfaces[index]

        Test.equal(expected[index][1], definition.key)
        Test.equal(expected[index][2], definition.label)
        Test.equal(expected[index][3], definition.opacity)
        Test.equal(settings.color, definition.color)
        Test.equal(settings.name, definition.placementTemplate.label)
        Test.equal(settings.color, definition.placementTemplate.color)
        Test.equal(settings.opacity, definition.placementTemplate.opacity)
        Test.truthy(definition.placementTemplate.isSurface)
        Test.contains(
            definition.placementTemplate.json,
            '"MeshURL":"https://steamusercontent-a.akamaihd.net/'
        )
        Test.contains(
            definition.placementTemplate.json,
            '"a":' .. tostring(settings.opacity)
        )
    end

    Test.truthy(
        SurfaceDefinitions[1].placementTemplate.blocksSurfacePlacement
    )
    Test.truthy(SurfaceDefinitions[1].placementTemplate.isDeathFog)
    Test.falsy(
        SurfaceDefinitions[2].placementTemplate.blocksSurfacePlacement
    )
end)

Test.case("surface templates encode configured tint and opacity", function()
    local expectedColors = {
        deathFog = '"ColorDiffuse":{"r":0.188235,"g":1,"b":0,"a":0.784314}',
        fire = '"ColorDiffuse":{"r":0.85,"g":0.08,"b":0.04,"a":0.65}',
        smoke = '"ColorDiffuse":{"r":0.15,"g":0.15,"b":0.15,"a":0.55}',
        water = '"ColorDiffuse":{"r":0.05,"g":0.3,"b":0.95,"a":0.55}',
        steam = '"ColorDiffuse":{"r":1,"g":1,"b":1,"a":0.5}',
        sludge = '"ColorDiffuse":{"r":0.35,"g":0.15,"b":0.05,"a":0.7}',
        vines = '"ColorDiffuse":{"r":0.03,"g":0.25,"b":0.06,"a":1}'
    }

    for _, definition in ipairs(SurfaceDefinitions) do
        Test.contains(
            definition.placementTemplate.json,
            expectedColors[definition.key]
        )
        Test.contains(
            definition.placementTemplate.json,
            '"MaterialIndex":2'
        )
    end
end)

Test.case("surface template configuration validates color channels", function()
    Test.raises(function()
        SurfaceTemplateFactory.build({
            key = "invalid",
            name = "Invalid",
            color = {r = 2, g = 0, b = 0},
            opacity = 0.5
        })
    end, "Surface red")
end)

Test.case("surface rules allow empty and source-stone hexes", function()
    Test.truthy(SurfaceRules.canPlace(
        definitions[1],
        {row = 0, column = 0},
        {},
        templatesByKey
    ))
    Test.truthy(SurfaceRules.canPlace(
        definitions[1],
        {row = 0, column = 0},
        {placement("sourceStone", 0, 0)},
        templatesByKey
    ))
end)

Test.case("surface rules find only source stones on a hex", function()
    local sourceStone = placement("sourceStone", 0, 0)
    local placements = {
        placement("mud", 0, 0),
        sourceStone,
        placement("sourceStone", 0, 1)
    }

    Test.equal(sourceStone, SurfaceRules.getSourceStonePlacement(
        {row = 0, column = 0},
        placements,
        templatesByKey
    ))
    Test.nilValue(SurfaceRules.getSourceStonePlacement(
        {row = 1, column = 0},
        placements,
        templatesByKey
    ))
end)

Test.case("surface rules reject ordinary occupied hexes", function()
    Test.falsy(SurfaceRules.canPlace(
        definitions[1],
        {row = 0, column = 0},
        {placement("token", 0, 0)},
        templatesByKey
    ))
    Test.falsy(SurfaceRules.canPlace(
        definitions[1],
        {row = 0, column = 1},
        {placement("wall", 0, 0, 0, 1)},
        templatesByKey
    ))
end)

Test.case("surfaces replace surfaces but never death fog", function()
    local mud = placement("mud", 0, 0)
    local deathFog = placement("deathFog", 0, 1)
    local placements = {mud, deathFog}

    Test.truthy(SurfaceRules.canPlace(
        definitions[2],
        {row = 0, column = 0},
        placements,
        templatesByKey
    ))
    Test.falsy(SurfaceRules.canPlace(
        definitions[2],
        {row = 0, column = 1},
        placements,
        templatesByKey
    ))
    Test.deepEqual({mud}, SurfaceRules.getReplacedPlacements(
        {row = 0, column = 0},
        placements,
        templatesByKey
    ))
    Test.equal(mud, SurfaceRules.getRemovableSurfacePlacement(
        {row = 0, column = 0},
        placements,
        templatesByKey
    ))
    Test.nilValue(SurfaceRules.getRemovableSurfacePlacement(
        {row = 0, column = 1},
        placements,
        templatesByKey
    ))
end)

Test.case("outermost surface candidates reuse general availability", function()
    local cells = HexGeometry.buildCells({
        sideLength = 2,
        hexRadius = 1,
        rotationDegrees = 0,
        offsetX = 0,
        offsetZ = 0,
        hitEdgePadding = 0
    })
    local candidates = SurfaceRules.getOutermostCandidates(
        definitions[1],
        cells,
        {
            placement("token", 0, 1),
            placement("sourceStone", -1, 1)
        },
        templatesByKey,
        HexGeometry.cellKey
    )

    Test.nilValue(candidates["0:1"])
    Test.truthy(candidates["-1:1"])
    Test.nilValue(candidates["0:0"])
end)

Test.case("surface view targets one player's left-side picker", function()
    local patches = SurfaceView.buildOpenPatch(
        Config,
        definitions,
        {
            playerColor = "Red",
            cell = {row = -1, column = 2},
            availableSurfaceKeys = {mud = true},
            canRemoveSurface = true
        }
    )

    Test.deepEqual({
        id = Config.ui.rootId,
        attribute = "visibility",
        value = "Red"
    }, patches[1])
    Test.equal("SURFACES  -1, 2", patches[2].value)
    Test.equal("true", patches[3].value)
    Test.equal("false", patches[4].value)
    Test.deepEqual({
        id = Config.ui.removeSourceStoneButtonId,
        attribute = "active",
        value = "false"
    }, patches[5])
    Test.deepEqual({
        id = Config.ui.removeSurfaceButtonId,
        attribute = "active",
        value = "true"
    }, patches[6])
    Test.deepEqual({
        id = Config.ui.rootId,
        attribute = "active",
        value = "true"
    }, patches[7])
end)

Test.case("surface controller removes a revalidated surface", function()
    local mud = placement("mud", 0, 0)
    local placements = {mud}
    local removed = nil
    local controller = SurfaceController.new({
        definitions = definitions,
        templatesByKey = templatesByKey,
        uiAdapter = {apply = function()
        end}
    })

    controller.initialize({
        getPlacements = function()
            return placements
        end,
        onRemoveSurface = function(surface, playerColor)
            removed = {surface = surface, playerColor = playerColor}
            return true
        end
    })

    Test.truthy(controller.open("Red", {row = 0, column = 0}))
    Test.truthy(controller.getActiveMenu().canRemoveSurface)
    Test.falsy(controller.handleAction("Blue", "removeSurface"))

    placements = {}
    Test.falsy(controller.handleAction("Red", "removeSurface"))
    Test.nilValue(removed)

    placements = {mud}
    Test.truthy(controller.handleAction("Red", "removeSurface"))
    Test.equal(mud, removed.surface)
    Test.equal("Red", removed.playerColor)
    Test.nilValue(controller.getActiveMenu())
end)

Test.case("surface controller removes a revalidated source stone", function()
    local sourceStone = placement("sourceStone", 0, 0)
    local placements = {sourceStone}
    local removed = nil
    local controller = SurfaceController.new({
        definitions = definitions,
        templatesByKey = templatesByKey,
        uiAdapter = {apply = function()
        end}
    })

    controller.initialize({
        getPlacements = function()
            return placements
        end,
        onRemoveSourceStone = function(placement, playerColor)
            removed = {placement = placement, playerColor = playerColor}
            return true
        end
    })

    Test.truthy(controller.open("Red", {row = 0, column = 0}))
    Test.truthy(controller.getActiveMenu().canRemoveSourceStone)
    Test.falsy(controller.handleAction("Blue", "removeSourceStone"))

    placements = {}
    Test.falsy(controller.handleAction("Red", "removeSourceStone"))
    Test.nilValue(removed)

    placements = {sourceStone}
    Test.truthy(controller.handleAction("Red", "removeSourceStone"))
    Test.equal(sourceStone, removed.placement)
    Test.equal("Red", removed.playerColor)
    Test.nilValue(controller.getActiveMenu())
end)

Test.case("source stone removal remains available on death fog", function()
    local controller = SurfaceController.new({
        definitions = definitions,
        templatesByKey = templatesByKey,
        uiAdapter = {apply = function()
        end}
    })

    controller.initialize({
        getPlacements = function()
            return {
                placement("deathFog", 0, 0),
                placement("sourceStone", 0, 0)
            }
        end
    })

    Test.truthy(controller.open("Red", {row = 0, column = 0}))
    local activeMenu = controller.getActiveMenu()
    Test.truthy(activeMenu.canRemoveSourceStone)
    Test.nilValue(next(activeMenu.availableSurfaceKeys))
end)

Test.case("surface controller owns picker permission and revalidation", function()
    local applied = {}
    local placements = {}
    local chosen = nil
    local controller = SurfaceController.new({
        definitions = definitions,
        templatesByKey = templatesByKey,
        cellKey = HexGeometry.cellKey,
        uiAdapter = {
            apply = function(patches)
                applied[#applied + 1] = patches
            end
        }
    })

    controller.initialize({
        getPlacements = function()
            return placements
        end,
        onSurfaceChoice = function(definition, cell, playerColor)
            chosen = {
                definition = definition,
                cell = cell,
                playerColor = playerColor
            }
            return true
        end
    })

    local cell = {row = 0, column = 0}
    Test.truthy(controller.open("Red", cell))
    Test.falsy(controller.handleAction("Blue", "mud"))

    placements[1] = placement("token", 0, 0)
    Test.falsy(controller.handleAction("Red", "mud"))
    Test.nilValue(chosen)

    placements = {}
    Test.truthy(controller.handleAction("Red", "mud"))
    Test.equal(definitions[1], chosen.definition)
    Test.equal(cell, chosen.cell)
    Test.equal("Red", chosen.playerColor)
    Test.nilValue(controller.getActiveMenu())
    Test.truthy(#applied >= 3)
end)

Test.case("surface menu model isolates player and tile state", function()
    local model = SurfaceMenuModel.new()
    local cell = {row = 1, column = -1}

    SurfaceMenuModel.open(model, "Teal", cell)
    Test.truthy(SurfaceMenuModel.belongsTo(model, "Teal"))
    Test.falsy(SurfaceMenuModel.belongsTo(model, "Red"))
    Test.equal(cell, SurfaceMenuModel.getActive(model).cell)

    SurfaceMenuModel.clear(model)
    Test.nilValue(SurfaceMenuModel.getActive(model))
end)

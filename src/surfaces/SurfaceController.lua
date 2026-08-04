local Config = require("src/config/SurfaceConfig")
local Definitions = require("src/surfaces/SurfaceDefinitions")
local SurfaceMenuModel = require("src/surfaces/SurfaceMenuModel")
local SurfaceRules = require("src/surfaces/SurfaceRules")
local SurfaceView = require("src/surfaces/SurfaceView")
local UiAdapter = require("src/tts/UiAdapter")

local SurfaceController = {}

function SurfaceController.new(dependencies)
    dependencies = dependencies or {}

    local config = dependencies.config or Config
    local definitions = dependencies.definitions or Definitions
    local modelApi = dependencies.model or SurfaceMenuModel
    local rules = dependencies.rules or SurfaceRules
    local view = dependencies.view or SurfaceView
    local uiAdapter = dependencies.uiAdapter or UiAdapter.default()
    local templatesByKey = dependencies.templatesByKey or {}
    local cellKey = dependencies.cellKey
    local definitionsByKey = {}
    local model = modelApi.new()
    local context = {
        getPlacements = nil,
        onSurfaceChoice = nil
    }
    local controller = {}

    for _, definition in ipairs(definitions) do
        definitionsByKey[definition.key] = definition
    end

    local function apply(patches)
        uiAdapter.apply(patches)
    end

    local function close()
        modelApi.clear(model)
        apply(view.buildHiddenPatch(config))
    end

    local function getPlacements()
        if context.getPlacements == nil then
            return {}
        end

        return context.getPlacements() or {}
    end

    function controller.initialize(parameters)
        parameters = parameters or {}
        context.getPlacements = parameters.getPlacements
        context.onSurfaceChoice = parameters.onSurfaceChoice
        close()
    end

    function controller.getDefinitions()
        return definitions
    end

    function controller.getDefinition(key)
        return definitionsByKey[key]
    end

    function controller.canPlace(definition, cell, placements)
        return rules.canPlace(
            definition,
            cell,
            placements or getPlacements(),
            templatesByKey
        )
    end

    function controller.getReplacedPlacements(cell, placements)
        return rules.getReplacedPlacements(
            cell,
            placements or getPlacements(),
            templatesByKey
        )
    end

    function controller.getCandidates(
        definition,
        cells,
        placements,
        outermostOnly
    )
        local getCandidates = outermostOnly == true
            and rules.getOutermostCandidates
            or rules.getCandidates

        return getCandidates(
            definition,
            cells,
            placements or getPlacements(),
            templatesByKey,
            cellKey
        )
    end

    function controller.open(playerColor, cell)
        if type(playerColor) ~= "string" or cell == nil then
            return false
        end

        local availableSurfaceKeys = {}

        for _, definition in ipairs(definitions) do
            if controller.canPlace(definition, cell) then
                availableSurfaceKeys[definition.key] = true
            end
        end

        if next(availableSurfaceKeys) == nil then
            close()
            return false
        end

        local activeMenu = modelApi.open(model, playerColor, cell)
        activeMenu.availableSurfaceKeys = availableSurfaceKeys
        apply(view.buildOpenPatch(config, definitions, activeMenu))
        return true
    end

    function controller.handleAction(playerColor, action)
        if not modelApi.belongsTo(model, playerColor) then
            return false
        end

        if action == "close" then
            close()
            return true
        end

        local activeMenu = modelApi.getActive(model)
        local definition = definitionsByKey[action]

        if definition == nil
            or not controller.canPlace(definition, activeMenu.cell)
            or context.onSurfaceChoice == nil
        then
            return false
        end

        if context.onSurfaceChoice(
            definition,
            activeMenu.cell,
            playerColor
        ) ~= true then
            return false
        end

        close()
        return true
    end

    function controller.close()
        close()
    end

    function controller.getActiveMenu()
        return modelApi.getActive(model)
    end

    return controller
end

return SurfaceController

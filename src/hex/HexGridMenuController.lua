local Config = require("src/config/HexMenuConfig")
local HexGridMenuModel = require("src/hex/HexGridMenuModel")
local HexGridMenuView = require("src/hex/HexGridMenuView")
local SpawnDefinitions = require("src/hex/HexSpawnDefinitions")
local UiAdapter = require("src/tts/UiAdapter")

local HexGridMenuController = {}

local function defaultGetObjectsWithTag(tag)
    if getObjectsWithTag == nil then
        return {}
    end

    return getObjectsWithTag(tag)
end

local function defaultDestroyObject(object)
    if destroyObject ~= nil then
        destroyObject(object)
    end
end

function HexGridMenuController.new(dependencies)
    dependencies = dependencies or {}

    local config = dependencies.config or Config
    local spawnDefinitions = dependencies.spawnDefinitions
        or SpawnDefinitions
    local modelApi = dependencies.model or HexGridMenuModel
    local view = dependencies.view or HexGridMenuView
    local uiAdapter = dependencies.uiAdapter or UiAdapter.default()
    local getTaggedObjects = dependencies.getObjectsWithTag
        or defaultGetObjectsWithTag
    local destroyTaggedObject = dependencies.destroyObject
        or defaultDestroyObject
    local templatesByKey = {}
    local model = modelApi.new()
    local context = {
        board = nil,
        isAdmin = nil,
        onObjectChoice = nil,
        onDeleteObject = nil,
        onTargetChanged = nil,
        onCancelRotation = nil
    }
    local controller = {}

    for _, template in ipairs(spawnDefinitions) do
        templatesByKey[template.key] = template
    end

    local function apply(patches)
        uiAdapter.apply(patches)
    end

    local function notifyTargetChanged(cell)
        if context.onTargetChanged ~= nil then
            context.onTargetChanged(cell)
        end
    end

    local function removeLegacyMenu()
        for _, existingAnchor in ipairs(
            getTaggedObjects(config.legacy.anchorTag)
        ) do
            destroyTaggedObject(existingAnchor)
        end

        if context.board == nil then
            return
        end

        local existingButtons = context.board.getButtons() or {}

        for index = #existingButtons, 1, -1 do
            local button = existingButtons[index]

            if config.legacy.clickFunctions[button.click_function] then
                context.board.removeButton(button.index)
            end
        end
    end

    local function close()
        modelApi.clear(model)
        apply(view.buildHiddenPatch(config))
        notifyTargetChanged(nil)
    end

    local routes = {
        add = function()
            apply(view.buildPagePatch(config, config.ui.objectPageId))
        end,
        close = function(playerColor, activeMenu)
            if activeMenu.rotationPending
                and context.onCancelRotation ~= nil
            then
                context.onCancelRotation(playerColor)
            end

            close()
        end,
        delete = function(playerColor, activeMenu)
            if activeMenu.placement ~= nil
                and context.onDeleteObject ~= nil
            then
                context.onDeleteObject(
                    activeMenu.placement,
                    playerColor
                )
            end
        end
    }

    function controller.initialize(parameters)
        context.board = parameters.board
        context.isAdmin = parameters.isAdmin
        context.onObjectChoice = parameters.onObjectChoice
        context.onDeleteObject = parameters.onDeleteObject
        context.onTargetChanged = parameters.onTargetChanged
        context.onCancelRotation = parameters.onCancelRotation
        modelApi.clear(model)

        apply(view.buildHiddenPatch(config))
        apply(view.buildSpawnSelectorHiddenPatch(config))
        notifyTargetChanged(nil)
        removeLegacyMenu()
    end

    function controller.showSpawnSelector(selectedTemplate)
        apply(view.buildSpawnSelectorPatch(
            config,
            spawnDefinitions,
            selectedTemplate
        ))
    end

    function controller.hideSpawnSelector()
        apply(view.buildSpawnSelectorHiddenPatch(config))
    end

    function controller.open(playerColor, player, cell, placement)
        if context.board == nil or player == nil or cell == nil then
            return
        end

        local activeMenu = modelApi.open(
            model,
            playerColor,
            cell,
            placement
        )
        apply(view.buildOpenPatch(config, templatesByKey, activeMenu))
        notifyTargetChanged(cell)
    end

    function controller.handleAction(playerColor, action)
        if not modelApi.belongsToAdmin(
            model,
            playerColor,
            context.isAdmin
        ) then
            return
        end

        local activeMenu = modelApi.getActive(model)
        local route = routes[action]

        if route ~= nil then
            route(playerColor, activeMenu)
            return
        end

        local template = templatesByKey[action]

        if template == nil or context.onObjectChoice == nil then
            return
        end

        if context.onObjectChoice(
            template,
            activeMenu.cell,
            playerColor,
            activeMenu.placement
        ) then
            modelApi.markRotationPending(model)
            apply(view.buildRotationPatch(config, template))
        end
    end

    function controller.close()
        close()
    end

    return controller
end

return HexGridMenuController

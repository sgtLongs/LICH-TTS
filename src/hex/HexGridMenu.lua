local Config = require("src/config/HexMenuConfig")
local SpawnDefinitions = require("src/hex/HexSpawnDefinitions")

local HexGridMenu = {}
local templatesByKey = {}

for _, template in ipairs(SpawnDefinitions) do
    templatesByKey[template.key] = template
end

local context = {
    board = nil,
    isAdmin = nil,
    onObjectChoice = nil,
    onDeleteObject = nil,
    onTargetChanged = nil,
    onCancelRotation = nil
}
local activeMenu = nil

local function setPage(pageId)
    UI.setAttribute(
        Config.ui.addPageId,
        "active",
        pageId == Config.ui.addPageId and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.objectPageId,
        "active",
        pageId == Config.ui.objectPageId and "true" or "false"
    )
    UI.setAttribute(
        Config.ui.rotationPageId,
        "active",
        pageId == Config.ui.rotationPageId and "true" or "false"
    )
end

local function hideMenu()
    UI.setAttribute(Config.ui.rootId, "active", "false")
end

local function removeLegacyMenu()
    for _, existingAnchor in ipairs(
        getObjectsWithTag(Config.legacy.anchorTag)
    ) do
        destroyObject(existingAnchor)
    end

    if context.board == nil then
        return
    end

    local existingButtons = context.board.getButtons() or {}

    for index = #existingButtons, 1, -1 do
        local button = existingButtons[index]

        if Config.legacy.clickFunctions[button.click_function] then
            context.board.removeButton(button.index)
        end
    end
end

local function menuBelongsToAdmin(playerColor)
    return activeMenu ~= nil
        and activeMenu.playerColor == playerColor
        and context.isAdmin ~= nil
        and context.isAdmin(playerColor)
end

local function notifyTargetChanged(cell)
    if context.onTargetChanged ~= nil then
        context.onTargetChanged(cell)
    end
end

function HexGridMenu.initialize(parameters)
    context.board = parameters.board
    context.isAdmin = parameters.isAdmin
    context.onObjectChoice = parameters.onObjectChoice
    context.onDeleteObject = parameters.onDeleteObject
    context.onTargetChanged = parameters.onTargetChanged
    context.onCancelRotation = parameters.onCancelRotation
    activeMenu = nil

    hideMenu()
    notifyTargetChanged(nil)
    removeLegacyMenu()
end

function HexGridMenu.open(playerColor, player, cell, placement)
    if context.board == nil or player == nil or cell == nil then
        return
    end

    activeMenu = {
        playerColor = playerColor,
        cell = cell,
        placement = placement
    }

    UI.setAttribute(Config.ui.rootId, "visibility", playerColor)
    UI.setAttribute(
        Config.ui.titleId,
        "text",
        placement ~= nil
            and "Edit " .. templatesByKey[placement.templateKey].label
            or "Selected Hex " .. cell.row .. ", " .. cell.column
    )
    UI.setAttribute(
        Config.ui.deleteButtonId,
        "active",
        placement ~= nil and "true" or "false"
    )
    setPage(Config.ui.objectPageId)
    UI.setAttribute(Config.ui.rootId, "active", "true")
    notifyTargetChanged(cell)
end

function HexGridMenu.handleAction(playerColor, action)
    if not menuBelongsToAdmin(playerColor) then
        return
    end

    if action == "add" then
        setPage(Config.ui.objectPageId)
        return
    end

    if action == "close" then
        if activeMenu.rotationPending
            and context.onCancelRotation ~= nil
        then
            context.onCancelRotation(playerColor)
        end

        HexGridMenu.close()
        return
    end

    if action == "delete" then
        if activeMenu.placement ~= nil
            and context.onDeleteObject ~= nil
        then
            context.onDeleteObject(
                activeMenu.placement,
                playerColor
            )
        end

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
        activeMenu.rotationPending = true
        UI.setAttribute(
            Config.ui.titleId,
            "text",
            "Rotate " .. template.label
        )
        UI.setAttribute(
            Config.ui.rotationPromptId,
            "text",
            "Click a highlighted adjacent hex to choose which way "
                .. template.label .. " faces."
        )
        setPage(Config.ui.rotationPageId)
    end
end

function HexGridMenu.close()
    activeMenu = nil
    hideMenu()
    notifyTargetChanged(nil)
end

return HexGridMenu

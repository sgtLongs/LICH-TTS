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
    onTargetChanged = nil
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
    context.onTargetChanged = parameters.onTargetChanged
    activeMenu = nil

    hideMenu()
    notifyTargetChanged(nil)
    removeLegacyMenu()
end

function HexGridMenu.open(playerColor, player, cell)
    if context.board == nil or player == nil or cell == nil then
        return
    end

    activeMenu = {
        playerColor = playerColor,
        cell = cell
    }

    UI.setAttribute(Config.ui.rootId, "visibility", playerColor)
    UI.setAttribute(
        Config.ui.titleId,
        "text",
        "Selected Hex " .. cell.row .. ", " .. cell.column
    )
    setPage(Config.ui.addPageId)
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
        HexGridMenu.close()
        return
    end

    local template = templatesByKey[action]

    if template == nil or context.onObjectChoice == nil then
        return
    end

    if context.onObjectChoice(template, activeMenu.cell, playerColor) then
        HexGridMenu.close()
    end
end

function HexGridMenu.close()
    activeMenu = nil
    hideMenu()
    notifyTargetChanged(nil)
end

return HexGridMenu

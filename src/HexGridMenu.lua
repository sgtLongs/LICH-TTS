local HexGridMenu = {}
local SavedObjectData = require("data/HexGridObjectTemplates")

-- Screen-space menu element IDs. Adjust visual layout, sizes, and colors in
-- .tts/objects/Global.xml; this module owns menu state and behavior.
local UI_CONFIG = {
    rootId = "hexGridMenuRoot",
    titleId = "hexGridMenuTitle",
    addPageId = "hexGridMenuAddPage",
    objectPageId = "hexGridMenuObjectPage"
}

-- Saved object data is bundled with Global, so no template needs to remain
-- in the live game.
local OBJECT_TEMPLATES = {
    {key = "tree", label = "Tree", json = SavedObjectData.tree},
    {key = "throne", label = "Throne", json = SavedObjectData.throne},
    {key = "rock1", label = "Rock 1", json = SavedObjectData.rock1},
    {key = "rock2", label = "Rock 2", json = SavedObjectData.rock2},
    {
        key = "doubleRock",
        label = "Double Rock",
        json = SavedObjectData.doubleRock
    },
    {key = "crystal", label = "Crystal", json = SavedObjectData.crystal},
    {key = "chest", label = "Chest", json = SavedObjectData.chest},
    {key = "cage", label = "Cage", json = SavedObjectData.cage},
    {
        key = "sourceStone",
        label = "Source Stone",
        json = SavedObjectData.sourceStone
    }
}

local OBJECT_TEMPLATES_BY_KEY = {}

for _, template in ipairs(OBJECT_TEMPLATES) do
    OBJECT_TEMPLATES_BY_KEY[template.key] = template
end

-- Clean up controls and anchors created by pre-screen-UI versions.
local LEGACY_MENU_ANCHOR_TAG = "HexGridAdminMenu"
local LEGACY_CLICK_FUNCTIONS = {
    onHexGridAddObjectClicked = true,
    onHexGridCloseMenuClicked = true,
    onHexGridMenuPanelClicked = true,
    onHexGridSpawnTreeClicked = true,
    onHexGridSpawnThroneClicked = true,
    onHexGridSpawnRock1Clicked = true,
    onHexGridSpawnRock2Clicked = true,
    onHexGridSpawnDoubleRockClicked = true,
    onHexGridSpawnCrystalClicked = true,
    onHexGridSpawnChestClicked = true,
    onHexGridSpawnCageClicked = true
}

local context = {
    board = nil,
    isAdmin = nil,
    onObjectChoice = nil,
    onTargetChanged = nil
}
local activeMenu = nil

local function setPage(pageId)
    UI.setAttribute(
        UI_CONFIG.addPageId,
        "active",
        pageId == UI_CONFIG.addPageId and "true" or "false"
    )
    UI.setAttribute(
        UI_CONFIG.objectPageId,
        "active",
        pageId == UI_CONFIG.objectPageId and "true" or "false"
    )
end

local function hideMenu()
    UI.setAttribute(UI_CONFIG.rootId, "active", "false")
end

local function removeLegacyMenu()
    for _, existingAnchor in ipairs(
        getObjectsWithTag(LEGACY_MENU_ANCHOR_TAG)
    ) do
        destroyObject(existingAnchor)
    end

    if context.board == nil then
        return
    end

    local existingButtons = context.board.getButtons() or {}

    for index = #existingButtons, 1, -1 do
        local button = existingButtons[index]

        if LEGACY_CLICK_FUNCTIONS[button.click_function] then
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

    UI.setAttribute(UI_CONFIG.rootId, "visibility", playerColor)
    UI.setAttribute(
        UI_CONFIG.titleId,
        "text",
        "Selected Hex " .. cell.row .. ", " .. cell.column
    )
    setPage(UI_CONFIG.addPageId)
    UI.setAttribute(UI_CONFIG.rootId, "active", "true")
    notifyTargetChanged(cell)
end

function HexGridMenu.handleAction(playerColor, action)
    if not menuBelongsToAdmin(playerColor) then
        return
    end

    if action == "add" then
        setPage(UI_CONFIG.objectPageId)
        return
    end

    if action == "close" then
        HexGridMenu.close()
        return
    end

    local template = OBJECT_TEMPLATES_BY_KEY[action]

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

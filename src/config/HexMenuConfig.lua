local HexMenuConfig = {
    ui = {
        rootId = "hexGridMenuRoot",
        titleId = "hexGridMenuTitle",
        addPageId = "hexGridMenuAddPage",
        objectPageId = "hexGridMenuObjectPage",
        deleteButtonId = "hexGridMenuDeleteObject",
        rotationPageId = "hexGridMenuRotationPage",
        rotationPromptId = "hexGridMenuRotationPrompt",
        spawnSelectorRootId = "hexGridSpawnSelectorRoot",
        spawnSelectorStatusId = "hexGridSpawnSelectorStatus",
        spawnSelectorButtonPrefix = "hexGridSpawnSelector",
        spawnSelectorButtonColors = "#1A2638|#263A55|#111A28|#111A28",
        spawnSelectorSelectedColors =
            "#167C5A|#22A878|#105A43|#105A43"
    },
    legacy = {
        anchorTag = "HexGridAdminMenu",
        clickFunctions = {
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
    }
}

return HexMenuConfig

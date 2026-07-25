local HexMenuConfig = {
    ui = {
        rootId = "hexGridMenuRoot",
        titleId = "hexGridMenuTitle",
        addPageId = "hexGridMenuAddPage",
        objectPageId = "hexGridMenuObjectPage"
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

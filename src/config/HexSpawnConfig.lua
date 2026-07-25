local HexSpawnConfig = {
    initialHeightAboveSurface = 1,
    -- Compound objects can finish loading their children several frames after
    -- spawnObjectJSON calls back. Reapply bounds-based placement as they settle.
    placementCorrectionFrames = {2, 10, 30, 60},
    missingTemplateColor = {1, 0.35, 0.25},
    failureColor = {1, 0.35, 0.25},
    successColor = {0.25, 0.9, 0.55}
}

return HexSpawnConfig

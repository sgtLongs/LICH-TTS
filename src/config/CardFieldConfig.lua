local CardFieldConfig = {
    columns = 7,
    rows = 3,

    -- World-space height used for the debug lines.
    surfaceY = -0.7,
    lineThickness = 0.08,
    sectionLineThickness = 0.18,
    gridColor = {0.75, 0.75, 0.75, 0.8},

    deckSlot = {
        row = 1,
        column = 1,
        -- Player-field columns are numbered from right to left, making
        -- column 7 the leftmost slot.
        columnsRunRightToLeft = true,
        -- Click-target dimensions in world units.
        buttonWidth = 20,
        buttonHeight = 27,
        buttonSurfaceOffset = 0.03,
        invisibleButtonColor = {0, 0, 0, 0},
        debugLabel = "DECK",
        debugFontSize = 80,
        debugColor = {1, 0.45, 0.05, 0.55},
        debugFontColor = {1, 1, 1, 1},
        debugHoverColor = {1, 0.65, 0.15, 0.72},
        debugPressColor = {0.85, 0.25, 0.02, 0.82},
        clickFunction = "onCardFieldDeckSlotClicked",
        apiUrl =
            "https://kickback-kingdom.com/api/v1/lich/get-deck.php",
        menuRootId = "deckSelectionMenuRoot",
        decks = {
            {lootId = 9636, name = "Arysa Andrews"},
            {lootId = 4371, name = "Aurelia, Maiden of the Brush"},
            {lootId = 11164, name = "Brain"},
            {lootId = 4375, name = "Devon Andrews"},
            {lootId = 10471, name = "Draelith, Phoenix King"},
            {lootId = 4369, name = "Eric and Eugene"},
            {lootId = 4370, name = "Eric, the Possessed"},
            {lootId = 9078, name = "Isiaiah Mangrum"},
            {lootId = 7813, name = "Kronnid the Wretched"},
            {lootId = 4376, name = "Maldrith, Acolyte of Shadows"},
            {lootId = 10853, name = "Manfred Schneider"},
            {lootId = 4374, name = "Marok, the Devourer"},
            {lootId = 4373, name = "Yashlaegon, the Sinful"}
        },
        cardSpawnHeight = 2,
        -- Rotation applied to every card spawned from the deck slot.
        -- Values are Euler angles in degrees: {x, y, z}.
        cardSpawnRotation = {0, 180, 0}
    },

    -- Gameplay labels the seven-wide axis as rows and the three-deep axis as
    -- columns. The hero starts in the opposite corner on the third column.
    heroSlot = {
        row = 7,
        column = 3,
        -- The cabinet deck button is mirrored when its deck spawn position is
        -- calculated, so row 7 runs in the unmirrored direction to place the
        -- hero directly opposite the spawned deck.
        rowsRunRightToLeft = false,
        loadTimeoutSeconds = 30
    },

    -- Rectangles use inclusive, one-based grid coordinates. Keeping the
    -- layout here makes it easy to replace with the final CSV mapping.
    sections = {
        {
            key = "skillLeft",
            label = "Skill 1",
            firstColumn = 1,
            lastColumn = 2,
            firstRow = 1,
            lastRow = 3,
            color = {0.25, 0.75, 1, 1}
        },
        {
            key = "source",
            label = "Source",
            firstColumn = 3,
            lastColumn = 5,
            firstRow = 1,
            lastRow = 3,
            color = {0.9, 0.35, 0.95, 1}
        },
        {
            key = "skillRight",
            label = "Skill 2",
            firstColumn = 6,
            lastColumn = 7,
            firstRow = 1,
            lastRow = 3,
            color = {0.25, 0.75, 1, 1}
        }
    },

    -- Positions line up with the six cabinet/table-extension spaces.
    -- Size is the complete 7-by-3 field size in world units.
    -- ownerColor follows the physical clockwise order around the table,
    -- anchored at White's confirmed field: White, Brown, Red, Green, Teal,
    -- Blue. The configuration list itself does not run in that direction.
    fields = {
        {
            playerColor = "White",
            ownerColor = "Red",
            surfaceObjectGuid = "3c4e81",
            position = {x = -36, z = -41},
            rotationDegrees = 0,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Brown",
            ownerColor = "Brown",
            surfaceObjectGuid = "665355",
            position = {x = 0, z = -41},
            rotationDegrees = 0,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Red",
            ownerColor = "White",
            surfaceObjectGuid = "0c8d35",
            position = {x = 36, z = -41},
            rotationDegrees = 0,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Green",
            ownerColor = "Blue",
            surfaceObjectGuid = "5dd89b",
            position = {x = 36, z = 41},
            rotationDegrees = 180,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Teal",
            ownerColor = "Teal",
            surfaceObjectGuid = "661907",
            position = {x = 0, z = 41},
            rotationDegrees = 180,
            size = {x = 28, z = 16.5}
        },
        {
            playerColor = "Blue",
            ownerColor = "Green",
            surfaceObjectGuid = "88b8d6",
            position = {x = -36, z = 41},
            rotationDegrees = 180,
            size = {x = 28, z = 16.5}
        }
    }
}

return CardFieldConfig

local CardFieldConfig = {
    columns = 7,
    rows = 3,

    -- World-space height shared by every player card field.
    fieldY = -1,
    zoneLineThickness = 0.08,
    -- Each zone is inset so adjacent outlines leave a visible gap rather
    -- than sharing or touching an edge.
    zoneInset = 0.12,
    gridColor = {0.75, 0.75, 0.75, 0.8},

    actionZone = {
        -- The five printed action spaces are used until the row fills. Extra
        -- cards share the same usable width with equal center-to-center gaps.
        defaultSlots = 5,
        cardCenterHeight = 0.2,
        -- A drop must overlap this much of an existing action card before it
        -- joins that card's stack. Drops in open space remain new row entries.
        stackDropHalfWidth = 1.5,
        stackDropHalfDepth = 1.75,
        -- Each lower card is fanned toward its player so part of its face
        -- remains visible. Its stack index, not the selection, owns this Z.
        stackCardZOffset = -0.55,
        stackLayerHeight = 0.03,
        selectedCardLift = 0.4,
        navigationButtons = {
            -- Up and down can be positioned and sized independently. TTS
            -- button width/height values are measured in hundredths.
            up = {
                position = {x = 0, y = 0.45, z = -2},
                width = 1200,
                height = 350
            },
            down = {
                position = {x = 0, y = 0.45, z = 2},
                width = 1200,
                height = 350
            },
            fontSize = 260,
            color = {0.08, 0.08, 0.08, 0.92},
            fontColor = {1, 1, 1, 1},
            hoverColor = {0.2, 0.55, 0.9, 1},
            pressColor = {0.05, 0.3, 0.62, 1}
        }
    },

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
        customLootIdInputId = "deckSelectionCustomLootId",
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
        -- Canonical physical scale for generated cards and cards returning
        -- from play. Hand zones may temporarily resize their contents.
        cardScale = {x = 1, y = 1, z = 1},
        -- Euler rotations in degrees. The deck's 180-degree Z rotation makes
        -- it spawn upside down; the extracted Hero remains face up.
        deckSpawnRotation = {0, 180, 180},
        heroSpawnRotation = {0, 180, 0}
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

    heroStatsDisplay = {
        -- Positions are relative to the center of each player field. Positive
        -- Z points away from the player and toward the central play area, so
        -- the same values work for fields on both sides of the table. Y is a
        -- world-space height because the central play area is raised above
        -- the card fields.
        intelligence = {
            position = {x = 4, y = 1.7, z = 13},
            label = "INT : ",
            fontColor = {0.2, 0.55, 1, 1}
        },
        health = {
            position = {x = -4, y = 1.7, z = 13},
            label = "HP  :",
            fontColor = {1, 0.2, 0.2, 1}
        },
        adjustButtons = {
            size = {width = 13, height = 5},
            -- Keep controls above the stat display button so overlapping
            -- button bounds cannot hide or intercept them.
            surfaceOffset = 0,
            fontSize = 420,
            color = {0.08, 0.08, 0.08, 0.92},
            fontColor = {1, 1, 1, 0.5},
            intelligence = {
                {
                    label = "▲",
                    offset = {x = 0, z = 1.4},
                    clickFunction = "onHeroIntelligenceIncreaseClicked"
                },
                {
                    label = "▼",
                    offset = {x = 0, z = -1.4},
                    clickFunction = "onHeroIntelligenceDecreaseClicked"
                }
            },
            health = {
                {
                    label = "▲",
                    offset = {x = 0, z = 1.4},
                    clickFunction = "onHeroHealthIncreaseClicked"
                },
                {
                    label = "▲▲",
                    offset = {x = 0, z = 2.45},
                    clickFunction = "onHeroHealthIncreaseFiveClicked"
                },
                {
                    label = "▼",
                    offset = {x = 0, z = -1.4},
                    clickFunction = "onHeroHealthDecreaseClicked"
                },
                {
                    label = "▼▼",
                    offset = {x = 0, z = -2.45},
                    clickFunction = "onHeroHealthDecreaseFiveClicked"
                }
            }
        },
        -- Zero-size transparent buttons render only their labels and do not
        -- overlap the nearby stat adjustment controls.
        size = {width = 24, height = 8},
        fontSize = 600,
        color = {0.1, 0.1, 0.1, 1},
        fontColor = {1, 1, 1, 1},
        tooltipPrefix = "Hero stat: "
    },

    -- Inclusive geometry coordinates. CSV rows are written from the player's
    -- top to bottom, while geometry rows run from the player outward, so the
    -- CSV's first row is geometry row 3.
    zones = {
        {
            key = "deck",
            type = "deck",
            label = "Deck",
            firstColumn = 1,
            lastColumn = 1,
            firstRow = 1,
            lastRow = 1
        },
        {
            key = "source",
            type = "source",
            label = "Source",
            firstColumn = 2,
            lastColumn = 6,
            firstRow = 1,
            lastRow = 2
        },
        {
            key = "skillBottom",
            type = "skill",
            label = "Skill",
            firstColumn = 7,
            lastColumn = 7,
            firstRow = 1,
            lastRow = 1
        },
        {
            key = "purgatory",
            type = "purgatory",
            label = "Purgatory",
            firstColumn = 1,
            lastColumn = 1,
            firstRow = 2,
            lastRow = 2
        },
        {
            key = "skillMiddle",
            type = "skill",
            label = "Skill",
            firstColumn = 7,
            lastColumn = 7,
            firstRow = 2,
            lastRow = 2
        },
        {
            key = "abyss",
            type = "abyss",
            label = "Abyss",
            firstColumn = 1,
            lastColumn = 1,
            firstRow = 3,
            lastRow = 3
        },
        {
            key = "action",
            type = "action",
            label = "Action",
            firstColumn = 2,
            lastColumn = 6,
            firstRow = 3,
            lastRow = 3
        },
        {
            key = "hero",
            type = "hero",
            label = "Hero",
            firstColumn = 7,
            lastColumn = 7,
            firstRow = 3,
            lastRow = 3
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

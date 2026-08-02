local Fixtures = {}

Fixtures.settingsV1 = {
    schemaVersion = 1,
    boardStateJson = "fixture-board-json"
}

Fixtures.settingsV2 = {
    schemaVersion = 2,
    nextBoardId = 3,
    selectedBoardId = "board-2",
    selectedBoardName = "Vault",
    savedBoards = {
        {
            id = "board-1",
            name = "Crypt",
            boardState = {fixture = "crypt"}
        },
        {
            id = "board-2",
            name = "Vault",
            boardState = {fixture = "vault"}
        }
    }
}

Fixtures.dungeonV1 = {
    schemaVersion = 1,
    tiles = {
        {q = 0, r = 0, boardSaveId = "board-1"},
        {q = 1, r = 0, boardSaveId = "board-2"}
    },
    currentTile = {q = 0, r = 0}
}

Fixtures.actionZoneLegacy = {
    fields = {
        ["field-a"] = {
            stacks = {
                {
                    cards = {"card-a", "card-b", "card-c"},
                    selectedIndex = 2
                },
                {
                    cards = {"card-d"},
                    selectedIndex = 1
                }
            }
        }
    },
    originalLocks = {
        ["card-a"] = true,
        ["card-b"] = false
    }
}

Fixtures.generatedCardLegacy = {
    rootMarker = "preserve-root",
    features = {
        rotate90 = {rotated = true, marker = "rotate"},
        destroyToPurgatory = {marker = "actions"},
        futureFeature = {marker = "future"}
    }
}

Fixtures.deckApi = {
    valid = {
        backImageUrl = "https://example.test/back.png",
        cards = {
            {
                id = "hero-a",
                name = "Fixture Hero",
                description = "A fixture card.",
                types = {"Hero"},
                frontImageURL = "https://example.test/hero.png",
                quantity = 1
            }
        }
    },
    partial = {
        backImageUrl = "https://example.test/back.png",
        cards = {
            {name = "Missing image", quantity = 1},
            {
                nickname = "Legacy Minion",
                index = 17,
                frontImageURL = "https://example.test/minion.png",
                quantity = "2.9"
            },
            {
                name = "Zero quantity",
                frontImageURL = "https://example.test/zero.png",
                quantity = 0
            }
        }
    },
    malformed = {
        backImageUrl = "",
        cards = "not-an-array"
    }
}

function Fixtures.boardStateForTemplates(templates, schemaVersion, boardGuid)
    local objects = {}

    for _, template in ipairs(templates or {}) do
        local occupiedHexes = {{row = 0, column = 0}}

        if template.occupiesFacingCell == true then
            occupiedHexes[#occupiedHexes + 1] = {row = 0, column = 1}
        end

        objects[#objects + 1] = {
            type = template.key,
            hex = {row = 0, column = 0},
            facing = {row = 0, column = 1},
            occupiedHexes = occupiedHexes
        }
    end

    return {
        schemaVersion = schemaVersion,
        boardGuid = boardGuid,
        selectedHexes = {{row = 0, column = 0}},
        hexObjects = objects
    }
end

return Fixtures

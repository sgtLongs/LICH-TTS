local Test = require("tests/support/Test")
local SavedBoardCatalog = require("src/boards/SavedBoardCatalog")

local function newCatalog(decodeJson)
    return SavedBoardCatalog.new({
        schemaVersion = 2,
        legacySchemaVersion = 1,
        decodeJson = decodeJson
    })
end

local function board(id, name, marker)
    return {
        id = id,
        name = name,
        boardState = {marker = marker or name}
    }
end

Test.case("saved board catalog migrates IDs and legacy selection", function()
    local catalog = newCatalog()
    local result = catalog:load({
        schemaVersion = 2,
        nextBoardId = 2,
        selectedBoardName = "beta",
        savedBoards = {
            board("board-4", "  Alpha  "),
            board("board-4", "Beta"),
            board(nil, "Gamma"),
            {id = "bad", name = " ", boardState = {}},
            {id = "bad", name = "No state"}
        }
    })

    Test.falsy(result.unsupportedVersion)
    Test.deepEqual({
        {id = "board-4", name = "Alpha"},
        {id = "board-5", name = "Beta"},
        {id = "board-6", name = "Gamma"}
    }, catalog:getSummaries())
    Test.equal("board-5", catalog:getSelected().id)
    Test.equal(7, catalog:serialize().nextBoardId)
end)

Test.case("saved board catalog imports legacy JSON without TTS globals", function()
    local decodedValue = nil
    local catalog = newCatalog(function(value)
        decodedValue = value
        return {legacy = true}
    end)

    catalog:load({
        schemaVersion = 1,
        boardStateJson = "legacy-json"
    })

    local state = catalog:serialize()
    Test.equal("legacy-json", decodedValue)
    Test.equal(1, #state.savedBoards)
    Test.equal("board-1", state.selectedBoardId)
    Test.equal("Imported Saved Board", state.selectedBoardName)
    Test.truthy(state.savedBoards[1].boardState.legacy)
end)

Test.case("saved board catalog rejects unsupported versions atomically", function()
    local catalog = newCatalog()
    catalog:load({savedBoards = {board("board-1", "First")}})

    local result = catalog:load({
        schemaVersion = 99,
        savedBoards = {board("board-9", "Ignored")}
    })

    Test.truthy(result.unsupportedVersion)
    Test.equal(0, #catalog:getSummaries())
    Test.nilValue(catalog:getSelected())
end)

Test.case("saved board catalog CRUD keeps stable IDs and selection", function()
    local catalog = newCatalog()
    catalog:load(nil)

    local first, firstIndex, firstUpdated = catalog:upsert(
        "  Crypt  ",
        {revision = 1}
    )
    Test.equal("board-1", first.id)
    Test.equal(1, firstIndex)
    Test.falsy(firstUpdated)

    local updated, updatedIndex, didUpdate = catalog:upsert(
        "crypt",
        {revision = 2}
    )
    Test.equal("board-1", updated.id)
    Test.equal(1, updatedIndex)
    Test.truthy(didUpdate)
    Test.equal(2, updated.boardState.revision)

    catalog:upsert("Hall", {})
    catalog:upsert("Vault", {})
    catalog:selectById("board-2")
    Test.truthy(catalog:removeById("board-2"))
    Test.equal("board-3", catalog:getSelected().id)
    Test.falsy(catalog:removeById("missing"))
end)

Test.case("saved board catalog supplies clamped pagination inputs", function()
    local catalog = newCatalog()
    catalog:load({
        savedBoards = {
            board("one", "One"),
            board("two", "Two"),
            board("three", "Three")
        },
        selectedBoardId = "three"
    })

    local page = catalog:getPage(99, 2)
    Test.equal(2, page.page)
    Test.equal(2, page.pageCount)
    Test.equal(3, page.firstIndex)
    Test.equal("three", page.rows[1].id)
    Test.nilValue(page.rows[2])
    Test.equal("three", page.selectedBoardId)
end)

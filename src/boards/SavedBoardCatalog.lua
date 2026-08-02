local SavedBoardCatalog = {}
local Catalog = {}

Catalog.__index = Catalog

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end

    return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isValidBoardId(boardId)
    return type(boardId) == "string" and trim(boardId) ~= ""
end

local function normalizeNextBoardId(value)
    local normalizedValue = tonumber(value)

    if normalizedValue == nil
        or normalizedValue < 1
        or normalizedValue ~= math.floor(normalizedValue)
    then
        return nil
    end

    return normalizedValue
end

local function isSavedBoardCandidate(savedBoard)
    return type(savedBoard) == "table"
        and type(savedBoard.name) == "string"
        and trim(savedBoard.name) ~= ""
        and type(savedBoard.boardState) == "table"
end

local function normalizePage(page, pageCount)
    local normalizedPage = tonumber(page) or 1
    normalizedPage = math.floor(normalizedPage)
    return math.max(1, math.min(normalizedPage, pageCount))
end

function SavedBoardCatalog.trimName(value)
    return trim(value)
end

function SavedBoardCatalog.isValidBoardId(boardId)
    return isValidBoardId(boardId)
end

function SavedBoardCatalog.new(options)
    options = options or {}

    return setmetatable({
        schemaVersion = options.schemaVersion,
        legacySchemaVersion = options.legacySchemaVersion,
        decodeJson = options.decodeJson,
        legacyImportedName = options.legacyImportedName
            or "Imported Saved Board",
        boards = {},
        selectedBoardId = nil,
        nextBoardId = 1
    }, Catalog)
end

function Catalog:reset()
    self.boards = {}
    self.selectedBoardId = nil
    self.nextBoardId = 1
end

function Catalog:findIndexById(boardId)
    if not isValidBoardId(boardId) then
        return nil
    end

    for index, savedBoard in ipairs(self.boards) do
        if savedBoard.id == boardId then
            return index
        end
    end

    return nil
end

function Catalog:findIndexByName(name)
    if type(name) ~= "string" then
        return nil
    end

    local normalizedName = string.lower(name)

    for index, savedBoard in ipairs(self.boards) do
        if string.lower(savedBoard.name) == normalizedName then
            return index
        end
    end

    return nil
end

function Catalog:getById(boardId)
    local index = self:findIndexById(boardId)
    return index ~= nil and self.boards[index] or nil, index
end

function Catalog:getSelected()
    return self:getById(self.selectedBoardId)
end

function Catalog:getSelectedIndex()
    return self:findIndexById(self.selectedBoardId)
end

function Catalog:selectByIndex(index)
    local savedBoard = self.boards[index]

    if savedBoard == nil then
        return nil
    end

    self.selectedBoardId = savedBoard.id
    return savedBoard, index
end

function Catalog:selectById(boardId)
    local savedBoard, index = self:getById(boardId)

    if savedBoard ~= nil then
        self.selectedBoardId = savedBoard.id
    end

    return savedBoard, index
end

function Catalog:advanceNextBoardIdPast(boardId)
    local numericId = type(boardId) == "string"
        and tonumber(string.match(boardId, "^board%-(%d+)$"))
        or nil

    if numericId ~= nil and numericId >= self.nextBoardId then
        self.nextBoardId = numericId + 1
    end
end

function Catalog:allocateBoardId(reservedBoardIds)
    local boardId = "board-" .. self.nextBoardId

    while self:findIndexById(boardId) ~= nil
        or (reservedBoardIds ~= nil and reservedBoardIds[boardId])
    do
        self.nextBoardId = self.nextBoardId + 1
        boardId = "board-" .. self.nextBoardId
    end

    self.nextBoardId = self.nextBoardId + 1
    return boardId
end

function Catalog:load(savedState)
    self:reset()

    if type(savedState) ~= "table" then
        return {unsupportedVersion = false}
    end

    local savedVersion = savedState.schemaVersion ~= nil
        and tonumber(savedState.schemaVersion) or nil

    if savedState.schemaVersion ~= nil
        and savedVersion ~= self.legacySchemaVersion
        and savedVersion ~= self.schemaVersion
    then
        return {unsupportedVersion = true}
    end

    if type(savedState.savedBoards) == "table" then
        self.nextBoardId = normalizeNextBoardId(savedState.nextBoardId) or 1
        local reservedBoardIds = {}

        for _, savedBoard in ipairs(savedState.savedBoards) do
            if isSavedBoardCandidate(savedBoard)
                and isValidBoardId(savedBoard.id)
            then
                reservedBoardIds[savedBoard.id] = true
                self:advanceNextBoardIdPast(savedBoard.id)
            end
        end

        local usedBoardIds = {}

        for _, savedBoard in ipairs(savedState.savedBoards) do
            if isSavedBoardCandidate(savedBoard) then
                local boardId = savedBoard.id

                if not isValidBoardId(boardId) or usedBoardIds[boardId] then
                    boardId = self:allocateBoardId(reservedBoardIds)
                end

                usedBoardIds[boardId] = true
                self.boards[#self.boards + 1] = {
                    id = boardId,
                    name = trim(savedBoard.name),
                    boardState = savedBoard.boardState
                }
            end
        end
    end

    if #self.boards == 0
        and type(savedState.boardStateJson) == "string"
        and self.decodeJson ~= nil
    then
        local succeeded, legacyBoardState = pcall(
            self.decodeJson,
            savedState.boardStateJson
        )

        if succeeded and type(legacyBoardState) == "table" then
            self.boards[1] = {
                id = self:allocateBoardId(),
                name = self.legacyImportedName,
                boardState = legacyBoardState
            }
        end
    end

    if isValidBoardId(savedState.selectedBoardId) then
        self:selectById(savedState.selectedBoardId)
    end

    if self.selectedBoardId == nil
        and type(savedState.selectedBoardName) == "string"
    then
        local selectedIndex = self:findIndexByName(
            savedState.selectedBoardName
        )

        if selectedIndex ~= nil then
            self:selectByIndex(selectedIndex)
        end
    end

    if self.selectedBoardId == nil and #self.boards > 0 then
        self:selectByIndex(1)
    end

    return {unsupportedVersion = false}
end

function Catalog:upsert(name, boardState)
    local normalizedName = trim(name)

    if normalizedName == "" then
        return nil, nil, false
    end

    local existingIndex = self:findIndexByName(normalizedName)
    local updatedExisting = existingIndex ~= nil
    local savedBoard = {
        id = existingIndex ~= nil
            and self.boards[existingIndex].id
            or self:allocateBoardId(),
        name = normalizedName,
        boardState = boardState
    }

    if existingIndex ~= nil then
        self.boards[existingIndex] = savedBoard
    else
        self.boards[#self.boards + 1] = savedBoard
        existingIndex = #self.boards
    end

    self.selectedBoardId = savedBoard.id
    return savedBoard, existingIndex, updatedExisting
end

function Catalog:removeById(boardId)
    local index = self:findIndexById(boardId)

    if index == nil then
        return false
    end

    local wasSelected = self.selectedBoardId == boardId
    table.remove(self.boards, index)

    if wasSelected then
        local replacement = self.boards[index] or self.boards[index - 1]
        self.selectedBoardId = replacement ~= nil and replacement.id or nil
    end

    return true
end


function Catalog:getSummaries()
    local summaries = {}

    for index, savedBoard in ipairs(self.boards) do
        summaries[index] = {
            id = savedBoard.id,
            name = savedBoard.name
        }
    end

    return summaries
end

function Catalog:getPage(page, pageSize)
    local normalizedPageSize = tonumber(pageSize) or 1
    normalizedPageSize = math.max(1, math.floor(normalizedPageSize))
    local pageCount = math.max(
        1,
        math.ceil(#self.boards / normalizedPageSize)
    )
    local normalizedPage = normalizePage(page, pageCount)
    local firstIndex = (normalizedPage - 1) * normalizedPageSize + 1
    local rows = {}

    for row = 1, normalizedPageSize do
        rows[row] = self.boards[firstIndex + row - 1]
    end

    return {
        page = normalizedPage,
        pageCount = pageCount,
        firstIndex = firstIndex,
        rows = rows,
        selectedBoardId = self.selectedBoardId
    }
end

function Catalog:serialize(schemaVersion)
    local selectedBoard = self:getSelected()

    return {
        schemaVersion = schemaVersion or self.schemaVersion,
        savedBoards = self.boards,
        nextBoardId = self.nextBoardId,
        selectedBoardId = selectedBoard ~= nil
            and selectedBoard.id or nil,
        selectedBoardName = selectedBoard ~= nil
            and selectedBoard.name or nil
    }
end

return SavedBoardCatalog

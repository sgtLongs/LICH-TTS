local Config = require("src/config/TurnConfig")
local MockPlayerConfig = require(
    "src/mock_players/MockPlayerConfig"
)
local Runtime = require("src/tts/Runtime")
local Scheduler = require("src/tts/Scheduler")

local MockPlayerFeature = {}
local Controller = {}
Controller.__index = Controller

local function forget(feature, playerColor)
    feature.mockByColor[playerColor] = nil

    for index = #feature.additionOrder, 1, -1 do
        if feature.additionOrder[index] == playerColor then
            table.remove(feature.additionOrder, index)
            return
        end
    end
end

function MockPlayerFeature.new(dependencies)
    dependencies = dependencies or {}
    local runtime = dependencies.runtime or Runtime.default()

    return setmetatable({
        turnConfig = dependencies.turnConfig or Config,
        config = dependencies.config or MockPlayerConfig,
        scheduler = dependencies.scheduler or Scheduler.default(),
        getPlayer = dependencies.getPlayer or runtime.getPlayer,
        mockByColor = {},
        additionOrder = {},
        generation = 0
    }, Controller)
end

function MockPlayerFeature.addWithRandomDeck(turnSystem, cardFields)
    local added, playerColor = turnSystem.addMockPlayer()

    if not added then
        return false, nil, nil,
            "No unused player color is available for a mock player."
    end

    local accepted, deck = cardFields.spawnRandomDeck(playerColor)

    if not accepted then
        turnSystem.removeMockPlayer(playerColor)
        return false, nil, nil,
            "A random deck could not be generated for the mock player."
    end

    return true, playerColor, deck and deck.name or nil
end

function Controller:cancelAutomation()
    self.generation = self.generation + 1
end

function Controller:load(savedTurnState, activeByColor)
    self:cancelAutomation()
    self.mockByColor = {}
    self.additionOrder = {}

    if type(savedTurnState) ~= "table"
        or type(savedTurnState.mockPlayerColors) ~= "table"
    then
        return
    end

    for _, playerColor in ipairs(savedTurnState.mockPlayerColors) do
        if activeByColor[playerColor] == true
            and self.turnConfig.playerHexColors[playerColor] ~= nil
            and self.mockByColor[playerColor] ~= true
        then
            self.mockByColor[playerColor] = true
            self.additionOrder[#self.additionOrder + 1] = playerColor
        end
    end
end

function Controller:getPlayerColors()
    local playerColors = {}

    for _, playerColor in ipairs(self.additionOrder) do
        playerColors[#playerColors + 1] = playerColor
    end

    return playerColors
end

function Controller:isMock(playerColor)
    return self.mockByColor[playerColor] == true
end

function Controller:getMostRecentPlayerColor()
    return self.additionOrder[#self.additionOrder]
end

function Controller:getName(playerColor)
    if not self:isMock(playerColor) then
        return nil
    end

    return self.config.namePrefix .. playerColor
end

function Controller:add(activeByColor)
    for _, playerColor in ipairs(self.turnConfig.playerColors) do
        local player = self.getPlayer(playerColor)
        local isSeated = player ~= nil and player.seated == true

        if activeByColor[playerColor] ~= true and not isSeated then
            self.mockByColor[playerColor] = true
            self.additionOrder[#self.additionOrder + 1] = playerColor
            return true, playerColor
        end
    end

    return false, nil
end

function Controller:remove(playerColor)
    if not self:isMock(playerColor) then
        return false
    end

    forget(self, playerColor)
    self:cancelAutomation()
    return true
end

function Controller:replaceWithReal(playerColor, preserveMock)
    if not self:isMock(playerColor) or preserveMock == true then
        return false
    end

    forget(self, playerColor)
    self:cancelAutomation()
    return true
end

function Controller:getDeathFogStarter(endPhase, playerColor)
    if endPhase == nil then
        return nil
    end

    if self:isMock(playerColor) then
        return endPhase.beginRandomDeathFogPlacement
    end

    return endPhase.beginDeathFogPlacement
end

function Controller:schedule(parameters)
    self:cancelAutomation()

    local playerColor = parameters.getCurrentColor()

    if playerColor == nil
        or not self:isMock(playerColor)
        or parameters.isBlocked()
        or type(self.scheduler.time) ~= "function"
    then
        return false
    end

    if type(self.scheduler.hasTime) == "function"
        and not self.scheduler.hasTime()
    then
        return false
    end

    local generation = self.generation
    self.scheduler.time(function()
        if generation ~= self.generation
            or parameters.getCurrentColor() ~= playerColor
            or not self:isMock(playerColor)
        then
            return
        end

        parameters.advance(playerColor)
    end, self.config.phaseDelaySeconds)
    return true
end

return MockPlayerFeature

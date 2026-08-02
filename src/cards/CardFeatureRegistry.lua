local CardFeatureRegistry = {}
CardFeatureRegistry.__index = CardFeatureRegistry

local function validateId(id, errorLevel)
    if type(id) ~= "string" or id == "" then
        error("Card feature names must be non-empty strings.", errorLevel or 3)
    end
end

local function validateSource(source, errorLevel)
    if type(source) ~= "string" or source == "" then
        error("Card feature sources must be non-empty strings.", errorLevel or 3)
    end
end

local function copyArray(values)
    local copied = {}

    for index, value in ipairs(values or {}) do
        copied[index] = value
    end

    return copied
end

local function copyRecords(values)
    local copied = {}

    for _, value in ipairs(values or {}) do
        if type(value) == "table" then
            local record = {}

            for key, fieldValue in pairs(value) do
                record[key] = fieldValue
            end

            copied[#copied + 1] = record
        end
    end

    return copied
end

local function normalizeDescriptor(descriptor, errorLevel)
    if type(descriptor) ~= "table" then
        error("Card feature descriptors must be tables.", errorLevel or 3)
    end

    validateId(descriptor.id, (errorLevel or 3) + 1)
    validateSource(descriptor.source, (errorLevel or 3) + 1)

    return {
        id = descriptor.id,
        source = descriptor.source,
        stateVersion = tonumber(descriptor.stateVersion),
        enabledByDefault = descriptor.enabledByDefault == true,
        hasTap = descriptor.hasTap == true,
        usesButtons = descriptor.usesButtons == true,
        buttonCallbacks = copyArray(descriptor.buttonCallbacks),
        runtimeConfigKeys = copyArray(descriptor.runtimeConfigKeys),
        hostButtons = copyRecords(descriptor.hostButtons)
    }
end

function CardFeatureRegistry.new()
    return setmetatable({
        descriptorsById = {},
        orderedIds = {},
        defaultIds = {}
    }, CardFeatureRegistry)
end

function CardFeatureRegistry:register(descriptor)
    local normalized = normalizeDescriptor(descriptor, 3)

    if self.descriptorsById[normalized.id] ~= nil then
        error("Card feature already registered: " .. normalized.id, 2)
    end

    self.descriptorsById[normalized.id] = normalized
    self.orderedIds[#self.orderedIds + 1] = normalized.id

    if normalized.enabledByDefault then
        self.defaultIds[#self.defaultIds + 1] = normalized.id
    end

    return normalized
end

-- CardLogic.registerFeature historically replaced a feature's source. Keep
-- that compatibility behavior at the facade while the focused registry's
-- normal register operation continues to protect feature identity.
function CardFeatureRegistry:replace(descriptor)
    local normalized = normalizeDescriptor(descriptor, 3)
    local previous = self.descriptorsById[normalized.id]

    if previous == nil then
        return self:register(normalized)
    end

    self.descriptorsById[normalized.id] = normalized

    if normalized.enabledByDefault and not previous.enabledByDefault then
        self.defaultIds[#self.defaultIds + 1] = normalized.id
    elseif previous.enabledByDefault and not normalized.enabledByDefault then
        for index, id in ipairs(self.defaultIds) do
            if id == normalized.id then
                table.remove(self.defaultIds, index)
                break
            end
        end
    end

    return normalized
end

function CardFeatureRegistry:get(id)
    validateId(id, 3)
    return self.descriptorsById[id]
end

function CardFeatureRegistry:getDefaultIds()
    return copyArray(self.defaultIds)
end

function CardFeatureRegistry:getDescriptors()
    local descriptors = {}

    for _, id in ipairs(self.orderedIds) do
        descriptors[#descriptors + 1] = self.descriptorsById[id]
    end

    return descriptors
end

function CardFeatureRegistry:resolve(ids)
    ids = ids or self.defaultIds
    local descriptors = {}

    for _, id in ipairs(ids) do
        local descriptor = self.descriptorsById[id]

        if descriptor == nil then
            error("Unknown card feature: " .. tostring(id), 3)
        end

        descriptors[#descriptors + 1] = descriptor
    end

    return descriptors
end

return CardFeatureRegistry

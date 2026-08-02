local UiPatch = {}

function UiPatch.set(id, attribute, value)
    return {
        id = id,
        attribute = attribute,
        value = value
    }
end

function UiPatch.append(patches, id, attribute, value)
    patches[#patches + 1] = UiPatch.set(id, attribute, value)
    return patches
end

function UiPatch.extend(target, source)
    for _, patch in ipairs(source or {}) do
        target[#target + 1] = patch
    end

    return target
end

return UiPatch

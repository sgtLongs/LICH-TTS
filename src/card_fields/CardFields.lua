local Config = require("src/config/CardFieldConfig")
local DebugConfig = require("src/config/GlobalDebugConfig")
local CardFieldGeometry = require("src/card_fields/CardFieldGeometry")

local CardFields = {}
local fields = {}

function CardFields.onLoad()
    local built = CardFieldGeometry.buildAll(Config)
    fields = built.fields

    if DebugConfig.drawCardFields == true then
        Global.setVectorLines(built.lines)
    else
        Global.setVectorLines({})
    end

    print(
        "CardFields: built " .. #fields
            .. " player fields with "
            .. Config.columns .. "x" .. Config.rows .. " spaces."
    )
end

function CardFields.getFields()
    return fields
end

return CardFields

local Config = require("src/config/ButtonConfig")

local ButtonFactory = {}

function ButtonFactory.createTextButton(owner, label, clickFunction, position)
    owner.createButton({
        label = label,
        click_function = clickFunction,
        function_owner = owner,

        position = position or Config.position,
        rotation = Config.rotation,
        scale = Config.scale,

        width = Config.width,
        height = Config.height,
        font_size = Config.fontSize,

        color = Config.color,
        font_color = Config.fontColor
    })
end

return ButtonFactory

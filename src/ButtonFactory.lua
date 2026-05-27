local ButtonFactory = {}

function ButtonFactory.createTextButton(owner, label, clickFunction, position)
    owner.createButton({
        label = label,
        click_function = clickFunction,
        function_owner = owner,

        position = position or {0, 0.3, 0},
        rotation = {0, 0, 0},
        scale = {1, 1, 1},

        width = 900,
        height = 400,
        font_size = 180,

        color = {1, 1, 1},
        font_color = {0, 0, 0}
    })
end

return ButtonFactory
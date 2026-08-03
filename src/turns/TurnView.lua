local UiPatch = require("src/ui/UiPatch")

local TurnView = {}

local function add(patches, id, attribute, value)
    UiPatch.append(patches, id, attribute, value)
end

function TurnView.buildModel(
    currentColor,
    currentPhase,
    playerName
)
    return {
        currentColor = currentColor,
        currentPhase = currentPhase,
        playerName = playerName
    }
end

function TurnView.buildPatch(config, model)
    local patches = {}
    local currentColor = model.currentColor
    local currentPhase = model.currentPhase

    if currentColor == nil then
        add(
            patches,
            config.ui.playerNameId,
            "text",
            config.ui.noPlayersText
        )
        add(
            patches,
            config.ui.playerNameId,
            "color",
            "#FFFFFF"
        )
        add(
            patches,
            config.ui.colorNameId,
            "text",
            config.ui.noPlayersDetailText
        )
    else
        add(
            patches,
            config.ui.playerNameId,
            "text",
            model.playerName .. "'s Turn"
        )
        add(
            patches,
            config.ui.playerNameId,
            "color",
            config.playerHexColors[currentColor]
        )
        add(
            patches,
            config.ui.colorNameId,
            "text",
            currentColor .. " Player"
        )
    end

    for _, phase in ipairs(model.phases or {}) do
        local isCurrentPhase = phase == currentPhase
        local phaseLabel = config.phaseLabels[phase]

        if isCurrentPhase and model.isDrawing == true then
            phaseLabel = config.drawPhase.activeLabel
        end

        add(
            patches,
            config.ui.phaseIdPrefix .. phase,
            "text",
            (isCurrentPhase
                and config.ui.activePhasePrefix
                or config.ui.inactivePhasePrefix)
                .. phaseLabel
        )
        add(
            patches,
            config.ui.phaseIdPrefix .. phase,
            "color",
            isCurrentPhase
                and config.ui.activePhaseColor
                or config.ui.inactivePhaseColor
        )
    end

    for _, playerColor in ipairs(config.playerColors) do
        local buttonId = config.ui.phaseButtonPrefix .. playerColor
        local isCurrentPlayer = playerColor == currentColor
        local activeButtonText = config.ui.activeButtonText

        if currentPhase == "start" then
            activeButtonText = config.ui.startPhaseButtonText
        elseif currentPhase == "draw" and model.isDrawing == true then
            activeButtonText = config.ui.drawingButtonText
        elseif currentPhase == "end" then
            activeButtonText = model.isPlacingDeathFog == true
                and config.ui.deathFogButtonText
                or config.ui.endPhaseButtonText
        end

        add(
            patches,
            buttonId,
            "text",
            isCurrentPlayer and activeButtonText
                or config.ui.waitingButtonText
        )
        add(
            patches,
            buttonId,
            "interactable",
            isCurrentPlayer and model.isDrawing ~= true
                and model.isPlacingDeathFog ~= true
                and "true" or "false"
        )
    end

    return patches
end

return TurnView

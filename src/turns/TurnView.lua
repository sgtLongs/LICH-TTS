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
        local awaitingFirstPlayer = model.hasStarted ~= true
            and #(model.activePlayerColors or {}) > 0
        add(
            patches,
            config.ui.playerNameId,
            "text",
            awaitingFirstPlayer
                and config.ui.awaitingFirstPlayerText
                or config.ui.noPlayersText
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
            awaitingFirstPlayer
                and config.ui.awaitingFirstPlayerDetailText
                or config.ui.noPlayersDetailText
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
                and model.isUntapping ~= true
                and model.isPlacingDeathFog ~= true
                and "true" or "false"
        )
    end

    local activePlayerColors = model.activePlayerColors or {}
    local hasActivePlayers = #activePlayerColors > 0
    add(
        patches,
        config.ui.firstPlayerButtonId,
        "active",
        model.hasStarted == true and "false" or "true"
    )
    add(
        patches,
        config.ui.firstPlayerButtonId,
        "interactable",
        hasActivePlayers and "true" or "false"
    )
    add(
        patches,
        config.ui.firstPlayerButtonId,
        "text",
        hasActivePlayers
            and config.ui.chooseFirstPlayerText
            or config.ui.waitingForDecksText
    )
    add(
        patches,
        config.ui.firstPlayerMenuRootId,
        "active",
        model.firstPlayerMenuOpen == true and "true" or "false"
    )

    local activeByColor = {}
    for _, playerColor in ipairs(activePlayerColors) do
        activeByColor[playerColor] = true
    end

    for _, playerColor in ipairs(config.playerColors) do
        add(
            patches,
            config.ui.firstPlayerChoicePrefix .. playerColor,
            "active",
            activeByColor[playerColor] == true and "true" or "false"
        )
    end

    add(
        patches,
        config.ui.playersMenuRootId,
        "active",
        model.playersMenuOpen == true and "true" or "false"
    )

    local playerNamesByColor = model.playerNamesByColor or {}
    for _, playerColor in ipairs(config.playerColors) do
        add(
            patches,
            config.ui.playersRowPrefix .. playerColor,
            "active",
            activeByColor[playerColor] == true and "true" or "false"
        )
        add(
            patches,
            config.ui.playersNamePrefix .. playerColor,
            "text",
            playerNamesByColor[playerColor] or playerColor
        )
    end

    return patches
end

return TurnView

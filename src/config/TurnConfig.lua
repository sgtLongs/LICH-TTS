local TurnConfig = {
    playerColors = {
        "White",
        "Brown",
        "Red",
        "Green",
        "Teal",
        "Blue"
    },
    playerHexColors = {
        White = "#FFFFFF",
        Brown = "#713B17",
        Red = "#C83232",
        Green = "#2E9F4D",
        Teal = "#21B19B",
        Blue = "#2E6DD8"
    },
    ui = {
        playerNameId = "turnPlayerName",
        colorNameId = "turnColorName",
        phaseIdPrefix = "turnPhase",
        phaseButtonPrefix = "advancePhase",
        firstPlayerButtonId = "chooseFirstPlayer",
        firstPlayerMenuRootId = "firstPlayerMenuRoot",
        firstPlayerChoicePrefix = "firstPlayerChoice",
        playersButtonId = "playersButton",
        playersMenuRootId = "playersMenuRoot",
        playersRowPrefix = "playersRow",
        playersNamePrefix = "playersName",
        playersRemovePrefix = "playersRemove",
        activePhaseColor = "#FBBF24",
        inactivePhaseColor = "#9CA3AF",
        activePhasePrefix = "> ",
        inactivePhasePrefix = "  ",
        startPhaseButtonText = "UNTAPPING...",
        activeButtonText = "NEXT PHASE",
        drawingButtonText = "DRAWING...",
        deathFogButtonText = "PLACE DEATH FOG",
        endPhaseButtonText = "END TURN",
        waitingButtonText = "WAITING...",
        noPlayersText = "WAITING FOR DECKS",
        noPlayersDetailText = "Spawn a deck to join",
        awaitingFirstPlayerText = "CHOOSE FIRST PLAYER",
        awaitingFirstPlayerDetailText = "Waiting for an admin",
        chooseFirstPlayerText = "CHOOSE WHO GOES FIRST",
        waitingForDecksText = "SPAWN DECKS FIRST",
        removePlayerText = "REMOVE"
    },
    phaseLabels = {
        start = "START PHASE",
        main = "MAIN PHASE",
        draw = "DRAW PHASE",
        status = "STATUS PHASE",
        ["end"] = "END PHASE"
    },
    drawPhase = {
        delaySeconds = 0,
        cardIntervalSeconds = 0.2,
        deckSearchRadius = 4,
        activeLabel = "DRAWING"
    },
    invalidTurnColor = {1, 0.35, 0.35}
}

return TurnConfig

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
        endTurnButtonPrefix = "endTurn",
        activeButtonText = "END MY TURN",
        waitingButtonText = "WAITING...",
        noPlayersText = "WAITING FOR DECKS",
        noPlayersDetailText = "Spawn a deck to join"
    },
    invalidTurnColor = {1, 0.35, 0.35}
}

return TurnConfig

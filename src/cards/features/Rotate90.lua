return {
    id = "rotate90",
    stateVersion = 1,
    enabledByDefault = true,
    hasTap = true,
    usesButtons = true,
    hostButtons = {
        {
            callback = "onCardTapped",
            removeOnRefresh = true
        }
    },
    source = [=[
local function notifyActionZoneRotationChanged(rotated)
    if Global ~= nil and type(Global.call) == "function" then
        pcall(
            Global.call,
            "onActionZoneCardRotationChanged",
            {card = self, rotated = rotated}
        )
    end
end

registerCardFeature({
    id = "rotate90",
    stateVersion = 1,
    usesButtons = true,

    migrate = function(state, savedVersion)
        -- Missing versions are the legacy generated-card state. The legacy
        -- shape already uses `rotated`, so migration only normalizes it.
        state.rotated = state.rotated == true
        return state
    end,

    onLoad = function(state)
        local rotated = readCardTapRotation()
        notifyActionZoneRotationChanged(rotated)
    end,

    onTap = function(state)
        local rotated = not readCardTapRotation()
        writeCardTapRotation(rotated)
        notifyActionZoneRotationChanged(rotated)

        if type(hideActionButtonsDuringCardRotation) == "function" then
            hideActionButtonsDuringCardRotation()
        end

        local targetSpin = cardTapRotationTarget(rotated)

        if type(self.getRotation) == "function"
            and type(self.setRotationSmooth) == "function"
        then
            local rotation = self.getRotation()

            -- Use an exact target and ignore collisions while turning. The
            -- relative rotate API can be physically constrained by the
            -- locked cards directly beneath an action-stack card.
            self.setRotationSmooth({
                x = rotation.x,
                y = targetSpin,
                z = rotation.z
            }, false, true)
        else
            self.rotate({
                x = 0,
                y = normalizeSignedRotation(targetSpin - currentCardSpin()),
                z = 0
            })
        end
    end,

    onRotate = function(state, spin)
        local rotated = readCardTapRotation(spin)
        notifyActionZoneRotationChanged(rotated)

        if type(hideActionButtonsDuringCardRotation) == "function" then
            hideActionButtonsDuringCardRotation()
        end
    end
})
]=]
}

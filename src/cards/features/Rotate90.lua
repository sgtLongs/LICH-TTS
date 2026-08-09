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
        state.rotated = state.rotated == true
        notifyActionZoneRotationChanged(state.rotated)
    end,

    onTap = function(state)
        state.rotated = not state.rotated
        notifyActionZoneRotationChanged(state.rotated)

        if type(hideActionButtonsDuringCardRotation) == "function" then
            hideActionButtonsDuringCardRotation()
        end

        local amount = state.rotated and 90 or -90

        if type(self.getRotation) == "function"
            and type(self.setRotationSmooth) == "function"
        then
            local rotation = self.getRotation()

            -- Use an exact target and ignore collisions while turning. The
            -- relative rotate API can be physically constrained by the
            -- locked cards directly beneath an action-stack card.
            self.setRotationSmooth({
                x = rotation.x,
                y = rotation.y + amount,
                z = rotation.z
            }, false, true)
        else
            self.rotate({x = 0, y = amount, z = 0})
        end
    end
})
]=]
}

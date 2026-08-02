return {
    -- Cards without a matching entry keep the mechanics that every generated
    -- card had before card definitions became data-driven.
    defaultFeatureIds = {
        "rotate90",
        "destroyToPurgatory"
    },

    -- Add individual-card overrides here. An empty featureIds array is a
    -- deliberate mechanic-free card; a missing entry uses the defaults.
    cards = {
        -- Example shape:
        -- {
        --     id = "api-card-id",
        --     featureIds = {"rotate90"}
        -- }
    }
}

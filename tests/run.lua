local Test = require("tests/support/Test")

local modules = {
    { "tests/test_test_support", { "unit" } },
    { "tests/test_game_save_codec", { "unit" } },
    { "tests/test_compatibility_fixtures", { "compatibility" } },
    { "tests/test_tts_adapters", { "unit", "integration" } },
    { "tests/test_object_scripts", { "generated", "integration" } },
    { "tests/test_hex_geometry", { "unit" } },
    { "tests/test_death_fog_rules", { "unit" } },
    { "tests/test_surfaces", { "unit", "integration" } },
    { "tests/test_hex_board_model", { "unit", "integration" } },
    { "tests/test_hex_grid_controller", { "integration" } },
    { "tests/test_card_field_geometry", { "unit" } },
    { "tests/test_card_fields", { "integration" } },
    { "tests/test_action_zone", { "integration" } },
    { "tests/test_action_zone_regressions", { "unit", "integration" } },
    { "tests/test_deck_generator", { "integration" } },
    { "tests/test_card_api_normalizer", { "unit" } },
    { "tests/test_card_logic", { "generated", "integration" } },
    { "tests/test_card_definitions", { "unit", "generated" } },
    { "tests/test_generated_card_runtime", { "generated", "integration" } },
    { "tests/test_deck_selection_menu", { "unit", "integration" } },
    { "tests/test_hex_grid_builder", { "integration" } },
    { "tests/test_hex_grid_menu", { "unit", "integration" } },
    { "tests/test_hex_grid", { "integration" } },
    { "tests/test_hex_object_spawner", { "integration" } },
    { "tests/test_hex_board_state", { "unit" } },
    { "tests/test_saved_board_catalog", { "unit" } },
    { "tests/test_board_load_coordinator", { "unit" } },
    { "tests/test_dungeon_map_state", { "unit" } },
    { "tests/test_dungeon_map_rules", { "unit" } },
    { "tests/test_settings_dungeon_views", { "unit" } },
    { "tests/test_dungeon_map", { "integration" } },
    { "tests/test_turn_state", { "unit" } },
    { "tests/test_turn_system", { "integration" } },
    { "tests/test_settings_menu", { "integration" } },
    { "tests/test_composition_smoke", { "integration" } },
    { "tests/test_global", { "integration" } },
    { "tests/test_game_controller", { "integration" } },
    { "tests/test_game", { "integration" } },
}

local options = TEST_RUNNER_OPTIONS or {}

for _, module in ipairs(modules) do
    local moduleName = module[1]
    local shouldLoad = options.files == nil or #options.files == 0

    if not shouldLoad then
        for _, fragment in ipairs(options.files) do
            if
                string.find(
                    string.lower(moduleName),
                    string.lower(fragment),
                    1,
                    true
                ) ~= nil
            then
                shouldLoad = true
                break
            end
        end
    end

    if shouldLoad then
        Test.beginModule(moduleName, module[2])
        require(moduleName)
        Test.endModule()
    end
end

Test.run(options)

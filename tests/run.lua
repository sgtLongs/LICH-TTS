local Test = require("tests/support/Test")

require("tests/test_hex_geometry")
require("tests/test_hex_grid_builder")
require("tests/test_hex_board_state")
require("tests/test_dungeon_map_state")
require("tests/test_turn_state")
require("tests/test_turn_system")
require("tests/test_game")

Test.run()

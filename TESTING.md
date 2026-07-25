# Automated tests

The automated suite runs the Lua source in MoonSharp, the Lua interpreter on
which Tabletop Simulator's scripting environment is based. Tests focus on pure
game rules and use small mocks at the TTS API boundary. Before running the test
cases, the runner also compiles every source and object script to catch syntax
errors in modules that a particular test does not load.

From Windows:

```console
run-tests.cmd
```

On macOS or Linux, run the underlying cross-platform command:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release
```

The first run restores the pinned MoonSharp NuGet package. Later runs use the
local NuGet cache.

## Test layout

- `tests/test_hex_geometry.lua`: grid construction, adjacency, and hit testing.
- `tests/test_hex_grid_builder.lua`: mocked TTS buttons, surface resolution, and
  vector-line output.
- `tests/test_hex_board_state.lua`: imported board-state validation.
- `tests/test_dungeon_map_state.lua`: dungeon construction, traversal, and
  persistence.
- `tests/test_turn_state.lua`: pure turn progression.
- `tests/test_turn_system.lua`: integration with mocked TTS globals.
- `tests/test_game.lua`: save/load orchestration and persistence with mocked
  subsystems.
- `tests/support/Test.lua`: dependency-free Lua assertions and runner.
- `tests/runner`: minimal .NET host for MoonSharp.

Add new cases with `Test.case("description", function() ... end)`. A failed
assertion causes the runner to exit nonzero, so the command can be used
unchanged in continuous integration. The GitHub Actions workflow in
`.github/workflows/tests.yml` runs it on every push and pull request. The
public-repository workflow uses a read-only token, immutable action SHAs,
non-persisted checkout credentials, locked dependencies, and a job timeout.
Dependabot proposes updates to the pinned actions and test dependency.

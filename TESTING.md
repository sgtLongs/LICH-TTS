# Automated tests

The automated suite runs the Lua source in MoonSharp, the Lua interpreter on
which Tabletop Simulator's scripting environment is based. Tests focus on pure
game rules and use small mocks at the TTS API boundary. Before running the test
cases, the runner also compiles every source, generated card, and tracked TTS
object script to catch syntax errors in modules that a particular test does not
load. It parses every tracked object JSON file and the Global UI XML fragment,
checks UI IDs and callback bindings in their exact rendered order, compiles
every supported card-feature combination, and fails if generated Global UI,
object scripts, or the root and tracked-object copies of `Global.lua` drift
apart.

From Windows:

```console
run-tests.cmd
```

On macOS or Linux, run the underlying cross-platform command:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release
```

### Focused test runs

The runner accepts repeatable file, name, and tag filters. Multiple values for
the same option are combined as alternatives; different option types are
intersected.

```console
run-tests.cmd --file board_load_coordinator
run-tests.cmd --filter timeout --filter stale
run-tests.cmd --tag unit --exclude-tag generated
run-tests.cmd --file hex_grid --filter placement
```

Available module tags are `unit`, `integration`, `generated`, and
`compatibility`. A `Test.case` can add tags with an optional third argument,
for example `Test.case("description", callback, {"slow"})`.

Useful feedback options are:

```console
run-tests.cmd --fail-fast
run-tests.cmd --timing --slowest 10
run-tests.cmd --failed
run-tests.cmd --help
```

`--failed` reruns the exact failures recorded by the previous test run. The
local record is stored in the ignored `tests/.last-failures` file. A successful
run clears it. Deep-table assertion failures report the first mismatched path
and its expected and actual values.

For cross-platform invocation, place runner options after `--`:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --tag unit --slowest 5
```

The first run restores the pinned MoonSharp NuGet package. Later runs use the
local NuGet cache.

## Canonical object scripts

Object-local Lua sources live in `object_logic/`. The mappings in
`object_logic/ObjectScriptManifest.json` deterministically synchronize those
sources to both the GUID-named Lua sidecars and the root `LuaScript` embedded
in each `.data.json` asset under `.tts/objects`. The normal test suite fails
when a tracked object-local script is unmapped or either published copy drifts
from its canonical source.

After changing or adding a canonical object script, synchronize the tracked
copies with:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --sync-object-scripts
```

For a quick drift and compilation check without the Lua test cases, run:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --check-object-scripts
```

To add an object, reuse an existing canonical source when behavior is identical;
otherwise add a narrowly named source under `object_logic/`. Add the target to
the manifest, synchronize, and run the full suite. Keep object save-state
decoding backward compatible whenever a canonical script has an `onLoad`
parameter or `onSave` callback.

## Generated Global UI regions

Repeated controls in `.tts/objects/Global.xml` are generated from the same Lua
configuration and definition modules used at runtime. Marker comments bound
each generated region, so synchronization changes only those regions and
preserves the surrounding hand-authored layout.

After changing settings boards, deck choices, dungeon tiles or boards, turn
controls, or hex spawn/menu choices, synchronize the XML with:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --sync-global-ui
```

For a quick drift check without running the Lua test cases, run:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --check-global-ui
```

Do not hand-edit controls inside a generated marker pair. Change the owning Lua
definition or the renderer in `tests/runner/Program.cs`, synchronize, and run
the full suite. Normal test runs also reject generated-region drift.

## Test layout

- `tests/test_compatibility_fixtures.lua`: durable Settings, Dungeon, action
  stack, generated-card, board-template, and deck-API compatibility fixtures.
- `tests/test_game_save_codec.lua`: legacy/current root-save migration and
  unknown-version fallback.
- `tests/test_tts_adapters.lua`: runtime, scheduling, UI, object, web, and
  deterministic fake contracts.
- `tests/test_object_scripts.lua`: canonical cabinet, board, state-toggle, and
  decoration behavior plus legacy cabinet lock-state compatibility.
- `tests/test_hex_geometry.lua`: grid construction, adjacency, and hit testing.
- `tests/test_surfaces.lua`: surface eligibility, replacement, protected death
  fog, player ownership, and picker UI patches.
- `tests/test_hex_board_state.lua`: strict imported-board validation.
- `tests/test_hex_board_model.lua`: model isolation, placement rules, codec,
  controller, and view boundaries.
- `tests/test_hex_grid_builder.lua`: mocked TTS buttons, surface resolution, and
  vector-line output.
- `tests/test_hex_grid_controller.lua`: atomic import validation, asynchronous
  load completion, missing-object replacement, and destruction behavior.
- `tests/test_hex_grid.lua`: board interaction and object-placement workflows.
- `tests/test_hex_grid_menu.lua`: editor UI ownership and action routing.
- `tests/test_hex_object_spawner.lua`: object placement, correction, and failure
  behavior.
- `tests/test_card_field_geometry.lua`: field, slot, zone, and rotation geometry.
- `tests/test_card_fields.lua`: field loading, ownership, deck buttons, saving,
  and collaborator routing.
- `tests/test_action_zone*.lua`: action-row layout, stacks, navigation, locks,
  persistence, and movement between fields.
- `tests/test_deck_generator.lua`: API payload conversion plus failure and retry
  behavior, injected ports, and isolated in-flight state.
- `tests/test_deck_selection_menu.lua`: deck-menu model/view snapshots,
  authorization, generation routing, and controller isolation.
- `tests/test_card_api_normalizer.lua`: canonical card definitions, API aliases,
  filtering, and data-selected features.
- `tests/test_card_definitions.lua`: unique/known feature IDs and buildability
  of every configured individual-card feature set.
- `tests/test_card_logic.lua`: Global-side card services and generated source
  contracts.
- `tests/test_generated_card_runtime.lua`: behavioral execution of generated
  card lifecycle, tap, hover, and action callbacks.
- `tests/test_settings_menu.lua`: settings UI, board catalog, import/export, and
  authorization behavior.
- `tests/test_saved_board_catalog.lua` and
  `tests/test_board_load_coordinator.lua`: pure CRUD/migration and asynchronous
  load ordering.
- `tests/test_dungeon_map_state.lua`: dungeon construction, traversal, and
  persistence.
- `tests/test_dungeon_map_rules.lua`: pure assignment, clearing, traversal, and
  validation ordering.
- `tests/test_dungeon_map.lua`: dungeon UI assignment and asynchronous traversal.
- `tests/test_turn_state.lua`: pure turn progression.
- `tests/test_turn_system.lua`: integration with mocked TTS globals.
- `tests/test_action_points.lua`: pure AP use, restoration, renewal, and saves.
- `tests/test_settings_dungeon_views.lua`: pure UI patch snapshots.
- `tests/test_game_controller.lua`: dependency-injected composition, load/save,
  persistence failure behavior, and legacy callback return contracts.
- `tests/test_game.lua`: save/load orchestration and persistence with mocked
  subsystems.
- `tests/test_composition_smoke.lua`: the real Global -> Game -> subsystem
  composition running against deterministic fake TTS ports.
- `tests/test_global.lua`: TTS callback signatures and Game routing.
- `tests/support/Test.lua`: dependency-free Lua assertions and runner.
- `tests/runner`: minimal .NET host for MoonSharp.

Add new cases with `Test.case("description", function() ... end)`. A failed
assertion causes the runner to exit nonzero, so the command can be used
unchanged in continuous integration. The GitHub Actions workflow in
`.github/workflows/tests.yml` runs it on every push and pull request. The
public-repository workflow uses a read-only token, immutable action SHAs,
non-persisted checkout credentials, locked dependencies, and a job timeout.
Dependabot proposes updates to the pinned actions and test dependency.

## Manual Tabletop Simulator smoke test

The automated suite cannot reproduce Unity physics, collider rebuilding, hand
measurement, object state replacement, or remote asset timing. Run this list in
TTS after changing those boundaries and before publishing a save:

1. Load an existing unversioned save, then save/reload it and confirm turns,
   deck buttons, selected hexes, placed objects, saved boards, dungeon
   assignments, and edit mode are retained.
2. Spawn a deck for two different player fields. Confirm the spawn button is
   removed, both players join turn order, the Hero is extracted into its slot,
   and another request cannot start for the same field while loading.
3. Draw and return cards through a multi-card deck, a one-card deck, and after
   the original deck is gone. Confirm hand cards expose no scripted buttons.
4. Open the actions menu and confirm gravity is disabled so the card stays
   raised with its configured glow outline while its player-only preview and
   four action buttons are visible on the left, with no side buttons on the
   card. Click elsewhere and each preview action button; confirm the glow is
   removed, the prior gravity setting is restored,
   the preview closes, and the card lowers before destroy, damn, unequip, or
   return continues. Build a multi-card action stack and open actions from its
   currently raised card; confirm every card in the stack lifts and the
   preview's right-side arrows and the card's arrows cycle the same image and
   action target without closing the preview. Confirm each newly selected card
   moves in front of the other lifted stack cards. Save/reload an older tapped
   card and a card with unversioned feature state.
5. Drop cards into every rotated action field, create/navigate/dissolve a stack,
   move it across fields, and verify original locks are restored.
6. Enter board edit mode; place one-cell and two-cell objects, rotate, replace,
   delete, save/export, clear/load/import, and verify buttons/tags and collider
   positions settle correctly. Leave edit mode, open the surface picker from
   empty and Source Stone hexes, place each configured surface, and verify its
   tint/opacity. Confirm the Source Stone settles on top, one non-fog surface
   replaces another, the red remove button deletes a selected non-fog surface,
   and death-fog hexes reject new surface placement while the red remove
   button still removes the death fog.
7. Save several named boards, paginate/select them in Settings and DungeonMap,
   traverse adjacent levels, and confirm failed/timed-out loads leave traversal
   usable.
8. Open each UI as admin and non-admin and compare visibility, ownership,
   labels, phase buttons, and permissions with the prior published save.
9. Toggle every cabinet/stateful object, reload, and verify hidden-object
   positions and original lock states return correctly.

Record the TTS version and the save used when a smoke failure depends on engine
behavior.

Architecture and extension recipes are in `DEVELOPMENT.md`.

# AGENTS.md

This file is the operational guide for AI coding agents working in this
repository. Keep changes small, preserve compatibility with existing Tabletop
Simulator (TTS) saves/scripts, and use the existing architecture instead of
creating parallel abstractions.

## Start here

1. Read the relevant section of `DEVELOPMENT.md` before changing behavior.
2. Read `TESTING.md` before editing generated UI or object scripts.
3. Inspect nearby source and tests before proposing a new pattern.
4. Check `git status --short`; preserve unrelated user changes.

Use `rg` and `rg --files` for discovery. Prefer targeted reads and tests over
loading the entire repository.

## Repository map

- `Global.lua`: thin TTS callback facade; keep business logic out.
- `src/Game.lua`: composition root.
- `src/GameController.lua`: top-level orchestration.
- `src/`: Lua models, rules, controllers, views, adapters, and compatibility
  facades.
- `data/`: stable definitions and saved TTS object templates.
- `object_logic/`: canonical object-local Lua scripts.
- `.tts/objects/`: synchronized/published TTS assets; some files are generated.
- `tests/`: Lua tests and deterministic TTS fakes.
- `tests/runner/`: .NET 8/MoonSharp runner, validation, and sync tooling.
- `types/tts/`: LuaLS-only definitions for TTS globals and APIs; never loaded
  by the game.

## Feature ownership index

Use this index before broad searches. Start with the section that matches the
requested behavior, then read the named config/data, pure state or rules,
controller, and closest tests. Cross subsystem boundaries through
`GameController` or an injected dependency rather than reaching directly into
another subsystem's state.

### Game lifecycle and callback routing

- `Global.lua` owns only TTS callback signatures and forwards them to
  `src/Game.lua`; `.tts/objects/Global.lua` is its synchronized published copy.
- `src/Game.lua` constructs shared services and subsystem defaults.
  `src/GameController.lua` coordinates load, save, restart, object events, and
  UI callbacks. Add gameplay decisions to the owning subsystem, not these
  facades.
- Start with `tests/test_global.lua`, `tests/test_game.lua`,
  `tests/test_game_controller.lua`, and `tests/test_composition_smoke.lua`.

### Player card fields, hero stats, and action points

- `src/config/CardFieldConfig.lua` owns stable field/surface GUID mappings,
  owner colors, zone definitions, deck and hero slots, stat displays, and
  action-point controls. `playerColor` identifies a physical configured
  position; `ownerColor` identifies the player who owns it. Do not treat them
  as interchangeable.
- `CardFieldDefinitions`, `CardFieldGeometry`, and `CardFieldLayout` derive
  immutable field geometry. `CardFieldState` owns persisted deck-spawn and hero
  state. `src/action_points/ActionPoints.lua` owns action-point transitions.
- `CardFieldController` owns TTS objects, buttons, authorization, and event
  routing; `CardFields.lua` is the compatibility facade.
- Start with `tests/test_card_field_geometry.lua`,
  `tests/test_card_fields.lua`, and `tests/test_action_points.lua`.

### Deck selection, remote deck generation, and card definitions

- Deck choices and spawn geometry live in
  `src/config/CardFieldConfig.lua`. Selection state/controller/view live in
  `src/card_fields/DeckSelectionMenu*.lua`.
- `src/card_fields/DeckGenerator.lua` owns the asynchronous API fetch and TTS
  deck/hero spawning. `CardApiNormalizer` converts the response to immutable
  `CardDefinition` values; keep untrusted response validation at that boundary.
- `data/CardDefinitions.lua` selects stable card feature IDs by API card ID or
  name and defines defaults. `data/Cards.lua` is currently empty and unused;
  do not put new definitions or mechanics there.
- Start with `tests/test_deck_selection_menu.lua`,
  `tests/test_deck_generator.lua`, `tests/test_card_api_normalizer.lua`, and
  `tests/test_card_definitions.lua`.

### Generated individual-card behavior

- `src/cards/CardFeatureRegistry.lua` validates and resolves feature
  descriptors. `src/cards/CardLogic.lua` registers built-ins and keeps the
  legacy facade. Feature implementations live in `src/cards/features/`.
- `CardScriptBuilder` combines selected features with the shared lifecycle in
  `CardRuntimeSource`; `CardHostService` owns Global-side operations performed
  on live card objects. Configuration for buttons, previews, and generated
  script context lives in `src/config/CardLogicConfig.lua`.
- Feature IDs and state versions are save contracts. Test lifecycle behavior
  and feature combinations, not only generated source text.
- Start with `tests/test_card_logic.lua`,
  `tests/test_generated_card_runtime.lua`, and
  `tests/test_card_definitions.lua`.

### Action-zone stacks and card movement

- `src/card_fields/zones/ActionZoneState.lua` owns persisted stacks and
  selection. `ActionZoneRules` owns drop/remove/prefer/navigate transitions,
  and `ActionZoneLayout` calculates card transforms.
- `ActionZoneController` owns live-card movement, locking, buttons, delayed
  correction, and event handling. `ZoneBehaviorRegistry` connects it to
  `CardFieldController`; `src/card_fields/ActionZone.lua` is the compatibility
  facade.
- Card-local action buttons that send a card to a field destination live in
  `src/cards/features/FieldActions.lua`; coordinate changes on both sides of
  this boundary.
- Start with `tests/test_action_zone.lua`,
  `tests/test_action_zone_regressions.lua`, and relevant generated-card tests.

### Turns, drawing, and end-phase death fog

- `src/config/TurnConfig.lua` owns player order, phases, draw timing, and UI
  IDs. `TurnState` owns pure turn transitions, `DrawPhase` owns draw-count and
  deck-selection rules, and `TurnView` renders UI patches.
- `TurnController` owns authorization and asynchronous draws;
  `TurnSystem.lua` is the compatibility facade. Deck spawning activates a
  player through the dependency wired in `src/Game.lua`.
- End-phase placement is coordinated through `HexGridController`.
  `src/turns/DeathFogRules.lua` selects candidates using the shared surface
  definitions and rules; do not create a parallel death-fog placement model.
- Start with `tests/test_turn_state.lua`, `tests/test_turn_system.lua`, and
  `tests/test_death_fog_rules.lua`.

### Hex board, edit mode, and object placement

- `src/config/HexGridConfig.lua` owns board GUID, schema/tag contracts, grid
  scale, and interaction visuals. `HexGeometry` owns coordinate math;
  `HexBoardModel` owns board state; `HexBoardCodec` validates import/export;
  `HexPlacementRules` owns occupancy and facing decisions.
- `HexGridBuilder` and `HexGridView` create grid interaction visuals.
  `HexGridMenu*` owns the cell/spawn picker. `HexGridController` orchestrates
  edit mode and persistence and delegates live spawning to `HexObjectSpawner`.
- Spawnable definitions live in `src/hex/HexSpawnDefinitions.lua`; their saved
  TTS templates live in `data/HexGridObjectTemplates.lua`. Stable template
  keys are persisted.
- Start with `tests/test_hex_geometry.lua`, `tests/test_hex_board_model.lua`,
  `tests/test_hex_board_state.lua`, `tests/test_hex_grid_controller.lua`,
  `tests/test_hex_grid_menu.lua`, and `tests/test_hex_object_spawner.lua`.

### Board surfaces

- `src/config/SurfaceConfig.lua` is the canonical list of surface keys,
  appearance, special flags, and menu IDs. `SurfaceDefinitions` derives
  placement definitions and `SurfaceTemplateFactory` derives TTS templates;
  do not duplicate a saved-object template per surface.
- `SurfaceRules` owns placement/removal eligibility, `SurfaceMenuModel` owns
  picker state, and `SurfaceController` owns the player interaction and routes
  spawning through the hex-grid boundary.
- Start with `tests/test_surfaces.lua` and
  `tests/test_death_fog_rules.lua`.

### Settings, saved boards, and restart

- `src/config/SettingsConfig.lua` owns menu/schema constants and only exposes
  legacy aliases for hex-board contracts. `SettingsView` renders the menu;
  `SettingsMenuController` owns admin authorization, edit mode, save/load,
  JSON import/export, deck renewal, and restart actions.
- `src/boards/SavedBoardCatalog.lua` owns saved-board identity, naming,
  selection, paging, and serialization. It is constructed once in
  `src/Game.lua` and shared with Dungeon Map. `src/SettingsMenu.lua` is the
  compatibility facade.
- Restart orchestration belongs in `GameController`; preserve the documented
  distinction between resetting game state, preserving the current map, and
  clearing placed surfaces.
- Start with `tests/test_settings_menu.lua`,
  `tests/test_saved_board_catalog.lua`, and `tests/test_game_controller.lua`.

### Dungeon map and board traversal

- `src/dungeon/DungeonMapConfig.lua` owns map schema, radius, load-lock timing,
  and UI IDs. `DungeonMapState` owns cells, assignments, current level, and
  serialization; `DungeonMapRules` owns assignment, paging, adjacency, and
  traversal validation; `DungeonMapView` renders patches.
- `DungeonMapController` owns admin edit mode and asynchronous traversal. It
  refers to saved boards by stable catalog ID and loads them through injected
  Settings/board-loading boundaries. `DungeonMap.lua` is the compatibility
  facade.
- Start with `tests/test_dungeon_map_state.lua`,
  `tests/test_dungeon_map_rules.lua`, `tests/test_dungeon_map.lua`, and
  `tests/test_settings_dungeon_views.lua`.

### Persistence and shared asynchronous coordination

- `src/persistence/GameSaveCodec.lua` owns the root save envelope, schema, and
  legacy migration. Each subsystem owns its normalized nested save state; keep
  unknown fields when practical.
- `src/boards/BoardLoadCoordinator.lua` is the single generation/timeout
  authority for Settings and Dungeon loads and is shared from `src/Game.lua`.
  `src/tts/Scheduler.lua` adapts `Wait`; use `tests/support/FakeWait.lua` for
  deterministic frames, time, conditions, cancellation, and timeout coverage.
- Start with `tests/test_game_save_codec.lua`,
  `tests/test_compatibility_fixtures.lua`, and
  `tests/test_board_load_coordinator.lua`.

### Global UI and TTS boundary adapters

- UI IDs and visual constants belong to the owning config. Views return
  ordered `src/ui/UiPatch.lua` records; only `src/tts/UiAdapter.lua` applies
  them. `Runtime`, `Scheduler`, `WebAdapter`, and `ObjectAdapter` isolate other
  TTS APIs.
- `.tts/objects/Global.xml` is the published UI. Repeated generated regions are
  rendered by `tests/runner/Program.cs` from their owning Lua definitions;
  follow the synchronization workflow below.
- Start with the feature's view test, `tests/test_tts_adapters.lua`,
  `tests/test_global.lua`, and generated-UI validation.

### Object-local scripts

- `object_logic/*.lua` contains canonical scripts for boards, cabinet storage,
  state toggles, and static decoration. `ObjectScriptManifest.json` maps each
  canonical source to sidecar and embedded published copies under
  `.tts/objects/`.
- Preserve `CabinetStorage.lua`'s established `script_state` shape and object
  identity assumptions. Read `object_logic/README.md`, edit only the canonical
  source, then synchronize as described below.
- Start with `tests/test_object_scripts.lua` and the object-script drift check.

## Lua development infrastructure

- Lua Language Server is configured by `.luarc.json` for Lua 5.2, repository
  `require` paths, and the definitions in `types/tts/`. Prefer adding focused
  LuaLS annotations to shared data contracts and injected boundaries. Keep
  runtime validation for saved, generated, and external data.
- StyLua is configured by `stylua.toml`. Adopt it incrementally: format or
  check only canonical Lua files changed by the task:

  ```console
  format-lua.cmd src/path/File.lua tests/test_file.lua
  check-lua-format.cmd src/path/File.lua tests/test_file.lua
  ```

- `.styluaignore` excludes `.tts/`. Never use formatting to modify published
  or generated copies. Formatting an `object_logic/` source still requires the
  normal object-script synchronization step.
- Do not mass-format unrelated files. Keep formatting changes in the same
  cohesive diff as the source changes that required them.

## Architecture rules

Follow this dependency direction:

```text
Global callbacks -> GameController -> subsystem controllers
                                  -> pure state/rules/models
                                  -> views -> UiPatch -> UiAdapter
                                  -> Runtime/Scheduler/WebAdapter
```

- Keep TTS globals (`Player`, `UI`, `Wait`, `WebRequest`, live objects, and
  global functions) out of pure modules.
- Put state transitions and validation in pure models/rules. Controllers own
  authorization and side effects. Views return ordered `UiPatch` arrays.
- Inject runtime boundaries and use fakes in tests.
- Prefer existing constructible `.new(dependencies)` APIs. Retain compatibility
  facades while saved/generated scripts or callbacks may still use them.
- Treat stable IDs, GUIDs, schema versions, field IDs, board IDs, card IDs, and
  feature IDs as persistence contracts. Do not rename them casually.
- Preserve unknown saved fields when practical and keep legacy migrations
  working.
- Route Settings and Dungeon asynchronous board loads through the shared
  `BoardLoadCoordinator`; do not introduce independent generation counters.

## Generated and synchronized files

Do not hand-edit generated copies.

- Object scripts: edit the canonical source in `object_logic/`, update
  `object_logic/ObjectScriptManifest.json` if needed, then run:

  ```console
  dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --sync-object-scripts
  ```

- Repeated Global UI controls: edit their owning Lua definition or the renderer
  in `tests/runner/Program.cs`, then run:

  ```console
  dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --sync-global-ui
  ```

- Never edit controls inside a generated marker pair in
  `.tts/objects/Global.xml`.
- Keep root `Global.lua`, tracked object copies, embedded JSON scripts, and
  generated XML synchronized; the test runner checks drift.

After synchronization, review every generated diff and include only changes
caused by the source edit.

## Efficient change workflow

1. Locate the owning module and its closest tests with `rg`.
2. Reproduce a bug with a focused regression test when feasible.
3. Make the smallest cohesive change at the correct layer.
4. Add tests for externally visible behavior, compatibility, and edge cases.
5. Run the narrowest useful check, then the full suite before completion.
6. Review `git diff --check`, `git diff`, and `git status --short`.

Avoid opportunistic refactors, duplicated configuration, speculative
abstractions, and broad formatting churn.

## Testing

Run the full suite on Windows with:

```console
run-tests.cmd
```

Cross-platform equivalent:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release
```

Useful fast checks:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --check-object-scripts
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --check-global-ui
```

Use the focused runner during development:

```console
run-tests.cmd --file board_load_coordinator
run-tests.cmd --filter timeout --filter stale
run-tests.cmd --tag unit --exclude-tag generated
run-tests.cmd --fail-fast
run-tests.cmd --timing --slowest 10
run-tests.cmd --failed
```

`--file`, `--filter`, `--tag`, and `--exclude-tag` are repeatable. File/name
filters are case-insensitive; repeated values of one kind are alternatives,
while different filter kinds are intersected. Module tags are `unit`,
`integration`, `generated`, and `compatibility`. `--failed` uses the ignored
`tests/.last-failures` record from the previous run. See `run-tests.cmd --help`
and `TESTING.md` for the complete interface.

Tests use `Test.case("description", function() ... end)` and may add case tags
with an optional third argument such as `{"slow"}`. Prefer deterministic
plain-value assertions and the fakes in `tests/support/`. `Test.deepEqual`
reports the first mismatched value path. For every accepted asynchronous
operation, cover success, synchronous completion, delayed completion, failure,
timeout, duplicate callbacks, and stale callbacks when applicable.

Run the manual TTS smoke checklist in `TESTING.md` after changing physics,
colliders, hands, state replacement, remote assets, or other engine boundaries.
If it cannot be run locally, state that clearly in the handoff.

## Coding expectations

- Match neighboring Lua style and naming.
- Keep modules focused and dependencies explicit.
- Use plain tables/values across pure boundaries.
- Do not read rendered UI attributes back as domain state.
- Comments should explain constraints or intent, not restate code.
- Do not add dependencies unless the task truly requires one.
- Never weaken validation or delete tests merely to make the suite pass.

## Completion checklist

A change is complete when the requested behavior is implemented, relevant
tests are added or updated, generated assets are synchronized, the appropriate
automated checks pass, and the final report names any unrun manual checks or
remaining risks.

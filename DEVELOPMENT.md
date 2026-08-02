# Development guide

The runtime is organized around a small composition root (`src/Game.lua`),
constructible controllers, pure state/rule modules, and thin compatibility
facades. Existing Tabletop Simulator callbacks still call the facades, while
new tests and features should instantiate controllers with fake adapters.

The intended dependency direction is:

```text
Global callbacks -> GameController -> subsystem controllers
                                  -> pure state/rules/models
                                  -> views -> UiPatch -> UiAdapter
                                  -> Runtime/Scheduler/WebAdapter
```

Keep TTS objects, `Player`, `UI`, `Wait`, `WebRequest`, and global functions out
of pure modules. Controllers translate those APIs into plain values and apply
the resulting effects.

## Adding card-field logic

Field definitions are snapshotted by
`src/card_fields/CardFieldDefinitions.lua`, geometry is calculated by
`CardFieldLayout`, and persistent deck state lives in `CardFieldState`.
`CardFieldController` routes generic object events through
`ZoneBehaviorRegistry`.

To add a zone behavior:

1. Add its geometry/configuration to the field definition data.
2. Implement a behavior table with only the handlers it needs. Supported
   handlers include `onLoad`, `getSaveState`, `refresh`, `onObjectPickUp`,
   `onObjectDrop`, `onCardLeaves`, `onStackNavigationClicked`, and
   `onCardRotationChanged`.
3. Register it with `controller:registerZoneBehavior(zoneType, behavior)` or
   provide a prebuilt registry to `CardFields.new(dependencies)`.
4. Test pure state/layout transitions separately from controller effects.

Use stable `fieldId` and `ownerColor` values. Do not persist a layout color,
list index, or live TTS object as identity. A new zone using an existing object
event category should not require edits to `Game.lua` or `Global.lua`.

## Adding board logic or objects

Board state belongs to `HexBoardModel`; validation and import/export belong to
`HexBoardCodec`; occupancy and placement decisions belong to
`HexPlacementRules`; rendering belongs to `HexGridView`. `HexGridController`
owns the model and board codec configuration. Keep spawning, tags, correction
frames, buttons, and destruction in the TTS-facing layer.

For a new placement rule, change the pure rule/model first and add boundary
tests in `tests/test_hex_board_model.lua`. Add a TTS adapter/controller test
only when the rule needs a new side effect.

For a spawnable object:

1. Add its saved TTS JSON to `data/HexGridObjectTemplates.lua`.
2. Add one stable-key template to `src/hex/HexSpawnDefinitions.lua`, including
   whether it occupies its facing cell and any placement/button corrections.
3. Add one-cell/two-cell codec and placement fixtures as applicable.
4. Run the full suite and perform the placement portion of the TTS smoke test.

Board schema version and placed-object tag are owned by
`src/config/HexGridConfig.lua`; the aliases in `SettingsConfig` exist only for
older callers.

## Adding UI logic

UI state transitions belong in a model/controller. A view should return an
ordered array of `UiPatch` records, and only `UiAdapter` should apply those
records. Current examples are `TurnView`, `DeckSelectionMenuView`,
`HexGridMenuView`, `SettingsView`, and `DungeonMapView`.

For a new panel or action:

1. Define stable IDs and visual constants in the owning config module.
2. Add the state/action to the controller and keep authorization there.
3. Add a pure view/model test that snapshots the important patch order and
   values.
4. Bind the action to a thin `Global.lua` callback. For repeated Global UI
   controls, update the owning Lua definitions and run `--sync-global-ui`;
   never hand-edit rows inside a generated marker pair.
5. Run the suite; the runner rejects duplicate IDs, missing or misordered
   Global callbacks, generated XML drift, and definition/control mismatches.

Do not read UI attributes back as domain state. Store state in the controller
and render it outward.

## Adding individual-card logic

The external API is converted once by `CardApiNormalizer` into immutable
`CardDefinition` values. `data/CardDefinitions.lua` maps a stable API card ID
or name to `featureIds`; cards without an override receive
`defaultFeatureIds`.

A card feature is a descriptor like:

```lua
{
    id = "myFeature",          -- persisted; never rename casually
    stateVersion = 1,
    enabledByDefault = false,
    usesButtons = true,
    hostButtons = {
        {callback = "onMyCardClicked", configKey = "myButton"}
    },
    source = [[
registerCardFeature({
    id = "myFeature",
    stateVersion = 1,
    migrate = function(state, savedVersion) return state end,
    onLoad = function(state) end
})
]]
}
```

Register descriptors with `CardLogic.registerFeatureDescriptor`, then select
their IDs in `data/CardDefinitions.lua`. The generic runtime derives feature
dispatch, cleanup, buttons, and migrations from descriptors. Preserve an ID
once cards containing it may exist in a saved game. Missing feature versions
must be treated as legacy state, and unknown saved fields should be retained
when practical.

Add behavioral generated-script tests for every lifecycle callback the new
feature implements. Also test the feature alone and in every combination used
by card data; source substring assertions are not sufficient.

## Persistence and asynchronous work

`GameSaveCodec` owns the versioned root envelope and migrates legacy
unversioned saves. Subsystem codecs/controllers receive only normalized data.
Stable board IDs, object GUIDs, field IDs, card IDs, and feature IDs are save
contracts.

Saved-board ownership lives in `SavedBoardCatalog`. All Settings/Dungeon load
generations, accepted/completed ordering, duplicate callbacks, stale callbacks,
and timeouts go through the shared `BoardLoadCoordinator` created in
`src/Game.lua`. Do not add a second generation counter to either UI.

Use `FakeWait` for frames, time, conditions, and timeout tests. Every accepted
asynchronous operation needs success, synchronous completion, delayed
completion, failure, timeout, duplicate-callback, and stale-callback coverage.

## Compatibility facades

`CardFields`, `ActionZone`, `TurnSystem`, `DeckSelectionMenu`, `HexGridMenu`,
`DeckGenerator`, and `CardLogic` retain their established static APIs for TTS
and old generated cards. New code should use `.new(dependencies)` where offered.
Remove a facade only after no saved/generated script or Global callback can call
it.

See `TESTING.md` for automated commands, object-script synchronization, and the
manual TTS smoke checklist.

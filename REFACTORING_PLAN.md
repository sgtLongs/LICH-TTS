# LICH-TTS Refactoring Plan

## Implementation status

The automated portions of Slices 0-9 were implemented on 2026-08-02. Static
TTS callback facades remain for save/generated-script compatibility, while the
stateful internals described below now use constructible controllers, pure
rules/models, codecs, views, and runtime adapters. See `DEVELOPMENT.md` for the
resulting extension workflows and `TESTING.md` for the automated commands and
the remaining manual TTS smoke checklist.

Published object-local Lua and repeated Global UI XML are now deterministic
generated assets. Their canonical sources are `object_logic/` and the runtime
Lua definitions respectively; synchronization commands update the published
copies, and every normal test run fails on drift.

The manual in-application smoke test is intentionally not marked complete by
the repository-only implementation; it exercises Unity physics, colliders,
hands, state replacement, and remote asset timing that MoonSharp cannot model.

## Purpose

This plan restructures the project so card fields, board rules, UI behavior,
and individual cards can grow independently. The work is intentionally
incremental: preserve current Tabletop Simulator (TTS) behavior first, create
testable seams, and migrate one vertical slice at a time.

This is not a request for a big-bang rewrite. Every slice below must leave the
mod runnable, keep the existing public callbacks working, and pass automated
and TTS smoke tests before the next slice begins.

## Baseline architecture at the planning checkpoint

### Runtime flow

```text
TTS callbacks and Global XML
        |
        v
Global.lua                         thin callback adapter
        |
        v
src/Game.lua                       composition, routing, root save/load
        |
        +-- card_fields/CardFields.lua
        |      +-- CardFieldGeometry.lua
        |      +-- ActionZone.lua
        |      +-- DeckSelectionMenu.lua
        |             +-- DeckGenerator.lua
        |                    +-- cards/CardLogic.lua
        |      +-- turns/TurnSystem.lua
        |
        +-- hex/HexGrid.lua
        |      +-- HexGeometry.lua
        |      +-- HexBoardState.lua
        |      +-- HexGridBuilder.lua
        |      +-- HexGridMenu.lua
        |      +-- HexObjectSpawner.lua
        |      +-- HexSpawnDefinitions.lua
        |
        +-- SettingsMenu.lua <------ callbacks ------> dungeon/DungeonMap.lua
        |
        +-- turns/TurnSystem.lua
```

Tracked TTS assets add a second runtime surface:

- `.tts/objects/Global.xml` contains the global UI.
- `.tts/objects/*.lua` contains object-local behavior.
- `.tts/bundled/` is generated and ignored.
- `object_logic/` was empty at the checkpoint even though the test runner was
  prepared to compile scripts from it. It now contains the canonical sources
  and manifest described in the implementation status above.

### Evidence from the audit

At the audit checkpoint, `src/` contained about 7,745 lines of Lua. The largest
files also have the most mixed responsibilities:

| Module | Approx. lines | Responsibilities currently combined |
| --- | ---: | --- |
| `src/cards/CardLogic.lua` | 1,511 | TTS card utilities, script generation, feature registry, button UI, card actions, lifecycle, persistence |
| `src/hex/HexGrid.lua` | 1,295 | input, authorization, editor session, placement rules, object effects, rendering, load/save |
| `src/card_fields/ActionZone.lua` | 976 | stack state, reconciliation, layout, locks, movement, buttons, scheduling, persistence |
| `src/dungeon/DungeonMap.lua` | 867 | dungeon session, traversal, async loading, persistence, UI rendering |
| `src/SettingsMenu.lua` | 815 | saved-board repository, migration, board loading, admin rules, pagination, UI rendering |

The global XML is also a maintenance hotspot. At audit time,
`.tts/objects/Global.xml` had about 1,873 lines, 115 IDs, and 109 click
bindings. Deck choices, nine spawn choices, and 37 dungeon tiles are repeated
manually even though Lua configuration already describes the same concepts.

The architecture already has useful seams that should be preserved:

- `Global.lua` is a thin TTS adapter.
- `Game.onLoad` is recognizable as a composition root.
- `TurnState`, `DungeonMapState`, `HexBoardState`, `HexGeometry`, and
  `CardFieldGeometry` demonstrate the desired pure-module style.
- Cross-platform MoonSharp tests and CI already exist.
- Settings and DungeonMap use injected callbacks for some collaboration,
  showing that dependency inversion works in this environment.

## Main structural risks

### Module-global mutable state

Most controllers are singletons with mutable locals. For example, `HexGrid`
holds board, cells, selections, hover state, menu state, pending placement,
placed objects, and edit state at module scope. `ActionZone` similarly holds
several maps keyed by card and field. This makes isolation, retries, reloads,
and parallel tests difficult.

Target: state belongs to an explicit controller instance or a plain state
value. Pure rule modules receive state as an argument.

### Rules mixed with TTS effects

Rules call `UI`, `Wait`, `Player`, object methods, `WebRequest`, spawn APIs,
and global lookup functions directly. A rule change therefore requires large
TTS mocks, and asynchronous engine timing can hide rule regressions.

Target: rules return state changes and effect descriptions. A small controller
executes effects through injected TTS adapters.

### String-coupled callbacks and generated scripts

Card buttons, action-zone buttons, Global callbacks, XML, and generated card
scripts communicate through callback-name strings. `CardLogic` repeats the
same action mapping in button cleanup, runtime configuration, button refresh,
and feature source. Adding one card action can require edits in several distant
blocks.

Target: one feature or action descriptor owns its ID, callbacks, buttons,
state schema, and handlers. Builders derive all repeated mappings from those
descriptors.

### Logical subsystem cycles

`SettingsMenu` owns saved boards and calls DungeonMap when loads start or end.
DungeonMap calls back into Settings to enumerate and load saved boards. Both
also implement load-generation and asynchronous-completion bookkeeping.

Target: a standalone `SavedBoardCatalog` owns saved-board data, and one
`BoardLoadCoordinator` owns load generations and completion semantics.
Settings and DungeonMap consume those services independently.

### Generated and source asset drift

At the planning checkpoint, Global XML duplicated configuration and several
tracked object scripts contained near-identical cabinet/storage behavior. The
test foundation compiled the tracked `.tts/objects` scripts and checked JSON,
XML callbacks/counts, and `Global.lua` parity, but those scripts were still the
duplicated source rather than reproducible outputs from `object_logic/`.

Target: one canonical source per object behavior and one deterministic UI
generation path. Generated artifacts must be reproducible and checked by CI.

### Persistence compatibility

Board import, Settings, and DungeonMap have schema versions, but the root game
save, CardFields/ActionZone state, Turn state, and generated card state do not
have an explicit migration boundary. Generated card scripts can also remain
inside saved decks long after Global code changes.

Target: every persisted boundary has a codec, version, migration tests, and a
documented compatibility window.

## Behavior compatibility envelope

The first refactor pass must preserve these observed behaviors. A desired rule
change should be proposed and tested separately from structural work.

### Card fields and deck generation

- Six configured fields retain their current 7-by-3 geometry, rotations,
  surfaces, and current `ownerColor` mapping.
- A field is authorized using `ownerColor` when present, not the configured
  `playerColor` label.
- Only one deck button for this mod remains on a surface after refresh.
- A used deck button disappears; renewing it clears the saved spawned flag.
- The deck spawn position mirrors the cabinet button X coordinate around the
  field center.
- A player becomes active only through the current successful deck-spawn
  callback path.
- API card quantity, front/back images, title/type encoding, card scale, deck
  rotation, and Hero extraction remain compatible.
- HTTP, decode, validation, spawn, Hero timeout, and Hero extraction failures
  release the per-field generation mutex.

### Action zone

- The first five row entries use the five printed slots; overflow entries are
  redistributed evenly across the same usable width.
- Drops close enough to another action card join its ordered stack.
- Removing or moving a card compacts the remaining row.
- Covered cards are locked to prevent TTS deck merging, and original lock
  values are restored when management ends.
- Only the first card in a stack owns the large tap target under current rules.
- The selected stack card is lifted without changing stable stack order or
  per-card fan position.
- Navigation buttons follow the selected card and counter-rotate with a tapped
  card.
- Stack order, selected index, and managed original locks survive the current
  save/load format.

### Hex board and saved boards

- Existing axial geometry, hit testing, adjacency, facing, and placement
  offsets remain unchanged.
- Only admins may use edit-mode placement and deletion.
- One-cell and facing-cell occupancy rules remain template-driven.
- Board and placed-object clicks share current selection/edit behavior.
- Existing object GUIDs are reused on load when present; missing objects are
  respawned.
- Board-state validation occurs before the live board is cleared.
- Accepted loads currently clear old placed objects before all replacement
  spawns finish, and completion can report partial failure. Preserve this
  behavior until the transactional-load decision below is made.
- Saved board IDs, names, selected board, edit mode, legacy imports, and
  DungeonMap assignments remain readable.

### UI and turns

- Existing XML IDs and Global callback names remain valid throughout migration.
- Menu visibility remains scoped to the player who opened it.
- Admin-only controls and actions remain protected in the controller, not only
  visually disabled.
- Current labels, pagination behavior, selection colors, status messages, and
  phase order remain stable unless explicitly approved.
- Active players continue to be derived from successful field deck spawns.

### Individual cards

- Cards in a hand have no scripted buttons, including during delayed deck and
  hand-zone updates.
- Standalone cards retain tap-to-rotate state and exact 90-degree rotation.
- Hover actions retain destroy-to-purgatory, damn-to-abyss, unequip-to-bottom,
  and return-to-hand behavior.
- Returning to hand continues to use bottom insertion/deal through the original
  deck when possible, with the current reload fallback when the deck is absent.
- Existing `LuaScriptState` feature data remains readable.
- Old generated cards can continue calling the current Global compatibility
  callbacks after new card code is deployed.

## Target module boundaries

Use feature-oriented folders with a small set of consistent roles rather than
a framework-heavy hierarchy.

```text
src/
  Game.lua                         composition root and compatibility facade
  tts/
    Runtime.lua                    object/player/global lookup ports
    Scheduler.lua                  Wait adapter
    UiAdapter.lua                  applies UI patches
    ObjectAdapter.lua              spawn/move/lock/button effects
    WebAdapter.lua                 WebRequest boundary

  card_fields/
    CardFieldDefinitions.lua       immutable field and zone definitions
    CardFieldLayout.lua            pure field/cell/zone geometry
    CardFieldState.lua             deck-spawn and field persistence
    CardFieldController.lua        event routing and TTS effects
    zones/
      ZoneBehaviorRegistry.lua
      ActionZoneState.lua          pure stacks and serialization
      ActionZoneRules.lua          pure event transitions
      ActionZoneLayout.lua         pure positions and drop targeting
      ActionZoneController.lua     buttons, movement, locks

  boards/
    SavedBoardCatalog.lua          IDs, names, selection, migration
    BoardLoadCoordinator.lua       one load generation/completion protocol
  hex/
    HexGeometry.lua                existing pure geometry
    HexBoardCodec.lua              validation, serialization, migration
    HexBoardState.lua              selected cells and placements
    HexPlacementRules.lua          occupancy and editor commands
    HexGridController.lua          input and TTS effects
    HexGridView.lua                view model/UI/vector-line patches
    HexObjectSpawner.lua           TTS spawn adapter
  dungeon/
    DungeonMapState.lua            existing pure persisted state
    DungeonMapRules.lua            assignment/traversal transitions
    DungeonMapController.lua       commands and board-load requests
    DungeonMapView.lua             UI patches

  cards/
    CardDefinition.lua             canonical per-card metadata
    CardApiNormalizer.lua          external response -> definitions
    CardFeatureRegistry.lua        validates unique features
    CardScriptBuilder.lua          composes one standalone script
    CardRuntimeSource.lua          generic lifecycle dispatcher
    CardHostService.lua            hand/deck/field services in Global
    features/
      Rotate90.lua
      FieldActions.lua
      <future-feature>.lua

  settings/
    SettingsController.lua
    SettingsView.lua
  ui/
    UiPatch.lua                    optional shared patch helpers only

data/
  CardDefinitions.lua              individual-card feature assignments
  HexGridObjectTemplates.lua

object_logic/
  CabinetStorage.lua               canonical object-local source
  Board.lua
```

Names may be adjusted during extraction, but the dependency direction is not
optional:

```text
configuration/data
      -> pure state, codecs, rules, and layout
      -> controllers/application services
      -> injected TTS adapters
```

Rules must not require `UI`, `Player`, `Wait`, Global, Settings controllers, or
another feature's controller. Cross-feature work goes through a narrow port or
domain event supplied by `Game`.

### Controller shape

Controllers should be constructible and own explicit state:

```lua
local controller = CardFieldController.new({
    runtime = runtime,
    deckMenu = deckMenu,
    zoneBehaviors = zoneBehaviors,
    onDeckSpawned = function(ownerColor)
        turnSystem.activatePlayer(ownerColor)
    end
})
```

Current modules can temporarily expose the old static functions by delegating
to a default instance. This allows callers and tests to migrate independently.

### Rule result and effect shape

Pure rules should return the next state and explicit effects:

```lua
local nextState, effects = ActionZoneRules.drop(state, event, layout)

-- Example effects:
-- {type = "moveCard", cardId = "abc123", position = {...}}
-- {type = "setLock", cardId = "abc123", locked = true}
-- {type = "setTapEnabled", cardId = "abc123", enabled = false}
```

The effect vocabulary should stay feature-specific until multiple features
genuinely share an operation. Do not build a generic event framework first.

### Zone behavior contract

`CardFields` should not know about Action-zone internals. A zone behavior owns
its state, transitions, serialization, and controller effects:

```lua
registry.register("action", {
    createState = ActionZoneState.new,
    load = ActionZoneState.load,
    save = ActionZoneState.save,
    contains = ActionZoneLayout.contains,
    handle = ActionZoneRules.handle,
    applyEffects = actionZoneController.applyEffects
})
```

Adding a future field zone then requires a definition, one behavior module, and
tests rather than edits across `CardFields`, `Game`, and `Global.lua`.

### Card feature contract

Each feature should declare one stable ID and own its state and UI descriptors:

```lua
return {
    id = "rotate90",
    stateVersion = 1,
    buttons = {...},
    migrate = function(savedState) ... end,
    onLoad = function(context, state) ... end,
    onTap = function(context, state, event) ... end
}
```

The first migration may still compile self-contained object scripts because
that matches current TTS persistence. Split the bootstrap, lifecycle, and each
feature into independently testable source modules before deciding whether to
replace them with a thin object-to-Global bridge.

## Ordered migration slices

Each slice should be a reviewable change that preserves the public facade and
contains its own tests.

### Slice 0: Record the compatibility baseline

1. Run the complete suite with:

   ```console
   dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release
   ```

2. Store representative fixtures for:

   - an unversioned current root game save;
   - Settings schema 1 and 2 states;
   - board-state schema 1 with every placement type;
   - DungeonMap schema 1;
   - ActionZone stacks, selection, and original locks;
   - generated card feature state;
   - valid, partial, and malformed deck API responses.

3. Add a short manual TTS smoke script covering load, save/reload, deck spawn,
   Hero extraction, hand draw, card actions, stack navigation, board edit,
   board save/load, and dungeon traversal.

Gate: all fixtures round-trip through current code, every current automated
test passes, and the smoke script passes in TTS.

### Slice 1: Improve the test and TTS boundary

1. Add reusable fakes for UI attributes, controlled frames/time/conditions,
   players and hands, object registry, buttons, locks, spawning, WebRequest,
   and chat.
2. Guarantee global restoration even when a test assertion fails.
3. Add deep-table, error, and call-history assertions to `tests/support/Test`.
4. Execute generated card scripts behaviorally in MoonSharp; compilation and
   source-substring checks alone are insufficient.
5. Add XML contracts: every configured ID exists, every XML callback resolves
   to a Global callback, and repeated item counts match their definitions.
6. Compile canonical object scripts in CI.

Gate: no production refactor yet; the enlarged suite is green and can control
asynchronous completion deterministically.

Status when this plan was written: behavioral generated-card execution, tracked
object-script compilation, and the XML/JSON/callback/parity checks are now in
place. Reusable fakes, automatic suite-wide isolation, and richer shared
assertions remain work for this slice.

### Slice 2: Introduce injected runtime adapters

1. Wrap raw `UI`, `Wait`, `Player`, object lookup/spawn/destruction,
   `WebRequest`, and broadcasts behind small adapters.
2. Let one low-risk controller accept those adapters through `.new(deps)`.
3. Retain its existing static API as a facade over a default instance.
4. Repeat mechanically for controllers as they are touched; do not convert
   every module in one commit.

Gate: identical public return values and adapter call traces before and after
each conversion. No rule changes in this slice.

### Slice 3: Extract ActionZone state and layout

1. Move stack add/remove/select/reconcile and save/load normalization to
   `ActionZoneState` and `ActionZoneRules`.
2. Move contains, snap positions, fan offsets, selected lift, and drop-target
   scoring to `ActionZoneLayout`.
3. Keep current `ActionZone` as the controller that translates object data to
   plain events and executes movement, lock, tap, and button effects.
4. Replace module-global maps with controller-owned state.

Required tests include save/load round trips, duplicate and missing GUIDs,
cross-field movement, exact drop thresholds, six field orientations, more than
five entries, stack insertion at every selected depth, removal at every depth,
original-lock restoration, stale callbacks, and rotation/button behavior.

Gate: golden ActionZone state is unchanged and real TTS cards still do not
merge unexpectedly.

### Slice 4: Make card fields behavior-driven

1. Separate immutable field definitions, calculated layout, and persisted
   field state.
2. Introduce `ZoneBehaviorRegistry`; register the extracted Action behavior.
3. Route pickup/drop/leave/rotation events generically to matching zones.
4. Remove the direct CardFields-to-TurnSystem require. Inject an
   `onDeckSpawned(ownerColor)` callback from `Game`.
5. Rename ambiguous identities in new code, for example `layoutColor` or
   `fieldId` versus `ownerColor`, while codecs continue accepting current
   names.

Gate: all existing `CardFields` facade calls and save data remain compatible.
Adding a no-op test zone requires no `Game` or `Global.lua` edit.

### Slice 5: Extract saved-board ownership and load coordination

1. Move board ID allocation, name normalization, selection, pagination inputs,
   schema migration, and CRUD into `SavedBoardCatalog`.
2. Move generation IDs, accepted/completed ordering, stale callback handling,
   timeouts, and completion reporting into `BoardLoadCoordinator`.
3. Inject both into Settings and Dungeon controllers.
4. Keep old Settings/Dungeon callback functions as adapters during migration.

Gate: Settings schema 1 and 2 and DungeonMap schema 1 fixtures load without
loss. Synchronous, delayed, failed, timed-out, duplicated, and stale completion
orders are covered.

### Slice 6: Extract the hex-board model

1. Consolidate selected cells and placements into an explicit `HexBoardState`.
2. Extract occupancy indexing, selection, begin/cancel/complete placement,
   replacement, and deletion into pure commands.
3. Keep spawning, placement corrections, object tags, buttons, and destruction
   in the controller/adapters.
4. Move board schema and placed-object tag out of `SettingsConfig`.
5. Split editor/session state from persisted board state.
6. Split vector/button rendering into `HexGridView` or focused renderers.

Gate: import/export and root-save fixtures are byte-equivalent where ordering
is significant and structurally equivalent otherwise. One-cell and two-cell
templates, existing-GUID restore, missing-object respawn, replacement failure,
partial load, and object destruction are covered.

### Slice 7: Normalize cards and split the generated runtime

1. Convert external API data once in `CardApiNormalizer`; retain current field
   aliases such as `frontImageURL`, `backImageUrl`, metadata `name`, and
   fallback `nickname`/`index` behavior.
2. Introduce canonical `CardDefinition` values with stable identity, name,
   description, types, images, quantity, and selected feature IDs.
3. Move bootstrap and lifecycle source out of `CardLogic`.
4. Move `rotate90` and field actions into separate feature modules.
5. Derive cleanup lists, buttons, runtime config, and dispatch from registered
   feature descriptors instead of hard-coded callback lists.
6. Add `data/CardDefinitions.lua` entries for card-specific feature selection;
   preserve current default features for cards without an entry.
7. Resolve mutable field destinations through a stable field identity at action
   time where possible. Continue embedding coordinates as a compatibility
   fallback for old Global code and saved cards.

Gate: execute generated scripts for load/save, hand entry/exit, tap, hover,
destroy, damn, unequip, return, disabled tap, feature isolation, unknown
features, and state migration. Existing generated cards must continue to call
Global successfully.

### Slice 8: Separate models, controllers, and views

1. Extract pure view-model builders from Settings, DungeonMap, TurnSystem,
   DeckSelectionMenu, and HexGridMenu.
2. Have views return `UiPatch` values rather than call `UI` directly.
3. Apply patches through `UiAdapter`.
4. Replace long action conditionals with feature-local route tables only after
   behavior tests cover every action.
5. Generate repeated XML controls from the same card, spawn, dungeon, and
   phase definitions used by Lua. Check in generated XML if required by the
   TTS workflow, but make regeneration deterministic.

Gate: UI patch snapshots and XML contracts pass, permissions are enforced in
controllers, and a visual TTS smoke comparison shows no layout or visibility
regression.

### Slice 9: Consolidate object scripts and remove temporary facades

1. Select canonical object-script sources under `object_logic/`.
2. Parameterize true cabinet differences rather than copy whole scripts.
3. Generate or sync `.tts/objects` from canonical source and fail CI on drift.
4. Remove old static facades only after all consumers use constructed
   controllers.
5. Update `TESTING.md` and add extension recipes.

Gate: a clean generation produces no diff, all tracked scripts compile in the
appropriate TTS Lua dialect, old object `script_state` loads, and the full TTS
smoke script passes.

## Test gates for every slice

Every migration pull request should meet all applicable gates:

1. **Pure rules:** table-driven boundary and transition tests, with no TTS
   globals.
2. **Codec compatibility:** old fixture -> migrate -> current state -> save ->
   reload, with unknown or malformed data handled deliberately.
3. **Controller contract:** fake-runtime call traces assert authorization,
   ordering, exactly-once callbacks, failure cleanup, and return values.
4. **Generated script:** compile every feature combination used by card data
   and behaviorally execute representative combinations.
5. **UI/XML contract:** configured IDs and callbacks exist and generated XML is
   current.
6. **Full suite:** no focused-only runs accepted as the final gate.
7. **TTS smoke:** required for physics, collider, hand sizing, object reload,
   state switching, smooth movement, and asynchronous asset loading changes.

Do not use a coverage percentage as the only gate. Branch and state-transition
coverage matters more here, especially for asynchronous completion and failure
recovery.

## Save compatibility plan

### Root save envelope

Introduce a codec without immediately changing subsystem payloads:

```lua
{
    schemaVersion = 1,
    cardFields = ...,
    dungeonMap = ...,
    hexGrid = ...,
    settings = ...,
    turnSystem = ...
}
```

Treat the current unversioned root table as version 0. `GameSaveCodec.load`
must migrate version 0 to the current in-memory shape. Add the version field
only after version-0 fixtures pass.

### Subsystem rules

- Codecs accept old and current shapes; controllers only receive normalized
  state.
- Write one current shape after migration rather than maintaining two writers.
- Never use UI list indexes as persisted identities. Preserve board IDs, object
  GUIDs, and stable field/card IDs.
- Increment a schema only when the persisted meaning changes, not when files
  move.
- Preserve unknown data when feasible if forward/backward mod use is expected;
  otherwise reject it with a tested, visible fallback.
- Any migration that discards invalid entries must report or log what was
  discarded.

### Generated card compatibility

Old cards and decks may contain old Lua source indefinitely. Keep these Global
entry points as compatibility APIs until an explicit old-card retirement plan
exists:

- `getCardButtonConfig`
- `onCardLeavesActionZone`
- `onActionZoneCardRotationChanged`
- `returnCardToHandThroughDeck`
- action-stack click callbacks

Feature state needs `stateVersion` per feature. Missing versions mean the
current legacy state. Test legacy scripts against new Global code and new
scripts against compatibility fallbacks.

## External deck API compatibility

Keep network concerns at one boundary:

1. `WebAdapter` performs the request and reports transport success/failure.
2. `CardApiNormalizer` validates and normalizes response data.
3. `DeckFactory` creates TTS data from canonical definitions.
4. `DeckGenerator` coordinates one generation attempt per field.

The normalizer must preserve current accepted inputs:

- `backImageUrl` is required and non-empty;
- `cards` must contain at least one spawnable entry;
- quantity is numeric, floored, and positive;
- `frontImageURL` is required for a spawnable card;
- `types` may be missing or empty;
- container metadata may expose `name` or legacy `nickname`;
- Hero extraction may use GUID or index metadata.

Do not change the endpoint, `lootId` query, image semantics, title encoding, or
invalid-entry filtering during structural extraction. Add new API versions
behind a new adapter with contract fixtures.

## Extension end states

### Adding card-field logic

After Slices 3 and 4, adding a zone should require:

1. a zone definition in field data;
2. one registered zone behavior;
3. pure rules/layout tests and controller-effect tests.

It should not require a new Global event unless TTS itself introduces a truly
new callback category.

### Adding board logic

After Slice 6, adding a placement rule or board command should require:

1. a pure command/rule change;
2. tests for resulting state/effects;
3. an adapter change only if a new TTS effect is needed.

Adding a spawnable object should remain primarily data-driven through one
template plus occupancy/placement fixtures.

### Adding UI logic

After Slice 8, adding a panel or action should require:

1. controller state/action handling;
2. a view-model/UI-patch builder;
3. generated XML/component data;
4. route, permission, patch snapshot, and XML contract tests.

Domain rules should not know an XML ID.

### Adding individual-card logic

After Slice 7, adding a card with existing mechanics should require only a
`CardDefinition` entry selecting feature IDs. Adding a new mechanic should
require one feature module, one registry entry, and feature/runtime tests. It
should not require editing the generic lifecycle or several button-name lists.

## Decisions required before changing suspected behavior

The audit found behaviors that may be intentional workarounds. Preserve them
until the relevant decision is made explicitly.

| Question | Current behavior/default for refactor | Decide before |
| --- | --- | --- |
| What does `field.playerColor` mean when `ownerColor` differs? | Authorization, save flags, and turn activation use `ownerColor`; display/log text sometimes uses `playerColor`. Preserve both. | Slice 4 naming and new field data |
| When is deck generation considered successful? | The field button is consumed and the player activated when the deck object spawns, before Hero extraction completes. | Any gameplay change to spawn success |
| What happens to a one-card response containing the Hero? | Single-card data is emitted as `CardCustom`, while Hero extraction expects container metadata and can time out. Preserve until specified. | Card/API redesign |
| Should board loading be transactional? | Old objects are destroyed after validation but before all new spawns succeed; partial failure does not roll back. | Slice 6 behavior follow-up |
| Should selected hexes persist when loading a board? | They are replaced by the loaded normalized selection. | Board rule changes |
| Should lower selected action-stack cards receive tap behavior? | Only stack index 1 owns the tap target, even when another card is selected/lifted. | ActionZone gameplay changes |
| Are physical card positions authoritative after save load? | Saved stack GUIDs are reconciled against cards physically inside the zone; missing/outside cards are dropped. | ActionZone codec changes |
| May fields move after decks are generated? | Card scripts embed destination coordinates at generation time, so existing cards do not follow later layout movement. | Slice 7 identity design |
| May non-admin players renew their own deck button? | Yes, Settings exposes owner renewal independently of board-admin actions. | UI permission changes |
| Is current turn phase order intentional? | `start`, `main`, `draw`, `status`, `end`. Preserve. | Turn-rule additions |
| Are cabinet/storage scripts source or imported asset code? | Several tracked copies differ slightly and use TTS-dialect syntax. Treat them as behavior to preserve. | Slice 9 consolidation |
| Should all cards receive both current default features? | Yes; `data/Cards.lua` is empty and `CardLogic` defaults every generated card to both registered defaults. | Individual-card definitions |

Record decisions as tests and, when they change gameplay, ship them separately
from the extraction that exposes the decision.

## Explicitly out of scope for this refactor

- New card mechanics, card balance, field shapes, board templates, or turn
  rules.
- Visual redesign of menus, colors, text, card button placement, or board art.
- Changing the deck API endpoint or requiring a new server response schema.
- Transactional board loading unless approved as a separate behavior change.
- Replacing MoonSharp, TTS, or the current .NET test host.
- A generic dependency-injection, event-bus, UI, or entity-component framework.
- Performance optimization without a measured TTS problem.
- Deleting compatibility callbacks or old-save migration code during the first
  extraction pass.
- Reformatting or regenerating unrelated TTS object assets in structural
  commits.

## Completion criteria

The refactor is complete when:

- TTS globals occur only in entry points, generated object bootstrap code, and
  adapters.
- Stateful controllers are constructible and independently testable.
- Rules, state transitions, codecs, layout, and view models run without TTS.
- Card fields dispatch behavior through a zone registry.
- Board state and commands are separate from spawning and rendering.
- Settings and DungeonMap share a saved-board catalog and one load coordinator.
- Card features own their state, buttons, handlers, and migration metadata.
- Individual cards select features through data rather than edits to the
  generic runtime.
- Repeated XML and object scripts have canonical, reproducible sources.
- Current and legacy save/API fixtures pass.
- The complete automated suite and the documented TTS smoke script pass.
- `TESTING.md` explains the test layers, and extension recipes explain how to
  add a field zone, board rule/object, UI action, and card feature.

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

# Object scripts

Files in this directory are the canonical sources for object-local Tabletop
Simulator scripts. `ObjectScriptManifest.json` maps each source to the tracked
Lua sidecar and embedded `.data.json` `LuaScript` copies under `.tts/objects`;
one source may intentionally feed several objects.

Do not edit a mapped `.tts/objects/*.lua` file directly. Update its canonical
source and synchronize the tracked assets:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --sync-object-scripts
```

To check mappings and compile canonical and generated scripts without running
the Lua test cases:

```console
dotnet run --project tests/runner/LichTts.TestRunner.csproj --configuration Release -- --check-object-scripts
```

The normal test command performs the same drift check and fails if a tracked
object script is missing from the manifest, has no canonical source, or if its
sidecar or embedded data script differs from that source.

When adding an object-local script:

1. Add or reuse a narrowly scoped canonical file here.
2. Add the tracked target to `ObjectScriptManifest.json`.
3. Run the synchronization command.
4. Run the full test suite.

`CabinetStorage.lua` deliberately retains the existing `script_state` format,
including the saved per-object lock-state table. Its mapped copies differ only
by object identity; no object GUID or state data is generated into the script.

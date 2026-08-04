using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml.Linq;

static string FindRepositoryRoot()
{
    var directory = new DirectoryInfo(Directory.GetCurrentDirectory());

    while (directory is not null)
    {
        if (File.Exists(Path.Combine(directory.FullName, "Global.lua")))
        {
            return directory.FullName;
        }

        directory = directory.Parent;
    }

    throw new InvalidOperationException(
        "Could not find the repository root containing Global.lua.");
}

static string NormalizeLineEndings(string value) =>
    value.Replace("\r\n", "\n", StringComparison.Ordinal)
        .Replace('\r', '\n');

static void RequireCount(string description, int actual, int expected)
{
    if (actual != expected)
    {
        throw new InvalidOperationException(
            $"Expected {expected} {description}, found {actual}.");
    }
}

static int EvaluateLuaCount(
    Script script,
    string source,
    string description)
{
    var value = script.DoString(source);

    if (value.Type != DataType.Number
        || value.Number < 0
        || value.Number != Math.Floor(value.Number))
    {
        throw new InvalidOperationException(
            $"Lua UI definition '{description}' did not return a count.");
    }

    return checked((int)value.Number);
}

static IReadOnlyList<string> EvaluateLuaStrings(
    Script script,
    string source,
    string description)
{
    var value = script.DoString(source);

    if (value.Type != DataType.Table)
    {
        throw new InvalidOperationException(
            $"Lua definition '{description}' did not return a list.");
    }

    var result = new List<string>();

    for (var index = 1; index <= value.Table.Length; index++)
    {
        var item = value.Table.Get(index);

        if (item.Type != DataType.String
            || string.IsNullOrEmpty(item.String))
        {
            throw new InvalidOperationException(
                $"Lua definition '{description}' contains a non-string "
                + $"value at position {index}.");
        }

        result.Add(item.String);
    }

    return result;
}

static void RequireExactSequence(
    string description,
    IReadOnlyList<string> actual,
    IReadOnlyList<string> expected)
{
    if (actual.Count != expected.Count)
    {
        throw new InvalidOperationException(
            $"Expected {expected.Count} {description}, found {actual.Count}. "
            + $"Expected [{string.Join(", ", expected)}]; "
            + $"found [{string.Join(", ", actual)}].");
    }

    for (var index = 0; index < expected.Count; index++)
    {
        if (!string.Equals(actual[index], expected[index],
            StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"Unexpected {description} at position {index + 1}: "
                + $"expected '{expected[index]}', found '{actual[index]}'. "
                + $"Expected [{string.Join(", ", expected)}]; "
                + $"found [{string.Join(", ", actual)}].");
        }
    }
}

static IReadOnlyList<string> ExtractCallbackArguments(
    IEnumerable<string> callbackValues,
    string callbackName,
    string argumentPattern)
{
    var pattern = new Regex(
        $"^{Regex.Escape(callbackName)}\\(({argumentPattern})\\)$");

    return callbackValues
        .Select(value => pattern.Match(value))
        .Where(match => match.Success)
        .Select(match => match.Groups[1].Value)
        .ToArray();
}

static IReadOnlyList<string> SequentialStrings(int count) =>
    Enumerable.Range(1, count)
        .Select(index => index.ToString())
        .ToArray();

static void RequireUiIds(
    string description,
    IReadOnlySet<string> actualIds,
    IReadOnlyList<string> expectedIds)
{
    var duplicateExpectedIds = expectedIds
        .GroupBy(id => id, StringComparer.Ordinal)
        .Where(group => group.Count() > 1)
        .Select(group => group.Key)
        .OrderBy(id => id, StringComparer.Ordinal)
        .ToArray();

    if (duplicateExpectedIds.Length > 0)
    {
        throw new InvalidOperationException(
            $"{description} derives duplicate UI IDs: "
            + string.Join(", ", duplicateExpectedIds));
    }

    var missingIds = expectedIds
        .Where(id => !actualIds.Contains(id))
        .OrderBy(id => id, StringComparer.Ordinal)
        .ToArray();

    if (missingIds.Length > 0)
    {
        throw new InvalidOperationException(
            $"Global.xml is missing {description} UI IDs: "
            + string.Join(", ", missingIds));
    }
}

static StringComparer FilePathComparer() =>
    OperatingSystem.IsWindows()
        ? StringComparer.OrdinalIgnoreCase
        : StringComparer.Ordinal;

static string ResolveManifestPath(
    string repositoryRoot,
    string allowedRoot,
    string relativePath,
    string description)
{
    if (string.IsNullOrWhiteSpace(relativePath)
        || Path.IsPathRooted(relativePath))
    {
        throw new InvalidOperationException(
            $"Object-script {description} must be a repository-relative path.");
    }

    var platformPath = relativePath.Replace(
        '/',
        Path.DirectorySeparatorChar);
    var resolvedPath = Path.GetFullPath(
        Path.Combine(repositoryRoot, platformPath));
    var relativeToAllowedRoot = Path.GetRelativePath(
        allowedRoot,
        resolvedPath);

    if (Path.IsPathRooted(relativeToAllowedRoot)
        || relativeToAllowedRoot == ".."
        || relativeToAllowedRoot.StartsWith(
            $"..{Path.DirectorySeparatorChar}",
            StringComparison.Ordinal))
    {
        throw new InvalidOperationException(
            $"Object-script {description} '{relativePath}' is outside "
            + $"'{Path.GetRelativePath(repositoryRoot, allowedRoot)}'.");
    }

    return resolvedPath;
}

static IReadOnlyList<(string SourcePath, string TargetPath)>
    LoadObjectScriptMappings(
        string repositoryRoot,
        bool allowMissingTargets = false)
{
    var canonicalRoot = Path.Combine(repositoryRoot, "object_logic");
    var objectRoot = Path.Combine(repositoryRoot, ".tts", "objects");
    var manifestPath = Path.Combine(
        canonicalRoot,
        "ObjectScriptManifest.json");

    if (!File.Exists(manifestPath))
    {
        throw new InvalidOperationException(
            "The canonical object-script manifest is missing at "
            + "object_logic/ObjectScriptManifest.json.");
    }

    using var document = JsonDocument.Parse(File.ReadAllText(manifestPath));
    var manifest = document.RootElement;

    if (manifest.ValueKind != JsonValueKind.Object
        || !manifest.TryGetProperty("schemaVersion", out var schemaVersion)
        || schemaVersion.ValueKind != JsonValueKind.Number
        || schemaVersion.GetInt32() != 1)
    {
        throw new InvalidOperationException(
            "ObjectScriptManifest.json must use schemaVersion 1.");
    }

    if (!manifest.TryGetProperty("mappings", out var mappingElements)
        || mappingElements.ValueKind != JsonValueKind.Array)
    {
        throw new InvalidOperationException(
            "ObjectScriptManifest.json must contain a mappings array.");
    }

    var comparer = FilePathComparer();
    var targets = new HashSet<string>(comparer);
    var mappings = new List<(string SourcePath, string TargetPath)>();

    foreach (var mappingElement in mappingElements.EnumerateArray())
    {
        if (mappingElement.ValueKind != JsonValueKind.Object
            || !mappingElement.TryGetProperty("source", out var sourceElement)
            || sourceElement.ValueKind != JsonValueKind.String
            || !mappingElement.TryGetProperty("targets", out var targetElements)
            || targetElements.ValueKind != JsonValueKind.Array)
        {
            throw new InvalidOperationException(
                "Each object-script mapping needs a source and targets array.");
        }

        var sourceRelativePath = sourceElement.GetString()!;
        var sourcePath = ResolveManifestPath(
            repositoryRoot,
            canonicalRoot,
            sourceRelativePath,
            "source");

        if (!sourcePath.EndsWith(".lua", StringComparison.OrdinalIgnoreCase)
            || !File.Exists(sourcePath))
        {
            throw new InvalidOperationException(
                $"Canonical object script '{sourceRelativePath}' is missing "
                + "or is not a Lua file.");
        }

        var targetCount = 0;

        foreach (var targetElement in targetElements.EnumerateArray())
        {
            if (targetElement.ValueKind != JsonValueKind.String)
            {
                throw new InvalidOperationException(
                    $"Targets for '{sourceRelativePath}' must be paths.");
            }

            var targetRelativePath = targetElement.GetString()!;
            var targetPath = ResolveManifestPath(
                repositoryRoot,
                objectRoot,
                targetRelativePath,
                "target");

            if (!targetPath.EndsWith(".lua", StringComparison.OrdinalIgnoreCase)
                || !comparer.Equals(
                    Path.GetDirectoryName(targetPath),
                    objectRoot)
                || comparer.Equals(
                    Path.GetFileName(targetPath),
                    "Global.lua"))
            {
                throw new InvalidOperationException(
                    $"Object-script target '{targetRelativePath}' must be a "
                    + "non-Global Lua file directly under .tts/objects.");
            }

            if (!targets.Add(targetPath))
            {
                throw new InvalidOperationException(
                    $"Object-script target '{targetRelativePath}' is mapped "
                    + "more than once.");
            }

            mappings.Add((sourcePath, targetPath));
            targetCount++;
        }

        if (targetCount == 0)
        {
            throw new InvalidOperationException(
                $"Canonical object script '{sourceRelativePath}' has no targets.");
        }
    }

    var trackedTargets = Directory
        .EnumerateFiles(objectRoot, "*.lua", SearchOption.TopDirectoryOnly)
        .Where(path => !comparer.Equals(Path.GetFileName(path), "Global.lua"))
        .Select(Path.GetFullPath)
        .ToHashSet(comparer);
    var unmappedTargets = trackedTargets
        .Except(targets, comparer)
        .Select(path => Path.GetRelativePath(repositoryRoot, path))
        .OrderBy(path => path, StringComparer.Ordinal)
        .ToArray();
    var missingTargets = targets
        .Except(trackedTargets, comparer)
        .Select(path => Path.GetRelativePath(repositoryRoot, path))
        .OrderBy(path => path, StringComparer.Ordinal)
        .ToArray();

    if (unmappedTargets.Length > 0)
    {
        throw new InvalidOperationException(
            "Tracked object scripts missing from ObjectScriptManifest.json: "
            + string.Join(", ", unmappedTargets));
    }

    if (!allowMissingTargets && missingTargets.Length > 0)
    {
        throw new InvalidOperationException(
            "Mapped object scripts missing from .tts/objects: "
            + string.Join(", ", missingTargets));
    }

    return mappings;
}

static bool FilesHaveEqualContents(string firstPath, string secondPath) =>
    File.ReadAllBytes(firstPath).AsSpan()
        .SequenceEqual(File.ReadAllBytes(secondPath));

static string GetObjectDataPath(string targetPath) =>
    Path.ChangeExtension(targetPath, ".data.json");

static string ReadEmbeddedObjectScript(string dataPath)
{
    if (!File.Exists(dataPath))
    {
        throw new InvalidOperationException(
            $"Mapped object data '{dataPath}' is missing.");
    }

    using var document = JsonDocument.Parse(File.ReadAllText(dataPath));

    if (!document.RootElement.TryGetProperty("LuaScript", out var script)
        || script.ValueKind != JsonValueKind.String)
    {
        throw new InvalidOperationException(
            $"Mapped object data '{dataPath}' has no LuaScript string.");
    }

    return script.GetString()!;
}

static bool SynchronizeEmbeddedObjectScript(
    string sourcePath,
    string targetPath)
{
    var dataPath = GetObjectDataPath(targetPath);
    var canonicalScript = NormalizeLineEndings(
        File.ReadAllText(sourcePath));
    var embeddedScript = NormalizeLineEndings(
        ReadEmbeddedObjectScript(dataPath));

    if (string.Equals(
        canonicalScript,
        embeddedScript,
        StringComparison.Ordinal))
    {
        return false;
    }

    var contents = File.ReadAllText(dataPath);
    var luaScriptProperty = new Regex(
        @"(?m)^(  ""LuaScript""\s*:\s*)""(?:\\.|[^""\\])*""");
    var matches = luaScriptProperty.Matches(contents);

    if (matches.Count != 1)
    {
        throw new InvalidOperationException(
            $"Mapped object data '{dataPath}' must have one LuaScript field.");
    }

    var replacement = matches[0].Groups[1].Value
        + JsonSerializer.Serialize(canonicalScript);
    var updated = luaScriptProperty.Replace(contents, replacement, 1);
    File.WriteAllText(dataPath, updated, new UTF8Encoding(false));
    return true;
}

static void SynchronizeCanonicalObjectScripts(string repositoryRoot)
{
    var mappings = LoadObjectScriptMappings(
        repositoryRoot,
        allowMissingTargets: true);
    var updatedCount = 0;

    foreach (var (sourcePath, targetPath) in mappings)
    {
        var targetUpdated = false;

        if (!File.Exists(targetPath)
            || !FilesHaveEqualContents(sourcePath, targetPath))
        {
            Directory.CreateDirectory(Path.GetDirectoryName(targetPath)!);
            File.Copy(sourcePath, targetPath, overwrite: true);
            targetUpdated = true;
        }

        targetUpdated = SynchronizeEmbeddedObjectScript(
            sourcePath,
            targetPath) || targetUpdated;

        if (targetUpdated)
        {
            Console.WriteLine(
                $"Synchronized "
                + $"{Path.GetRelativePath(repositoryRoot, targetPath)} "
                + "and its embedded data script.");
            updatedCount++;
        }
    }

    Console.WriteLine(
        updatedCount == 0
            ? "Object scripts are already synchronized."
            : $"Synchronized {updatedCount} object script(s).");
}

static void ValidateCanonicalObjectScripts(string repositoryRoot)
{
    foreach (var (sourcePath, targetPath) in
        LoadObjectScriptMappings(repositoryRoot))
    {
        if (!FilesHaveEqualContents(sourcePath, targetPath))
        {
            throw new InvalidOperationException(
                $"Tracked object script "
                + $"'{Path.GetRelativePath(repositoryRoot, targetPath)}' has "
                + "drifted from its canonical source "
                + $"'{Path.GetRelativePath(repositoryRoot, sourcePath)}'. "
                + "Run the test runner with --sync-object-scripts.");
        }

        var canonicalScript = NormalizeLineEndings(
            File.ReadAllText(sourcePath));
        var dataPath = GetObjectDataPath(targetPath);
        var embeddedScript = NormalizeLineEndings(
            ReadEmbeddedObjectScript(dataPath));

        if (!string.Equals(
            canonicalScript,
            embeddedScript,
            StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"Embedded LuaScript in "
                + $"'{Path.GetRelativePath(repositoryRoot, dataPath)}' has "
                + "drifted from its canonical source "
                + $"'{Path.GetRelativePath(repositoryRoot, sourcePath)}'. "
                + "Run the test runner with --sync-object-scripts.");
        }
    }
}

static string EscapeXmlAttribute(string value) =>
    value.Replace("&", "&amp;", StringComparison.Ordinal)
        .Replace("<", "&lt;", StringComparison.Ordinal)
        .Replace("\"", "&quot;", StringComparison.Ordinal);

static string[] DefinitionFields(
    string value,
    int expectedCount,
    string description)
{
    var fields = value.Split('\t');

    if (fields.Length != expectedCount)
    {
        throw new InvalidOperationException(
            $"Generated UI definition '{description}' expected "
            + $"{expectedCount} fields, found {fields.Length}.");
    }

    return fields;
}

static string RenderSettingsBoardButtons(int count)
{
    var lines = new List<string>();

    for (var index = 1; index <= count; index++)
    {
        lines.Add("                <Button");
        lines.Add($"                    id=\"settingsSavedBoard{index}\"");
        lines.Add($"                    text=\"Saved Board {index}\"");
        lines.Add("                    fontSize=\"18\"");
        lines.Add(
            $"                    onClick=\"onSettingsUiClicked(select{index})\"");
        lines.Add("                    preferredWidth=\"630\"");
        lines.Add("                    preferredHeight=\"36\"");
        lines.Add("                    active=\"false\"");
        lines.Add("                />");
    }

    return string.Join('\n', lines);
}

static string RenderDeckChoiceRows(IReadOnlyList<string> definitions)
{
    var choices = definitions
        .Select(value => DefinitionFields(value, 2, "deck choice"))
        .ToArray();
    var lines = new List<string>();

    for (var offset = 0; offset < choices.Length; offset += 2)
    {
        lines.Add("        <HorizontalLayout preferredHeight=\"68\" spacing=\"12\">");

        for (var column = 0; column < 2; column++)
        {
            var choiceIndex = offset + column;

            if (choiceIndex >= choices.Length)
            {
                lines.Add("            <Panel preferredWidth=\"420\" preferredHeight=\"64\" />");
                continue;
            }

            var lootId = choices[choiceIndex][0];
            var name = choices[choiceIndex][1];
            lines.Add("            <Button");
            lines.Add($"                text=\"{EscapeXmlAttribute(name)}\"");
            lines.Add(
                $"                onClick=\"onDeckSelectionUiClicked({lootId})\"");

            if (name.Length > 25)
            {
                lines.Add("                resizeTextForBestFit=\"true\"");
                lines.Add("                resizeTextMinSize=\"16\"");
            }

            lines.Add("                preferredWidth=\"420\"");
            lines.Add("                preferredHeight=\"64\"");
            lines.Add("            />");
        }

        lines.Add("        </HorizontalLayout>");
    }

    return string.Join('\n', lines);
}

static string RenderDungeonTileButtons(
    IReadOnlyList<string> definitions,
    string textColor,
    string colors)
{
    var lines = new List<string>();
    int? previousR = null;

    foreach (var definition in definitions)
    {
        var fields = DefinitionFields(definition, 3, "dungeon tile");
        var index = int.Parse(fields[0]);
        var q = int.Parse(fields[1]);
        var r = int.Parse(fields[2]);
        var x = 284 + 70 * q + 35 * r;
        var y = -218 - 68 * r;

        if (previousR is not null && previousR != r)
        {
            lines.Add("");
        }

        previousR = r;

        lines.Add("                <Button");
        lines.Add($"                    id=\"dungeonMapTile{index}\"");
        lines.Add("                    text=\"#\"");
        lines.Add("                    rectAlignment=\"UpperLeft\"");
        lines.Add("                    width=\"64\"");
        lines.Add("                    height=\"56\"");
        lines.Add($"                    offsetXY=\"{x} {y}\"");
        lines.Add("                    fontSize=\"16\"");
        lines.Add("                    fontStyle=\"Bold\"");
        lines.Add($"                    textColor=\"{textColor}\"");
        lines.Add($"                    colors=\"{colors}\"");
        lines.Add(
            $"                    onClick=\"onDungeonMapUiClicked(tile{index})\"");
        lines.Add("                    active=\"false\"");
        lines.Add("                    tooltip=\"Unassigned dungeon hex\"");
        lines.Add("                />");
    }

    return string.Join('\n', lines);
}

static string RenderDungeonBoardButtons(int count)
{
    var lines = new List<string>();

    for (var index = 1; index <= count; index++)
    {
        lines.Add("                    <Button");
        lines.Add($"                        id=\"dungeonMapBoard{index}\"");
        lines.Add($"                        text=\"Saved Board {index}\"");
        lines.Add("                        fontSize=\"17\"");
        lines.Add("                        resizeTextForBestFit=\"true\"");
        lines.Add("                        resizeTextMinSize=\"13\"");
        lines.Add("                        resizeTextMaxSize=\"17\"");
        lines.Add(
            $"                        onClick=\"onDungeonMapUiClicked(board{index})\"");
        lines.Add("                        preferredWidth=\"340\"");
        lines.Add("                        preferredHeight=\"42\"");
        lines.Add("                        active=\"false\"");
        lines.Add("                    />");
    }

    return string.Join('\n', lines);
}

static string RenderTurnControls(
    IReadOnlyList<string> phaseDefinitions,
    IReadOnlyList<string> playerColors,
    IReadOnlyList<string> uiValues)
{
    var phaseIdPrefix = uiValues[0];
    var activePhasePrefix = uiValues[1];
    var inactivePhasePrefix = uiValues[2];
    var activePhaseColor = uiValues[3];
    var inactivePhaseColor = uiValues[4];
    var startPhaseButtonText = uiValues[5];
    var waitingButtonText = uiValues[6];
    var phaseButtonPrefix = uiValues[7];
    var lines = new List<string>();

    for (var index = 0; index < phaseDefinitions.Count; index++)
    {
        var fields = DefinitionFields(
            phaseDefinitions[index],
            2,
            "turn phase");
        var active = index == 0;
        var text = (active ? activePhasePrefix : inactivePhasePrefix)
            + fields[1];
        lines.Add("        <Text");
        lines.Add($"            id=\"{phaseIdPrefix}{fields[0]}\"");
        lines.Add($"            text=\"{EscapeXmlAttribute(text)}\"");
        lines.Add("            fontSize=\"22\"");

        if (active)
        {
            lines.Add("            fontStyle=\"Bold\"");
        }

        lines.Add(
            $"            color=\"{(active ? activePhaseColor : inactivePhaseColor)}\"");
        lines.Add("            alignment=\"MiddleLeft\"");
        lines.Add("            preferredWidth=\"280\"");
        lines.Add("            preferredHeight=\"38\"");
        lines.Add("        />");
    }

    lines.Add("");

    for (var index = 0; index < playerColors.Count; index++)
    {
        var color = playerColors[index];
        var active = index == 0;
        lines.Add("        <Button");
        lines.Add($"            id=\"{phaseButtonPrefix}{color}\"");
        lines.Add(
            $"            text=\"{EscapeXmlAttribute(active ? startPhaseButtonText : waitingButtonText)}\"");
        lines.Add($"            visibility=\"{color}\"");
        lines.Add("            onClick=\"onAdvancePhaseClicked\"");
        lines.Add("            preferredWidth=\"280\"");
        lines.Add("            preferredHeight=\"52\"");

        if (!active)
        {
            lines.Add("            interactable=\"false\"");
        }

        lines.Add("        />");
    }

    return string.Join('\n', lines);
}

static string SelectorLabel(string label)
{
    if (label.Length <= 8)
    {
        return label;
    }

    var separator = label.IndexOf(' ');
    return separator > 0 ? label[..separator] : label;
}

static void AppendHexSelectorButton(
    List<string> lines,
    string idPrefix,
    int index,
    string label,
    int width)
{
    var shortLabel = SelectorLabel(label);
    lines.Add("            <Button");
    lines.Add($"                id=\"{idPrefix}{index}\"");
    lines.Add(
        $"                text=\"{index}  {EscapeXmlAttribute(shortLabel.ToUpperInvariant())}\"");
    lines.Add("                fontSize=\"18\"");
    lines.Add(
        $"                onClick=\"onHexGridSpawnSelectorUiClicked({index})\"");
    lines.Add($"                preferredWidth=\"{width}\"");
    lines.Add("                preferredHeight=\"52\"");

    if (!string.Equals(shortLabel, label, StringComparison.Ordinal))
    {
        lines.Add($"                tooltip=\"{EscapeXmlAttribute(label)}\"");
    }

    lines.Add("            />");
}

static string RenderHexSpawnSelectorRows(
    IReadOnlyList<string> definitions,
    string idPrefix)
{
    if (definitions.Count > 9)
    {
        throw new InvalidOperationException(
            "The numeric hex spawn palette supports at most nine objects.");
    }

    var labels = definitions
        .Select(value => DefinitionFields(value, 2, "hex spawn object")[1])
        .ToArray();
    var lines = new List<string>();
    var rowStarts = new[] {0, 5};

    foreach (var rowStart in rowStarts)
    {
        if (rowStart >= labels.Length)
        {
            continue;
        }

        var rowEnd = Math.Min(labels.Length, rowStart == 0 ? 5 : 9);
        var width = rowStart == 0 ? 116 : 140;
        lines.Add("        <HorizontalLayout");
        lines.Add("            preferredHeight=\"58\"");
        lines.Add("            spacing=\"8\"");
        lines.Add("            childAlignment=\"MiddleCenter\"");
        lines.Add("        >");

        for (var index = rowStart; index < rowEnd; index++)
        {
            AppendHexSelectorButton(
                lines,
                idPrefix,
                index + 1,
                labels[index],
                width);
        }

        lines.Add("        </HorizontalLayout>");
    }

    return string.Join('\n', lines);
}

static void AppendHexMenuButton(
    List<string> lines,
    string[] definition,
    int index,
    int width)
{
    lines.Add("                <Button");
    lines.Add(
        $"                    text=\"{index}  {EscapeXmlAttribute(definition[1])}\"");
    lines.Add(
        $"                    onClick=\"onHexGridMenuUiClicked({definition[0]})\"");
    lines.Add($"                    preferredWidth=\"{width}\"");
    lines.Add("                    preferredHeight=\"64\"");
    lines.Add("                />");
}

static string RenderHexMenuChoiceRows(IReadOnlyList<string> definitions)
{
    if (definitions.Count > 9)
    {
        throw new InvalidOperationException(
            "The numeric hex object menu supports at most nine objects.");
    }

    var choices = definitions
        .Select(value => DefinitionFields(value, 2, "hex menu object"))
        .ToArray();
    var lines = new List<string>();

    for (var row = 0; row < 4 && row < choices.Length; row++)
    {
        lines.Add("            <HorizontalLayout");
        lines.Add("                preferredHeight=\"72\"");
        lines.Add("                spacing=\"12\"");
        lines.Add("                childAlignment=\"MiddleCenter\"");
        lines.Add("            >");
        AppendHexMenuButton(lines, choices[row], row + 1, 185);

        if (row + 4 < choices.Length)
        {
            AppendHexMenuButton(lines, choices[row + 4], row + 5, 185);
        }
        else
        {
            lines.Add("                <Panel preferredWidth=\"185\" preferredHeight=\"64\" />");
        }

        lines.Add("            </HorizontalLayout>");
    }

    if (choices.Length == 9)
    {
        lines.Add("            <HorizontalLayout");
        lines.Add("                preferredHeight=\"72\"");
        lines.Add("                spacing=\"12\"");
        lines.Add("                childAlignment=\"MiddleCenter\"");
        lines.Add("            >");
        AppendHexMenuButton(lines, choices[8], 9, 382);
        lines.Add("            </HorizontalLayout>");
    }

    return string.Join('\n', lines);
}

static string RenderSurfaceChoiceButtons(
    IReadOnlyList<string> definitions,
    string idPrefix)
{
    var lines = new List<string>();

    for (var rowStart = 0; rowStart < definitions.Count; rowStart += 2)
    {
        lines.Add("        <HorizontalLayout");
        lines.Add("            preferredHeight=\"58\"");
        lines.Add("            spacing=\"10\"");
        lines.Add("            childAlignment=\"MiddleCenter\"");
        lines.Add("        >");

        for (var column = 0; column < 2; column++)
        {
            var index = rowStart + column;

            if (index >= definitions.Count)
            {
                lines.Add(
                    "            <Panel preferredWidth=\"185\" preferredHeight=\"54\" />");
                continue;
            }

            var fields = DefinitionFields(
                definitions[index],
                2,
                "surface definition");
            lines.Add("            <Button");
            lines.Add($"                id=\"{idPrefix}{index + 1}\"");
            lines.Add(
                $"                text=\"{EscapeXmlAttribute(fields[1].ToUpperInvariant())}\"");
            lines.Add("                fontSize=\"19\"");
            lines.Add("                fontStyle=\"Bold\"");
            lines.Add("                colors=\"#4C1D6F|#6B2998|#35134E|#35134E\"");
            lines.Add(
                $"                onClick=\"onSurfaceUiClicked({fields[0]})\"");
            lines.Add("                preferredWidth=\"185\"");
            lines.Add("                preferredHeight=\"54\"");
            lines.Add("            />");
        }

        lines.Add("        </HorizontalLayout>");
    }

    return string.Join('\n', lines);
}

static IReadOnlyDictionary<string, string> BuildGlobalUiRegions(Script script)
{
    var settingsCount = EvaluateLuaCount(
        script,
        "return require('src/config/SettingsConfig').boardListPageSize",
        "settings board rows");
    var deckChoices = EvaluateLuaStrings(
        script,
        "local result = {}; for _, deck in ipairs(require('src/config/CardFieldConfig').deckSlot.decks) do "
            + "result[#result + 1] = tostring(deck.lootId) .. '\\t' .. deck.name; end; return result",
        "deck choices");
    var dungeonTiles = EvaluateLuaStrings(
        script,
        "local State = require('src/dungeon/DungeonMapState'); local Config = require('src/dungeon/DungeonMapConfig'); "
            + "local result = {}; for _, cell in ipairs(State.buildCells(Config.radius)) do "
            + "result[#result + 1] = table.concat({cell.index, cell.q, cell.r}, '\\t'); end; return result",
        "dungeon tile layout");
    var dungeonUi = EvaluateLuaStrings(
        script,
        "local Config = require('src/dungeon/DungeonMapConfig'); return {Config.tileTextColor, Config.tileColors.empty}",
        "dungeon UI colors");
    var dungeonBoardCount = EvaluateLuaCount(
        script,
        "return require('src/dungeon/DungeonMapConfig').boardListPageSize",
        "dungeon board rows");
    var phases = EvaluateLuaStrings(
        script,
        "local State = require('src/turns/TurnState'); local Config = require('src/config/TurnConfig'); "
            + "local result = {}; for _, phase in ipairs(State.getPhases()) do "
            + "result[#result + 1] = phase .. '\\t' .. Config.phaseLabels[phase]; end; return result",
        "turn phases");
    var players = EvaluateLuaStrings(
        script,
        "local result = {}; for _, color in ipairs(require('src/config/TurnConfig').playerColors) do "
            + "result[#result + 1] = color; end; return result",
        "turn player colors");
    var turnUi = EvaluateLuaStrings(
        script,
        "local ui = require('src/config/TurnConfig').ui; return {ui.phaseIdPrefix, ui.activePhasePrefix, "
            + "ui.inactivePhasePrefix, ui.activePhaseColor, ui.inactivePhaseColor, ui.startPhaseButtonText, "
            + "ui.waitingButtonText, ui.phaseButtonPrefix}",
        "turn UI values");
    var spawnDefinitions = EvaluateLuaStrings(
        script,
        "local result = {}; for _, definition in ipairs(require('src/hex/HexSpawnDefinitions')) do "
            + "result[#result + 1] = definition.key .. '\\t' .. definition.label; end; return result",
        "hex spawn definitions");
    var spawnPrefix = EvaluateLuaStrings(
        script,
        "return {require('src/config/HexMenuConfig').ui.spawnSelectorButtonPrefix}",
        "hex spawn selector prefix")[0];
    var surfaceDefinitions = EvaluateLuaStrings(
        script,
        "local result = {}; for _, definition in ipairs(require('src/surfaces/SurfaceDefinitions')) do "
            + "result[#result + 1] = definition.key .. '\\t' .. definition.label; end; return result",
        "surface definitions");
    var surfaceButtonPrefix = EvaluateLuaStrings(
        script,
        "return {require('src/config/SurfaceConfig').ui.buttonPrefix}",
        "surface button prefix")[0];

    return new Dictionary<string, string>(StringComparer.Ordinal)
    {
        ["settings-board-buttons"] = RenderSettingsBoardButtons(settingsCount),
        ["deck-choice-rows"] = RenderDeckChoiceRows(deckChoices),
        ["dungeon-tile-buttons"] = RenderDungeonTileButtons(
            dungeonTiles,
            dungeonUi[0],
            dungeonUi[1]),
        ["dungeon-board-buttons"] = RenderDungeonBoardButtons(
            dungeonBoardCount),
        ["turn-phase-and-player-controls"] = RenderTurnControls(
            phases,
            players,
            turnUi),
        ["hex-spawn-selector-rows"] = RenderHexSpawnSelectorRows(
            spawnDefinitions,
            spawnPrefix),
        ["hex-menu-choice-rows"] = RenderHexMenuChoiceRows(
            spawnDefinitions),
        ["surface-choice-buttons"] = RenderSurfaceChoiceButtons(
            surfaceDefinitions,
            surfaceButtonPrefix)
    };
}

static Regex GeneratedUiRegionPattern(string name) => new(
    $"(?ms)(^[ \\t]*<!-- BEGIN GENERATED:{Regex.Escape(name)} -->\\r?\\n)"
        + "(.*?)"
        + $"(^[ \\t]*<!-- END GENERATED:{Regex.Escape(name)} -->)");

static string ExpectedGeneratedBody(string body) =>
    NormalizeLineEndings(body).TrimEnd('\n') + "\n";

static void ValidateGeneratedGlobalUi(string contents, Script script)
{
    foreach (var (name, body) in BuildGlobalUiRegions(script))
    {
        var matches = GeneratedUiRegionPattern(name).Matches(contents);

        if (matches.Count != 1)
        {
            throw new InvalidOperationException(
                $"Global.xml must contain exactly one generated UI region '{name}'.");
        }

        var actual = NormalizeLineEndings(matches[0].Groups[2].Value);
        var expected = ExpectedGeneratedBody(body);

        if (!string.Equals(actual, expected, StringComparison.Ordinal))
        {
            throw new InvalidOperationException(
                $"Global.xml generated UI region '{name}' has drifted. "
                + "Run the test runner with --sync-global-ui.");
        }
    }
}

static void SynchronizeGlobalUi(string repositoryRoot, Script script)
{
    var path = Path.Combine(repositoryRoot, ".tts", "objects", "Global.xml");
    var contents = File.ReadAllText(path);
    var lineEnding = contents.Contains("\r\n", StringComparison.Ordinal)
        ? "\r\n" : "\n";
    var updated = contents;

    foreach (var (name, body) in BuildGlobalUiRegions(script))
    {
        var pattern = GeneratedUiRegionPattern(name);
        var matches = pattern.Matches(updated);

        if (matches.Count != 1)
        {
            throw new InvalidOperationException(
                $"Global.xml must contain exactly one generated UI region '{name}'.");
        }

        var expectedBody = ExpectedGeneratedBody(body)
            .Replace("\n", lineEnding, StringComparison.Ordinal);
        updated = pattern.Replace(
            updated,
            match => match.Groups[1].Value
                + expectedBody
                + match.Groups[3].Value,
            1);
    }

    if (string.Equals(contents, updated, StringComparison.Ordinal))
    {
        Console.WriteLine("Global UI XML is already synchronized.");
        return;
    }

    File.WriteAllText(path, updated, new UTF8Encoding(false));
    Console.WriteLine("Synchronized generated Global UI XML regions.");
}

static void ValidateTrackedAssets(string repositoryRoot, Script script)
{
    var objectRoot = Path.Combine(repositoryRoot, ".tts", "objects");
    var rootGlobalPath = Path.Combine(repositoryRoot, "Global.lua");
    var objectGlobalPath = Path.Combine(objectRoot, "Global.lua");
    var uiPath = Path.Combine(objectRoot, "Global.xml");

    if (!Directory.Exists(objectRoot))
    {
        throw new InvalidOperationException(
            "The tracked .tts/objects directory is missing.");
    }

    ValidateCanonicalObjectScripts(repositoryRoot);

    foreach (var dataPath in Directory.EnumerateFiles(
        objectRoot,
        "*.data.json",
        SearchOption.TopDirectoryOnly))
    {
        using var document = JsonDocument.Parse(File.ReadAllText(dataPath));
    }

    var rootGlobal = NormalizeLineEndings(File.ReadAllText(rootGlobalPath));
    var objectGlobal = NormalizeLineEndings(File.ReadAllText(objectGlobalPath));

    if (!string.Equals(rootGlobal, objectGlobal, StringComparison.Ordinal))
    {
        throw new InvalidOperationException(
            "Global.lua and .tts/objects/Global.lua have drifted apart.");
    }

    var uiFragment = File.ReadAllText(uiPath);
    ValidateGeneratedGlobalUi(uiFragment, script);
    var ui = XDocument.Parse($"<TtsUi>{uiFragment}</TtsUi>");
    var ids = ui.Descendants()
        .Attributes("id")
        .Select(attribute => attribute.Value)
        .ToArray();
    var duplicateIds = ids
        .GroupBy(id => id, StringComparer.Ordinal)
        .Where(group => group.Count() > 1)
        .Select(group => group.Key)
        .ToArray();

    if (duplicateIds.Length > 0)
    {
        throw new InvalidOperationException(
            "Duplicate UI IDs: " + string.Join(", ", duplicateIds));
    }

    var globalFunctions = Regex.Matches(
            rootGlobal,
            @"(?m)^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
        .Select(match => match.Groups[1].Value)
        .ToHashSet(StringComparer.Ordinal);
    var callbackValues = ui.Descendants()
        .Attributes()
        .Where(attribute => attribute.Name.LocalName is
            "onClick" or "onValueChanged" or "onEndEdit")
        .Select(attribute => attribute.Value)
        .ToArray();

    foreach (var callbackValue in callbackValues)
    {
        var callbackMatch = Regex.Match(
            callbackValue,
            @"^\s*([A-Za-z_][A-Za-z0-9_]*)");

        if (!callbackMatch.Success
            || !globalFunctions.Contains(callbackMatch.Groups[1].Value))
        {
            throw new InvalidOperationException(
                $"UI callback '{callbackValue}' has no Global.lua function.");
        }
    }

    var expectedDeckArguments = EvaluateLuaStrings(
        script,
        "local values = {}; "
            + "for index, deck in ipairs(require('src/config/CardFieldConfig')"
            + ".deckSlot.decks) do values[index] = tostring(deck.lootId); end; "
            + "return values",
        "deck choice callback arguments");
    RequireExactSequence(
        "deck choice callback arguments",
        ExtractCallbackArguments(
            callbackValues,
            "onDeckSelectionUiClicked",
            @"\d+"),
        expectedDeckArguments);

    var hexSpawnCount = EvaluateLuaCount(
        script,
        "return #require('src/hex/HexSpawnDefinitions')",
        "hex spawn choices");
    RequireExactSequence(
        "hex spawn callback arguments",
        ExtractCallbackArguments(
            callbackValues,
            "onHexGridSpawnSelectorUiClicked",
            @"\d+"),
        SequentialStrings(hexSpawnCount));

    var expectedSurfaceArguments = EvaluateLuaStrings(
        script,
        "local values = {'close'}; for _, definition in ipairs(require('src/surfaces/SurfaceDefinitions')) do "
            + "values[#values + 1] = definition.key; end; return values",
        "surface callback arguments");
    RequireExactSequence(
        "surface callback arguments",
        ExtractCallbackArguments(
            callbackValues,
            "onSurfaceUiClicked",
            @"[A-Za-z_][A-Za-z0-9_]*"),
        expectedSurfaceArguments);

    var settingsRowCount = EvaluateLuaCount(
        script,
        "return require('src/config/SettingsConfig').boardListPageSize",
        "settings board rows");
    RequireExactSequence(
        "settings board-row callback arguments",
        ExtractCallbackArguments(
            callbackValues,
            "onSettingsUiClicked",
            @"select\d+"),
        SequentialStrings(settingsRowCount)
            .Select(index => $"select{index}")
            .ToArray());

    var dungeonTileCount = EvaluateLuaCount(
        script,
        "local State = require('src/dungeon/DungeonMapState'); "
            + "local Config = require('src/dungeon/DungeonMapConfig'); "
            + "return #State.buildCells(Config.radius)",
        "dungeon tiles");
    RequireExactSequence(
        "dungeon tile callback arguments",
        ExtractCallbackArguments(
            callbackValues,
            "onDungeonMapUiClicked",
            @"tile\d+"),
        SequentialStrings(dungeonTileCount)
            .Select(index => $"tile{index}")
            .ToArray());

    var dungeonRowCount = EvaluateLuaCount(
        script,
        "return require('src/dungeon/DungeonMapConfig').boardListPageSize",
        "dungeon board rows");
    RequireExactSequence(
        "dungeon board-row callback arguments",
        ExtractCallbackArguments(
            callbackValues,
            "onDungeonMapUiClicked",
            @"board\d+"),
        SequentialStrings(dungeonRowCount)
            .Select(index => $"board{index}")
            .ToArray());
    RequireCount(
        "turn phase labels",
        ids.Count(id => id.StartsWith("turnPhase", StringComparison.Ordinal)
            && id != "turnPhasePanel"),
        EvaluateLuaCount(
            script,
            "return #require('src/turns/TurnState').getPhases()",
            "turn phases"));
    RequireCount(
        "turn player buttons",
        ids.Count(id => id.StartsWith(
            "advancePhase",
            StringComparison.Ordinal)),
        EvaluateLuaCount(
            script,
            "return #require('src/config/TurnConfig').playerColors",
            "turn players"));

    var idSet = ids.ToHashSet(StringComparer.Ordinal);

    RequireUiIds(
        "settings",
        idSet,
        EvaluateLuaStrings(
            script,
            "local config = require('src/config/SettingsConfig'); "
                + "local result = {}; "
                + "for key, value in pairs(config.ui) do "
                + "if type(value) == 'string' and string.match(key, 'Id$') "
                + "then result[#result + 1] = value; end; end; "
                + "for row = 1, config.boardListPageSize do "
                + "result[#result + 1] = config.ui.boardButtonPrefix .. row; "
                + "end; return result",
            "settings UI IDs"));

    RequireUiIds(
        "dungeon",
        idSet,
        EvaluateLuaStrings(
            script,
            "local config = require('src/dungeon/DungeonMapConfig'); "
                + "local State = require('src/dungeon/DungeonMapState'); "
                + "local result = {}; "
                + "for key, value in pairs(config.ui) do "
                + "if type(value) == 'string' and string.match(key, 'Id$') "
                + "then result[#result + 1] = value; end; end; "
                + "for _, cell in ipairs(State.buildCells(config.radius)) do "
                + "result[#result + 1] = config.ui.tileButtonPrefix "
                + ".. cell.index; end; "
                + "for row = 1, config.boardListPageSize do "
                + "result[#result + 1] = config.ui.boardButtonPrefix .. row; "
                + "end; return result",
            "dungeon UI IDs"));

    RequireUiIds(
        "turn",
        idSet,
        EvaluateLuaStrings(
            script,
            "local config = require('src/config/TurnConfig'); "
                + "local TurnState = require('src/turns/TurnState'); "
                + "local result = {}; "
                + "for key, value in pairs(config.ui) do "
                + "if type(value) == 'string' and string.match(key, 'Id$') "
                + "then result[#result + 1] = value; end; end; "
                + "for _, phase in ipairs(TurnState.getPhases()) do "
                + "result[#result + 1] = config.ui.phaseIdPrefix .. phase; "
                + "end; for _, color in ipairs(config.playerColors) do "
                + "result[#result + 1] = config.ui.phaseButtonPrefix .. color; "
                + "end; return result",
            "turn UI IDs"));

    RequireUiIds(
        "deck-selection",
        idSet,
        EvaluateLuaStrings(
            script,
            "local config = require('src/config/CardFieldConfig'); "
                + "return {config.deckSlot.menuRootId}",
            "deck-selection UI IDs"));

    RequireUiIds(
        "hex",
        idSet,
        EvaluateLuaStrings(
            script,
            "local config = require('src/config/HexMenuConfig'); "
                + "local definitions = require('src/hex/HexSpawnDefinitions'); "
                + "local result = {}; "
                + "for key, value in pairs(config.ui) do "
                + "if type(value) == 'string' and string.match(key, 'Id$') "
                + "then result[#result + 1] = value; end; end; "
                + "for index = 1, #definitions do result[#result + 1] = "
                + "config.ui.spawnSelectorButtonPrefix .. index; end; "
                + "return result",
            "hex UI IDs"));

    RequireUiIds(
        "surfaces",
        idSet,
        EvaluateLuaStrings(
            script,
            "local config = require('src/config/SurfaceConfig'); "
                + "local definitions = require('src/surfaces/SurfaceDefinitions'); "
                + "local result = {}; "
                + "for key, value in pairs(config.ui) do "
                + "if type(value) == 'string' and string.match(key, 'Id$') "
                + "then result[#result + 1] = value; end; end; "
                + "for index = 1, #definitions do result[#result + 1] = "
                + "config.ui.buttonPrefix .. index; end; return result",
            "surface UI IDs"));
}

static void CompileGeneratedCardScripts(Script script)
{
    var generatedCases = script.DoString(
        "local definitions = require('data/CardDefinitions'); "
            + "local CardLogic = require('src/cards/CardLogic'); "
            + "if type(definitions.defaultFeatureIds) ~= 'table' then "
            + "error('CardDefinitions.defaultFeatureIds must be a table'); "
            + "end; local cases = {}; "
            + "local function add(name, featureIds) cases[#cases + 1] = {"
            + "name = name, source = CardLogic.build(featureIds)}; end; "
            + "add('configured-defaults', definitions.defaultFeatureIds); "
            + "add('empty-features', {}); "
            + "for index, definition in ipairs(definitions.cards or {}) do "
            + "if definition.featureIds ~= nil then "
            + "if type(definition.featureIds) ~= 'table' then "
            + "error('Configured featureIds must be a table for card ' "
            + ".. tostring(definition.id or index)); end; "
            + "add('configured-card-' .. tostring(index) .. '-' "
            + ".. tostring(definition.id or 'unknown'), "
            + "definition.featureIds); end; end; return cases");

    if (generatedCases.Type != DataType.Table)
    {
        throw new InvalidOperationException(
            "Generated-card compilation cases did not return a list.");
    }

    for (var index = 1; index <= generatedCases.Table.Length; index++)
    {
        var generatedCase = generatedCases.Table.Get(index);

        if (generatedCase.Type != DataType.Table)
        {
            throw new InvalidOperationException(
                $"Generated-card case {index} is not a table.");
        }

        var name = generatedCase.Table.Get("name");
        var source = generatedCase.Table.Get("source");

        if (name.Type != DataType.String
            || source.Type != DataType.String)
        {
            throw new InvalidOperationException(
                $"Generated-card case {index} needs a name and source.");
        }

        var safeName = Regex.Replace(
            name.String,
            @"[^A-Za-z0-9._-]+",
            "-");
        script.LoadString(
            source.String,
            null,
            $"generated-card-{index}-{safeName}.lua");
    }
}

try
{
    var command = args.Length == 0 ? null : args[0];

    if (args.Length > 1
        || command is not null
            and not "--check-object-scripts"
            and not "--sync-object-scripts"
            and not "--check-global-ui"
            and not "--sync-global-ui")
    {
        throw new InvalidOperationException(
            "Usage: LichTts.TestRunner [--check-object-scripts|"
            + "--sync-object-scripts|--check-global-ui|--sync-global-ui]");
    }

    var repositoryRoot = FindRepositoryRoot();

    if (command == "--sync-object-scripts")
    {
        SynchronizeCanonicalObjectScripts(repositoryRoot);
    }

    var script = new Script(CoreModules.Preset_Complete);
    var loader = new FileSystemScriptLoader
    {
        ModulePaths =
        [
            Path.Combine(repositoryRoot, "?.lua"),
            Path.Combine(repositoryRoot, "?", "init.lua")
        ],
        IgnoreLuaPathGlobal = true
    };

    script.Options.ScriptLoader = loader;
    script.Options.DebugPrint = Console.WriteLine;
    script.Globals["TEST_REPOSITORY_ROOT"] = repositoryRoot;

    if (command == "--sync-global-ui")
    {
        SynchronizeGlobalUi(repositoryRoot, script);
    }

    ValidateTrackedAssets(repositoryRoot, script);

    var sourceFiles = Directory
        .EnumerateFiles(
            Path.Combine(repositoryRoot, "src"),
            "*.lua",
            SearchOption.AllDirectories)
        .Concat(
            Directory.EnumerateFiles(
                Path.Combine(repositoryRoot, "object_logic"),
                "*.lua",
                SearchOption.AllDirectories))
        .Concat(
            Directory.EnumerateFiles(
                Path.Combine(repositoryRoot, ".tts", "objects"),
                "*.lua",
                SearchOption.TopDirectoryOnly))
        .Append(Path.Combine(repositoryRoot, "Global.lua"));

    foreach (var sourceFile in sourceFiles)
    {
        var relativePath = Path.GetRelativePath(repositoryRoot, sourceFile);
        script.LoadString(
            File.ReadAllText(sourceFile),
            null,
            relativePath);
    }

    // Dynamic cards receive generated object scripts. Compile every mechanic
    // combination declared by card data, including its explicit defaults and
    // the intentional mechanic-free case, before reaching TTS.
    CompileGeneratedCardScripts(script);

    if (command is not null)
    {
        Console.WriteLine(
            "Generated assets are synchronized and all tracked scripts compile.");
        return 0;
    }

    script.DoFile(Path.Combine(repositoryRoot, "tests", "run.lua"));
    return 0;
}
catch (InterpreterException exception)
{
    Console.Error.WriteLine(exception.DecoratedMessage);
    return 1;
}
catch (Exception exception)
{
    Console.Error.WriteLine(exception);
    return 1;
}

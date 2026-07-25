using MoonSharp.Interpreter;
using MoonSharp.Interpreter.Loaders;

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

try
{
    var repositoryRoot = FindRepositoryRoot();
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
        .Append(Path.Combine(repositoryRoot, "Global.lua"));

    foreach (var sourceFile in sourceFiles)
    {
        var relativePath = Path.GetRelativePath(repositoryRoot, sourceFile);
        script.LoadString(
            File.ReadAllText(sourceFile),
            null,
            relativePath);
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

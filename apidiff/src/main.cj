package restest_apidiff

import std.collection.*
import std.env.*
import std.fs.*
import restest_apidiff.deps.*
import restest_common.*
import std.sort.*
import stdx.encoding.json.*
import stdx.syntax.*
import toml4cj.decoders.*

struct RunnerTarget {
    RunnerTarget(let packageName: String, let projectPath: String) {}
}

func commandIsTopLevelFunction(command: CommandInfo): Bool {
    !command.isConstructor && !command.isInstanceMethod && !command.isStaticMethod && command.className.isEmpty()
}

func collectSharedTopLevelFunctions(left: Manifest, right: Manifest): ArrayList<CommandInfo> {
    let leftCommands = HashMap<CommandInfo, Unit>()
    for (command in left.commands) {
        if (commandIsTopLevelFunction(command)) {
            leftCommands[command] = ()
        }
    }

    let sharedCommands = HashMap<CommandInfo, Unit>()
    for (command in right.commands) {
        if (!commandIsTopLevelFunction(command)) {
            continue
        }

        if (leftCommands.contains(command)) {
            sharedCommands[command] = ()
        }
    }

    let sortedCommands = ArrayList<CommandInfo>()
    for ((command, _) in sharedCommands) {
        sortedCommands.add(command)
    }
    sort(sortedCommands)

    let shared = ArrayList<CommandInfo>()
    for (command in sortedCommands) {
        shared.add(command)
    }
    shared
}

func buildInterfaces(commands: ArrayList<CommandInfo>): ArrayList<InterfaceDecl> {
    let interfaces = ArrayList<InterfaceDecl>()
    var currentPackageNameParts = Array<String>()
    let currentPackageCommands = ArrayList<Decl>()

    func flushCurrentPackage(): Unit {
        if (currentPackageNameParts.size == 0) {
            return
        }
        interfaces.add(InterfaceDecl(Body(currentPackageCommands.toArray()), None, [],
            interfaceNameFromPackageParts(currentPackageNameParts), []))
        currentPackageNameParts = Array<String>()
        currentPackageCommands.clear()
    }

    for (command in commands) {
        if (currentPackageNameParts.size == 0) {
            currentPackageNameParts = command.packageNameParts
        } else if (currentPackageNameParts != command.packageNameParts) {
            flushCurrentPackage()
            currentPackageNameParts = command.packageNameParts
        }
        currentPackageCommands.add(command.toFuncDecl())
    }

    flushCurrentPackage()
    interfaces
}

func renderInterfaces(commands: ArrayList<CommandInfo>): String {
    let interfaces = buildInterfaces(commands)
    var output = ""
    for (i in 0..interfaces.size) {
        if (i > 0) {
            output += "\n\n"
        }
        output += interfaces[i].toString()
    }
    output
}

func ensureCleanDirectory(path: String): Unit {
    if (exists(path)) {
        remove(path, recursive: true)
    }
    Directory.create(path, recursive: true)
}

func writeTextFile(path: String, content: String): Unit {
    File.writeTo(path, unsafe { content.rawData() })
}

func readTextFile(path: String): String {
    String.fromUtf8(File.readFrom(path))
}

func loadRunnerTarget(projectPath: String): RunnerTarget {
    let absoluteProjectPath = canonicalize(projectPath).toString()
    let decoder = Decoder()
    decoder.load(Path(absoluteProjectPath).join("cjpm.toml").toString())
    let root = decoder.decode()
    let packageValue = match (root.get("package")) {
        case Some(value) => value
        case None => throw Exception("missing package table in ${absoluteProjectPath}/cjpm.toml")
    }
    let packageObject = match (packageValue) {
        case objectValue: JsonObject => objectValue
        case _ => throw Exception("package table in ${absoluteProjectPath}/cjpm.toml must be an object")
    }
    let packageNameValue = match (packageObject.get("name")) {
        case Some(value) => value
        case None => throw Exception("missing package.name in ${absoluteProjectPath}/cjpm.toml")
    }
    let packageName = match (packageNameValue) {
        case stringValue: JsonString => stringValue.getValue()
        case _ => throw Exception("package.name in ${absoluteProjectPath}/cjpm.toml must be a string")
    }
    RunnerTarget(packageName, absoluteProjectPath)
}

func instantiateRunner(templateRoot: String, destinationRoot: String, target: RunnerTarget, commonRoot: String): Unit {
    ensureCleanDirectory(destinationRoot)
    copy(Path(templateRoot).join("src"), to: Path(destinationRoot).join("src"), overwrite: true)
    copy(Path(templateRoot).join("cjpm.toml"), to: Path(destinationRoot).join("cjpm.toml"), overwrite: true)

    let archivePath = "target/release/" + target.packageName + "/lib" + target.packageName + ".a"
    let replacements = [
        ("__RESTEST_TARGET_PACKAGE_NAME__", target.packageName),
        ("__RESTEST_TARGET_PACKAGE_PATH__", target.projectPath),
        ("__RESTEST_TARGET_ARCHIVE_PATH__", archivePath),
        ("../restest_common", commonRoot)
    ]

    for (relativePath in ["src/main.cj", "cjpm.toml"]) {
        let filePath = Path(destinationRoot).join(relativePath).toString()
        var content = readTextFile(filePath)
        for ((placeholder, value) in replacements) {
            content = content.replace(placeholder, value)
        }
        writeTextFile(filePath, content)
    }
}

func generationModeEnabled(): Bool {
    let args = getCommandLine()
    args.size > 1 && args[1] == "generate-runners"
}

func generateArtifacts(sharedCommands: ArrayList<CommandInfo>, leftTarget: RunnerTarget, rightTarget: RunnerTarget): Unit {
    let repoRoot = canonicalize("..").toString()
    let generatedRoot = Path(repoRoot).join(".generated").toString()
    let templateRunnerRoot = Path(repoRoot).join("runner").toString()
    let commonRoot = canonicalize(Path(repoRoot).join("restest_common")).toString()

    ensureCleanDirectory(generatedRoot)
    writeTextFile(Path(generatedRoot).join("shared-commands.cj").toString(), renderInterfaces(sharedCommands))
    instantiateRunner(templateRunnerRoot, Path(generatedRoot).join("runner-left").toString(), leftTarget, commonRoot)
    instantiateRunner(templateRunnerRoot, Path(generatedRoot).join("runner-right").toString(), rightTarget, commonRoot)
}

func requireManifest(outcome: ParseOutcome, projectPath: String): Option<Manifest> {
    match (outcome.manifest) {
        case Some(manifest) => Some(manifest)
        case None =>
            println("failed to parse project '${projectPath}': ${outcome.errorMessage}")
            None
    }
}

main() {
    let config = loadRestestConfig()
    let leftTarget = loadRunnerTarget(config.leftProjectPath)
    let rightTarget = loadRunnerTarget(config.rightProjectPath)
    let leftManifest = requireManifest(parsePackage(config.leftProjectPath), config.leftProjectPath)
    if (leftManifest.isNone()) {
        return 1
    }

    let rightManifest = requireManifest(parsePackage(config.rightProjectPath), config.rightProjectPath)
    if (rightManifest.isNone()) {
        return 1
    }

    let sharedCommands = collectSharedTopLevelFunctions(leftManifest.getOrThrow(), rightManifest.getOrThrow())
    if (generationModeEnabled()) {
        generateArtifacts(sharedCommands, leftTarget, rightTarget)
    } else {
        println(renderInterfaces(sharedCommands))
    }
    0
}

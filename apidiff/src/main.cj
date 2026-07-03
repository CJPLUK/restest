package restest_apidiff

import std.collection.*
import restest_apidiff.deps.*
import std.sort.*
import stdx.syntax.*

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

func joinStrings(parts: Array<String>, delimiter: String): String {
    var result = ""
    for (i in 0..parts.size) {
        if (i > 0) {
            result += delimiter
        }
        result += parts[i]
    }
    result
}

func interfaceNameFromPackageParts(packageNameParts: Array<String>): String {
    "Restest__" + joinStrings(packageNameParts, "__")
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
    let leftManifest = requireManifest(parsePackage(config.leftProjectPath), config.leftProjectPath)
    if (leftManifest.isNone()) {
        return 1
    }

    let rightManifest = requireManifest(parsePackage(config.rightProjectPath), config.rightProjectPath)
    if (rightManifest.isNone()) {
        return 1
    }

    let sharedCommands = collectSharedTopLevelFunctions(leftManifest.getOrThrow(), rightManifest.getOrThrow())
    let interfaces = buildInterfaces(sharedCommands)
    for (i in 0..interfaces.size) {
        if (i > 0) {
            println()
        }
        println(interfaces[i].toString())
    }
    0
}

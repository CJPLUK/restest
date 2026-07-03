package restest_apidiff

import std.collection.*
import restest_apidiff.deps.*
import std.sort.*

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

    for (signature in collectSharedTopLevelFunctions(leftManifest.getOrThrow(), rightManifest.getOrThrow())) {
        println(signature.displayText())
    }
    0
}

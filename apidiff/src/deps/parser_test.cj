/**
 * Parser unit tests: parsePackage on fixture package; failure cases.
 * Run from Clive repo root so fixture path test/fixtures/minimal_package is valid.
 */
package restest_apidiff.deps

import std.collection.*
import std.env.*
import std.unittest.*
import std.unittest.testmacro.*
import stdx.syntax.*

// Path to minimal fixture (relative to repo root). Set CLIVE_REPO_ROOT if running from elsewhere.
func _fixturePath(): String {
    match (getVariable("CLIVE_REPO_ROOT")) {
        case Option<String>.Some(root) => root + "/test/fixtures/minimal_package"
        case _ => "test/fixtures/minimal_package"
    }
}

func _genericFixturePath(): String {
    match (getVariable("CLIVE_REPO_ROOT")) {
        case Option<String>.Some(root) => root + "/test/fixtures/generic_package"
        case _ => "test/fixtures/generic_package"
    }
}

@Test
class ParserTests {
    @TestCase
    func parsePackageMinimalFixture() {
        let path: String = _fixturePath()
        let outcome: ParseOutcome = parsePackage(path)
        if (outcome.manifest.isNone()) {
            @Fail("parsePackage should succeed for minimal_package fixture at " + path + ": " + outcome.errorMessage)
        }
        let m: Manifest = outcome.manifest.getOrThrow()
        @Assert(m.commands.size >= 2)
        var hasHello: Bool = false
        var hasBox: Bool = false
        var i: Int64 = 0
        while (i < m.commands.size) {
            let cmd: CommandInfo = m.commands.get(i).getOrThrow()
            if (cmd.name == "hello") { hasHello = true }
            if (cmd.isConstructor && cmd.className == "Box") { hasBox = true }
            i++
        }
        @Assert(hasHello)
        @Assert(hasBox)
        // Package name is minimal_pkg when parser extracts it; otherwise default
        @Assert(m.packageQualifiedName.size > 0)
    }

    @TestCase
    func parsePackageInvalidPathReturnsNoneOrEmpty() {
        // Invalid path: expect failure (manifest None and errorMessage set) or empty commands
        let outcome: ParseOutcome = parsePackage("/nonexistent_path_abracadabra_12345")
        if (outcome.manifest.isSome()) {
            let m: Manifest = outcome.manifest.getOrThrow()
            @Assert(m.commands.size == 0)
        } else {
            @Assert(outcome.errorMessage.size > 0)
        }
    }

    @TestCase
    func parsePackageGenericCommands() {
        let path: String = _genericFixturePath()
        let outcome: ParseOutcome = parsePackage(path)
        if (outcome.manifest.isNone()) {
            @Fail("parsePackage should succeed for generic_package fixture at " + path + ": " + outcome.errorMessage)
        }
        let m: Manifest = outcome.manifest.getOrThrow()
        var foundIdentity: Bool = false
        var foundWrap: Bool = false
        var foundChoose: Bool = false
        var i: Int64 = 0
        while (i < m.commands.size) {
            let cmd: CommandInfo = m.commands.get(i).getOrThrow()
            if (cmd.name == "identity") {
                foundIdentity = true
                @Assert(cmd.genericParams.size == 1)
                @Assert(cmd.genericParams.get(0).getOrThrow().name == "T")
                @Assert(cmd.genericParams.get(0).getOrThrow().declaration.toString() == "T")
                @Assert(cmd.returnType.isSome())
            }
            if (cmd.name == "wrap") {
                foundWrap = true
                @Assert(cmd.genericParams.size == 2)
                @Assert(cmd.genericParams.get(0).getOrThrow().name == "T")
                @Assert(cmd.genericParams.get(1).getOrThrow().name == "U")
                @Assert(cmd.genericParams.get(1).getOrThrow().declaration.toString() == "U")
            }
            if (cmd.name == "choose") {
                foundChoose = true
                @Assert(cmd.isInstanceMethod)
                @Assert(cmd.params.size >= 1)
                @Assert(cmd.params.get(0).getOrThrow().paramName == "this")
                @Assert(cmd.params.get(0).getOrThrow().paramType.toString() == "Box")
                @Assert(cmd.genericParams.size == 1)
                @Assert(cmd.genericParams.get(0).getOrThrow().name == "T")
            }
            i++
        }
        @Assert(foundIdentity)
        @Assert(foundWrap)
        @Assert(foundChoose)
    }

    @TestCase
    func parsePackageConstructorReturnTypeIsNone() {
        let path: String = _fixturePath()
        let outcome: ParseOutcome = parsePackage(path)
        if (outcome.manifest.isNone()) {
            @Fail("parsePackage should succeed for minimal_package fixture at " + path + ": " + outcome.errorMessage)
        }

        let m: Manifest = outcome.manifest.getOrThrow()
        var foundConstructor: Bool = false
        var foundHello: Bool = false
        for (cmd in m.commands) {
            if (cmd.isConstructor && cmd.className == "Box") {
                foundConstructor = true
                @Assert(cmd.returnType.isNone())
                @Assert(cmd.params.size == 1)
                @Assert(cmd.params.get(0).getOrThrow().paramType.toString() == "String")
            }
            if (cmd.name == "hello") {
                foundHello = true
                @Assert(cmd.returnType.isSome())
                @Assert(cmd.returnType.getOrThrow().toString() == "String")
                @Assert(cmd.params.size > 0)
                @Assert(cmd.params.get(0).getOrThrow().paramType.toString().size > 0)
            }
        }
        @Assert(foundConstructor)
        @Assert(foundHello)
    }
}

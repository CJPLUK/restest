macro package restest.macros

import std.ast.*
import std.collection.*
import std.random.*
import stdx.syntax.{ AtomicType, AtomicTypeKind, CompositeType, TypeAnnotation }
import restest.deps.*

class GenerateImpl {
    public GenerateImpl(private let rand: Random) {}

    let arbitraryLeafTypes = [
        AtomicType(AtomicTypeKind.BoolType),
        AtomicType(AtomicTypeKind.Int32Type),
        AtomicType(AtomicTypeKind.Int64Type),
        AtomicType(AtomicTypeKind.Float32Type),
        AtomicType(AtomicTypeKind.Float64Type),
        CompositeType("String", [], [])
    ]

    func RandomIndex(bound: Int64): Int64 {
        rand.nextInt64(bound)
    }

    func CloneType(typeAnnotation: TypeAnnotation): TypeAnnotation {
        cloneTypeAnnotation(typeAnnotation)
    }

    func MakeRandomArbitraryLeafType(): TypeAnnotation {
        CloneType(arbitraryLeafTypes[RandomIndex(arbitraryLeafTypes.size)])
    }

    func MakeRandomTypeSubstitution(_: CommandInfo, genericParam: GenericParamInfo): TypeSubstitution {
        TypeSubstitution(genericParam.name, MakeRandomArbitraryLeafType())
    }

    func MakeRandomTypeSubstitutions(command: CommandInfo): Array<TypeSubstitution> {
        let substitutions = ArrayList<TypeSubstitution>()
        for (genericParam in command.genericParams) {
            substitutions.add(MakeRandomTypeSubstitution(command, genericParam))
        }
        substitutions.toArray()
    }

    func MakeRandomArgument(ty: TypeAnnotation): Expr {
        parseExpr(quote(arbitraryValue<$(ty.toTokens())>()))
    }

    func CanGenerateCall(specialized: SpecializedCommandSignature): Bool {
        if (specialized.returnType.isNone()) {
            return false
        }
        for (param in specialized.params) {
            if (param.paramName == "this") {
                return false
            }
        }
        true
    }

    func CanCallCommand(command: CommandInfo): Bool {
        if (command.isConstructor || command.isInstanceMethod || command.isStaticMethod) {
            return false
        }

        for (param in command.params) {
            if (typeAnnotationContainsFuncType(param.paramType)) {
                return false
            }
        }
        if (typeAnnotationContainsFuncType(command.returnType)) {
            return false
        }
        true
    }

    func RandomCommandIndex(commandCount: Int64): Int64 {
        rand.nextInt64(commandCount)
    }

    public func MakeRandomCall(command: CommandInfo): Option<Tokens> {
        if (!CanCallCommand(command)) {
            return None
        }

        let substitutions = MakeRandomTypeSubstitutions(command)
        let specialized = specializeCommandSignature(command, substitutions)
        if (!CanGenerateCall(specialized)) {
            return None
        }

        // 2. Pick random arguments.
        let args = ArrayList<Argument>()
        for (param in specialized.params) {
            let arg = Argument()
            arg.expr = MakeRandomArgument(param.paramType)
            args.add(arg)
        }
        Option<Tokens>.Some(Token(IDENTIFIER, command.name) + quote(($(args))))
    }

    public func MakeRandomCall(commands: ArrayList<CommandInfo>): Option<Tokens> {
        if (commands.size == 0) {
            return None
        }

        let start = RandomCommandIndex(commands.size)
        var offset: Int64 = 0
        while (offset < commands.size) {
            let index = (start + offset) % commands.size
            if (let Some(callTokens) <- MakeRandomCall(commands[index])) {
                return Option<Tokens>.Some(callTokens)
            }
            offset += 1
        }
        None
    }
}

func varExpr(name: Token): Expr {
    parseExpr(Tokens([name]))
}

func makeGeneratedTuple(names: ArrayList<Token>): Expr {
    if (names.size == 0) {
        return parseExpr(quote(()))
    }

    if (names.size == 1) {
        return varExpr(names[0])
    }

    let tuple = TupleLiteral()
    let elements = ArrayList<Expr>()
    for (name in names) {
        elements.add(varExpr(name))
    }
    tuple.elements = elements
    tuple
}

func parseGenerateNames(input: Tokens): ArrayList<Token> {
    if (input.size < 2 || input[0].kind != LSQUARE || input[input.size - 1].kind != RSQUARE) {
        throw Exception("@Generate expects an array literal of variable names.")
    }

    let names = ArrayList<Token>()
    var index: Int64 = 1
    let end: Int64 = input.size - 1
    while (index < end) {
        let name = input[index]
        if (name.kind != IDENTIFIER) {
            throw Exception("@Generate expects identifiers inside the array literal.")
        }
        names.add(Token(IDENTIFIER, name.value))
        index += 1
        if (index == end) {
            break
        }
        if (input[index].kind != COMMA) {
            throw Exception("@Generate expects comma-separated variable names.")
        }
        index += 1
    }
    names
}

public macro Generate(input: Tokens): Tokens {
    let names = parseGenerateNames(input)

    let outcome: ParseOutcome = parsePackage("./test-test")
    if (outcome.manifest.isNone()) {
        println(outcome.errorMessage)
        return Tokens()
    }

    let manifest: Manifest = outcome.manifest.getOrThrow()
    let generateImpl = GenerateImpl(Random())

    let block = Block()
    for (name in names) {
        if (let Some(callTokens) <- generateImpl.MakeRandomCall(manifest.commands)) {
            block.nodes.add(parseDecl(quote(let $name = $callTokens)))
        } else {
            throw Exception("@Generate could not find any generatable command.")
        }
    }
    block.nodes.add(makeGeneratedTuple(names))
    block.toTokens()
}

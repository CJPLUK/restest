macro package restest.macros

import std.ast.*
import std.collection.*
import std.random.*
import stdx.syntax.{ AtomicType, AtomicTypeKind, CompositeType, TypeAnnotation }
import restest.deps.*

struct WithType<T> {
    public WithType(public let value: T, public let typeAnnotation: TypeAnnotation) {}

    public func map<U>(f: (T) -> U): WithType<U> {
        WithType(f(value), typeAnnotation)
    }
}

type GeneratedBinding = WithType<Token>
type GeneratedCall = WithType<Tokens>

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

    func TypeKey(typeAnnotation: TypeAnnotation): String {
        typeAnnotation.toTokens().toString()
    }

    func FindMatchingBindings(ty: TypeAnnotation, previousBindings: ArrayList<GeneratedBinding>): ArrayList<GeneratedBinding> {
        let matches = ArrayList<GeneratedBinding>()
        let key = TypeKey(ty)
        for (binding in previousBindings) {
            if (TypeKey(binding.typeAnnotation) == key) {
                matches.add(binding)
            }
        }
        matches
    }

    func MakeRandomArgument(ty: TypeAnnotation, previousBindings: ArrayList<GeneratedBinding>): Expr {
        let matches = FindMatchingBindings(ty, previousBindings)
        if (matches.size > 0 && RandomIndex(2) == 0) {
            let binding = matches[RandomIndex(matches.size)]
            return RefExpr(Tokens(binding.value))
        }
        MakeRandomArgument(ty)
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

    public func MakeRandomCall(command: CommandInfo, previousBindings: ArrayList<GeneratedBinding>): Option<GeneratedCall> {
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
            arg.expr = MakeRandomArgument(param.paramType, previousBindings)
            args.add(arg)
        }
        Some(GeneratedCall(Token(IDENTIFIER, command.name) + quote(($(args))),
            specialized.returnType.getOrThrow()))
    }

    public func MakeRandomCall(commands: ArrayList<CommandInfo>, previousBindings: ArrayList<GeneratedBinding>): Option<GeneratedCall> {
        if (commands.size == 0) {
            return None
        }

        let start = RandomCommandIndex(commands.size)
        var offset: Int64 = 0
        while (offset < commands.size) {
            let index = (start + offset) % commands.size
            let maybeCall = MakeRandomCall(commands[index], previousBindings)
            if (maybeCall.isSome()) {
                return maybeCall
            }
            offset += 1
        }
        None
    }
}

func makeGeneratedTuple(names: Tokens): Expr {
    let tuple = TupleLiteral()
    let elements = ArrayList<Expr>()
    for (name in names) {
        elements.add(RefExpr(Tokens(name)))
    }
    tuple.elements = elements
    tuple
}

public macro Generate(input: Tokens): Tokens {
    let outcome: ParseOutcome = parsePackage("./test-test")
    if (outcome.manifest.isNone()) {
        println(outcome.errorMessage)
        return Tokens()
    }

    let manifest: Manifest = outcome.manifest.getOrThrow()
    let generateImpl = GenerateImpl(Random())
    let previousBindings = ArrayList<GeneratedBinding>()

    let block = Block()
    for (name in input) {
        if (let Some(call) <- generateImpl.MakeRandomCall(manifest.commands, previousBindings)) {
            block.nodes.add(parseDecl(quote(let $name = $(call.value))))
            previousBindings.add(GeneratedBinding(name, call.typeAnnotation))
        } else {
            throw Exception("@Generate could not find any generatable command.")
        }
    }
    block.nodes.add(makeGeneratedTuple(input))
    block.toTokens()
}

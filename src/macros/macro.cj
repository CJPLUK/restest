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

    func DefaultInferenceType(): TypeAnnotation {
        AtomicType(AtomicTypeKind.Int64Type)
    }

    func MakeRandomArbitraryType(depth: Int64): TypeAnnotation {
        if (depth <= 0) {
            return MakeRandomArbitraryLeafType()
        }

        match (RandomIndex(4)) {
            case 0 => CompositeType("Option", [], [MakeRandomArbitraryType(depth - 1)])
            case 1 => CompositeType("Array", [], [MakeRandomArbitraryType(depth - 1)])
            case _ => MakeRandomArbitraryLeafType()  // probability 1/2
        }
    }

    func MakeRandomTypeSubstitution(command: CommandInfo, genericParam: GenericParamInfo): TypeSubstitution {
        if (typeAnnotationContainsUnqualifiedName(command.returnType, genericParam.name)) {
            return TypeSubstitution(genericParam.name, DefaultInferenceType())
        }
        TypeSubstitution(genericParam.name, MakeRandomArbitraryType(2))
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

            match (param.paramType) {
                case _: FuncType => return false
                case _ => ()
            }
        }
        true
    }

    func CanCallCommand(command: CommandInfo): Bool {
        !(command.isConstructor || command.isInstanceMethod || command.isStaticMethod)
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
}

public macro Generate(input: Tokens): Tokens {
    if (input.size != 0) {
        throw Exception("@Generate expects no arguments.")
    }

    let outcome: ParseOutcome = parsePackage("./test-test")
    if (outcome.manifest.isNone()) {
        println(outcome.errorMessage)
        return Tokens()
    }

    let manifest: Manifest = outcome.manifest.getOrThrow()
    let generateImpl = GenerateImpl(Random())
    for (command in manifest.commands) {
        if (let Some(callTokens) <- generateImpl.MakeRandomCall(command)) {
            return callTokens
        }
    }
    Tokens()
}

macro package restest_runner.macros

import std.ast.*
import std.collection.*
import std.random.*
import restest_common.*
import stdx.syntax.{ AtomicType, AtomicTypeKind, CompositeType, TypeAnnotation }
import stdx.syntax.Argument as StdxArgument
import stdx.syntax.Block as StdxBlock
import stdx.syntax.CallExpr as StdxCallExpr
import stdx.syntax.Expr as StdxExpr
import stdx.syntax.FuncDecl as StdxFuncDecl
import stdx.syntax.FuncKind as StdxFuncKind
import stdx.syntax.FuncParam as StdxFuncParam
import stdx.syntax.FuncType as StdxFuncType
import stdx.syntax.GenericParam as StdxGenericParam
import stdx.syntax.MemberAccess as StdxMemberAccess
import stdx.syntax.Parameter as StdxParameter
import stdx.syntax.ParameterList as StdxParameterList
import stdx.syntax.SymbolRef as StdxSymbolRef
import stdx.syntax.SyntaxTreeNode as StdxSyntaxTreeNode
import restest_runner.deps.*

struct WithType<T> {
    public WithType(public let value: T, public let typeAnnotation: TypeAnnotation) {}

    public func map<U>(f: (T) -> U): WithType<U> {
        WithType(f(value), typeAnnotation)
    }
}

type GeneratedBinding = WithType<Token>

struct GeneratedCall {
    public GeneratedCall(public let value: Tokens, public let typeAnnotation: TypeAnnotation, public let trace: String) {}
}

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
        let traceName = command.name.replace("restest__", "")
        Some(GeneratedCall(Token(IDENTIFIER, command.name) + quote(($(args))),
            specialized.returnType.getOrThrow(), traceName + "(...)"))
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

func wrapFunctionParamType(typeAnnotation: TypeAnnotation): Option<TypeAnnotation> {
    match (typeAnnotation) {
        case funcType: StdxFuncType =>
            let typeArguments = ArrayList<TypeAnnotation>()
            for (paramType in funcType.paramTypes) {
                typeArguments.add(paramType)
            }
            typeArguments.add(funcType.retType)
            match (funcType.paramTypes.size) {
                case 0 => Some(CompositeType("Func0", [], typeArguments.toArray()))
                case 1 => Some(CompositeType("Func1", [], typeArguments.toArray()))
                case 2 => Some(CompositeType("Func2", [], typeArguments.toArray()))
                case _ => None
            }
        case _ => Some(typeAnnotation)
    }
}

func libToWrappers(commands: ArrayList<CommandInfo>): (ArrayList<CommandInfo>, ArrayList<Node>) {
    let wrappedCommands = ArrayList<CommandInfo>()
    let bindings = ArrayList<Node>()
    for (command in commands) {
        if (command.isConstructor || command.isInstanceMethod || command.isStaticMethod) {
            continue
        }
        let wrappedName = "restest__" + command.name
        let wrappedParams = ArrayList<ParamInfo>(command.params.size)
        let funcParams = ArrayList<StdxParameter>(command.params.size)
        let callArgs = ArrayList<StdxArgument>(command.params.size)
        var supported = true
        for (param in command.params) {
            let wrappedType = wrapFunctionParamType(param.paramType)
            if (wrappedType.isNone()) {
                supported = false
                break
            }

            let paramType = wrappedType.getOrThrow()
            wrappedParams.add(ParamInfo(param.paramName, paramType))
            let funcParam = StdxFuncParam(None, None, param.paramName, paramType)
            funcParams.add(funcParam)

            let argValue: StdxExpr = match (param.paramType) {
                case _: StdxFuncType =>
                    StdxMemberAccess(StdxSymbolRef(param.paramName, []), StdxSymbolRef("call", []))
                case _ => StdxSymbolRef(param.paramName, [])
            }
            let arg = StdxArgument(None, false, argValue)
            callArgs.add(arg)
        }

        if (!supported) {
            continue
        }

        let wrappedCommand = CommandInfo(wrappedName, command.packageNameParts, command.genericParams,
            command.isConstructor, command.className, wrappedParams, command.returnType, command.returnIsRef,
            command.isInstanceMethod, command.isStaticMethod)
        wrappedCommands.add(wrappedCommand)

        let genericParams = ArrayList<StdxGenericParam>(command.genericParams.size)
        for (genericParam in command.genericParams) {
            genericParams.add(genericParam.declaration)
        }

        let syntaxCall = StdxCallExpr(StdxSymbolRef(command.name, []), callArgs.toArray())
        let syntaxNodes = ArrayList<StdxSyntaxTreeNode>()
        syntaxNodes.add(syntaxCall)
        let syntaxBlock = StdxBlock(syntaxNodes.toArray())
        let syntaxWrapper = StdxFuncDecl(Some(syntaxBlock), None, genericParams.toArray(), StdxFuncKind.Normal,
            wrappedName, StdxParameterList(funcParams.toArray()), command.returnType)
        bindings.add(parseDecl(syntaxWrapper.toTokens()))
    }
    (wrappedCommands, bindings)
}

public macro Generate(input: Tokens): Tokens {
    let config = loadRestestConfig()
    let commands = loadCommandsFromInterfaces(config.commandsPath)
    let (wrappedCommands, bindings) = libToWrappers(commands)
    let generateImpl = GenerateImpl(Random(config.seed))
    let previousBindings = ArrayList<GeneratedBinding>()

    let block = Block()
    block.nodes.add(all: bindings)
    let typeMapping = HashMap<String, TypeAnnotation>()
    for (name in input) {
        if (let Some(call) <- generateImpl.MakeRandomCall(wrappedCommands, previousBindings)) {
            let name_resumption = Token(IDENTIFIER, name.value + "_resumption")
            let name_trace = Token(IDENTIFIER, name.value + "_trace")
            typeMapping.add(name.value, call.typeAnnotation)
            block.nodes.add(parseDecl(quote(let $name_trace = $(Token(STRING_LITERAL, call.trace)))))
            block.nodes.add(parseDecl(quote(let $name_resumption = Box(None<Resumption<Unit, ?$(call.typeAnnotation)>>))))
            block.nodes.add(parseDecl(quote(var $name =
                try {
                    Some($(call.value))
                } handle(_: Switch, r: Resumption<Unit, ?$(call.typeAnnotation)>) {
                    $name_resumption.value = Some(r)
                    None<$(call.typeAnnotation)>
                })))
            // previousBindings.add(GeneratedBinding(name, call.typeAnnotation))
        } else {
            throw Exception("@Generate could not find any generatable command.")
        }
    }
    for (name in input) {
        let name_resumption = Token(IDENTIFIER, name.value + "_resumption")
        block.nodes.add(parseExpr(quote(
            if (let Some(r) <- $name_resumption.value) {
                $name_resumption.value = None<Resumption<Unit, ?$(typeMapping[name.value])>>
                $name = resume r
            })))
    }
    let tupleExpr = makeGeneratedTuple(input)
    block.nodes.add(parseDecl(quote(let _ = $tupleExpr)))
    block.toTokens()
}

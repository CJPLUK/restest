/**
 * Helpers for specializing stdx.syntax generic type annotations and function signatures.
 * This is a syntactic substitution layer only; it does not resolve names or type-check bodies.
 */
package restest.deps

import std.collection.ArrayList
import stdx.syntax.*

public class TypeSubstitution {
    public let typeParamName: String
    public let replacement: TypeAnnotation

    public init(typeParamName: String, replacement: TypeAnnotation) {
        this.typeParamName = typeParamName
        this.replacement = replacement
    }
}

public class SpecializedFuncSignature {
    public let params: ParameterList
    public let returnType: Option<TypeAnnotation>

    public init(params: ParameterList, returnType: Option<TypeAnnotation>) {
        this.params = params
        this.returnType = returnType
    }
}

public class SpecializedCommandSignature {
    public let params: ArrayList<ParamInfo>
    public let returnType: Option<TypeAnnotation>

    public init(params: ArrayList<ParamInfo>, returnType: Option<TypeAnnotation>) {
        this.params = params
        this.returnType = returnType
    }
}

func findSubstitution(typeParamName: String, substitutions: Array<TypeSubstitution>): Option<TypeAnnotation> {
    for (substitution in substitutions) {
        if (substitution.typeParamName == typeParamName) {
            return Option<TypeAnnotation>.Some(cloneTypeAnnotation(substitution.replacement))
        }
    }
    None
}

public func cloneTypeAnnotation(typeAnnotation: TypeAnnotation): TypeAnnotation {
    substituteTypeAnnotation(typeAnnotation, [])
}

public func substituteOptionalTypeAnnotation(typeAnnotation: Option<TypeAnnotation>,
    substitutions: Array<TypeSubstitution>): Option<TypeAnnotation> {
    if (let Some(ty) <- typeAnnotation) {
        return Option<TypeAnnotation>.Some(substituteTypeAnnotation(ty, substitutions))
    }
    None
}

public func typeAnnotationContainsUnqualifiedName(typeAnnotation: Option<TypeAnnotation>, name: String): Bool {
    if (let Some(ty) <- typeAnnotation) {
        return typeAnnotationContainsUnqualifiedName(ty, name)
    }
    false
}

public func typeAnnotationContainsUnqualifiedName(typeAnnotation: TypeAnnotation, name: String): Bool {
    match (typeAnnotation) {
        case ty: CompositeType =>
            if (ty.prefixes.size == 0 && ty.name == name) {
                return true
            }
            for (typeArgument in ty.typeArguments) {
                if (typeAnnotationContainsUnqualifiedName(typeArgument, name)) {
                    return true
                }
            }
            false
        case ty: FuncType =>
            for (paramType in ty.paramTypes) {
                if (typeAnnotationContainsUnqualifiedName(paramType, name)) {
                    return true
                }
            }
            typeAnnotationContainsUnqualifiedName(ty.retType, name)
        case ty: PrefixType => typeAnnotationContainsUnqualifiedName(ty.base, name)
        case _: AtomicType => false
        case ty: ParenType => typeAnnotationContainsUnqualifiedName(ty.subType, name)
        case ty: TupleType =>
            for (element in ty.elements) {
                if (typeAnnotationContainsUnqualifiedName(element, name)) {
                    return true
                }
            }
            false
        case ty: VArrayType => typeAnnotationContainsUnqualifiedName(ty.elementType, name)
        case _ => false
    }
}

public func substituteTypeAnnotation(typeAnnotation: TypeAnnotation,
    substitutions: Array<TypeSubstitution>): TypeAnnotation {
    match (typeAnnotation) {
        case ty: CompositeType =>
            if (ty.prefixes.size == 0 && ty.typeArguments.size == 0) {
                if (let Some(replacement) <- findSubstitution(ty.name, substitutions)) {
                    return replacement
                }
            }

            let typeArguments = ArrayList<TypeAnnotation>()
            for (typeArgument in ty.typeArguments) {
                typeArguments.add(substituteTypeAnnotation(typeArgument, substitutions))
            }
            CompositeType(ty.name, ty.prefixes, typeArguments.toArray())
        case ty: FuncType =>
            let paramTypes = ArrayList<TypeAnnotation>()
            for (paramType in ty.paramTypes) {
                paramTypes.add(substituteTypeAnnotation(paramType, substitutions))
            }
            FuncType(paramTypes.toArray(), ty.labels, substituteTypeAnnotation(ty.retType, substitutions))
        case ty: PrefixType =>
            PrefixType(substituteTypeAnnotation(ty.base, substitutions), ty.prefixTypeOpKind)
        case ty: AtomicType => AtomicType(ty.kind)
        case ty: ParenType => ParenType(substituteTypeAnnotation(ty.subType, substitutions))
        case ty: TupleType =>
            let elements = ArrayList<TypeAnnotation>()
            for (element in ty.elements) {
                elements.add(substituteTypeAnnotation(element, substitutions))
            }
            TupleType(ty.labels, elements.toArray())
        case ty: VArrayType =>
            VArrayType(substituteTypeAnnotation(ty.elementType, substitutions), ty.size)
        case _ => cloneTypeAnnotationViaText(typeAnnotation)
    }
}

func cloneTypeAnnotationViaText(typeAnnotation: TypeAnnotation): TypeAnnotation {
    let parsed = parseTokens(typeAnnotation.toTokens())
    if (let Some(node) <- parsed.node) {
        if (let Some(ty) <- (node as TypeAnnotation)) {
            return ty
        }
    }
    throw Exception("failed to clone type annotation: " + typeAnnotation.toString())
}

func specializeParameter(parameter: Parameter, substitutions: Array<TypeSubstitution>): Parameter {
    match (parameter) {
        case funcParam: FuncParam =>
            FuncParam(funcParam.defaultValue, funcParam.kind, funcParam.name,
                substituteTypeAnnotation(funcParam.typeAnnotation, substitutions), annotations: funcParam.annotations,
                modifiers: funcParam.modifiers)
        case lambdaParam: LambdaParam =>
            LambdaParam(lambdaParam.name, substituteOptionalTypeAnnotation(lambdaParam.typeAnnotation, substitutions))
        case _ => parameter
    }
}

public func specializeParameterList(params: ParameterList, substitutions: Array<TypeSubstitution>): ParameterList {
    let specializedParams = ArrayList<Parameter>()
    for (parameter in params.params) {
        specializedParams.add(specializeParameter(parameter, substitutions))
    }
    ParameterList(specializedParams.toArray(), hasParen: params.getParamsLParenPos().isSome())
}

public func specializeFuncSignature(fd: FuncDecl, substitutions: Array<TypeSubstitution>): SpecializedFuncSignature {
    SpecializedFuncSignature(specializeParameterList(fd.params, substitutions),
        substituteOptionalTypeAnnotation(fd.retTyAnnotation, substitutions))
}

public func specializeCommandSignature(command: CommandInfo,
    substitutions: Array<TypeSubstitution>): SpecializedCommandSignature {
    let specializedParams = ArrayList<ParamInfo>()
    for (param in command.params) {
        specializedParams.add(ParamInfo(param.paramName, substituteTypeAnnotation(param.paramType, substitutions)))
    }
    SpecializedCommandSignature(specializedParams,
        substituteOptionalTypeAnnotation(command.returnType, substitutions))
}

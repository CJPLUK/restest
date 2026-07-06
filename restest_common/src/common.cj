package restest_common

import std.collection.*
import std.fs.*
import stdx.syntax.*

public class CommandInfo <: Comparable<CommandInfo> & Hashable {
    public let name: String
    public let packageNameParts: Array<String>
    public let genericParams: ArrayList<GenericParamInfo>
    public let isConstructor: Bool
    public let className: String
    public let params: ArrayList<ParamInfo>
    public let returnType: Option<TypeAnnotation>
    public let returnIsRef: Bool
    public let isInstanceMethod: Bool
    public let isStaticMethod: Bool

    public init(name: String, packageNameParts: Array<String>, genericParams: ArrayList<GenericParamInfo>,
        isConstructor: Bool, className: String, params: ArrayList<ParamInfo>, returnType: Option<TypeAnnotation>,
        returnIsRef: Bool, isInstanceMethod: Bool, isStaticMethod: Bool) {
        this.name = name
        this.packageNameParts = packageNameParts
        this.genericParams = genericParams
        this.isConstructor = isConstructor
        this.className = className
        this.params = params
        this.returnType = returnType
        this.returnIsRef = returnIsRef
        this.isInstanceMethod = isInstanceMethod
        this.isStaticMethod = isStaticMethod
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        var hash = name.hashCode()
        for (packageNamePart in packageNameParts) {
            hash = 31 * hash + packageNamePart.hashCode()
        }
        for (genericParam in genericParams) {
            hash = 31 * hash + genericParam.name.hashCode()
        }
        for (param in params) {
            hash = 31 * hash + typeAnnotationHashCode(param.paramType)
        }
        hash = 31 * hash + optionalTypeAnnotationHashCode(returnType)
        return hash
    }

    public operator func ==(that: CommandInfo): Bool {
        if (this.packageNameParts != that.packageNameParts || this.name != that.name ||
            this.genericParams.size != that.genericParams.size || this.params.size != that.params.size) {
            return false
        }
        for (i in 0..genericParams.size) {
            if (this.genericParams[i].name != that.genericParams[i].name) {
                return false
            }
        }
        for (i in 0..params.size) {
            if (!typeAnnotationEquals(this.params[i].paramType, that.params[i].paramType)) {
                return false
            }
        }
        optionalTypeAnnotationEquals(this.returnType, that.returnType)
    }

    public func compare(other: CommandInfo): Ordering {
        let packageCompare = compareStringArrays(this.packageNameParts, other.packageNameParts)
        if (packageCompare != EQ) {
            return packageCompare
        }
        this.displayText().compare(other.displayText())
    }

    public func toFuncDecl(): FuncDecl {
        let syntaxGenericParams = ArrayList<GenericParam>()
        for (genericParam in genericParams) {
            syntaxGenericParams.add(GenericParam(genericParam.name))
        }

        let syntaxParams = ArrayList<Parameter>()
        for (param in params) {
            syntaxParams.add(FuncParam(None, None, param.paramName, param.paramType))
        }

        FuncDecl(None, None, syntaxGenericParams.toArray(), FuncKind.Normal, name,
            ParameterList(syntaxParams.toArray()), returnType)
    }

    public func displayText(): String {
        toFuncDecl().toString()
    }
}

public class GenericParamInfo {
    public let name: String
    public let declaration: GenericParam

    public init(name: String, declaration: GenericParam) {
        this.name = name
        this.declaration = declaration
    }
}

public class ParamInfo {
    public let paramName: String
    public let paramType: TypeAnnotation

    public init(paramName: String, paramType: TypeAnnotation) {
        this.paramName = paramName
        this.paramType = paramType
    }
}

public func compareStringArrays(left: Array<String>, right: Array<String>): Ordering {
    let commonSize = min(left.size, right.size)
    for (i in 0..commonSize) {
        let itemCompare = left[i].compare(right[i])
        if (itemCompare != EQ) {
            return itemCompare
        }
    }
    left.size.compare(right.size)
}

public func packageNameFromParts(parts: Array<String>): String {
    var packageName = ""
    for (i in 0..parts.size) {
        if (i > 0) {
            packageName += "."
        }
        packageName += parts[i]
    }
    packageName
}

public func interfaceNameFromPackageParts(packageNameParts: Array<String>): String {
    "Restest__" + joinStrings(packageNameParts, "__")
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

func decodeInterfaceName(name: String): Option<Array<String>> {
    let prefix = "Restest__"
    if (name.size <= prefix.size || name[..prefix.size] != prefix) {
        return None
    }

    let parts = ArrayList<String>()
    var start = prefix.size
    var i = start
    while (i < name.size) {
        if (i + 1 < name.size && name[i..i + 1] == "_" && name[i + 1..i + 2] == "_") {
            if (i == start) {
                return None
            }
            parts.add(name[start..i])
            i += 2
            start = i
            continue
        }
        i += 1
    }

    if (start >= name.size) {
        return None
    }
    parts.add(name[start..name.size])
    Some(parts.toArray())
}

func getGenericParamList(fd: FuncDecl): ArrayList<GenericParamInfo> {
    let result = ArrayList<GenericParamInfo>()
    for (genericParam in fd.genericParams) {
        result.add(GenericParamInfo(genericParam.name, genericParam))
    }
    result
}

func getParamList(fd: FuncDecl): ArrayList<ParamInfo> {
    let list = ArrayList<ParamInfo>()
    for (param in fd.params.params) {
        match (param) {
            case fp: FuncParam => list.add(ParamInfo(fp.name, fp.typeAnnotation))
            case _ => ()
        }
    }
    list
}

public func loadCommandsFromInterfaces(path: String): ArrayList<CommandInfo> {
    var content = String.fromUtf8(File.readFrom(path))
    content = content.replace("\ncjpm run finished\n", "\n")
    content = content.replace("\ncjpm run finished", "")
    content = "package restest_common_generated\n\n" + content
    let cleanedPath = path + ".restest_common_cleaned.cj"
    File.writeTo(cleanedPath, unsafe { content.rawData() })
    let result = parseFile(cleanedPath)
    var hasError = false
    for (diag in result.diags) {
        match (diag.diagInfo) {
            case DiagnosticInfo.Error(_, _) =>
                hasError = true
                break
            case _ => ()
        }
    }
    if (result.node.isNone() || hasError) {
        throw Exception("failed to parse command file: ${path}")
    }

    let commands = ArrayList<CommandInfo>()
    let file = result.node.getOrThrow()
    for (decl in file.topLevelDecls) {
        match (decl) {
            case interfaceDecl: InterfaceDecl =>
                let packageNameParts = decodeInterfaceName(interfaceDecl.name)
                if (packageNameParts.isNone()) {
                    throw Exception("invalid restest interface name: ${interfaceDecl.name}")
                }
                for (memberDecl in interfaceDecl.body.memberDecls) {
                    match (memberDecl) {
                        case fd: FuncDecl =>
                            match (fd.kind) {
                                case FuncKind.Normal =>
                                    let genericParams = getGenericParamList(fd)
                                    let params = getParamList(fd)
                                    let returnType = fd.retTyAnnotation
                                    commands.add(CommandInfo(fd.name, packageNameParts.getOrThrow(), genericParams,
                                        false, "", params, returnType, isRefType(returnType), false, false))
                                case _ =>
                                    throw Exception("unexpected non-normal function in command file: ${fd.toString()}")
                            }
                        case _ => throw Exception("unexpected non-function interface member in command file")
                    }
                }
            case _ => throw Exception("unexpected top-level declaration in command file")
        }
    }
    commands
}

func _isSimpleValueTypeName(name: String): Bool {
    name == "String" || name == "Int64" || name == "Int32" || name == "Float64" || name == "Float32" ||
        name == "Bool" || name == "Unit"
}

public func isRefType(typeAnnotation: Option<TypeAnnotation>): Bool {
    if (typeAnnotation.isNone()) {
        return false
    }

    match (typeAnnotation.getOrThrow()) {
        case _: AtomicType => false
        case ty: CompositeType =>
            if (ty.prefixes.size == 0 && (ty.name == "Option" || _isSimpleValueTypeName(ty.name))) {
                return false
            }
            true
        case ty: PrefixType => isRefType(Option<TypeAnnotation>.Some(ty.base))
        case ty: ParenType => isRefType(Option<TypeAnnotation>.Some(ty.subType))
        case _: TupleType => true
        case _: FuncType => true
        case _: VArrayType => true
        case _ => true
    }
}

func optionalTypeAnnotationEquals(left: Option<TypeAnnotation>, right: Option<TypeAnnotation>): Bool {
    if (let Some(leftType) <- left) {
        if (let Some(rightType) <- right) {
            return typeAnnotationEquals(leftType, rightType)
        }
        return false
    }
    right.isNone()
}

func typeAnnotationEquals(left: TypeAnnotation, right: TypeAnnotation): Bool {
    match ((left, right)) {
        case lr: (AtomicType, AtomicType) =>
            let (leftType, rightType) = lr
            leftType.toString() == rightType.toString()
        case lr: (CompositeType, CompositeType) =>
            let (leftType, rightType) = lr
            leftType.name == rightType.name && leftType.prefixes == rightType.prefixes &&
                typeAnnotationArrayEquals(leftType.typeArguments, rightType.typeArguments)
        case lr: (PrefixType, PrefixType) =>
            let (leftType, rightType) = lr
            leftType.toString() == rightType.toString() && typeAnnotationEquals(leftType.base, rightType.base)
        case lr: (ParenType, ParenType) =>
            let (leftType, rightType) = lr
            typeAnnotationEquals(leftType.subType, rightType.subType)
        case lr: (TupleType, TupleType) =>
            let (leftType, rightType) = lr
            leftType.labels == rightType.labels &&
                typeAnnotationArrayEquals(leftType.elements, rightType.elements)
        case lr: (FuncType, FuncType) =>
            let (leftType, rightType) = lr
            leftType.labels == rightType.labels &&
                typeAnnotationArrayEquals(leftType.paramTypes, rightType.paramTypes) &&
                typeAnnotationEquals(leftType.retType, rightType.retType)
        case lr: (VArrayType, VArrayType) =>
            let (leftType, rightType) = lr
            leftType.size == rightType.size && typeAnnotationEquals(leftType.elementType, rightType.elementType)
        case _ => false
    }
}

func typeAnnotationArrayEquals(left: Array<TypeAnnotation>, right: Array<TypeAnnotation>): Bool {
    if (left.size != right.size) {
        return false
    }
    for (i in 0..left.size) {
        if (!typeAnnotationEquals(left[i], right[i])) {
            return false
        }
    }
    true
}

@OverflowWrapping
func optionalTypeAnnotationHashCode(typeAnnotation: Option<TypeAnnotation>): Int64 {
    match (typeAnnotation) {
        case Some(ty) => 31 + typeAnnotationHashCode(ty)
        case None => 0
    }
}

@OverflowWrapping
func typeAnnotationHashCode(typeAnnotation: TypeAnnotation): Int64 {
    match (typeAnnotation) {
        case ty: AtomicType => ty.toString().hashCode()
        case ty: CompositeType =>
            var hash = ty.name.hashCode()
            for (prefix in ty.prefixes) {
                hash = 31 * hash + prefix.hashCode()
            }
            for (typeArgument in ty.typeArguments) {
                hash = 31 * hash + typeAnnotationHashCode(typeArgument)
            }
            hash
        case ty: PrefixType => 31 * ty.toString().hashCode() + typeAnnotationHashCode(ty.base)
        case ty: ParenType => 31 * typeAnnotationHashCode(ty.subType)
        case ty: TupleType =>
            var hash = 7
            for (label in ty.labels) {
                hash = 31 * hash + label.hashCode()
            }
            for (element in ty.elements) {
                hash = 31 * hash + typeAnnotationHashCode(element)
            }
            hash
        case ty: FuncType =>
            var hash = 11
            for (label in ty.labels) {
                hash = 31 * hash + label.hashCode()
            }
            for (paramType in ty.paramTypes) {
                hash = 31 * hash + typeAnnotationHashCode(paramType)
            }
            31 * hash + typeAnnotationHashCode(ty.retType)
        case ty: VArrayType => 31 * ty.size.hashCode() + typeAnnotationHashCode(ty.elementType)
        case _ => typeAnnotation.toString().hashCode()
    }
}

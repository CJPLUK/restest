/**
 * Source parser for Cangjie package: extracts package name, public functions, and public constructors.
 * Uses stdx.syntax for parsing; outputs a manifest for the code generator.
 */
package restest_apidiff.deps

import std.fs.*
import std.collection.ArrayList
import stdx.syntax.*

// Result of parsing a package: either success (manifest present) or failure (errorMessage set).
public class ParseOutcome {
    public let manifest: Option<Manifest>
    public let errorMessage: String

    public init(manifest: Option<Manifest>, errorMessage: String) {
        this.manifest = manifest
        this.errorMessage = errorMessage
    }
}

// Manifest: package name + list of commands (functions and constructors)
public class Manifest {
    public let packageQualifiedName: String
    public let commands: ArrayList<CommandInfo>

    public init(packageQualifiedName: String, commands: ArrayList<CommandInfo>) {
        this.packageQualifiedName = packageQualifiedName
        this.commands = commands
    }
}

// One command: top-level function, constructor (ClassName new args), or class method (instance or static)
public class CommandInfo <: Comparable<CommandInfo> & Hashable {
    public let name: String
    public let genericParams: ArrayList<GenericParamInfo>
    public let isConstructor: Bool
    public let className: String  // if isConstructor or class method, the class name
    public let params: ArrayList<ParamInfo>
    public let returnType: Option<TypeAnnotation>
    public let returnIsRef: Bool   // true if return type is a class (store in object store)
    public let isInstanceMethod: Bool  // true for non-static instance methods (needs THIS)
    public let isStaticMethod: Bool    // true for static methods (no THIS)
    public let packagePath: String     // CLI directory path: "/" for root, or e.g. "demo_sub"

    public init(name: String, genericParams: ArrayList<GenericParamInfo>, isConstructor: Bool, className: String,
        params: ArrayList<ParamInfo>, returnType: Option<TypeAnnotation>, returnIsRef: Bool, isInstanceMethod: Bool,
        isStaticMethod: Bool, packagePath: String) {
        this.name = name
        this.genericParams = genericParams
        this.isConstructor = isConstructor
        this.className = className
        this.params = params
        this.returnType = returnType
        this.returnIsRef = returnIsRef
        this.isInstanceMethod = isInstanceMethod
        this.isStaticMethod = isStaticMethod
        this.packagePath = packagePath
    }

    @OverflowWrapping
    public func hashCode(): Int64 {
        var hash = packagePath.hashCode() + 31 * name.hashCode()
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
        if (this.packagePath != that.packagePath || this.name != that.name ||
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
        this.displayText().compare(other.displayText())
    }

    public func displayText(): String {
        let syntaxGenericParams = ArrayList<GenericParam>()
        for (genericParam in genericParams) {
            syntaxGenericParams.add(GenericParam(genericParam.name))
        }

        let syntaxParams = ArrayList<Parameter>()
        for (param in params) {
            syntaxParams.add(FuncParam(None, None, param.paramName, param.paramType))
        }

        let signature = FuncDecl(
            None,
            None,
            syntaxGenericParams.toArray(),
            FuncKind.Normal,
            name,
            ParameterList(syntaxParams.toArray()),
            returnType
        )

        var display = signature.toString()
        display
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

func _isSimpleValueTypeName(name: String): Bool {
    name == "String" || name == "Int64" || name == "Int32" || name == "Float64" || name == "Float32" ||
        name == "Bool" || name == "Unit"
}

// Check if type looks like a reference type (class) for our purposes.
func isRefType(typeAnnotation: Option<TypeAnnotation>): Bool {
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

func hasModifier(decl: Decl, kind: ModifierKind): Bool {
    for (modifier in decl.modifiers) {
        if (modifier.kind == kind) {
            return true
        }
    }
    false
}

// Return true if decl has public modifier
func isPublic(decl: Decl): Bool {
    hasModifier(decl, ModifierKind.Public)
}

// Return true if decl has static modifier
func isStatic(decl: Decl): Bool {
    hasModifier(decl, ModifierKind.Static)
}

// Character codes for identifier check (a-z, A-Z, _)
let _CODE_LOWER_A: Int64 = 97
let _CODE_LOWER_Z: Int64 = 122
let _CODE_UPPER_A: Int64 = 65
let _CODE_UPPER_Z: Int64 = 90
let _CODE_UNDERSCORE: Int64 = 95

// Return true if name is an operator (e.g. ==, +); such methods are not exposed as CLI commands
func isOperatorMethodName(name: String): Bool {
    if (name.size < 1) { return true }
    let first: Byte = name.get(0).getOrThrow()
    let code: Int64 = Int64(first)
    if ((code >= _CODE_LOWER_A && code <= _CODE_LOWER_Z) || (code >= _CODE_UPPER_A && code <= _CODE_UPPER_Z) || code == _CODE_UNDERSCORE) { return false }
    true
}

// Build generic parameter list from FuncDecl.
func getGenericParamList(fd: FuncDecl): ArrayList<GenericParamInfo> {
    let result: ArrayList<GenericParamInfo> = ArrayList<GenericParamInfo>()
    for (genericParam in fd.genericParams) {
        result.add(all: [GenericParamInfo(genericParam.name, genericParam)])
    }
    result
}

func packageNameFromHeader(header: PackageHeader): String {
    if (header.packageNameIdentifiers.size == 0) {
        return ""
    }

    var packageName = ""
    var i: Int64 = 0
    while (i < header.packageNameIdentifiers.size) {
        if (i > 0) {
            packageName += "."
        }
        packageName += header.packageNameIdentifiers[i]
        i++
    }
    packageName
}

func getReturnType(fd: FuncDecl): Option<TypeAnnotation> {
    fd.retTyAnnotation
}

// Build ParamInfo list from FuncDecl.params.
func getParamList(fd: FuncDecl): ArrayList<ParamInfo> {
    let list: ArrayList<ParamInfo> = ArrayList<ParamInfo>()
    for (param in fd.params.params) {
        match (param) {
            case fp: FuncParam => list.add(all: [ParamInfo(fp.name, fp.typeAnnotation)])
            case _ => ()
        }
    }
    list
}

func makeClassType(className: String): TypeAnnotation {
    CompositeType(className, [], [])
}

func isConstructorFunc(fd: FuncDecl): Bool {
    match (fd.kind) {
        case FuncKind.Constructor => true
        case _ => false
    }
}

func isNormalFunc(fd: FuncDecl): Bool {
    match (fd.kind) {
        case FuncKind.Normal => true
        case _ => false
    }
}

// Collect one decl from class body: public init, or public instance/static func
func collectClassBodyDecl(className: String, decl: Decl, commands: ArrayList<CommandInfo>, packagePath: String): Unit {
    match (decl) {
        case fd: FuncDecl =>
            if (isConstructorFunc(fd) && isPublic(fd)) {
                let params: ArrayList<ParamInfo> = getParamList(fd)
                commands.add(all: [CommandInfo("init", ArrayList<GenericParamInfo>(), true, className, params,
                    None, false, false, false, packagePath)])
            } else if (isNormalFunc(fd) && isPublic(fd) && !isOperatorMethodName(fd.name)) {
                let genericParams: ArrayList<GenericParamInfo> = getGenericParamList(fd)
                let returnType = getReturnType(fd)
                let methodParams: ArrayList<ParamInfo> = getParamList(fd)
                if (isStatic(fd)) {
                    commands.add(all: [CommandInfo(fd.name, genericParams, false, className, methodParams, returnType,
                        isRefType(returnType), false, true, packagePath)])
                } else {
                    let paramsWithThis: ArrayList<ParamInfo> = ArrayList<ParamInfo>()
                    paramsWithThis.add(all: [ParamInfo("this", makeClassType(className))])
                    for (param in methodParams) {
                        paramsWithThis.add(all: [param])
                    }
                    commands.add(all: [CommandInfo(fd.name, genericParams, false, className, paramsWithThis,
                        returnType, isRefType(returnType), true, false, packagePath)])
                }
            }
        case _ => ()
    }
}

// Collect public init commands from a class body into commands list
func collectPublicInits(className: String, body: Body, commands: ArrayList<CommandInfo>, packagePath: String): Unit {
    for (decl in body.memberDecls) {
        collectClassBodyDecl(className, decl, commands, packagePath)
    }
}

// Process one parsed file: mutates packageName (first file at root sets it) and appends to commands.
// Contract: first file with packagePath == "/" and non-empty package declaration sets package name; order is from collectCjFilesUnder (sorted paths).
func processFile(file: SourceFile, packageName: ArrayList<String>, commands: ArrayList<CommandInfo>, packagePath: String): Unit {
    if (let Some(header) <- file.pkgHeader) {
        let pkgStr: String = packageNameFromHeader(header)
        if (pkgStr.size > 0 && packageName.size == 0 && packagePath == rootPackagePath) {
            packageName.add(all: [pkgStr])
        }
    }

    for (decl in file.topLevelDecls) {
        collectTopLevelDecl(decl, commands, packagePath)
    }
}

// Handle one top-level decl: add public class inits or public func to commands
func collectTopLevelDecl(decl: Decl, commands: ArrayList<CommandInfo>, packagePath: String): Unit {
    match (decl) {
        case cd: ClassDecl =>
            if (isPublic(cd)) {
                collectPublicInits(cd.name, cd.body, commands, packagePath)
            }
        case fd: FuncDecl =>
            if (isPublic(fd) && isNormalFunc(fd)) {
                let genericParams: ArrayList<GenericParamInfo> = getGenericParamList(fd)
                let params: ArrayList<ParamInfo> = getParamList(fd)
                let returnType = getReturnType(fd)
                commands.add(all: [CommandInfo(fd.name, genericParams, false, "", params, returnType,
                    isRefType(returnType), false, false, packagePath)])
            }
        case _ => ()
    }
}

func hasErrorDiagnostics(result: ParsingResult<SourceFile>): Bool {
    for (diag in result.diags) {
        match (diag.diagInfo) {
            case DiagnosticInfo.Error(_, _) => return true
            case _ => ()
        }
    }
    false
}

// Resolve directory to scan: if package root has src/ subdir, use it; else use path as-is.
// Relies on std.fs FileInfo.path.fileName being the directory entry name (e.g. "src").
// Parse package at given path (directory containing .cj files, or package root with src/).
// Returns ParseOutcome with manifest on success, or errorMessage on failure (invalid path, read error, or parse failure).
public func parsePackage(sourcePath: String): ParseOutcome {
    try {
        let scanDir: String = sourcePath + "/src"
        let cjPaths: ArrayList<Path> = collectCjFilesUnder(scanDir)
        let packageName: ArrayList<String> = ArrayList<String>()
        let commands: ArrayList<CommandInfo> = ArrayList<CommandInfo>()

        for (path in cjPaths) {
            let pathStr = path.toString()
            let pkgPath: String = packagePathFromFile(path, scanDir)
            let result = parseFile(pathStr)
            if (result.node.isNone() || hasErrorDiagnostics(result)) {
                return ParseOutcome(Option<Manifest>.None, "failed to parse file: " + pathStr)
            }
            processFile(result.node.getOrThrow(), packageName, commands, pkgPath)
        }

        let pkgName: String = if (packageName.size > 0) { packageName.get(0).getOrThrow() } else { "default" }
        return ParseOutcome(Option<Manifest>.Some(Manifest(pkgName, commands)), "")
    } catch (_) {
        return ParseOutcome(Option<Manifest>.None, "invalid package path or cannot read directory: " + sourcePath)
    }
}

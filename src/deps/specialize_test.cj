package restest.deps

import std.unittest.*
import std.unittest.testmacro.*
import stdx.syntax.*

func parseFuncDecl(text: String): FuncDecl {
    let result = parseText(text)
    if (result.node.isNone()) {
        throw Exception("expected function declaration: " + text)
    }
    match (result.node.getOrThrow()) {
        case fd: FuncDecl => fd
        case _ => throw Exception("expected FuncDecl: " + text)
    }
}

func stringType(): TypeAnnotation {
    CompositeType("String", [], [])
}

@Test
class SpecializeTests {
    @TestCase
    func substituteTypeAnnotationRewritesNamedTypeArguments() {
        let funcDecl = parseFuncDecl("func wrap<T>(value: Box<T>): Box<T> { value }")
        let originalType = (funcDecl.params.params[0] as FuncParam).getOrThrow().typeAnnotation
        let substitutions = [TypeSubstitution("T", stringType())]

        let specialized = substituteTypeAnnotation(originalType, substitutions)

        @Assert(specialized.toString() == "Box<String>")
    }

    @TestCase
    func specializeFuncSignatureRewritesParamsAndReturnType() {
        let funcDecl = parseFuncDecl("func identity<T>(value: T): T { value }")
        let substitutions = [TypeSubstitution("T", stringType())]

        let specialized = specializeFuncSignature(funcDecl, substitutions)
        let param = specialized.params.params[0] as FuncParam

        @Assert(param.isSome())
        @Assert(param.getOrThrow().typeAnnotation.toString() == "String")
        @Assert(specialized.returnType.isSome())
        @Assert(specialized.returnType.getOrThrow().toString() == "String")
    }

    @TestCase
    func substituteTypeAnnotationLeavesUnboundNamesAlone() {
        let funcDecl = parseFuncDecl("func keep<T>(value: Box<T>): Box<T> { value }")
        let originalType = (funcDecl.retTyAnnotation.getOrThrow())
        let substitutions = [TypeSubstitution("U", stringType())]

        let specialized = substituteTypeAnnotation(originalType, substitutions)

        @Assert(specialized.toString() == "Box<T>")
    }
}

package restest

import restest.macros.Generate
import test_test.*

main() {
    let foo: SLL<Int64> = @Generate()
    match (foo) {
        case Nil => println("Nil")
        case Cons(_, _) => println("Cons")
    }
    0
}

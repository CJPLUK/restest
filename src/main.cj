package restest

import restest.macros.Generate
import restest.deps.*
import test_test.*

main() {
    @Generate(a b c d e f g h)
    println(a)
    println(b)
    println(c)
    println(d)
    println(e)
    println(f)
    println(g)
    println(h)
    0
}

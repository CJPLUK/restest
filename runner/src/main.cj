package restest_runner

import restest_runner.deps.*
import restest_runner.macros.Generate
import test_test.*
import stdx.effect.*

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

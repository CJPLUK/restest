package restest

import restest.macros.Generate
import test_test.*

main() {
    @Generate([a, b, c])
    println(a)
    println(b)
    println(c)
    0
}

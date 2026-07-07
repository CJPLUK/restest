package restest_runner

import restest_runner.deps.*
import restest_runner.macros.Generate
import __RESTEST_TARGET_PACKAGE_NAME__.*
import stdx.effect.*

main() {
    @Generate(a b c d e f g h)
    println(a_trace + " = " + a.toString())
    println(b_trace + " = " + b.toString())
    println(c_trace + " = " + c.toString())
    println(d_trace + " = " + d.toString())
    println(e_trace + " = " + e.toString())
    println(f_trace + " = " + f.toString())
    println(g_trace + " = " + g.toString())
    println(h_trace + " = " + h.toString())
    0
}

package test_test

import std.unittest.*
import std.unittest.testmacro.*
import std.unittest.prop_test.*

/*
@Test[xs in random<SLL<Int64>>()] 
func appendNilRightIdentity(xs: SLL<Int64>): Unit {
    @Assert(append(xs, Nil) == xs)
}

@Test[xs in random<SLL<Int64>>(), ys in random<SLL<Int64>>(), zs in random<SLL<Int64>>()]
func appendAssociative(xs: SLL<Int64>, ys: SLL<Int64>, zs: SLL<Int64>): Unit {
    @Assert(append(append(xs, ys), zs) == append(xs, append(ys, zs)))
}

@Test[xs in random<SLL<String>>()]
func mapId(xs: SLL<String>): Unit {
    @Assert(map({ x => x }, xs) == xs)
}

@Test[wf in random<Function1Wrapper<Int64, String>>(), xs in random<SLL<Int64>>(), ys in random<SLL<Int64>>()]
func mapAppend(wf: Function1Wrapper<Int64, String>, xs: SLL<Int64>, ys: SLL<Int64>) {
    let f = wf.function
    @Assert(map(f, append(xs, ys)) == append(map(f, xs), map(f, ys)))
}
*/

@Test[wf in random<Function0Wrapper<?Int64>>()]
func testGenerate(wf: Function0Wrapper<?Int64>) {
    let fuel = Box<Int64>(10)
    @Assert(length(generate<Int64>({ => if (fuel.value > 0) { fuel.value -= 1; wf() } else { None } })) <= 10)
}

@Test[wf in random<Function0Wrapper<?Int64>>()]
func testGenerate2(wf: Function0Wrapper<?Int64>) {
    let fuel = Box<Int64>(10)
    @Assert(length(generate<Int64>({ => if (fuel.value > 0) { fuel.value -= 1; wf() } else { None } })) <= 10)
}

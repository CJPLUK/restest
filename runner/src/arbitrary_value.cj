package restest_runner

import std.convert.*
import std.env.*
import std.random.Random
import std.unittest.prop_test.{ Arbitrary, Generators }

let runtimeRandom = { =>
    match (getVariable("RESTEST_SEED")) {
        case Some(seedValue) =>
            match (UInt64.tryParse(seedValue)) {
                case Some(seed) => Random(seed)
                case None => Random()
            }
        case None => Random()
    }
}()

public func arbitraryValue<T>(): T where T <: Arbitrary<T> {
    Generators.lookup<T>(runtimeRandom).next()
}

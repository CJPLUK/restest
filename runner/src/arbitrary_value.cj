package restest_runner

import std.random.Random
import std.unittest.prop_test.{ Arbitrary, Generators }

public func arbitraryValue<T>(): T where T <: Arbitrary<T> {
    Generators.lookup<T>(Random()).next()
}

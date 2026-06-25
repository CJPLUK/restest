package restest.deps

import std.unittest.prop_test.*
import stdx.effect.Command

public class Switch <: Command<Unit> {}

public class Func0<R> {
    public Func0(public let call: () -> R) {}

    public operator func () (): R {
        call()
    }
}

extend<R> Func0<R> <: Arbitrary<Func0<R>> where R <: Arbitrary<R> {
    public static func arbitrary(random: RandomSource): Generator<Func0<R>> {
        Generators.mapped(random) { r: R =>
            perform Switch()
            Func0 { => r }
        }
    }
}

public class Func1<T0, R> {
    public Func1(public let call: (T0) -> R) {}

    public operator func () (arg0: T0): R {
        call(arg0)
    }
}

extend<T0, R> Func1<T0, R> <: Arbitrary<Func1<T0, R>> where R <: Arbitrary<R> {
    public static func arbitrary(random: RandomSource): Generator<Func1<T0, R>> {
        Generators.mapped(random) { r: R =>
            perform Switch()
            Func1 { _: T0 => r }
        }
    }
}

public class Func2<T0, T1, R> {
    public Func2(public let call: (T0, T1) -> R) {}

    public operator func () (arg0: T0, arg1: T1): R {
        call(arg0, arg1)
    }
}

extend<T0, T1, R> Func2<T0, T1, R> <: Arbitrary<Func2<T0, T1, R>> where R <: Arbitrary<R> {
    public static func arbitrary(random: RandomSource): Generator<Func2<T0, T1, R>> {
        Generators.mapped(random) { r: R =>
            perform Switch()
            Func2 { _: T0, _: T1 => r }
        }
    }
}

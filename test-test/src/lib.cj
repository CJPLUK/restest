package test_test

import std.unittest.prop_test.{Arbitrary, Generator, Generators, RandomSource}

public enum SLL<A> {
    | Nil
    | Cons(A, SLL<A>)
}

public func singleton<A>(x: A): SLL<A> {
    Cons(x, Nil)
}

public func append<A>(xs: SLL<A>, ys: SLL<A>): SLL<A> {
    match (xs) {
        case Nil => ys
        case Cons(x, xs) => Cons(x, append(xs, ys))
    }
}

public func map<A,B>(f: (A) -> B, xs: SLL<A>): SLL<B> {
    match (xs) {
        case Nil => Nil
        case Cons(x, xs) => Cons(f(x), map(f, xs))
    }
}

public func map_<A>(f: (A) -> Unit, xs: SLL<A>): Unit { map(f, xs) }

public func generate<A>(f: () -> ?A): SLL<A> {
    var result = Nil<A>
    while (let Some(x) <- f()) {
        result = Cons(x, result)
    }
    result
}

public func length<A>(xs: SLL<A>): Int64 {
    var rest = xs
    var result: Int64 = 0
    while (let Cons(_, tail) <- rest) {
        result += 1
        rest = tail
    }
    result
}

public func isNil<A>(xs: SLL<A>): Bool {
    match (xs) {
        case Nil => true
        case _ => false
    }
}

public func isConsAnd<A>(h: (A) -> Bool, t: ((SLL<A>) -> Bool)): (SLL<A>) -> Bool {
    { xs => match (xs) {
            case Cons(x, xs) => h(x) && t(xs)
            case _ => false
        }
    }
}

extend<A> SLL<A> <: Equatable<SLL<A>> where A <: Equatable<A> {
    public operator func ==(rhs: SLL<A>): Bool {
        match (this) {
            case Nil => isNil(rhs)
            case Cons(x, xt) =>
                isConsAnd({ y => x == y }, { yt => xt == yt })(rhs)
        }
    }
}

public func fromArray<A>(xs: Array<A>): SLL<A> {
    func build(i: Int64): SLL<A> {
        if (i >= xs.size) {
            Nil
        } else {
            Cons(xs[i], build(i + 1))
        }
    }
    build(0)
}

extend<A> SLL<A> <: Arbitrary<SLL<A>> where A <: Arbitrary<A> {
    public static func arbitrary(random: RandomSource): Generator<SLL<A>> {
        Generators.mapped<Array<A>, SLL<A>>(random, { xs => fromArray(xs) })
    }
}

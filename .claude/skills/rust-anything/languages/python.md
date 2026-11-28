# Python ports

The bridge is PyO3, and `enable` can switch the unit on in place. Types come from the hints; an
unhinted parameter takes its default's type, else `f64` when the body does arithmetic with it,
else `serde_json::Value`. `*args`, `**kwargs` and generators keep a function in Python.

## Constructs

- **Errors**: `raise` becomes `Err("ValueError: message")`. A built-in exception goes by its name,
  the original's own class by its dotted path (`Err("mypkg.errors.ParseError: message")`), which
  the bindings import. `diff` compares the exception type, not the message, and counts a `TypeError`
  from the bindings (arguments they rejected) as agreeing with any error.
- **None**: `Optional[T]` and `T | None` are `Option<T>`; decide per parameter what `None` means.
- **Numbers**: ints never overflow in Python. `int` is `i64`; inside JSON values an int beyond 2**53
  crosses as `{"$int": "digits"}`, and `crate::pynum::Num` turns ints beyond `i64` into floats. Ints the
  original passes through must come back as ints: compute int-or-float values with
  `crate::pynum::Num` (`true_div`, `modulo`, `max`, `min`), not `f64` or `serde_json::Value`.
- **Strings**: `len`, indexes and slices count code points: use `chars()`, never byte offsets.
- **Collections**: `dict` keeps insertion order (`indexmap` where order reaches output). Tuples,
  sets, bytes and dicts with non-string keys cross as `$tuple`, `$set`, `$bytes` and `$dict`
  markers; set iteration order comes from Python's hashing, so sort before output.
- **Classes**: hierarchies become traits plus composition, `isinstance` checks become enums.

## Traps

- **Floor division**: `//` floors and `%` takes the divisor's sign (`-7 // 2` is `-4`,
  `-7 % -2` is `-1`, `-7 % 2` is `1`); Rust truncates. Use `Num::modulo` or explicit floor math;
  `rem_euclid` agrees only for a positive divisor.
- **Rounding**: `round(2.5)` is `2` and `round(0.5)` is `0` (halves to even); Rust's `round` goes
  away from zero.
- **NaN in comparisons**: `max(nan, 1, 2)` is `nan` (the first value wins unless a later one
  compares greater); `-0.0 % 1.0` is `0.0`.
- **Letters**: `str.isalpha` takes letters only, where Rust's `char::is_alphanumeric` also takes
  digits and more. Match the original's rule by general category.
- **numpy**: `record` cannot generate `np.ndarray` arguments. Record the app instead, or port the
  function with a caller that takes plain lists. Code under numba, Cython or `@jax.jit` is already
  machine code: porting it gains little speed.
- **Clock and random** (`time.time`, `datetime.now`, `random`): `record --pin-clock` fixes them,
  and the port reads the same values from `src/port/pinned.rs`.

## Recording

- `record <crate> --from-tests -- pytest` records every call the suite makes to the unit.
- Untyped code: every fourth recorded case passes integral numbers as ints, which is what exposes
  an `f64` port.

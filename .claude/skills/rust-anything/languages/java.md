# Java ports

The bridge is typed JNI with a generated binary wire, in wrapper classes that keep the original
`public static` methods. `char`, `Object`, unordered `Set`, `BigInteger`/`BigDecimal`, functional
interfaces, streams, generic and variadic methods stay in Java. When the unit imports classes from
outside it, set `CLASSPATH` to the jars and class folders the project builds against before
`record`, `diff` and `bench`.

## Constructs

- **Errors**: `Err("NumberFormatException: message")` throws that class. A simple name is looked up
  in `java.lang`, `java.util`, `java.io`, `java.time` and `java.util.concurrent`; any other class
  takes its full name (`com.acme.ParseException`). `diff` compares the exception class, not the
  message. A Rust panic becomes a `RuntimeException` that never matches.
- **null**: a boxed `Integer` is not optional; `Optional<T>` and `OptionalInt` are `Option`. A
  `null` `String` argument throws `NullPointerException` in the wrapper before Rust runs.
- **Numbers**: `int`, `long`, `short` and `byte` are all `i64` in the port, but Java wraps at the
  declared width (`Integer.MAX_VALUE + 1` is `-2147483648`): compute in `i32` with `wrapping_*`
  where the original can overflow, and the same for `hashCode`. `float` is `f64` in the port while
  Java computes in single precision (`1.0f / 3` is `0.33333334`): compute in `f32` and widen.
  Integer division by zero throws `ArithmeticException: / by zero`; Rust panics, so return `Err`.
- **Strings**: Java indexes UTF-16 code units (`charAt`, `substring`, `length`; `"😀".length()` is
  2): index through `encode_utf16()`. The wrapper turns a lone surrogate into U+FFFD on the way in.
- **Collections**: `HashMap` and `HashSet` iterate in Java's hash order: sort before output.
  `TreeSet`, `SortedSet` and `LinkedHashSet` cross as a `Vec` in the set's order.
- **Classes**: hierarchies become traits plus composition, `instanceof` checks become enums.

## Traps

- **Rounding**: `Math.round(-2.5)` is `-2` (halves round up); Rust's `round` gives `-3`.
- **Printing doubles**: `Double.toString` prints the shortest decimal but never fewer than two
  digits (`4.9E-324`, where Rust's shortest form is `5e-324`), switches to exponent form from 1e7
  and below 1e-3 (`1.0E7`, `1.0E-4`), and keeps `.0` (`100.0`).
- **Digits and letters**: `Integer.parseInt` accepts any Unicode decimal digit (`١٢` is 12).
  `Character.isLetterOrDigit` takes letters and decimal digits per UTF-16 unit, so nothing beyond
  U+FFFF; Rust's `char::is_alphanumeric` also takes `²`, `Ⅰ`, `½` and vowel signs. Match the
  original's rule by general category.
- **Whitespace and regex**: `\s` is ASCII-only, where Rust's `split_whitespace` also splits at
  U+00A0; `\w` is ASCII-only too, so write `[A-Za-z0-9_]` or `unicode(false)`.
- **Locale**: `toLowerCase()` and `toUpperCase()` without a `Locale` follow the default locale
  (Turkish turns `I` into `ı`); record on the locale the app runs with.
- **Speed**: after the JIT a leaf method takes nanoseconds and a JNI call with strings costs more:
  port a small method with its callers, or batch it.

## Recording

- On a busy machine a JVM can print `[warning][perf,memops] Cannot use file` to stdout and fail a
  case: run the recorded app (`app record`) with `java -XX:-UsePerfData`.

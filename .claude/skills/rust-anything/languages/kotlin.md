# Kotlin ports

Kotlin crosses through the Java bridge, so read [java.md](java.md) as well: its errors, number
widths, UTF-16 strings, rounding and printing apply here too. A unit is a Gradle module of
top-level functions and `@JvmStatic` members; `record` and `diff` need `kotlinc` on `PATH`.

## Constructs

- **Where the code lives**: a top-level function compiles to a static method on `<File>Kt`
  (`NativeLib.kt` gives `NativeLibKt`); only `@JvmStatic` members of an `object` or
  `companion object` live on the enclosing class.
- **Errors**: `require` throws `IllegalArgumentException`, `check` `IllegalStateException`, `!!`
  `NullPointerException`: return `Err("IllegalArgumentException: message")` and so on, as in Java.
- **Null**: `T?` is `Option<T>`, and `List<Int?>` is `Vec<Option<i64>>`.
- **Numbers**: `Int`, `Long`, `Short` and `Byte` are `i64` in the port while Kotlin wraps at the
  declared width (`Int.MAX_VALUE + 1` is `Int.MIN_VALUE`): use `wrapping_*` on `i32` where the
  original can overflow. `Float` is `f64` in the port: compute in `f32` and widen. `UInt`,
  `ULong`, `Char`, `Any`, `Set`, `Pair`, lambdas and `Sequence` keep a function in Kotlin, and so
  do `ByteArray`, `ShortArray` and `FloatArray`, which the Java wire cannot carry yet.
- **Collections**: `HashMap` and `HashSet` iterate in hash order: sort before output.
- **Coroutines and `@Synchronized`**: keep concurrency in the Kotlin caller and port the
  sequential core.

## Android

`build --profile android` builds the JNI library with the NDK for each ABI (API 26 or higher),
and `record`/`diff --profile android` replay the unit under ART on a connected device. UI,
lifecycle and SDK-only classes stay in Kotlin.

# C# ports

The bridge is a JSON dispatcher over P/Invoke, in `<namespace>.Rust` classes with the original
`public static` methods (`Acme.Text.Slug.Slugify` becomes `Acme.Text.Rust.Slug.Slugify`). There is
no `shadow` and no `--batch`: once `diff` passes, compile the generated `cs/` wrapper into the
project and call the `.Rust` classes, or alias them with `using`. Each call costs about 1 to 3 µs,
so `bench` shows small methods slower than .NET. `ref`, `out`, `params`, generic methods,
delegates, `Task`, `decimal`, `ulong`, `char`, `object` and `dynamic` stay in C#.

## Constructs

- **Errors**: return the exception's full type name: `Err("System.ArgumentNullException: chars")`,
  with `+` for a nested type. A name that resolves to no exception type throws
  `InvalidOperationException`. `diff` compares the type, not the message.
- **null**: `int?` is `Option<i64>`. A `null` record or plain-class argument makes the original
  throw `NullReferenceException`, and the port must return that error instead of computing with
  missing fields. Where the original throws for a `null` string, type the parameter
  `Option<String>` in `port.rs` and run `refresh`.
- **Numbers**: `int`, `long`, `short` and `byte` are all `i64` in the port, but C# wraps at the
  declared width unless the code is `checked` (`int.MaxValue + 1` is `-2147483648`): use
  `wrapping_*` on `i32`. `float` is `f64` in the port while C# computes in single precision
  (`1.0f / 3` is `0.33333334`): compute in `f32` and widen. Integer division by zero throws
  `System.DivideByZeroException`: return `Err`, never panic.
- **Strings**: C# indexes UTF-16 code units (`"😀".Length` is 2; `Substring`, `IndexOf`). A string
  can hold a lone surrogate; it crosses as `{"$utf16": [...]}` and a `String` parameter refuses it.
  List such cases in `known-diffs.jsonl` with that reason rather than mapping them to U+FFFD.
- **Collections**: `Dictionary` and `HashSet` iterate in hash order, and a `HashSet` crosses as an
  array in that order: sort before output. LINQ queries run lazily: port the materialized result.
- **Classes**: a project record or class crosses as `serde_json::Value` when it is public, has no
  base list, no constructor with arguments and only properties that cross; `bridge` names the
  reason when one does not.

## Traps

- **Rounding**: `Math.Round(2.5)` is `2` and `Math.Round(-2.5)` is `-2` (halves to even); Rust's
  `round` goes away from zero. `(int)2.7` truncates to `2`, as `as i32` does.
- **Culture**: `ToString()` and string interpolation format numbers with the current culture
  (`0.1` prints `0,1` under `tr-TR`). Record on the culture the app runs with.
- **Casing**: `ToLowerInvariant` leaves `İ` alone and has no final-sigma rule (`ΣΑΣ` becomes
  `σασ`); `OrdinalIgnoreCase` never folds `ı` or `ſ` to ASCII. Fold per character as .NET does,
  not with Rust's `to_lowercase`. A case-insensitive `[a-z]` matches `İ` on macOS but not under
  invariant globalization (`DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`, as on GitHub's Ubuntu
  runner): record on the machine the code runs on.
- **`GetHashCode`** of a string differs between processes: a result built from it cannot be
  recorded.

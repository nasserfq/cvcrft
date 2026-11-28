# Ruby ports

The bridge is a magnus extension that defines the same modules. Types come from YARD tags
(`@param name [String, nil]`); an untagged parameter takes its default's type, else `f64` when the
body does arithmetic with it, else `serde_json::Value`. `*args`, `**options`, blocks and methods
that `yield` stay in Ruby. Building the extension needs Ruby 3.

## Constructs

- **Errors**: `Err("ArgumentError: message")` raises that class; any other text raises a
  `RuntimeError`. `diff` compares the exception class, not the message.
- **nil**: `[String, nil]` is `Option<String>`. An index out of range returns `nil` instead of
  failing (`"abc"[5]`, `[1, 2, 3][0, -1]`), and the next method call on it raises
  `NoMethodError`: port that raise, never a Rust panic.
- **Numbers**: Ruby integers never overflow. `Integer` is `i64`; inside JSON values a larger one
  crosses as `{"$int": "digits"}`. Ints the original passes through must come back as ints.
- **Strings and symbols**: `Symbol` is a `String` in the port type; inside JSON values a symbol
  crosses as `{"$sym": "name"}` and must come back as one.
- **Collections**: `Hash` keeps insertion order (`indexmap` where order reaches output); a hash
  with keys that are not strings crosses as `{"$hash": [[k, v], ...]}`.
- **Dynamic values**: a method that accepts anything needs Ruby's `to_s` and `inspect` for
  numbers, `nil`, arrays and hashes (`nil.inspect` inside an array is `nil`). A typed port is
  shorter but changes behavior for some callers; `diff` shows which.

## Traps

- **Division**: `/` and `%` on integers floor (`-7 / 2` is `-4`, `-7 % 2` is `1`); Rust truncates.
  Integer division by zero raises `ZeroDivisionError`, float division gives `Infinity`.
- **Printing floats**: `Float#to_s` switches to exponent form from 1e15 (`1e15.to_s` is
  `"1.0e+15"`, `1e14.to_s` is `"100000000000000.0"`).
- **`Array#sum`** uses Kahan-Babuska summation and starts from integer 0, so `[-0.0].sum` is `0.0`.
- **Case mapping**: `downcase` lowers each character alone (`ΣΑΣ` becomes `σασ`); Rust's
  `to_lowercase` applies the final-sigma rule.
- **Regex**: Onigmo's `\h` is a hex digit, not horizontal space.
- **Metaprogramming**: reopened core classes (`class String` at top level), `method_missing`,
  `define_method` and `class_eval` have no Rust form: keep them in Ruby and port the stable
  parts.

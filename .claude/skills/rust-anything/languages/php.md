# PHP ports

The bridge is a JSON dispatcher over PHP's FFI extension: a unit's top-level functions with scalar,
string, list and assoc-array parameters. Classes, `public static` methods, `callable` and class
parameters, references, `...$args` and generators stay in PHP. Each call costs about 1 µs, so
`bench` shows small functions slower than PHP. There is no `shadow` and no `--batch`: once `diff`
passes, require the generated `php/<crate>.php` (`foo-rs` gives `php/foo_rs.php`) where the app
required the original. It replaces that file, so whatever else the file holds (classes, constants,
functions kept in PHP) moves to a file that stays required.

## Constructs

- **Errors**: `Err("TypeError: message")` throws that class, and so does a namespaced class name
  (`Err("App\\Errors\\ParseError: message")`) when the class exists; any other text throws a
  `RuntimeException`. `diff` compares the class, not the message. The original's own parameter
  types run in the generated wrapper too, so a `TypeError` for a wrong argument happens before Rust.
- **null**: `?int` and `int|null` are `Option<i64>`.
- **Numbers**: an `int` that overflows becomes a float (`PHP_INT_MAX + 1` is
  `9.2233720368547758E+18`). `/` gives a float unless the division is exact (`7 / 2` is `3.5`,
  `6 / 2` is the int `3`); `intdiv` for ints. `%` truncates as in Rust, and `%` or `/` by zero
  throws `DivisionByZeroError`. NaN, the infinities and `-0.0` inside an array or untyped argument
  reach the port as `{"$num": "NaN"}` markers.
- **Strings**: PHP strings are bytes: `strlen("é")` is 2, and `strtoupper` changes ASCII letters
  only. The `mb_*` functions count code points.
- **Arrays**: an array is an ordered map (`indexmap` where order reaches output). A list (keys
  0 to n-1) crosses as a JSON array, any other array as an object; numeric string keys become ints
  (`["2" => 1]` has the int key `2`). Porting `ksort` means porting its key comparison.

## Traps

- **Printing floats**: PHP prints 14 significant digits, in exponent form below 1e-4 and from 1e14
  after rounding: `0.00001` is `1.0E-5`, `99999999999999.9` is `1.0E+14`, `-0.0` is `-0`.
- **Loose comparison**: `==` compares numeric strings as numbers (`"1e3" == "1000"` is true) and
  `"abc" == 0` is false; write each comparison out in Rust.
- **Results that are not UTF-8**: recording drops a case whose result JSON cannot hold (a Latin-1
  byte from `html_entity_decode`), so a broken port can pass. After writing inputs for a behavior,
  check that `cases.jsonl` holds them.

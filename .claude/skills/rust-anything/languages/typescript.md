# TypeScript and JavaScript ports

The bridge is napi-rs (or wasm-bindgen), and `enable` can switch the unit on in place. Types come
from TS annotations, JSDoc or a sibling `.d.ts`; `port.rs` has them after `bridge`. Generated
helpers live in `src/js.rs`, and in `src/utf16.rs` when the unit works with string offsets.

## Constructs

- **Errors**: `throw` becomes `Err`. `Err("TypeError: message")` throws that class for the
  built-ins (`TypeError`, `RangeError`, `SyntaxError`, `ReferenceError`, `URIError`,
  `EvalError`); any other text throws a plain `Error` with that message. `diff` counts any two
  throws as a match, so match the class and message yourself where callers read them.
- **undefined and null**: `T | undefined`, `T | null` and every parameter with a default are
  `Option<T>`. Inside a `serde_json::Value`, `undefined` is the marker `{"$undefined": true}`:
  build it with `js::undefined()`, test it with `js::is_undefined`.
- **Numbers**: `number` is `f64`. Bitwise operators truncate to `i32` (`>>>` to `u32`), so
  convert explicitly. NaN, the infinities and `-0` cross as `{"$num": "NaN"}` markers.
- **Strings**: JS indexes UTF-16 code units, Rust `str` UTF-8 bytes. Use `src/utf16.rs` for every
  offset, length and slice; a substring that can cut a surrogate pair goes back as
  `js::utf16_string(utf16::slice_units(..))`, not a `String`.
- **Collections**: `Map`, `Set` and object keys keep insertion order: `indexmap` where order
  reaches output, and `shift_remove` (not `remove`) for `delete`. Integer-like object keys come
  first, in numeric order (`Object.keys({b: 1, 2: 1, a: 1, 1: 1})` is `["1", "2", "b", "a"]`).
- **Classes**: hierarchies become traits plus composition, `instanceof` checks become enums.
  A function or `RegExp` parameter keeps the function in JS.

## Traps

- **Printing numbers**: `${n}` gives `1e+21`, `1e-7` and `0` for `-0`; use
  `js::number_to_string`, never `{}`.
- **Rounding**: `Math.round(-2.5)` is `-2`, Rust's `round` gives `-3`: use `js::math_round`.
  `(2.5).toFixed(0)` is `"3"`, Rust's `{:.0}` rounds to even.
- **`parseInt`** reads a prefix (`parseInt("12px")` is 12) and **`sort`** without a comparator
  compares as strings (`[10, 9, 1]` sorts to `[1, 10, 9]`). A comparator that can return NaN
  needs `js::sort`.
- **Regex**: `/i` without `u` never matches a non-ASCII letter to an ASCII one; Rust `(?i)` does
  (`ſ` and `s`, the Kelvin sign and `k`): write `(?i-u)`. Lookaround, backreferences and the `y`
  flag need `fancy-regex`; the `d` flag and `lastIndex` are UTF-16 offsets.
- **Lone surrogates**: a JS string can hold one, a Rust `String` cannot. The generated guard throws
  a `TypeError` for such an argument instead of altering it; report it as a difference.
- **`Intl`, `localeCompare`, `normalize`, `toLocale*`** run on V8's ICU data; ICU4X crates cover
  them but differ at the edges (V8 splits katakana compounds that ICU4X keeps whole). Record CJK,
  Thai and accented inputs.
- **`Date.parse` and `new Date(string)`** accept formats no crate parses the same way and read a
  zoneless date-time in local time: port only the formats the data holds.
- **`URL`, `URLSearchParams`**: the `url` crate follows the same WHATWG standard. `atob`
  validates first, `btoa` takes Latin-1, `TextDecoder` replaces bad UTF-8 and drops a BOM.
- **Clock and random** (`Date.now()`, `new Date()`, `Math.random`): `record --pin-clock` fixes
  them, and the port reads the same values from `src/port/pinned.rs`.

## Recording

- `record <crate> --from-tests -- npx jest` (any runner) records the calls the suite makes.
  Exports that are not function declarations (`export const f = () => ...`) are listed as not
  captured.
- TS that Node cannot run directly (extensionless imports, path aliases): record from built
  output with `--module dist/x.mjs`, or pass `--node-arg=--import=tsx`.

# Go ports

The bridge is typed cgo with a generated binary wire, in a package with the original API. Pointer,
function, channel, `any` and fixed-array parameters keep a function in Go; an exported struct
crosses as `serde_json::Value` with its exported fields, named by `json` tag.

## Constructs

- **Errors**: a trailing `error` result is dropped from the port type: return `Err` where Go
  returns an error. `diff` compares the error text exactly. Exported sentinels
  (`var ErrBadPattern = errors.New("syntax error in pattern")`) are redeclared in the wrapper: returning
  the sentinel's text or name gives back the sentinel itself (`==` holds), and `"<text>: detail"`
  or `"<name>: detail"` an error that wraps it (`errors.Is` holds).
- **Panics**: in a function with no `error` result, `Err` comes out as a Go panic. A recorded panic
  matches any panic, since the messages differ; a Rust panic never matches.
- **nil**: `encoding/json` writes a nil slice as `null` and an empty one as `[]`, so a recorded
  `null` result is the original's nil slice, not a missing value.
- **Numbers**: `int` to `int64`, `uint8` to `uint32`, `byte` and `rune` are `i64`; `uint` and
  `uint64` are `u64`. Go integers wrap on overflow (`int32` max plus 1 is `-2147483648`) where
  Rust panics in debug: compute at the original's width with `wrapping_*`. `/` and `%` truncate
  as in Rust; an integer division by zero panics in Go.
- **Strings**: Go strings are bytes. `len` and slices count bytes, and a cut through a rune
  reaches JSON as one U+FFFD per byte; `range` over a string yields runes. `[]byte` crosses as
  `Vec<i64>`, a list of numbers.
- **Collections**: range over a map runs in random order: sort before output that depends on it.
  Two or more results cross as one `serde_json::Value` array.

## Traps

- **Case mapping**: `strings.ToLower` lowers each rune alone (`ΣΑΣ` becomes `σασ`, where Rust's
  `to_lowercase` applies the final-sigma rule), and maps `İ` to `i` where Rust gives `i̇`.
- **Speed**: a leaf function takes nanoseconds in Go and one cgo call alone costs about 80 ns.
  A small function is slower through Rust: port it with its callers, or batch it.
- **Goroutines, channels, locks**: keep concurrency in the Go caller and port the sequential core.

## Recording

- Go's table-driven tests make good `--inputs`: the `path` run took 542 of its cases from Go's own
  test tables.

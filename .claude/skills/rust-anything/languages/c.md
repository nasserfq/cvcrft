# C ports

The bridge is `extern "C"` functions with the original names and a header, called directly with
no crossing cost, so `bench` compares the code itself. Scalars keep their C
width and sign (`c_int`, `c_long`, which is 32 bits on Windows, `u8`, `usize`); a port function
returns `T` as the C one does. `profile` does not cover C (use `perf`), and `--batch` is not for C.

## Constructs

- **Errors and undefined behavior**: inputs recorded as `crash:` (a signal in the original) are
  undefined behavior, and any result passes. Undefined behavior that does not crash
  (`ispunct(1000)` reads past glibc's table and returns 1) is recorded like a real result: remove
  that case from `cases.jsonl` by hand and tell the user.
- **Pointers**: a byte pointer with a length parameter is `&[u8]` (or `&mut [u8]` when the
  function writes it), a pointer to one scalar is `Option<&mut T>`, and a returned pointer into a
  parameter is its offset (`Option<usize>`). A `char **` / `const char **` the function points into
  the first `char` string argument is `Option<&mut Option<usize>>` (the offset into it). A struct
  of scalar fields passed or returned by value is a `#[repr(C)]` struct at the crate root
  (`crate::AVRational`), and an object of its fields in cases.
- **Strings**: `const char *` is `Option<&[u8]>`, which costs a `strlen` per argument. Where that
  dominates (short-string helpers), type the parameter `Option<crate::CChars<'_>>` in `port.rs`
  and run `refresh`: the port reads the bytes as it goes (`next`, `peek`, `to_bytes`).
- **Blocked shapes**: contexts, other structs, other `**`, other returned pointers, function
  pointers and variadic functions stay in C: bridge a small wrapper with plain arguments, and say
  so.
- **Integers**: unsigned arithmetic wraps (`wrapping_*`); signed overflow and division by zero are
  undefined, so recorded cases there crash or say nothing.

## Traps

- **libc edges**: `strtod("-")` converts nothing and returns `+0.0`, not `-0.0`; `strtol` with
  base 0 reads `077` as octal and `0x` without a hex digit as `0`; glibc's `toupper(-128)` is
  `128`.
- **Target-dependent C** (inline assembly, `volatile` hardware access, bitfields, `#pragma pack`,
  integers cast to addresses): a recording on this machine says nothing about the target. Keep it
  in C and port the portable logic around it.
- **Macros**: the parser cannot read functions defined through macros, and the plan marks those
  units partial.

## Recording

- In `--inputs`, give buffers as hex text (a number means that many zero bytes, `null` is `NULL`)
  and leave length parameters out; recorded results then hold the return value and what the
  function wrote. For `char **` give the starting offset, `true` for a `NULL` start, or `null` for
  a `NULL` `**`.
- Pass the project's build flags in `CFLAGS` (`-DHAVE_CONFIG_H`, `-I<root>`) when its sources need
  them, and check that the originals compile before reading anything into a failed `record`.

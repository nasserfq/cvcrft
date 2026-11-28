# PowerShell ports

The bridge is a JSON dispatcher over P/Invoke, in a generated `ps/<crate>.ps1` that redeclares each
function with its original `param()` block; `enable` dot-sources it at the end of the original
file. Filters, `begin`/`process` blocks, pipeline input, `[scriptblock]`, `[ref]` and other .NET
types stay in PowerShell. There is no `shadow`, `--batch` or `profile`. Each call costs about
0.1 ms, so only functions doing more work than that get faster; when a tool is slow because it
starts a new `pwsh` per command, no port fixes that. Needs PowerShell 7.4 or later.

## Constructs

- **Errors**: `throw "text"` raises `System.Management.Automation.RuntimeException`, and so does
  `Err("text")`; `Err("System.ArgumentException: message")` raises that type. `diff` compares the
  exception type and the text written to other streams, not the message.
- **Output**: every value a function does not assign or discard is output, not only what `return`
  names, and arrays unroll on the way out: no output reads as `$null`, one item as that item,
  `,@(x)` keeps the array. Port the value `$r = f ...` sees (a `Vec` for several items).
  `Write-Host` text and non-terminating `Write-Error` records are recorded as `output`, which a port
  cannot produce: such cases fail until the function stops writing them.
- **Null and parameters**: an untyped parameter is `serde_json::Value`; an untyped, array,
  `[hashtable]` or `[object]` parameter is `Option<T>` unless it is `Mandatory` or has a default
  other than `$null`.
- **Numbers**: `[int]`, `[long]` and `[byte]` are `i64` and `[decimal]` is `f64` in the port.
- **Collections**: `@{}` iterates in hash order; `[ordered]@{}` keeps insertion order (`indexmap`).

## Traps

- **Case-insensitive by default**: `-eq`, `-ne`, `-like`, `-match`, `-replace`, `-split`,
  `-contains`, `-in`, `switch` and `@{}` keys ignore case unless written `-ceq`, `-cmatch`,
  `switch -CaseSensitive`. Compare folded strings, write regexes with `(?i)`, and key maps by a
  folded string. .NET folds per character: `ToLowerInvariant` leaves `İ` alone and
  `OrdinalIgnoreCase` never folds `ı` or `ſ` to ASCII, so Rust's `to_lowercase` fails those cases.
- **Implicit conversion**: the right operand converts to the left one's type (`'10' -eq 10` and
  `10 -eq '10.0'` are true, `'a' + 1` is `a1`); `/` on two integers gives a double (`5 / 2` is
  2.5); an `[int]` that overflows becomes a `[double]`; `[int]` casts round halves to even
  (`[int]2.5` is 2, `[int]3.5` is 4). `$null -eq $x` and `$x -eq $null` differ when `$x` is an
  array (the second filters it). Write each conversion out in Rust.
- **Machine-dependent matching**: a case-insensitive `-replace '[a-z]'` matches `İ` on macOS but
  not under .NET's invariant globalization (GitHub's Ubuntu runner): record on the machine the
  code runs on, or reproduce with `DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1`.
- **`ConvertFrom-Json`** turns a string shaped like an ISO date into `[datetime]` unless called
  with `-DateKind String` (7.5 and later): a port of code that reads JSON must do the same.
- **Clock and random** (`Get-Date`, `Get-Random`, `New-Guid`): `--pin-clock` does not cover
  PowerShell; pass the time and the seed in as parameters.

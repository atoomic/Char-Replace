# CLAUDE.md — Char::Replace

## What is Char::Replace

XS Perl module providing fast character-level string operations as an alternative
to `tr///` and `s///`. All core functions are implemented in C (`Replace.xs`) for
maximum performance.

## Build & Test

```bash
perl Makefile.PL && make && make test
```

Requires: Test2::Bundle::Extended, Test2::Tools::Explain, Test2::Plugin::NoWarnings

## Architecture

- `Replace.xs` — Core C implementation (~730 lines)
- `lib/Char/Replace.pm` — Perl interface: `identity_map()`, `build_map()`, XS loader
- `examples/` — Synopsis, benchmarks (replace, trim, fast-path)
- `t/` — 16 test files, ~562 assertions

## Public API

| Function | Allocates? | Map types | Description |
|----------|-----------|-----------|-------------|
| `replace($str, $map)` | Yes (new SV) | PV, IV, coderef, undef, empty string | General replacement |
| `replace_inplace($str, $map)` | No | PV(len=1), IV, undef | In-place 1:1 replacement |
| `replace_list(\@strs, $map)` | Yes (new SVs) | PV, IV, coderef, undef, empty string | Batch replacement (map built once) |
| `trim($str [, $chars])` | Yes (new SV) | N/A | Strip leading/trailing characters |
| `trim_inplace($str [, $chars])` | No | N/A | In-place character stripping |
| `identity_map()` | Yes | N/A | Returns 256-entry identity array |
| `build_map(%pairs)` | Yes | All | Convenience map constructor |

## XS Internals

- **Fast path**: `_build_fast_map()` creates 256-byte lookup table for 1:1 maps
  (avoids per-byte SV type dispatch)
- **Custom trim**: `_build_trim_set()` creates 256-byte boolean lookup;
  `SHOULD_TRIM` macro dispatches between custom set and `IS_SPACE` (zero overhead for default)
- **UTF-8 safety**: Multi-byte sequences (>= 0x80) copied through unchanged;
  map applied to ASCII bytes only
- **Taint propagation**: Input taint flag propagated to output via `PROPAGATE_TAINT` macro
- **Threading**: Uses `PERL_NO_GET_CONTEXT` + `pTHX_` calling convention
- **Perl 5.8+ compat**: `croak_sv` fallback for Perl < 5.18

## Conventions

- Dist::Zilla build (`dist.ini`), README.md auto-generated from POD
- Makefile.PL auto-generated and committed for CI compatibility
- Tests use Test2 framework
- Whitespace chars: space, `\r`, `\n`, `\t`, `\f`, `\v`

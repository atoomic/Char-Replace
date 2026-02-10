# Char::Replace — Project Rules

## Build & Test

```bash
perl Makefile.PL && make && make test
```

Clean rebuild (after XS changes):
```bash
make clean && perl Makefile.PL && make && make test
```

## Architecture

- **Replace.xs** — all XS/C code lives here (single file)
- **lib/Char/Replace.pm** — Perl wrapper with POD documentation
- **dist.ini / weaver.ini** — Dist::Zilla config (README.md is auto-generated)
- Tests in `t/`, examples in `examples/`

## Coding Guidelines

- XS functions use `pTHX_` calling convention (with `PERL_NO_GET_CONTEXT`)
- Use `SvPV()` for reading strings (handles magic), `SvPV_force_nolen()` for mutation
- Use `ENSURE_ROOM` macro for buffer growth in replace functions
- Use `UTF8_SEQ_LEN` macro for UTF-8 byte sequence length
- UTF-8 safety: multi-byte sequences (>= 0x80) are copied through unchanged;
  only ASCII bytes (0x00–0x7F) are subject to the replacement map
- All new features need tests in `t/`

## Release Process

Managed via Dist::Zilla (`dist.ini`). Version is auto-set.
Changes file uses `{{$NEXT}}` placeholder.

## Key Functions

| Function | Type | Description |
|----------|------|-------------|
| `replace()` | allocating | character replacement with full map support |
| `replace_inplace()` | in-place | 1:1 byte replacement only |
| `trim()` | allocating | strip leading/trailing whitespace |
| `trim_inplace()` | in-place | strip whitespace, returns bytes removed |
| `identity_map()` | constructor | 256-entry identity array ref |
| `build_map()` | constructor | convenience key-value map builder |

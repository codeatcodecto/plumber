# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/). Each release also bumps the
`Distribution-Date` line in every `.pkg` file so that `ado update` detects it.

## [1.0.0] - 2026-11-26

### Added
- `plumber`: eight-level FROM vs TO audit (exist, type, varlab, vallab, vldef,
  cases, values, transitions); `severity()` overrides; `failon()` gate;
  `.dta`/TSV export; provenance characteristics with input checksums.
- `plumbchain`: consecutive or baseline audit across any number of stages.
- `plumbmeta`: variable-level metadata snapshot with value-label definition check.
- `plumbview`: long side-by-side value listing with optional label text.
- Unit tests (`tests/`), `install.do`, `uninstall.do`, worked example.

### Changed (relative to the internal `sesri_compare` v1.0.0 it generalises)
- `rawfile()`/`intfile()` became `from()`/`to()`; output columns
  `raw_value`/`int_value` became `from_value`/`to_value`; checks renamed
  (`raw_only` -> `from_only`, `int_only_cases` -> `to_only_cases`, ...).
- `misscodes()` has no default; organisations supply their own codes.
- `study()` became `tag()`, defaulting to `<from base> -> <to base>`.

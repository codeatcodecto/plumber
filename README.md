# plumber: audit every stage of a Stata data pipeline

`plumber` shows what changed between two stages of a dataset: raw to ingested
to cleaned to labelled to released. It checks variables, labels, value-label
definitions, cases and individual cells, gives each finding a severity, and
can stop a master do-file when a step does something it should not.

Your input files are never modified. String differences are flagged, never
"fixed".

| Command | What it does |
|---|---|
| `plumber` | Audit a FROM dataset against a TO dataset at up to eight levels |
| `plumbchain` | Run `plumber` over every step of a multi-stage pipeline and stack the results |
| `plumbmeta` | Snapshot a dataset's metadata (one row per variable) for dictionaries and preservation |
| `plumbview` | List FROM and TO values side by side, optionally only changed cells |

Requires Stata 14 or later. No other dependencies.

## Installation

All four packages:

```stata
do "https://raw.githubusercontent.com/codeatcodecto/plumber/main/install.do"
```

Or individually (install `plumber` before `plumbchain`):

```stata
local repo "https://raw.githubusercontent.com/codeatcodecto/plumber/main/"
net install plumber,    from("`repo'") replace
net install plumbchain, from("`repo'") replace
net install plumbmeta,  from("`repo'") replace
net install plumbview,  from("`repo'") replace
```

From a local clone, run `do install.do local` in the repository root.
Run `net get plumber, from("`repo'")` to download the worked example
`plumber_example.do`. Remove everything with `do uninstall.do`.

## Quick start

```stata
* Metadata audit after a labelling step (no case key needed)
plumber, from("01_raw/survey_RAW.dta") to("04_labels/survey_LAB.dta") ///
    levels(meta) nopass clear

* Full audit, saved for the archive, gating the pipeline on CRITICAL findings
plumber, from("01_raw/survey_RAW.dta") to("03_clean/survey_INT.dta") ///
    id(caseid) misscodes(-9 -8 -7 -6 -5) ///
    saving("audit/raw_vs_int.dta") tsv("audit/raw_vs_int.tsv") replace ///
    failon(critical) clear

* Which cases and values changed?
plumbview age q1*, from("01_raw/survey_RAW.dta") to("03_clean/survey_INT.dta") ///
    id(caseid) changed labels clear

* The whole pipeline, step by step
plumbchain, files("01_raw/s.dta" "02_ingest/s.dta" "03_clean/s.dta") ///
    stages(raw ingest clean) id(caseid) nopass clear
```

## Audit levels (`plumber`)

| Level | Checks (default severity) |
|---|---|
| `exist` | `from_only` (MAJOR), `to_only` (INFO); notes possible case-only renames |
| `type` | `class_changed` numeric↔string (MAJOR), `storage_changed`, `format_changed` (INFO) |
| `varlab` | `label_removed` (MAJOR), `label_missing` (MINOR), `label_changed`, `label_added` (INFO) |
| `vallab` | `vallab_removed` (MAJOR), `vallab_undefined` (MINOR), `vallab_changed`, `vallab_added` (INFO) |
| `vldef` | `code_from_only`, `text_changed` (MINOR), `code_to_only` (INFO) |
| `cases` | `to_only_cases` (CRITICAL), `from_only_cases` (MAJOR) |
| `values` | 8 numeric and 5 string change categories (below) |
| `transitions` | Every FROM→TO value pair among changed cells, with counts |

`meta` = `exist type varlab vallab vldef`; `all` = everything. Without `id()`,
the default is `meta`; with `id()`, the default is `all`.

**Numeric cell changes** (`code` = a value in `misscodes()`, `sysmiss` = `.` or `.a`–`.z`).
These categories never overlap and together cover every changed cell, so
they always add up to the total number of changed cells:

| Category | Meaning | Default |
|---|---|---|
| `miss2miss` | `.` → `.a` | MINOR |
| `val2sysmiss` | value → Stata missing | MAJOR |
| `sysmiss2code` | `.` → `-7` (skip coding) | INFO |
| `sysmiss2val` | `.` → value | MINOR |
| `val2code` | value → code | INFO |
| `code2code` | `-8` → `-9` | MINOR |
| `code2val` | code → value | MAJOR |
| `val2val` | value → different value | MINOR |

**String cell changes:** `ws_only`, `case_only` (INFO), `val2empty` (MAJOR),
`empty2val`, `val2val` (MINOR).

The default severities are a starting point for triage. Change them to match
your own procedures, e.g. `severity(from_only_cases=INFO)` for a step that
drops cases on purpose.

## Why not `rename *, suffix(_raw)` and `merge`?

That common approach has several problems:
- It breaks on variable names longer than 28 characters.
- It renames the merge key too.
- It confuses variables that already end in `_raw`.
- Comparisons guarded with `!missing(a) & !missing(b)` hide exactly the changes
  that matter most: values set to missing and missing values filled in.

`plumber` renames FROM variables to `tempvar` names, matches variable names
exactly (`confirm variable` would accept abbreviations), and classifies
missing-value changes explicitly.

## Repository layout

```
stata.toc                  net site table of contents
plumber.pkg  plumber.ado  plumber.sthlp  plumber_example.do
plumbchain.pkg  plumbchain.ado  plumbchain.sthlp
plumbmeta.pkg   plumbmeta.ado   plumbmeta.sthlp
plumbview.pkg   plumbview.ado   plumbview.sthlp
install.do  uninstall.do
tests/      run_all_tests.do, one suite per command, _tally.doh
```

## Tests

From the repository root:

```stata
do tests/run_all_tests.do
```

52 unit tests build their own data, with differences you can count by hand.
The runner exits with `r(9)` if any test fails.

## Citation

See `CITATION.cff`. Suggested: Mandikiana, B. W. (2026). *plumber: audit every
stage of a Stata data pipeline* (Version 1.0.0) [Computer software].

## Author and support

Brian W. Mandikiana (bwmandikiana@gmail.com), SESRI, Qatar University.
Report bugs and request features via [GitHub issues](https://github.com/codeatcodecto/plumber/issues).

## License

MIT. See `LICENSE`.

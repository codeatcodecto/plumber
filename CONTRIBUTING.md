# Contributing to plumber

Thank you for helping improve plumber. Bug reports, test cases and pull
requests are welcome. Maintainer: Brian W. Mandikiana (bwmandikiana@gmail.com).

## Reporting a bug
Open an issue with: Stata version and flavour (`about`), the plumber
version (`which plumber`), the exact command, the full error output, and,
if possible, a minimal generated dataset that reproduces the problem.
Never attach confidential survey data.

## Code conventions (required for pull requests)
- Stata 14 compatibility (`version 14`); no external dependencies.
- One program per `.ado` file; no sub-programs.
- Tabs for indentation; opening brace at the end of the condition line;
  closing brace alone on its own line; `} else {` is not used.
- `//` for inline comments; `*` only for header and `***NN` section lines.
- Skeptic-first input checks (`capture confirm file`, `isid`, exact names).
- Commands never modify their input files; strings are flagged, never fixed.
- `r()` values are computed into locals before the first `return` statement.

## Tests
Every change needs a test in `tests/`. Fixtures are generated in the test,
with differences that can be counted by hand. From the repository root:

```stata
do tests/run_all_tests.do
```

## Releasing
1. Update the `*! version` line, header change log and `pl_version`
   characteristic in each changed `.ado`, and the version line in each `.sthlp`.
2. Bump `d Distribution-Date: YYYYMMDD` in every changed `.pkg`.
3. Add an entry to `CHANGELOG.md` and update `CITATION.cff`.
4. Run the full test suite, then tag the release (`vX.Y.Z`).

*------------------------------------------------------------------------------
* Do-file  : tests/run_all_tests.do
* Purpose  : Run every plumber-package test file; exit r(9) if any fails.
* Usage    : from the repository root:  do tests/run_all_tests.do
*------------------------------------------------------------------------------

version 14
clear
set more off
local suites test_plumber test_plumbmeta test_plumbview test_plumbchain
local bad ""
foreach s of local suites {
	capture noisily do "tests/`s'.do"
	if _rc {
		local bad `bad' `s'
	}
}
di as txt _n "{hline 78}"
if "`bad'" != "" {
	di as err "Failing suites: `bad'"
	di as txt "{hline 78}"
	exit 9
}
di as res "All plumber test suites passed  ($S_DATE $S_TIME)"
di as txt "{hline 78}"

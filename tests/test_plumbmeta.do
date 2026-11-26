*------------------------------------------------------------------------------
* Do-file  : tests/test_plumbmeta.do
* Purpose  : Unit tests for plumbmeta.ado (synthetic fixtures, falsifiable checks)
* Usage    : from the repository root:  do tests/test_plumbmeta.do
*            Exits with r(9) if any test fails.
* Change log
*   2026-11-26  v1.0.0  6 tests.
*------------------------------------------------------------------------------

version 14
clear
set more off
discard

***00 Paths and harness
capture confirm file "plumbmeta.ado"
if _rc {
	di as err "run from the repository root (plumbmeta.ado not found in `c(pwd)')"
	exit 601
}
adopath ++ "`c(pwd)'"
global pl_tmp "`c(tmpdir)'/plumber_tests"
cap mkdir "${pl_tmp}"
local pass = 0
local fail = 0
local failed ""
di as txt "{hline 78}"
di as txt "test_plumbmeta  |  $S_DATE $S_TIME"
di as txt "{hline 78}"

***01 Fixture: 5 obs, 5 variables with known metadata
clear
set obs 5
gen long id = _n
gen byte g = 1 + mod(_n, 2)
label define gl 1 "One" 2 "Two"
label values g gl
gen double x = .
replace x = .a in 3
replace x = 4 in 4
replace x = 5 in 5
gen str3 s = "a"
replace s = "" in 2
replace s = "c" in 3/4
replace s = "" in 5
gen byte u = 1
label values u undeflbl
label variable id "Identifier"
label variable g "Group"
label variable x "Measure"
label variable s "Text"
save "${pl_tmp}/meta_fix.dta", replace
local F "${pl_tmp}/meta_fix.dta"

***02 Tests

//------------------------------------------------------------------ M01
local t "M01_rows_order_and_returns"
capture noisily {
	plumbmeta using "`F'", clear
	assert r(N) == 5
	assert r(k) == 5
	assert r(N_unlabelled) == 1
	assert r(N_vallab_undefined) == 1
	assert _N == 5
	assert variable[1] == "id" & position[1] == 1
	assert variable[5] == "u" & position[5] == 5
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ M02
local t "M02_missing_counts"
capture noisily {
	plumbmeta using "`F'", clear
	assert n_nonmiss == 2 & n_sysmiss == 2 & n_extmiss == 1 if variable == "x"
	assert n_nonmiss == 3 & n_sysmiss == 2 & n_extmiss == 0 if variable == "s"
	assert isnumeric == 0 if variable == "s"
	assert vallab == "gl" & vallab_defined == 1 if variable == "g"
	assert vallab == "undeflbl" & vallab_defined == 0 if variable == "u"
	assert missing(vallab_defined) if variable == "id"
	assert varlab == "Measure" if variable == "x"
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ M03
local t "M03_stats_option"
capture noisily {
	plumbmeta using "`F'", stats clear
	assert n_distinct == 2 if variable == "g"
	assert n_distinct == 2 & min == 4 & max == 5 if variable == "x"
	assert n_distinct == 2 & missing(min) if variable == "s"
	plumbmeta using "`F'", clear
	capture confirm variable n_distinct
	assert _rc != 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ M04
local t "M04_data_in_memory"
capture noisily {
	use "`F'", clear
	plumbmeta
	assert _N == 5
	assert strpos(source, "meta_fix") > 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ M05
local t "M05_saving_and_tsv"
capture noisily {
	plumbmeta using "`F'", saving("${pl_tmp}/M05.dta") tsv("${pl_tmp}/M05.tsv") replace clear
	use "${pl_tmp}/M05.dta", clear
	assert _N == 5
	import delimited using "${pl_tmp}/M05.tsv", delimiter(tab) varnames(1) clear
	assert _N == 5
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ M06
local t "M06_errors"
capture noisily {
	clear
	set obs 1
	gen byte a = 1
	capture plumbmeta using "`F'"
	assert _rc == 4
	capture plumbmeta using "${pl_tmp}/no_such_file.dta", clear
	assert _rc == 601
}
local rc = _rc
include "tests/_tally.doh"

***03 Summary
di as txt _n "{hline 78}"
di as txt "Tests passed: " as res `pass' as txt "   failed: " as res `fail'
if `fail' > 0 {
	di as err "Failed: `failed'"
	di as txt "{hline 78}"
	exit 9
}
di as res "All plumbmeta tests passed."
di as txt "{hline 78}"

*------------------------------------------------------------------------------
* Do-file  : tests/test_plumbview.do
* Purpose  : Unit tests for plumbview.ado (synthetic fixtures, falsifiable checks)
* Usage    : from the repository root:  do tests/test_plumbview.do
*            Exits with r(9) if any test fails.
* Change log
*   2026-11-26  v1.0.0  6 tests.
*------------------------------------------------------------------------------

version 14
clear
set more off
discard

***00 Paths and harness
capture confirm file "plumbview.ado"
if _rc {
	di as err "run from the repository root (plumbview.ado not found in `c(pwd)')"
	exit 601
}
adopath ++ "`c(pwd)'"
global pl_tmp "`c(tmpdir)'/plumber_tests"
cap mkdir "${pl_tmp}"
local pass = 0
local fail = 0
local failed ""
di as txt "{hline 78}"
di as txt "test_plumbview  |  $S_DATE $S_TIME"
di as txt "{hline 78}"

***01 Fixtures
clear
set obs 4
gen long caseid = _n
gen byte g = 1 + mod(_n + 1, 2)
label define sexlbl 1 "Male" 2 "Female"
label values g sexlbl
gen str5 s = "x"
gen byte abcdefghijklmnopqrstuvwxyz012345 = 7
save "${pl_tmp}/view_FROM.dta", replace
replace g = 2 in 1
drop if caseid == 4
set obs 4
replace caseid = 5 in 4
save "${pl_tmp}/view_TO.dta", replace
use "${pl_tmp}/view_FROM.dta", clear
label define sexlbl 2 "F", modify
save "${pl_tmp}/view_RELAB.dta", replace
local A "${pl_tmp}/view_FROM.dta"
local B "${pl_tmp}/view_TO.dta"

***02 Tests

//------------------------------------------------------------------ V01
local t "V01_changed_only"
capture noisily {
	plumbview g, from("`A'") to("`B'") id(caseid) changed clear
	assert r(N_changed) == 1
	assert _N == 1
	assert caseid == 1 & from_value == "1" & to_value == "2" & changed == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ V02
local t "V02_value_label_text"
capture noisily {
	plumbview g, from("`A'") to("`B'") id(caseid) changed labels clear
	assert from_value == "1 [Male]" & to_value == "2 [Female]"
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ V03
local t "V03_all_rows_and_presence"
capture noisily {
	plumbview, from("`A'") to("`B'") id(caseid) nolist clear
	assert r(k) == 3
	assert _N == 15
	quietly count if presence == "from only"
	assert r(N) == 3
	quietly count if presence == "to only"
	assert r(N) == 3
	assert missing(changed) if presence != "both"
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ V04
local t "V04_patterns_and_long_names"
capture noisily {
	plumbview abc*, from("`A'") to("`B'") id(caseid) nolist clear
	assert r(k) == 1
	assert "`r(varlist)'" == "abcdefghijklmnopqrstuvwxyz012345"
	quietly count if changed == 1
	assert r(N) == 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ V05
local t "V05_relabel_is_not_a_change"
capture noisily {
	plumbview g, from("`A'") to("${pl_tmp}/view_RELAB.dta") id(caseid) changed labels clear
	assert r(N_changed) == 0
	assert _N == 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ V06
local t "V06_errors"
capture noisily {
	capture plumbview zzz*, from("`A'") to("`B'") id(caseid) clear
	assert _rc == 111
	capture plumbview g, from("`A'") to("`B'") id(nokey) clear
	assert _rc == 111
	capture plumbview g, from("${pl_tmp}/nofile.dta") to("`B'") id(caseid) clear
	assert _rc == 601
	use "`A'", clear
	expand 2 in 1
	save "${pl_tmp}/view_DUP.dta", replace
	capture plumbview g, from("`A'") to("${pl_tmp}/view_DUP.dta") id(caseid) clear
	assert _rc == 459
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
di as res "All plumbview tests passed."
di as txt "{hline 78}"

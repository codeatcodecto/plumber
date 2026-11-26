*------------------------------------------------------------------------------
* Do-file  : tests/test_plumbchain.do
* Purpose  : Unit tests for plumbchain.ado (synthetic fixtures, falsifiable checks)
* Usage    : from the repository root:  do tests/test_plumbchain.do
*            Exits with r(9) if any test fails.
* Change log
*   2026-11-26  v1.0.0  6 tests.
*------------------------------------------------------------------------------

version 14
clear
set more off
discard

***00 Paths and harness
capture confirm file "plumbchain.ado"
if _rc {
	di as err "run from the repository root (plumbchain.ado not found in `c(pwd)')"
	exit 601
}
adopath ++ "`c(pwd)'"
global pl_tmp "`c(tmpdir)'/plumber_tests"
cap mkdir "${pl_tmp}"
local pass = 0
local fail = 0
local failed ""
di as txt "{hline 78}"
di as txt "test_plumbchain  |  $S_DATE $S_TIME"
di as txt "{hline 78}"

***01 Fixtures: three stages; step 1 recodes x, step 2 drops y
clear
set obs 4
gen long caseid = _n
gen byte x = _n
gen byte y = 1
save "${pl_tmp}/chain_s1.dta", replace
replace x = 9 in 1
save "${pl_tmp}/chain_s2.dta", replace
drop y
save "${pl_tmp}/chain_s3.dta", replace
cap mkdir "${pl_tmp}/chain dir"
save "${pl_tmp}/chain dir/chain s4.dta", replace
local S1 "${pl_tmp}/chain_s1.dta"
local S2 "${pl_tmp}/chain_s2.dta"
local S3 "${pl_tmp}/chain_s3.dta"

***02 Tests

//------------------------------------------------------------------ C01
local t "C01_consecutive_steps"
capture noisily {
	plumbchain, files("`S1'" "`S2'" "`S3'") id(caseid) nopass clear
	assert r(N_steps) == 2
	assert "`r(mode)'" == "consecutive"
	quietly count if step == 1 & variable == "x" & check == "val2val" & n_affected == 1
	assert r(N) == 1
	quietly count if step == 2 & variable == "y" & check == "from_only" & severity == "MAJOR"
	assert r(N) == 1
	quietly count if step == 1 & level == "exist"
	assert r(N) == 0
	quietly count if step == 2 & check == "val2val"
	assert r(N) == 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ C02
local t "C02_baseline_mode"
capture noisily {
	plumbchain, files("`S1'" "`S2'" "`S3'") baseline id(caseid) nopass clear
	assert "`r(mode)'" == "baseline"
	assert from_stage == "chain_s1"
	quietly count if step == 2 & variable == "x" & check == "val2val"
	assert r(N) == 1
	quietly count if step == 2 & variable == "y" & check == "from_only"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ C03
local t "C03_stage_labels_and_paths_with_spaces"
capture noisily {
	plumbchain, files("`S1'" "`S2'" "${pl_tmp}/chain dir/chain s4.dta") stages(raw clean final) id(caseid) clear
	assert from_stage == "raw" if step == 1
	assert to_stage == "final" if step == 2
	assert tag == "clean -> final" if step == 2
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ C04
local t "C04_failon_gate"
capture noisily {
	capture plumbchain, files("`S1'" "`S2'" "`S3'") id(caseid) failon(major) clear
	assert _rc == 9
	capture plumbchain, files("`S1'" "`S2'" "`S3'") id(caseid) failon(critical) clear
	assert _rc == 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ C05
local t "C05_saving_and_tsv"
capture noisily {
	plumbchain, files("`S1'" "`S2'" "`S3'") levels(exist) saving("${pl_tmp}/C05.dta") tsv("${pl_tmp}/C05.tsv") replace clear
	local n = r(N_rows)
	use "${pl_tmp}/C05.dta", clear
	assert _N == `n'
	assert "`: char _dta[pl_chain_mode]'" == "consecutive"
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ C06
local t "C06_errors"
capture noisily {
	capture plumbchain, files("`S1'") clear
	assert _rc == 198
	capture plumbchain, files("`S1'" "`S2'") from("`S1'") clear
	assert _rc == 198
	capture plumbchain, files("`S1'" "`S2'") stages(a b c) clear
	assert _rc == 198
	capture plumbchain, files("`S1'" "${pl_tmp}/nofile.dta") clear
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
di as res "All plumbchain tests passed."
di as txt "{hline 78}"

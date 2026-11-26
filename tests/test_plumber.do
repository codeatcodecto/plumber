*------------------------------------------------------------------------------
* Do-file  : tests/test_plumber.do
* Purpose  : Unit tests for plumber.ado. Synthetic fixtures with hand-countable
*            differences; every assertion is falsifiable.
* Usage    : from the repository root:  do tests/test_plumber.do
*            Exits with r(9) if any test fails.
* Change log
*   2026-11-26  v1.0.0  34 tests.
*------------------------------------------------------------------------------

version 14
clear
set more off
discard

***00 Paths and harness
capture confirm file "plumber.ado"
if _rc {
	di as err "run from the repository root (plumber.ado not found in `c(pwd)')"
	exit 601
}
adopath ++ "`c(pwd)'"
global pl_tmp "`c(tmpdir)'/plumber_tests"
cap mkdir "${pl_tmp}"
local pass = 0
local fail = 0
local failed ""
di as txt "{hline 78}"
di as txt "test_plumber  |  $S_DATE $S_TIME"
di as txt "{hline 78}"

***01 Base fixture (N=10)
clear
set obs 10
gen long caseid = _n
gen byte gender = 1 + mod(_n, 2)
gen byte marital = 1 + mod(_n, 3)
gen int age = 20 + _n
gen str10 city = "Doha"
gen byte yn = 1
label define sexlbl 1 "Male" 2 "Female"
label define marlbl 1 "Single" 2 "Married" 3 "Other"
label define ynlbl 1 "Yes" 2 "No" 9 "DK"
label values gender sexlbl
label values marital marlbl
label values yn ynlbl
label variable caseid "Case ID"
label variable gender "Demographics: Gender"
label variable marital "Demographics: Marital status"
label variable age "Demographics: Age"
label variable city "Demographics: City"
label variable yn "Attitudes: Agree"
save "${pl_tmp}/base_RAW.dta", replace
local R "${pl_tmp}/base_RAW.dta"

***02 Tests

//------------------------------------------------------------------ T01
local t "T01_identical_files_all_levels"
capture noisily {
	copy "`R'" "${pl_tmp}/T01_INT.dta", replace
	plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") id(caseid) clear
	assert r(N_critical) == 0
	assert r(N_major) == 0
	assert r(N_minor) == 0
	assert r(N_info) == 0
	assert r(N_matched) == 10
	assert "`r(tag)'" == "base_RAW -> T01_INT"
	quietly count if severity != "PASS"
	assert r(N) == 0
	quietly count if level == "values" & check == "no_change"
	assert r(N) == 5
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T02
local t "T02_exist_dropped_and_added"
capture noisily {
	use "`R'", clear
	drop age
	gen byte newvar = 1
	label variable newvar "Derived: flag"
	save "${pl_tmp}/T02_INT.dta", replace
	plumber, from("`R'") to("${pl_tmp}/T02_INT.dta") levels(exist) clear
	assert r(N_major) == 1
	assert r(N_info) == 1
	quietly count if variable == "age" & check == "from_only" & severity == "MAJOR"
	assert r(N) == 1
	quietly count if variable == "newvar" & check == "to_only" & severity == "INFO"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T03
local t "T03_varlab_changed_and_removed"
capture noisily {
	use "`R'", clear
	label variable gender "Demographics: Sex"
	label variable marital ""
	save "${pl_tmp}/T03_INT.dta", replace
	plumber, from("`R'") to("${pl_tmp}/T03_INT.dta") levels(varlab) clear
	assert r(N_major) == 1
	assert r(N_info) == 1
	quietly count if variable == "gender" & check == "label_changed" & to_value == "Demographics: Sex"
	assert r(N) == 1
	quietly count if variable == "marital" & check == "label_removed" & severity == "MAJOR"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T04
local t "T04_vallab_changed_removed_added_undefined"
capture noisily {
	use "`R'", clear
	label copy sexlbl genderlbl
	label values gender genderlbl
	label values marital
	label values age agelbl
	save "${pl_tmp}/T04_INT.dta", replace
	plumber, from("`R'") to("${pl_tmp}/T04_INT.dta") levels(vallab) clear
	assert r(N_major) == 1
	assert r(N_minor) == 1
	assert r(N_info) == 2
	quietly count if variable == "gender" & check == "vallab_changed"
	assert r(N) == 1
	quietly count if variable == "marital" & check == "vallab_removed" & severity == "MAJOR"
	assert r(N) == 1
	quietly count if variable == "age" & check == "vallab_added"
	assert r(N) == 1
	quietly count if variable == "age" & check == "vallab_undefined" & severity == "MINOR"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T05
local t "T05_vldef_text_and_codes"
capture noisily {
	use "`R'", clear
	label define sexlbl 2 "female", modify
	label drop ynlbl
	label define ynlbl 1 "Yes" 2 "No" -8 "Don't know"
	save "${pl_tmp}/T05_INT.dta", replace
	plumber, from("`R'") to("${pl_tmp}/T05_INT.dta") levels(vldef) clear
	assert r(N_minor) == 2
	assert r(N_info) == 1
	quietly count if variable == "sexlbl" & check == "text_changed" & from_value == "Female" & to_value == "female"
	assert r(N) == 1
	quietly count if variable == "ynlbl" & check == "code_from_only" & note == "code 9"
	assert r(N) == 1
	quietly count if variable == "ynlbl" & check == "code_to_only" & note == "code -8"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T06
local t "T06_type_storage_class_format"
capture noisily {
	use "`R'", clear
	recast int gender
	tostring age, replace
	format marital %12.0g
	save "${pl_tmp}/T06_INT.dta", replace
	plumber, from("`R'") to("${pl_tmp}/T06_INT.dta") levels(type) clear
	assert r(N_major) == 1
	assert r(N_info) == 3
	quietly count if variable == "age" & check == "class_changed" & severity == "MAJOR"
	assert r(N) == 1
	quietly count if variable == "gender" & check == "storage_changed" & from_value == "byte" & to_value == "int"
	assert r(N) == 1
	quietly count if variable == "marital" & check == "format_changed" & to_value == "%12.0g"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T07
local t "T07_values_class_mismatch_not_compared"
capture noisily {
	plumber, from("`R'") to("${pl_tmp}/T06_INT.dta") id(caseid) levels(values) clear
	assert r(N_major) == 1
	quietly count if variable == "age" & check == "class_mismatch" & severity == "MAJOR"
	assert r(N) == 1
	quietly count if variable == "gender" & check == "no_change"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T08
local t "T08_cases_dropped_and_added"
capture noisily {
	use "`R'", clear
	drop if caseid >= 9
	set obs 9
	replace caseid = 11 in 9
	save "${pl_tmp}/T08_INT.dta", replace
	plumber, from("`R'") to("${pl_tmp}/T08_INT.dta") id(caseid) levels(cases) clear
	assert r(N_matched) == 8
	assert r(N_from_only) == 2
	assert r(N_to_only) == 1
	assert r(N_critical) == 1
	assert r(N_major) == 1
	quietly count if check == "from_only_cases" & n_affected == 2 & strpos(note, "9 10") > 0
	assert r(N) == 1
	quietly count if check == "to_only_cases" & n_affected == 1 & severity == "CRITICAL"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T09
// One observation per numeric change category; obs 1 and 10 unchanged
local t "T09_values_numeric_all_eight_categories"
capture noisily {
	clear
	set obs 10
	gen long caseid = _n
	gen double x = .
	replace x = 1  in 1
	replace x = 5  in 3
	replace x = 4  in 6
	replace x = -8 in 7
	replace x = -9 in 8
	replace x = 2  in 9
	replace x = .a in 10
	save "${pl_tmp}/T09_RAW.dta", replace
	replace x = .a in 2
	replace x = .  in 3
	replace x = -7 in 4
	replace x = 3  in 5
	replace x = -9 in 6
	replace x = -9 in 7
	replace x = 2  in 8
	replace x = 7  in 9
	save "${pl_tmp}/T09_INT.dta", replace
	plumber, from("${pl_tmp}/T09_RAW.dta") to("${pl_tmp}/T09_INT.dta") ///
		id(caseid) levels(values) misscodes(-9 -8 -7 -6 -5) nopass clear
	assert r(N_major) == 2
	assert r(N_minor) == 4
	assert r(N_info) == 2
	foreach c in miss2miss val2sysmiss sysmiss2code sysmiss2val val2code code2code code2val val2val {
		quietly count if variable == "x" & check == "`c'" & n_affected == 1 & n_compared == 10
		assert r(N) == 1
	}
	quietly count if check == "val2sysmiss" & severity == "MAJOR"
	assert r(N) == 1
	quietly count if check == "code2val" & severity == "MAJOR"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T10
local t "T10_values_string_categories_flag_only"
capture noisily {
	clear
	set obs 8
	gen long caseid = _n
	gen str10 s = "abc"
	replace s = "abc " in 2
	replace s = "a  b" in 3
	replace s = "ABC" in 4
	replace s = "" in 7
	replace s = "" in 8
	save "${pl_tmp}/T10_RAW.dta", replace
	replace s = "abc" in 2
	replace s = "a b" in 3
	replace s = "abc" in 4
	replace s = "xyz" in 5
	replace s = "" in 6
	replace s = "abc" in 7
	save "${pl_tmp}/T10_INT.dta", replace
	plumber, from("${pl_tmp}/T10_RAW.dta") to("${pl_tmp}/T10_INT.dta") ///
		id(caseid) levels(values) nopass clear
	assert r(N_major) == 1
	assert r(N_minor) == 2
	assert r(N_info) == 2
	quietly count if check == "ws_only" & n_affected == 2
	assert r(N) == 1
	quietly count if check == "case_only" & n_affected == 1
	assert r(N) == 1
	quietly count if check == "val2empty" & n_affected == 1 & severity == "MAJOR"
	assert r(N) == 1
	quietly count if check == "empty2val" & n_affected == 1
	assert r(N) == 1
	quietly count if check == "val2val" & n_affected == 1
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T11
local t "T11_tolerance_float_vs_double"
capture noisily {
	clear
	set obs 3
	gen long caseid = _n
	gen float y = 0.1
	save "${pl_tmp}/T11_RAW.dta", replace
	recast double y
	replace y = 0.1
	save "${pl_tmp}/T11_INT.dta", replace
	plumber, from("${pl_tmp}/T11_RAW.dta") to("${pl_tmp}/T11_INT.dta") ///
		id(caseid) levels(values) clear
	quietly count if variable == "y" & check == "val2val" & n_affected == 3
	assert r(N) == 1
	plumber, from("${pl_tmp}/T11_RAW.dta") to("${pl_tmp}/T11_INT.dta") ///
		id(caseid) levels(values) tolerance(1e-6) clear
	assert r(N_minor) == 0
	quietly count if variable == "y" & check == "no_change"
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T12
local t "T12_transitions_pairs_and_counts"
capture noisily {
	clear
	set obs 6
	gen long caseid = _n
	gen byte z = 1
	replace z = 2 in 4/5
	replace z = 3 in 6
	save "${pl_tmp}/T12_RAW.dta", replace
	replace z = 5 in 1/3
	replace z = 6 in 4
	save "${pl_tmp}/T12_INT.dta", replace
	plumber, from("${pl_tmp}/T12_RAW.dta") to("${pl_tmp}/T12_INT.dta") ///
		id(caseid) levels(transitions) clear
	quietly count if level == "values" & check == "val2val" & n_affected == 4
	assert r(N) == 1
	quietly count if level == "transitions" & from_value == "1" & to_value == "5" & n_affected == 3
	assert r(N) == 1
	quietly count if level == "transitions" & from_value == "2" & to_value == "6" & n_affected == 1
	assert r(N) == 1
	quietly count if level == "transitions"
	assert r(N) == 2
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T13
local t "T13_maxtrans_caps_rows"
capture noisily {
	plumber, from("${pl_tmp}/T12_RAW.dta") to("${pl_tmp}/T12_INT.dta") ///
		id(caseid) levels(transitions) maxtrans(1) clear
	quietly count if level == "transitions"
	assert r(N) == 1
	quietly count if level == "transitions" & from_value == "1" & n_affected == 3
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T14
// 32-character name: a suffix-rename approach (rename *, suffix(_raw)) fails here
local t "T14_32_character_variable_name"
capture noisily {
	clear
	set obs 4
	gen long caseid = _n
	gen byte abcdefghijklmnopqrstuvwxyz012345 = 1
	save "${pl_tmp}/T14_RAW.dta", replace
	replace abcdefghijklmnopqrstuvwxyz012345 = 2 in 1
	save "${pl_tmp}/T14_INT.dta", replace
	plumber, from("${pl_tmp}/T14_RAW.dta") to("${pl_tmp}/T14_INT.dta") ///
		id(caseid) levels(values) clear
	quietly count if variable == "abcdefghijklmnopqrstuvwxyz012345" & check == "val2val" & n_affected == 1
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T15
// Existing *_raw names must not be confused with suffix stems
local t "T15_existing_raw_suffix_names"
capture noisily {
	clear
	set obs 4
	gen long caseid = _n
	gen byte gender = 1
	gen byte gender_raw = 1
	save "${pl_tmp}/T15_RAW.dta", replace
	replace gender_raw = 2 in 1
	save "${pl_tmp}/T15_INT.dta", replace
	plumber, from("${pl_tmp}/T15_RAW.dta") to("${pl_tmp}/T15_INT.dta") ///
		id(caseid) levels(values) clear
	quietly count if variable == "gender" & check == "no_change"
	assert r(N) == 1
	quietly count if variable == "gender_raw" & check == "val2val" & n_affected == 1
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T16
local t "T16_composite_key"
capture noisily {
	clear
	set obs 4
	gen long hhid = ceil(_n / 2)
	gen byte pid = 2 - mod(_n, 2)
	gen byte v = 4 + _n
	save "${pl_tmp}/T16_RAW.dta", replace
	replace v = 9 if hhid == 2 & pid == 2
	save "${pl_tmp}/T16_INT.dta", replace
	plumber, from("${pl_tmp}/T16_RAW.dta") to("${pl_tmp}/T16_INT.dta") ///
		id(hhid pid) levels(values) clear
	assert r(N_matched) == 4
	quietly count if variable == "v" & check == "val2val" & n_affected == 1
	assert r(N) == 1
	quietly count if variable == "pid" & level == "values"
	assert r(N) == 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T17
local t "T17_misscodes_override"
capture noisily {
	clear
	set obs 2
	gen long caseid = _n
	gen int w = _n
	save "${pl_tmp}/T17_RAW.dta", replace
	replace w = -99 in 1
	save "${pl_tmp}/T17_INT.dta", replace
	plumber, from("${pl_tmp}/T17_RAW.dta") to("${pl_tmp}/T17_INT.dta") ///
		id(caseid) levels(values) clear
	quietly count if check == "val2val" & n_affected == 1
	assert r(N) == 1
	plumber, from("${pl_tmp}/T17_RAW.dta") to("${pl_tmp}/T17_INT.dta") ///
		id(caseid) levels(values) misscodes(-99 -98) clear
	quietly count if check == "val2code" & n_affected == 1
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T18
local t "T18_vars_filter"
capture noisily {
	plumber, from("`R'") to("${pl_tmp}/T03_INT.dta") levels(meta) vars(gender) clear
	quietly count if variable != "gender" & level != "vldef"
	assert r(N) == 0
	quietly count if level == "vldef" & variable != "sexlbl"
	assert r(N) == 0
	quietly count if level == "vldef"
	assert r(N) == 2
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T19
local t "T19_case_only_rename_note"
capture noisily {
	use "`R'", clear
	rename gender Gender
	save "${pl_tmp}/T19_RAW.dta", replace
	plumber, from("${pl_tmp}/T19_RAW.dta") to("`R'") levels(exist) clear
	quietly count if variable == "Gender" & check == "from_only" & strpos(note, "case-only") > 0
	assert r(N) == 1
	quietly count if variable == "gender" & check == "to_only" & strpos(note, "case-only") > 0
	assert r(N) == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T20
local t "T20_nopass_on_identical_gives_empty_table"
capture noisily {
	plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") id(caseid) nopass clear
	assert r(N_rows) == 0
	assert _N == 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T21
local t "T21_inputs_unchanged_read_only"
capture noisily {
	checksum "`R'"
	local ck1 = r(checksum)
	checksum "${pl_tmp}/T08_INT.dta"
	local ck2 = r(checksum)
	plumber, from("`R'") to("${pl_tmp}/T08_INT.dta") id(caseid) clear
	checksum "`R'"
	assert r(checksum) == `ck1'
	checksum "${pl_tmp}/T08_INT.dta"
	assert r(checksum) == `ck2'
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T22
local t "T22_saving_and_tsv_outputs"
capture noisily {
	capture erase "${pl_tmp}/T22_audit.dta"
	capture erase "${pl_tmp}/T22_audit.tsv"
	plumber, from("`R'") to("${pl_tmp}/T03_INT.dta") levels(varlab) ///
		saving("${pl_tmp}/T22_audit.dta") tsv("${pl_tmp}/T22_audit.tsv") replace clear
	local nrows = r(N_rows)
	confirm file "${pl_tmp}/T22_audit.dta"
	confirm file "${pl_tmp}/T22_audit.tsv"
	use "${pl_tmp}/T22_audit.dta", clear
	assert _N == `nrows'
	assert tag == "base_RAW -> T03_INT"
	assert "`: char _dta[pl_levels]'" == "varlab"
	import delimited using "${pl_tmp}/T22_audit.tsv", delimiter(tab) varnames(1) clear
	assert _N == `nrows'
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T23
local t "T23_failon_gate"
capture noisily {
	capture plumber, from("`R'") to("${pl_tmp}/T02_INT.dta") levels(exist) failon(major) clear
	assert _rc == 9
	capture plumber, from("`R'") to("${pl_tmp}/T02_INT.dta") levels(exist) failon(critical) clear
	assert _rc == 0
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T24
local t "T24_err_missing_file_601"
capture noisily {
	capture plumber, from("${pl_tmp}/no_such_file.dta") to("`R'") clear
	assert _rc == 601
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T25
local t "T25_err_values_without_id_198"
capture noisily {
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") levels(values) clear
	assert _rc == 198
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T26
local t "T26_err_nonunique_key_459"
capture noisily {
	use "`R'", clear
	expand 2 in 1
	save "${pl_tmp}/T26_INT.dta", replace
	capture plumber, from("`R'") to("${pl_tmp}/T26_INT.dta") id(caseid) levels(cases) clear
	assert _rc == 459
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T27
local t "T27_err_unsaved_data_requires_clear_4"
capture noisily {
	clear
	set obs 1
	gen byte a = 1
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta")
	assert _rc == 4
	assert _N == 1
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T28
local t "T28_err_id_not_found_111"
capture noisily {
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") id(nokey) levels(cases) clear
	assert _rc == 111
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T29
local t "T29_err_id_class_mismatch_109"
capture noisily {
	use "`R'", clear
	tostring caseid, replace
	save "${pl_tmp}/T29_INT.dta", replace
	capture plumber, from("`R'") to("${pl_tmp}/T29_INT.dta") id(caseid) levels(cases) clear
	assert _rc == 109
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T30
local t "T30_err_bad_options_198"
capture noisily {
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") levels(bogus) clear
	assert _rc == 198
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") failon(severe) clear
	assert _rc == 198
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") misscodes(-9 abc) clear
	assert _rc == 198
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") tolerance(-1) clear
	assert _rc == 198
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T31
local t "T31_err_vars_no_match_111"
capture noisily {
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") vars(zz*) clear
	assert _rc == 111
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T32
local t "T32_severity_override"
capture noisily {
	plumber, from("`R'") to("${pl_tmp}/T08_INT.dta") id(caseid) levels(cases) ///
		severity(from_only_cases=INFO to_only_cases=minor) clear
	assert r(N_critical) == 0
	assert r(N_major) == 0
	assert r(N_minor) == 1
	assert r(N_info) == 1
	assert "`: char _dta[pl_severity]'" == "from_only_cases=INFO to_only_cases=MINOR"
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T33
local t "T33_err_bad_severity_198"
capture noisily {
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") severity(raw_only) clear
	assert _rc == 198
	capture plumber, from("`R'") to("${pl_tmp}/T01_INT.dta") severity(raw_only=HIGH) clear
	assert _rc == 198
}
local rc = _rc
include "tests/_tally.doh"

//------------------------------------------------------------------ T34
// Without misscodes() no value is a code: -7/-9/-8 count as ordinary values
local t "T34_no_default_misscodes"
capture noisily {
	plumber, from("${pl_tmp}/T09_RAW.dta") to("${pl_tmp}/T09_INT.dta") ///
		id(caseid) levels(values) nopass clear
	quietly count if check == "miss2miss" & n_affected == 1
	assert r(N) == 1
	quietly count if check == "val2sysmiss" & n_affected == 1
	assert r(N) == 1
	quietly count if check == "sysmiss2val" & n_affected == 2
	assert r(N) == 1
	quietly count if check == "val2val" & n_affected == 4
	assert r(N) == 1
	quietly count if inlist(check, "sysmiss2code", "val2code", "code2code", "code2val")
	assert r(N) == 0
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
di as res "All plumber tests passed."
di as txt "{hline 78}"

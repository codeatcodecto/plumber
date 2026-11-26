*------------------------------------------------------------------------------
* Do-file  : plumber_example.do
* Purpose  : Worked example of the plumber family on a generated three-stage
*            pipeline (raw -> clean -> labelled). Obtain with: net get plumber
* Requires : plumber, plumbchain, plumbmeta, plumbview
*------------------------------------------------------------------------------

version 14
clear
set more off
set seed 20261126

***01 Build a small three-stage pipeline in a temporary folder
local dir "`c(tmpdir)'/plumber_example"
cap mkdir "`dir'"

// Stage 1: raw survey extract
clear
set obs 200
gen long caseid = _n
gen byte sex = 1 + (runiform() < 0.5)
gen byte age = 18 + floor(60 * runiform())
gen byte q1 = 1 + floor(5 * runiform())
replace q1 = . if runiform() < 0.10
gen str20 city = "Doha"
replace city = "doha " if runiform() < 0.5
save "`dir'/stage1_raw.dta", replace

// Stage 2: cleaning (drop test cases, recode, code skips as -7, tidy strings)
drop if caseid > 195
replace age = . if age > 70
replace q1 = -7 if missing(q1)
replace city = "Doha" if strtrim(lower(city)) == "doha"
save "`dir'/stage2_clean.dta", replace

// Stage 3: labelling
label variable sex "Respondent sex"
label variable age "Age in years"
label variable q1 "Q1 satisfaction"
label define sexlbl 1 "Male" 2 "Female"
label define q1lbl 1 "Very low" 5 "Very high" -7 "Valid skip"
label values sex sexlbl
label values q1 q1lbl
save "`dir'/stage3_labelled.dta", replace

***02 plumber: what changed between raw and clean?
plumber, from("`dir'/stage1_raw.dta") to("`dir'/stage2_clean.dta") ///
	id(caseid) misscodes(-9 -8 -7) severity(from_only_cases=INFO) clear
list variable check severity n_affected if level == "values" & severity != "PASS", noobs

***03 plumbview: which cases and values?
plumbview age q1, from("`dir'/stage1_raw.dta") to("`dir'/stage2_clean.dta") ///
	id(caseid) changed maxrows(10) clear

***04 plumbchain: audit the whole pipeline step by step
plumbchain, files("`dir'/stage1_raw.dta" "`dir'/stage2_clean.dta" "`dir'/stage3_labelled.dta") ///
	stages(raw clean labelled) id(caseid) misscodes(-9 -8 -7) nopass clear
tabulate step sev_rank

***05 plumbmeta: data dictionary of the final stage
plumbmeta using "`dir'/stage3_labelled.dta", stats clear
list variable type varlab vallab n_nonmiss n_distinct, noobs

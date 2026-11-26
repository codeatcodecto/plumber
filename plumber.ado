*! version 1.0.0  26nov2026  plumber: audit changes between two stages of a data pipeline
*------------------------------------------------------------------------------
* Program  : plumber.ado
* Package  : plumber (plumber, plumbchain, plumbmeta, plumbview)
* Purpose  : Multi-level audit of a FROM dataset (earlier pipeline stage, e.g.
*            raw) against a TO dataset (later stage, e.g. cleaned): variable
*            existence, storage type/format, variable labels, value-label
*            assignment, value-label definitions, case coverage, cell values,
*            and RAW->TO value transitions.
* Author   : Brian W. Mandikiana <bwmandikiana@gmail.com>, SESRI, Qatar University
* Source   : https://github.com/codeatcodecto/plumber
* Requires : Stata 14.0 or later
* License  : MIT
* Design   : Read-only: neither input file is modified or re-saved.
*            String differences are flagged, never harmonised.
*            FROM variables are renamed to tempvar names before the merge, so
*            32-character names and names ending in _raw/_int are safe.
*            Single program, no sub-programs; brace-disciplined control flow.
*
* Change log
*   2026-11-26  v1.0.0  First public release (generalised from SESRI's
*                       internal sesri_compare v1.0.0): from()/to(), tag(),
*                       severity() overrides, no default missing codes.
*------------------------------------------------------------------------------

program define plumber, rclass
	version 14

***01 Parse options
	syntax , FROM(string) TO(string) [ID(namelist) LEVels(string) ///
		VARs(string) TOLerance(real 0) MISScodes(string) MAXTrans(integer 50) ///
		TAG(string) SEVerity(string) SAVing(string) TSV(string) REPLACE ///
		NOPASS FAILon(string) SHOW(integer 25) CLEAR]

***02 Validate inputs (skeptic-first)
	if c(changed) & "`clear'" == "" {
		di as err "no; data in memory would be lost (specify clear)"
		exit 4
	}
	foreach side in from to {
		capture confirm file `"``side''"'
		if _rc {
			di as err `"`side'() file not found: ``side''"'
			exit 601
		}
	}
	if `"`from'"' == `"`to'"' {
		di as txt "(note: from() and to() name the same file)"
	}
	if `tolerance' < 0 {
		di as err "tolerance() must be >= 0"
		exit 198
	}
	if `maxtrans' < 1 {
		di as err "maxtrans() must be >= 1"
		exit 198
	}

	// Missing-value codes: none by default (institution-specific)
	local misscodes : list retokenize misscodes
	foreach c of local misscodes {
		capture confirm number `c'
		if _rc {
			di as err "misscodes() must contain numbers only: `c'"
			exit 198
		}
	}
	local codes : subinstr local misscodes " " ",", all

	// Levels
	local allowed "exist type varlab vallab vldef cases values transitions"
	local levels = lower(`"`levels'"')
	if `"`levels'"' == "" {
		if "`id'" != "" {
			local levels "all"
		}
		else {
			local levels "meta"
		}
	}
	local lv ""
	foreach l of local levels {
		if "`l'" == "all" {
			local lv `lv' `allowed'
		}
		else if "`l'" == "meta" {
			local lv `lv' exist type varlab vallab vldef
		}
		else {
			local ok : list l in allowed
			if !`ok' {
				di as err "levels(): unknown level `l' (allowed: all meta `allowed')"
				exit 198
			}
			local lv `lv' `l'
		}
	}
	local has_t : list posof "transitions" in lv
	if `has_t' {
		local lv `lv' values
	}
	local has_v : list posof "values" in lv
	if `has_v' {
		local lv `lv' cases
	}
	local lv : list uniq lv
	foreach l of local allowed {
		local p : list posof "`l'" in lv
		local do_`l' = (`p' > 0)
	}
	if `do_cases' & "`id'" == "" {
		di as err "levels cases/values/transitions require id()"
		exit 198
	}

	// Severity overrides: check=LEVEL pairs
	local sevlevels "CRITICAL MAJOR MINOR INFO PASS"
	local sevpairs ""
	foreach tok of local severity {
		local eq = strpos("`tok'", "=")
		if `eq' < 2 {
			di as err "severity(): expected check=LEVEL, got `tok'"
			exit 198
		}
		local sl = upper(substr("`tok'", `eq' + 1, .))
		local okl : list sl in sevlevels
		if !`okl' {
			di as err "severity(): level must be one of `sevlevels' (got `sl')"
			exit 198
		}
		local sevpairs `sevpairs' `=substr("`tok'", 1, `eq' - 1)'=`sl'
	}

	// Pipeline gate
	local thr = 0
	if `"`failon'"' != "" {
		local failon = lower(`"`failon'"')
		if "`failon'" == "critical" {
			local thr = 1
		}
		else if "`failon'" == "major" {
			local thr = 2
		}
		else if "`failon'" == "minor" {
			local thr = 3
		}
		else {
			di as err "failon() must be critical, major or minor"
			exit 198
		}
	}

	// Default tag: <from basename> -> <to basename> (strrpos: mixed separators)
	foreach side in from to {
		local f = subinstr(`"``side''"', "\", "/", .)
		local b_`side' = substr(`"`f'"', strrpos(`"`f'"', "/") + 1, .)
		local b_`side' = ustrregexra(`"`b_`side''"', "(?i)\.dta$", "")
	}
	if `"`tag'"' == "" {
		local tag `"`b_from' -> `b_to'"'
	}

***03 Collect variable-level metadata from FROM and TO
	tempfile meta_from meta_to meta vl_from vl_to audit vrows trows fromv
	tempname ph vh
	foreach side in from to {
		quietly use `"``side''"', clear
		if c(k) == 0 {
			di as err "`side'() dataset contains no variables"
			exit 459
		}
		local N_`side' = c(N)
		local k_`side' = c(k)
		quietly label dir
		local defined `r(names)'
		postfile `ph' str32 variable str8 type_`side' str57 fmt_`side' ///
			str32 vallab_`side' byte vldefd_`side' str2045 varlab_`side' ///
			using `meta_`side'', replace
		foreach v of varlist _all {
			local t : type `v'
			local f : format `v'
			local vl : value label `v'
			local defd = .
			if "`vl'" != "" {
				local defd : list vl in defined
			}
			local lbl : variable label `v'
			post `ph' ("`v'") ("`t'") ("`f'") ("`vl'") (`defd') (`"`macval(lbl)'"')
		}
		postclose `ph'
		local ck_`side' "unavailable"
		capture checksum `"``side''"'
		if !_rc {
			local ck_`side' = r(checksum)
		}
	}

	quietly use `meta_from', clear
	quietly merge 1:1 variable using `meta_to', generate(_src)
	quietly gen byte _keep = (`"`vars'"' == "")
	foreach p of local vars {
		quietly replace _keep = 1 if strmatch(variable, `"`p'"')
	}
	quietly keep if _keep
	if _N == 0 {
		di as err "vars() matched no variable in FROM or TO"
		exit 111
	}
	drop _keep
	quietly save `meta'
	local has_audit = 0
	local ntrans = 0

***04 Level exist: variables dropped or added between stages
	if `do_exist' {
		quietly use `meta', clear
		quietly gen str12 level = "exist"
		quietly gen str32 check = "present_both"
		quietly replace check = "from_only" if _src == 1
		quietly replace check = "to_only" if _src == 2
		quietly gen str8 severity = "PASS"
		quietly replace severity = "MAJOR" if _src == 1
		quietly replace severity = "INFO" if _src == 2
		quietly gen str7 from_value = "present"
		quietly replace from_value = "absent" if _src == 2
		quietly gen str7 to_value = "present"
		quietly replace to_value = "absent" if _src == 1
		quietly gen str244 note = ""
		quietly replace note = "Variable dropped between stages: confirm it is documented" if _src == 1
		quietly replace note = "Variable added between stages: confirm it is documented" if _src == 2
		quietly gen str32 _low = lower(variable)
		quietly bysort _low: gen long _nlow = _N
		quietly replace note = note + " (possible case-only rename)" if _nlow > 1 & _src != 3
		keep level variable check from_value to_value severity note
		if `has_audit' {
			quietly append using `audit'
		}
		quietly save `audit', replace
		local has_audit = 1
	}

***05 Level type: storage type class, storage type, display format
	if `do_type' {
		quietly use `meta', clear
		quietly keep if _src == 3
		quietly expand 2
		quietly bysort variable: gen byte _r = _n
		quietly gen str12 level = "type"
		quietly gen str32 check = ""
		quietly gen str57 from_value = ""
		quietly gen str57 to_value = ""
		quietly gen str8 severity = "PASS"
		quietly gen str244 note = ""
		quietly gen byte _cls = (substr(type_from, 1, 3) == "str") != (substr(type_to, 1, 3) == "str")

		// Row 1: storage type
		quietly replace from_value = type_from if _r == 1
		quietly replace to_value = type_to if _r == 1
		quietly replace check = "storage_same" if _r == 1
		quietly replace check = "storage_changed" if _r == 1 & type_from != type_to
		quietly replace severity = "INFO" if _r == 1 & type_from != type_to
		quietly replace check = "class_changed" if _r == 1 & _cls
		quietly replace severity = "MAJOR" if _r == 1 & _cls
		quietly replace note = "Numeric/string class changed: cell values not comparable" if _r == 1 & _cls

		// Row 2: display format
		quietly replace from_value = fmt_from if _r == 2
		quietly replace to_value = fmt_to if _r == 2
		quietly replace check = "format_same" if _r == 2
		quietly replace check = "format_changed" if _r == 2 & fmt_from != fmt_to
		quietly replace severity = "INFO" if _r == 2 & fmt_from != fmt_to
		keep level variable check from_value to_value severity note
		if `has_audit' {
			quietly append using `audit'
		}
		quietly save `audit', replace
		local has_audit = 1
	}

***06 Level varlab: variable labels
	if `do_varlab' {
		quietly use `meta', clear
		quietly drop if _src == 1
		rename varlab_from from_value
		rename varlab_to to_value
		quietly gen str12 level = "varlab"
		quietly gen str32 check = ""
		quietly gen str8 severity = ""
		quietly gen str244 note = ""

		// TO-only variables: only a missing label is reportable here
		quietly drop if _src == 2 & to_value != ""
		quietly replace check = "label_missing" if _src == 2
		quietly replace severity = "MINOR" if _src == 2
		quietly replace note = "New TO variable has no variable label" if _src == 2

		// Variables present in both stages
		quietly replace check = "label_same" if _src == 3 & from_value == to_value & to_value != ""
		quietly replace severity = "PASS" if check == "label_same"
		quietly replace check = "label_missing" if _src == 3 & from_value == "" & to_value == ""
		quietly replace severity = "MINOR" if _src == 3 & from_value == "" & to_value == ""
		quietly replace note = "Variable is unlabelled in FROM and TO" if _src == 3 & from_value == "" & to_value == ""
		quietly replace check = "label_removed" if _src == 3 & from_value != "" & to_value == ""
		quietly replace severity = "MAJOR" if check == "label_removed"
		quietly replace note = "Label present in FROM but empty in TO" if check == "label_removed"
		quietly replace check = "label_added" if _src == 3 & from_value == "" & to_value != ""
		quietly replace severity = "INFO" if check == "label_added"
		quietly replace check = "label_changed" if _src == 3 & from_value != "" & to_value != "" & from_value != to_value
		quietly replace severity = "INFO" if check == "label_changed"
		keep level variable check from_value to_value severity note
		if `has_audit' {
			quietly append using `audit'
		}
		quietly save `audit', replace
		local has_audit = 1
	}

***07 Level vallab: value-label set assigned to each variable
	if `do_vallab' {
		quietly use `meta', clear
		quietly keep if _src == 3
		quietly drop if vallab_from == "" & vallab_to == ""
		rename vallab_from from_value
		rename vallab_to to_value
		quietly gen str12 level = "vallab"
		quietly gen str32 check = "vallab_same"
		quietly gen str8 severity = "PASS"
		quietly gen str244 note = ""
		quietly replace check = "vallab_changed" if from_value != "" & to_value != "" & from_value != to_value
		quietly replace severity = "INFO" if check == "vallab_changed"
		quietly replace check = "vallab_removed" if from_value != "" & to_value == ""
		quietly replace severity = "MAJOR" if check == "vallab_removed"
		quietly replace note = "Value label detached in TO" if check == "vallab_removed"
		quietly replace check = "vallab_added" if from_value == "" & to_value != ""
		quietly replace severity = "INFO" if check == "vallab_added"
		keep level variable check from_value to_value severity note
		if `has_audit' {
			quietly append using `audit'
		}
		quietly save `audit', replace
		local has_audit = 1

		// Value label attached in TO but never defined in TO
		quietly use `meta', clear
		quietly keep if _src != 1 & vldefd_to == 0
		quietly gen str12 level = "vallab"
		quietly gen str32 check = "vallab_undefined"
		quietly gen str32 from_value = vallab_from
		quietly gen str32 to_value = vallab_to
		quietly gen str8 severity = "MINOR"
		quietly gen str244 note = "Value label attached in TO but not defined in TO"
		keep level variable check from_value to_value severity note
		quietly append using `audit'
		quietly save `audit', replace
	}

***08 Level vldef: value-label definitions (code -> text)
	if `do_vldef' {
		// With vars(), restrict to label sets attached to the selected variables
		local lsets ""
		if `"`vars'"' != "" {
			quietly use `meta', clear
			forvalues i = 1/`=_N' {
				local a = vallab_from[`i']
				local b = vallab_to[`i']
				local lsets `lsets' `a' `b'
			}
			local lsets : list uniq lsets
		}
		foreach side in from to {
			capture quietly uselabel using `"``side''"', clear
			local urc = _rc
			if !`urc' {
				capture confirm variable lname value label trunc, exact
				local urc = _rc
			}
			if `urc' {
				clear
				quietly gen str32 lname = ""
				quietly gen double value = .
				quietly gen str1 label = ""
				quietly gen byte trunc = .
			}
			if `"`vars'"' != "" {
				quietly gen byte _k = 0
				foreach s of local lsets {
					quietly replace _k = 1 if lname == "`s'"
				}
				quietly keep if _k
				drop _k
			}
			rename label label_`side'
			rename trunc trunc_`side'
			quietly save `vl_`side'', replace
		}
		quietly use `vl_from', clear
		quietly merge 1:1 lname value using `vl_to', generate(_src)
		rename label_from from_value
		rename label_to to_value
		quietly gen str12 level = "vldef"
		quietly gen str32 variable = lname
		quietly gen str32 check = "code_same"
		quietly gen str8 severity = "PASS"
		quietly replace check = "code_from_only" if _src == 1
		quietly replace severity = "MINOR" if _src == 1
		quietly replace check = "code_to_only" if _src == 2
		quietly replace severity = "INFO" if _src == 2
		quietly replace check = "text_changed" if _src == 3 & from_value != to_value
		quietly replace severity = "MINOR" if check == "text_changed"
		quietly gen str244 note = "code " + string(value, "%21.0g")
		quietly replace note = note + "; text truncated by uselabel" if trunc_from == 1 | trunc_to == 1
		keep level variable check from_value to_value severity note
		if `has_audit' {
			quietly append using `audit'
		}
		quietly save `audit', replace
		local has_audit = 1
	}

***09 Levels cases / values / transitions (require id)
	if `do_cases' {
		// Variables common to both stages, excluding the key
		quietly use `meta', clear
		quietly keep if _src == 3
		local common ""
		forvalues i = 1/`=_N' {
			local vn = variable[`i']
			local isk : list vn in id
			if !`isk' {
				local common `common' `vn'
			}
		}

		// FROM: validate key, rename comparison variables to tempvar names
		quietly use `"`from'"', clear
		local idnum_from ""
		foreach k of local id {
			capture confirm variable `k', exact
			if _rc {
				di as err "id() variable `k' not found in FROM"
				exit 111
			}
			capture confirm numeric variable `k', exact
			local idnum_from `idnum_from' `=(_rc == 0)'
		}
		capture isid `id'
		if _rc {
			di as err "id(`id') does not uniquely identify FROM observations (duplicates or missing keys)"
			exit 459
		}
		keep `id' `common'
		local j = 0
		foreach v of local common {
			local ++j
			tempvar rv
			rename `v' `rv'
			local rn`j' `rv'
		}
		local ncommon = `j'
		quietly save `fromv'

		// TO: validate key, guard against name collision, merge
		quietly use `"`to'"', clear
		local idnum_to ""
		foreach k of local id {
			capture confirm variable `k', exact
			if _rc {
				di as err "id() variable `k' not found in TO"
				exit 111
			}
			capture confirm numeric variable `k', exact
			local idnum_to `idnum_to' `=(_rc == 0)'
		}
		if "`idnum_from'" != "`idnum_to'" {
			di as err "id() storage class (numeric/string) differs between FROM and TO"
			exit 109
		}
		capture isid `id'
		if _rc {
			di as err "id(`id') does not uniquely identify TO observations (duplicates or missing keys)"
			exit 459
		}
		keep `id' `common'
		forvalues j = 1/`ncommon' {
			capture confirm variable `rn`j'', exact
			if !_rc {
				di as err "internal name collision: `rn`j'' already exists in TO"
				exit 110
			}
		}
		tempvar m
		quietly merge 1:1 `id' using `fromv', generate(`m')
		quietly count if `m' == 1
		local n_toonly = r(N)
		quietly count if `m' == 2
		local n_fromonly = r(N)
		quietly count if `m' == 3
		local Nm = r(N)

		// First unmatched keys (single-variable keys only)
		local ex_from ""
		local ex_to ""
		if `: word count `id'' == 1 {
			tempvar cum
			if `n_fromonly' > 0 {
				quietly gen long `cum' = sum(`m' == 2)
				quietly levelsof `id' if `m' == 2 & `cum' <= 10, local(ex_from) clean
				drop `cum'
			}
			if `n_toonly' > 0 {
				quietly gen long `cum' = sum(`m' == 1)
				quietly levelsof `id' if `m' == 1 & `cum' <= 10, local(ex_to) clean
				drop `cum'
			}
		}

		postfile `vh' str12 level str32 variable str32 check str2045 from_value ///
			str2045 to_value double n_affected double n_compared ///
			double pct_affected str8 severity str244 note using `vrows', replace
		local idname = substr("`id'", 1, 32)
		post `vh' ("cases") ("`idname'") ("matched") ("") ("") (`Nm') (`N_from') ///
			(100 * `Nm' / `N_from') ("PASS") ("Cases present in FROM and TO")
		if `n_fromonly' > 0 {
			local nt `"Cases dropped in TO: expected only under a documented filter. First keys: `macval(ex_from)'"'
			post `vh' ("cases") ("`idname'") ("from_only_cases") ("") ("") (`n_fromonly') ///
				(`N_from') (100 * `n_fromonly' / `N_from') ("MAJOR") (substr(`"`macval(nt)'"', 1, 244))
		}
		if `n_toonly' > 0 {
			local nt `"Cases in TO with no FROM source. First keys: `macval(ex_to)'"'
			post `vh' ("cases") ("`idname'") ("to_only_cases") ("") ("") (`n_toonly') ///
				(`N_to') (100 * `n_toonly' / `N_to') ("CRITICAL") (substr(`"`macval(nt)'"', 1, 244))
		}

		// Category notes
		local nt_miss2miss "Missing type changed (e.g. . to .a)"
		local nt_val2sysmiss "Observed value set to Stata missing: check missing-value rules"
		local nt_sysmiss2code "System missing recoded to a missing-value code (typical of skip-pattern steps)"
		local nt_sysmiss2val "System missing filled with a valid value: verify source"
		local nt_val2code "Observed value recoded to a missing-value code: verify skip/DK/refusal logic"
		local nt_code2code "One missing-value code replaced by another"
		local nt_code2val "Missing-value code replaced by a valid value: verify justification"
		local nt_val2val "Valid value changed: verify against do-file and log"
		local nt_ws_only "Whitespace-only difference (flag and log only)"
		local nt_case_only "Letter-case-only difference (flag and log only)"
		local nt_val2empty "Non-empty string emptied in TO: verify"
		local nt_empty2val "Empty string filled in TO: verify source"

		if `do_values' & `Nm' == 0 {
			post `vh' ("values") ("_all") ("not_compared") ("") ("") (.) (0) (.) ///
				("CRITICAL") ("No matched cases: cell values could not be compared")
		}
		if `do_values' & `Nm' > 0 {
			quietly keep if `m' == 3
			local j = 0
			foreach v of local common {
				local ++j
				local r `rn`j''
				capture confirm string variable `v', exact
				local vstr = (_rc == 0)
				capture confirm string variable `r', exact
				local rstr = (_rc == 0)
				if `vstr' != `rstr' {
					post `vh' ("values") ("`v'") ("class_mismatch") ("") ("") (.) (`Nm') (.) ///
						("MAJOR") ("Numeric/string class differs: cell comparison not possible")
					continue
				}
				if !`vstr' {
					if "`codes'" != "" {
						local negr "inlist(`r', `codes')"
						local negv "inlist(`v', `codes')"
					}
					else {
						local negr "0"
						local negv "0"
					}
					local dd "!missing(`r') & !missing(`v') & abs(`v' - `r') > `tolerance'"
					local c1 "missing(`r') & missing(`v') & `r' != `v'"
					local c2 "!missing(`r') & missing(`v')"
					local c3 "missing(`r') & !missing(`v') & `negv'"
					local c4 "missing(`r') & !missing(`v') & !`negv'"
					local c5 "`dd' & !`negr' & `negv'"
					local c6 "`dd' & `negr' & `negv'"
					local c7 "`dd' & `negr' & !`negv'"
					local c8 "`dd' & !`negr' & !`negv'"
					local cats "miss2miss val2sysmiss sysmiss2code sysmiss2val val2code code2code code2val val2val"
					local sevs "MINOR MAJOR INFO MINOR INFO MINOR MAJOR MINOR"
					local ncat = 8
				}
				else {
					local nr "strtrim(stritrim(`r'))"
					local nv "strtrim(stritrim(`v'))"
					local df "`r' != `v' & ustrlower(`nr') != ustrlower(`nv')"
					local c1 "`r' != `v' & `nr' == `nv'"
					local c2 "`r' != `v' & `nr' != `nv' & ustrlower(`nr') == ustrlower(`nv')"
					local c3 "`df' & missing(`v')"
					local c4 "`df' & missing(`r')"
					local c5 "`df' & !missing(`r') & !missing(`v')"
					local cats "ws_only case_only val2empty empty2val val2val"
					local sevs "INFO INFO MAJOR MINOR MINOR"
					local ncat = 5
				}
				local nchg = 0
				local chg ""
				forvalues k = 1/`ncat' {
					quietly count if `c`k''
					local n`k' = r(N)
					local nchg = `nchg' + r(N)
					if `k' == 1 {
						local chg "(`c1')"
					}
					else {
						local chg "`chg' | (`c`k'')"
					}
				}
				if `nchg' == 0 {
					post `vh' ("values") ("`v'") ("no_change") ("") ("") (0) (`Nm') (0) ///
						("PASS") ("All matched cells identical")
				}
				forvalues k = 1/`ncat' {
					if `n`k'' > 0 {
						local cn : word `k' of `cats'
						local sv : word `k' of `sevs'
						post `vh' ("values") ("`v'") ("`cn'") ("") ("") (`n`k'') (`Nm') ///
							(100 * `n`k'' / `Nm') ("`sv'") ("`nt_`cn''")
					}
				}

				// Value transitions among changed cells (top maxtrans pairs)
				if `do_transitions' & `nchg' > 0 {
					preserve
					quietly keep if `chg'
					keep `r' `v'
					if `vstr' {
						quietly gen str2045 from_value = substr(`r', 1, 2045)
						quietly gen str2045 to_value = substr(`v', 1, 2045)
					}
					else {
						quietly gen str32 from_value = string(`r', "%21.0g")
						quietly gen str32 to_value = string(`v', "%21.0g")
					}
					quietly contract from_value to_value, freq(n_affected)
					quietly gsort -n_affected from_value to_value
					quietly keep in 1/`=min(_N, `maxtrans')'
					quietly gen str12 level = "transitions"
					quietly gen str32 variable = "`v'"
					quietly gen str32 check = "value_transition"
					quietly gen double n_compared = `Nm'
					quietly gen double pct_affected = 100 * n_affected / `Nm'
					quietly gen str8 severity = "INFO"
					quietly gen str244 note = "FROM -> TO value pair among changed cells"
					if `ntrans' {
						quietly append using `trows'
					}
					quietly save `trows', replace
					restore
					local ntrans = 1
				}
			}
		}
		postclose `vh'
	}

***10 Assemble the audit dataset
	clear
	if `has_audit' {
		quietly append using `audit'
	}
	if `do_cases' {
		quietly append using `vrows'
	}
	if `ntrans' {
		quietly append using `trows'
	}
	foreach s in level variable check from_value to_value severity note {
		capture confirm variable `s', exact
		if _rc {
			quietly gen str1 `s' = ""
		}
	}
	foreach s in n_affected n_compared pct_affected {
		capture confirm variable `s', exact
		if _rc {
			quietly gen double `s' = .
		}
	}

	// User severity overrides, applied before PASS filtering and counting
	foreach tok of local sevpairs {
		local eq = strpos("`tok'", "=")
		local ck = substr("`tok'", 1, `eq' - 1)
		local sl = substr("`tok'", `eq' + 1, .)
		quietly replace severity = "`sl'" if check == "`ck'"
	}
	if "`nopass'" != "" {
		quietly drop if severity == "PASS"
	}
	quietly gen str244 tag = substr(`"`tag'"', 1, 244)
	quietly gen byte sev_rank = 5
	quietly replace sev_rank = 1 if severity == "CRITICAL"
	quietly replace sev_rank = 2 if severity == "MAJOR"
	quietly replace sev_rank = 3 if severity == "MINOR"
	quietly replace sev_rank = 4 if severity == "INFO"
	label define _plumber_sev 1 "CRITICAL" 2 "MAJOR" 3 "MINOR" 4 "INFO" 5 "PASS", replace
	label values sev_rank _plumber_sev
	quietly gen byte _lo = 9
	local o = 0
	foreach l of local allowed {
		local ++o
		quietly replace _lo = `o' if level == "`l'"
	}
	sort sev_rank _lo variable check from_value
	drop _lo
	order tag level variable check severity from_value to_value ///
		n_affected n_compared pct_affected note sev_rank
	format pct_affected %6.2f
	label variable tag "Comparison tag (FROM -> TO)"
	label variable level "Audit level"
	label variable variable "Variable (value-label name for vldef; key for cases)"
	label variable check "Check outcome"
	label variable severity "Severity"
	label variable from_value "FROM attribute or value"
	label variable to_value "TO attribute or value"
	label variable n_affected "Cells or cases affected"
	label variable n_compared "Cells or cases compared"
	label variable pct_affected "Percent affected"
	label variable note "Audit note"
	label variable sev_rank "Severity rank (1 = most severe)"
	label data "plumber audit"
	char _dta[pl_from] `macval(from)'
	char _dta[pl_to] `macval(to)'
	char _dta[pl_checksum_from] `ck_from'
	char _dta[pl_checksum_to] `ck_to'
	char _dta[pl_levels] `lv'
	char _dta[pl_id] `id'
	char _dta[pl_tolerance] `tolerance'
	char _dta[pl_misscodes] `misscodes'
	char _dta[pl_severity] `sevpairs'
	char _dta[pl_version] 1.0.0
	char _dta[pl_run] $S_DATE $S_TIME
	quietly compress

***11 Counts (computed before any return statement)
	foreach s in CRITICAL MAJOR MINOR INFO PASS {
		quietly count if severity == "`s'"
		local N_`s' = r(N)
	}
	local N_rows = _N
	local fail = 0
	if `thr' > 0 {
		quietly count if sev_rank <= `thr'
		local fail = (r(N) > 0)
	}

***12 Save outputs
	if `"`saving'"' != "" {
		quietly save `"`saving'"', `replace'
	}
	if `"`tsv'"' != "" {
		quietly export delimited using `"`tsv'"', delimiter(tab) `replace'
	}

***13 Console report
	di as txt _n "{hline 78}"
	di as txt "plumber audit" _col(16) as res `"`tag'"'
	di as txt "Run" _col(16) as res "$S_DATE $S_TIME"
	di as txt "FROM" _col(16) as res `"`from'"' as txt "  (N=" as res `N_from' as txt ", k=" as res `k_from' as txt ")"
	di as txt "TO" _col(16) as res `"`to'"' as txt "  (N=" as res `N_to' as txt ", k=" as res `k_to' as txt ")"
	di as txt "Levels" _col(16) as res "`lv'"
	if `do_cases' {
		di as txt "Key" _col(16) as res "`id'" as txt "  matched=" as res `Nm' ///
			as txt "  FROM-only=" as res `n_fromonly' as txt "  TO-only=" as res `n_toonly'
	}
	di as txt "Findings" _col(16) as txt "CRITICAL=" as res `N_CRITICAL' as txt "  MAJOR=" as res `N_MAJOR' ///
		as txt "  MINOR=" as res `N_MINOR' as txt "  INFO=" as res `N_INFO' as txt "  PASS=" as res `N_PASS'
	di as txt "{hline 78}"
	if `N_rows' > 0 {
		tabulate level sev_rank, missing
	}
	quietly count if sev_rank <= 4
	if r(N) > 0 & `show' > 0 {
		di as txt _n "Top findings (sorted by severity; full table is in memory):"
		list level variable check severity from_value to_value n_affected ///
			if sev_rank <= 4 in 1/`=min(_N, `show')', noobs abbreviate(12) string(24) sepby(level)
	}
	if `"`saving'"' != "" {
		di as txt `"Audit dataset: `saving'"'
	}
	if `"`tsv'"' != "" {
		di as txt `"Audit TSV    : `tsv'"'
	}

***14 Return results
	return scalar N_critical = `N_CRITICAL'
	return scalar N_major = `N_MAJOR'
	return scalar N_minor = `N_MINOR'
	return scalar N_info = `N_INFO'
	return scalar N_pass = `N_PASS'
	return scalar N_rows = `N_rows'
	return scalar N_from = `N_from'
	return scalar N_to = `N_to'
	return scalar k_from = `k_from'
	return scalar k_to = `k_to'
	if `do_cases' {
		return scalar N_matched = `Nm'
		return scalar N_from_only = `n_fromonly'
		return scalar N_to_only = `n_toonly'
	}
	return local levels "`lv'"
	return local id "`id'"
	return local tag `"`tag'"'
	return local from `"`from'"'
	return local to `"`to'"'
	return local checksum_from "`ck_from'"
	return local checksum_to "`ck_to'"

	if `fail' {
		di as err "failon(`failon'): findings at or above `failon' severity"
		exit 9
	}
end

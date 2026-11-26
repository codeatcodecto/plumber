*! version 1.0.0  26nov2026  plumbmeta: variable-level metadata snapshot of a dataset
*------------------------------------------------------------------------------
* Program  : plumbmeta.ado
* Package  : plumber (plumber, plumbchain, plumbmeta, plumbview)
* Purpose  : Replace the data in memory with one row per variable describing
*            the dataset in memory or a dataset on disk: position, name,
*            storage type, format, variable label, value label (and whether
*            it is defined), non-missing / system-missing / extended-missing
*            counts, and optionally distinct count, minimum and maximum.
*            Use to snapshot each pipeline stage for a data dictionary or a
*            preservation export (TSV).
* Author   : Brian W. Mandikiana <bwmandikiana@gmail.com>, SESRI, Qatar University
* Source   : https://github.com/codeatcodecto/plumber
* Requires : Stata 14.0 or later
* License  : MIT
*
* Change log
*   2026-11-26  v1.0.0  First public release.
*------------------------------------------------------------------------------

program define plumbmeta, rclass
	version 14

***01 Parse and validate
	syntax [using/] [, SAVing(string) TSV(string) REPLACE STATs CLEAR]

	if c(changed) & "`clear'" == "" {
		di as err "no; data in memory would be lost (specify clear)"
		exit 4
	}
	if `"`using'"' != "" {
		capture confirm file `"`using'"'
		if _rc {
			di as err `"file not found: `using'"'
			exit 601
		}
		quietly use `"`using'"', clear
		local source `"`using'"'
	}
	else {
		local source `"`c(filename)'"'
		if `"`source'"' == "" {
			local source "(data in memory)"
		}
	}
	if c(k) == 0 {
		di as err "no variables to describe"
		exit 459
	}
	local N = c(N)
	local k = c(k)

***02 Collect metadata, one row per variable
	tempfile meta
	tempname ph
	quietly label dir
	local defined `r(names)'
	postfile `ph' long position str32 variable str8 type str57 format ///
		byte isnumeric str32 vallab byte vallab_defined str2045 varlab ///
		double n_nonmiss double n_sysmiss double n_extmiss ///
		double n_distinct double min double max using `meta', replace
	local pos = 0
	foreach v of varlist _all {
		local ++pos
		local t : type `v'
		local f : format `v'
		local vl : value label `v'
		local defd = .
		if "`vl'" != "" {
			local defd : list vl in defined
		}
		local lbl : variable label `v'
		capture confirm numeric variable `v', exact
		local isnum = (_rc == 0)
		quietly count if !missing(`v')
		local nn = r(N)
		local ns = .
		local ne = .
		if `isnum' {
			quietly count if `v' == .
			local ns = r(N)
			quietly count if `v' > .
			local ne = r(N)
		}
		else {
			local ns = `N' - `nn'
			local ne = 0
		}
		local nd = .
		local mn = .
		local mx = .
		if "`stats'" != "" & "`t'" != "strL" {
			tempvar first
			quietly bysort `v': gen byte `first' = (_n == 1) & !missing(`v')
			quietly count if `first'
			local nd = r(N)
			drop `first'
			if `isnum' {
				quietly summarize `v', meanonly
				if r(N) > 0 {
					local mn = r(min)
					local mx = r(max)
				}
			}
		}
		post `ph' (`pos') ("`v'") ("`t'") ("`f'") (`isnum') ("`vl'") (`defd') ///
			(`"`macval(lbl)'"') (`nn') (`ns') (`ne') (`nd') (`mn') (`mx')
	}
	postclose `ph'

***03 Build the metadata dataset
	quietly use `meta', clear
	if "`stats'" == "" {
		drop n_distinct min max
	}
	quietly gen str244 source = substr(`"`source'"', 1, 244)
	order source position variable
	label variable source "Dataset described"
	label variable position "Position in dataset"
	label variable variable "Variable name"
	label variable type "Storage type"
	label variable format "Display format"
	label variable isnumeric "1 = numeric"
	label variable vallab "Value label assigned"
	label variable vallab_defined "1 = value label defined, 0 = attached but undefined"
	label variable varlab "Variable label"
	label variable n_nonmiss "Non-missing observations"
	label variable n_sysmiss "System missing (.) or empty string"
	label variable n_extmiss "Extended missing (.a-.z)"
	if "`stats'" != "" {
		label variable n_distinct "Distinct non-missing values"
		label variable min "Minimum (numeric)"
		label variable max "Maximum (numeric)"
	}
	label data "plumbmeta snapshot"
	char _dta[pl_source] `macval(source)'
	char _dta[pl_N] `N'
	char _dta[pl_k] `k'
	char _dta[pl_version] 1.0.0
	char _dta[pl_run] $S_DATE $S_TIME
	quietly compress

	quietly count if varlab == ""
	local n_nolab = r(N)
	quietly count if vallab_defined == 0
	local n_undef = r(N)

***04 Save outputs
	if `"`saving'"' != "" {
		quietly save `"`saving'"', `replace'
	}
	if `"`tsv'"' != "" {
		quietly export delimited using `"`tsv'"', delimiter(tab) `replace'
	}

***05 Report
	di as txt _n "{hline 78}"
	di as txt "plumbmeta" _col(16) as res `"`source'"'
	di as txt "Observations" _col(16) as res `N' as txt "   Variables " as res `k'
	di as txt "Unlabelled" _col(16) as res `n_nolab' as txt " variable(s)   undefined value labels " as res `n_undef'
	if `"`saving'"' != "" {
		di as txt `"Saved        : `saving'"'
	}
	if `"`tsv'"' != "" {
		di as txt `"TSV          : `tsv'"'
	}
	di as txt "{hline 78}"

***06 Return results
	return scalar N = `N'
	return scalar k = `k'
	return scalar N_unlabelled = `n_nolab'
	return scalar N_vallab_undefined = `n_undef'
	return local source `"`source'"'
end

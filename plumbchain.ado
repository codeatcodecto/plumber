*! version 1.0.0  26nov2026  plumbchain: audit every step of a multi-stage data pipeline
*------------------------------------------------------------------------------
* Program  : plumbchain.ado
* Package  : plumber (plumber, plumbchain, plumbmeta, plumbview)
* Purpose  : Run plumber on consecutive pipeline stages (1->2, 2->3, ...) or,
*            with baseline, on the first stage against every later stage
*            (1->2, 1->3, ...). Stack the audit tables with step and stage
*            identifiers, report findings by step, and optionally gate the
*            pipeline on severity.
* Author   : Brian W. Mandikiana <bwmandikiana@gmail.com>, SESRI, Qatar University
* Source   : https://github.com/codeatcodecto/plumber
* Requires : Stata 14.0 or later; plumber.ado (same package family)
* License  : MIT
*
* Change log
*   2026-11-26  v1.0.0  First public release.
*------------------------------------------------------------------------------

program define plumbchain, rclass
	version 14

***01 Parse and validate
	syntax , FILES(string asis) [STAGEs(string asis) BASEline ///
		SAVing(string) TSV(string) REPLACE FAILon(string) VERbose CLEAR *]

	capture which plumber
	if _rc {
		di as err "plumbchain requires plumber.ado; install the plumber package"
		exit 111
	}
	if c(changed) & "`clear'" == "" {
		di as err "no; data in memory would be lost (specify clear)"
		exit 4
	}
	if ustrregexm(`"`options'"', "(?i)(^|[ ,])(from|to|tag|saving|tsv|failon|clear)\(") {
		di as err "from(), to(), tag(), saving(), tsv() and failon() are set by plumbchain"
		exit 198
	}

	// Stage files (quoted entries allowed for paths with spaces)
	local nf = 0
	foreach f of local files {
		local ++nf
		local f`nf' `"`f'"'
		capture confirm file `"`f'"'
		if _rc {
			di as err `"files(): stage `nf' not found: `f'"'
			exit 601
		}
	}
	if `nf' < 2 {
		di as err "files() needs at least two stage files"
		exit 198
	}

	// Stage labels: user-supplied or file basename without .dta
	local ns = 0
	foreach s of local stages {
		local ++ns
		local s`ns' `"`s'"'
	}
	if `ns' > 0 & `ns' != `nf' {
		di as err "stages() must list one label per file (`nf' files, `ns' labels)"
		exit 198
	}
	forvalues i = 1/`nf' {
		if `ns' == 0 {
			local p = subinstr(`"`f`i''"', "\", "/", .)
			local p = substr(`"`p'"', strrpos(`"`p'"', "/") + 1, .)
			local s`i' = ustrregexra(`"`p'"', "(?i)\.dta$", "")
		}
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

***02 Run plumber on each step and stack results
	tempfile acc
	local nsteps = `nf' - 1
	forvalues t = 1/`nsteps' {
		local a = `t'
		if "`baseline'" != "" {
			local a = 1
		}
		local b = `t' + 1
		local tg `"`s`a'' -> `s`b''"'
		if "`verbose'" != "" {
			plumber, from(`"`f`a''"') to(`"`f`b''"') tag(`"`tg'"') `options' clear
		}
		else {
			quietly plumber, from(`"`f`a''"') to(`"`f`b''"') tag(`"`tg'"') `options' clear
		}
		local c`t' = r(N_critical)
		local j`t' = r(N_major)
		local n`t' = r(N_minor)
		local i`t' = r(N_info)
		quietly gen int step = `t'
		quietly gen str244 from_stage = substr(`"`s`a''"', 1, 244)
		quietly gen str244 to_stage = substr(`"`s`b''"', 1, 244)
		if `t' > 1 {
			quietly append using `acc'
		}
		quietly save `acc', replace
	}

***03 Final stacked audit
	quietly use `acc', clear
	sort step sev_rank level variable check
	order step from_stage to_stage
	label variable step "Pipeline step"
	label variable from_stage "FROM stage"
	label variable to_stage "TO stage"
	label data "plumbchain audit"
	local mode "consecutive"
	if "`baseline'" != "" {
		local mode "baseline"
	}
	char _dta[pl_chain_mode] `mode'
	char _dta[pl_chain_steps] `nsteps'
	char _dta[pl_version] 1.0.0
	char _dta[pl_run] $S_DATE $S_TIME

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

	if `"`saving'"' != "" {
		quietly save `"`saving'"', `replace'
	}
	if `"`tsv'"' != "" {
		quietly export delimited using `"`tsv'"', delimiter(tab) `replace'
	}

***04 Report by step
	di as txt _n "{hline 78}"
	di as txt "plumbchain" _col(14) as res "`nf'" as txt " stages, " as res "`nsteps'" ///
		as txt " steps (" as res "`mode'" as txt ")   $S_DATE $S_TIME"
	di as txt "{hline 78}"
	di as txt "Step" _col(7) "FROM -> TO" _col(50) "CRIT" _col(57) "MAJOR" _col(64) "MINOR" _col(71) "INFO"
	forvalues t = 1/`nsteps' {
		local a = `t'
		if "`baseline'" != "" {
			local a = 1
		}
		local b = `t' + 1
		local tg = substr(`"`s`a'' -> `s`b''"', 1, 42)
		di as res %4.0f `t' _col(7) as txt `"`tg'"' _col(50) as res %4.0f `c`t'' ///
			_col(57) %5.0f `j`t'' _col(64) %5.0f `n`t'' _col(71) %4.0f `i`t''
	}
	di as txt "{hline 78}"
	di as txt "Total" _col(7) "CRITICAL=" as res `N_CRITICAL' as txt "  MAJOR=" as res `N_MAJOR' ///
		as txt "  MINOR=" as res `N_MINOR' as txt "  INFO=" as res `N_INFO'
	if `"`saving'"' != "" {
		di as txt `"Audit dataset: `saving'"'
	}
	if `"`tsv'"' != "" {
		di as txt `"Audit TSV    : `tsv'"'
	}

***05 Return results
	return scalar N_steps = `nsteps'
	return scalar N_critical = `N_CRITICAL'
	return scalar N_major = `N_MAJOR'
	return scalar N_minor = `N_MINOR'
	return scalar N_info = `N_INFO'
	return scalar N_pass = `N_PASS'
	return scalar N_rows = `N_rows'
	return local mode "`mode'"

	if `fail' {
		di as err "failon(`failon'): findings at or above `failon' severity"
		exit 9
	}
end

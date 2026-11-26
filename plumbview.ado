*! version 1.0.0  26nov2026  plumbview: side-by-side values of variables across two pipeline stages
*------------------------------------------------------------------------------
* Program  : plumbview.ado
* Package  : plumber (plumber, plumbchain, plumbmeta, plumbview)
* Purpose  : Replace the data in memory with a long, side-by-side listing of
*            selected variables for each case: key, variable, FROM value,
*            TO value, changed flag, and case presence. Optionally show
*            value-label text next to codes and keep only changed cells.
*            Long format avoids the 32-character limit that suffix-renaming
*            (rename *, suffix(_raw)) runs into.
* Author   : Brian W. Mandikiana <bwmandikiana@gmail.com>, SESRI, Qatar University
* Source   : https://github.com/codeatcodecto/plumber
* Requires : Stata 14.0 or later
* License  : MIT
*
* Change log
*   2026-11-26  v1.0.0  First public release.
*------------------------------------------------------------------------------

program define plumbview, rclass
	version 14

***01 Parse and validate
	syntax [anything(name=patterns)] , FROM(string) TO(string) ID(namelist) ///
		[CHANGED LABels MAXRows(integer 50) SAVing(string) TSV(string) ///
		REPLACE NOLIST CLEAR]

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
	if `maxrows' < 0 {
		di as err "maxrows() must be >= 0"
		exit 198
	}

***02 Variables common to both stages (describe using: no data loaded)
	quietly describe using `"`from'"', varlist
	local vfrom `r(varlist)'
	quietly describe using `"`to'"', varlist
	local vto `r(varlist)'
	local both : list vfrom & vto
	local both : list both - id
	local common ""
	foreach v of local both {
		local keepv = (`"`patterns'"' == "")
		foreach p of local patterns {
			if strmatch("`v'", `"`p'"') {
				local keepv = 1
			}
		}
		if `keepv' {
			local common `common' `v'
		}
	}
	local ncommon : word count `common'
	if `ncommon' == 0 {
		di as err "no variable common to FROM and TO matches the request"
		exit 111
	}

***03 Build display strings in each stage, then merge on the key
	tempfile fromv acc
	tempvar m
	foreach side in from to {
		quietly use `"``side''"', clear
		local idnum_`side' ""
		foreach k of local id {
			capture confirm variable `k', exact
			if _rc {
				di as err "id() variable `k' not found in `side'()"
				exit 111
			}
			capture confirm numeric variable `k', exact
			local idnum_`side' `idnum_`side'' `=(_rc == 0)'
		}
		capture isid `id'
		if _rc {
			di as err "id(`id') does not uniquely identify `side'() observations"
			exit 459
		}
		local keeplist `id'
		local j = 0
		foreach v of local common {
			local ++j
			tempvar b`side'`j' d`side'`j'
			capture confirm string variable `v', exact
			if !_rc {
				quietly gen str2045 `b`side'`j'' = substr(`v', 1, 2045)
			}
			else {
				quietly gen str32 `b`side'`j'' = string(`v', "%21.0g")
			}
			quietly gen str2045 `d`side'`j'' = `b`side'`j''
			local vl : value label `v'
			if "`labels'" != "" & "`vl'" != "" {
				quietly levelsof `v', local(vals)
				foreach val of local vals {
					local lab : label (`v') `val', strict
					if `"`macval(lab)'"' != "" {
						quietly replace `d`side'`j'' = `b`side'`j'' + " [" + `"`macval(lab)'"' + "]" if `v' == `val'
					}
				}
			}
			local keeplist `keeplist' `b`side'`j'' `d`side'`j''
		}
		keep `keeplist'
		if "`side'" == "from" {
			quietly save `fromv'
		}
	}
	if "`idnum_from'" != "`idnum_to'" {
		di as err "id() storage class (numeric/string) differs between FROM and TO"
		exit 109
	}
	quietly merge 1:1 `id' using `fromv', generate(`m')

***04 Reshape to long side-by-side rows, one variable at a time
	local nacc = 0
	local j = 0
	foreach v of local common {
		local ++j
		preserve
		keep `id' `m' `bfrom`j'' `dfrom`j'' `bto`j'' `dto`j''
		quietly gen str32 variable = "`v'"
		quietly gen long varorder = `j'
		quietly gen str2045 from_value = `dfrom`j''
		quietly gen str2045 to_value = `dto`j''
		quietly gen byte changed = (`bfrom`j'' != `bto`j'') if `m' == 3
		quietly gen str9 presence = "both"
		quietly replace presence = "from only" if `m' == 2
		quietly replace presence = "to only" if `m' == 1
		if "`changed'" != "" {
			quietly keep if changed == 1
		}
		keep `id' variable varorder from_value to_value changed presence
		if `nacc' {
			quietly append using `acc'
		}
		quietly save `acc', replace
		restore
		local nacc = 1
	}

***05 Final listing dataset
	quietly use `acc', clear
	sort `id' varorder
	drop varorder
	order `id' variable from_value to_value changed presence
	label variable variable "Variable"
	label variable from_value "FROM value"
	label variable to_value "TO value"
	label variable changed "1 = value differs (matched cases)"
	label variable presence "Case present in"
	label data "plumbview side-by-side listing"
	char _dta[pl_from] `macval(from)'
	char _dta[pl_to] `macval(to)'
	char _dta[pl_id] `id'
	char _dta[pl_version] 1.0.0
	char _dta[pl_run] $S_DATE $S_TIME
	quietly compress

	local N_rows = _N
	quietly count if changed == 1
	local N_changed = r(N)

	if `"`saving'"' != "" {
		quietly save `"`saving'"', `replace'
	}
	if `"`tsv'"' != "" {
		quietly export delimited using `"`tsv'"', delimiter(tab) `replace'
	}

***06 Report
	di as txt _n "plumbview" _col(12) as res `"`from'"' as txt "  ->  " as res `"`to'"'
	di as txt "Variables " as res `ncommon' as txt "   rows " as res `N_rows' ///
		as txt "   changed cells " as res `N_changed'
	if "`nolist'" == "" & `N_rows' > 0 & `maxrows' > 0 {
		list `id' variable from_value to_value changed presence ///
			in 1/`=min(_N, `maxrows')', noobs abbreviate(12) string(30) sepby(`id')
		if _N > `maxrows' {
			di as txt "(first `maxrows' of `N_rows' rows shown; full listing is in memory)"
		}
	}

***07 Return results
	return scalar N_rows = `N_rows'
	return scalar N_changed = `N_changed'
	return scalar k = `ncommon'
	return local varlist "`common'"
	return local id "`id'"
end

*------------------------------------------------------------------------------
* Do-file  : install.do
* Purpose  : Install (or reinstall) all four packages of the plumber family:
*            plumber, plumbchain, plumbmeta, plumbview.
* Usage    : From GitHub (default):
*              do "https://raw.githubusercontent.com/codeatcodecto/plumber/main/install.do"
*            From a local clone (run from the repository root):
*              do install.do local
*------------------------------------------------------------------------------

version 14
args source
local repo "https://raw.githubusercontent.com/codeatcodecto/plumber/main/"
if "`source'" == "local" {
	capture confirm file "plumber.pkg"
	if _rc {
		di as err "install.do local must be run from the repository root"
		exit 601
	}
	local repo "`c(pwd)'"
}

// plumber first: plumbchain depends on it
foreach p in plumber plumbchain plumbmeta plumbview {
	capture ado uninstall `p'
	net install `p', from("`repo'") replace
}
discard
foreach c in plumber plumbchain plumbmeta plumbview {
	which `c'
}
di as res _n "plumber family installed. Start with: help plumber"

*------------------------------------------------------------------------------
* Do-file  : uninstall.do
* Purpose  : Remove all four packages of the plumber family.
*------------------------------------------------------------------------------

version 14
foreach p in plumbchain plumbview plumbmeta plumber {
	capture noisily ado uninstall `p'
}
discard

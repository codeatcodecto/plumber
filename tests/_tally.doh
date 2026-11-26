* tests/_tally.doh: record the outcome of one test block.
* Expects locals t (test name) and rc (return code of the capture block).
if `rc' {
	local ++fail
	local failed `failed' `t'
	di as err "FAIL: `t' (rc=`rc')"
}
else {
	local ++pass
	di as res "PASS: `t'"
}

{smcl}
{* *! version 1.0.0  26nov2026}{...}
{vieweralsosee "plumbchain" "help plumbchain"}{...}
{vieweralsosee "plumbmeta" "help plumbmeta"}{...}
{vieweralsosee "plumbview" "help plumbview"}{...}
{vieweralsosee "[D] cf" "help cf"}{...}
{vieweralsosee "[D] datasignature" "help datasignature"}{...}
{viewerjumpto "Syntax" "plumber##syntax"}{...}
{viewerjumpto "Description" "plumber##description"}{...}
{viewerjumpto "Options" "plumber##options"}{...}
{viewerjumpto "Levels and checks" "plumber##levels"}{...}
{viewerjumpto "Output dataset" "plumber##output"}{...}
{viewerjumpto "Examples" "plumber##examples"}{...}
{viewerjumpto "Stored results" "plumber##results"}{...}
{viewerjumpto "Author" "plumber##author"}{...}
{title:Title}

{phang}
{bf:plumber} {hline 2} Audit changes between two stages of a data pipeline


{marker syntax}{...}
{title:Syntax}

{p 8 16 2}
{cmd:plumber}{cmd:,}
{opt from(filename)}
{opt to(filename)}
[{it:options}]

{synoptset 26 tabbed}{...}
{synopthdr}
{synoptline}
{syntab:Required}
{synopt:{opt from(filename)}}earlier stage, e.g. the raw dataset; read only{p_end}
{synopt:{opt to(filename)}}later stage, e.g. the cleaned dataset; read only{p_end}

{syntab:Scope}
{synopt:{opt id(varlist)}}case key, unique in both files; required for levels {it:cases}, {it:values}, {it:transitions}{p_end}
{synopt:{opt lev:els(list)}}any of {it:exist type varlab vallab vldef cases values transitions}, or {it:meta} or {it:all}{p_end}
{synopt:{opt var:s(patterns)}}restrict to variables matching names or {cmd:*}/{cmd:?} patterns{p_end}

{syntab:Value comparison}
{synopt:{opt tol:erance(#)}}absolute tolerance for numeric changes between non-missing cells; default {cmd:0}{p_end}
{synopt:{opt miss:codes(numbers)}}numeric missing-value codes, e.g. {cmd:-9 -8 -7}; default none{p_end}
{synopt:{opt maxt:rans(#)}}maximum value pairs per variable at level {it:transitions}; default {cmd:50}{p_end}

{syntab:Classification}
{synopt:{opt sev:erity(check=LEVEL ...)}}override default severities, e.g. {cmd:severity(from_only_cases=INFO)}{p_end}
{synopt:{opt fail:on(level)}}exit with r(9) if any finding at or above {it:critical}, {it:major} or {it:minor}{p_end}

{syntab:Output}
{synopt:{opt tag(string)}}label for this comparison; default {it:frombase} {cmd:->} {it:tobase}{p_end}
{synopt:{opt sav:ing(filename)}}save the audit table as a Stata dataset{p_end}
{synopt:{opt tsv(filename)}}export the audit table as tab-separated text{p_end}
{synopt:{opt replace}}overwrite files named in {opt saving()} and {opt tsv()}{p_end}
{synopt:{opt nopass}}drop PASS rows{p_end}
{synopt:{opt show(#)}}number of findings listed in the Results window; default {cmd:25}{p_end}
{synopt:{opt clear}}allow unsaved data in memory to be replaced{p_end}
{synoptline}
{p 4 6 2}
Default levels: {it:all} when {opt id()} is specified, otherwise {it:meta}
(= {it:exist type varlab vallab vldef}). {it:transitions} implies {it:values};
{it:values} implies {it:cases}.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:plumber} audits what happened to a dataset between two stages of a data
pipeline, for example raw -> ingested -> cleaned -> labelled -> released. It
compares the {opt from()} dataset with the {opt to()} dataset at the levels you
request and replaces the data in memory with a long audit table: one row per
level x variable x check, each with a severity.

{pstd}
Design principles:

{p 8 11 2}1. {bf:Read only.} Neither input file is modified or re-saved. Each
input's {cmd:checksum} is recorded in the audit table's characteristics.{p_end}
{p 8 11 2}2. {bf:Flag, never fix.} String differences are classified
(whitespace-only, case-only, emptied, filled, changed) but never harmonised.{p_end}
{p 8 11 2}3. {bf:Name-safe.} FROM variables are renamed to {cmd:tempvar} names
before the 1:1 merge, so 32-character names and existing names ending in
{cmd:_raw}/{cmd:_int} cannot collide or overflow, unlike
{cmd:rename *, suffix(_raw)}.{p_end}
{p 8 11 2}4. {bf:Falsifiable counts.} Numeric change categories are disjoint
and exhaustive, so category counts sum to the number of changed cells.{p_end}
{p 8 11 2}5. {bf:Exact names.} Existence is checked by exact name match, not
{cmd:confirm variable}, which accepts abbreviations by default.{p_end}


{marker options}{...}
{title:Options}

{phang}
{opt from(filename)} and {opt to(filename)} name the two stages. Paths may contain
spaces. Use the same {opt id()} in both files.

{phang}
{opt id(varlist)} specifies the case key. It must uniquely identify observations
in both files, contain no missing values, and have the same storage class
(numeric or string) in both files. Composite keys are allowed.

{phang}
{opt levels(list)} selects the audit levels; see {help plumber##levels:Levels and checks}.

{phang}
{opt vars(patterns)} restricts the metadata and value levels to matching variables.
At level {it:vldef}, only value-label sets attached to the selected variables are compared.

{phang}
{opt tolerance(#)} ignores numeric differences with |TO - FROM| <= {it:#} when both
cells are non-missing. Useful when a variable was recast between {cmd:float} and
{cmd:double}: {cmd:float(0.1)} and {cmd:double(0.1)} differ by about 1.5e-9.

{phang}
{opt misscodes(numbers)} lists the numeric codes your organisation uses for
item missing data (for example skip, don't know, refusal). They enable the
{it:code} categories at level {it:values}. With no codes, those categories are
always zero and such changes are counted as {it:val2val} or {it:sysmiss2val}.

{phang}
{opt severity(check=LEVEL ...)} replaces the default severity of every row whose
{cmd:check} equals {it:check}. {it:LEVEL} is one of CRITICAL, MAJOR, MINOR, INFO,
PASS. Example: a documented filter step that drops cases on purpose:
{cmd:severity(from_only_cases=INFO)}.

{phang}
{opt failon(level)} turns {cmd:plumber} into a pipeline gate. The audit table is
built, saved and displayed first; then {cmd:plumber} exits with return code 9
if any row has severity at or above {it:level}.


{marker levels}{...}
{title:Levels and checks (default severities)}

{p2colset 5 18 20 2}{...}
{p2col:{it:exist}}from_only (MAJOR), to_only (INFO), present_both (PASS); a note flags possible case-only renames{p_end}
{p2col:{it:type}}class_changed numeric<->string (MAJOR), storage_changed (INFO), format_changed (INFO){p_end}
{p2col:{it:varlab}}label_removed (MAJOR), label_missing (MINOR), label_changed, label_added (INFO){p_end}
{p2col:{it:vallab}}vallab_removed (MAJOR), vallab_undefined (MINOR: attached in TO but not defined), vallab_changed, vallab_added (INFO){p_end}
{p2col:{it:vldef}}code_from_only (MINOR), text_changed (MINOR), code_to_only (INFO); {cmd:variable} holds the label-set name{p_end}
{p2col:{it:cases}}to_only_cases (CRITICAL), from_only_cases (MAJOR), matched (PASS){p_end}
{p2col:{it:values}}see below; class_mismatch (MAJOR) when a variable changed numeric<->string{p_end}
{p2col:{it:transitions}}value_transition (INFO): each FROM -> TO value pair among changed cells, with its frequency{p_end}
{p2colreset}{...}

{pstd}
{bf:Numeric value categories.} Let {it:code} be a value listed in {opt misscodes()} and
{it:sysmiss} be a Stata missing value ({cmd:.} or {cmd:.a}-{cmd:.z}):

{p2colset 9 26 28 2}{...}
{p2col:miss2miss}sysmiss -> different sysmiss, e.g. {cmd:.} -> {cmd:.a} (MINOR){p_end}
{p2col:val2sysmiss}non-missing -> sysmiss (MAJOR){p_end}
{p2col:sysmiss2code}sysmiss -> code, typical of skip-pattern steps (INFO){p_end}
{p2col:sysmiss2val}sysmiss -> valid value (MINOR){p_end}
{p2col:val2code}valid value -> code (INFO){p_end}
{p2col:code2code}code -> different code (MINOR){p_end}
{p2col:code2val}code -> valid value (MAJOR){p_end}
{p2col:val2val}valid value -> different valid value (MINOR){p_end}
{p2colreset}{...}

{pstd}
{bf:String value categories:} ws_only (INFO), case_only (INFO), val2empty (MAJOR),
empty2val (MINOR), val2val (MINOR).

{pstd}
Severities are defaults for triage, not verdicts. Adjust them with {opt severity()}
to match your organisation's standard operating procedures.


{marker output}{...}
{title:Output dataset}

{pstd}
Variables: {cmd:tag level variable check severity from_value to_value n_affected
n_compared pct_affected note sev_rank}, sorted by severity. Characteristics
{cmd:_dta[pl_*]} record both file paths, their checksums, levels, key, tolerance,
missing codes, severity overrides, version and run time; see {help char}.


{marker examples}{...}
{title:Examples}

{pstd}Metadata audit after a labelling step (no key needed){p_end}
{phang2}{cmd:. plumber, from("01_raw/survey_RAW.dta") to("04_labels/survey_LAB.dta") levels(varlab vallab vldef) nopass clear}{p_end}

{pstd}Full audit with SESRI-style missing codes, saved for the archive{p_end}
{phang2}{cmd:. plumber, from("01_raw/survey_RAW.dta") to("03_clean/survey_INT.dta") id(caseid) misscodes(-9 -8 -7 -6 -5) saving("audit/raw_vs_int.dta") tsv("audit/raw_vs_int.tsv") replace clear}{p_end}

{pstd}Pipeline gate: stop the master do-file if any case appeared from nowhere{p_end}
{phang2}{cmd:. plumber, from("raw.dta") to("clean.dta") id(hhid pid) levels(cases values) failon(critical) clear}{p_end}

{pstd}A documented filter step drops cases on purpose{p_end}
{phang2}{cmd:. plumber, from("raw.dta") to("eligible.dta") id(caseid) severity(from_only_cases=INFO) clear}{p_end}

{pstd}Inspect what a recode did{p_end}
{phang2}{cmd:. plumber, from("raw.dta") to("clean.dta") id(caseid) vars(q1* educ) levels(transitions) clear}{p_end}
{phang2}{cmd:. list variable from_value to_value n_affected if level == "transitions", sepby(variable)}{p_end}

{pstd}A worked example with generated data: {cmd:net get plumber}, then {cmd:do plumber_example.do}.{p_end}


{marker results}{...}
{title:Stored results}

{pstd}{cmd:plumber} stores the following in {cmd:r()}:{p_end}

{synoptset 22 tabbed}{...}
{p2col 5 22 26 2: Scalars}{p_end}
{synopt:{cmd:r(N_critical)}}rows with severity CRITICAL{p_end}
{synopt:{cmd:r(N_major)}}rows with severity MAJOR{p_end}
{synopt:{cmd:r(N_minor)}}rows with severity MINOR{p_end}
{synopt:{cmd:r(N_info)}}rows with severity INFO{p_end}
{synopt:{cmd:r(N_pass)}}rows with severity PASS{p_end}
{synopt:{cmd:r(N_rows)}}rows in the audit table{p_end}
{synopt:{cmd:r(N_from)}, {cmd:r(N_to)}}observations in each file{p_end}
{synopt:{cmd:r(k_from)}, {cmd:r(k_to)}}variables in each file{p_end}
{synopt:{cmd:r(N_matched)}}matched cases (with {opt id()}){p_end}
{synopt:{cmd:r(N_from_only)}}cases only in FROM (with {opt id()}){p_end}
{synopt:{cmd:r(N_to_only)}}cases only in TO (with {opt id()}){p_end}

{p2col 5 22 26 2: Macros}{p_end}
{synopt:{cmd:r(levels)}}levels run{p_end}
{synopt:{cmd:r(id)}}case key{p_end}
{synopt:{cmd:r(tag)}}comparison tag{p_end}
{synopt:{cmd:r(from)}, {cmd:r(to)}}file names{p_end}
{synopt:{cmd:r(checksum_from)}, {cmd:r(checksum_to)}}{cmd:checksum} of each input{p_end}


{marker author}{...}
{title:Author}

{pstd}Brian W. Mandikiana, SESRI, Qatar University{p_end}
{pstd}{browse "mailto:bwmandikiana@gmail.com":bwmandikiana@gmail.com}{p_end}
{pstd}Bug reports and suggestions: {browse "https://github.com/codeatcodecto/plumber/issues"}{p_end}

{title:Also see}

{psee}
Help: {help plumbchain}, {help plumbmeta}, {help plumbview}, {help cf}, {help datasignature}, {help merge}
{p_end}

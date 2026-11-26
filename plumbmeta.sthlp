{smcl}
{* *! version 1.0.0  26nov2026}{...}
{vieweralsosee "plumber" "help plumber"}{...}
{vieweralsosee "[D] describe" "help describe"}{...}
{vieweralsosee "[D] codebook" "help codebook"}{...}
{viewerjumpto "Syntax" "plumbmeta##syntax"}{...}
{viewerjumpto "Description" "plumbmeta##description"}{...}
{viewerjumpto "Output dataset" "plumbmeta##output"}{...}
{viewerjumpto "Examples" "plumbmeta##examples"}{...}
{viewerjumpto "Stored results" "plumbmeta##results"}{...}
{title:Title}

{phang}
{bf:plumbmeta} {hline 2} Variable-level metadata snapshot of a dataset


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:plumbmeta} [{cmd:using} {it:filename}] [{cmd:,} {it:options}]

{synoptset 20 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt stat:s}}add distinct count, minimum and maximum (slower: sorts each variable){p_end}
{synopt:{opt sav:ing(filename)}}save the snapshot as a Stata dataset{p_end}
{synopt:{opt tsv(filename)}}export the snapshot as tab-separated text{p_end}
{synopt:{opt replace}}overwrite output files{p_end}
{synopt:{opt clear}}allow unsaved data in memory to be replaced{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:plumbmeta} replaces the data in memory with one row per variable of the
dataset in memory, or of {it:filename} when {cmd:using} is specified. Use it to
snapshot each pipeline stage, build a data dictionary, or export metadata as
TSV for preservation. Unlike {cmd:describe, replace}, it also reports whether
each attached value label is actually defined, and counts system-missing and
extended-missing values separately.


{marker output}{...}
{title:Output dataset}

{p2colset 5 22 24 2}{...}
{p2col:{cmd:source}}dataset described{p_end}
{p2col:{cmd:position}}position in the dataset{p_end}
{p2col:{cmd:variable}}name{p_end}
{p2col:{cmd:type}, {cmd:format}}storage type and display format{p_end}
{p2col:{cmd:isnumeric}}1 if numeric{p_end}
{p2col:{cmd:vallab}}value label attached{p_end}
{p2col:{cmd:vallab_defined}}1 defined; 0 attached but not defined; missing if none attached{p_end}
{p2col:{cmd:varlab}}variable label{p_end}
{p2col:{cmd:n_nonmiss}}non-missing observations{p_end}
{p2col:{cmd:n_sysmiss}}{cmd:.} for numeric variables, empty string for strings{p_end}
{p2col:{cmd:n_extmiss}}{cmd:.a}-{cmd:.z} (numeric only){p_end}
{p2col:{cmd:n_distinct}, {cmd:min}, {cmd:max}}with {opt stats}; {cmd:n_distinct} not computed for strL{p_end}
{p2colreset}{...}


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. plumbmeta using "03_clean/survey_INT.dta", stats tsv("docs/dictionary.tsv") replace clear}{p_end}
{phang2}{cmd:. list variable varlab vallab if vallab_defined == 0}{p_end}

{pstd}Snapshot the data in memory (replaces it){p_end}
{phang2}{cmd:. sysuse auto, clear}{p_end}
{phang2}{cmd:. plumbmeta, stats clear}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 24 tabbed}{...}
{p2col 5 24 28 2: Scalars}{p_end}
{synopt:{cmd:r(N)}}observations in the described dataset{p_end}
{synopt:{cmd:r(k)}}variables in the described dataset{p_end}
{synopt:{cmd:r(N_unlabelled)}}variables without a variable label{p_end}
{synopt:{cmd:r(N_vallab_undefined)}}variables with an undefined value label attached{p_end}
{p2col 5 24 28 2: Macros}{p_end}
{synopt:{cmd:r(source)}}dataset described{p_end}


{title:Author}

{pstd}Brian W. Mandikiana, SESRI, Qatar University{p_end}
{pstd}{browse "mailto:bwmandikiana@gmail.com":bwmandikiana@gmail.com}{p_end}
{pstd}Bug reports and suggestions: {browse "https://github.com/codeatcodecto/plumber/issues"}{p_end}

{title:Also see}

{psee}Help: {help plumber}, {help describe}, {help codebook}, {help uselabel}{p_end}

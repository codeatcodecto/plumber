{smcl}
{* *! version 1.0.0  26nov2026}{...}
{vieweralsosee "plumber" "help plumber"}{...}
{vieweralsosee "[D] merge" "help merge"}{...}
{viewerjumpto "Syntax" "plumbview##syntax"}{...}
{viewerjumpto "Description" "plumbview##description"}{...}
{viewerjumpto "Options" "plumbview##options"}{...}
{viewerjumpto "Examples" "plumbview##examples"}{...}
{viewerjumpto "Stored results" "plumbview##results"}{...}
{title:Title}

{phang}
{bf:plumbview} {hline 2} Side-by-side listing of variable values across two pipeline stages


{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:plumbview} [{it:names_or_patterns}]{cmd:,}
{opt from(filename)}
{opt to(filename)}
{opt id(varlist)}
[{it:options}]

{synoptset 22 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt from(filename)}}earlier stage; read only{p_end}
{synopt:{opt to(filename)}}later stage; read only{p_end}
{synopt:{opt id(varlist)}}case key, unique in both files{p_end}
{synopt:{opt changed}}keep only matched cells whose values differ{p_end}
{synopt:{opt lab:els}}append value-label text to codes, e.g. {cmd:2 [Female]}{p_end}
{synopt:{opt maxr:ows(#)}}rows listed in the Results window; default {cmd:50}{p_end}
{synopt:{opt nolist}}do not list; leave the result in memory only{p_end}
{synopt:{opt sav:ing(filename)}}save the listing as a Stata dataset{p_end}
{synopt:{opt tsv(filename)}}export the listing as tab-separated text{p_end}
{synopt:{opt replace}}overwrite output files{p_end}
{synopt:{opt clear}}allow unsaved data in memory to be replaced{p_end}
{synoptline}
{p 4 6 2}
{it:names_or_patterns} select variables common to both files (wildcards {cmd:*} and {cmd:?}
allowed). Default: all common variables except the key.{p_end}


{marker description}{...}
{title:Description}

{pstd}
{cmd:plumbview} merges two stages on {opt id()} and replaces the data in memory
with one row per case x variable: the key, {cmd:variable}, {cmd:from_value},
{cmd:to_value}, {cmd:changed} (1/0 for matched cases, missing otherwise) and
{cmd:presence} ({cmd:both}, {cmd:from only}, {cmd:to only}). Values are shown
as text (numbers with {cmd:%21.0g}), so numeric and string variables share one
long table and variable-name length never limits the comparison.

{pstd}
Use {help plumber} to find which variables changed and {cmd:plumbview} to see
the cases and values involved.


{marker options}{...}
{title:Options}

{phang}
{opt changed} keeps only matched cases whose FROM and TO text values differ. Change
detection uses the values without label text, so relabelling alone is not a change.

{phang}
{opt labels} appends the value-label text from each file's own label set to
labelled codes. Unlabelled codes are shown as numbers only.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. plumbview gender birth child, from("raw.dta") to("clean.dta") id(caseid) labels clear}{p_end}
{phang2}{cmd:. plumbview q1*, from("raw.dta") to("clean.dta") id(caseid) changed maxrows(100) clear}{p_end}
{phang2}{cmd:. plumbview, from("raw.dta") to("clean.dta") id(hhid pid) changed nolist tsv("audit/changed_cells.tsv") replace clear}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 18 tabbed}{...}
{p2col 5 18 22 2: Scalars}{p_end}
{synopt:{cmd:r(N_rows)}}rows in the listing{p_end}
{synopt:{cmd:r(N_changed)}}changed cells among matched cases{p_end}
{synopt:{cmd:r(k)}}variables compared{p_end}
{p2col 5 18 22 2: Macros}{p_end}
{synopt:{cmd:r(varlist)}}variables compared{p_end}
{synopt:{cmd:r(id)}}case key{p_end}


{title:Author}

{pstd}Brian W. Mandikiana, SESRI, Qatar University{p_end}
{pstd}{browse "mailto:bwmandikiana@gmail.com":bwmandikiana@gmail.com}{p_end}
{pstd}Bug reports and suggestions: {browse "https://github.com/codeatcodecto/plumber/issues"}{p_end}

{title:Also see}

{psee}Help: {help plumber}, {help plumbchain}, {help merge}{p_end}

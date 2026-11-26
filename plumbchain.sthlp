{smcl}
{* *! version 1.0.0  26nov2026}{...}
{vieweralsosee "plumber" "help plumber"}{...}
{vieweralsosee "plumbmeta" "help plumbmeta"}{...}
{vieweralsosee "plumbview" "help plumbview"}{...}
{viewerjumpto "Syntax" "plumbchain##syntax"}{...}
{viewerjumpto "Description" "plumbchain##description"}{...}
{viewerjumpto "Options" "plumbchain##options"}{...}
{viewerjumpto "Examples" "plumbchain##examples"}{...}
{viewerjumpto "Stored results" "plumbchain##results"}{...}
{title:Title}

{phang}
{bf:plumbchain} {hline 2} Audit every step of a multi-stage data pipeline


{marker syntax}{...}
{title:Syntax}

{p 8 18 2}
{cmd:plumbchain}{cmd:,}
{opt files(filelist)}
[{it:options} {it:plumber_options}]

{synoptset 24 tabbed}{...}
{synopthdr}
{synoptline}
{synopt:{opt files(filelist)}}two or more stage datasets in pipeline order; quote paths with spaces{p_end}
{synopt:{opt stage:s(labellist)}}one label per file; default is each file's base name{p_end}
{synopt:{opt base:line}}compare the first stage with every later stage instead of consecutive pairs{p_end}
{synopt:{opt sav:ing(filename)}}save the stacked audit table{p_end}
{synopt:{opt tsv(filename)}}export the stacked audit table as tab-separated text{p_end}
{synopt:{opt replace}}overwrite output files{p_end}
{synopt:{opt fail:on(level)}}exit with r(9) if any step has a finding at or above {it:critical}, {it:major} or {it:minor}{p_end}
{synopt:{opt ver:bose}}show each step's full {cmd:plumber} report{p_end}
{synopt:{opt clear}}allow unsaved data in memory to be replaced{p_end}
{synopt:{it:plumber_options}}any {help plumber} option except {opt from()}, {opt to()}, {opt tag()}, {opt saving()}, {opt tsv()}, {opt failon()}{p_end}
{synoptline}


{marker description}{...}
{title:Description}

{pstd}
{cmd:plumbchain} runs {help plumber} on each step of a pipeline and stacks the
audit tables. By default the steps are consecutive (1->2, 2->3, ...), which
shows where a change was introduced. With {opt baseline}, every stage is
compared with the first (1->2, 1->3, ...), which shows the cumulative effect
of the pipeline up to each stage.

{pstd}
The result in memory has the {cmd:plumber} audit variables plus {cmd:step},
{cmd:from_stage} and {cmd:to_stage}. A step-by-severity summary is displayed.
{cmd:plumbchain} requires the {cmd:plumber} package.


{marker options}{...}
{title:Options}

{phang}
{opt files(filelist)} lists the stage datasets in pipeline order, for example
{cmd:files("01_raw/s.dta" "02_ingest/s.dta" "03_clean/s.dta")}.

{phang}
{opt stages(labellist)} gives readable stage names, for example
{cmd:stages(raw ingest clean)}. The number of labels must equal the number of files.

{phang}
{it:plumber_options} such as {opt id()}, {opt levels()}, {opt vars()}, {opt misscodes()},
{opt tolerance()}, {opt severity()} and {opt nopass} are passed to every step.


{marker examples}{...}
{title:Examples}

{phang2}{cmd:. plumbchain, files("01_raw/s.dta" "02_ingest/s.dta" "03_clean/s.dta" "04_labels/s.dta") stages(raw ingest clean labels) id(caseid) misscodes(-9 -8 -7) nopass clear}{p_end}
{phang2}{cmd:. tabulate step sev_rank}{p_end}
{phang2}{cmd:. list step check variable n_affected if level == "values" & sev_rank <= 2, sepby(step)}{p_end}

{pstd}Cumulative view against the raw file, saved for the archive and used as a gate{p_end}
{phang2}{cmd:. plumbchain, files("raw.dta" "clean.dta" "final.dta") baseline id(caseid) levels(meta cases) saving("audit/chain.dta") replace failon(critical) clear}{p_end}


{marker results}{...}
{title:Stored results}

{synoptset 20 tabbed}{...}
{p2col 5 20 24 2: Scalars}{p_end}
{synopt:{cmd:r(N_steps)}}number of steps compared{p_end}
{synopt:{cmd:r(N_critical)}}CRITICAL rows across steps{p_end}
{synopt:{cmd:r(N_major)}}MAJOR rows across steps{p_end}
{synopt:{cmd:r(N_minor)}}MINOR rows across steps{p_end}
{synopt:{cmd:r(N_info)}}INFO rows across steps{p_end}
{synopt:{cmd:r(N_pass)}}PASS rows across steps{p_end}
{synopt:{cmd:r(N_rows)}}rows in the stacked table{p_end}
{p2col 5 20 24 2: Macros}{p_end}
{synopt:{cmd:r(mode)}}{cmd:consecutive} or {cmd:baseline}{p_end}


{title:Author}

{pstd}Brian W. Mandikiana, SESRI, Qatar University{p_end}
{pstd}{browse "mailto:bwmandikiana@gmail.com":bwmandikiana@gmail.com}{p_end}
{pstd}Bug reports and suggestions: {browse "https://github.com/codeatcodecto/plumber/issues"}{p_end}

{title:Also see}

{psee}Help: {help plumber}, {help plumbmeta}, {help plumbview}{p_end}

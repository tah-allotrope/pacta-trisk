# Project: PACTA Vietnam
One-sentence What/Why: End-to-end PACTA (Paris Agreement Capital Transition Assessment) demo and reporting pipeline to learn the methodology and produce shareable alignment outputs.

High-level map:
- scripts/: runnable PACTA pipelines and report builders
- compare/: staff implementation and comparison artifacts
- output/ and synthesis_output/: generated datasets and plots
- reports/: rendered HTML reports
- docs/: domain guides and references

How to run (package manager / runtime):
- Use base R with Rscript (no Node/npm).
- Dependencies are installed with install.packages to the user library on Windows.

Essential commands (discover exact entrypoints by listing scripts/ and compare/):
- Run main pipeline: `Rscript scripts/<pipeline>.R`
- Build reports: `Rscript scripts/<report_builder>.R`
- Run AI vs staff comparison: `Rscript compare/<comparison>.R`

Progressive disclosure:
- For methodology, data dictionary, and domain rules, see docs/.
- Use directory listing and search to locate current entrypoints before executing.

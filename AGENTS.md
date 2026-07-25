# Project: PACTA + TRISK Vietnam
One-sentence What/Why: End-to-end PACTA (Paris Agreement Capital Transition
Assessment) + TRISK transition-risk demo and reporting pipeline for a synthetic
Vietnamese bank case, feeding a Streamlit dashboard and client engagement
deliverables.

High-level map:
- `scripts/`: R pipeline stages (PACTA, TRISK, prioritization, engagement
  scoring, letters, disclosure) and `run_engagement.R`, the single
  orchestrator for every engagement including the public MCB demo;
  `pipeline_refresh.R` is a thin wrapper that delegates to it
- `R/`: shared R modules sourced by `scripts/*.R` (engagement config loader,
  sector registry, report toolkit, matching helpers)
- `data/` and `synthesis_output/`: synthetic inputs and generated pipeline
  outputs
- `dashboard/`: the Streamlit app (`app.py`, `pages/`, `lib/`, `tests/`) and
  its frozen snapshot (`dashboard/data/`)
- `reports/`: rendered self-contained HTML reports
- `docs/`: methodology guides, deployment notes, assumption registers
- `attic/`: superseded methodology-reference scripts (see `attic/README.md`),
  kept for historical context only — not part of any pipeline

For the full architecture diagram and repository map, see `README.md`. For
repo-specific laws, traps, and exact commands, see `CLAUDE.md` — it is the
source of truth and takes precedence over this file.

How to run (package manager / runtime):
- Base R via `Rscript` (no Node/npm) for the pipeline; Python 3.11+ with
  Streamlit for the dashboard.
- R dependencies pinned in `renv.lock`; restore with `Rscript -e "renv::restore()"`
  or the no-renv fallback `Rscript scripts/ci/install_deps.R`.

Essential commands (see `CLAUDE.md` for the full list):
- Run PACTA pipeline: `Rscript scripts/pacta_vietnam_scenario.R`
- Run full pipeline refresh: `Rscript scripts/pipeline_refresh.R`
- Run R tests: `Rscript -e "testthat::test_dir('tests/testthat')"`
- Run dashboard tests: `python -m pytest dashboard/tests`

Progressive disclosure:
- For methodology, data dictionary, and domain rules, see `docs/`.
- For implementation plans and research briefs, see `plans/` and `research/`.
- Use directory listing and search to locate current entrypoints before
  executing.

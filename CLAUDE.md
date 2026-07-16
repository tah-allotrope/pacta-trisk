# CLAUDE.md — Repo Laws

PACTA + TRISK Vietnam: a synthetic-data demo platform showing how a fictional
Vietnamese bank ("Mekong Commercial Bank", MCB) could measure loanbook climate
alignment (PACTA) and transition-risk stress (TRISK). **All data is synthetic.**
See `README.md` for the full architecture and `AGENTS.md` for a quick map.

## Commands

- **Full R test suite:** `Rscript -e "testthat::test_dir('tests/testthat')"`
- **Single R test file:** `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`
- **Python test suite:** `python -m pytest dashboard/tests`
- **Regenerate PACTA outputs:** `Rscript scripts/pacta_vietnam_scenario.R`
- **Full pipeline refresh:** `Rscript scripts/pipeline_refresh.R`
- **Run the dashboard:** `python -m streamlit run dashboard/app.py`

Windows: prepend `& "C:\Program Files\R\R-4.5.2\bin\Rscript.exe"` or add it to
`PATH` for the session. Linux/CI: plain `Rscript`.

## Laws (violate these and something breaks downstream)

1. **Always run R commands from the repo root.** Every script resolves paths
   via `getwd()`; `tests/testthat/helper-root.R`'s `project_root()` walks
   upward looking for a `dashboard/` directory.
2. **VND is never rescaled.** Loanbook money (`loan_size_outstanding`, currency
   literal `VND`) spans raw magnitudes 1e5–5e12. Never divide/multiply except
   where existing code already does so for display (e.g. a `cat()` summary).
3. **Vietnamese names are matched after ASCII normalization.** Use
   `normalize_vn_name()` from `R/matching_helpers.R` (wraps
   `stringi::stri_trans_general(x, "Latin-ASCII")`). CSVs are UTF-8, no BOM.
4. **The golden-number tests are load-bearing.** `tests/testthat/test_golden_numbers.R`
   pins exact values (e.g. `engagement_priority.csv` rank-1 `name_abcd` ==
   `"Nghi Son Power LLC"`, `composite_score[1]` == 1.0). A green run of the
   full suite is the primary proof that a refactor changed nothing observable.
5. **Refactor acceptance bar: byte-identical MCB CSV outputs.** Any change
   touching `scripts/` or `R/` must leave every `synthesis_output/vietnam/*.csv`
   byte-identical to its pre-change hash (verify with `tools::md5sum`). PNGs
   are compared visually only (compression is nondeterministic); HTML reports
   may differ only in the generated-timestamp text.
6. **The engagement-config convention.** Scripts source `R/engagement_config.R`
   and call `cfg <- load_engagement_config(get_config_arg())`. No `--config`
   flag → MCB defaults, reproducing today's hardcoded paths exactly. Do not
   hardcode a new path outside this mechanism.
7. **PowerShell 5.1 has no `&&` chaining.** Use separate commands or `;`
   sequencing on Windows; prefer the portable `Rscript -e "..."` one-liners
   used throughout this repo, which run identically on Windows and Linux.
8. **Do not add pipeline dependencies casually.** The analysis stack is pinned
   in `renv.lock`. `yaml` was deliberately rejected in favor of JSON configs
   via `jsonlite`. Dev-only tooling (e.g. `roxygen2`/`devtools`) is the only
   category added without a strong reason.

## Do-not-touch

- `attic/` — retired methodology-reference scripts (see `attic/README.md`),
  kept for historical reference only. Not sourced by any pipeline, not tested.
- `dashboard/data/` — the frozen public snapshot. Only
  `scripts/refresh_dashboard_data.R` (via `pipeline_refresh.R`) may write it.
- Synthetic-data disclaimers (README banner, dashboard banners, report
  footers) — these must always state the data is synthetic/illustrative.

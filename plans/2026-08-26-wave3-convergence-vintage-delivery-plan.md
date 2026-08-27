---
title: "Wave 3: Convergence, Scenario Vintage Truth, and Delivery Readiness"
date: "2026-08-26"
status: "draft"
request: "Turn research/2026-08-26-wave3-convergence-vintage-and-delivery-readiness-brainstorm.md into a multi-phase implementation plan, merging the two predecessor brainstorms (2026-08-11 GTB gap closers, 2026-08-19 PCAF/seams) into one sequenced program with a single refreeze boundary"
plan_type: "multi-phase"
research_inputs:
  - "research/2026-08-26-wave3-convergence-vintage-and-delivery-readiness-brainstorm.md"
  - "research/2026-08-19-pcaf-layer-scale-and-platform-seams-brainstorm.md"
  - "research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md"
---

# Plan: Wave 3 — Convergence, Scenario Vintage Truth, and Delivery Readiness

## Objective

Convert three accumulated analysis documents into one ordered, landable program
that closes the repository's remaining client-facing gaps: a live data-governance
defect that would commit a real bank's counterparty names to git, an orchestrator
that requires a source edit to add a pipeline step, scenario benchmarks frozen at
2023 vintages, an unknown supported loanbook size, a missing financed-emissions
layer, four unbuilt client commitments, and deliverables that exist only as
English-language HTML. It matters now because the client program these
commitments belong to starts in Q4 2026 and no pipeline code has changed since
2026-08-08.

## Context Snapshot

- **Current state:** Waves 0, 1 and 2 are complete. Two engagements (`mcb-demo`,
  `sdb-rehearsal`) run end to end through one orchestrator
  (`scripts/run_engagement.R`). Two acceptance gates run in CI on every push:
  byte-identity (`Rscript tools/verify_refactor.R`) and six cross-artifact
  invariants (`Rscript tools/verify_refactor.R --invariants`). Measured at commit
  `6170ae2` on 2026-08-26: the R suite is `FAIL 0 | WARN 5 | SKIP 1 | PASS 408`
  and the Python suite is `58 passed`. There are 10,295 lines of R across `R/` and
  `scripts/`, and 2,811 lines of Python under `dashboard/`.
- **Desired state:** A platform whose `.gitignore` cannot stage a real client's
  named exposures; whose pipeline steps are declared in config rather than an `if`
  ladder; whose scenario benchmarks carry a current vintage and can be compared
  against the prior one; that has a measured and published supported loanbook
  size; that computes PCAF financed emissions and carbon-cost exposure with an
  explicit data-quality score; that delivers the four outstanding client
  commitments; and that emits bilingual-labelled PDF alongside HTML.
- **Key repo surfaces:**
  `.gitignore`; `tools/verify_refactor.R`; `R/engagement_config.R`;
  `R/step_runner.R`; `scripts/run_engagement.R`; `scripts/refresh_dashboard_data.R`;
  `dashboard/lib/loaders.py`; `data/scenarios/pdp8-2023/`;
  `scripts/generate_vietnam_data.R`; `scripts/engagement_scoring.R`;
  `R/severity_scoring.R`; `R/report_toolkit.R`; `templates/engagement/`;
  `templates/disclosure/`; `tests/testthat/`; `dashboard/tests/`;
  `.github/workflows/ci.yml`; `.github/workflows/refresh.yml`.
- **Out of scope:** The ABCD sourcing decision (`docs/abcd_sourcing_decision.md`)
  remains open and is not addressed here. Automotive TRISK coverage. Multi-
  engagement viewing inside the Streamlit dashboard (blocked by design — the app
  reads only `dashboard/data`). Full narrative translation into Vietnamese (only
  labels and disclaimers are translated). Migrating off Streamlit. Refactoring
  `R/pacta_core.R` or `R/trisk_core.R` for their own sake.

## Environment & Conventions

- **Stack:** R 4.5 for the entire analytical pipeline (no Node, no npm); Python
  3.12 for the Streamlit dashboard. R dependencies are pinned in `renv.lock`
  (24 packages). The R code is also structured as a loadable package named
  `pactatrisk` (`DESCRIPTION`, `NAMESPACE`, `man/`), currently version `0.4.1`.
- **Setup:**
  - R dependencies: `Rscript -e "renv::restore()"`, or the no-renv fallback
    `Rscript scripts/ci/install_deps.R`.
  - Python dependencies: `python -m pip install -r dashboard/requirements.txt`.
  - On Windows, `Rscript` is at `C:\Program Files\R\R-4.5.2\bin\Rscript.exe`. Add
    it to `PATH` for the session before running anything that shells out to
    `Rscript` (the orchestrator uses `system2("Rscript", ...)` and needs it on
    `PATH` even when the outer call used a full path):
    `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"`. On Linux and macOS use plain
    `Rscript`.
- **Build / Run:**
  - Full pipeline refresh for the public demo: `Rscript scripts/pipeline_refresh.R`
    (a thin wrapper that delegates to `run_engagement.R` with
    `engagements/mcb-demo/engagement_config.json`).
  - Any engagement:
    `Rscript scripts/run_engagement.R --config engagements/<slug>/engagement_config.json`
    Add `--dry-run` to print the resolved step list without executing or writing.
  - Dashboard: `python -m streamlit run dashboard/app.py`.
- **Test:**
  - Full R suite: `Rscript -e "testthat::test_dir('tests/testthat')"` — expected
    at the start of this plan: `FAIL 0 | WARN 5 | SKIP 1 | PASS 408`.
  - Single R test file:
    `Rscript -e "testthat::test_file('tests/testthat/test_golden_numbers.R')"`.
  - The one skipped test regenerates the second engagement and is opt-in:
    `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`.
  - Full Python suite: `python -m pytest dashboard/tests` — expected `58 passed`.
  - Single Python test: `python -m pytest dashboard/tests/test_loaders.py -v`.
  - Byte-identity acceptance: `Rscript tools/verify_refactor.R` — prints
    `BYTE-IDENTITY PASS` and exits 0 only when no genuine drift is found. Add
    `--skip-refresh` to classify the current working tree without re-running the
    pipeline.
  - Cross-artifact invariants: `Rscript tools/verify_refactor.R --invariants` —
    prints `INVARIANTS PASS` and exits 0 only when INV-001 through INV-006 all
    hold.
- **Conventions & traps:**
  - **Always run R commands from the repository root.** Every script resolves
    paths via `getwd()`; the test helper `tests/testthat/helper-root.R` walks
    upward looking for a `dashboard/` directory.
  - **Money is whole Vietnamese Dong (VND) and is never rescaled.** Loan exposures
    (`loan_size_outstanding`, `exposure_vnd`) span raw magnitudes 1e5 to 5e12. Never
    divide or multiply except where existing code already does so for display.
    Formatting for display goes through `R/format_money.R`.
  - **Vietnamese counterparty names are matched after ASCII normalization.** Use
    `normalize_vn_name()` from `R/matching_helpers.R`, which wraps
    `stringi::stri_trans_general(x, "Latin-ASCII")`. CSVs are UTF-8 with no BOM.
  - **Byte-identity is the refactor acceptance bar.** Any change touching
    `scripts/` or `R/` must leave every `synthesis_output/vietnam/*.csv`,
    `synthesis_output/prioritization/*.csv`, `output/engagement/engagement_priority.csv`
    and the committed `engagements/sdb-rehearsal/` outputs byte-identical, verified
    with `tools/verify_refactor.R` and never with raw file digests (Git's
    `core.autocrlf` normalization makes raw digests differ across platforms for
    files that are identical after normalization). PNGs are compared visually only;
    HTML reports may differ only in generated-timestamp text.
  - **The engagement-config convention.** Scripts source `R/engagement_config.R`
    and call `cfg <- load_engagement_config(get_config_arg())`. Passing no
    `--config` flag yields the built-in Mekong Commercial Bank defaults. Never
    hardcode a new path outside this mechanism.
  - **No casual new pipeline dependencies.** The analysis stack is pinned in
    `renv.lock`; `yaml` was deliberately rejected in favour of JSON configs via
    `jsonlite`. Anything new must either be dev-only tooling or live outside the
    pipeline behind a `requireNamespace()` guard.
  - **`jsonlite` empty-value round-trip trap.** An optional config field written
    with `jsonlite::toJSON(..., auto_unbox = TRUE)` and read back with
    `jsonlite::read_json(..., simplifyVector = TRUE)` comes back as an empty
    `list()` whether it started as `NULL` or as `character(0)`. Always test
    "not configured" with `length(x) == 0`, never with `is.null(x)` or
    `is.character(x)`.
  - **Windows PowerShell 5.1 has no `&&` chaining.** Use separate commands or `;`
    sequencing. Prefer the portable `Rscript -e "..."` one-liners used throughout
    this repository, which behave identically on Windows and Linux.
  - `attic/` is retired reference code — never sourced by any pipeline, never
    tested, and must not be modified except to receive newly retired scripts.
  - `dashboard/data/` is the frozen public snapshot; only
    `scripts/refresh_dashboard_data.R` may write it, and only the `mcb-demo`
    engagement may publish there (`public_snapshot_allowed`).
  - Every generated artifact must carry a disclaimer stating the data is
    synthetic and illustrative. This is non-negotiable and applies to every new
    artifact created by this plan.
- **Repo map:**
  ```
  R/                    shared modules sourced by scripts/ (engagement_config,
                        step_runner, pacta_core, trisk_core, severity_scoring,
                        prioritization_core, report_toolkit, format_money,
                        matching_helpers, sector_registry)
  scripts/              pipeline stages, report generators, run_engagement.R
                        orchestrator, pipeline_refresh.R wrapper
  tools/                verify_refactor.R — byte-identity and invariants gates
  data/                 synthetic input CSVs; data/scenarios/<vintage>/ holds
                        the scenario pathway files
  synthesis_output/     PACTA, TRISK and prioritization outputs
  output/               engagement scoring, letters, disclosure, TRISK inputs
  engagements/<slug>/   per-engagement config and committed regression fixtures
  dashboard/            Streamlit app (app.py, pages/, lib/, tests/) and its
                        frozen snapshot dashboard/data/
  intake/               "Bring Your Own Loanbook" schema contract and templates
  templates/            engagement letter and disclosure narrative templates
  tests/testthat/       R test suite
  docs/                 methodology guides, deployment notes, assumption registers
  ```

## Research Inputs

- From `research/2026-08-26-wave3-convergence-vintage-and-delivery-readiness-brainstorm.md`:
  - `.gitignore` contains `!engagements/*/intake/normalized_loanbook.csv` and
    `!engagements/*/output/engagement/engagement_priority.csv`. Those negations are
    wildcards over every engagement, added to keep the `sdb-rehearsal` regression
    fixtures tracked. `normalized_loanbook.csv` holds counterparty legal names,
    whole-VND exposures, credit limits, sector codes and LEIs, so a real client
    engagement directory would have its named exposures staged by `git add -A` —
    directly contradicting `docs/intake_privacy.md` rule 1, "No raw client data is
    committed to git."
  - Every scenario row in the repository is stamped with a 2023 vintage
    (`pdp8_2023`, `nze_2023`, `steps_2023`), and `data/scenarios/` has exactly one
    child, `pdp8-2023/`. Vietnam amended its Power Development Plan 8 in April 2025.
    The vintage directory convention and its policing invariant (INV-002) were
    built in Wave 1 and have never had a second tenant.
  - `grep -rn "pdf\|docx\|officer\|pagedown\|chromote\|wkhtmltopdf" --include=*.R scripts/ R/`
    returns no matches. Every client deliverable — engagement letters, disclosure
    pack, coverage report, validation report — is HTML only. The three PDFs under
    `reports/` are dated 2026-04-16 and were produced by hand.
  - `grep -rn "set.seed\|runif\|rnorm\|sample(" scripts/*.R R/*.R` returns no
    matches. `scripts/generate_vietnam_data.R` is 751 lines of hand-written
    literals, so there is no generator to parameterize for scale testing; a new
    seeded generator is required, and it must stay off the byte-identity path.
    The largest loanbook anywhere in the repository is
    `data/fixtures/unseen_bank_loanbook.csv` at 40 rows.
  - Every run overwrites its predecessor. There is no result history, in a product
    whose regulatory purpose (TCFD, IFRS S2, Decision 263) is annual comparison
    against a baseline.
  - Only `intake/templates/README_vi.md` is bilingual. The dashboard, engagement
    letters, disclosure pack, coverage report and every generated HTML file are
    English-only, for two Vietnamese client banks.
  - `scripts/refresh_dashboard_data.R` copies eight reports into
    `dashboard/data/reports/`; `dashboard/lib/loaders.py::report_catalog()` has
    metadata for four and silently drops the rest via `if meta:`. Two of the eight
    are built on r2dii's bundled European demo portfolio and two are internal
    engineering phase reports. The newest is dated 2026-04-28.
- From `research/2026-08-19-pcaf-layer-scale-and-platform-seams-brainstorm.md`:
  - `output/engagement/engagement_priority.csv` has 23 borrowers and only 14
    distinct `composite_score` values; the top three tie at exactly
    `0.9113849765258216`. The ties are structural: `severity_trisk` saturates at 1
    for the worst coal names and at 0 for borrowers with positive `npv_change`,
    and `alignment_gap` is sector-level (not borrower-level) for every automotive,
    cement and steel borrower.
  - `scripts/engagement_scoring.R` computes
    `rank(composite_score, ties.method = "average") / n()` on raw doubles. Four
    renewables borrowers carry `alignment_gap = 13.548387096774196` and two carry
    `13.548387096774189` — a one-ULP difference from summation order — which splits
    six otherwise identical borrowers across thirteen percentile points.
  - `R/trisk_core.R` documents `stress_priority_score` as rank-relative and
    legitimate only as a dashboard sort key, yet `scripts/engagement_scoring.R`
    copies it verbatim into `engagement_priority.csv` as `trisk_priority_score`.
    In a two-borrower sector it takes the values 95 and 5 and means nothing else.
  - `scripts/run_engagement.R`'s `build_step_list()` is a hardcoded ladder of `if`
    blocks; `.merge_config_lists()` copies any key from the JSON and
    `.validate_engagement_config()` never rejects unknown keys, so a config with
    a typo such as `"trisk_sector"` validates clean and silently runs the default
    sectors. There is no `schema_version`, no `--only-step`, and step failures
    record a status without a reason.
  - `DESCRIPTION` Imports lists 19 packages, `scripts/ci/install_deps.R` installs
    25, `renv.lock` records 24, and `trisk.model` — the single most load-bearing
    dependency, used at `R/trisk_core.R` — is absent from `DESCRIPTION` entirely,
    as are `glue`, `magrittr`, `uuid` and `zoo`.
  - The PCAF data model is roughly one third built: cement and steel emission
    factors exist in `data/vietnam_abcd.csv`; power, automotive and coal emission
    factors are all `NA`; power holds capacity in MW rather than generation in MWh;
    there is no attribution denominator anywhere; and there is no data-quality
    score column or concept.
- From `research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md`:
  - Three artifacts still publish pre-Wave-2 min-max numbers that the code no
    longer produces: `docs/bidv_sector_prioritization_methodology.md` (sections
    2.1–2.3 formulas and section 9 results),
    `synthesis_output/prioritization/interpretation_notes.md`, and
    `scripts/generate_bidv_report.R` around the phrase "scoring maximum (1.0)".
    They say Power 1.000 / Steel 0.158 Low / Cement 0.011 Low; the code now
    produces power 0.863 Critical, steel 0.646 High, cement 0.556 High. The
    qualitative story inverted.
  - The borrower ranking answers "who is most exposed to transition risk", which
    is not the same question as "who can we write a sustainability-linked loan
    with". A separate readiness screen is needed, reading
    `engagement_priority.csv` as feedstock so it stays purely additive.
  - Nothing in the repository expresses a sector emission-reduction target as a
    governance object with a baseline year, target year, method and scenario
    vintage.
  - `templates/engagement/engagement_prompt_templates.csv` and
    `templates/disclosure/disclosure_sections.md` hardcode the literal
    "Mekong Commercial Bank" in all four sector rows, and
    `scripts/generate_bidv_report.R` (1,034 lines) is config-blind.
  - Borrower scoring weights are reachable only through the scoring script's own
    command line and cannot be set through `run_engagement.R`.

## Assumptions and Constraints

- **ASM-001:** No real BIDV or Techcombank loanbook is available during this work.
  Every artifact is demonstrated on the synthetic Mekong Commercial Bank book or
  on the `sdb-rehearsal` fixture.
- **ASM-002:** The 2025 Adjusted Power Development Plan 8 exists and supersedes the
  2023 plan for Vietnamese power-sector target setting. — **BINDING DEFAULT:**
  before creating `data/scenarios/pdp8-2025-adjusted/`, the executor must locate a
  primary-source citation for the adjusted plan (decision number and date) and
  record it in `data/scenarios/pdp8-2025-adjusted/SOURCE.md`. If no primary source
  can be obtained, create the directory anyway using synthetic, clearly-labelled
  pathway values derived by applying a documented uplift to the 2023 renewables
  targets, and state in `SOURCE.md` that the vintage is illustrative and must be
  replaced before any client use. The engineering work in PHASE-03 is identical
  either way.
- **ASM-003:** Which decimal precision to round `composite_score` to before
  ranking. — **BINDING DEFAULT:** 10 decimal places, applied with
  `round(composite_score, 10)`. This is at least four orders of magnitude above
  the observed floating-point residue (about 1e-14) and far below any
  methodologically meaningful difference. The published `composite_score` column
  is written at the same rounded precision so the file and the ranking agree.
- **ASM-004:** What replaces the misleading `trisk_priority_score` column name in
  `engagement_priority.csv`. — **BINDING DEFAULT:** rename it to
  `trisk_stress_rank_pct` and add a one-line description to
  `docs/scoring_anchors.md` stating that it is a within-engagement percentile
  rank, is not comparable across banks or refreshes, and must never be fed into a
  composite. Do not delete the column; downstream consumers exist.
- **ASM-005:** The attribution denominator for unlisted Vietnamese borrowers,
  where an Enterprise Value Including Cash figure does not exist. — **BINDING
  DEFAULT:** total debt plus total equity in whole VND, supplied by a new
  `borrower_capital_vnd` column on the TRISK financial-features input, assigned
  PCAF data-quality score 3. Where no value is available, derive it from a
  sector-median leverage assumption and assign data-quality score 5. Do not widen
  the client-facing intake schema in `intake/SCHEMA.md`.
- **ASM-006:** Whether financed emissions cover Scope 1+2 only or also Scope 3.
  — **BINDING DEFAULT:** compute Scope 1+2 only in this plan, but carry a `scope`
  column with the literal value `"1+2"` from the first row written, so adding
  Scope 3 later is a new set of rows rather than a schema migration. State the
  Scope 3 exclusion explicitly in the generated report, naming automotive and coal
  mining as the sectors where the exclusion matters most.
- **ASM-007:** The scale target the platform commits to supporting. — **BINDING
  DEFAULT:** benchmark at 1,000 / 10,000 / 50,000 loans crossed with 200 / 1,000 /
  5,000 distinct counterparties, publish the measured curve regardless of outcome,
  and state in `intake/SCHEMA.md` only the largest configuration that completed
  the full chain in under 30 minutes on the benchmarking machine. Do not state a
  number that was not measured.
- **ASM-008:** Whether the bilingual overlay is global or per-engagement.
  — **BINDING DEFAULT:** one global table at `templates/i18n/labels.csv`, with an
  optional per-engagement override file named by a new config key
  `paths.i18n_override_csv`. Translate section headings, table column labels and
  the synthetic-data disclaimer; leave analyst-written narrative in English and
  say so in each bilingual artifact.
- **ASM-009:** Whether the public MCB demo switches to the 2025 scenario vintage.
  — **BINDING DEFAULT:** yes, and the switch happens inside the single refreeze in
  PHASE-07, not in PHASE-03. `pdp8-2023` remains tracked and runnable so the
  two-vintage comparison keeps working.
- **ASM-010:** Whether run history is recorded during the weekly automated refresh.
  — **BINDING DEFAULT:** yes. A new config key `run_history` defaults to `FALSE`
  and is set `TRUE` only in `engagements/mcb-demo/engagement_config.json`. Paths
  under `history/` are classified as expected churn by `tools/verify_refactor.R`,
  and `history` is added to the `git add` list in `.github/workflows/refresh.yml`.
- **ASM-011:** Where a client-specific private dashboard instance is hosted.
  — **BINDING DEFAULT:** record the decision as a single operator-hosted,
  access-controlled deployment with per-engagement data separation, rather than
  one cloned private repository per client. This plan writes the decision record
  only; it does not build the deployment.
- **CON-001:** Byte-identity. Every change must leave `synthesis_output/**`,
  `output/engagement/engagement_priority.csv` and the committed
  `engagements/sdb-rehearsal/` outputs byte-identical, except inside PHASE-07,
  which is the single authorized refreeze for this program.
- **CON-002:** `tests/testthat/test_golden_numbers.R` pins
  `ep$name_abcd[1] == "Nghi Son Power LLC"`, `nrow(ep) == 23`,
  `ep$composite_score[1] == 0.9113849765258216` (tolerance 1e-4) for the top three
  rows, and asserts `all(ep$composite_score > 0 & ep$composite_score < 1)` as an
  anti-min-max guard. PHASE-07 moves these values and must re-pin them in the same
  commit.
- **CON-003:** No new pipeline dependency. PDF rendering lives in `tools/` behind
  a `requireNamespace()` guard and is never invoked from `scripts/run_engagement.R`.
  Internationalization is a CSV plus a lookup function. Financed-emissions
  arithmetic uses `dplyr` and base R only.
- **CON-004:** VND is never rescaled. A PCAF attribution factor is a ratio of two
  VND quantities and is therefore unit-safe, but the denominator must be captured
  in whole VND like every other money column.
- **CON-005:** Only `mcb-demo` may write `dashboard/data`
  (`public_snapshot_allowed`). Client-facing PCAF, SLL and target artifacts are
  file deliverables, not dashboard views.
- **CON-006:** The supported-sector literal `c("power", "cement", "steel")` is
  duplicated across several files and is cross-checked by INV-004. Nothing added
  by this plan may become an uncoordinated fifth copy.
- **DEC-001:** One merged program with exactly one golden refreeze, placed last
  (PHASE-07). Every earlier phase is additive and must leave the existing gates
  green.
- **DEC-002:** PCAF financed-emissions accounting is built into the platform as a
  thin, explicitly data-quality-scored layer. It reads the normalized loanbook and
  asset-based company data, writes its own outputs, and does not feed
  `composite_score`, the sector ranking, or any frozen artifact.
- **DEC-003:** Every financed-emissions figure carries a PCAF data-quality score
  of 1 to 5, and no total is published without its quality-weighted composition.
- **DEC-004:** The headline new analytic is carbon-cost exposure — financed
  emissions multiplied by the carbon-price pathways already in
  `data/vietnam_trisk_ngfs_carbon_price_*.csv`, expressed in whole VND.
- **DEC-005:** The step list becomes declarative before any new pipeline step is
  added, and today's boolean config keys (`run_grid`, `run_outputs`,
  `run_refresh_audit`, `run_data_generation`) keep working untouched by being
  translated into the registry internally.
- **DEC-006:** The published report set becomes config-declared with one
  title/date/summary sidecar consumed by both the R writer and the Python catalog.
  Reports built on r2dii's European demo data and internal engineering phase
  reports are removed from the public snapshot.
- **DEC-007:** The sustainability-linked-loan readiness screen is a new downstream
  script reading `engagement_priority.csv` as feedstock, so it trips neither the
  golden tests nor the byte-identity gate.
- **DEC-008:** Sector targets are expressed as a target registry CSV with sector,
  metric, unit, baseline year and value, target year and value, scope, method,
  scenario vintage and status. Multi-horizon schema, populated for 2030 only.
- **DEC-009:** `R/pacta_core.R`'s `pacta_sda()` stays frozen. Target convergence
  is computed in a new module reading the existing SDA portfolio output, so
  cement and steel alignment gaps — which feed the severity anchors and cascade
  into every frozen artifact — do not move.

## Specification

### S1 — Composite score rounding and ranking (PHASE-07)

Let `c_i` be the raw composite score for borrower `i` as computed today in
`scripts/engagement_scoring.R`.

```
c_i_rounded = round(c_i, 10)
composite_rank_pct_i = rank(c_i_rounded, ties.method = "average") / n
```

- `round(x, 10)` — R's `base::round`, rounding to 10 decimal places.
- `n` — the number of borrower rows in this engagement (23 for `mcb-demo`).
- `ties.method = "average"` — unchanged from today; borrowers whose rounded scores
  are equal now genuinely tie instead of being separated by one unit in the last
  place of a double.
- The column written to `engagement_priority.csv` as `composite_score` is
  `c_i_rounded`, so the published number and the published rank agree.

### S2 — PCAF financed emissions (PHASE-05)

For borrower `b` in reporting year `y`:

```
attribution_factor_b = outstanding_amount_vnd_b / borrower_capital_vnd_b
financed_emissions_tco2e_b = attribution_factor_b * borrower_emissions_tco2e_b
```

- `outstanding_amount_vnd_b` — the borrower's total outstanding exposure in whole
  VND, summed across that borrower's loans from the normalized loanbook.
- `borrower_capital_vnd_b` — total debt plus total equity in whole VND (ASM-005).
- `attribution_factor_b` — a dimensionless ratio, clamped to the interval
  `[0, 1]`. A ratio above 1 means the loan exceeds the borrower's total capital
  and indicates a data error; clamp it, and emit a warning row naming the borrower.
- `borrower_emissions_tco2e_b` — the borrower's own annual Scope 1+2 emissions in
  tonnes of CO2 equivalent, computed per sector:

**Power:**
```
generation_mwh = capacity_mw * capacity_factor * 8760
borrower_emissions_tco2e = generation_mwh * emission_factor_tco2_per_mwh
```
- `capacity_mw` — the `production` column of `data/vietnam_abcd.csv` for power rows,
  in megawatts.
- `capacity_factor` — a dimensionless technology-level utilization fraction between
  0 and 1, from the new `data/vietnam_capacity_factors.csv`.
- `8760` — hours in a non-leap year. Use 8760 for every year; do not adjust for
  leap years.
- `emission_factor_tco2_per_mwh` — technology-level factor from the new
  `data/vietnam_emission_factors.csv`.

**Cement and steel:**
```
borrower_emissions_tco2e = production_tonnes * emission_factor_tco2_per_tonne
```
- `production_tonnes` — the `production` column of `data/vietnam_abcd.csv`, in
  tonnes of product per year.
- `emission_factor_tco2_per_tonne` — the existing `emission_factor` column of
  `data/vietnam_abcd.csv` for cement and steel rows.

**Automotive and coal mining:** excluded from the Scope 1+2 inventory in this
plan (their emissions are overwhelmingly Scope 3). Emit one row per such borrower
with `financed_emissions_tco2e = NA_real_`, `data_quality_score = NA_integer_`
and `exclusion_reason = "scope_3_dominant_sector_out_of_scope"`.

### S3 — PCAF data-quality score (PHASE-05)

A single integer from 1 (best) to 5 (worst), assigned per borrower by the first
rule that matches, evaluated top to bottom:

1. Score **2** — reported physical activity data and a borrower-specific emission
   factor are both available.
2. Score **3** — physical activity data is available and a technology-level
   emission factor is used, and `borrower_capital_vnd` came from the financial
   features input rather than a sector median.
3. Score **4** — physical activity is derived (for example power generation
   estimated from capacity and a capacity factor) rather than reported.
4. Score **5** — any input is a sector-median or otherwise portfolio-level
   assumption, including a sector-median `borrower_capital_vnd`.

Score 1 (audited, verified emissions) is never assigned by this synthetic
pipeline. No total may be published without the quality-weighted composition
defined as, for each score `s`:

```
share_s = sum(financed_emissions_tco2e where data_quality_score == s)
          / sum(financed_emissions_tco2e over all scored rows)
```

### S4 — Carbon-cost exposure (PHASE-05)

For borrower `b` and year `y`:

```
carbon_cost_vnd_b_y = financed_emissions_tco2e_b
                      * carbon_price_usd_per_tco2_y
                      * fx_rate_usd_vnd
```

- `carbon_price_usd_per_tco2_y` — read from
  `data/vietnam_trisk_ngfs_carbon_price_<sector>.csv` for the borrower's sector
  and the year `y`.
- `fx_rate_usd_vnd` — the engagement config's `inputs.fx_rate_usd_vnd`. When that
  key is not configured (`length(x) == 0`), write `carbon_cost_vnd` as
  `NA_real_` and exit the script non-zero after writing all outputs, naming the
  missing key. This mirrors the existing intake behaviour exactly.
- The result is whole VND and must never be rescaled.

### S5 — Sustainability-linked-loan readiness score (PHASE-06)

Four dimensions, each a value in `[0, 1]`:

```
readiness = (w_m * materiality + w_e * exposure + w_d * data_avail + w_r * relationship)
            / (w_m + w_e + w_d + w_r)
```

- `w_m = 0.30`, `w_e = 0.25`, `w_d = 0.25`, `w_r = 0.20`.
- `materiality` — the mean of `severity_alignment` and `severity_trisk` from
  `engagement_priority.csv`. When `severity_trisk` is `NA`, use
  `severity_alignment` alone.
- `exposure` — `severity_from_anchors()` applied to the borrower's
  `exposure_vnd` using anchor breakpoints
  `c(1e10, 1e11, 5e11, 1e12, 5e12)` mapped to `c(0, 0.25, 0.5, 0.75, 1)`. Those
  breakpoints are 10 billion, 100 billion, 500 billion, 1 trillion and 5 trillion
  whole VND.
- `data_avail` — 1.0 when the borrower has an asset-level match in
  `data/vietnam_abcd.csv` after `normalize_vn_name()`, otherwise 0.0.
- `relationship` — read from an optional overlay CSV at the config path
  `inputs.relationship_overlay_csv`, joined on `name_abcd`. When the overlay is
  absent (`length(x) == 0`), drop the term entirely: set `w_r = 0` for every row,
  so the remaining weights renormalize to sum to 1, and set the output column
  `readiness_partial = TRUE`.
- Bands, assigned from `readiness`: `>= 0.75` Ready, `>= 0.55` Near-ready,
  `>= 0.35` Developing, otherwise Not ready.
- The script emits a ranked, banded qualified pool. It does not select the final
  three; an analyst does, and the output carries an empty `analyst_rationale`
  column for that selection to be recorded in.

### S6 — Sector target registry rows (PHASE-06)

One row per sector per target horizon, with these columns in this order:

```
sector, metric, unit, baseline_year, baseline_value, target_year, target_value,
scope, method, scenario_vintage, status, source_artifact
```

- `metric` — for power, `technology_market_share`; for cement and steel,
  `emission_intensity`.
- `unit` — for power, `share_of_sector_capacity` (a fraction between 0 and 1); for
  cement, `tco2_per_tonne_cement`; for steel, `tco2_per_tonne_crude_steel`.
- `baseline_year` — 2025. `target_year` — 2030 for the populated rows; also emit
  unpopulated rows for 2035 and 2050 with `target_value = NA_real_` and
  `status = "not_set"`.
- `scope` — the literal `"1+2"` for intensity metrics, `"n/a"` for market-share
  metrics.
- `method` — `"market_share"` or `"sda_convergence"`.
- `scenario_vintage` — the engagement's configured `inputs.scenario_vintage`.
- `status` — one of `"proposed"`, `"adopted"`, `"not_set"`. Everything this plan
  generates is `"proposed"` or `"not_set"`; nothing is `"adopted"`.
- `source_artifact` — the relative path of the file the baseline was read from.

## Phase Summary

| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Close the data-governance defect and the verification gaps; land same-day | None | Narrowed `.gitignore`, INV-007, Python lockfile, refreshed stale docs, hosting decision record |
| PHASE-02 | Make the orchestrator declarative and the published report set config-declared | PHASE-01 | `R/step_registry.R`, strict config validation, `schema_version`, `--only-step`, INV-008, `reports/report_catalog.json` |
| PHASE-03 | Give the scenario-vintage mechanism a second tenant and stamp vintage on every output | PHASE-02 | `data/scenarios/pdp8-2025-adjusted/`, `inputs.scenario_vintage`, INV-009, vintage comparison report |
| PHASE-04 | Establish the supported scale empirically and add an append-only result history | PHASE-02 | `tools/generate_scale_fixture.R`, `tools/benchmark_scale.R`, `docs/scale_benchmark.md`, `R/run_history.R`, `history/` |
| PHASE-05 | Build the PCAF financed-emissions layer and carbon-cost exposure | PHASE-03, PHASE-04 | `R/financed_emissions.R`, `scripts/generate_financed_emissions.R`, three new CSVs, HTML report |
| PHASE-06 | Deliver the four outstanding client commitments | PHASE-05 | `scripts/sll_readiness.R`, `R/target_setting.R`, parameterized report generator, `workshop/` |
| PHASE-07 | Bilingual PDF delivery and the single golden refreeze to 0.5.0 | PHASE-06 | `tools/render_pdf.R`, `templates/i18n/labels.csv`, refrozen goldens, version 0.5.0 |

## Detailed Phases

### PHASE-01 - Governance, Hygiene and Verification Gaps

**Goal**
Remove the `.gitignore` rule that would stage a real client's named exposures,
add a mechanical guard against it recurring, pin the Python dependency stack,
make skipped tests visible locally, and bring five-month-stale status documents
into agreement with reality. Every task in this phase is additive, trips no
existing gate, and should land as one commit.

**Tasks**
- [x] TASK-01-01: In `.gitignore`, replace the two wildcard negations that
  whitelist client data with fixture-specific paths. Change
  `!engagements/*/intake/normalized_loanbook.csv` to
  `!engagements/sdb-rehearsal/intake/normalized_loanbook.csv`,
  `!engagements/*/intake/validation_warnings.csv` to
  `!engagements/sdb-rehearsal/intake/validation_warnings.csv`,
  `!engagements/*/intake/coverage_metrics.json` to
  `!engagements/sdb-rehearsal/intake/coverage_metrics.json`,
  `!engagements/*/output/engagement/engagement_priority.csv` to
  `!engagements/sdb-rehearsal/output/engagement/engagement_priority.csv`, and
  `!engagements/*/output/trisk/*/npv_results_latest.csv` and
  `!engagements/*/output/trisk/*/company_summary.csv` to their
  `engagements/sdb-rehearsal/...` equivalents. Leave every other line in the file
  unchanged.
- [x] TASK-01-02: Add `inv_engagement_fixture_allowlist()` to
  `tools/verify_refactor.R` as INV-007 and register it in `run_invariants()`.
- [x] TASK-01-03: Generate a Python lockfile. Run
  `python -m pip install -r dashboard/requirements.txt` in a clean virtual
  environment, then `python -m pip freeze > dashboard/requirements.lock`. Update
  both `.github/workflows/ci.yml`'s `python-tests` job to install from the lockfile
  (`python -m pip install -r dashboard/requirements.lock`) and
  `dashboard/README.md` to explain that `requirements.txt` declares intent and
  `requirements.lock` pins the exact resolved versions used by CI and by the
  public deployment.
- [x] TASK-01-04: Remove the hand-typed test counts from `NEWS.md`. In the
  `# pactatrisk 0.4.1` section, replace the string
  `full R suite FAIL 0 / PASS 404` with `full R suite green (FAIL 0)`. Add a line
  to `CLAUDE.md`'s Laws section stating that changelog entries must not quote test
  counts, because nothing verifies them.
- [x] TASK-01-05: Create `tools/run_tests.R`, a wrapper that runs the full R suite
  and then prints an explicit reminder naming every environment-gated test file
  and the variable that enables it. Update `CLAUDE.md`'s Commands section to list
  `Rscript tools/run_tests.R` alongside the existing `testthat::test_dir` one-liner.
- [x] TASK-01-06: Rewrite `plans/PROGRESS.md`. Replace its entire body with a
  short status page whose "As of" date is the date this phase lands, stating that
  Waves 0, 1 and 2 are complete at version 0.4.1, that the current program is this
  plan, and pointing to `NEWS.md` as the authoritative changelog. Delete the
  "Suggested Next Steps (Weeks 1–3 to First Results)" and "Key Design Decisions to
  Confirm" sections entirely; the six decisions they list are either settled or
  restated as ASM entries in this plan.
- [x] TASK-01-07: Truncate `activeContext.md` to a pointer. Replace its contents
  with a short note stating that per-session working context now lives in the
  active plan under `plans/`, and naming this plan file. Do not delete the file;
  the repository's global workflow conventions expect it to exist.
- [x] TASK-01-08: Add a second section to `docs/hosting-decision.md` titled
  "Multi-client private instances (2026-08)". Record the decision from ASM-011:
  one operator-hosted, access-controlled deployment with per-engagement data
  separation, rather than one cloned private repository per client. State the two
  facts that force the decision — Streamlit Community Cloud's free tier supports
  one private application, and `DEMO_PASSWORD` in `dashboard/lib/auth.py` is a
  single shared static string with no per-user identity, no rotation, no lockout
  and no access log. State explicitly that the existing password gate remains
  correct for the public synthetic demo and is not being changed by this plan.
- [x] TASK-01-09: Harden the password comparison in `dashboard/lib/auth.py` to use
  `hmac.compare_digest(pw, expected)` instead of `pw == expected`. Change nothing
  else in that file; the fail-open behaviour when no password is configured is
  deliberate and must be preserved.

**File Changes**
- `.gitignore` (modify): narrow the six `!engagements/*/...` negations to
  `!engagements/sdb-rehearsal/...`. Leave the non-negated `engagements/*/...`
  ignore rules exactly as they are — they must stay wildcards so that new
  engagement directories are ignored by default.
- `tools/verify_refactor.R` (modify): add `inv_engagement_fixture_allowlist()`
  immediately after `inv_loanbook_currency_scale()`, following the same
  `list(id = ..., ok = ..., detail = ...)` return shape used by every existing
  invariant. Add a call to it in `run_invariants()`'s `results <- list(...)`.
  Update the header comment block that currently says `INV-001..005` to say
  `INV-001..007`.
- `dashboard/requirements.lock` (create): the full `pip freeze` output.
- `.github/workflows/ci.yml` (modify): in the `python-tests` job only, change the
  install step to `python -m pip install -r dashboard/requirements.lock`. Leave
  every R job untouched.
- `dashboard/README.md` (modify): add a short paragraph explaining the two
  requirements files.
- `NEWS.md` (modify): the one string in the 0.4.1 section.
- `CLAUDE.md` (modify): add the no-test-counts rule to Laws; add
  `Rscript tools/run_tests.R` to Commands.
- `tools/run_tests.R` (create): the test wrapper.
- `plans/PROGRESS.md` (modify): full rewrite as described.
- `activeContext.md` (modify): truncate to a pointer.
- `docs/hosting-decision.md` (modify): append the new section.
- `dashboard/lib/auth.py` (modify): `import hmac` and use `hmac.compare_digest`.
- `tests/testthat/test_verify_invariants.R` (modify): add tests for INV-007.
- `dashboard/tests/test_auth.py` (modify): no behavioural change is expected;
  confirm the existing four scenarios still pass after the `compare_digest` change.

**Function Signatures**
- `inv_engagement_fixture_allowlist(root: character, allowlist: character = c("sdb-rehearsal")) -> list` —
  returns `list(id = "INV-007", ok = logical(1), detail = character())`. Runs
  `git ls-files engagements` from `root`, extracts the slug segment of every
  returned path (the second path component), and fails with one detail line per
  offending path when any slug is not in `allowlist` and the path is not
  `engagements/<slug>/engagement_config.json`. The config file itself is always
  permitted for every slug; nothing else is.
- `run_tests()` — no arguments; `tools/run_tests.R` is a script, not a library.
  It calls `testthat::test_dir("tests/testthat")` and then writes to standard
  output a block listing each environment-gated test file and its enabling
  variable, currently the single entry
  `tests/testthat/test_sdb_engagement.R — set RUN_SDB_ENGAGEMENT=1 to run`.
  It exits non-zero if `test_dir` reports any failure.

**Test Specs**
- `inv_engagement_fixture_allowlist(root)` on the repository as it stands after
  TASK-01-01 → `list(id = "INV-007", ok = TRUE, detail = character(0))`. The
  thirteen tracked paths under `engagements/` are twelve `sdb-rehearsal` files
  plus `engagements/mcb-demo/engagement_config.json`, which is exempt as a config
  file.
- A test that creates a temporary root containing
  `engagements/bidv/intake/normalized_loanbook.csv` as a tracked file →
  `ok == FALSE` and `detail` contains exactly one string naming that path and the
  slug `bidv`.
- A test that creates a temporary root containing only
  `engagements/bidv/engagement_config.json` as a tracked file → `ok == TRUE`,
  because config files are exempt for every slug.
- `git check-ignore -v engagements/bidv/intake/normalized_loanbook.csv` after
  TASK-01-01, run with a placeholder file at that path → exits 0 and reports the
  `engagements/*/intake/*` rule as the match, proving the file is ignored.
- `git check-ignore -v engagements/sdb-rehearsal/intake/normalized_loanbook.csv`
  → exits 1 (not ignored), proving the fixture is still tracked.
- `python -m pytest dashboard/tests/test_auth.py -v` → 4 passed, unchanged from
  before the `compare_digest` change.

**Dependencies**
- None. This phase depends on nothing and blocks nothing except by convention.

**Exit Criteria**
- [x] `Rscript tools/verify_refactor.R --invariants` prints `[PASS] INV-007`
  along with INV-001 through INV-006 and exits 0.
- [x] `git check-ignore -q engagements/bidv/intake/normalized_loanbook.csv` exits
  0 when a placeholder file is created at that path, and
  `git check-ignore -q engagements/sdb-rehearsal/intake/normalized_loanbook.csv`
  exits 1.
- [x] `git status --porcelain` reports no change to any file under
  `synthesis_output/`, `output/engagement/`, `dashboard/data/` or
  `engagements/sdb-rehearsal/`.
- [x] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0` with a
  pass count at least as high as before this phase.
- [x] `python -m pytest dashboard/tests` reports `58 passed`.
- [x] `dashboard/requirements.lock` exists and pins an exact version for every
  package named in `dashboard/requirements.txt`.

**Phase Risks**
- **RISK-01-01:** Narrowing the `.gitignore` negations could accidentally untrack
  an existing `sdb-rehearsal` fixture if a path is mistyped. Mitigation: after the
  edit, run `git status --porcelain engagements/` and confirm it is empty. If any
  fixture shows as deleted, the negation path is wrong.
- **RISK-01-02:** `pip freeze` in a dirty environment will capture unrelated
  packages. Mitigation: create the lockfile from a fresh virtual environment
  containing only `dashboard/requirements.txt`, and confirm the lockfile has fewer
  than 60 entries.

### PHASE-02 - Declarative Orchestrator and Publication Truth

**Goal**
Replace the hardcoded step ladder with a named step registry so that the four
later phases add configuration entries rather than source branches; reject unknown
config keys instead of silently ignoring them; give the manifest a failure reason;
add a dependency-manifest invariant; and make the published report set
config-declared so the public demo stops shipping European demo data and internal
engineering build reports.

**Tasks**
- [x] TASK-02-01: Create `R/step_registry.R` defining every pipeline step by name,
  with its script path and an argument-builder function. Include all thirteen
  step names currently produced by `build_step_list()`:
  `generate_vietnam_data`, `intake`, `validation_report`, `coverage_report`,
  `pacta_vietnam_scenario`, `trisk_prepare_inputs`, `trisk_sector_demo_<sector>`
  (one per configured sector, power first), `trisk_scenario_grid`,
  `sector_prioritization`, `refresh_dashboard_data`, `engagement_scoring`,
  `generate_engagement_letters`, `generate_disclosure_pack`, `refresh_audit`.
- [x] TASK-02-02: Rewrite `build_step_list()` in `scripts/run_engagement.R` to
  call `resolve_step_list()` from the registry. The resulting step list must be
  **identical in order, name, script and arguments** to what the current function
  produces for both `engagements/mcb-demo/engagement_config.json` and
  `engagements/sdb-rehearsal/engagement_config.json`. Verify with `--dry-run`
  output captured before and after.
- [x] TASK-02-03: Add `schema_version` to the engagement config. Default it to the
  integer `1` in `.default_engagement_config()`, validate that it is a single
  integer equal to `1`, and add `"schema_version": 1` to both existing
  `engagement_config.json` files.
- [x] TASK-02-04: Add strict unknown-key rejection to
  `.validate_engagement_config()`. Walk the merged config recursively; any key not
  present in `.default_engagement_config()` is collected into `problems` with a
  message naming the offending key path and listing the accepted sibling keys. Add
  `steps` (PHASE-02), `run_history` (PHASE-04) and every other new key introduced
  by later phases to the defaults at the time each phase lands, so this validation
  never has to be relaxed.
- [x] TASK-02-05: Add `--only-step <name>` and `--resume-from <name>` flags to
  `scripts/run_engagement.R`. Both filter the resolved step list before execution.
  `--only-step` may be repeated to select several steps. An unknown step name is a
  hard error naming the valid names. Both flags are compatible with `--dry-run`.
- [x] TASK-02-06: Capture step failure output. Change `run_step()` in
  `R/step_runner.R` to run the subprocess with `stderr = TRUE` capture, and to
  return a fourth element `error_excerpt` holding the last 20 lines of combined
  output when `status != "ok"`, and `NULL` when the step succeeded. Ensure
  `write_pipeline_manifest()` carries the field through unchanged.
- [x] TASK-02-07: Add `inv_dependency_manifests_agree()` to
  `tools/verify_refactor.R` as INV-008 and register it. Add the five packages
  currently missing from `DESCRIPTION` — `trisk.model`, `glue`, `magrittr`, `uuid`,
  `zoo` — to its `Imports` field so the new invariant passes.
- [x] TASK-02-08: Create `reports/report_catalog.json`, a single sidecar listing
  every report that may be published, each with `file`, `title`, `date`,
  `summary`, and `category`. `category` is one of `client_facing`,
  `methodology_reference`, or `internal_build`. Only `client_facing` and
  `methodology_reference` entries are eligible for the public snapshot.
- [x] TASK-02-09: Add a `published_reports` key to the engagement config schema,
  defaulting to `character(0)`. Populate it in
  `engagements/mcb-demo/engagement_config.json` with the file names of the reports
  that should reach the public snapshot. Per DEC-006 and the research findings,
  **remove** `PACTA_Alignment_Report.html` and `PACTA_Comparison_Report.html`
  (built on r2dii's bundled European demo portfolio),
  `2026-04-28-trisk-multisector-phases-1-2.html` and
  `2026-04-16-pacta-baseline-stabilization.html` (internal engineering phase
  reports). **Keep** `PACTA_Vietnam_Bank_Report.html`, `PACTA_Synthesis_Report.html`,
  `2026-04-16-final-vietnam-bank-trisk-demo.html` and
  `2026-04-16-trisk-power-pilot.html`. **Add**
  `BIDV_Framework_Recommendation_Report.html` and, once PHASE-05 produces it, the
  financed-emissions report.
- [x] TASK-02-10: Rewrite `scripts/refresh_dashboard_data.R`'s hardcoded
  `report_files` vector to read `cfg$published_reports`, cross-checked against
  `reports/report_catalog.json`. A file named in `published_reports` that is
  absent from the catalog, or present with `category == "internal_build"`, is a
  hard error naming the file.
- [x] TASK-02-11: Rewrite `dashboard/lib/loaders.py::report_catalog()` to read
  `dashboard/data/reports/report_catalog.json` (copied into the snapshot by
  `refresh_dashboard_data.R`) instead of the hardcoded `summaries` dictionary. A
  published HTML file with no catalog entry must render with its filename as the
  title and an explicit `"No summary available."` string — never be silently
  dropped.
- [x] TASK-02-12: Delete the four removed reports from `dashboard/data/reports/`
  in the same commit as TASK-02-10, so that a subsequent pipeline run reproduces
  the tree exactly.
- [x] TASK-02-13: Retire the demo-data report generator. Move
  `scripts/generate_report.R` to `attic/generate_report.R` and the fourteen r2dii
  demo CSVs under `output/` (everything matching `output/0*.csv` and
  `output/1*.csv` that is r2dii demo output, not `output/engagement/`,
  `output/disclosure/`, `output/engagement_letters/` or `output/trisk_inputs/`) to
  `attic/demo_output/`. Add a paragraph to `attic/README.md` recording what was
  retired, when, and why.

**File Changes**
- `R/step_registry.R` (create): the registry and its resolver.
- `scripts/run_engagement.R` (modify): replace the body of `build_step_list()`
  with a call to `resolve_step_list()`; add `--only-step` and `--resume-from`
  parsing near the existing `--dry-run` and `--config` parsing. Leave the
  `public_snapshot_allowed` guard, the effective-config write and the banner
  untouched.
- `R/engagement_config.R` (modify): add `schema_version = 1L`,
  `published_reports = character(0)` and `steps = character(0)` to
  `.default_engagement_config()`; add the `schema_version` check and the recursive
  unknown-key walk to `.validate_engagement_config()`. Preserve every existing
  `length(x) == 0` empty-shape guard exactly as written — they encode a
  `jsonlite` round-trip trap.
- `R/step_runner.R` (modify): `run_step()` gains stderr capture and an
  `error_excerpt` element. `run_steps()` and `write_pipeline_manifest()` are
  otherwise unchanged.
- `tools/verify_refactor.R` (modify): add `inv_dependency_manifests_agree()`;
  register it in `run_invariants()`; update the header comment to `INV-001..008`.
- `DESCRIPTION` (modify): add `trisk.model`, `glue`, `magrittr`, `uuid`, `zoo` to
  `Imports`, keeping the list alphabetically sorted.
- `reports/report_catalog.json` (create): the report metadata sidecar.
- `scripts/refresh_dashboard_data.R` (modify): replace the hardcoded
  `report_files` vector; add the catalog copy into the snapshot.
- `dashboard/lib/loaders.py` (modify): `report_catalog()` reads the sidecar; delete
  the `summaries` dictionary and the `if meta:` filter.
- `engagements/mcb-demo/engagement_config.json` (modify): add `schema_version` and
  `published_reports`.
- `engagements/sdb-rehearsal/engagement_config.json` (modify): add
  `schema_version`.
- `dashboard/data/reports/` (modify): delete the four retired HTML files.
- `attic/generate_report.R` (create, by move from `scripts/`).
- `attic/demo_output/` (create, by move from `output/`).
- `attic/README.md` (modify): append the retirement record.
- `tests/testthat/test_step_runner.R` (modify): add `error_excerpt` assertions.
- `tests/testthat/test_engagement_config.R` (modify): add unknown-key and
  `schema_version` assertions.
- `tests/testthat/test_verify_invariants.R` (modify): add INV-008 tests.
- `tests/testthat/test_snapshot_contract.R` (modify): update the expected
  published-report set.
- `dashboard/tests/test_loaders.py` (modify): update `report_catalog()` tests.

**Function Signatures**
- `step_registry() -> list` — returns a named list where each element is
  `list(name = character(1), script = character(1), args_fn = function(cfg, ctx) character())`.
  `ctx` is a named list carrying the runtime values that are not in the config:
  `effective_config_path`, `run_intake`, `raw_loanbook`, `intake_dir`, `top_n`,
  and `sector` for per-sector steps.
- `resolve_step_list(cfg: list, ctx: list) -> list` — returns an ordered list of
  `list(name, script, args)` entries, identical in shape to what
  `build_step_list()` returns today. Steps are selected by translating the boolean
  config keys `run_data_generation`, `run_grid`, `run_outputs`,
  `run_refresh_audit` and the runtime `ctx$run_intake` into registry entries, then
  expanding `trisk_sector_demo` once per element of `cfg$trisk_sectors` with
  `"power"` moved to the front when present. When `cfg$steps` is non-empty it
  overrides the boolean translation entirely and names the steps to run, in order.
- `filter_step_list(steps: list, only: character = character(0), resume_from: character = NA_character_) -> list` —
  returns the filtered step list. With `only` non-empty, keeps only steps whose
  `name` is in `only`, preserving registry order. With `resume_from` set, drops
  every step before the first whose `name` matches. Stops with an error naming the
  valid step names when any requested name is not present in `steps`.
- `run_step(step: list) -> list` — now returns
  `list(name = character(1), status = character(1), seconds = numeric(1), error_excerpt = character()|NULL)`.
  `error_excerpt` holds the last 20 lines of combined standard output and standard
  error when `status == "failed"`, and `NULL` otherwise.
- `inv_dependency_manifests_agree(root: character) -> list` — returns
  `list(id = "INV-008", ok, detail)`. Parses the `Imports:` field of `DESCRIPTION`,
  the package names installed by `scripts/ci/install_deps.R`, and the `Packages`
  keys of `renv.lock`, and fails with one detail line per package that appears in
  `renv.lock` or `install_deps.R` but not in `DESCRIPTION` `Imports`. Packages in
  `DESCRIPTION` `Suggests` are exempt.
- `report_catalog() -> list[dict[str, str | Path]]` (Python, in
  `dashboard/lib/loaders.py`) — returns one dictionary per HTML file present in
  `dashboard/data/reports/`, each with keys `path`, `title`, `date`, `summary`,
  `category`. Files with no catalog entry get `title` set to the filename stem,
  `summary` set to `"No summary available."`, `date` set to `""` and `category`
  set to `"uncatalogued"`. No file is ever dropped.

**Test Specs**
- `resolve_step_list(load_engagement_config("engagements/mcb-demo/engagement_config.json"), ctx)`
  with `ctx$run_intake = FALSE` → a list of exactly 11 steps whose `name` values,
  in order, are `generate_vietnam_data`, `pacta_vietnam_scenario`,
  `trisk_prepare_inputs`, `trisk_sector_demo_power`, `trisk_sector_demo_cement`,
  `trisk_sector_demo_steel`, `trisk_scenario_grid`, `sector_prioritization`,
  `refresh_dashboard_data`, `engagement_scoring`, `refresh_audit`. Note that
  `run_data_generation` is `FALSE` in the committed MCB config, so
  `generate_vietnam_data` appears only when the config or the `--full` path sets
  it — assert against the actual resolved config rather than this illustrative
  ordering, and assert equality against the pre-refactor `--dry-run` output
  captured in TASK-02-02.
- `filter_step_list(steps, only = c("engagement_scoring"))` → a one-element list
  whose `name` is `"engagement_scoring"`.
- `filter_step_list(steps, resume_from = "sector_prioritization")` → a list whose
  first element's `name` is `"sector_prioritization"` and which contains every
  subsequent step.
- `filter_step_list(steps, only = c("no_such_step"))` → error whose message
  contains both `"no_such_step"` and at least one valid step name.
- `load_engagement_config()` on a temporary JSON file containing
  `{"trisk_sector": ["power"]}` → error whose message contains
  `"trisk_sector"` and `"trisk_sectors"`. This is the exact typo the research
  identified as currently validating clean.
- `load_engagement_config()` on a temporary JSON file containing
  `{"schema_version": 2}` → error whose message contains `"schema_version"` and
  `"1"`.
- `load_engagement_config("engagements/mcb-demo/engagement_config.json")` →
  succeeds, with `cfg$schema_version == 1L`.
- `run_step(list(name = "boom", script = "tools/nonexistent.R", args = character()))`
  → `status == "failed"` and `error_excerpt` is a character vector of length at
  least 1.
- `run_step()` on a script that exits 0 → `error_excerpt` is `NULL`.
- `inv_dependency_manifests_agree(getwd())` after TASK-02-07 → `ok == TRUE`.
- A test that removes `trisk.model` from a temporary copy of `DESCRIPTION` →
  `ok == FALSE` and `detail` contains a string naming `trisk.model`.
- `report_catalog()` (Python) with `dashboard/data/reports/` containing six HTML
  files and a catalog naming five of them → a list of length 6, where the
  uncatalogued entry has `summary == "No summary available."`.
- `python -m pytest dashboard/tests/test_loaders.py -v` → all tests pass with the
  new report set.

**Dependencies**
- PHASE-01 (so the invariant registration lands on a clean base).

**Exit Criteria**
- [x] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --dry-run`
  produces byte-identical output to the same command run before this phase (capture
  both to files and `diff` them).
- [x] `Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json --dry-run`
  likewise produces byte-identical output to the pre-refactor run.
- [x] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS` and exits 0.
- [x] `Rscript tools/verify_refactor.R --invariants` prints `[PASS]` for INV-001
  through INV-008 and exits 0.
- [x] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [x] `python -m pytest dashboard/tests` passes with an increased test count.
- [x] `ls dashboard/data/reports/*.html | wc -l` returns the number of entries in
  `mcb-demo`'s `published_reports`, and no returned filename is
  `PACTA_Alignment_Report.html`, `PACTA_Comparison_Report.html`,
  `2026-04-28-trisk-multisector-phases-1-2.html` or
  `2026-04-16-pacta-baseline-stabilization.html`.
- [x] `grep -rn "generate_report.R" scripts/ R/ tools/ .github/` returns no matches.

**Phase Risks**
- **RISK-02-01:** The step-registry rewrite is the highest-risk refactor in this
  plan because it sits directly on the byte-identity path. Mitigation: capture
  `--dry-run` output for both engagements before touching anything, and treat a
  non-empty `diff` as a blocking failure. Do not proceed to any other task in this
  phase until both diffs are empty.
- **RISK-02-02:** Strict unknown-key rejection will break any config with a
  legitimately-unrecognized key. Mitigation: run
  `Rscript -e "source('R/engagement_config.R'); load_engagement_config('engagements/sdb-rehearsal/engagement_config.json')"`
  and the same for `mcb-demo` immediately after implementing the check; both must
  succeed before continuing.
- **RISK-02-03:** Deleting reports from `dashboard/data/reports/` will show as
  drift to `tools/verify_refactor.R` if the deletion and the code change land in
  different commits. Mitigation: land TASK-02-10 and TASK-02-12 together.

### PHASE-03 - Scenario Vintage: A Second Tenant

**Goal**
Give the scenario-vintage directory convention its first second tenant, make the
vintage an explicit, validated, run-stamped attribute rather than an implicit
directory name, and produce a two-vintage comparison as a client-facing artifact
in its own right. The public demo does **not** switch default vintage in this
phase; that happens in the single refreeze in PHASE-07.

**Tasks**
- [x] TASK-03-01: Create `data/scenarios/pdp8-2025-adjusted/SOURCE.md` recording
  the provenance of the new vintage per ASM-002 — either the primary-source
  decision number and date, or an explicit statement that the values are
  illustrative and must be replaced before client use.
- [x] TASK-03-02: Create
  `data/scenarios/pdp8-2025-adjusted/vietnam_scenario_ms.csv` and
  `data/scenarios/pdp8-2025-adjusted/vietnam_scenario_co2.csv` with the same
  column schema as their 2023 counterparts
  (`scenario_source, scenario, sector, technology, region, year, smsp, tmsr` for
  the market-share file). Set `scenario_source` to the literal
  `pdp8_2025_adjusted` on every PDP8 row. Leave the `nze_2023` and `steps_2023`
  rows' `scenario_source` values as they are — those are IEA vintages, not
  Vietnamese ones, and changing them is out of scope for this phase.
- [x] TASK-03-03: Add `inputs.scenario_vintage` to the engagement config schema,
  a single non-empty string defaulting to `"pdp8-2023"`. Validate that it matches
  `^[a-z0-9-]+$` and that it equals the immediate parent directory name of both
  `inputs.scenario_ms_csv` and `inputs.scenario_co2_csv`. A mismatch is a hard
  validation error naming all three values.
- [x] TASK-03-04: Add `inv_scenario_vintage_declared()` as INV-009 to
  `tools/verify_refactor.R` and register it: every engagement config's declared
  `inputs.scenario_vintage` must equal the parent directory of both its scenario
  paths, and the named vintage directory must exist. This makes the config-level
  check enforceable from the acceptance gate as well as at load time.
- [x] TASK-03-05: Stamp the vintage into `write_pipeline_manifest()`'s output. Add
  `scenario_vintage` to the `extra` list passed from `scripts/run_engagement.R`,
  so both `dashboard/data/pipeline_manifest.json` and each engagement's
  `pipeline_manifest.json` carry it.
- [x] TASK-03-06: Surface the vintage in the dashboard. Extend
  `dashboard/lib/branding.py::data_freshness_badge()` to append
  `scenario vintage: <value>` to its caption when the manifest carries the field,
  and to say nothing extra when it does not.
- [x] TASK-03-07: Create `scripts/compare_scenario_vintages.R`, which runs the
  PACTA alignment stage twice — once per named vintage — into two temporary output
  directories, joins the resulting `06_vn_ms_alignment_2030.csv` and
  `06_vn_sda_alignment_2030.csv` tables on their key columns, and writes a
  self-contained HTML comparison report.
- [x] TASK-03-08: Register `compare_scenario_vintages` as an optional step in
  `R/step_registry.R`, gated on a new boolean config key
  `run_vintage_comparison`, defaulting to `FALSE`. Do not enable it for either
  existing engagement in this phase.
- [x] TASK-03-09: Add a row to `reports/report_catalog.json` for
  `Scenario_Vintage_Comparison.html` with `category` set to `client_facing`.

**File Changes**
- `data/scenarios/pdp8-2025-adjusted/SOURCE.md` (create).
- `data/scenarios/pdp8-2025-adjusted/vietnam_scenario_ms.csv` (create).
- `data/scenarios/pdp8-2025-adjusted/vietnam_scenario_co2.csv` (create).
- `R/engagement_config.R` (modify): add `scenario_vintage = "pdp8-2023"` inside
  the `inputs` list of `.default_engagement_config()`; add the vintage validation
  block to `.validate_engagement_config()`. **Important:** the existing
  "every input must exist" loop calls `file.exists()` on every element of
  `cfg$inputs`. `scenario_vintage` is a name, not a path, so it must be skipped
  in that loop exactly the way `fx_rate_usd_vnd` already is — add it to the same
  skip branch, or the config will fail validation with a confusing
  "input file(s) not found: pdp8-2023".
- `engagements/mcb-demo/engagement_config.json` (modify): add
  `"scenario_vintage": "pdp8-2023"` inside `inputs`.
- `engagements/sdb-rehearsal/engagement_config.json` (modify): same.
- `tools/verify_refactor.R` (modify): add and register INV-009; update the header
  comment to `INV-001..009`.
- `scripts/run_engagement.R` (modify): pass `scenario_vintage` in the manifest
  `extra` list. Change nothing else.
- `dashboard/lib/branding.py` (modify): extend `data_freshness_badge()` only.
- `scripts/compare_scenario_vintages.R` (create).
- `R/step_registry.R` (modify): add the `compare_scenario_vintages` entry.
- `reports/report_catalog.json` (modify): add the new report row.
- `tests/testthat/test_engagement_config.R` (modify): vintage validation tests.
- `tests/testthat/test_verify_invariants.R` (modify): INV-009 tests.
- `dashboard/tests/test_manifest.py` (modify): assert the badge handles a manifest
  both with and without `scenario_vintage`.

**Function Signatures**
- `compare_vintages(cfg: list, vintage_a: character, vintage_b: character, out_html: character) -> character` —
  defined in `scripts/compare_scenario_vintages.R`. Runs the PACTA alignment stage
  once per vintage into `tempdir()` subdirectories, joins the two alignment tables
  on `c("sector", "technology", "year", "scenario")`, computes
  `gap_delta_pp = gap_pct_b - gap_pct_a` in percentage points, writes the HTML
  report, and returns the path written. The report must carry the standard
  synthetic-data disclaimer and must state both vintage names in its title.
- `inv_scenario_vintage_declared(root: character) -> list` — returns
  `list(id = "INV-009", ok, detail)`. For each
  `engagements/*/engagement_config.json`, fails with one detail line when
  `inputs.scenario_vintage` is absent, when it does not equal `basename(dirname())`
  of both scenario paths, or when `data/scenarios/<vintage>/` does not exist.

**Test Specs**
- `load_engagement_config("engagements/mcb-demo/engagement_config.json")` →
  succeeds with `cfg$inputs$scenario_vintage == "pdp8-2023"`.
- A temporary config with `"scenario_vintage": "pdp8-2025-adjusted"` but scenario
  paths still pointing at `data/scenarios/pdp8-2023/...` → error whose message
  contains `pdp8-2025-adjusted`, `pdp8-2023` and `scenario_vintage`.
- A temporary config with `"scenario_vintage": "PDP8 2023"` (spaces and capitals)
  → error naming the `^[a-z0-9-]+$` requirement.
- `inv_scenario_vintage_declared(getwd())` on the repository after this phase →
  `ok == TRUE`.
- `nrow(read.csv("data/scenarios/pdp8-2025-adjusted/vietnam_scenario_ms.csv"))` →
  equal to `nrow(read.csv("data/scenarios/pdp8-2023/vietnam_scenario_ms.csv"))`,
  and the two files must have identical column names in identical order.
- `unique(read.csv("data/scenarios/pdp8-2025-adjusted/vietnam_scenario_ms.csv")$scenario_source)`
  → contains `"pdp8_2025_adjusted"` and does not contain `"pdp8_2023"`.
- `data_freshness_badge()` with a manifest lacking `scenario_vintage` → renders
  the existing caption text with no trailing vintage clause and raises no
  exception.

**Dependencies**
- PHASE-02 (the step registry, so `compare_scenario_vintages` is a registry entry
  rather than a new `if` branch; and the unknown-key validation, so
  `scenario_vintage` and `run_vintage_comparison` are added to the defaults at the
  same time they are added to the configs).

**Exit Criteria**
- [x] `Rscript tools/verify_refactor.R --invariants` prints `[PASS]` for INV-001
  through INV-009 and exits 0. INV-002 (no scenario vintage exists at two paths)
  must still pass with two vintage directories present — this is its first real
  exercise.
- [x] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS`. No published
  number changes in this phase, because the default vintage is unchanged.
- [x] `Rscript scripts/compare_scenario_vintages.R --config engagements/mcb-demo/engagement_config.json --vintage-a pdp8-2023 --vintage-b pdp8-2025-adjusted --output reports/Scenario_Vintage_Comparison.html`
  exits 0 and writes a non-empty HTML file containing both vintage names and the
  synthetic-data disclaimer.
- [x] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [x] `python -m pytest dashboard/tests` passes.

**Phase Risks**
- **RISK-03-01:** `scenario_vintage` sits inside `cfg$inputs`, whose validation
  loop calls `file.exists()` on every element. Forgetting the skip branch produces
  the same confusing failure that `fx_rate_usd_vnd` produced in a previous wave.
  Mitigation: the skip branch is called out explicitly in File Changes; add a test
  that loads both real configs immediately after the change.
- **RISK-03-02:** If the 2025 vintage cannot be sourced primarily, the comparison
  report risks being read as authoritative. Mitigation: `SOURCE.md` and a
  prominent banner in the comparison report itself must both state the vintage's
  provenance status, and the report title must include the word "illustrative"
  when the values are synthetic.

### PHASE-04 - Scale Truth and Result History

**Goal**
Replace "we do not know how large a loanbook this supports" with a measured,
published curve, and give the platform an append-only result history so that
every downstream deliverable can express change over time rather than a single
snapshot.

**Tasks**
- [x] TASK-04-01: Create `tools/generate_scale_fixture.R`, a seeded synthetic
  loanbook and asset-based-company-data generator used only for benchmarking. It
  must write exclusively to a path supplied on its command line, must never write
  under `data/`, and must set a seed so a given set of arguments reproduces byte-
  identically. `scripts/generate_vietnam_data.R` is not modified and must remain
  free of any random-number call.
- [x] TASK-04-02: Add `.gitignore` entries for the benchmark scratch directory:
  `bench/` and `bench/**`.
- [x] TASK-04-03: Create `tools/benchmark_scale.R`, which for each configuration
  in the benchmark grid generates a fixture, runs intake, name matching, the PACTA
  stage and engagement scoring, records wall-clock seconds and peak memory for
  each, and appends a row to `docs/scale_benchmark.csv`.
- [x] TASK-04-04: Benchmark the grid from ASM-007: loan counts 1,000 / 10,000 /
  50,000 crossed with distinct-counterparty counts 200 / 1,000 / 5,000, nine
  configurations in total. Record the machine's operating system, CPU model, core
  count and installed memory in the output.
- [x] TASK-04-05: Write `docs/scale_benchmark.md` narrating the measured curve,
  naming the bottleneck stage for each configuration, and stating explicitly which
  configurations were not attempted or did not complete.
- [x] TASK-04-06: Add a "Submission size" section to `intake/SCHEMA.md` stating
  the largest configuration that completed the full chain in under 30 minutes on
  the benchmarking machine, in both loans and distinct counterparties, and stating
  that larger submissions are accepted but not yet characterized. Do not state any
  number that was not measured.
- [x] TASK-04-07: Create `R/run_history.R` implementing the append-only history
  writer and the diff computation.
- [x] TASK-04-08: Create `scripts/record_run_history.R`, a thin script wrapper
  that reads the engagement config and calls `record_run_history()`.
- [x] TASK-04-09: Add a `run_history` boolean config key defaulting to `FALSE`,
  set `TRUE` only in `engagements/mcb-demo/engagement_config.json`. Register
  `record_run_history` as a registry step gated on that key, placed last in the
  step order, after `refresh_audit`.
- [x] TASK-04-10: Classify `history/` as expected churn in
  `tools/verify_refactor.R`'s `classify_path()`, so that a new run directory does
  not read as genuine drift.
- [x] TASK-04-11: Add `history` to the `git add` list in the "Commit refreshed
  snapshot" step of `.github/workflows/refresh.yml`.
- [x] TASK-04-12: Create `scripts/generate_history_diff.R`, producing
  `reports/Run_History_Diff.html` comparing the two most recent history entries
  for an engagement, and add a `client_facing` row for it to
  `reports/report_catalog.json`.

**File Changes**
- `tools/generate_scale_fixture.R` (create).
- `tools/benchmark_scale.R` (create).
- `docs/scale_benchmark.csv` (create): the raw measurements.
- `docs/scale_benchmark.md` (create): the narrative.
- `intake/SCHEMA.md` (modify): add the "Submission size" section after the
  existing "Units" section. Change no existing rule.
- `.gitignore` (modify): add `bench/`.
- `R/run_history.R` (create).
- `scripts/record_run_history.R` (create).
- `scripts/generate_history_diff.R` (create).
- `R/engagement_config.R` (modify): add `run_history = FALSE` to the defaults and
  a boolean check to the validator's existing flag loop.
- `R/step_registry.R` (modify): add the `record_history` entry.
- `engagements/mcb-demo/engagement_config.json` (modify): add
  `"run_history": true`.
- `tools/verify_refactor.R` (modify): `classify_path()` returns expected-churn for
  any path beginning `history/`.
- `.github/workflows/refresh.yml` (modify): add `history` to `git add`.
- `reports/report_catalog.json` (modify): add the history-diff row.
- `tests/testthat/test_run_history.R` (create).
- `tests/testthat/test_config_paths.R` (modify): assert `run_history` defaults
  `FALSE`.

**Function Signatures**
- `make_run_id(git_sha: character, scenario_vintage: character, timestamp: POSIXct = Sys.time()) -> character` —
  returns a directory-safe run identifier of the exact form
  `YYYYMMDD-<sha7>-<vintage>`, for example `20260826-6170ae2-pdp8-2023`. Uses UTC
  for the date component so runs from different time zones sort consistently.
- `record_run_history(cfg: list, artifacts: character, history_root: character = "history") -> character` —
  copies each path in `artifacts` into
  `<history_root>/<bank_slug>/<run_id>/`, writes a `manifest.json` alongside them
  carrying `run_id`, `generated_at`, `git_sha`, `scenario_vintage`, `bank_slug`
  and the list of artifacts, and returns the directory written. Refuses to
  overwrite an existing run directory: if it already exists, the function stops
  with an error naming it. History is append-only.
- `history_runs(bank_slug: character, history_root: character = "history") -> character` —
  returns the run identifiers for a bank, sorted oldest first.
- `history_diff(bank_slug: character, run_a: character, run_b: character, artifact: character, key_cols: character, value_cols: character, history_root: character = "history") -> data.frame` —
  reads the named artifact from both runs, full-joins on `key_cols`, and returns a
  data frame with the key columns, `<col>_a`, `<col>_b` and `<col>_delta` for each
  element of `value_cols`, plus a `change_type` column taking the values
  `"added"`, `"removed"` or `"changed"`. Rows identical across both runs are
  omitted.
- `generate_scale_fixture(n_loans: integer, n_counterparties: integer, seed: integer, out_dir: character) -> list` —
  writes `loanbook.csv` and `abcd.csv` into `out_dir` and returns
  `list(loanbook_path, abcd_path, n_loans, n_counterparties, seed)`. Exposures are
  drawn in whole VND in the range 1e9 to 5e12, matching the magnitude contract in
  `intake/SCHEMA.md`. Sector codes are drawn from the twenty accepted codes already
  handled by `scripts/intake_validate_and_map.R`. Counterparty names are
  ASCII-safe generated strings — do not reuse real company names in a fixture that
  is not committed.

**Test Specs**
- `make_run_id("6170ae2f1a", "pdp8-2023", as.POSIXct("2026-08-26 03:00:00", tz = "UTC"))`
  → `"20260826-6170ae2-pdp8-2023"`.
- `generate_scale_fixture(1000L, 200L, 42L, tempdir())` called twice with the same
  arguments → the two `loanbook.csv` files have identical MD5 digests, proving the
  seed controls everything.
- `generate_scale_fixture(1000L, 200L, 42L, d)` → `read.csv(loanbook_path)` has
  exactly 1000 rows and exactly 200 distinct values in
  `name_direct_loantaker`.
- `generate_scale_fixture(1000L, 200L, 42L, d)` → `median(loan_size_outstanding)`
  is greater than 1e8, so INV-006's VND-magnitude rule would pass on the fixture.
- `record_run_history(cfg, c("output/engagement/engagement_priority.csv"))` into an
  empty temporary history root → creates
  `<root>/mcb-demo/<run_id>/engagement_priority.csv` and
  `<root>/mcb-demo/<run_id>/manifest.json`, and returns that directory.
- Calling `record_run_history()` twice with the same `run_id` → the second call
  stops with an error naming the existing directory. Nothing is overwritten.
- `history_diff("mcb-demo", run_a, run_b, "engagement_priority.csv", key_cols = "name_abcd", value_cols = "composite_score")`
  where run B has one borrower's score changed from `0.50` to `0.60`, one borrower
  added and one removed → a three-row data frame with `change_type` values
  `"changed"`, `"added"` and `"removed"`, and `composite_score_delta` equal to
  `0.10` on the changed row.
- `history_diff()` where the two runs are identical → a zero-row data frame.
- `classify_path("history/mcb-demo/20260826-6170ae2-pdp8-2023/manifest.json")` →
  the expected-churn classification, not genuine drift.

**Dependencies**
- PHASE-02 (step registry and unknown-key validation).

**Exit Criteria**
- [x] `Rscript tools/generate_scale_fixture.R --loans 1000 --counterparties 200 --seed 42 --out bench/f1`
  exits 0 and writes two CSVs; running it a second time produces byte-identical
  files.
- [x] `git status --porcelain data/` is empty after running the fixture generator,
  proving it never writes under `data/`.
- [x] `grep -c "set.seed\|runif\|rnorm\|sample(" scripts/generate_vietnam_data.R`
  returns `0`.
- [x] `docs/scale_benchmark.csv` has one row per attempted configuration with
  non-empty timing columns, and `docs/scale_benchmark.md` names the bottleneck
  stage for each.
- [x] `intake/SCHEMA.md` contains a "Submission size" section whose stated numbers
  each appear in `docs/scale_benchmark.csv`.
- [x] `Rscript scripts/pipeline_refresh.R` followed by
  `Rscript tools/verify_refactor.R --skip-refresh` prints `BYTE-IDENTITY PASS`
  with a new `history/mcb-demo/<run_id>/` directory present.
- [x] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.

**Phase Risks**
- **RISK-04-01:** A 50,000-loan by 5,000-counterparty run may not finish. That is
  a legitimate result, not a failure of the phase. Mitigation: give
  `tools/benchmark_scale.R` a per-configuration timeout defaulting to 3,600
  seconds, record `did_not_complete` in the CSV, and say so in
  `docs/scale_benchmark.md`. Do not tune anything in this phase — measurement
  first, optimization later, and only against a measurement.
- **RISK-04-02:** Fuzzy name matching scales with distinct counterparties, not
  loan count, so a benchmark that varies only loan count will report a
  reassuring and wrong curve. Mitigation: the grid crosses both axes, which is why
  it has nine cells rather than three.
- **RISK-04-03:** `history/` could grow without bound. Mitigation: record only the
  headline artifacts, not full output trees. The artifact list is a config key so
  it is extensible without a schema change.

### PHASE-05 - PCAF Financed Emissions and Carbon-Cost Exposure

**Goal**
Give the platform the financed-emissions layer its own disclosure pack already
cites, computed with an explicit PCAF data-quality score on every figure, and add
the carbon-cost analytic that bridges alignment, stress and emissions into one
number a credit officer can act on. The layer is purely additive: it does not feed
`composite_score`, the sector ranking, or any frozen artifact.

**Tasks**
- [x] TASK-05-01: Create `data/vietnam_emission_factors.csv` with columns
  `sector, technology, emission_factor, unit, source, data_quality_score`. Populate
  power technologies (coal, gas, hydro, solar, wind, nuclear where present in the
  asset-based company data) with factors in tonnes of CO2 per megawatt-hour. Mark
  every row's `source` explicitly as synthetic or as a named published factor.
- [x] TASK-05-02: Create `data/vietnam_capacity_factors.csv` with columns
  `sector, technology, capacity_factor, source`, holding a dimensionless
  utilization fraction between 0 and 1 per power technology.
- [x] TASK-05-03: Add a `borrower_capital_vnd` column to
  `data/vietnam_trisk_financial_features.csv` holding total debt plus total equity
  in whole VND per company, per ASM-005. Add a sibling
  `borrower_capital_source` column taking the values `"reported"` or
  `"sector_median"`.
- [x] TASK-05-04: Create `R/financed_emissions.R` implementing the S2, S3 and S4
  specifications.
- [x] TASK-05-05: Create `scripts/generate_financed_emissions.R`, the pipeline
  step wrapper, writing three CSVs and one HTML report into the engagement's
  output directory.
- [x] TASK-05-06: Add a `run_financed_emissions` boolean config key defaulting to
  `FALSE`, set `TRUE` in both existing engagement configs, and register
  `financed_emissions` as a registry step placed immediately after
  `engagement_scoring`.
- [x] TASK-05-07: Add `paths.financed_emissions_output_dir` to the config schema,
  defaulting to `"output/financed_emissions"`, and set it appropriately in both
  engagement configs.
- [x] TASK-05-08: Add the financed-emissions report to
  `reports/report_catalog.json` as `client_facing` and to `mcb-demo`'s
  `published_reports`.
- [x] TASK-05-09: Update `templates/disclosure/disclosure_sections.md`'s Metrics
  and Targets section so that it reports the financed-emissions figure with its
  data-quality composition, replacing the current text that cites IFRS S2
  Category 15 and then reports alignment gaps instead. State the Scope 3 exclusion
  per ASM-006, naming automotive and coal mining.
- [x] TASK-05-10: Add `run_financed_emissions` and the new path key to the history
  artifact list for `mcb-demo`, so financed emissions is a tracked vintage from
  its very first run.

**File Changes**
- `data/vietnam_emission_factors.csv` (create).
- `data/vietnam_capacity_factors.csv` (create).
- `data/vietnam_trisk_financial_features.csv` (modify): add two columns. **This
  file is a TRISK input.** Confirm with `Rscript tools/verify_refactor.R` that
  adding columns does not change any TRISK output; `trisk.model` should ignore
  unknown columns, but this must be verified, not assumed. If TRISK output does
  move, put the two new columns in a separate sidecar file
  `data/vietnam_borrower_capital.csv` instead and leave the TRISK input untouched.
- `R/financed_emissions.R` (create).
- `scripts/generate_financed_emissions.R` (create).
- `R/engagement_config.R` (modify): add `run_financed_emissions = FALSE` and
  `paths.financed_emissions_output_dir = "output/financed_emissions"`.
- `R/step_registry.R` (modify): add the `financed_emissions` entry.
- `engagements/mcb-demo/engagement_config.json` (modify).
- `engagements/sdb-rehearsal/engagement_config.json` (modify).
- `reports/report_catalog.json` (modify).
- `templates/disclosure/disclosure_sections.md` (modify): the Metrics and Targets
  section only.
- `tests/testthat/test_financed_emissions.R` (create).
- `docs/financed_emissions_methodology.md` (create): the reviewer-facing
  explanation of S2, S3 and S4, written so a person with a calculator can
  reproduce any published figure — the same standard `docs/scoring_anchors.md`
  set.

**Function Signatures**
- `attribution_factor(outstanding_vnd: numeric, capital_vnd: numeric) -> numeric` —
  returns `outstanding_vnd / capital_vnd` clamped to `[0, 1]`, vectorized,
  `NA_real_` where either input is `NA` or where `capital_vnd` is zero.
- `borrower_emissions_power(capacity_mw: numeric, capacity_factor: numeric, emission_factor_tco2_per_mwh: numeric) -> numeric` —
  returns annual tonnes of CO2 equivalent, computed as
  `capacity_mw * capacity_factor * 8760 * emission_factor_tco2_per_mwh`.
- `borrower_emissions_intensity(production_tonnes: numeric, emission_factor_tco2_per_tonne: numeric) -> numeric` —
  returns annual tonnes of CO2 equivalent for cement and steel.
- `pcaf_data_quality_score(activity_source: character, factor_source: character, capital_source: character) -> integer` —
  returns an integer 2 to 5 per the S3 rules, evaluated in the documented order.
  `activity_source` is one of `"reported"` or `"derived"`; `factor_source` is one
  of `"borrower"` or `"technology"`; `capital_source` is one of `"reported"` or
  `"sector_median"`.
- `financed_emissions(loanbook: data.frame, abcd: data.frame, capital: data.frame, factors: data.frame, capacity_factors: data.frame) -> data.frame` —
  returns one row per borrower with columns
  `name_abcd, sector, scope, outstanding_vnd, borrower_capital_vnd,
  attribution_factor, borrower_emissions_tco2e, financed_emissions_tco2e,
  data_quality_score, exclusion_reason, data_source`. `scope` is the literal
  `"1+2"` on every computed row.
- `data_quality_summary(fe: data.frame) -> data.frame` — returns one row per
  distinct `data_quality_score` present, with columns
  `data_quality_score, n_borrowers, financed_emissions_tco2e, share_of_total`,
  where `share_of_total` is computed per S3 over scored rows only.
- `carbon_cost_exposure(fe: data.frame, carbon_price: data.frame, fx_rate_usd_vnd: numeric) -> data.frame` —
  returns one row per borrower per year with columns
  `name_abcd, sector, year, financed_emissions_tco2e, carbon_price_usd_per_tco2,
  fx_rate_usd_vnd, carbon_cost_vnd`. When `fx_rate_usd_vnd` has length 0,
  `carbon_cost_vnd` is `NA_real_` on every row.

**Test Specs**
- `attribution_factor(500e9, 2000e9)` → `0.25`.
- `attribution_factor(3000e9, 2000e9)` → `1` (clamped, not `1.5`).
- `attribution_factor(500e9, 0)` → `NA_real_`.
- `attribution_factor(c(500e9, NA), c(2000e9, 2000e9))` → `c(0.25, NA_real_)`.
- `borrower_emissions_power(1000, 0.6, 0.9)` → `4730400`. Derivation:
  `1000 * 0.6 * 8760 = 5256000` megawatt-hours, times `0.9` tonnes per
  megawatt-hour.
- `borrower_emissions_intensity(2e6, 0.85)` → `1700000`.
- `pcaf_data_quality_score("reported", "borrower", "reported")` → `2L`.
- `pcaf_data_quality_score("reported", "technology", "reported")` → `3L`.
- `pcaf_data_quality_score("derived", "technology", "reported")` → `4L`.
- `pcaf_data_quality_score("derived", "technology", "sector_median")` → `5L`.
- `pcaf_data_quality_score("reported", "borrower", "sector_median")` → `5L`,
  because the sector-median capital rule wins regardless of the other two inputs.
- `financed_emissions()` on a two-borrower fixture where borrower A is a power
  company (1000 megawatts, capacity factor 0.6, factor 0.9 tonnes per
  megawatt-hour, 500 billion VND outstanding, 2 trillion VND capital) → row A has
  `attribution_factor == 0.25` and
  `financed_emissions_tco2e == 1182600` (that is `4730400 * 0.25`).
- `financed_emissions()` on an automotive borrower → one row with
  `financed_emissions_tco2e` equal to `NA_real_` and `exclusion_reason` equal to
  `"scope_3_dominant_sector_out_of_scope"`.
- `data_quality_summary()` on a frame with two rows scored 3 carrying 100 and 300
  tonnes → the score-3 row has `share_of_total == 1` and `n_borrowers == 2`.
- `data_quality_summary()` ignores rows whose `financed_emissions_tco2e` is `NA`
  when computing `share_of_total`; the shares across scores sum to exactly 1.
- `carbon_cost_exposure(fe, prices, 26300)` with
  `financed_emissions_tco2e == 1000` and `carbon_price_usd_per_tco2 == 50` →
  `carbon_cost_vnd == 1315000000` (that is `1000 * 50 * 26300`), in whole VND with
  no rescaling.
- `carbon_cost_exposure(fe, prices, numeric(0))` → every `carbon_cost_vnd` is
  `NA_real_`, and the calling script exits non-zero after writing every output,
  naming `inputs.fx_rate_usd_vnd`.
- Running the full step on `mcb-demo` → `Rscript tools/verify_refactor.R` still
  prints `BYTE-IDENTITY PASS`, proving the layer is additive.

**Dependencies**
- PHASE-03 (so financed emissions is stamped with a scenario vintage) and
  PHASE-04 (so its first run is its first history vintage).

**Exit Criteria**
- [x] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --only-step financed_emissions`
  exits 0 and writes `financed_emissions.csv`, `data_quality_summary.csv` and
  `carbon_cost_exposure.csv` into the configured output directory.
- [x] Every row of `financed_emissions.csv` has either a non-`NA`
  `data_quality_score` or a non-empty `exclusion_reason` — never both empty.
- [x] The `share_of_total` column of `data_quality_summary.csv` sums to `1` within
  a tolerance of `1e-9`.
- [x] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS`.
- [x] `Rscript tools/verify_refactor.R --invariants` prints `[PASS]` for every
  invariant.
- [x] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [x] The generated HTML report contains the synthetic-data disclaimer, the Scope
  3 exclusion statement naming automotive and coal mining, and the data-quality
  composition table.

**Phase Risks**
- **RISK-05-01:** A financed-emissions total is the single most misquotable number
  this repository can produce. Mitigation: no total may appear anywhere — CSV,
  HTML, dashboard — without its data-quality composition adjacent to it, and the
  disclaimer for this artifact must be stricter than the standard banner, stating
  that the figure is computed from synthetic activity data and synthetic emission
  factors and is not an emissions inventory of any institution.
- **RISK-05-02:** Adding columns to `data/vietnam_trisk_financial_features.csv`
  may perturb TRISK output. Mitigation: the fallback to a separate
  `data/vietnam_borrower_capital.csv` is specified in File Changes; decide by
  running the byte-identity gate immediately after the column addition and before
  writing any other code in this phase.

### PHASE-06 - The Four Client Commitments

**Goal**
Deliver the sustainability-linked-loan readiness screen, the sector target
registry, the client-neutral report generator, and the workshop kit — the four
commitments where the machinery already exists but is pointed at the wrong thing.
Reconciling the three artifacts that still publish pre-Wave-2 numbers is a
blocking prerequisite, done first.

**Tasks**
- [x] TASK-06-01 (blocking prerequisite): Reconcile the three stale artifacts.
  In `docs/bidv_sector_prioritization_methodology.md`, replace the min-max
  formulas in sections 2.1 through 2.3 with the anchor-table method described in
  `docs/scoring_anchors.md`, and replace the section 9 results
  (Power 1.000 / Steel 0.158 Low / Cement 0.011 Low) with the values the code
  actually produces today, read from
  `synthesis_output/prioritization/sector_priority_ranking.csv`. Apply the same
  correction to `synthesis_output/prioritization/interpretation_notes.md` and to
  the "scoring maximum (1.0)" passage in `scripts/generate_bidv_report.R`.
- [x] TASK-06-02: Add scoring-weight keys to the engagement config schema:
  `scoring.weight_alignment` defaulting to the value
  `scripts/engagement_scoring.R` currently uses as `w_align`, and
  `scoring.weight_trisk` defaulting to its current `w_trisk`. Read the current
  defaults out of the script rather than guessing them. Have
  `scripts/run_engagement.R` forward them to the scoring step. Defaults must
  reproduce today's numbers exactly, so the byte-identity gate stays green.
- [x] TASK-06-03: Create `R/sll_readiness.R` implementing the S5 specification,
  reusing `severity_from_anchors()` from `R/severity_scoring.R` for the exposure
  dimension.
- [x] TASK-06-04: Create `scripts/sll_readiness.R`, reading
  `engagement_priority.csv` plus the optional relationship overlay, and writing
  `sll_readiness.csv` and `SLL_Readiness_Shortlist.html`.
- [x] TASK-06-05: Add `inputs.relationship_overlay_csv` to the config schema,
  defaulting to `NULL`, and skip it in the "every input must exist" validation
  loop the same way `raw_loanbook_csv` is skipped when empty.
- [ ] TASK-06-06: Create `R/target_setting.R` implementing sectoral decarbonization
  convergence for cement and steel from
  `synthesis_output/vietnam/05_vn_sda_portfolio.csv` and the scenario CO2 file.
  `pacta_sda()` in `R/pacta_core.R` is not modified (DEC-009).
- [ ] TASK-06-07: Create `scripts/generate_targets.R`, writing
  `target_registry.csv` per the S6 specification and a
  `Sector_Target_Registry.html` report.
- [ ] TASK-06-08: Document the methodological duality in
  `docs/financed_emissions_methodology.md` and in the target registry report: PACTA
  alignment gaps are measured against the scenario benchmark, while targets are
  computed by convergence. One explicit sentence, in both places.
- [ ] TASK-06-09: Parameterize `scripts/generate_bidv_report.R`. Add `--config`
  parsing via `get_config_arg()`, replace every hardcoded
  `"Mekong Commercial Bank"` and `"BIDV"` literal with `cfg$bank_name`, and split
  its narrative source material into client-neutral methodology plus a
  per-engagement content overlay at a new config path
  `paths.report_overlay_md`. Do not rewrite the 1,034 lines of assembly logic.
- [ ] TASK-06-10: Strip the `"Mekong Commercial Bank"` literals from all four
  sector rows of `templates/engagement/engagement_prompt_templates.csv` and from
  `templates/disclosure/disclosure_sections.md`, replacing them with the
  `{{bank_name}}` token. Verify the existing residual-token guard in
  `scripts/generate_engagement_letters.R` still fails the run on any unreplaced
  token.
- [ ] TASK-06-11: Register `sll_readiness` and `generate_targets` as registry
  steps gated on new boolean keys `run_sll_readiness` and `run_targets`, both
  defaulting to `FALSE` and both set `TRUE` for `mcb-demo`. Both must run after
  `engagement_scoring` and after `refresh_dashboard_data`, because the scoring
  step reads the published snapshot rather than `synthesis_output/trisk`.
- [ ] TASK-06-12: Create the `workshop/` directory as a facilitation kit
  assembling existing assets: a `README.md` sequencing the session, a data-
  readiness exercise built on `intake/templates/` and the whole-VND unit contract,
  a methodology walkthrough built on `docs/scoring_anchors.md`, a live-surface
  segment pointing at the Scenario Builder page, and a worked example built on an
  anonymized disclosure pack produced with `anonymize: true`. Write facilitation
  notes and timings; write no new analytical content.
- [ ] TASK-06-13: Add `SLL_Readiness_Shortlist.html` and
  `Sector_Target_Registry.html` to `reports/report_catalog.json` as
  `client_facing`.

**File Changes**
- `docs/bidv_sector_prioritization_methodology.md` (modify): sections 2.1–2.3 and
  section 9.
- `synthesis_output/prioritization/interpretation_notes.md` (modify): the stale
  results narrative.
- `scripts/generate_bidv_report.R` (modify): the "scoring maximum (1.0)" passage,
  plus the `--config` parameterization.
- `R/engagement_config.R` (modify): add `scoring` list,
  `inputs.relationship_overlay_csv`, `paths.report_overlay_md`,
  `run_sll_readiness`, `run_targets`.
- `R/sll_readiness.R` (create).
- `scripts/sll_readiness.R` (create).
- `R/target_setting.R` (create).
- `scripts/generate_targets.R` (create).
- `R/step_registry.R` (modify): two new entries.
- `templates/engagement/engagement_prompt_templates.csv` (modify): four rows.
- `templates/disclosure/disclosure_sections.md` (modify): bank-name literals.
- `engagements/mcb-demo/engagement_config.json` (modify).
- `engagements/sdb-rehearsal/engagement_config.json` (modify).
- `reports/report_catalog.json` (modify).
- `workshop/README.md` (create) plus the kit's supporting markdown files.
- `docs/scoring_anchors.md` (modify): add the SLL readiness anchor table and the
  `trisk_stress_rank_pct` note deferred from ASM-004 — the note lands here, the
  column rename lands in PHASE-07.
- `tests/testthat/test_sll_readiness.R` (create).
- `tests/testthat/test_target_setting.R` (create).

**Function Signatures**
- `sll_readiness_score(severity_alignment: numeric, severity_trisk: numeric, exposure_vnd: numeric, has_abcd_match: logical, relationship: numeric = NA_real_) -> numeric` —
  returns a value in `[0, 1]` per S5, vectorized. When `relationship` is `NA` on
  every element, the relationship weight is dropped and the remaining three
  weights renormalize.
- `sll_readiness_band(readiness: numeric) -> character` — returns one of
  `"Ready"`, `"Near-ready"`, `"Developing"`, `"Not ready"` per the S5 breakpoints.
- `sll_readiness(priority: data.frame, abcd: data.frame, overlay: data.frame = NULL) -> data.frame` —
  returns one row per borrower with columns
  `name_abcd, sector, exposure_vnd, materiality, exposure_severity,
  data_availability, relationship, readiness, readiness_band, readiness_partial,
  analyst_rationale`, sorted by `readiness` descending. `analyst_rationale` is
  always the empty string; it exists for a human to fill in.
- `sda_convergence_target(baseline_value: numeric, baseline_year: integer, scenario: data.frame, target_year: integer) -> numeric` —
  returns the portfolio-anchored convergence target value at `target_year`,
  computed by scaling the baseline by the scenario's own ratio between
  `target_year` and `baseline_year`.
- `build_target_registry(sda_portfolio: data.frame, ms_portfolio: data.frame, scenario_co2: data.frame, scenario_ms: data.frame, scenario_vintage: character, horizons: integer = c(2030L, 2035L, 2050L)) -> data.frame` —
  returns the registry with the exact twelve columns, in the exact order, given in
  S6.

**Test Specs**
- `sll_readiness_score(0.8, 0.6, 1e12, TRUE, 0.5)` → the weighted mean
  `(0.30 * 0.7 + 0.25 * 0.75 + 0.25 * 1.0 + 0.20 * 0.5) / 1.0 = 0.7325`, where
  `0.7` is the mean of `0.8` and `0.6`, and `0.75` is
  `severity_from_anchors(1e12, c(1e10, 1e11, 5e11, 1e12, 5e12))`.
- `sll_readiness_score(0.8, 0.6, 1e12, TRUE, NA_real_)` with `relationship` `NA`
  on every element → `(0.30 * 0.7 + 0.25 * 0.75 + 0.25 * 1.0) / 0.80 = 0.809375`.
- `sll_readiness_score(0.8, NA_real_, 1e12, TRUE, 0.5)` → materiality falls back
  to `severity_alignment` alone, so materiality is `0.8`.
- `sll_readiness_band(0.75)` → `"Ready"`. `sll_readiness_band(0.7499)` →
  `"Near-ready"`. `sll_readiness_band(0.34)` → `"Not ready"`.
- `sll_readiness(priority, abcd, overlay = NULL)` on the 23-row MCB
  `engagement_priority.csv` → 23 rows, every `readiness_partial` is `TRUE`, and
  the count of rows banded `"Ready"` or `"Near-ready"` is between 5 and 8
  inclusive. If it falls outside that range, retune the exposure anchors and
  record the change in `docs/scoring_anchors.md`.
- `build_target_registry(...)` → a data frame with exactly the twelve S6 columns
  in the S6 order; every row has `status` in
  `c("proposed", "not_set")` and none has `"adopted"`; every `scenario_vintage`
  equals the engagement's configured vintage; rows with `target_year` in
  `c(2035L, 2050L)` have `target_value` equal to `NA_real_` and `status` equal to
  `"not_set"`.
- Running `scripts/generate_engagement_letters.R` after TASK-06-10 → exits 0 and
  no generated letter contains the literal string `{{bank_name}}` or the literal
  string `Mekong Commercial Bank` when the config's `bank_name` is
  `Saigon Delta Bank`.
- `Rscript tools/verify_refactor.R` after TASK-06-02 → `BYTE-IDENTITY PASS`,
  proving the weight defaults reproduce today's numbers exactly.

**Dependencies**
- PHASE-05 (the target registry's Metrics and Targets narrative references
  financed emissions; the workshop kit's worked example uses the updated
  disclosure pack).

**Exit Criteria**
- [ ] `grep -rn "1\.000" docs/bidv_sector_prioritization_methodology.md` returns no
  match in a results context, and the sector scores quoted in that document match
  `synthesis_output/prioritization/sector_priority_ranking.csv` exactly.
- [ ] `grep -rn "Mekong Commercial Bank" templates/` returns no match.
- [ ] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --only-step sll_readiness`
  exits 0 and writes `sll_readiness.csv` with 23 rows.
- [ ] `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --only-step generate_targets`
  exits 0 and writes `target_registry.csv` whose column names, in order, match S6.
- [ ] `Rscript scripts/generate_bidv_report.R --config engagements/sdb-rehearsal/engagement_config.json`
  exits 0 and the resulting HTML contains `Saigon Delta Bank` and does not contain
  `BIDV` outside of citations to published BIDV framework documents.
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS`.
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0`.
- [ ] `workshop/README.md` exists and every asset it references resolves to a real
  path in the repository.

**Phase Risks**
- **RISK-06-01:** Two scoring paths (`engagement_scoring.R` and
  `sll_readiness.R`) can drift apart. Mitigation: both must source
  `R/severity_scoring.R` and use `severity_from_anchors()` rather than
  hand-rolling interpolation; add a test asserting that
  `sll_readiness()`'s `materiality` column equals the mean of the
  `severity_alignment` and `severity_trisk` columns of its own input for every
  row where both are present.
- **RISK-06-02:** Correcting the three stale documents changes text that a client
  may already have seen. Mitigation: add a dated note at the top of
  `docs/bidv_sector_prioritization_methodology.md` recording that the scoring
  method changed in version 0.4.0 and that earlier figures were rank-relative.
- **RISK-06-03:** Parameterizing `generate_bidv_report.R` touches 1,034 lines.
  Mitigation: run it for `mcb-demo` before and after and diff the output, allowing
  only the generated-timestamp text to differ.

### PHASE-07 - Bilingual PDF Delivery and the Single Refreeze

**Goal**
Close the delivery-format gap — PDF output and Vietnamese labels — and then land
the one authorized golden refreeze of this program, carrying the composite-score
rounding fix, the misleading column rename, and the switch of the public demo to
the 2025 scenario vintage, in a single reviewed commit that bumps the package to
0.5.0.

**Tasks**
- [ ] TASK-07-01: Create `templates/i18n/labels.csv` with columns
  `token, en, vi`. Populate it with every section heading, table column label and
  disclaimer string used by the report generators. The synthetic-data disclaimer
  must be among the first entries translated (CON-005).
- [ ] TASK-07-02: Add `report_label()` to `R/report_toolkit.R`, plus loading and
  caching of the label table and any per-engagement override.
- [ ] TASK-07-03: Add `paths.i18n_override_csv` to the config schema, defaulting
  to `NULL`, skipped in the "every input must exist" validation when empty.
- [ ] TASK-07-04: Add a `report_language` config key taking `"en"`, `"vi"` or
  `"bilingual"`, defaulting to `"en"` so no existing output changes. Set it to
  `"bilingual"` for `mcb-demo` only after the byte-identity implications are
  confirmed — HTML reports are exempt from byte-identity except for timestamp
  text, but confirm this against `tools/verify_refactor.R`'s classifier before
  flipping it.
- [ ] TASK-07-05: Retrofit the report generators to call `report_label()` for
  headings, table column labels and disclaimers:
  `scripts/generate_coverage_report.R`, `scripts/generate_validation_report.R`,
  `scripts/generate_disclosure_pack.R`, `scripts/generate_engagement_letters.R`,
  and `scripts/generate_financed_emissions.R`. Leave analyst-written narrative in
  English and add one sentence to each bilingual artifact stating which parts are
  translated.
- [ ] TASK-07-06: Create `tools/render_pdf.R`, converting a self-contained HTML
  file to PDF behind a `requireNamespace()` guard. It must print a clear,
  actionable message and exit non-zero when the renderer is unavailable, naming
  the prerequisite. It must never be invoked from `scripts/run_engagement.R` or
  appear in `R/step_registry.R`.
- [ ] TASK-07-07: Document the PDF path in `docs/outputs_layer.md`: the command,
  the prerequisite, and the statement that HTML remains the canonical generated
  artifact.
- [ ] TASK-07-08 (refreeze): Apply S1. In `scripts/engagement_scoring.R`, round
  `composite_score` to 10 decimal places before both writing it and computing
  `composite_rank_pct`.
- [ ] TASK-07-09 (refreeze): Apply ASM-004. Rename the `trisk_priority_score`
  column of `engagement_priority.csv` to `trisk_stress_rank_pct` in
  `scripts/engagement_scoring.R`'s `dplyr::select()` block, and update every
  consumer: `scripts/generate_engagement_letters.R`,
  `scripts/generate_disclosure_pack.R`, `R/sll_readiness.R`, and any dashboard
  loader that names the column. Search with
  `grep -rn "trisk_priority_score" --include=*.R --include=*.py .` and fix every hit.
- [ ] TASK-07-10 (refreeze): Apply ASM-009. Change
  `engagements/mcb-demo/engagement_config.json`'s `inputs.scenario_vintage` to
  `"pdp8-2025-adjusted"` and both scenario paths to that directory. Leave
  `sdb-rehearsal` on `pdp8-2023` so the two-vintage comparison keeps a live
  counterpart.
- [ ] TASK-07-11 (refreeze): Regenerate every affected artifact in one run:
  `Rscript scripts/pipeline_refresh.R`, then
  `RUN_SDB_ENGAGEMENT=1 Rscript scripts/run_engagement.R --config engagements/sdb-rehearsal/engagement_config.json`.
- [ ] TASK-07-12 (refreeze): Re-pin `tests/testthat/test_golden_numbers.R` to the
  new values. Read the actual regenerated `engagement_priority.csv` and pin the
  new rank-1 name and score. Keep the anti-min-max guard
  (`all(ep$composite_score > 0 & ep$composite_score < 1)`) and the MCB-versus-SDB
  difference test unchanged. Add a new assertion that
  `length(unique(ep$composite_rank_pct)) <= length(unique(ep$composite_score))`,
  which fails if ranking ever again separates borrowers that the published score
  does not.
- [ ] TASK-07-13 (refreeze): Re-pin `tests/testthat/test_sdb_engagement.R` if the
  scenario-vintage change or the rounding moves its committed fixtures.
- [ ] TASK-07-14 (refreeze): Bump `DESCRIPTION` `Version` to `0.5.0` and write the
  `# pactatrisk 0.5.0` section of `NEWS.md`, covering every phase of this program.
  Per TASK-01-04, do not quote a test count.
- [ ] TASK-07-15: Land the refreeze as a single commit. Run the weekly refresh
  workflow manually with `allow_drift: true` if the automated refresh fires before
  the refreeze commit is merged; this is exactly the case that input exists for.

**File Changes**
- `templates/i18n/labels.csv` (create).
- `R/report_toolkit.R` (modify): add `report_label()` and the label-table loader.
  Leave `img_to_base64()`, `report_css()` and `write_html_report()` unchanged.
- `R/engagement_config.R` (modify): add `paths.i18n_override_csv` and
  `report_language`.
- `scripts/generate_coverage_report.R`, `scripts/generate_validation_report.R`,
  `scripts/generate_disclosure_pack.R`, `scripts/generate_engagement_letters.R`,
  `scripts/generate_financed_emissions.R` (modify): label lookups only.
- `tools/render_pdf.R` (create).
- `docs/outputs_layer.md` (modify): add the PDF section.
- `scripts/engagement_scoring.R` (modify): rounding and the column rename.
- `engagements/mcb-demo/engagement_config.json` (modify): scenario vintage.
- `tests/testthat/test_golden_numbers.R` (modify): re-pin.
- `tests/testthat/test_sdb_engagement.R` (modify): re-pin if needed.
- `DESCRIPTION` (modify): version.
- `NEWS.md` (modify): the 0.5.0 section.
- `docs/scoring_anchors.md` (modify): record the rounding rule as part of the
  published method.
- All regenerated artifacts under `synthesis_output/`, `output/engagement/`,
  `dashboard/data/` and `engagements/sdb-rehearsal/` (modify, by regeneration).

**Function Signatures**
- `report_label(token: character, lang: character = "en", labels: data.frame = NULL) -> character` —
  returns the label for `token` in language `lang`. When `lang` is `"bilingual"`,
  returns `paste0(en, " / ", vi)`. When `token` is absent from the table, returns
  `token` itself unchanged and emits one warning per missing token per run, so a
  missing translation degrades visibly rather than silently.
- `load_report_labels(base_csv: character = "templates/i18n/labels.csv", override_csv: character = NULL) -> data.frame` —
  returns the label table with any override rows replacing base rows on matching
  `token`. Stops with an error if `base_csv` is missing or lacks any of the three
  required columns.
- `render_pdf(html_path: character, pdf_path: character) -> character` — returns
  the path written. Stops with an actionable message naming the missing
  prerequisite when no renderer is available.

**Test Specs**
- `report_label("coverage_summary", "en", labels)` → the English string.
- `report_label("coverage_summary", "vi", labels)` → the Vietnamese string.
- `report_label("coverage_summary", "bilingual", labels)` →
  `"<english> / <vietnamese>"`.
- `report_label("no_such_token", "en", labels)` → `"no_such_token"`, with exactly
  one warning raised.
- `load_report_labels(base, override)` where the override supplies a different
  `vi` value for one token → that token's `vi` comes from the override and every
  other row comes from the base.
- After TASK-07-08, `read.csv("output/engagement/engagement_priority.csv")` →
  every `composite_score` value has at most 10 decimal places, and
  `length(unique(composite_rank_pct)) <= length(unique(composite_score))`.
- After TASK-07-08, the six renewables borrowers that previously split across
  percentiles `0.1957` and `0.0652` because of a one-ULP difference in
  `alignment_gap` → all six share a single `composite_rank_pct` value.
- `grep -rn "trisk_priority_score" --include=*.R --include=*.py .` after
  TASK-07-09 → no matches.
- `read.csv("output/engagement/engagement_priority.csv")` after TASK-07-09 →
  `"trisk_stress_rank_pct" %in% names(ep)` is `TRUE` and
  `"trisk_priority_score" %in% names(ep)` is `FALSE`.
- `tools/render_pdf.R` on a repository where no renderer package is installed →
  exits non-zero with a message naming the missing package and the install
  command; it must not raise an uncaught R error.

**Dependencies**
- PHASE-06 (all content that the delivery layer formats must exist first; the
  refreeze must carry every number-moving change in the program).

**Exit Criteria**
- [ ] `Rscript -e "testthat::test_dir('tests/testthat')"` reports `FAIL 0` with
  the re-pinned golden values.
- [ ] `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`
  reports `FAIL 0`.
- [ ] `python -m pytest dashboard/tests` passes.
- [ ] `Rscript tools/verify_refactor.R` prints `BYTE-IDENTITY PASS` when run
  against the post-refreeze committed tree — that is, the refreeze is stable and
  reproduces itself.
- [ ] `Rscript tools/verify_refactor.R --invariants` prints `[PASS]` for every
  invariant, INV-001 through INV-009.
- [ ] `grep -c "0\.4\.1" DESCRIPTION` returns `0` and `grep -c "0\.5\.0" DESCRIPTION`
  returns `1`.
- [ ] `Rscript tools/render_pdf.R reports/pipeline_refresh_audit.html /tmp/out.pdf`
  either writes a non-empty PDF or exits non-zero with an actionable message; it
  never fails silently.
- [ ] Every artifact regenerated in this phase is committed together in one
  commit whose message names it as the 0.5.0 refreeze.

**Phase Risks**
- **RISK-07-01:** Combining three number-moving changes (rounding, column rename,
  scenario vintage) into one refreeze makes it harder to attribute a surprising
  result to its cause. Mitigation: run the pipeline three times, applying one
  change at a time, and record the resulting `engagement_priority.csv` after each
  into `bench/refreeze-step-{1,2,3}/` for inspection — then commit only the final
  state. The intermediate runs are diagnostic only and are never committed.
- **RISK-07-02:** Renaming `trisk_priority_score` may break an unnoticed consumer,
  including the Streamlit pages. Mitigation: the repository-wide `grep` in
  TASK-07-09 is the acceptance check, and `python -m pytest dashboard/tests` must
  pass afterwards.
- **RISK-07-03:** Switching the public demo's scenario vintage will visibly change
  the headline coal alignment gap that several documents quote. Mitigation: after
  regenerating, grep the `docs/` tree for the old figure and update every
  occurrence in the same commit, exactly as TASK-06-01 did for the min-max
  figures. The failure mode here is precisely the one that created the three stale
  artifacts in the first place.

## Gotchas

- **Run every R command from the repository root.** Scripts resolve paths through
  `getwd()`, and `tests/testthat/helper-root.R` finds the root by walking upward
  for a `dashboard/` directory. Running from `scripts/` silently produces wrong
  paths rather than an error.
- **`Rscript` must be on `PATH` even when the outer call used a full path.**
  `scripts/run_engagement.R` and `R/step_runner.R` shell out with
  `system2("Rscript", ...)`. On Windows run
  `$env:Path += ";C:\Program Files\R\R-4.5.2\bin"` first.
- **PowerShell 5.1 has no `&&`.** Chain with `;` or use separate commands. Every
  command in this plan is written to run unchanged in a POSIX shell and, where
  chaining is absent, in PowerShell too.
- **Never rescale VND.** Exposures span 1e5 to 5e12 in whole Dong. A PCAF
  attribution factor is a ratio of two VND quantities and is unit-safe, but its
  denominator must be captured in whole VND. Format for display only through
  `R/format_money.R`. INV-006 fails if any declared-VND loanbook's median exposure
  drops below 1e8, which is what catches an accidental millions-of-VND rescale.
- **`cfg$inputs` is validated with `file.exists()` on every element.** Any new key
  added under `inputs` that is not a path — `fx_rate_usd_vnd` today,
  `scenario_vintage` in PHASE-03 — must be added to the skip branch in
  `.validate_engagement_config()`, or every config that sets it fails with a
  confusing "input file(s) not found" message naming the value.
- **Empty optional config values round-trip as `list()`, never as their original
  type.** `jsonlite::toJSON(..., auto_unbox = TRUE)` serializes `NULL` as `{}` and
  `character(0)` as `[]`, and `jsonlite::read_json(..., simplifyVector = TRUE)`
  returns an empty named `list()` for both. Test "not configured" with
  `length(x) == 0`. This bug only appears on the *second* generation of a config —
  the resolved copy `run_engagement.R` writes after intake — so a test that only
  loads a hand-written JSON file will not catch it.
- **Caches must be keyed on their inputs, not only on their parameters.** The
  TRISK scenario grid learned this the hard way and now carries
  `grid_input_fingerprint()`. Any cache added by this plan must hash its input
  files and invalidate the whole cache on mismatch, never merge partially.
- **A test that reads a committed artifact guards the artifact, not the code.**
  `test_sdb_engagement.R` exists in both forms deliberately: a fixture-content
  test that always runs, and a regeneration test gated behind
  `RUN_SDB_ENGAGEMENT=1` that runs in CI. Any new regression test for "does the
  code still produce this" must actually run the code.
- **Byte-identity is verified through `git diff`, never through file digests.**
  Git's `core.autocrlf` normalization means two files identical after
  normalization can have different raw digests across Windows and Linux. Extend
  `tools/verify_refactor.R` rather than hand-rolling a comparison.
- **Deleting a published artifact and changing the code that publishes it must
  land in the same commit,** or the byte-identity gate reports the deletion as
  drift.
- **Percentage points versus percent.** `alignment_gap` and `gap_pct` are in
  percentage points (`13.548387096774196` means 13.55 pp), while
  `severity_alignment` and `composite_score` are dimensionless values in `[0, 1]`.
  The vintage comparison's `gap_delta_pp` is a difference of percentage points, not
  a percentage change.
- **`8760` hours per year, always.** Do not adjust for leap years in the power
  generation formula; the asset-based company data is annual and the scenario
  pathways are annual.
- **PCAF data-quality scores run 1 (best) to 5 (worst).** This is the opposite
  direction from every severity score in this repository, where 1 is worst. Label
  the column and every axis explicitly.
- **`attic/` is do-not-touch except to receive newly retired code.** It is not
  sourced by any pipeline and not tested. `scripts/generate_report.R` and the
  r2dii demo CSVs move there in PHASE-02 and must not be modified in the move.
- **`dashboard/data/` may be written only by `scripts/refresh_dashboard_data.R`,
  and only for the `mcb-demo` engagement.** The orchestrator refuses to start any
  engagement whose `snapshot_dir` resolves there without
  `public_snapshot_allowed: true`.
- **Every generated artifact must carry a synthetic-data disclaimer.** For the
  financed-emissions artifacts the disclaimer must be stricter than the standard
  banner, because a financed-emissions total is the most misquotable number this
  platform can produce.
- **The supported-sector literal `c("power", "cement", "steel")` is duplicated
  across several files and cross-checked by INV-004.** Nothing added by this plan
  may become an uncoordinated additional copy; read it from
  `R/sector_registry.R` instead.

## Verification Strategy

- **TEST-001:** `Rscript -e "testthat::test_dir('tests/testthat')"` → reports
  `FAIL 0`, with a pass count greater than or equal to 408 at every phase
  boundary.
- **TEST-002:** `python -m pytest dashboard/tests` → reports all tests passing,
  with a count greater than or equal to 58 at every phase boundary.
- **TEST-003:** `Rscript tools/verify_refactor.R` → prints `BYTE-IDENTITY PASS`
  and exits 0 at the end of PHASE-01 through PHASE-06. In PHASE-07 it must print
  `BYTE-IDENTITY PASS` when run against the post-refreeze committed tree.
- **TEST-004:** `Rscript tools/verify_refactor.R --invariants` → prints `[PASS]`
  for every registered invariant and exits 0. The registered set grows from
  INV-001..006 to INV-001..009 across this plan.
- **TEST-005:** `RUN_SDB_ENGAGEMENT=1 Rscript -e "testthat::test_file('tests/testthat/test_sdb_engagement.R')"`
  → reports `FAIL 0`.
- **TEST-006:** `Rscript scripts/run_engagement.R --config engagements/mcb-demo/engagement_config.json --dry-run > /tmp/steps_after.txt`
  compared with the same output captured before PHASE-02 →
  `diff /tmp/steps_before.txt /tmp/steps_after.txt` produces no output.
- **TEST-007:** `git check-ignore -q engagements/bidv/intake/normalized_loanbook.csv`
  with a placeholder file created at that path → exits 0 (the file is ignored).
  Then `git check-ignore -q engagements/sdb-rehearsal/intake/normalized_loanbook.csv`
  → exits 1 (the fixture is still tracked). Remove the placeholder afterwards.
- **TEST-008:** `Rscript -e "source('R/financed_emissions.R'); print(attribution_factor(500e9, 2000e9))"`
  → prints `[1] 0.25`.
- **TEST-009:** `Rscript -e "d <- read.csv('output/financed_emissions/data_quality_summary.csv'); stopifnot(abs(sum(d\$share_of_total) - 1) < 1e-9); cat('OK\n')"`
  → prints `OK`.
- **TEST-010:** `grep -rn "trisk_priority_score" --include=*.R --include=*.py .`
  after PHASE-07 → no output.
- **TEST-011:** `grep -rn "Mekong Commercial Bank" templates/` after PHASE-06 →
  no output.
- **TEST-012:** `Rscript -e "cat(nrow(read.csv('data/scenarios/pdp8-2025-adjusted/vietnam_scenario_ms.csv')), nrow(read.csv('data/scenarios/pdp8-2023/vietnam_scenario_ms.csv')), '\n')"`
  → prints two identical numbers.
- **MANUAL-001:** Open `reports/Scenario_Vintage_Comparison.html` in a browser and
  confirm it names both vintages in the title, states the provenance of the 2025
  vintage, carries the synthetic-data disclaimer, and shows a non-empty delta
  table.
- **MANUAL-002:** Open the generated financed-emissions HTML report and confirm
  that no headline total appears without its data-quality composition adjacent to
  it, and that the Scope 3 exclusion statement names automotive and coal mining.
- **MANUAL-003:** Run `python -m streamlit run dashboard/app.py`, visit the
  Reports page, and confirm that every HTML file present in
  `dashboard/data/reports/` is listed — none silently dropped — and that no listed
  report is an internal engineering phase report or built on European demo data.
- **MANUAL-004:** Render one engagement letter and one disclosure pack with
  `report_language` set to `"bilingual"` and confirm the Vietnamese labels appear
  alongside the English, that the disclaimer is translated, and that the artifact
  states which parts remain English.
- **OBS-001:** After PHASE-02, force a step failure (temporarily rename a script
  the step list references) and confirm the written `pipeline_manifest.json`
  carries a non-empty `error_excerpt` for the failed step. Restore the script.
- **OBS-002:** After PHASE-04, run `Rscript scripts/pipeline_refresh.R` twice and
  confirm two distinct directories exist under `history/mcb-demo/`, that the
  second run did not overwrite the first, and that
  `Rscript tools/verify_refactor.R --skip-refresh` still prints
  `BYTE-IDENTITY PASS`.
- **OBS-003:** Confirm the GitHub Actions `ci.yml` workflow passes all four jobs
  (`python-tests`, `r-tests`, `sdb-engagement`, `byte-identity`) on the branch
  carrying each phase before merging it.

## Risks and Alternatives

- **RISK-001:** The program is large and the client program starts in Q4 2026. If
  time runs short, phases must be dropped from the end, not the middle, because
  each phase's dependencies point backwards. The minimum defensible subset is
  PHASE-01 through PHASE-03: the governance defect closed, the orchestrator
  declarative, and the scenario benchmark current. Mitigation: land each phase as
  its own commit with its own green gates, so stopping after any phase leaves the
  repository in a shippable state.
- **RISK-002:** Three number-moving changes are deferred to a single refreeze in
  PHASE-07. If PHASE-07 is not reached, the composite-score ranking defect and the
  misleading `trisk_priority_score` column continue to ship. Mitigation: if the
  program stops before PHASE-07, extract TASK-07-08, TASK-07-09 and TASK-07-12
  into their own small refreeze; they are independent of the delivery-format work
  in the same phase.
- **RISK-003:** The 2025 scenario vintage may not be sourceable from a primary
  document within the available time. Mitigation: ASM-002 makes the engineering
  work identical either way, and `SOURCE.md` plus a report banner make the
  provenance status unambiguous. Do not let the sourcing question block the
  mechanism.
- **RISK-004:** Adding columns to a TRISK input file could perturb TRISK outputs
  and break byte-identity in a phase that is supposed to be additive. Mitigation:
  RISK-05-02's fallback to a separate sidecar file, decided by running the gate
  immediately after the change and before any other work in that phase.
- **RISK-005:** Strict unknown-key config validation is a behaviour change that
  could break a config not visible in this repository (for example an operator's
  local client config). Mitigation: the error message must name the offending key
  and list the accepted sibling keys, so the fix is obvious from the message
  alone.
- **ALT-001:** Build the PCAF layer first and defer the seam work. Rejected: a
  PCAF step built against the current `if` ladder adds another branch and another
  undeclared dependency, and publishing an emissions inventory against 2023
  scenario vintages inherits the credibility problem at the worst possible moment.
- **ALT-002:** Ship the delivery-format work (PDF and bilingual labels) first as
  the fastest visible improvement. Rejected: it formats content that PHASE-03
  through PHASE-06 are about to change, so most of the work would be done twice.
  It is placed last rather than dropped.
- **ALT-003:** Fix the composite-score rounding and the column rename immediately
  in their own refreeze. Rejected: each refreeze costs a full re-verification, and
  the repository's batched-refreeze discipline has worked three times.
- **ALT-004:** Delete `scripts/generate_report.R` and the r2dii demo CSVs outright
  rather than retiring them to `attic/`. Rejected: `attic/README.md` already
  establishes the retirement convention, and the demo outputs document the
  methodology-convergence exercise.
- **ALT-005:** Optimize the intake validator's three row-wise passes and the
  name-matching step now. Rejected as speculative — PHASE-04 measures first. The
  row-wise passes may be entirely adequate at 10,000 rows, and optimizing before
  measuring risks changing byte-identical output for no gain.

## Suggested Next Step

Execute PHASE-01. It has no dependencies, every task is additive, and it closes a
live data-governance defect. Land it as one commit and confirm all six of its exit
criteria before beginning PHASE-02. Each subsequent phase's exit criteria are
verifiable before the next begins; do not start a phase whose dependency phase has
an unmet exit criterion.

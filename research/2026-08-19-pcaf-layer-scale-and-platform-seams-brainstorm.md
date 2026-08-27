---
title: "PCAF Layer, Real Scale, and the Seams That Make the Next Four Builds Cheap"
date: "2026-08-19"
type: "brainstorm"
depth: "standard"
source_request: "Unattended nightly analysis: what would take pacta-trisk to the next level, grounded in the repo at 6170ae2"
slug: "pcaf-layer-scale-and-platform-seams"
predecessor: "research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md"
---

# Brainstorm: PCAF Layer, Real Scale, and the Seams That Make the Next Four Builds Cheap

## Problem & Why Now

Wave 2 closed on 2026-08-08 (`7ce3dc8`, golden freeze 0.4.0, 404 R tests green) and
fixed the three defects that made client-facing output *wrong*: money on the wrong
scale, scores that were rank-relative tautologies, and an intake validator that
silently deleted exposure. The repository is now internally honest.

Two documents then arrived from the client side (`reports/2026-08-11-gtb-2026-drive-repo-readiness.html`),
and `research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md` queued the four
*commitment-shaped* workstreams that follow from them — SLL readiness screening, a
sector target registry, client-neutral report parameterization, and a workshop kit.
That brainstorm has not yet been turned into a plan; nothing in `plans/` is dated
August.

**This brainstorm deliberately does not re-litigate those four.** It covers what
they left on the table: the one structural decision they declared out of scope
(PCAF), and the platform-level facts a fresh read of the codebase turns up — the
things that are true about this repo regardless of which client signs first.

Why now: every one of the four queued workstreams adds a new pipeline step, a new
config key, and a new client-facing CSV. Whether that is cheap or expensive is
decided by seams that exist today, before any of them is built. And two of the
findings below are live defects in artifacts that already ship.

## Current vs Desired State

- **Current state.** One orchestrator (`scripts/run_engagement.R`) runs two
  engagements end to end. 404 R assertions across 123 `test_that` blocks; 58 Python
  tests; two acceptance gates (byte-identity, cross-artifact invariants) both wired
  into `ci.yml` on every push. Money is true VND; severity is anchored and absolute.
  The public demo is live at `pactavn.streamlit.app`.
- **What is not true yet.** The platform has never processed more than **43 loans**.
  It reports no emissions number, in a deliverable whose own Metrics & Targets
  section cross-references IFRS S2 financed emissions. Its borrower ranking cannot
  separate its own top three. It publishes a report built on r2dii's European demo
  portfolio into the public Vietnam snapshot. Adding a pipeline step means editing
  the orchestrator's `if` ladder.
- **Desired state.** A platform that (a) can state, with a benchmark behind it, what
  loanbook size it supports; (b) either owns the financed-emissions layer or says in
  one sentence why it does not; (c) produces rankings whose order is decided by
  methodology rather than by floating-point residue; (d) accepts a new pipeline step
  as a config entry rather than a source edit.
- **Key repo surfaces.**
  - Orchestration: `scripts/run_engagement.R` (`build_step_list()`, ln 95-190),
    `R/step_runner.R`, `R/engagement_config.R` (`.merge_config_lists`,
    `.validate_engagement_config`)
  - Scoring: `scripts/engagement_scoring.R` (ln 222-241),
    `R/severity_scoring.R`, `R/trisk_core.R:829` (`stress_priority_score`),
    `output/engagement/engagement_priority.csv`
  - Data model: `data/vietnam_abcd.csv` (174 rows, 14 cols),
    `data/vietnam_trisk_financial_features.csv`, `intake/SCHEMA.md`
  - Intake: `scripts/intake_validate_and_map.R` (three row-wise passes, ln 196/253/285)
  - Publication: `scripts/refresh_dashboard_data.R:73-81`,
    `dashboard/lib/loaders.py::report_catalog()`
  - Dependency truth: `DESCRIPTION`, `renv.lock`, `scripts/ci/install_deps.R`
  - Gates: `tools/verify_refactor.R`, `tests/testthat/test_golden_numbers.R`

## Findings (each verified against the tree at `6170ae2`)

### F-001 — The borrower ranking cannot separate its own top three

`output/engagement/engagement_priority.csv` has 23 borrowers and **14 distinct
`composite_score` values**. The top three — Nghi Son Power, Vinacomin Power,
International Power Mong Duong — are tied at exactly `0.9113849765258216`. Three
automotive borrowers tie at `0.7743710044722474`. Six renewables borrowers tie at
`0.29435...`.

The ties are structural, not coincidental: `severity_trisk` saturates at exactly
`1` for the three worst coal names and at exactly `0` for six borrowers with
positive `npv_change`, so the TRISK dimension is near-binary for 9 of the 17
TRISK-covered rows; and `alignment_gap` is *sector-level* for every automotive
(21.9497), cement (2.1) and steel (7.2) borrower, so within those sectors the
alignment dimension carries no borrower-level information at all.

This matters commercially: the BIDV MoU commits to "a shortlist of up to three
priority clients", and the tool's answer to "who are the top three" is currently
"these three are indistinguishable, and here they are in file order."

### F-002 — `composite_rank_pct` is decided by floating-point residue

`scripts/engagement_scoring.R:237` computes
`rank(composite_score, ties.method = "average") / n()` on raw doubles. Four
renewables borrowers carry `alignment_gap = 13.548387096774196` and two carry
`13.548387096774189` — a difference of about one ULP, from summation order. That
1e-14 difference propagates to `composite_score` (`...67744` vs `...6774`), `rank()`
sees two distinct values, and the six borrowers split into percentile `0.1957` and
percentile `0.0652`.

Two borrowers whose severity is identical to fifteen significant figures land
thirteen percentile points apart in a client deliverable. The fix is to round to a
documented precision before ranking — but `engagement_priority.csv` is a frozen
artifact under Law 5, so it must ride a refreeze rather than land alone.

### F-003 — A rank-relative column still ships in a client-facing CSV

Wave 2 PHASE-03 replaced min-max normalization in the *composite*, and
`R/trisk_core.R:829` carries an explicit comment that `stress_priority_score` is
"rank-relative ... legitimate ONLY as a dashboard sort key (ASM-004). ... do not feed
it into a composite score." It is not fed into the composite. It is, however,
copied verbatim into `engagement_priority.csv` as `trisk_priority_score`
(`scripts/engagement_scoring.R:111`).

In the shipped file, Hoa Phat Group scores 95 and Pomina scores 5 — a two-borrower
sector where those numbers mean "worse of two" and "better of two" and nothing
else. Same for VICEM (95) and Holcim (5). A client reading the CSV has no way to
know that column obeys different rules from the one beside it.

### F-004 — The public snapshot publishes a European demo portfolio

`dashboard/data/reports/PACTA_Alignment_Report.html` opens: "a PACTA alignment
analysis applied to a **demonstration** loan portfolio", 177 matched loan-company
pairs, target year 2025, four sectors. That is r2dii's bundled demo data, not MCB.
Its inputs are the 14 files tracked under `output/` since the first commit —
`output/01_loanbook_sample.csv` row 1 is "Vitale Group / Scholz KGaA / 225625 EUR
/ NACE D35.11". They are produced by `attic/pacta_demo.R` (do-not-touch) and
rendered by `scripts/generate_report.R` (561 lines, `output_dir <- "output"`,
invoked by no pipeline and no config).

Two further problems sit on the same code path:

- `scripts/refresh_dashboard_data.R:73-81` copies **8** reports into the public
  snapshot; `dashboard/lib/loaders.py::report_catalog()` has summary metadata for
  **4** and silently drops the rest (`if meta:`). Four published files are
  unreachable from the app that publishes them.
- That list was last edited in April. The BIDV Framework Recommendation Report, the
  Coverage & Reconciliation Report, and every Wave 0/1/2 report never reach the
  public demo. The live demo's Reports page is frozen at April 2026.

### F-005 — The platform has never been run above 43 loans

Largest loanbook anywhere in the repo: `data/fixtures/unseen_bank_loanbook.csv`,
**40 rows**. ABCD: 174 rows. Borrowers scored: 23. There is no benchmark, no
performance test, no documented supported size, and no statement in
`intake/SCHEMA.md` about how big a submission may be — in a repo whose entire
"Bring Your Own Loanbook" pitch is aimed at real Vietnamese commercial banks, which
carry corporate books in the 10,000–100,000 loan range.

Two specific hot spots are visible without running anything.
`scripts/intake_validate_and_map.R` makes three separate row-wise passes
(ln 196, 253, 285), each doing `row <- input_data[i, ]` — data-frame row subsetting,
the slowest way to walk a table in R — and accumulates one 1-row tibble per finding.
And `r2dii.match::match_name()` is fuzzy string matching, the classic quadratic
bottleneck, currently run against 23 counterparties.

I have **not** benchmarked this; the honest statement is that the limit is unknown,
which is itself the finding. It is also cheap to resolve: the repo already has a
synthetic loanbook generator.

### F-006 — Adding a pipeline step means editing the orchestrator

`build_step_list()` (`scripts/run_engagement.R:95-190`) is a hardcoded ladder of
`if (isTRUE(cfg$run_grid))` / `if (run_intake)` blocks. Every one of the four
queued workstreams adds a step; each will add another branch and another boolean
config key. Related gaps in the same seam:

- **Unknown config keys are silently ignored.** `.merge_config_lists()` copies any
  key from the JSON into the config; `.validate_engagement_config()` checks the keys
  it knows about and never rejects the ones it does not. A config with
  `"trisk_sector": ["power"]` (singular typo) validates clean and runs all three
  sectors. Lesson #5 in `lessons.md` is about exactly this family of bug.
- **No `schema_version`** on the config, so there is no way to evolve the schema
  and detect a stale config.
- **No `--only-step` / `--resume-from`.** Re-running letters after a template fix
  means re-running the chain or invoking the script by hand outside the orchestrator.
- **Step failures record a status, not a reason.** `run_step()` returns
  `list(name, status, seconds)`; the manifest carries no captured log or error
  excerpt, so a CI failure is diagnosable only from console scrollback.

### F-007 — Three dependency manifests, no cross-check

`DESCRIPTION` Imports lists 19 packages. `scripts/ci/install_deps.R` installs 25.
`renv.lock` records 24. **`trisk.model` — the single most load-bearing dependency
in the repository** (`library(trisk.model)` at `R/trisk_core.R:37`,
`trisk.model::run_trisk` at ln 868) — is absent from `DESCRIPTION` Imports, as are
`glue`, `magrittr`, `uuid` and `zoo`.

CI's "Verify pactatrisk package loads" step uses `devtools::load_all()`, which does
not check `Imports`; no `R CMD check` runs anywhere. This is precisely the class of
silent cross-artifact disagreement `tools/verify_refactor.R --invariants` was built
to catch, and it currently checks five rules, none of them about dependencies.

### F-008 — The methodological heart is covered end-to-end but barely unit-tested

`R/pacta_core.R` is 1,459 lines and has **2** `test_that` blocks
(`test_pacta_core.R`), covering ISIC-to-sector mapping and a coverage percentage.
`R/prioritization_core.R` is 439 lines with 3. `R/trisk_core.R` is 1,745 lines with
29 — a genuinely different standard. The alignment-gap math itself
(`pacta_market_share`, `pacta_sda`, `pacta_alignment_gaps`) is guarded only by the
six pinned values in `test_golden_numbers.R`, which tell you *that* a number moved,
never *which* step produced it. There is no coverage measurement and no linter
(`lintr`, `ruff`, pre-commit — none present).

### F-009 — The structural gap: no financed-emissions layer, in a pack that cites it

`templates/disclosure/disclosure_sections.md:47` cross-references "IFRS S2 paras
27–37 — cross-industry metrics, GHG emissions (including financed emissions,
Category 15)". The section body then reports alignment gaps and TRISK NPV/PD
changes, and calls its own targets "illustrative". The repo cites the metric its
clients are regulated on and substitutes a different one.

How far the data model actually is from PCAF, from `data/vietnam_abcd.csv`:

| PCAF input | Status in repo |
|---|---|
| Borrower outstanding amount | **Have** — true whole VND, post-Wave-2 |
| Borrower to sector/asset mapping | **Have** — intake sector map + `match_name()` |
| Emission factor, cement | **Have** — 12 rows, tCO2/tonne |
| Emission factor, steel | **Have** — 12 rows, tCO2/tonne |
| Emission factor, power | **Missing** — 96 power rows, all `emission_factor = NA` |
| Emission factor, automotive / coal | **Missing** — all NA |
| Physical activity for power | **Missing** — ABCD holds capacity (MW), not generation (MWh); needs capacity factors |
| Attribution denominator (EVIC, or total debt + equity) | **Missing entirely** — `vietnam_trisk_financial_features.csv` has `debt_equity_ratio` but no absolute capital |
| PCAF data-quality score (1–5) | **Missing** — no column, no concept |

So it is roughly a third built, and the missing third is enumerable: one
emission-factor table, one capacity-factor assumption set, one borrower-capital
column, one quality-score scheme.

## Resolved Decisions

Per the unattended-run rule, where a choice was open I adopted the option I would
have recommended and recorded it here.

- **DEC-001: Build the PCAF layer into the platform, as a thin and explicitly
  data-quality-scored Layer 1.** — Both client documents open there; the disclosure
  pack already cites the metric; and the intake contract, FX-at-intake conversion
  and sector map are the natural foundation. The alternative (keep it a spreadsheet
  deliverable feeding the repo) leaves the platform permanently unable to answer the
  first question either client asks.
- **DEC-002: Every financed-emissions figure carries a PCAF data-quality score
  1–5 as a first-class column, and no total is ever published without its
  quality-weighted composition.** — This is what makes a synthetic-anchored
  inventory honest rather than misleading, and it is the same discipline
  `composite_partial` and `validation_warnings.csv` already established.
- **DEC-003: PCAF lands as new downstream modules —
  `R/financed_emissions.R` + `scripts/generate_financed_emissions.R` — reading the
  normalized loanbook and ABCD, writing `financed_emissions.csv` and a
  `data_quality_summary.csv`.** It does **not** feed `composite_score`, the sector
  ranking, or any frozen artifact in its first iteration. — Purely additive; trips
  neither golden tests nor byte-identity, exactly as DEC-003 in the 2026-08-11
  brainstorm did for the SLL screen.
- **DEC-004: The new analytic worth building on top is carbon-cost exposure —
  financed emissions multiplied by the NGFS carbon-price paths already in
  `data/vietnam_trisk_ngfs_carbon_price_*.csv`, expressed in VND.** — This is the
  one number that bridges PACTA (who is misaligned), TRISK (what a shock does to
  NPV) and PCAF (how much CO2 the bank finances), and neither framework produces it
  alone. It is also the number a credit officer can act on.
- **DEC-005: Establish the supported-scale number empirically before the next
  client conversation.** Parameterize the synthetic generator by row count, time
  intake → match → PACTA → scoring at 1k / 10k / 50k loans, publish the curve in
  `docs/`, and state a supported size in `intake/SCHEMA.md`. — "We don't know" is
  the current answer to the most predictable question a bank IT team asks.
- **DEC-006: Fix F-004 (the demo-portfolio report) by making the published report
  set config-declared with a single title/date/summary sidecar, consumed by both the
  R writer and the Python catalog.** Drop the r2dii-demo reports from the public
  snapshot; retire `scripts/generate_report.R` and the `output/` demo CSVs to
  `attic/`. — Two hardcoded lists in two languages that must agree is the same
  duplication `supported_sectors` already needed an invariant for.
- **DEC-007: F-002 and F-003 ride the next golden refreeze together, not
  separately.** Round `composite_score` to a documented precision before ranking;
  rename `trisk_priority_score` to something that says what it is, or drop it from
  the client CSV. — The repo's refreeze discipline is one batched commit per wave,
  and it has now worked three times.
- **DEC-008: Make the step list declarative before the four queued workstreams
  land, not after.** A step registry keyed by name, with the config naming which
  steps run, replaces the `if` ladder; add strict unknown-key rejection and
  `schema_version` to the config at the same time. — Four workstreams times one
  branch and one boolean each is the cost of not doing this; the refactor is cheaper
  than the fourth branch.
- **DEC-009: Add a dependency-manifest-agreement invariant to
  `tools/verify_refactor.R --invariants`.** — The tool exists for exactly this, the
  rule is a dozen lines, and it closes a gap in which the most important dependency
  in the repo is undeclared.

## Assumptions & Constraints

- **ASM-001:** No real BIDV or Techcombank loanbook exists this cycle; everything
  is demonstrated on the synthetic MCB book. Unchanged from the predecessor.
- **ASM-002:** The four workstreams in `research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md`
  are still wanted and still unplanned. This brainstorm is complementary, not a
  replacement; where they overlap (both touch `engagement_priority.csv`), F-002/F-003
  should be folded into whichever refreeze that work triggers.
- **ASM-003:** Emission factors for Vietnamese power generation can be sourced or
  synthesized defensibly (grid EF, technology-level tCO2/MWh). For the synthetic
  demo they are generated, clearly labelled, and scored PCAF quality 4–5.
- **ASM-004:** Nobody has yet run the pipeline at scale, so the intake and matching
  hot spots in F-005 are *suspected*, not measured. The first task in that
  workstream is measurement, not optimization.
- **CON-001:** Law 5 — byte-identity of `synthesis_output/**`,
  `output/engagement/engagement_priority.csv` and the committed SDB outputs, gated
  in `ci.yml` on every push. Every proposal here is additive except F-002/F-003,
  which are explicitly deferred to a refreeze.
- **CON-002:** Law 4 — `test_golden_numbers.R` pins `composite_score[1] == 0.9113849765258216`,
  23 rows, and an anti-min-max guard. Rounding `composite_score` (F-002) moves that
  pin; the plan must re-pin it in the same commit.
- **CON-003:** Law 2 — VND is never rescaled. A financed-emissions attribution
  factor is a ratio of two VND quantities and is therefore unit-safe, but the
  denominator must be captured in whole VND like everything else.
- **CON-004:** Law 8 — no new pipeline dependencies. Financed-emissions arithmetic
  is `dplyr` and base R; nothing here needs a package outside `renv.lock`.
- **CON-005:** The dashboard reads only `dashboard/data`, and
  `public_snapshot_allowed` blocks other engagements from writing there by design.
  A PCAF layer for a client engagement is HTML/CSV delivery, not a dashboard view.
- **CON-006:** Synthetic-data disclaimers are mandatory everywhere. A financed-
  emissions total is the single most misquotable number this repo could produce, so
  its disclaimer requirement is stricter than the existing banner, not equal to it.

## Approaches Considered

- **Chosen: platform seams first (F-006, F-007, F-004), then scale measurement
  (F-005), then the PCAF layer (F-009), with the scoring fixes riding the next
  refreeze.** Each earlier item makes the later ones cheaper: a declarative step
  list is what a PCAF step plugs into, and a known scale limit is what makes a PCAF
  claim credible to a bank.
- **ALT-001: PCAF first, seams later.** Fastest path to the thing both clients ask
  for. Rejected because a PCAF step built against the current `if` ladder adds the
  fifth branch and the third undeclared dependency, and because publishing an
  emissions inventory whose scale limit is unknown is the worst possible place to
  discover it.
- **ALT-002: Decline PCAF; keep it a spreadsheet deliverable that feeds the repo.**
  Honest, cheap, and consistent with `docs/bidv_framework_comparison.md`, which
  classes PCAF as a prerequisite "already in place". Rejected because both new client
  documents scale that hand-built work up, and a platform that cannot compute the
  metric its own disclosure pack cites will keep re-encountering this decision.
- **ALT-003: Fix F-002/F-003 immediately in their own refreeze.** Rejected: the
  repo's batched-refreeze discipline exists because each refreeze costs a full
  re-verification, and the 2026-08-11 workstreams will trigger one anyway.
- **ALT-004: Optimize intake and matching now.** Rejected as speculative — measure
  first (DEC-005). The row-wise passes may be entirely adequate at 10k rows.
- **ALT-005: Delete `output/`, `compare/`, `scripts/generate_report.R` outright
  rather than retiring them to `attic/`.** Rejected: `attic/README.md` already
  establishes the retirement convention, and `compare/` documents the AI-vs-staff
  convergence exercise that justifies the methodology.

## Out of Scope

- The four commitment-shaped workstreams from the 2026-08-11 brainstorm (SLL
  readiness screen, target registry, report parameterization, workshop kit). Still
  wanted; still awaiting `/plan`.
- Real SDA convergence for cement and steel (DEC-007/DEC-010 there) and automotive
  TRISK — both already queued elsewhere.
- Any change to the MCB public snapshot's published *numbers* (as opposed to its
  published *report set*, which F-004 addresses).
- Multi-engagement dashboard viewing — blocked by CON-005 by design.
- The ABCD sourcing decision (`docs/abcd_sourcing_decision.md`), which remains open
  and is unblocked by everything here.
- Refreshing `plans/PROGRESS.md` (as-of 2026-03-21) and `activeContext.md`
  (last updated 2026-03-20, "Step 7 IN PROGRESS"). Both are five months stale and
  contradict `NEWS.md`, which is well maintained and is the real changelog. Worth a
  ten-minute pass, not a workstream.

## Open Questions

1. **Q-001: Does the PCAF layer compute Scope 1+2 only, or Scope 1+2+3 for the
   sectors where Scope 3 dominates (automotive, coal)?**
   - **Recommended default:** Scope 1+2 first, with the schema carrying a `scope`
     column from day one so Scope 3 is a populated row rather than a migration.
   - **Why this matters:** for a coal-mining or automotive borrower, Scope 3 is the
     overwhelming majority of financed emissions, so a Scope 1+2-only total
     understates exactly the sectors the bank cares most about — which must be
     stated, not discovered by the client.

2. **Q-002: What supplies the attribution denominator for unlisted Vietnamese
   borrowers, where EVIC does not exist?**
   - **Recommended default:** total debt + total equity from the borrower's own
     financial statements, PCAF data-quality score 3; fall back to a sector-median
     leverage assumption at quality score 5 where statements are unavailable. Add
     one `borrower_capital_vnd` column to the ABCD-adjacent inputs rather than
     widening the loanbook intake schema, which banks have already been given.
   - **Why this matters:** it decides whether the intake contract clients have
     already seen has to change, and it is the single largest driver of the
     data-quality profile of the whole inventory.

3. **Q-003: What is the scale target the platform commits to supporting?**
   - **Recommended default:** 50,000 loans and 5,000 distinct counterparties, on a
     laptop, in under 30 minutes for the full chain. Publish the measured curve
     regardless of whether the target is met.
   - **Why this matters:** it converts an unknown into either a specification or a
     known piece of work, and it is the number a bank's IT function will ask for
     before any pilot.

4. **Q-004: Does the declarative step registry keep backward compatibility with
   today's boolean config keys (`run_grid`, `run_outputs`, `run_refresh_audit`)?**
   - **Recommended default:** yes — translate them into the registry internally, so
     both existing configs keep working untouched and the byte-identity gate stays
     green through the refactor.
   - **Why this matters:** it determines whether the seam refactor is a
     no-observable-change change (verifiable by the existing gate) or a migration
     requiring both engagement configs to move at once.

5. **Q-005: Are the four April-era reports removed from the public snapshot, or
   kept and relabelled as methodology references?**
   - **Recommended default:** remove the two built on r2dii demo data
     (`PACTA_Alignment_Report`, `PACTA_Comparison_Report`); keep
     `PACTA_Synthesis_Report`, which is genuinely Vietnam-facing methodology
     guidance, and give it a catalog entry saying so.
   - **Why this matters:** the public demo is the sales surface, and a European
     demo portfolio sitting inside a Vietnam demo is the kind of detail a technical
     evaluator finds first.

## Suggested Next Step

Run `/plan pcaf-layer-scale-and-platform-seams` to turn this into a multi-phase
implementation plan, sequenced per DEC-008 → DEC-005 → DEC-001, with F-002/F-003
folded into whichever refreeze the 2026-08-11 workstreams trigger first.

---
title: "Wave 4: Deliverable Trust, Provenance Truth, and Scale Follow-Through"
date: "2026-09-01"
type: "brainstorm"
depth: "standard"
source_request: "Unattended analysis: what would take pacta-trisk to the next level, grounded in the repo at 503743f (post-Wave-3 0.5.0 refreeze)"
slug: "wave4-deliverable-trust-and-scale-followthrough"
predecessors:
  - "research/2026-08-26-wave3-convergence-vintage-and-delivery-readiness-brainstorm.md"
  - "research/2026-08-19-pcaf-layer-scale-and-platform-seams-brainstorm.md"
  - "research/2026-08-11_gtb-middle-tier-gap-closers-brainstorm.md"
---

# Brainstorm: Wave 4 — Deliverable Trust, Provenance Truth, and Scale Follow-Through

## Problem & Why Now

Wave 3 landed in full. I verified this independently before writing anything
here: all 81 tasks are implemented, `DESCRIPTION` is at `0.5.0`, the R suite is
`FAIL 0 | WARN 5 | SKIP 1 | PASS 552`, the Python suite is `63 passed`,
`Rscript tools/verify_refactor.R --invariants` returns `INVARIANTS PASS` for
INV-001..009, and the working tree is clean. The platform is in the best shape
it has ever been in.

That success is exactly what creates the next problem. Waves 0–3 built three
layers of verification — byte-identical CSVs, nine cross-artifact invariants,
and 552 unit tests — and pointed **all three at the numbers**. Meanwhile the
surface the client actually receives grew from a handful of reports to 71
tracked HTML artifacts, a bilingual label layer, a PDF path, engagement letters,
a disclosure pack, and a provenance manifest that the dashboard shows to bank
evaluators as a freshness badge.

Not one byte of that surface is gated. `classify_path()` in
`tools/verify_refactor.R:54` returns `"timestamp-class"` for **every** file
whose extension is `.html`, which means the acceptance gate ignores all of them
unconditionally. No test anywhere asserts the content of a generated report.

This is not theoretical. Three provenance defects are sitting in the committed
tree right now, and each one is invisible to all three verification layers:

- `reports/pipeline_refresh_audit.html` — the repo's own audit artifact —
  publishes the MD5 checksums of `data/scenarios/pdp8-2023/*.csv`, a scenario
  vintage the MCB pipeline **did not use**. It has run on
  `pdp8-2025-adjusted` since Wave 3 PHASE-03.
- That same audit report states `engagement_scoring failed`, while the
  `pipeline_manifest.json` committed beside it states every step is `ok`.
- Saigon Delta Bank's committed financed-emissions inventory labels all of its
  rows `data_source: "mcb-demo"` — another bank's identifier on a client
  deliverable.

The through-line is one sentence: **the repository can prove its numbers are
reproducible, and cannot prove its deliverables are true.** For a product whose
entire value proposition to BIDV and Techcombank is auditability, that is the
gap worth closing next.

There is also unfinished business Wave 3 explicitly deferred: `ALT-005` rejected
optimizing the intake validator as "speculative — PHASE-04 measures first."
PHASE-04 has now measured, and the measurement names that exact code. The
precondition has been satisfied.

## Current vs Desired State

- **Current state:** 0.5.0. Two engagements through one declarative orchestrator
  (16 steps for MCB, 15 for SDB). Three verification layers, all pointed at CSVs.
  71 tracked HTML artifacts with zero regression protection. A provenance chain
  (manifest → refresh audit → dashboard badge) with three demonstrable internal
  contradictions and no invariant tying it together. Twenty Wave 3 functions
  carry `#' @export` and appear in no `NAMESPACE`. Intake measured at 50k loans;
  fuzzy matching and the full analytical chain never measured at all.
- **Desired state:** A platform where a generated deliverable is a checkable
  artifact rather than an ignored one; where the provenance record cannot claim
  inputs the run did not read or a status the run did not have; where adding a
  fourth sector cannot silently produce a three-sector emissions inventory;
  where `library(pactatrisk)` exposes the API the package actually has; and
  where the published supported-loanbook size covers the whole pipeline rather
  than its first stage.
- **Key repo surfaces:** `tools/verify_refactor.R`;
  `scripts/generate_refresh_audit.R`; `scripts/run_engagement.R`;
  `R/step_runner.R`; `R/financed_emissions.R`; `R/target_setting.R`;
  `R/report_toolkit.R`; `scripts/intake_validate_and_map.R`; `NAMESPACE`;
  `man/`; `engagements/sdb-rehearsal/engagement_config.json`;
  `docs/scale_benchmark.md`; `plans/PROGRESS.md`; `CLAUDE.md`; `README.md`.

## Findings

New findings are `N-1xx` to avoid colliding with the Wave 3 series. Every
finding below was verified against the working tree in this session; the
command or file:line that establishes it is quoted inline. Where I initially
suspected a defect and testing disproved it, I say so rather than shipping the
suspicion (see N-113).

---

### N-101 — The acceptance gate ignores every HTML file by construction

`tools/verify_refactor.R:48-56`:

```r
classify_path <- function(path, volatile_basenames = VOLATILE_BASENAMES) {
  ext <- tolower(tools::file_ext(path))
  base <- basename(path)
  if (identical(ext, "png")) return("png-noise")
  if (identical(ext, "html") || base %in% TIMESTAMP_BASENAMES) {
    return("timestamp-class")
  }
  ...
```

Any changed `.html` is classified `timestamp-class` and never reaches `"drift"`.
The rationale in `CLAUDE.md` law 5 is sound as far as it goes — "HTML reports
may differ only in the generated-timestamp text" — but the rule is enforced by
assumption, not by checking. The classifier never looks inside the file.

`git ls-files "*.html" | wc -l` → **71**. That set includes every client-facing
deliverable: the engagement letters index, the disclosure pack, the coverage and
validation reports, the financed-emissions report, the SLL shortlist, the sector
target registry, and all eight reports published into the public snapshot.

And nothing else covers them. `grep -rln "synthetic\|disclaimer" tests/testthat/`
matches three files, none of which assert on a generated report's content; the
two matches in `test_sdb_engagement.R` are a header comment and a code comment
citing a report path. There is no assertion, anywhere in 552 R tests and 63
Python tests, that any generated HTML contains any particular number or phrase.

**Severity: high. Effort: medium.** This is the finding the rest of the section
depends on — N-102, N-103 and N-104 are all instances of it.

---

### N-102 — The refresh audit publishes checksums of a scenario vintage the pipeline did not use

`scripts/generate_refresh_audit.R:31-35` hardcodes its input list:

```r
input_files <- c(
  "data/vietnam_loanbook.csv",
  "data/vietnam_abcd.csv",
  "data/scenarios/pdp8-2023/vietnam_scenario_ms.csv",
  "data/scenarios/pdp8-2023/vietnam_scenario_co2.csv"
)
```

`engagements/mcb-demo/engagement_config.json` has pointed at
`data/scenarios/pdp8-2025-adjusted/` since Wave 3 PHASE-03. The audit therefore
attests to files the run never read. Verified directly:

```
recorded ms checksum : 1827b2776aa0df5f50b72ff866d54665
recorded co2 checksum: ce806a7c4cdfa4d835ff925759ab695e

7454bb5c...  data/scenarios/pdp8-2025-adjusted/vietnam_scenario_ms.csv
f3ff478f...  data/scenarios/pdp8-2025-adjusted/vietnam_scenario_co2.csv
1827b277...  data/scenarios/pdp8-2023/vietnam_scenario_ms.csv     <-- matches
ce806a7c...  data/scenarios/pdp8-2023/vietnam_scenario_co2.csv    <-- matches
```

The rendered `reports/pipeline_refresh_audit.html` prints those two `pdp8-2023`
rows under the heading "Input Checksums (MD5)" for a reader to trust.

The root cause is a violation of `CLAUDE.md` law 6. This is the only step in
`R/step_registry.R` whose `args_fn` is `function(cfg, ctx) character()` — it
receives no config at all — and it also hardcodes `dashboard/data/` and
`data/vietnam_loanbook.csv`, so running it under any non-public engagement would
audit MCB's snapshot rather than that engagement's.

Wave 3 PHASE-03 introduced the vintage mechanism and INV-009 to police it, but
INV-009 checks only that a vintage is *declared* in the config; nothing checks
that the artifacts *attest to the declared one*.

**Severity: high. Effort: low.** A `--config` flag and four
`cfg$inputs$...`-derived paths.

---

### N-103 — Two committed provenance artifacts contradict each other, and both are gate-invisible

`reports/pipeline_refresh_audit.html`, rendered, contains:

```
Step Timings
  sector_prioritization    ok      5.8s
  refresh_dashboard_data   ok      4.0s
  engagement_scoring       failed  2.7s
```

`dashboard/data/pipeline_manifest.json`, committed in the same commit
(`59f5cf2`), reports `"status": "ok"` for all 16 steps — and reports every one
of them as exactly `"seconds": 1`:

```
seconds: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1]
```

Uniform 1-second timings are not plausible for this pipeline. The same steps in
`engagements/sdb-rehearsal/pipeline_manifest.json` took
`[4.7, 2.3, 2.9, 24.1, 6.7, 28.8, 22, 22.9, ...]`, and the MCB manifest at the
previous commit `f69ceca` recorded `[12.7, 3.4, 16.1, 11.5, 11.6, ...]`. The
audit's own timings for shared steps (5.8 / 4.0 / 2.7) disagree with the
manifest's. The manifest's `git_sha` is `f69ceca` — the previous commit — and
`refresh_audit_metrics.json` is stamped 15:41 while the manifest is stamped
16:19, 38 minutes later, for a run the manifest claims took 16 seconds total.

I could not determine the exact invocation that produced this, and I am not
going to guess at one. What matters is structural: **no layer can detect it.**
`.html` is ignored (N-101) and `pipeline_manifest.json` is listed in
`TIMESTAMP_BASENAMES` (`verify_refactor.R:37-41`), so byte-identity ignores it
too. No invariant reads either file. The dashboard, meanwhile, renders
`manifest.get("git_sha")` and `manifest.get("status")` into the freshness badge
that a bank evaluator sees first (`dashboard/lib/branding.py:73-85`).

This is `lessons.md` §3 in a new costume: an artifact with no dependency on the
thing it claims to describe.

**Severity: high. Effort: low-to-medium.** Plausibility invariants are cheap;
the real fix is N-104.

---

### N-104 — A filtered run silently overwrites the full-run manifest, with no "partial" marker

`scripts/run_engagement.R` applies `--only-step` / `--resume-from` via
`filter_step_list()`, then calls `write_pipeline_manifest(step_results, ...)`
unconditionally at line 193. `step_results` contains only the steps that
actually executed.

So `--only-step refresh_audit` rewrites `dashboard/data/pipeline_manifest.json`
as a one-step manifest, destroying the full-run record, and nothing in the file
indicates the run was partial. `generate_refresh_audit.R` then reads that
manifest and renders whatever it finds as though it were a complete run. This is
the most likely mechanism behind N-103 and it is worth fixing on its own terms:
the two flags were added in Wave 3 PHASE-02 as a debugging convenience, and they
silently corrupt the provenance record as a side effect.

The manifest needs a `partial: true` field (plus the filter that produced it),
and `write_pipeline_manifest()` should refuse to overwrite a complete manifest
with a partial one unless asked to.

**Severity: medium-high. Effort: low.**

---

### N-105 — A client's financed-emissions inventory is stamped with another bank's identifier

`R/financed_emissions.R:115`:

```r
common <- list(
  name_abcd = name, sector = sector, scope = "1+2",
  outstanding_vnd = outstanding_vnd,
  borrower_capital_vnd = cap_row$borrower_capital_vnd,
  data_source = "mcb-demo"          # <-- hardcoded
)
```

Verified in the committed SDB fixture
(`engagements/sdb-rehearsal/output/financed_emissions/financed_emissions.csv`):

```
"EVN (Electricity of Vietnam)","power","1+2",4.2e+11,9.37625e+12,"mcb-demo",...
"Vinacomin Power JSC","power","1+2",9.1e+11,1401891891892,"mcb-demo",...
```

`grep -rn '"mcb-demo"' R/*.R scripts/*.R` shows this is the *only* hardcoded
provenance literal in an analytic — `R/prioritization_core.R` correctly threads
`data_source` through as a parameter in all four of its call sites. So this is a
one-line fix with a one-line test.

The reason it shipped: INV-003 exists precisely to catch "hardcoded provenance
leaking into a client deliverable," but its implementation
(`verify_refactor.R:248-272`) only ever opens
`cfg$paths$engagement_output_dir/engagement_priority.csv`. Wave 3 added three
new per-engagement CSV outputs and none of them inherited the guard.

**Severity: medium-high (client-facing mislabelling). Effort: trivial.**
Note this changes a committed SDB fixture — a scoped fixture refreeze, not a
golden refreeze, since `data_source` feeds no score.

---

### N-106 — Wave 3 re-introduced the exact sector-list drift INV-004 was built to prevent

INV-004 checks that the supported-sector list agrees across four named sites:
`R/sector_registry.R`, `R/engagement_config.R`, `R/trisk_core.R`,
`scripts/new_engagement.R`. Wave 3 added two more that it does not watch:

- `R/target_setting.R:73` — `sectors <- c("power", "cement", "steel")`
- `scripts/generate_financed_emissions.R:55` — `for (sector in c("power", "cement", "steel"))`

Both could call `sector_registry()`; neither does. Adding a fourth TRISK sector
would pass INV-004 and then silently produce a three-sector target registry and
a three-sector emissions inventory — a wrong answer that looks complete, which
is the worst failure shape for this product.

The deeper issue is that INV-004 hardcodes *its own* list of sites to check, so
it can only ever catch drift among the four places someone remembered to
register. A grep-based invariant that fails on *any* `c("power", "cement",
"steel")` literal outside `sector_registry.R` would be self-maintaining.

**Severity: medium. Effort: low.**

---

### N-107 — `NAMESPACE` and `man/` predate Wave 3 entirely; CI is structurally unable to notice

Twenty functions carry a roxygen `#' @export` and appear in no `NAMESPACE`
entry — every Wave 3 module, without exception:

```
attribution_factor            financed_emissions        report_label
borrower_emissions_intensity  history_diff              resolve_step_list
borrower_emissions_power      history_runs              sda_convergence_target
build_target_registry         load_report_labels        sll_readiness
carbon_cost_exposure          make_run_id               sll_readiness_band
data_quality_summary          pcaf_data_quality_score   sll_readiness_score
filter_step_list              record_run_history
```

`man/` holds 45 `.Rd` files and not one for a Wave 3 topic. In the other
direction, `pacta_market_share` is exported in `NAMESPACE` with no matching
`@export`ed definition.

So `library(pactatrisk)` exposes none of the PCAF layer, the target registry,
the SLL screen, the run history, or the i18n engine. The reason nobody noticed
is in `ci.yml:47-49`: the check is
`devtools::load_all('.')`, which loads every function in `R/` regardless of
`NAMESPACE` and therefore cannot fail this way. `R CMD check` would catch it in
one line and is not run.

**Severity: medium. Effort: low.** `roxygen2::roxygenise()` plus an
`R CMD check`-or-`NAMESPACE`-freshness step in CI.

---

### N-108 — The two least-tested modules in the repo are both Wave 3, and both are client-facing

Three `R/` modules have no dedicated test file. One (`sector_registry.R`) is
covered incidentally by `test_engagement_config.R:225`. The other two are not
covered at all:

- **`R/target_setting.R`** — `sda_convergence_target()` and
  `build_target_registry()`, the S6 specification. This computes the interim
  decarbonization targets a bank would propose to its board. Its sibling specs
  all got tests: S2/S3/S4 have `test_financed_emissions.R`, S5 has
  `test_sll_readiness.R`. S6 has nothing.
- **The i18n engine in `R/report_toolkit.R`** — `report_label()` and
  `load_report_labels()`, called from eight report generators. This is the code
  that decides whether a Vietnamese bank's deliverable says the right thing in
  Vietnamese. The override-merge path, the `bilingual` join, and the
  missing-token warn-once behaviour are all untested.

`grep -rln "sda_convergence_target\|build_target_registry\|report_label" tests/`
returns nothing.

**Severity: medium. Effort: low.** These are pure functions; they are the
cheapest tests in the repo to write.

---

### N-109 — The scale answer is one stage deep, and the promised measurement is missing

`docs/scale_benchmark.md` is admirably honest about its own limits, which makes
this easy to state precisely. From `docs/scale_benchmark.csv`, `match_seconds`
is `NA` for all 8 cells. The document says so directly:

> **`r2dii.match::match_name()` fuzzy-matching timing.** The benchmark harness
> attempted to time this directly but could not produce a reliable reading in
> this session (...) **Do not assume matching is cheap at 5,000 counterparties
> because intake was fast — this was not tested.**

So the one number the predecessor brainstorm's F-005 actually cared about — the
classic quadratic bottleneck — is still unknown, and the full PACTA + TRISK
chain and memory usage were never measured either. Wave 3's objective promised
"a measured and published supported loanbook size"; what shipped is a measured
and published *intake* size, correctly scoped in prose but easy to over-read.

**Severity: medium. Effort: medium.** The harness exists and appends rather than
overwrites, so extending the grid is additive.

---

### N-110 — Intake's hot spot is now measured, which retires `ALT-005`'s objection

Wave 3's `ALT-005` rejected optimizing the intake validator: *"Rejected as
speculative — PHASE-04 measures first. The row-wise passes may be entirely
adequate at 10,000 rows, and optimizing before measuring risks changing
byte-identical output for no gain."*

PHASE-04 measured. The result:

| Loans | Intake seconds |
|---:|---:|
| 1,000 | 3.8 |
| 10,000 | 18.0–19.6 |
| 50,000 | 101.6–230.3 |

and the document names the cause: three separate row-wise passes over the
loanbook at `scripts/intake_validate_and_map.R:196, 253, 285`. The specific
anti-pattern is the first line of each loop body:

```r
for (i in seq_len(n_total)) {
  row <- input_data[i, ]        # single-row tibble slice, n times
```

Every check in that first pass — empty name, non-numeric or negative exposure
and credit limit, `sector_code_system` membership, `sector_code` format — is
elementwise and vectorizes directly. The second and third passes likewise.

The remaining `ALT-005` concern (risk to byte-identical output) is real and
handled by the existing gates: the SDB intake fixture is committed, the
`sdb-engagement` CI job regenerates it end to end, and error *ordering* in
`validation_errors.csv` must be preserved. That makes this a measurable,
verifiable optimization rather than a speculative one.

**Severity: medium. Effort: medium.** The evidence bar `ALT-005` set has been
met; this is the one performance item that should now proceed.

---

### N-111 — The second engagement is not a parity rehearsal, so CI's end-to-end run misses a third of Wave 3

`engagements/sdb-rehearsal/engagement_config.json` omits `run_targets`,
`run_history`, `report_language` and `published_reports`, and still points at
`data/scenarios/pdp8-2023/` with a flat `region_isos_csv:
data/vietnam_region_isos.csv` rather than a vintage-directory path.

`ci.yml`'s `sdb-engagement` job is the only job that runs the orchestrator
end to end against a second bank and asserts no cross-contamination. Because the
config omits those flags, that job never exercises the target registry, run
history, or bilingual rendering for a second engagement. Those paths are
exercised for MCB via the `byte-identity` job, so this is a rehearsal-fidelity
gap rather than a total blind spot — but "the second bank works" is the claim
the SDB engagement exists to support, and it currently supports a weaker version
of that claim than it appears to.

This is `lessons.md` §4 one level up: the fixture is regenerated, but the
regenerated fixture doesn't cover the feature set.

**Severity: medium. Effort: low.**

---

### N-112 — Wave 3's analytics reach the dashboard as pictures, not data

`dashboard/lib/loaders.py` has loaders for PACTA tables, TRISK sector tables,
the scenario grid, and the report catalog. It has none for financed emissions,
the target registry, SLL readiness, or run history. `dashboard/data/` contains
`pacta/`, `trisk/` and `reports/` — the three Wave 3 analytics appear only as
`Financed_Emissions.html`, `SLL_Readiness_Shortlist.html` and
`Sector_Target_Registry.html` under `reports/`.

So a bank evaluator can filter, sort and drill into PACTA and TRISK, and can
only scroll a static page for the PCAF inventory that Wave 3 built as its
flagship deliverable — the one the BIDV MoU names first. The underlying CSVs
exist (`output/financed_emissions/*.csv`, `output/engagement/target_registry.csv`);
they are simply never copied into the snapshot.

This is the highest-visibility, lowest-risk *feature* item in this document: it
adds nothing to the analytical surface and makes the existing one legible.

**Severity: medium (commercial). Effort: medium.**

---

### N-113 — Two suspected latent bugs that are not bugs

Recorded so a future session does not re-open them. I suspected, from reading:

1. `attribution_factor()` (`R/financed_emissions.R:33`) would error on an `NA`
   `capital_vnd`, because `ratio[capital_vnd == 0] <- NA_real_` indexes with an
   `NA` logical subscript.
2. `sda_convergence_target()` (`R/target_setting.R:34`) would error on a
   zero-length `baseline_value`, because `is.na(numeric(0)) || ...` evaluates a
   zero-length condition.

Both were tested directly under R 4.5.2 and **neither reproduces**:

```
--- attribution_factor with NA capital ---      [1] 0.001    NA
--- sda_convergence_target zero-length baseline --- [1] NA
--- attribution_factor with capital 0 and NA mixed --- [1] NA NA 0.001
```

Both functions return `NA` cleanly. Reading alone would have shipped two false
findings; they are listed here as verified non-issues.

---

### N-114 — Documentation drift accumulated across the refreeze

Individually trivial, collectively the reason a fresh session mis-reads the repo:

- **`CLAUDE.md` law 4** pins the golden as ``composite_score[1]` == 1.0`. The
  0.5.0 refreeze moved it to `0.9816483381` (confirmed in both
  `output/engagement/engagement_priority.csv` and
  `tests/testthat/test_golden_numbers.R:19`). The repo's own law now quotes a
  number the repo's own test contradicts.
- **`plans/PROGRESS.md`** — rewritten by Wave 3 PHASE-01 to be the status
  pointer — says "Waves 0, 1 and 2 are complete. The platform is at version
  0.4.1 (...) six cross-artifact invariants." Actual: Wave 3 complete, 0.5.0,
  nine invariants. It went stale within the same wave that rewrote it.
- **`README.md`'s repository map** omits `history/`, `workshop/`, `tools/`,
  `templates/`, `output/`, `compare/` and `present/`, and still describes
  `pipeline_refresh.R` as the orchestrator rather than a wrapper over
  `run_engagement.R`.
- **`dashboard/app.py:19`** says "Work through the five steps below" above six
  `st.page_link` calls.
- **`compare/`** is referenced only from superseded plans and brainstorms —
  nothing in `scripts/`, `R/`, `dashboard/` or `docs/` reads it. It is the one
  top-level directory that fits `attic/`'s stated convention and is not in it.

**Severity: low. Effort: low.** Worth folding into whichever phase touches each
file rather than doing as a batch.

---

### N-115 — Small code-level notes

- **`R/step_runner.R:31,53`** — the comment claims step output stays live on the
  console "via `stdout = \"\"`", but the code passes `stdout = log_path,
  stderr = log_path` and echoes the log only after the step returns. Output is
  correct but no longer streaming, so a 25-second TRISK step now looks hung. The
  comment asserts the opposite of the behaviour.
- **`R/step_runner.R:86-89`** — `run_steps()` prints `"[FAILED] ... Stopping
  pipeline."` before testing `stop_on_failure`, so it announces a stop it is not
  going to make.
- **`R/report_toolkit.R:96-110`** — `load_report_labels()` reads the base CSV
  with `read.csv()` *before* computing its cache key and checking the cache, so
  the cache never avoids the disk read it exists to avoid.
- **Report-generator duplication** — 12 scripts hand-build HTML and 7 carry
  independent `<style>` blocks. A shared report shell is attractive but should
  **not** be attempted before N-101: with HTML ungated, such a refactor is
  unverifiable by construction.

## Resolved Decisions

Adopted here without asking, per the unattended-analysis brief. Each is the
option I would have recommended.

- **DEC-001 — Gate HTML by normalized content, not byte-identity.** Reports
  embed base64 PNGs and a generated timestamp, so full-file hashing would be
  brittle and noisy. Instead: strip the known timestamp/`git_sha` spans, hash the
  remainder, and pin a small set of content assertions per deliverable (the
  synthetic-data disclaimer is present; named headline figures match the CSV
  they came from). This gives N-101 a real gate without making every legitimate
  edit a refreeze.
- **DEC-002 — Fix `data_source` (N-105) as a scoped fixture refreeze, not a
  golden refreeze.** `data_source` feeds no score and no ranking; the change is
  confined to a provenance column in one committed SDB CSV. Batching it behind a
  full golden refreeze would delay a client-facing mislabelling for no benefit.
- **DEC-003 — Make INV-004 self-maintaining rather than adding two more
  registered sites.** Registering `target_setting.R` and
  `generate_financed_emissions.R` fixes today's instance and leaves tomorrow's
  to memory. A grep-based invariant that fails on any hardcoded sector triple
  outside `sector_registry.R` fixes the class.
- **DEC-004 — Vectorize the intake validator (N-110), and do not touch
  `match_name()` yet.** The intake passes are measured, named, and covered by a
  regenerating CI fixture. Fuzzy matching is unmeasured (N-109); measure it in
  the same wave, optimize it in the next one if the number warrants.
- **DEC-005 — Bring SDB to feature parity rather than adding a third
  engagement.** A third engagement multiplies fixtures; parity on the existing
  one costs four config keys and makes the CI job mean what it appears to mean.
- **DEC-006 — Regenerate `NAMESPACE` with roxygen and add `R CMD check` to CI,
  rather than hand-editing `NAMESPACE`.** The file's own first line says
  "Generated by roxygen2: do not edit by hand," and hand-editing would drift
  again at the next wave.

## Assumptions & Constraints

- **ASM-001:** Wave 3 is genuinely complete — verified this session via green
  suites, passing invariants, a clean tree, and artifact-level spot checks — so
  this is new work rather than a re-plan. The plan file's status was set to
  `complete` in commit `503743f`.
- **ASM-002:** I did **not** run the full byte-identity gate
  (`Rscript tools/verify_refactor.R` without `--skip-refresh`), because it
  re-runs the pipeline and writes into the repository, which was outside an
  analysis brief. Only the read-only `--invariants` mode was run. Any plan
  derived from this document should run the full gate before and after its first
  code change.
- **ASM-003:** The cause of the uniform-1-second manifest (N-103) is
  undetermined. The recommendations target the *mechanism* — no partial marker,
  no plausibility check, no gate coverage — not the specific incident. If a plan
  wants the incident explained, regenerating the MCB snapshot and diffing the
  manifest is the cheapest experiment.
- **ASM-004:** Fixing N-102 changes `reports/pipeline_refresh_audit.html` and
  `reports/refresh_audit_metrics.json` (different checksums, correct ones). Both
  are auto-committed weekly by `refresh.yml` and both are currently gate-invisible,
  so this lands cleanly — but it should land *after* DEC-001's HTML gate exists,
  or the fix cannot be verified.
- **ASM-005:** `docs/abcd_sourcing_decision.md` stays open. It is a procurement
  decision, not an engineering one. Note the adjacent engineering fact, which is
  better than I first assumed: ABCD *is* schema-validated, by
  `validate_abcd_schema()` (`R/trisk_core.R:53`, called at `:513` with the
  configured `cfg$inputs$abcd_csv`, tested at `test_trisk_core.R:169-220`).
  What is missing is only the intake-style *client-facing* path — a pre-flight
  validation report and errors CSV — rather than validation itself.
- **CON-001:** `renv.lock` is pinned and law 8 forbids casual dependencies.
  Every item above is implementable with the existing stack; none needs a new
  package.
- **CON-002:** The synthetic-data disclaimer must survive every change. N-101's
  gate is the first mechanism that would actually enforce this rather than
  trusting it — all eight published reports carry it today (verified by grep),
  so the gate would lock in a currently-true property.

## Approaches Considered

- **APP-001 (recommended) — "Make the deliverable as trustworthy as the
  number."** Sequence: provenance truth (N-102, N-103, N-104, N-105) → extend
  the gate to deliverables (N-101) → close invariant drift (N-106) → package and
  test hygiene (N-107, N-108) → scale follow-through (N-109, N-110) → parity and
  surfacing (N-111, N-112), folding N-114/N-115 into whichever phase touches each
  file. Rationale: the provenance fixes are small and severe, and each phase's
  output is verifiable by the phase before it. One caveat on ordering — the
  N-102 fix changes audit HTML, so DEC-001's gate should land first or in the
  same phase.
- **APP-002 — Lead with the dashboard surfacing (N-112).** The most visible
  improvement for the Q4 client program, and commercially tempting. Rejected as
  the *lead*: publishing the PCAF inventory more prominently while its
  provenance chain contradicts itself increases exposure rather than reducing
  it. It belongs in the same wave, at the end.
- **APP-003 — Lead with performance (N-109, N-110).** Rejected: nothing in the
  two live client scopes is blocked on 50k-row throughput today, and the
  correctness findings are cheaper and more severe. `ALT-005`'s evidence bar is
  met, which earns this a place in the wave, not the front of it.
- **APP-004 — A report-shell refactor to kill the 7-way CSS duplication.**
  Rejected for this wave, on its own merits: it is the single largest
  unverifiable change available in the repo right now. Revisit once N-101 makes
  HTML checkable — at which point it becomes routine.

## Out of Scope

- The ABCD sourcing decision (`docs/abcd_sourcing_decision.md`) — procurement,
  not engineering.
- Multi-engagement viewing in Streamlit — still blocked by design; the app reads
  only `dashboard/data`.
- Full narrative translation into Vietnamese — labels and disclaimers only, as
  established in Wave 3.
- Refactoring `R/pacta_core.R` (1,474 lines) or `R/trisk_core.R` (1,745 lines)
  for their own sake.
- Migrating off Streamlit.
- Optimizing `r2dii.match::match_name()` — measure it this wave (N-109), decide
  next wave (DEC-004).

## Open Questions

Recorded, not blocking; each has a stated default so a plan can proceed.

- **OQ-001:** Should the HTML gate hash normalized content, or only assert a
  pinned set of facts per report? *Default: both — hash for change detection,
  assertions for the disclaimer and headline figures.*
- **OQ-002:** Should `write_pipeline_manifest()` hard-refuse to overwrite a
  complete manifest with a partial one, or write it with `partial: true` and
  warn? *Default: write with `partial: true` and refuse only when the target
  is the public snapshot.*
- **OQ-003:** Does the `pdp8-2023` vintage directory need a retrofitted
  `SOURCE.md` and `region_isos.csv` for symmetry with `pdp8-2025-adjusted`?
  *Default: yes for `SOURCE.md` (provenance for the vintage SDB still runs on),
  no for `region_isos.csv` (INV-002 forbids a byte-identical twin of
  `data/vietnam_region_isos.csv`, so it would have to differ for no reason).*
- **OQ-004:** How many history runs should `history/` retain before pruning? Two
  exist today; the regulatory use case is annual comparison. *Default: no
  pruning this wave — revisit past ~20 runs.*

## Suggested Next Step

Run `/plan wave4-deliverable-trust-and-scale-followthrough` against this
document, sequenced as APP-001.

Land N-102 and N-105 first — each is a handful of lines, each fixes a
demonstrably wrong statement in a committed client-facing artifact, and neither
needs a refreeze of any golden number. They are the smallest possible proof that
this wave is worth running.

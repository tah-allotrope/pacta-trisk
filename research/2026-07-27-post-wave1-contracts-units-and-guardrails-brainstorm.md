---
title: "Brainstorm: Post-Wave-1 — Units of Measure, Broken Contracts, and the Unguarded Write Path"
date: "2026-07-27"
status: "final"
mode: "unattended (no questions asked; assumptions recorded in the Assumptions section)"
supersedes-in-part: "research/2026-07-25-post-wave0-platform-hardening-brainstorm.md (its Wave 1 is now fully executed and verified; its Waves 2-4 backlog is re-prioritized below)"
plan_inputs:
  - "plans/2026-07-25-wave1-consistency-and-orchestrator-convergence-plan.md (complete, commits a629593 / fb56221 / ab9729b / 9e530dd / ccb6cb1 / d169901)"
---

# Brainstorm: Post-Wave-1 Platform Hardening

## TL;DR

**Wave 1 landed and holds up under fresh verification.** Every claim in
`NEWS.md` 0.3.0 that I could check, I checked this session — not inherited from
the prior brainstorm (see "Verified current state"). The scenario grid now
agrees with the base TRISK run, `--invariants` is real and wired into both
workflows, `pipeline_refresh.R` is a genuine 42-line wrapper, and the SDB CI job
actually executes the orchestrator.

Wave 1 closed the blind spot "does committed artifact A agree with committed
artifact B?" This pass finds the next one, one layer out, and it has two halves:

1. **Does the code agree with its own written contract?** It does not, in two
   places that sit directly on the path to the first paid pilot. `intake/SCHEMA.md`
   promises to accept USD exposure and to *classify* out-of-scope sector codes;
   `scripts/intake_validate_and_map.R` treats both as hard errors and **deletes
   the rows**. A real Vietnamese bank's loanbook coded to VSIC 2018 loses most of
   its power exposure on ingestion, silently.

2. **Does anything guard the artifact the public actually sees?** No. CI never
   runs the MCB pipeline and never runs byte-identity — despite `CLAUDE.md` law
   #5 stating "Both checks run in CI on every push." The only process that runs
   MCB end-to-end is the Monday `refresh.yml` job, which `git add`s
   `dashboard/data synthesis_output` and pushes, gated by six pinned golden
   numbers and no drift check.

And underneath both: **a unit-of-measure defect that spans the data, the code,
and every client-facing artifact.** The MCB loanbook is denominated in
*millions of VND* while its own `loan_size_outstanding_currency` column says
`VND`; the SDB fixture is in true VND. Same column, same code path, same label,
**281,000× apart**. This is the root cause of the "implausible money" symptom
the last brainstorm filed under credibility (M6) — it is not a taste question,
it is a units bug with documentary proof.

**Recommended next move:** **Wave 2 — "Contracts & Units"**: fix the unit
scale, fix the intake contract, add the CI drift gate, and fold the
absolute-scoring change (M1) into the same single golden refreeze. Analytics
(traffic-light, exec summary) moves behind it, again — for the same reason as
last time, one layer up: a traffic-light matrix built on rank-normalized scores
where the top sector is *always* exactly 1.0 is a chart that cannot be wrong,
and therefore cannot be informative.

---

## Verified current state (2026-07-27)

Checked directly this session, from a clean tree at `42b4406`:

| Fact | Evidence |
|---|---|
| R suite green | `testthat::test_dir('tests/testthat')` → `[ FAIL 0 \| WARN 4 \| SKIP 1 \| PASS 276 ]` (up from 203) |
| Python suite green | `python -m pytest dashboard/tests -q` → `58 passed in 30.90s` |
| Invariants green | `Rscript tools/verify_refactor.R --invariants` → `INV-001..005 [PASS]`, `INVARIANTS PASS` |
| Working tree clean | `git status --porcelain` → empty |
| Package at 0.3.0 | `DESCRIPTION`, `NEWS.md`, 26 `@export`s in `NAMESPACE` |
| Wave 1 C1 genuinely fixed | `grid_meta.json` carries `grid_contract_version: v2` + `input_fingerprint: 57600f19…`; INV-001 compares 243-cell grid base cell to `company_summary.csv` at 1e-6 and passes |
| Wave 1 A1 genuinely fixed | `scripts/pipeline_refresh.R` is 42 lines, pure `system2()` delegation to `run_engagement.R --config engagements/mcb-demo/…` |
| Wave 1 C3 genuinely fixed | `ci.yml` job `sdb-engagement` runs `run_engagement.R` for SDB, then `RUN_SDB_ENGAGEMENT=1` golden tests, then a cross-contamination assert |
| Wave 1 P5 shipped early | `5_Scenario_Builder.py:103-163` round-trips all five levers through `st.query_params` |
| Wave 1 H1/H3 shipped | `lessons.md` exists with 5 entries; `test_loaders.py:69` now derives from `grid_meta.json` |

The Wave-1 work is real. Everything below is what the *next* verification layer
would have caught.

---

## U — Units of measure (new; the root cause behind last pass's M6)

### U1 — The MCB loanbook is in millions of VND and says it is in VND 🔴

Three independent statements of the same quantity, all in this repo:

| Source | Claim |
|---|---|
| `plans/vietnam_bank_pacta_scenario_plan.md:163` (design intent) | "Climate-relevant loan portfolio: ~25,000 billion VND" |
| `plans/PROGRESS.md:14` and `present/build_deck_v2.py:210` (**the live pitch deck**) | "43 loans, ~25 trillion VND (~$1B USD)" |
| `data/vietnam_loanbook.csv` (the actual data) | `sum(loan_size_outstanding)` = **25,020,000**, `loan_size_outstanding_currency` = `VND` |

25,020,000 VND is about **USD 950**. The deck a prospect is shown claims a
USD 1B book; the pipeline computes on a USD 950 book.

**The code knows.** `scripts/generate_vietnam_data.R:196` and `:715`:

```r
cat(sprintf("  Loanbook: %d rows | Total: %s bn VND\n",
            nrow(vietnam_loanbook),
            format(sum(vietnam_loanbook$loan_size_outstanding) / 1000, ...)))
...
total_bn_vnd   = sum(loan_size_outstanding) / 1000,
```

Dividing by 1,000 to obtain "billion VND" is only correct if the column is
denominated in **millions of VND**. So the generator's authors intended
millions, the CSV's currency column says VND, and nothing reconciles them.

**And a second engagement is on the other scale.** From the two committed
`sector_priority_ranking.csv` files — same column, same generator, same label:

| Sector | MCB `exposure_vnd` | SDB `exposure_vnd` | Ratio |
|---|---:|---:|---:|
| power | 15,770,000 | 4,435,000,000,000 | 281,000× |
| cement | 2,000,000 | 960,000,000,000 | 480,000× |
| steel | 1,500,000 | 2,050,000,000,000 | 1,366,000× |

`data/fixtures/unseen_bank_loanbook.csv` totals 22,375,000,000,000 VND
(≈ USD 850M) — a realistic mid-size Vietnamese bank book. The MCB demo is the
outlier, and it is the one on the public URL.

**The mislabeling has already propagated into generated and committed prose.**
`synthesis_output/prioritization/interpretation_notes.md:4` — "43 loans,
~19.3 billion VND Decision 263 exposure"; the actual figure under the literal
`VND` reading is 19,300,000 (19.3 *million*). Same error in
`reports/BIDV_Framework_Recommendation_Report_README.md:13` and
`docs/bidv_sector_prioritization_methodology.md:222`. Meanwhile
`scripts/generate_engagement_letters.R:143` prints the raw number with the
hedge `"%s VND (synthetic units)"` — which is neither correct nor a unit.

**On `CLAUDE.md` law #2.** The law says "VND is never rescaled" and cites the
range "1e5–5e12" as if it described one scale. It does not: `1e5` is MCB's
millions-denominated floor and `5e12` is SDB's true-VND ceiling. The law is
sound about *not mangling money in transit*; it has been read as forbidding a
fix to *what the generator emits*, which is a different decision. (Same reading
as last pass's ASM-8, now with the documentary evidence that closes it.)

**Fix (recommended):** rescale `generate_vietnam_data.R`'s loan literals by
1e6 so MCB is in true VND like SDB, delete the `/1000` display hacks in favor
of an explicit formatter, and add **INV-006**: for every engagement, the
loanbook's declared currency must be consistent with a plausible magnitude
band (e.g. a VND book's median loan ≥ 1e8), and every artifact reporting a
money figure must route through one shared formatter. Cost: one batched golden
refreeze. Payoff: every number in every deliverable becomes defensible, and the
deck stops contradicting the pipeline.

### U2 — There is no unit contract at all 🟠

`intake/SCHEMA.md` names `exposure_vnd` and `currency` but never states the
*denomination* (units vs thousands vs millions). Neither does
`pilot/loanbook_data_spec.md`, the document actually sent to a prospect. A
bank submitting a treasury extract in "triệu đồng" (millions of dong — the
default unit in most Vietnamese bank MIS reports) would be off by 1e6 with
nothing to catch it, and the pipeline would happily produce a full deliverable.
Given U1 shows *this repo* already made exactly that mistake internally, the
odds a client makes it are high. Add a required `exposure_unit` field
(`VND` / `thousand_VND` / `million_VND`) with explicit normalization at intake.

---

## I — The intake contract is broken where it matters most (new)

`scripts/intake_validate_and_map.R` is the artifact that converts a prospect
into a pilot ("send us your loanbook"). It disagrees with its own published
contract in two ways, and both **silently delete exposure**.

### I1 — Real Vietnamese power sector codes are rejected as out of scope 🔴

`intake_validate_and_map.R:137` — the entire accepted universe:

```r
known_isic <- c("3511", "2910", "2394", "2410", "0510", "0610")
```

Six exact 4-digit codes. But ISIC Rev.4 class **`3510`** ("Electric power
generation, transmission and distribution") is the standard 4-digit class for
electricity; `3511` exists only in national sub-class extensions. VSIC 2018
uses 5-digit `35101` / `35102` / `35103`, which `normalize_sector_code()`
zero-pads to 4 and then fails to match anyway.

**This is not hypothetical — the repo's own rehearsal fixture demonstrates it.**
`engagements/sdb-rehearsal/intake/validation_summary.txt`:

```
Total rows processed:     40
Rows passing validation:  23
Rows with errors:         17
...
--- Unresolved ISIC Codes (not in PACTA scope) ---
 original_code normalized_code
         D3510            3510      (× 7)
```

Seven power-sector rows dropped for using the *correct* ISIC class. 42% of the
submitted fixture rejected. The engagement then proceeded and produced a
complete-looking deliverable over the surviving 58%.

### I2 — `SCHEMA.md` promises USD is accepted; the code deletes USD rows 🔴

`intake/SCHEMA.md:23` — `| currency | string | Currency of exposure (VND or USD) | VND |`.

`intake_validate_and_map.R:130-134`:

```r
if (!is.na(cur) && cur != "" && cur != "VND") {
  add_error(i, "currency", sprintf("currency '%s' must be VND for PACTA processing", cur))
}
```

Errored rows are excluded from `normalized_loanbook.csv`. There is no FX
conversion path anywhere in the repo. USD-denominated lending is routine in
Vietnamese commercial banks (project finance, BOT power, trade facilities) —
this is a material, not marginal, deletion.

### I3 — `SCHEMA.md` says "classified as not in scope"; the code says "error" 🟠

`SCHEMA.md:51` — "Codes outside the known ISIC→PACTA mapping are classified as
'not in scope'." That describes a *label on a retained row*. The implementation
raises an error and drops the row. The distinction is the whole difference
between "here is your coverage report" and "here is a smaller book than you
sent us."

### I4 — Nothing reconciles submitted exposure against processed exposure 🔴

This is the through-line of I1–I3 and the single highest-value new build. There
is no artifact anywhere that says:

> You submitted N rows / X VND. We processed M rows / Y VND. Here is the
> Z VND (P%) we could not process, itemized by reason, and here is the
> ABCD coverage of what we did process.

`validation_summary.txt` counts *rows*, never *money*, and is gitignored
(`engagements/*/intake/*`), so it is not even a durable engagement artifact —
the committed SDB summary currently says "23 rows passing" while the committed
`normalized_loanbook.csv` has 24, because the summary is a stale local leftover
from a prior run.

**Fix:** demote unmappable-sector and non-VND from row-dropping errors to
retained-with-warning classifications; add FX at intake (a
`fx_rate_usd_vnd` config key, applied once, recorded in the manifest); build a
**Coverage & Reconciliation report** as a first-class tracked engagement
artifact denominated in money, not rows. This is the D1 idea from last pass,
but the evidence now shows it is not a nice-to-have for real data — the current
behavior would produce a *wrong* deliverable for a real bank, not a partial one.

---

## G — Guard rails on the public artifact (new)

### G1 — `CLAUDE.md` law #5 states something CI does not do 🔴

Law #5: *"Both checks run in CI on every push."*

```
$ grep -rn "verify_refactor" .github/
.github/workflows/ci.yml:57:        run: Rscript tools/verify_refactor.R --invariants
.github/workflows/refresh.yml:42:   run: Rscript tools/verify_refactor.R --invariants
```

Only `--invariants` runs. **Byte-identity has never run in CI**, and no CI job
executes the MCB pipeline at all — `ci.yml`'s three jobs are Python tests, R
tests, and the *SDB* engagement. The tool that Wave 0 built as the acceptance
bar is a local-only ritual.

### G2 — The weekly refresh is an unguarded write path to the public snapshot 🔴

`refresh.yml` runs `pipeline_refresh.R`, runs the test suite, then:

```yaml
git add dashboard/data synthesis_output reports/pipeline_refresh_audit.html reports/refresh_audit_metrics.json
git commit -m "chore: automated pipeline refresh $(date -u +%Y-%m-%d)" && git push
```

The only numeric gate between a regression and the public demo is
`test_golden_numbers.R`, which pins **six values** (`nrow == 23`, three
borrower names, three composite scores). Everything else — every PACTA
trajectory, every NPV, every PD, the entire 243-cell grid — is committed
unreviewed. A change in `trisk.model`'s RSPM build, or a scenario data edit,
silently republishes different numbers under the same synthetic-bank story.

This is *structurally* the Wave-1 lesson repeating in the time dimension: Wave 1
fixed "artifact A vs artifact B at rest"; nothing checks "the artifact this
week vs the artifact last week" on the one process authorized to overwrite it.

**Fix (cheap, high leverage):** add `Rscript tools/verify_refactor.R` (byte
identity, no `--full`) as a CI job on push, and as a *gate* in `refresh.yml`
before the `git add`. The committed `pipeline_manifest.json` shows the full MCB
chain runs in **107 seconds** with the grid cached, so this is ~3-4 CI minutes
on top of renv restore. When drift *is* intended, the job's failure is the
prompt to review the diff — which is exactly what you want a refreeze to be.

### G3 — Two of the golden numbers are tautologies 🟠

`test_golden_numbers.R:13` asserts `composite_score[1] == 1.0`.
`test_sdb_engagement.R:63` asserts the same for a *different bank*. Both pass
for **any** input, because both scores are min-max normalized (see M1). Two of
six load-bearing assertions carry zero information, and the same is true of the
`sector_priority_ranking.csv` top row in both engagements.

### G4 — The cross-contamination guard misses the directory that is actually shared 🟡

`ci.yml:89` checks `synthesis_output output dashboard/data reports`. But
`R/trisk_core.R:517-529` writes into **`data/`**:

```r
is_default_mode <- identical(cfg$bank_slug, "mcb-demo")
...
if (is_default_mode) {
  write_csv(financial_features, file.path(data_dir, "vietnam_trisk_financial_features.csv"))
  ...
}
```

`data/` is not in the guard's path list, and neither is
`engagements/<other-slug>/`. Also worth noting: this `bank_slug` string
comparison is the **last surviving one** of the kind Wave 1 replaced elsewhere
with the explicit `public_snapshot_allowed` flag. It should become a config key
(`write_demo_data_copies`) for the same reason the other one did.

---

## M — Methodology (M1 carried, now with side-by-side proof)

### M1 — Rank-normalized scores make two different banks look identical 🔴 (upgraded from 🟠)

Last pass argued this from the code. It is now demonstrable from two committed
deliverables. Both `sector_priority_ranking.csv` files, verbatim:

| | MCB power | MCB cement | MCB steel | SDB power | SDB cement | SDB steel |
|---|---:|---:|---:|---:|---:|---:|
| `composite_score` | **1.000** | 0.011 | 0.145 | **1.000** | **0.000** | 0.169 |
| `priority_band` | Critical | Low | Low | Critical | Low | Low |
| `exposure_share` | 82% | 10% | 8% | 60% | 13% | 28% |

Two banks with materially different books — SDB's cement is 13% of a
USD 850M Decision-263 exposure (≈ USD 38M), MCB's is 10% of USD 750 — produce
**the same score pattern and the same band assignment.** With three sectors and
min-max normalization the outcome is arithmetically forced: one sector is 1.0 in
every dimension, one is 0.0, and only the middle one carries information.

Telling a Vietnamese CRO their USD 38M cement book scores **0.000 / "Low"** is
not a defensible statement in a risk committee — it is a statement about there
being three sectors.

The band thresholds in `classify_band()` (0.70 / 0.50 / 0.30) are written as
though the score were absolute; they are applied to a rank. This also silently
kills the "what changed since last refresh" monitoring story before it is
built, since scores are not comparable across runs.

**Fix (unchanged, ASM-5 carried):** anchored absolute bands documented in
`docs/` — alignment gap in pp against fixed thresholds, NPV change against
fixed % buckets, exposure against a share threshold — keeping the relative rank
as a secondary display column. Forces a golden refreeze, which is why it should
ride along with U1's refreeze rather than pay for its own.

### M2 — Exposure is loaded into the borrower table and excluded from its score 🟡 (carried)

`engagement_scoring.R` joins `exposure_vnd`, writes it to
`engagement_priority.csv`, and never uses it in `composite_score` — while
`prioritize_sectors()` weights exposure at 0.30. Unchanged since last pass.
Additional wrinkle found this session: `normalise_01(alignment_gap)` is applied
**across sectors**, mixing power/automotive market-share percentage-points with
cement/steel SDA `gap_pct`. The script's own header (lines 32-35) documents
that these are not comparable — and then min-maxes them into one column anyway.
Whichever family has the wider raw range defines the scale for both.

### M3 — Multi-scenario traffic-light matrix 🟢 (carried; data confirmed present)

Verified this session: `04_vn_ms_company.csv` carries all three
`scenario_source` values (`pdp8_2023`, `nze_2023`, `steps_2023`), but
`06_vn_ms_alignment_2030.csv` has exactly one target column (`target_pdp8`) and
`06_vn_sda_alignment_2030.csv` likewise. The NZE and STEPS cuts are computed and
then discarded at the alignment step. Still the highest-ROI unbuilt analytic —
but it must land *after* M1, or it renders a matrix whose cells are ranks.

### M4/M5/M7 — carried unchanged

M7 re-verified: `dashboard/pages/4_Methodology.py:35` still says *"the current
pilot is limited to the power sector"* (cement and steel live since April), and
`:52-59` still offers `docs/Baer_TRISK_2022.pdf` (4.2 MB third-party academic
PDF) as a download from a public deploy, while `docs/TRISK_Demo_Assumptions.md`
and `docs/trisk_multisector_contract.md` — the curated registers — are surfaced
nowhere in the app.

---

## A — Architecture (carried, re-verified, one addition)

### A3/D2 — Financial features are still hardcoded per company name 🔴 (hardest real-data blocker)

`.trisk_company_archetypes` (`R/trisk_core.R:164`) hardcodes PD, net profit
margin, debt/equity, and volatility for **17 named companies**, and
`trisk_prepare_sector_inputs()` writes that same table as every sector's
`financial_features.csv` regardless of engagement. SDB's config points
`abcd_csv` at `data/vietnam_abcd.csv` (MCB's ABCD), which is the only reason the
rehearsal works at all.

**New this session:** there is *no referential-integrity check* between
`assets.csv`'s `company_id` set and `financial_features.csv`'s.
`assert_required_input_files()` (`R/trisk_core.R:652`) checks only that four
files exist. A client ABCD with unknown `company_id`s would be handed to
`trisk.model` with financial features that cover none of its assets, and the
failure mode is whatever `trisk.model` does with that — not a clear error.
**INV-007** (assets ⊆ financial features, per sector) is a five-line invariant
and would turn a mystery into a message.

A bank's borrower PDs are the most sensitive input in the pipeline and have no
config key, no schema section, and no validator. This remains the hardest
blocker to engagement #3.

### A2 — Sector registry is code; adding a sector is still a five-file edit 🟠 (carried)

`R/sector_registry.R` (registry tibble), `R/trisk_core.R:598`
(`trisk_supported_sectors`) and `:120-162` (`.trisk_input_sector_specs`),
`R/engagement_config.R:128` (`supported_sectors`), `scripts/new_engagement.R`,
plus `R/prioritization_core.R:32` (`.d263_isic_map`). INV-004 now checks four of
these agree, which is real progress — but **`.d263_isic_map` is not one of them**.

**Latent bug found this session:** `prioritize_sectors()` builds
`alignment_raw_all` as a fixed named vector of `power`/`cement`/`steel`
(`R/prioritization_core.R:125-129`) and then subsets it by `cfg$trisk_sectors`
(`:133`). Config a fourth sector and that subset yields `NA`, which propagates
through `min()`/`max()` into an all-`NA` score column — silently, no error. The
config validator would reject a fourth sector today, so this is dormant; it
becomes live the moment A2 or M4 lands, which is the argument for doing A2
*first*. Also still true: `sector_registry()$grid_available` is a dead
`c(FALSE, FALSE, FALSE)` literal that `refresh_dashboard_data.R:154` overwrites
by probing the filesystem.

### A4 — The dashboard is still not engagement-aware 🟠 (carried)

`dashboard/lib/loaders.py:11` — `DATA_DIR = ROOT / "data"`, full stop.
`branding.py:64` hardcodes "Synthetic Vietnam bank showcase" and `:89` "Allotrope
VC demo build". `bank_name` from the engagement config is read nowhere in
Python. The orchestrator produces a complete private snapshot for SDB and there
is no supported way to show it. Fix unchanged: `PACTATRISK_SNAPSHOT_DIR` +
a small `snapshot_meta.json` (`bank_name`, `synthetic: true|false`) written by
the snapshot step.

Note one wrinkle for whoever builds it: SDB runs `run_grid: false`, so a private
snapshot legitimately has no grid. `manifest.csv`'s `grid_available` column
already carries that fact — the Scenario Builder page needs to read it and
degrade, rather than assume.

### A6 — `refresh_dashboard_data.R` wipes before it validates 🟡 (new, small)

`clear_dir(trisk_dest)` (`:121`) empties `dashboard/data/trisk` at the top, and
the `misses_required` guard that aborts a partial publish runs at the *bottom*
(`:160`). A mid-run upstream failure therefore leaves the public snapshot
directory emptied on disk before exiting non-zero. Git recovers it and CI stops
before committing, so blast radius is a confused local operator — but staging
into a temp dir and swapping at the end is strictly better and is three lines.

---

## E — Engineering hygiene (re-verified, sharpened)

### E1 — The test suite does not cover the engine 🟠

276 passing tests, and **27 of 52 functions in `R/` have no test that names
them** — including every exported PACTA analytic:

```
pacta_load_inputs, pacta_match_and_prioritize, pacta_market_share, pacta_sda,
pacta_alignment_gaps, pacta_encode_charts, pacta_build_report,
prioritize_sectors, trisk_prepare_sector_inputs, trisk_run_sector,
trisk_run_grid, build_borrower_results, summarize_trisk_run, ...
```

`test_pacta_core.R` is 67 lines covering two helpers (`pacta_prejoin_sectors`,
`pacta_coverage`). The analytic core is covered *only* transitively, by six
golden numbers — two of which are tautologies (G3) — over a snapshot that CI
never regenerates (G1). That is a thinner safety net than the green counts
suggest, and it is why G1 (byte-identity in CI) is worth more than 30 new unit
tests: it turns the entire artifact tree into the assertion.

Highest-value unit tests to add, in order: `pacta_market_share` /
`pacta_alignment_gaps` (fixed tiny fixture, hand-computed expected gaps),
`prioritize_sectors` (drives M1's redesign anyway), `build_borrower_results`.

### E2 — `R CMD check` would not pass, and the dependency list is wrong 🟠 (H4 carried, now specific)

- **`trisk.model` is in `renv.lock` but absent from `DESCRIPTION`'s `Imports`** — the single most important analytic dependency is undeclared.
- **19 `library()` calls inside `R/`** (`trisk_core.R` ×10, `prioritization_core.R` ×5, four others ×1) — a package must not `library()` at load.
- **No `Depends: R (>= 4.4)`** despite `%||%` (base R 4.4.0) being used in `R/prioritization_core.R:61` and three places in `scripts/`.

A clean `R CMD check` with a documented allowed-failures budget is the artifact
that survives a bank's technical due diligence, and `roxygen2`/`devtools` are
already in `Suggests` and `renv.lock` — the cost is CI minutes, not dependencies.

### E3 — ~100 KB of dead R and 34 KB of dead Python still live in `scripts/` 🟡

Verified by reference search across the whole tree:

| File | Size | Referenced by |
|---|---:|---|
| `scripts/generate_bidv_report.R` | 45 KB | one **comment** in `generate_disclosure_pack.R:253` |
| `scripts/generate_report.R` | 28 KB | `compare/compare_report.R` (itself dead) and docs |
| `scripts/generate_trisk_reports.py` | 27 KB | nothing (one stale plan) |
| `scripts/generate_template_xlsx.py` | 6.6 KB | **nothing at all** |

`CLAUDE.md` already establishes `attic/` as the home for retired
methodology-reference scripts. These four qualify; moving them makes `scripts/`
mean "things the pipeline runs."

### E4 — Repository weight 🟡 (H2 carried)

`.git` is 54 MB, of which **`present/` is 45 MB** (pitch-deck working directory:
`.pptx`, `render_v2/`, `archive/`, `assets/`) and `compare/` is 3.0 MB of
2026-02-era material. `activeContext.md` is 951 lines; `plans/PROGRESS.md` is
frozen at 2026-03-21 and is one of the documents propagating U1's wrong scale.
A clone is dominated by a deck.

### E5 — Reports page ships 680 KB it never renders, and eagerly loads 1.5 MB 🟡 (P3 carried, quantified)

`refresh_dashboard_data.R:73-82` publishes **8** report HTMLs into the snapshot
(1.9 MB); `dashboard/lib/loaders.py:117-138`'s `report_catalog()` has summaries
for **4**. Orphans never shown: `PACTA_Alignment_Report.html` (320 KB),
`PACTA_Comparison_Report.html` (329 KB), `2026-04-16-pacta-baseline-stabilization.html`
(22 KB), `2026-04-28-trisk-multisector-phases-1-2.html` (10 KB). And
`3_Reports.py:27-36` calls `load_bytes()` then `components.html()` for all four
catalogued reports — including the 869 KB `PACTA_Vietnam_Bank_Report.html` — on
*every* page load, inside collapsed expanders. Lazy-load on expander open; drop
or catalog the orphans.

### E6 — Small nits worth one line each 🟡

- `dashboard/lib/auth.py:27` uses `pw == expected` (non-constant-time). Fine for a demo gate; if a private instance ever fronts real bank data, use `hmac.compare_digest` and add a lockout.
- `tests/testthat/test_sdb_engagement.R:31` hardcodes `C:/Program Files/R/R-4.5.2/bin/Rscript.exe` as a fallback — harmless on CI (where `Sys.which` succeeds), but it is a machine-specific path in a tracked test.
- `pipeline_manifest.json` still carries no scenario vintage, package versions, or input checksums (D3 carried) — while `refresh_audit_metrics.json` already computes `scenario_ms_checksum` / `scenario_co2_checksum`. Promoting those into the manifest is most of the "trace this number" story for free, and it is the natural place to record U2's `exposure_unit` and I2's FX rate.
- No linter or formatter anywhere: no `lintr` config, no `ruff`/`black` config, no pre-commit. Two languages, ~9,000 lines.

---

## Recommended sequencing

| Wave | Contents | Outcome |
|---|---|---|
| **2 — Contracts & Units (now)** | **G1** byte-identity in CI + refresh gate (build the detector first, as in Waves 0/1) → **U1** loanbook rescale + one shared money formatter + INV-006 → **M1** anchored absolute bands → **I1/I2/I3** intake contract fixes (widen sector map, FX at intake, out-of-scope becomes a warning) → **I4** coverage & reconciliation report → **one** golden refreeze covering U1 + M1 | Every money figure is defensible, every score means something absolute, a real bank's book survives ingestion, and the public snapshot has a gate |
| **3 — Credibility & Delivery** | U2 unit contract in `SCHEMA.md`/`loanbook_data_spec.md` → M3 traffic-light matrix → M7 methodology page (fix sector claim, cite Baer by DOI, surface curated registers) → P1 exec-summary generator → A4 engagement-aware dashboard + `snapshot_meta.json` → E5 reports page | A prospect's evaluation and a client's private instance are both first-class |
| **4 — Real data** | A2 data-driven registry (+ fold `.d263_isic_map` into INV-004) → INV-007 assets ⊆ financial features → A3/D2 financial-features intake + schema + validator → M4 automotive TRISK → D3 lineage in the manifest → D4 data-handling annex | A real bank's data enters the pipeline without code edits |
| **Opportunistic** | E1 engine unit tests, E2 `R CMD check` + lintr, E3 dead-script retirement, E4 repo weight, E6 nits, A6 snapshot staging | Package maturity, DD-readiness |
| **Trigger-deferred** | `targets`-scoped caching (2nd–3rd real engagement); multi-tenant auth (2nd concurrent private instance); PDF export; Vietnamese chrome toggle (`pilot/vn/` already has the content) | Pay when it bites |

**Rationale.** Wave 0 verified *processes*. Wave 1 verified *products against
each other*. The gap this pass finds is that nothing verifies **products against
their stated contracts** (`SCHEMA.md` vs the validator; `CLAUDE.md` law #5 vs
`ci.yml`; the deck's "25 trillion VND" vs the data's 25 million) and nothing
guards **the one automated process authorized to overwrite the public
artifact**. Both are the same failure shape as before, which is why the fix
order is the same: build the detector (G1), then fix under it.

The judgment call worth naming: **U1 and M1 are proposed in the same wave and
the same refreeze**, even though M1 is a methodology change and U1 is a data
change. They are batched because each independently forces a full golden
refreeze, and because they interact — anchored absolute bands need a *plausible*
money scale to anchor exposure thresholds against. Doing M1 first would mean
choosing exposure thresholds against a USD 950 portfolio.

---

## Assumptions adopted (unattended — no questions were asked)

- **ASM-1:** Business objective unchanged — convert a Vietnamese bank prospect into a paid real-data pilot. Delivery capability and defensibility outrank analytical breadth. (Carried, ASM-1 of 2026-07-25.)
- **ASM-2:** U1 is treated as a **units defect, not a design choice**, on the strength of three independent internal contradictions (`generate_vietnam_data.R`'s `/1000` "bn VND", `PROGRESS.md`'s "25 trillion", and SDB's true-VND fixture on the same code path). `CLAUDE.md` law #2 is read as governing the *pipeline*, not the *generator* — the same reading as ASM-8 of 2026-07-25, now evidenced rather than assumed. **If that reading is rejected**, U1 collapses to "make the unit explicit everywhere" (U2 only), and the deck and `PROGRESS.md` must be corrected downward to ~USD 950 instead.
- **ASM-3:** I1's widened sector map is scoped to **VSIC 2018 / ISIC Rev.4 codes that map to the five existing PACTA sectors** (notably `3510` and the `3510x` VSIC sub-classes for power) — not to new sectors. Adding sectors is Wave 4.
- **ASM-4:** I2's FX handling converts **once, at intake**, using a config-supplied rate recorded in the manifest — not a live rate lookup (no new dependency, law #8) and not a per-borrower rate.
- **ASM-5:** M1's absolute-score design uses **fixed anchored thresholds documented in `docs/`**, not percentile ranks against a reference portfolio. (Carried verbatim from ASM-5 of 2026-07-25.)
- **ASM-6:** Golden refreezes stay **batched** — Wave 2 gets exactly one refreeze commit covering U1 and M1. (Carried; the discipline has worked twice.)
- **ASM-7:** G1 adds byte-identity as a **non-`--full`** CI job (~107 s pipeline + renv restore). The `--full` variant, which regenerates synthetic inputs, stays local/weekly — it is the only mode that would rewrite `data/`.
- **ASM-8:** No new pipeline dependency in Wave 2. INV-006/INV-007 are base R + `jsonlite` + `arrow`, all in `renv.lock`. `lintr`/`ruff` (E2) are dev-only tooling, the one category law #8 permits.
- **ASM-9:** The prior binding defaults all carry forward: JSON configs via `jsonlite` (no `yaml`), MCB-as-no-flag-default, byte-identity as the refactor acceptance bar, synthetic-data disclaimers untouchable, no real bank data before a signed engagement, `r2dii.*` / `trisk.model` stay pinned.

---

## Out of scope

Real bank data execution; multi-tenant SaaS auth; sectors beyond the existing
five + automotive TRISK; upstream package changes; full i18n beyond a
chrome-level Vietnamese toggle; any change to the 243-cell grid lever ranges;
production credit-model calibration; rewriting the pitch deck (only correcting
the one number U1 invalidates).

---

## Suggested next step

Write a Wave 2 plan
(`plans/2026-07-27-contracts-units-and-guardrails-plan.md`) with six phases:

1. **G1 — byte-identity in CI**, added as a `ci.yml` job and as a gate in
   `refresh.yml` before `git add`, proven green on the current tree first (so a
   later failure is unambiguously the change under test). Also correct
   `CLAUDE.md` law #5's wording to match reality. Gates everything after it.
2. **U1 — units**: rescale `generate_vietnam_data.R` by 1e6, replace the two
   `/1000` display hacks and `format_vnd()`'s `"(synthetic units)"` hedge with
   one shared formatter, add INV-006, correct `PROGRESS.md` /
   `interpretation_notes.md` / the deck's one number.
3. **M1 — anchored absolute bands** in `engagement_scoring.R` and
   `prioritization_core.R`, with the rationale and thresholds documented in
   `docs/`, the rank retained as a secondary column, and
   `test_golden_numbers.R` / `test_sdb_engagement.R` re-pinned to values that
   are no longer tautologies.
4. **Single golden refreeze** covering phases 2–3, verified by phase 1's own
   new CI job.
5. **I1/I2/I3 — intake contract**: widen the sector map to VSIC 2018 / ISIC
   Rev.4, add config-driven FX at intake, demote out-of-scope and non-VND from
   row-dropping errors to retained warnings; reconcile `intake/SCHEMA.md` with
   the implementation in both directions.
6. **I4 — coverage & reconciliation report**: a tracked, money-denominated
   engagement artifact (submitted vs processed vs dropped, itemized by reason,
   plus ABCD coverage of what was processed), rendered through
   `R/report_toolkit.R` and re-run for the SDB fixture as its regression test.

Phase 1 gates the rest, exactly as PHASE-01 did in Waves 0 and 1.

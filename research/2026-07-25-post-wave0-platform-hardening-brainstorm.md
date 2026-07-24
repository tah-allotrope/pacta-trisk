---
title: "Brainstorm: Post-Wave-0 Platform Hardening — Correctness Debt, Orchestrator Convergence, and Credibility Analytics"
date: "2026-07-25"
status: "final"
mode: "unattended (no questions asked; assumptions recorded in the Assumptions section)"
supersedes-in-part: "research/2026-07-20-runway-final-phases-and-beyond-brainstorm.md (its Wave 0 is now fully executed; its Wave 1+ backlog is re-prioritized below)"
plan_inputs:
  - "plans/2026-07-20-wave0-orchestrator-sdb-closers-plan.md (complete, commits 981553e / 61f3d46 / 0e57fd9)"
  - "plans/2026-07-18-engagement-runway-completion-plan.md (complete)"
---

# Brainstorm: Post-Wave-0 Platform Hardening

## TL;DR

Wave 0 landed. The engagement runway is real: `scripts/run_engagement.R` runs a
config-driven end-to-end delivery flow, `tools/verify_refactor.R` makes the
byte-identity acceptance bar a one-command check, both test suites are green
(**R 203 pass / 0 fail; Python 58 pass** — verified this session, not inherited),
and the working tree is clean.

But this pass found something the last three brainstorms could not have found,
because it only becomes visible once you compare *artifacts against each other*
rather than *runs against runs*: **the repository currently ships internally
contradictory committed data.** The precomputed TRISK scenario grid that powers
the Scenario Builder — the page `dashboard/app.py` calls "the best page for a
hands-on evaluation" — is three months stale and disagrees with the base TRISK
run on the same borrower under the same parameters. A prospect who clicks from
page 2 to page 5 sees Dung Quat LNG at **−37.5% NPV** and then at **−43.2% NPV**.

That is the headline. The rest of this document is: five more correctness
defects of the same family (things `verify_refactor.R` structurally cannot
catch), the architectural convergence that stops them recurring, and a
re-prioritized credibility backlog.

**Recommended next move:** a tightly-scoped **Wave 1 — "Consistency"** that fixes
the six correctness defects, converges the two orchestrators, and upgrades
`verify_refactor.R` from a reproducibility check into a *consistency* check.
Analytics (traffic-light, exec summary, automotive) moves to Wave 2. Shipping
new analytics on top of provably inconsistent data would be the same mistake the
prior brainstorms warned about, one layer up.

---

## Verified current state (2026-07-25)

Checked directly this session:

| Fact | Evidence |
|---|---|
| R suite green | `testthat::test_dir('tests/testthat')` → `[ FAIL 0 \| WARN 4 \| SKIP 0 \| PASS 203 ]` |
| Python suite green | `python -m pytest dashboard/tests` → `58 passed in 31.08s` (the `test_auth.py` flake did not fire) |
| Working tree clean | `git status --porcelain` → empty |
| Package at 0.2.0 | `DESCRIPTION`, `NEWS.md`, 24 `@export`s in `NAMESPACE`, `man/` populated |
| Volatility list retired | `tools/verify_refactor.R:VOLATILE_BASENAMES <- character(0)` |
| Two engagements exist | `engagements/mcb-demo/`, `engagements/sdb-rehearsal/` (24-row normalized loanbook, own manifest) |
| SDB is a genuinely different book | SDB counterparties are parent-level names (`Vinacomin Power JSC`); MCB's are subsidiary names (`Nhiet Dien Vinh Tan 1 JSC`) requiring fuzzy match — the two exercise different matching paths |

The engineering foundation is sound. Everything below is about what sits *on* it.

---

## C — Correctness defects (all found and reproduced this session)

These are ordered by client-facing blast radius. Every one is verifiable with a
command given in-line.

### C1 — The scenario grid is stale and contradicts the base TRISK run 🔴

`trisk_run_grid()` (`R/trisk_core.R:1349`) keys its cache on `scenario_id` alone
— the five lever values. It has **no dependency on the input data, the ABCD, the
scenario vintage, or the `trisk.model` version.** Worse, at
`R/trisk_core.R:1386` it short-circuits entirely:

```r
if (nrow(pending_grid) == 0 && nrow(existing$borrower_results) > 0 && ...) {
  cat("  [%s] grid already complete, skipping regeneration.\n")
  return(...)
}
```

`read_existing_grid()` reads the **committed** `borrower_results.parquet`. So on
a fresh CI checkout the grid is already "complete" and is never recomputed —
permanently. The weekly `refresh.yml` job has been re-publishing a May snapshot
every Monday since.

**Git archaeology confirms the split:**

```
dashboard/data/trisk/grid/power/borrower_results.parquet  → 251adc8 (2026-05-02)
synthesis_output/trisk/grid/power/input/assets.csv        → 0e57fd9 (2026-07-21, Wave 0 refreeze)
data/vietnam_trisk_assets_power.csv                       → 0e57fd9
synthesis_output/trisk/power_demo/npv_results_latest.csv  → 0e57fd9
```

The grid's *inputs* are current (they're overwritten every run by
`build_grid_input_dir()`, and `diff` shows them byte-identical to
`output/trisk_inputs/power_demo/assets.csv`). Its *results* are from before the
PHASE-05 Dung Quat zero-baseline fix and the power-2025 NA fix.

**Empirical proof — grid base cell vs. base run, same parameters:**

| Company | Grid `npv_change_pct` | Base run `npv_change` | Δ |
|---|---:|---:|---:|
| **Dung Quat LNG Power Consortium** | −0.432056 | −0.374884 | **5.72 pp (15.3% relative)** |
| **PVN Power Corporation** | −0.425554 | −0.406385 | **1.92 pp** |
| EVN (Electricity of Vietnam) | −0.634490 | −0.633151 | 0.13 pp |
| Vietnam Hydropower JSC | 0.000778 | 0.000870 | small |
| Nghi Son / Mong Duong / Vinacomin | −0.980411 | −0.980411 | 0 (unaffected by the fix) |

The two companies that move are exactly the two the Wave 0 refreeze fixed. This
is not noise; it is the fix failing to propagate.

**Why `verify_refactor.R` didn't catch it.** The tool answers "does run *N+1*
byte-match run *N*?" The grid is deterministic-by-skipping, so it passes
trivially. Nobody asked "does artifact A agree with artifact B?"

**Fix:** fingerprint the grid. Hash the resolved grid input directory + the
`trisk.model` version + `grid_contract_version` into `grid_meta.json`; on
mismatch, discard the cache and regenerate. Add an invariant test asserting the
grid's base cell equals the base run's `company_summary.csv` within tolerance.
Effort: small (the meta file already exists and already records
`trisk_model_version` and `grid_contract_version` — it just isn't *checked*).
Cost: one 243×3-scenario regeneration (~5 min/sector per `grid_meta.json`
`runtime_seconds: 280`) plus a golden refreeze.

### C2 — `data_source` is hardcoded `"MCB_synthetic"` in every engagement's deliverable 🔴

`scripts/engagement_scoring.R:79` — `data_source <- "MCB_synthetic"` — despite
`cfg$bank_slug` being available three lines up. The provenance column that exists
specifically to say *whose data this is* says the wrong bank.

**Proof, from the committed Saigon Delta Bank fixture:**

```
$ head -2 engagements/sdb-rehearsal/output/engagement/engagement_priority.csv
name_abcd,sector,...,alignment_basis,data_source
Nghi Son Power LLC,power,...,Borrower-level PACTA market-share gap,MCB_synthetic
```

`prioritize_sectors()` gets this right (`data_source <- cfg$bank_slug`,
`R/prioritization_core.R:69`), which makes the inconsistency an outright bug
rather than a convention. `engagement_priority.csv` feeds the letters and the
disclosure pack — this leaks into client-facing output. Effort: one line + a
golden refreeze of both fixtures.

### C3 — The SDB "regression guard" doesn't run the pipeline, and its CI job doesn't exist 🔴

Two claims in `reports/2026-07-22-final-wave0-completion.html` do not hold:

1. *"CI job added to `refresh.yml`"* — `grep -rn "run_engagement\|sdb\|engagement" .github/workflows/` returns **nothing**. Neither workflow ever invokes `run_engagement.R`.
2. `tests/testthat/test_sdb_engagement.R` contains **no** `system2` / `Rscript` / pipeline invocation. It reads three committed files and asserts on their contents.

So the second golden fixture validates *the committed CSVs*, not *the code that
produced them*. `run_engagement.R` could be broken in `main` right now and the
suite would stay green. The one thing Wave 0's PHASE-03/04 existed to guarantee
— "the orchestrator works for a bank that isn't MCB" — is currently unguarded.

Compounding it: `engagements/sdb-rehearsal/engagement_config.json` points
`loanbook_csv` at `data/vietnam_loanbook.csv` (MCB's book). The rehearsal
actually ran with `--raw-loanbook data/fixtures/unseen_bank_loanbook.csv`, a flag
recorded nowhere in the config. Re-running the config as committed silently
produces MCB numbers under SDB's name. **The engagement config does not
self-describe its own reproduction.**

**Fix:** add `inputs.raw_loanbook_csv` to the config schema so
`run_engagement.R` can pick it up without a CLI flag; add a CI job that runs the
SDB engagement (grid off — it's minutes) and *then* runs the golden test.
Effort: small–medium.

### C4 — `prioritize_sectors()` ignores `cfg$trisk_sectors` 🟠

`R/prioritization_core.R:68` hardcodes `sectors <- c("power", "cement",
"steel")` and `:149` hardcodes the ISIC→Decision-263 map. An engagement
configured `"trisk_sectors": ["power"]` still emits cement and steel rows with
zeroed dimensions — and because scoring is min-max normalized (see M1), those
phantom zeros *define the bottom of the scale* and distort power's own score.
The config layer validates `trisk_sectors`, then this function ignores it.

### C5 — Scenario "versioning" produced a duplicate, not a version 🟠

```
$ md5sum data/vietnam_scenario_ms.csv data/scenarios/pdp8-2023/vietnam_scenario_ms.csv
1827b2776aa0df5f50b72ff866d54665 *data/vietnam_scenario_ms.csv
1827b2776aa0df5f50b72ff866d54665 *data/scenarios/pdp8-2023/vietnam_scenario_ms.csv
```

Byte-identical copies. `mcb-demo` reads the versioned path; `sdb-rehearsal`
reads the unversioned one. Two sources of truth, one of which nothing owns.
Either retire the flat copies (updating the SDB config) or make them symlinks —
but not both live. Note `generate_vietnam_data.R` writes the flat path, so
retirement means teaching the generator about the vintage directory.

### C6 — The demo's own ABCD fails the demo's own ABCD contract 🟠

`intake/SCHEMA.md` §ABCD specifies 12 required + 2 provenance columns
(`data_source`, `as_of_year`), and `intake/templates/abcd_template.csv` ships all
14. But:

```
$ head -1 data/vietnam_abcd.csv
company_id,name_company,lei,sector,technology,production_unit,year,production,emission_factor,plant_location,is_ultimate_owner,emission_factor_unit
```

12 columns — no provenance. And there is **no ABCD validator** at all: the
loanbook gets `scripts/intake_validate_and_map.R`, the ABCD gets a markdown
table. The first real client ABCD file will be validated by whether the pipeline
crashes. Effort: medium (mirror the loanbook validator; add provenance columns to
the generator).

---

## A — Architectural convergence (stop the C-class recurring)

### A1 — Two orchestrators that must not diverge, and already have 🔴

| | `scripts/pipeline_refresh.R` | `scripts/run_engagement.R` |
|---|---|---|
| Serves | MCB / public snapshot | any engagement |
| Power step | `scripts/trisk_power_demo.R` | `scripts/trisk_sector_demo.R power` |
| Intake / validation report | ✗ | ✓ |
| Letters / disclosure | ✗ | ✓ |
| Refresh audit | ✓ | ✗ |
| Config-aware | ✗ (`--config` unsupported) | ✓ |
| Run weekly by CI | ✓ | ✗ |

Two step lists, two power entrypoints, and the *public demo — the artifact
prospects actually see — never travels the engagement code path.* "One command,
any bank" is true for every bank except the one on the website.

**Fix (the elegant one):** make `pipeline_refresh.R` a thin compatibility wrapper
that calls `run_engagement.R --config engagements/mcb-demo/engagement_config.json`
with the public-snapshot allowance, and delete `trisk_power_demo.R` (it is
already a pure wrapper around `trisk_run_sector(cfg, "power")`). One step list,
one code path, CI exercises the engagement runway every Monday for free — which
also resolves C3 for MCB. Byte-identity is the acceptance bar and
`verify_refactor.R` already enforces it. This is the single highest-leverage
refactor available. Effort: medium.

### A2 — The sector registry is code, so adding a sector is a five-file edit 🟠

Adding automotive TRISK (the top analytics ask) currently means editing:
`R/sector_registry.R` (registry tibble), `R/trisk_core.R`
(`.trisk_input_sector_specs`, `trisk_supported_sectors`,
`.trisk_company_archetypes`), `R/engagement_config.R`
(`supported_sectors` literal, line 98), and `R/prioritization_core.R`
(`sectors`, `isic_to_d263`). Five hardcoded sector lists that must agree, with no
test asserting they do.

**Fix:** move the registry to `data/sector_registry.json`, load it once, derive
every list from it, and add a test asserting the config validator's supported set
== the registry's set. The registry is already pure data in a tibble; this is a
mechanical lift with a large payoff on the *next* sector.

Related nit: `sector_registry()` hardcodes `grid_available = c(FALSE, FALSE,
FALSE)`, which `refresh_dashboard_data.R:154` then overwrites by probing the
filesystem. Dead literals that read as fact.

### A3 — TRISK financial features are hardcoded per company name, blocking engagement #3 🔴

`.trisk_company_archetypes` (`R/trisk_core.R:80`) hardcodes PD, net profit
margin, debt/equity, and volatility for 17 named companies. `data/
vietnam_trisk_financial_features.csv` is *generated from that literal*, not read
from anywhere. There is no config key, no intake path, and no schema entry for
it.

The SDB rehearsal only worked because SDB's synthetic borrowers resolve to the
same 17 ABCD companies. A real bank's counterparties will not, and their PDs are
the bank's own data — arguably the most sensitive input in the whole pipeline.
**This is the hardest remaining blocker to a real engagement**, and it is not on
any existing plan. Fix: a `financial_features_csv` config input + schema section
+ validator, with the archetype table demoted to a synthetic-demo fallback.

### A4 — The dashboard is not engagement-aware 🟠

`dashboard/lib/loaders.py:11` — `DATA_DIR = ROOT / "data"`, full stop. There is
no way to point the app at `engagements/<slug>/snapshot/`. Branding is hardcoded
too: `public_demo_banner()` says "Synthetic Vietnam bank showcase",
`footer_note()` says "Allotrope VC demo build", and `bank_name` from the
engagement config is never read anywhere in Python.

So the orchestrator can produce a complete private snapshot for Saigon Delta Bank
— and there is no supported way to *show* it. `docs/private-instance-deploy.md`
describes deploying the app, but the app it deploys renders MCB. For a paid
pilot, delivery currently means hand-editing Python.

**Fix:** `PACTATRISK_SNAPSHOT_DIR` env var (default `dashboard/data`) + read
`bank_name` / a `synthetic: true|false` flag from a small
`snapshot_meta.json` the snapshot step already could write. Small, and it is the
difference between "demo" and "deliverable".

### A5 — Upgrade `verify_refactor.R` from reproducibility to consistency 🟠

C1 and C5 are both *cross-artifact* defects, and the acceptance tool is
structurally blind to them: it diffs the tree against itself. Add a
`--invariants` mode asserting a short list of things that must be true of any
valid tree:

1. Grid base cell ≡ base run `company_summary.csv` (catches C1).
2. Every `data/scenarios/<vintage>/` file is referenced by ≥1 engagement config; no unreferenced duplicates (catches C5).
3. Every engagement's `data_source` column == its `bank_slug` (catches C2).
4. `sector_registry()` set == config-validator supported set == `trisk_supported_sectors` (catches A2 drift).
5. `dashboard/data/trisk/manifest.csv` sectors ⊆ registry sectors.

This is the generalization of the Wave-0 lesson, and it is cheap: pure base R
over CSVs, no new dependency. Wire it into `ci.yml`.

---

## M — Methodology credibility (what a bank's risk committee will push on)

### M1 — Every composite score is rank-relative, so the top borrower is always exactly 1.0 🟠

`normalise_01()` in `engagement_scoring.R:85` and the three min-max blocks in
`prioritization_core.R` mean scores encode *rank within this portfolio*, not
severity. Consequences:

- `composite_score[1] == 1.0` is pinned as a golden number in
  `test_golden_numbers.R` — but it is 1.0 for *any* input, including a portfolio
  of uniformly excellent borrowers. The golden test asserts an identity, not a result.
- Scores are not comparable across engagements (MCB's 1.0 ≠ SDB's 1.0), nor
  across refreshes — which silently kills the P1.6 "what changed since last run"
  monitoring narrative before it is built.
- With three sectors, the lowest sector is forced to 0 in every dimension. Cement
  scores 0.0105 not because it is safe but because it is last of three. C4's
  phantom sectors make this worse.

**Fix:** anchored absolute bands (e.g. alignment gap in pp against fixed
thresholds; NPV change against fixed % buckets), keeping the relative rank as a
secondary display column. This is a *methodology* change, so it needs a
documented rationale in `docs/` and a golden refreeze — but it is what makes the
number defensible in a committee room and what unlocks the monitoring story.

### M2 — Exposure is loaded into the borrower table and then excluded from the score 🟡

`engagement_scoring.R` joins `exposure_vnd` onto every borrower, writes it to
`engagement_priority.csv`, and never uses it in `composite_score` (which is
alignment + TRISK only). Meanwhile `prioritize_sectors()` weights exposure at
0.30. A reader comparing the two tables sees the bank's largest exposure ranked
below a small one and cannot tell whether that is a judgment or an oversight.
Either add a third weighted term or state the omission explicitly in the
generated output. (The script header documents a "fixed 50/50" decision — it just
never says *why exposure is out*.)

### M3 — Multi-scenario traffic-light matrix (carried, still the best unbuilt artifact) 🟢

Sector × {PDP8, NDC, NZE} × {aligned / marginal / misaligned}. All three
scenarios are already in `04_vn_ms_company.csv` (`scenario_source` column) and
`07_alignment_market_share.csv`; only the PDP8 cut is ever surfaced. One
synthesis CSV + one dashboard view. Highest ROI in the analytics backlog, and
after C1/A1 it costs a day.

### M4 — Automotive is PACTA-only, so the second-largest sector carries an asterisk 🟢

`trisk_status = "N/A - sector not in TRISK pilot"` for every automotive borrower,
and those rows renormalize to the alignment term alone (`composite_partial =
TRUE`). With `trisk_core.R` live this is data prep (a market-share shock
analogous to power) plus one registry row — *cheap only after A2 lands*, which is
the argument for doing A2 first.

### M5 — Steel honesty pass 🟢

Steel match coverage in the synthetic book is low (2 borrowers) and the README
already admits it. Either enrich the synthetic steel book or build a reusable
"below reporting threshold — N counterparties, X% of sector exposure" component
and apply it consistently. The second is more valuable: real bank books will hit
this constantly.

### M6 — The public demo's money is implausible 🟡

MCB's synthetic loanbook is denominated in raw VND but sized like millions:
individual loans of `800000` VND (≈ USD 30) and a total matched book of
**25,020,000 VND ≈ USD 950**. The SDB fixture, by contrast, uses realistic
magnitudes (`910000000000` VND ≈ USD 36M). `CLAUDE.md` law #2 correctly forbids
rescaling *in the pipeline* — but that law is about not mangling data in transit,
not about the generator's choice of scale.

A Vietnamese bank CRO reads "15,770,000 VND of power exposure" on the sector
priority chart and stops taking the demo seriously in the first thirty seconds.
The letters hedge with `"%s VND (synthetic units)"`, which reads as an excuse.
**Fix:** scale `generate_vietnam_data.R` by 1e6 and refreeze the goldens — a
deliberate, planned, one-time refreeze that makes every downstream number
plausible. Cheap in effort, disproportionate in credibility.

### M7 — The Methodology page is factually stale and leans on raw text dumps 🟡

`dashboard/pages/4_Methodology.py:35` still says *"the current pilot is limited
to the power sector"* — cement and steel have been live since April. The page
also renders `research/PACTA for BANKS - TRISK overview.pptx.txt` and
`research/Baer_TRISK_2022_extracted.txt` (raw extraction dumps, truncated to
3,500 and 4,000 chars mid-sentence) and offers `docs/Baer_TRISK_2022.pdf`
(4.2 MB) as a download **from a public deploy** — that is a third-party academic
PDF being redistributed. Meanwhile `docs/TRISK_Demo_Assumptions.md`,
`docs/trisk_multisector_contract.md`, and `dashboard/data/README.md` — the actual
curated assumption registers — are never surfaced in the app at all.

Fix: cite the Baer paper (DOI/link) rather than redistributing it; surface the
curated registers; correct the sector claim. This is the page a technical
evaluator opens *second*.

---

## D — Real-data readiness (gating the first paid pilot)

- **D1 — ABCD validator** mirroring `intake_validate_and_map.R`: schema check, coverage report (what % of loanbook exposure has ABCD coverage), provenance columns enforced. Closes C6. *This is the artifact that lets you tell a prospect "send us your list and we'll tell you your coverage in 48 hours."*
- **D2 — Financial-features intake** (see A3). The hardest blocker.
- **D3 — Scenario vintage as a first-class object.** `refresh_audit_metrics.json` already carries `scenario_ms_checksum` / `scenario_co2_checksum`; `pipeline_manifest.json` does not. Promote vintage + checksum + package version + git SHA into the manifest and you have two-thirds of the P1.5 "trace this number" story for free.
- **D4 — Data-handling posture.** `docs/intake_privacy.md` exists and `--anonymize` works, but nothing states retention, deletion, or where a bank's data physically sits during an engagement. A one-page data-handling annex is a sales artifact, not just a doc.

---

## P — Product & delivery polish

- **P1 — Executive summary generator.** A one-page HTML/PDF over `pipeline_manifest.json` + `engagement_priority.csv` + `sector_priority_ranking.csv`. Trivial now that the orchestrator emits per-engagement manifests; it is the artifact a bank actually forwards internally.
- **P2 — Refresh-to-refresh delta view.** Needs M1's absolute scores first, or the deltas are meaningless.
- **P3 — Reports page weight.** `3_Reports.py` eagerly `load_bytes` + `components.html` all four catalog reports (852 KB + 348 KB + …) on every page load. Also, the snapshot ships 8 report HTMLs but `report_catalog()` hardcodes summaries for only 4 — `PACTA_Alignment_Report.html`, `PACTA_Comparison_Report.html`, `2026-04-16-pacta-baseline-stabilization.html`, and `2026-04-28-trisk-multisector-phases-1-2.html` are copied into `dashboard/data/reports/` (~700 KB) and never rendered. Lazy-load on expander open; drop or catalog the orphans.
- **P4 — Vietnamese chrome toggle** (`pilot/` already has `{{BANK_NAME}}` tailoring slots and `intake/templates/README_vi.md` proves the appetite) and **PDF export via print CSS**. Both carried, both still right, both after Wave 1.
- **P5 — Scenario Builder shareable links.** Query-param round-trip of the five levers. Small, and it is how an evaluator sends a finding to a colleague.

---

## H — Hygiene (unchanged items are marked "carried")

- **H1 — `lessons.md` still does not exist** despite the global workflow expecting it (carried from 07-20, now three brainstorms old). Seed it with the four hard-won lessons that are currently only in commit messages: (a) git-diff-not-md5sum for byte identity; (b) the `file.path(getwd(), ...)` double-join bug class; (c) **caches must be keyed on inputs, not just on parameters** (C1); (d) **a golden test that reads committed artifacts guards the artifacts, not the code** (C3).
- **H2 — carried:** `activeContext.md` is 951 lines; `plans/PROGRESS.md` is stale (Mar-21 era); `compare/` (3.0 MB, 17 files, 2026-02 era) still tracked and still unretired to `attic/`. New: **`present/` is 45 MB tracked** — the pitch-deck working directory dominates a 52 MB `.git`. Consider `attic/` or a release artifact.
- **H3 — test nits, carried:** `dashboard/tests/test_auth.py` hardcodes a 3 s Streamlit AppTest timeout (did not fire this session, still a flake); `test_loaders.py:66` hardcodes `243` instead of deriving from `grid_meta.json` — which would also have been a second detector for C1.
- **H4 — `R CMD check` + `lintr` in CI.** `ci.yml` currently does `devtools::load_all()` and the test suite; a clean `R CMD check` with a documented allowed-failures budget is the artifact that survives a bank's technical due diligence. `roxygen2`/`devtools` are already in `Suggests` and `renv.lock`, so the cost is CI minutes, not dependencies.
- **H5 — doc sweep after A1.** `README.md` architecture diagram, `AGENTS.md`, `CLAUDE.md` command list, and `docs/demo-script.md` all describe the two-orchestrator world. One sweep once `pipeline_refresh.R` becomes a wrapper.

---

## Recommended sequencing

| Wave | Contents | Outcome |
|---|---|---|
| **1 — Consistency (now)** | C1 grid fingerprinting → C2 `data_source` → C4 `cfg$trisk_sectors` → C5 scenario dedupe → **A1 orchestrator convergence** → **A5 `--invariants`** → C3 (config self-description + real SDB CI job) → one golden refreeze covering all of it | The repo stops shipping contradictory data; MCB and clients share one code path; the acceptance tool catches this defect class forever |
| **2 — Credibility** | M6 loanbook scale + M1 absolute scores (fold into Wave 1's refreeze if timing allows — see ASM-3) → M3 traffic-light → M7 methodology page → P1 exec summary | The numbers survive a risk committee and a technical evaluator |
| **3 — Real-data** | A2 data-driven registry → M4 automotive → A3/D2 financial-features intake → D1 ABCD validator → D3 lineage in the manifest → D4 data-handling annex | A real bank's data can enter the pipeline without code edits |
| **4 — Delivery** | A4 engagement-aware dashboard → P4 VN toggle + PDF → P2 delta view → P5 shareable links | A private instance is a deploy, not a fork |
| **Opportunistic** | P3, H1–H5 | Hygiene, package maturity |
| **Trigger-deferred** | `targets`-scoped caching (2nd–3rd real engagement); multi-tenant auth (2nd concurrent private instance) | Pay the cost when it bites |

**Rationale.** Wave 0 proved the engineering discipline works. What this pass
shows is that the discipline had a blind spot with a precise shape: it verified
*processes* (run N vs run N+1) and never verified *products* (artifact A vs
artifact B). Every C-finding lives in that blind spot, and A5 is the structural
answer. Doing analytics first would mean building the traffic-light matrix on a
grid that already disagrees with itself — and the traffic-light is exactly the
artifact where a prospect would notice.

The one judgment call worth naming: **A1 (orchestrator convergence) is proposed
inside Wave 1 rather than deferred**, because it is what makes C3 self-solving
for MCB and because every week it waits, the two step lists drift further. It is
also the change most likely to surface a latent difference — which is precisely
why it should happen while `verify_refactor.R` is fresh and the tree is clean.

---

## Assumptions adopted (unattended — no questions were asked)

- **ASM-1:** Business objective unchanged — convert a Vietnamese bank prospect into a paid real-data pilot. Delivery capability and defensibility outrank analytical breadth. (Inherited from ASM-iv of 2026-07-20; nothing this session contradicts it.)
- **ASM-2:** C1 is treated as a **correctness defect, not a performance trade-off**. An alternative reading — "the grid is an intentionally frozen artifact" — is rejected because nothing documents it, `grid_meta.json` records freshness fields nobody checks, and the Scenario Builder presents grid output as the same quantity the TRISK page presents.
- **ASM-3:** Golden refreezes are **batched**. Wave 1 gets exactly one refreeze commit covering C1/C2/C4/C5 and A1. M1 and M6 (which also force a refreeze) are scheduled into Wave 2's own single refreeze rather than being pulled forward — unless Wave 1 slips, in which case folding them in is strictly cheaper than a second freeze. This mirrors the ASM-i discipline that worked in Wave 0.
- **ASM-4:** A1 collapses `pipeline_refresh.R` into `run_engagement.R` (not the reverse, and not a new third orchestrator). The public-snapshot guard rail becomes an explicit config-level allowance for `mcb-demo` rather than a `bank_slug` string comparison in the orchestrator.
- **ASM-5:** M1's absolute-score design uses **fixed anchored thresholds documented in `docs/`**, not percentile ranks against a synthetic reference portfolio. Anchors are auditable; reference portfolios are another thing to keep fresh.
- **ASM-6:** No new pipeline dependency is introduced anywhere in Waves 1–2. `A5`'s invariant checks are base R + `jsonlite` + `arrow` (all already in `renv.lock`), consistent with law #8.
- **ASM-7:** The three prior binding defaults carry forward unchanged: JSON configs via `jsonlite` (no `yaml`), MCB-as-no-flag-default, byte-identity as the refactor acceptance bar, synthetic-data disclaimers untouchable, and no real bank data before a signed engagement.
- **ASM-8:** M6 (rescaling the synthetic loanbook) is read as **not** conflicting with `CLAUDE.md` law #2. The law forbids the *pipeline* rescaling money in transit; changing what the *generator* emits is a data-generation choice. If that reading is wrong, M6 should be dropped and the "(synthetic units)" hedge made prominent instead — but the credibility cost is real either way.

---

## Out of scope

Real bank data execution; multi-tenant SaaS auth; sectors beyond the existing
four + automotive; upstream package changes (`r2dii.*` and `trisk.model` stay
pinned); full i18n beyond a chrome-level Vietnamese toggle; any change to the
243-cell grid lever ranges; production credit-model calibration.

---

## Suggested next step

Write a Wave 1 plan (`plans/2026-07-25-consistency-and-orchestrator-convergence-plan.md`)
with five phases: **(1)** `verify_refactor.R --invariants` with the five checks
above, proven to *fail* on the current tree by detecting C1 — building the
detector first is the Wave-0 lesson applied; **(2)** C2/C4/C5 one-line-class
fixes; **(3)** grid input fingerprinting + regeneration; **(4)** A1 orchestrator
convergence under byte-identity; **(5)** C3 config self-description + SDB CI job,
then a single golden refreeze commit. Phase 1 gates everything after it, exactly
as PHASE-01 did in Wave 0.

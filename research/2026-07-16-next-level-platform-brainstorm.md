---
title: "Next-Level Platform: Finish the Runway, Then Harden the Foundation"
date: "2026-07-16"
type: "brainstorm"
depth: "thorough"
source_request: "Analyze current state, brainstorm what takes pacta-trisk to the next level (features, refactors, architecture, optimizations)"
slug: "next-level-platform"
predecessor: "research/2026-07-13-client-engagement-runway-brainstorm.md"
mode: "unattended — assumptions adopted, no questions asked"
---

# Brainstorm: Next-Level Platform

## TL;DR

The single most important fact about the current state: **the platform's headline
promise is half-built.** The 2026-07-13 client-engagement-runway plan defines a
6-phase path to "run the whole PACTA + TRISK platform on a new bank's loanbook in one
command." **Only PHASE-01 and PHASE-02 are committed.** PHASE-03 → PHASE-06 (parameterize
the TRISK chain + downstream generators, the `run_engagement.R` orchestrator, the
second-bank end-to-end run, the ABCD sourcing/scenario-versioning briefs) are **not
done**. Verified in the working tree today:

- Only `scripts/pacta_vietnam_scenario.R` reads the engagement config. The entire TRISK
  chain, `sector_prioritization.R`, `engagement_scoring.R`, and the letter/disclosure
  generators still hardcode MCB paths.
- `scripts/run_engagement.R` **does not exist**. `R/step_runner.R` **does not exist**.
- `engagements/` contains only `mcb-demo/`. No `sdb-rehearsal/`.
- `data/scenarios/` and `docs/abcd_sourcing_decision.md` **do not exist**.

So the honest "next level" is two-layered:

1. **Finish the runway (P0).** Ship PHASE-03 → PHASE-06 as already specified. Until
   `run_engagement.R` runs the SDB fixture end-to-end, the pilot proposal's milestone
   "PACTA + TRISK results delivered" remains a claim, not a demonstrated capability. No
   new brainstorming is needed here — the plan is written; it needs execution.

2. **Then harden the foundation and level up credibility (P1–P3).** This is where new
   thinking adds value, and it's the focus of the rest of this document: the engineering
   debt the runway plan deliberately deferred, the methodology holes a signing bank hits
   in week one, and the product/commercial polish that makes a private instance feel
   finished in a Vietnamese boardroom.

**Thesis:** the runway plan makes the platform *deliverable*; the items below make it
*defensible, fast, and repeatable* across many banks — which is what turns a one-off
pilot into a productized engagement practice.

---

## Where the project actually stands (verified 2026-07-16)

**Mature and working:**
- Public Streamlit demo (7 pages, 3 operator-gated) live at pactavn.streamlit.app, fed
  by a frozen 3 MB snapshot in `dashboard/data/`.
- Reproducibility rails: `renv.lock`, `tests/testthat/` (golden numbers, snapshot
  contract, manifest, intake fixture, matching helpers, config), `dashboard/tests/`
  (8 pytest files), two CI workflows (`ci.yml` test gate + `refresh.yml` weekly
  auto-commit).
- Refresh automation: `pipeline_refresh.R` 8-step runner → `pipeline_manifest.json`.
- Intake layer rehearsed: dirty 40-row Saigon Delta Bank (SDB) fixture → 17 errors →
  validation report → `--anonymize` pseudonym map.
- Private-instance delivery: dormant password gate, deploy doc, per-refresh audit report.
- **PHASE-01/02 of the runway:** engagement config loader (`R/engagement_config.R`),
  single sector registry (`R/sector_registry.R`) replacing two hand-synced tribbles,
  shared `R/report_toolkit.R` + `R/matching_helpers.R`, PACTA script config-driven with
  byte-identical MCB output, `pacta_demo.R`/`pacta_synthesis.R` retired to `attic/`.

**Not yet built (the gap):**
- The one-command engagement run (PHASE-03–06).
- Every methodology objection-closer (automotive TRISK, steel coverage, Dung Quat LNG
  NA, power-2025 NA).
- Real ABCD data sourcing decision — still only synthetic, MCB-shaped ABCD exists.
- All product polish (VN toggle, PDF export, scenario persistence, exec summary).

---

## Theme 0 — Finish the runway (P0, execution not ideation)

Run `/plan` is unnecessary; the plan exists at `plans/2026-07-13-client-engagement-runway-plan.md`.
The work is PHASE-03 through PHASE-06. Sequencing and acceptance bars are already
specified (byte-identical MCB CSV outputs under green golden tests). **This must land
before anything in Themes 2–5**, because those themes would otherwise be built on top of
code slated for the same refactor. The only judgment call worth flagging:

- **ASM-0A:** If execution reveals that the SDB fixture crashes deep in PACTA/TRISK
  analysis code (zero-match sectors, empty tibbles), fix with guards inline per the
  plan's PHASE-05 RISK notes — do not redesign. Log each friction point in
  `pilot/rehearsal_log.md`. The rehearsal *is* the point; friction is the deliverable.

---

## Theme 1 — Engineering foundation the runway plan under-delivers (P1)

The runway plan extracts `report_toolkit` and `matching_helpers` but **leaves the
1,386-line `pacta_vietnam_scenario.R` monolith intact** (still 21 inline sections; only
paths were parameterized). The brainstorm that spawned the plan (T1.2) called for a real
`R/pacta_core.R` extraction; the plan quietly narrowed that to "paths only." That is the
biggest remaining piece of structural debt, and it's the foundation everything else at
scale rests on.

- **T1.1 — Decompose the PACTA monolith into tested functions (the real refactor).**
  `DESCRIPTION` already declares this an R package (`pactatrisk 0.1.0`), but there is
  **no `NAMESPACE`, no roxygen, no loadable library** — the `R/` files are `source()`d
  scripts, not package functions. Extract PACTA stages (`load_inputs`, `match_and_prioritize`,
  `target_market_share`, `target_sda`, `compute_alignment`, `render_charts`) into pure
  functions in `R/pacta_core.R`, each unit-testable in isolation with tiny fixtures. Today
  the *only* way to test PACTA is to run the whole 1,386-line script and diff CSVs — slow,
  coarse, and it can't localize a regression to a stage. Function-level tests would catch
  the exact kind of "works only for MCB" bug the second-book fixture is meant to guard,
  but *before* a full run. **Recommendation (ASM-1A): do this as a follow-on to the runway,
  not inside it** — the runway's byte-identity bar is safer against a path-only change than
  against a full decompose; sequence the decompose immediately after PHASE-06 refreezes
  goldens, using those same goldens as the acceptance net.

- **T1.2 — Make it an actual installable package OR drop the package pretense.** Right
  now `DESCRIPTION` promises a package the repo doesn't deliver. Two honest options:
  (a) complete the package (`NAMESPACE`, roxygen, `devtools::load_all()`, functions
  callable as `pactatrisk::run_pacta(cfg)`), which makes multi-bank orchestration and
  testing dramatically cleaner; or (b) delete `DESCRIPTION`/`.Rbuildignore` and commit to
  the "sourced scripts + renv" model. **Recommendation: (a).** Once you're running the
  pipeline for N banks, `library(pactatrisk); run_engagement(cfg)` beats `source()`-ing
  eight scripts, and it's the natural home for the T1.1 functions. This is the single
  highest-leverage architectural move for scale.

- **T1.3 — Project `CLAUDE.md` codifying the traps.** There is no root `CLAUDE.md` (only
  `AGENTS.md`, which is thin and partly stale — it references a `compare/` AI-vs-staff
  workflow and `pacta_demo.R` that are now historical). The repo has sharp, expensive
  traps that every contributor (human or agent) must know: **VND money is never rescaled**;
  **run everything from repo root**; **byte-identical MCB CSV is the refactor acceptance
  bar**; diacritic normalization via `stri_trans_general`; PowerShell 5.1 has no `&&`;
  the golden-number suite is load-bearing. A 40-line `CLAUDE.md` capturing these would
  prevent a whole class of regressions and is near-zero cost. (The user's global
  instructions expect a project `CLAUDE.md` read first each session — its absence means
  that contract currently resolves to `AGENTS.md`, which under-documents the traps.)

- **T1.4 — Incremental / cached pipeline (the runtime problem).** The 243-cell scenario
  grid dominates pipeline runtime (documented 30–60 min). For the *public* MCB refresh
  that's fine (weekly CI). For *client engagements at scale* it's a wall: every re-run
  recomputes everything. The runway plan defers `targets` — correctly, for one book. But
  the moment you run 3–5 banks, a content-hash cache (skip a stage when its inputs +
  config are unchanged) or a `targets` DAG pays for itself. **Recommendation: defer until
  the 2nd or 3rd real engagement**, then adopt `targets` scoped to the grid + TRISK stages
  only (the expensive ones), leaving PACTA as fast pass-through. Don't build it
  speculatively.

## Theme 2 — Methodology objection-closers (P1, decision-critical for a signing bank)

These are the holes a bank's ESG/risk team will find in the first walkthrough. All were
deferred by prior plans and remain open (verified: `engagement_scoring.R:149` still emits
`"N/A - sector not in TRISK pilot"`).

- **T2.1 — Automotive TRISK.** VinFast/THACO carry the demo's *best* alignment story yet
  show "Not assessed" in TRISK, letters, and composite scores (`composite_partial = TRUE`).
  This is the most visible sector hole and the most quoted line in a skeptical review.
  The sector-aware runner + grid infra (once PHASE-03 lands) make it mostly data prep —
  a market-share shock analogous to power. Closing it removes the `composite_partial`
  caveat from the engagement page entirely.
- **T2.2 — Real ABCD sourcing decision brief** (runway PHASE-06 TASK-06-01, currently
  unwritten). A real loanbook must match against *real* asset-based company data;
  `data/vietnam_abcd.csv` is synthetic and MCB-shaped. Asset Impact license vs.
  self-collected (EVN/GENCO reports, Global Energy Monitor trackers, VNSTEEL/VICEM
  disclosures) vs. hybrid — with a per-sector coverage table and a recommendation. This
  is research, not code, and it unblocks the *commercial* conversation before a bank asks
  "where does the company data come from?" **This is arguably the #1 real-engagement
  blocker** — it's in the runway plan but at the very end; consider pulling it forward as
  a parallel research track since it has no code dependency.
- **T2.3 — Steel coverage honesty pass.** ~4% synthetic match coverage makes steel
  outputs decorative. Two-part fix: enrich the synthetic steel book (the demo should model
  what a *good* engagement looks like), and promote a "below reporting threshold" pattern
  into the steel views — real books will also have thin sectors, so this becomes a reusable
  engagement feature rather than a demo apology.
- **T2.4 — NA edge cases (Dung Quat LNG zero-baseline; power-2025 empty bars).** Both
  produce NA rows/blank bars in client-visible outputs — the worst possible artifact in a
  boardroom. Cheap generator/prep-side backfills (runway PHASE-06 TASK-06-04/05). Fix
  regardless of everything else; NAs in a bank deliverable read as "unfinished."
- **T2.5 — Scenario vintage versioning.** PDP8 anchors, NDC targets, and NZE pathways are
  frozen 2023-vintage interpolations inside `data/generate_vietnam_data.R`. A PDP8 revision
  is expected. Move anchors into versioned `data/scenarios/<source>-<year>/` referenced by
  config so "which scenario vintage produced this number" is answerable and auditable
  (runway PHASE-06 TASK-06-03).

## Theme 3 — Analytical outputs that actually change a decision (P2, high storytelling ROI)

These are *new* capability ideas beyond the runway plan — the analytics a risk head
forwards to a CRO.

- **T3.1 — Multi-scenario comparison as a first-class output.** Verified: the current
  Vietnam outputs benchmark against PDP8 primarily; there is **no side-by-side
  PDP8 vs NDC vs NZE traffic-light view** in `synthesis_output/vietnam/`. This was the
  single most-useful artifact named in the *original* 9-week plan (`PROGRESS.md` Week 3:
  "traffic-light table showing which sectors/technologies are aligned, borderline, or
  misaligned under each scenario") and it was never fully built. A sector × scenario
  traffic-light matrix is the one-glance answer an ESG committee wants. **High leverage,
  moderate effort — data already exists, it's a synthesis + view.**
- **T3.2 — Engagement-level executive summary generator.** One page: coverage, top-3
  alignment gaps, top-5 stress borrowers, recommended next steps — the artifact a risk
  head forwards upward. Trivial once `run_engagement.R` exists (it's a report over the
  engagement manifest + outputs). This is the "so what" layer above the diagnostic pages.
- **T3.3 — Refresh-to-refresh delta / "what changed since last quarter."** A returning
  client's first question is "what moved?" A diff view (this run's manifest + key metrics
  vs. the prior committed run) turns the platform from a snapshot tool into a monitoring
  tool — and monitoring is a recurring-revenue narrative, not a one-off-report narrative.
  The `pipeline_manifest.json` already carries `row_counts`; extend it to key alignment/PD
  metrics and render a changed-since-last-run table (the `future_planning_ideas.md`
  reproducibility-report idea, matured).
- **T3.4 — Unified number→source lineage.** Credibility multiplier for a bank: every
  published figure traceable to input file + checksum + scenario vintage + git sha. The
  pieces exist (manifest, audit report, checksums) but are scattered. Unify into a single
  "trace this number" artifact usable live in a client Q&A ("this 76% gap comes from
  file X, scenario PDP8-2023, run SHA abc123"). This is what separates a defensible
  advisory deliverable from a black box.

## Theme 4 — Pilot-facing product polish (P2, "finished in a boardroom")

- **T4.1 — Vietnamese language toggle.** For a *Vietnamese bank's* private instance this
  is the single most visible polish item. Scope honestly (ASM-4A): a `lang=vi` string
  table for page titles, nav, KPI labels, and disclaimers — not chart internals or
  generated reports — covers the walkthrough-meeting need at ~10% of full-i18n cost.
- **T4.2 — PDF export.** Banks circulate PDFs internally; validation report, disclosure
  pack, and audit report are HTML-only. A print-CSS pass + documented browser-print recipe
  (or `pagedown`) is the low-dep answer.
- **T4.3 — Scenario Builder persistence + shareable links.** Saved scenarios die with
  `st.session_state`; deep-link query params already exist — add "copy shareable link" +
  optional file-based save. Converts a workshop session into a durable artifact.
- **T4.4 — Reports page lazy-load.** Four ~350 KB inline iframes load eagerly; gate behind
  expanders/buttons. Cheap page-weight win.

## Theme 5 — Test coverage & repo hygiene (P2, quietly important)

- **T5.1 — Second-book regression fixture** (runway PHASE-05 TASK-05-06). Freeze SDB
  outputs as a second golden set so parameterization can never silently regress to
  "works only for MCB." This is the structural guarantee that Theme 1's refactors are
  safe.
- **T5.2 — Untested dashboard surface.** Pages 6/7 (Intake Wizard, Outputs) have thin
  coverage; derive the grid-size assertion from `grid_meta.json` instead of the hardcoded
  243 in `test_loaders.py`; import Scenario Builder helpers in `test_scenario_builder.py`
  rather than reimplementing them.
- **T5.3 — Housekeeping.** `activeContext.md` is 63 KB of accreted log (per the user's
  own workflow it's meant to be a living plan, not an archive — consider rotating old
  entries to `plans/PROGRESS.md`). No `lessons.md` exists despite the global workflow
  calling for one. `AGENTS.md` is stale (references retired `pacta_demo.R` and a
  `compare/` workflow). Small, but these are the first files a new contributor reads.

## Theme 6 — Commercial completeness (P3)

- **T6.1 — Pricing scaffold.** `{{PRICING_AND_TERMS_PLACEHOLDER}}` is blank. Draft the
  *structure* (fixed-fee intake+validation, per-sector analysis modules, private-instance
  hosting, workshop add-on) so proposals tailor in minutes; numbers stay the owner's call.
- **T6.2 — ABCD intake contract.** `intake/SCHEMA.md` covers only the loanbook. Define
  the minimum ABCD columns + validation for when a bank/data-partner supplies company data
  (runway PHASE-06 TASK-06-02).
- **T6.3 — Recorded walkthrough.** A 5-minute screen recording following
  `docs/demo-script.md` — an async sales asset that survives scheduling failures with
  bank contacts.

---

## Recommended sequencing

| Wave | Contents | Outcome |
|---|---|---|
| **0 — Finish runway** | PHASE-03 → PHASE-06 (existing plan) | One-command engagement run demonstrated on SDB; TRISK chain parameterized; NA bugs fixed; scenario versioning; ABCD brief. **The headline promise becomes real.** |
| **1 — Foundation** | T1.1 PACTA decompose, T1.2 real package, T1.3 CLAUDE.md, T5.1 second-book goldens | Testable, loadable core; refactors become safe and localizable; scale-ready. |
| **2 — Credibility** | T2.1 automotive TRISK, T2.3 steel honesty, T3.1 multi-scenario traffic-light, T3.2 exec summary | The two visible sector holes closed; the one-glance ESG artifact shipped; the CRO one-pager. |
| **3 — Product** | T4.1 VN toggle, T4.2 PDF, T4.3 scenario persistence, T3.3 delta view, T3.4 lineage | Private instance feels finished; monitoring + defensibility narrative. |
| **Opportunistic** | T4.4, T5.2, T5.3, T6.1–T6.3, T1.4 (only at 2nd+ engagement) | Page weight, tests, hygiene, sales assets, caching when runtime actually bites. |

**Rationale:** Wave 0 is non-negotiable and already planned — everything else is built on
the parameterized pipeline it produces, so building Themes 2–5 first would mean building on
code about to change. Wave 1 is the genuinely *new* recommendation this brainstorm adds
beyond the runway plan: the runway parameterized the paths but left the analytical core an
untestable monolith and the "package" a promise. Fixing that is what makes the next ten
engagements cheap instead of each being a fresh archaeology dig. Waves 2–3 are the
credibility and polish that convert a working tool into a boardroom-ready advisory product.

---

## Assumptions adopted (orchestrator unavailable — no questions asked)

- **ASM-0A:** SDB-run friction is fixed with inline guards, not redesign; logged in the
  rehearsal log.
- **ASM-1A:** The PACTA-monolith decompose (T1.1) sequences *after* the runway's PHASE-06
  goldens refreeze, using those goldens as the safety net — not inside the runway.
- **ASM-1B:** The right call on `DESCRIPTION` is to *complete* the package (T1.2 option a),
  not delete it — because multi-bank scale is the stated commercial direction and a loadable
  package is the clean substrate for it.
- **ASM-2A:** Real ABCD sourcing (T2.2) can run as a parallel *research* track immediately
  (no code dependency), rather than waiting for its PHASE-06 slot.
- **ASM-3A:** Multi-scenario traffic-light (T3.1) is treated as a *new* first-class output
  worth building even though it predates the runway plan — it was in the original 9-week
  plan, never shipped, and is the highest-value analytical artifact for an ESG committee.
- **ASM-4A:** VN toggle stays chrome-only (titles/nav/KPI/disclaimers), not chart internals
  or generated reports — extends the prior DEC-007 docs-only compromise.
- **ASM-B (business):** The objective is still "convert a Vietnamese bank prospect into a
  paid real-data pilot, then productize into a repeatable engagement practice." Delivery
  capability and defensibility outrank analytical breadth.

## Out of scope

- Real bank data execution (still requires a signed engagement; fixtures only).
- Any change to the public app's synthetic-data disclaimers.
- Upstream package changes (`r2dii.*`, `trisk.model` pinned via `renv.lock`).
- Multi-tenant SaaS / real auth (per-client stamped private instances cover the first
  engagements).
- New sectors beyond the existing four (oil & gas, aviation) — no Vietnamese-bank pull yet.
- `targets` migration except narrowly scoped to the grid, and only at the 2nd+ real
  engagement (T1.4).

## Suggested next step

Execute the existing runway plan (`plans/2026-07-13-client-engagement-runway-plan.md`,
PHASE-03 → PHASE-06). Once PHASE-06 refreezes goldens, run
`/plan next-level-platform` scoped to **Wave 1 (engineering foundation)** — PACTA
decompose into a tested, loadable `pactatrisk` package plus the project `CLAUDE.md` — as
the first follow-on, with Waves 2–3 as subsequent plans.

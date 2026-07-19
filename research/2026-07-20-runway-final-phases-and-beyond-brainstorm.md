---
title: "Brainstorm: Runway Final Phases (03–05) and What Comes After"
date: "2026-07-20"
status: "final"
mode: "unattended (no questions asked; assumptions recorded below)"
supersedes-in-part: "research/2026-07-18-runway-completion-and-credibility-brainstorm.md (its P0 wave is now half-executed)"
plan_inputs:
  - "plans/2026-07-18-engagement-runway-completion-plan.md (PHASE-03..05 remain authoritative)"
---

# Brainstorm: Runway Final Phases (03–05) and What Comes After

## TL;DR

The 2026-07-18 runway-completion plan is **2/5 phases done and verified**. PHASE-01
(merged TRISK parameterize+decompose → `R/trisk_core.R` + `R/prioritization_core.R`,
commit `d299496`) and PHASE-02 (snapshot/scoring/letters/disclosure config-driven,
commit `408e95c`) landed with the byte-identity acceptance bar met and both test
suites green **(verified today: R 171 passed / 0 failed; Python 58/58 passed)**.

The single highest-value move is unchanged and now cheaper than planned: **execute
PHASE-03 → 05 of the existing plan** — the `run_engagement.R` orchestrator, the SDB
end-to-end dress rehearsal with a second golden fixture, and the data closers. No new
plan is needed; the plan text is already at acceptance-bar specificity. Everything
else in this document is sequenced *after* that, because building analytics or polish
on a runway that stops one phase short of "one command, any bank" would repeat the
exact mistake the last two brainstorms warned about.

Two genuinely new engineering ideas surfaced by this pass: **(N1) codify the
byte-identity verification as a repo tool** (both phase commits hand-rolled the same
git-diff-based check; PHASE-03/04/05 and every future refactor need it again), and
**(N2) neutralize the known run_id/run_path volatility at the wrapper level** so
future byte-identity checks and the SDB goldens don't have to carry a volatile-file
exclusion list forever.

## Verified current state (2026-07-20)

Checked directly this session, not inherited from prior docs:

- **Done and committed:** `R/trisk_core.R`, `R/prioritization_core.R` exist; the four
  TRISK/prioritization scripts are thin CLI wrappers; all four downstream generators
  (`refresh_dashboard_data.R`, `engagement_scoring.R`, `generate_engagement_letters.R`,
  `generate_disclosure_pack.R`) accept `--config` with byte-identical default mode;
  `tests/testthat/test_trisk_core.R` (21 unit tests) and `test_config_paths.R`
  (subprocess smoke tests) exist.
- **Not yet built (PHASE-03..05 scope):** `R/step_runner.R`, `scripts/run_engagement.R`,
  `engagements/sdb-rehearsal/`, `tests/testthat/test_step_runner.R`,
  `test_sdb_engagement.R`, `docs/abcd_sourcing_decision.md`, `data/scenarios/`,
  ABCD section in `intake/SCHEMA.md`, package version still 0.1.0 / no `NEWS.md`.
- **Test state:** full R suite 171/171 green; Python dashboard suite 58/58 green
  (including `test_auth.py`, which the phase-2 commit documents as an occasional
  environmental flake — see H3).
- **Volatility knowledge (from phase-1 commit, empirically established):** five TRISK
  CSVs (`company_trajectories_latest.csv`, `npv_results_latest.csv`,
  `params_latest.csv`, `pd_results_latest.csv`, `run_catalog.csv`) differ between
  identical runs only in a `run_id`/`run_path` UUID that `trisk.model::run_trisk()`
  regenerates per invocation. Byte-identity checks must use autocrlf-aware `git diff`,
  not raw md5sum (Windows line-ending churn).
- **Head start on PHASE-05:** `backfill_zero_baseline()` is already written and
  unit-tested in `R/trisk_core.R` — it just isn't wired into the prepare-inputs path.
  The Dung Quat fix (TASK-05-04) is therefore mostly a wiring + rerun + refreeze task.
- **Hygiene deltas since the 07-18 brainstorm:** `Rplots.pdf` is now gitignored and
  `data/data/` is gone (both fixed); `compare/` (17 files) is still tracked;
  `plans/PROGRESS.md` is still stale; `activeContext.md` is still an ~880-line
  accreted log frozen at Session-6-era structure; no `lessons.md` exists.

## P0 — Execute PHASE-03 → 05 of the existing plan (do not re-plan)

The plan (`plans/2026-07-18-engagement-runway-completion-plan.md`) remains
authoritative; its task text, binding defaults (ASM-001..011), and exit criteria need
no revision. What this pass adds is *execution intelligence* learned from phases 1–2:

- **P0.1 — PHASE-03 orchestrator.** Extract `R/step_runner.R` from
  `pipeline_refresh.R` (manifest schema locked by `test_manifest_json.R` /
  `test_manifest.py`), build `scripts/run_engagement.R` with `--dry-run` and the
  public-snapshot guard rail, bump the package to 0.2.0 with regenerated `NAMESPACE`
  and a `NEWS.md`. Nothing learned in phases 1–2 changes this tasking; the
  script-chaining decision (plan ALT-002) stands.
- **P0.2 — PHASE-04 SDB rehearsal.** One execution-order note: run N1 (the
  verification tool below) *first* so the cross-contamination check
  (`git status --porcelain synthesis_output output dashboard/data reports` → empty)
  and the byte-identity check are one command each. Expect the zero-match guards to
  land in `R/pacta_core.R`/`R/trisk_core.R` behind emptiness checks MCB never enters.
- **P0.3 — PHASE-05 closers.** Two effort downgrades vs. plan text: TASK-05-04 (Dung
  Quat) is wiring an existing tested helper, and TASK-05-01/02 (ABCD brief + intake
  contract) have zero code dependencies — write them in parallel with PHASE-03 rather
  than serially at the end (the 07-18 brainstorm's ASM-B, still unexecuted, still
  right: the ABCD sourcing decision gates the *commercial* conversation with any real
  bank and is pure research).

## N — New engineering ideas from this pass (small, high-leverage)

- **N1 — `tools/verify_refactor.R`: codify the acceptance check.** Both phase commits
  independently hand-rolled the same verification: full default-mode refresh →
  autocrlf-aware `git diff` → classify drift into {intentional edits, PNG noise,
  timestamp text, known-volatile run_id files}. PHASE-03 (manifest compatibility),
  PHASE-04 (cross-contamination), PHASE-05 (golden refreeze diff inspection), and
  every future refactor need exactly this again. A ~60-line script that runs the
  refresh, diffs, filters the known-volatile list, and prints PASS/DRIFT would turn a
  half-day of careful manual diffing per phase into one command — and make the
  acceptance bar mechanically enforceable by CI later. Effort: small. Do it before
  PHASE-03.
- **N2 — Neutralize run_id volatility at the wrapper.** The five volatile TRISK CSVs
  force every byte-identity check and potentially the SDB goldens to carry an
  exclusion list. Since the differing column is pure provenance noise
  (`run_id`/`run_path` UUID from `trisk.model`), have `write_trisk_demo_outputs()`
  (already ours, in `R/trisk_core.R`) rewrite those columns to a deterministic value
  (e.g. constant `"local"` or a hash of the input params) *at write time*. Upstream
  package untouched; default-mode CSVs change once (one-time refreeze, ideally folded
  into the PHASE-05 refreeze that is happening anyway); volatility list retired
  forever. Effort: small. **Timing assumption (ASM-i):** fold into PHASE-05's golden
  refreeze commit so the suite is only refrozen once.
- **N3 — CI runs the SDB engagement weekly too.** Once PHASE-04 lands, add the SDB
  `run_engagement.R` invocation (grid off, ~minutes not hours) to the Monday refresh
  workflow or a parallel job, gated by `test_sdb_engagement.R`. This makes the
  "works only for MCB" regression guard *continuous* instead of only-when-someone-runs-
  the-suite. Effort: small, after PHASE-04.
- **N4 — Engagement scaffolding command.** `scripts/new_engagement.R --slug x-bank
  --name "X Bank"` that stamps out `engagements/<slug>/engagement_config.json` with
  all paths rooted under `engagements/<slug>/` (the PHASE-04 SDB config is the
  template — today it must be hand-written, and a hand-typo in `snapshot_dir` is
  exactly the cross-contamination class the guard rail exists for). Effort: small,
  after PHASE-04 proves the config shape.

## P1 — Credibility analytics (carried from 07-18, all effort classes now lower)

Unchanged in content, re-ordered only where phases 1–2 changed the cost:

- **P1.1 — Multi-scenario traffic-light matrix** (sector × {PDP8, NDC, NZE}).
  Still the highest-ROI unbuilt analytics artifact; data exists; one synthesis CSV +
  one dashboard view.
- **P1.2 — Executive summary generator.** Now explicitly a report over
  `pipeline_manifest.json` + `engagement_priority.csv`; trivial once PHASE-03's
  orchestrator emits per-engagement manifests. (Swapped ahead of automotive TRISK
  because its dependency lands in P0 and its effort is days not weeks.)
- **P1.3 — Automotive TRISK.** With `trisk_core.R` live this is data prep (market-
  share shock for VinFast/THACO analogous to power) + one `sector_specs` row;
  removes the `composite_partial` asterisk from engagement scoring.
- **P1.4 — Steel honesty pass** (enrich synthetic steel book + reusable
  "below reporting threshold" pattern).
- **P1.5 — Number→source lineage** ("trace this number": manifest + checksums +
  scenario vintage + git SHA in one lookup). Note PHASE-05's scenario-checksum audit
  work builds the first third of this.
- **P1.6 — Refresh-to-refresh delta view** (key metrics in the manifest, "what
  changed since last run" panel) — the monitoring/recurring-revenue narrative.

## P2 — Product polish for the private instance (unchanged)

- **P2.1** Vietnamese chrome-only language toggle. **P2.2** PDF export via print CSS.
- **P2.3** Scenario Builder shareable links/persistence. **P2.4** Reports page
  lazy-load (four ~350 KB eager iframes → expanders).

## P3 — Package & platform maturation

- **P3.1 — Version discipline: lands inside PHASE-03** (0.2.0 + `NEWS.md` are plan
  tasks) — no longer a separate item.
- **P3.2 — Clean `R CMD check`** pass after P0 (`@importFrom` question, allowed-
  failures budget in CI). Defensibility for bank/partner technical due diligence.
- **P3.3 — `targets`-scoped grid caching** — still trigger-deferred to the 2nd–3rd
  real engagement.
- **P3.4 — `lintr` in CI** — opportunistic only.

## H — Hygiene (updated statuses)

- **H1 — Done since 07-18:** `Rplots.pdf` gitignored; stray `data/data/` removed.
- **H2 — Still open:** `plans/PROGRESS.md` stale (mark "historical snapshot" or move
  to `attic/`); `compare/` (17 tracked files, 2026-02 era) → `attic/` per the
  established retirement pattern; `activeContext.md` is an ~880-line accreted log —
  rotate completed session entries into an archive file and keep a short living
  header; create `lessons.md` (the user's global workflow expects it; seed it with
  the two hard-won phase-1/2 lessons: git-diff-not-md5sum for byte identity, and the
  `file.path(getwd(), ...)` absolute-path double-join bug class).
- **H3 — Test nits:** `dashboard/tests/test_auth.py` hardcodes a 3 s Streamlit
  AppTest timeout (documented flake; bump to ~15 s or make it env-tunable);
  `dashboard/tests/test_loaders.py:66` hardcodes `243` instead of deriving from
  `grid_meta.json`.
- **H4 — Doc drift risk:** once `run_engagement.R` exists, `README.md` gains the
  engagement-run section (plan TASK-03-06) — also sweep `AGENTS.md` and
  `docs/demo-script.md` for the new one-command story at the same time.

## Recommended sequencing

| Wave | Contents | Outcome |
|---|---|---|
| **0 (now)** | N1 verify tool → PHASE-03 → PHASE-04 (then N3, N4) → PHASE-05 (fold N2 into its refreeze); ABCD brief (TASK-05-01/02) written in parallel from day one | "One command, any bank" demonstrated; second golden fixture guards it; volatility list retired |
| **1** | P1.1 traffic-light, P1.2 exec summary, P1.3 automotive TRISK, P1.4 steel | Committee-facing methodology holes closed |
| **2** | P1.5 lineage, P1.6 delta view, P2.1–P2.3 | Defensibility + monitoring narrative |
| **Opportunistic** | P2.4, P3.2, P3.4, H2–H4 | Hygiene and package maturity |
| **Trigger-deferred** | P3.3 `targets` caching (2nd–3rd real engagement) | Runtime cost paid when it bites |

**Rationale.** Three consecutive planning cycles have converged on the same
conclusion and phases 1–2 validated it empirically: the byte-identity + verbatim-move
discipline works, is cheap when the code is touched once, and every downstream
feature drops an effort class after the core lands. The remaining runway phases are
the last structural work; everything after is additive. The only novel structural
recommendations this cycle (N1/N2) exist purely to make the *remaining* phases and
all future refactors cheaper and to retire the one wart (volatile run IDs) that
phases 1–2 discovered but could not fix mid-flight.

## Assumptions adopted (unattended — no questions asked)

- **ASM-i:** N2 (deterministic run IDs) is folded into PHASE-05's already-planned
  golden refreeze so committed CSVs are refrozen exactly once. If PHASE-05 were
  descoped, N2 would wait for the next planned refreeze rather than forcing one.
- **ASM-ii:** N1's verification tool lives at `tools/verify_refactor.R` (new `tools/`
  top-level dir; `scripts/` is reserved for pipeline stages by convention) and is
  dev-tooling — no new pipeline dependency, plain base-R + `system2("git", ...)`.
- **ASM-iii:** The prior brainstorm's binding defaults all carry forward (JSON
  configs, MCB as no-flag default, byte-identity acceptance, grid opt-in per
  engagement, synthetic-data disclaimers untouchable, no real bank data before a
  signed engagement).
- **ASM-iv:** Business objective unchanged: convert a Vietnamese bank prospect into
  a paid real-data pilot; delivery capability and defensibility outrank analytical
  breadth. (No user input this session; inherited from ASM-D of 07-18.)
- **ASM-v:** No re-plan is issued for PHASE-03..05 — the existing plan text is at
  acceptance-bar specificity and re-planning would be pure overhead. N1–N4 are small
  enough to execute as tasks alongside the phases they attach to.

## Out of scope (unchanged)

Real bank data execution; multi-tenant SaaS/auth; sectors beyond the existing four +
automotive; upstream package changes (`r2dii.*`, `trisk.model` pinned); full i18n.

## Suggested next step

Execute PHASE-03 of `plans/2026-07-18-engagement-runway-completion-plan.md`, preceded
by the ~60-line N1 verification tool, with the ABCD sourcing brief (TASK-05-01)
started the same day as a parallel research track.

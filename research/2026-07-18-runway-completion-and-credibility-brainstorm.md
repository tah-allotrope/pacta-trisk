---
title: "Next Level: Finish the Engagement Runway on the New Foundation, Then Buy Credibility"
date: "2026-07-18"
type: "brainstorm"
depth: "thorough"
source_request: "Analyze current state, brainstorm improvements/features/refactors/architecture/optimizations to take pacta-trisk to the next level"
slug: "runway-completion-and-credibility"
predecessor: "research/2026-07-16-next-level-platform-brainstorm.md"
mode: "unattended — assumptions adopted, no questions asked"
---

# Brainstorm: Runway Completion & Credibility

## TL;DR

Since the 2026-07-16 brainstorm, **Wave 1 (engineering foundation) shipped in full**
— commits `fd6b112` → `4affc00` delivered the repo laws (`CLAUDE.md`), the PACTA
monolith decompose (`R/pacta_core.R`, 1,431 lines of pure functions; the script is now
a 115-line wrapper), and a genuinely loadable `pactatrisk` package (`NAMESPACE`,
`man/`, `tests/testthat.R`, CI package-load gate). The full R suite (8 test files
incl. `test_pacta_core.R`) and both CI workflows are green-configured.

**What did NOT happen: Wave 0.** The client-engagement-runway plan
(`plans/2026-07-13-client-engagement-runway-plan.md`) is still only 2/6 phases done.
Verified in today's working tree:

- Only `scripts/pacta_vietnam_scenario.R` reads the engagement config. The entire
  TRISK chain (`trisk_prepare_inputs.R`, `trisk_sector_demo.R`,
  `trisk_scenario_grid.R`), `sector_prioritization.R`, `engagement_scoring.R`,
  `refresh_dashboard_data.R`, and the letter/disclosure generators still hardcode
  MCB paths (e.g. `trisk_prepare_inputs.R:30-32`).
- `scripts/run_engagement.R` and `R/step_runner.R` **do not exist**.
- `engagements/` contains only `mcb-demo/`; no SDB rehearsal engagement, no second
  golden fixture (`test_sdb_engagement.R` absent).
- `data/scenarios/` and `docs/abcd_sourcing_decision.md` **do not exist**.
- `scripts/engagement_scoring.R:149` still emits `"N/A - sector not in TRISK pilot"`
  (automotive hole intact).

So the platform's headline promise — *"run PACTA + TRISK on a new bank's loanbook in
one command"* — remains half-built, but the ground it will be built on is now solid.
**The single highest-value move is to execute runway PHASE-03 → PHASE-06 now, with
one deliberate upgrade: fold the TRISK-chain decompose (the `R/trisk_core.R`
follow-on the foundation plan deferred) INTO the runway's PHASE-03 parameterization,
so the ~1,300 lines of TRISK scripts are touched once, not twice.** That merge is the
main new recommendation of this brainstorm; everything else is prioritized backlog.

---

## Verified current state (2026-07-18)

**Mature and working**

| Layer | Evidence |
|---|---|
| Public demo | 7-page Streamlit app (3 operator-gated), frozen 3 MB snapshot `dashboard/data/`, live at pactavn.streamlit.app |
| Reproducibility | `renv.lock` (now incl. `devtools`/`roxygen2`), 8 R test files (golden numbers, snapshot contract, manifest, intake fixture, matching, config, **pacta_core**), 9 pytest files, `ci.yml` (py + R + package-load gate), `refresh.yml` weekly test-gated auto-commit |
| PACTA core | `R/pacta_core.R` — 9 pure functions, unit-tested; `scripts/pacta_vietnam_scenario.R` is a 115-line orchestration wrapper; byte-identical MCB acceptance held |
| Package | `pactatrisk 0.1.0` loads via `devtools::load_all()`; `NAMESPACE` + `man/` generated; `DESCRIPTION` Imports real |
| Config substrate | `R/engagement_config.R` + `R/sector_registry.R` + `engagements/mcb-demo/` (runway PHASE-01/02) |
| Laws | Root `CLAUDE.md` codifies VND-never-rescale, run-from-root, byte-identity bar, diacritics, golden tests, PS5.1 |
| Intake | SDB dirty-fixture validation + anonymization rehearsed (`intake/`, `pilot/rehearsal_log.md`) |

**The gap (unchanged since 2026-07-16)**

1. One-command engagement run (runway PHASE-03–06) — **the** undemonstrable proposal
   promise.
2. Methodology objection-closers: automotive TRISK, steel ~4% coverage, Dung Quat
   LNG / power-2025 NA artifacts, scenario vintage versioning.
3. Real-ABCD sourcing decision — the #1 real-engagement blocker; pure research, zero
   code dependency, still unwritten.
4. Analytical "so what" layer: no PDP8-vs-NDC-vs-NZE traffic-light, no exec summary,
   no run-over-run delta.
5. Product polish: VN language toggle, PDF export, scenario persistence.

---

## P0 — Execute the runway (PHASE-03 → 06), upgraded by the new foundation

The plan exists and is specified to acceptance-bar level. What's *new* is that the
foundation work changes how PHASE-03/04 should be executed:

- **P0.1 (new recommendation) — Merge TRISK parameterization with TRISK decompose.**
  The runway's PHASE-03 threads `cfg` paths through `trisk_prepare_inputs.R` (392
  lines), `trisk_sector_demo.R` (491), `trisk_scenario_grid.R` (431),
  `sector_prioritization.R` (363) — and the foundation plan separately queued "TRISK
  decompose using the pacta_core pattern" as a follow-on. Doing them as two passes
  means rewriting the same sections twice under the same byte-identity gate (the
  exact double-touch the 2026-07-13 brainstorm warned about for PACTA). Instead:
  extract `R/trisk_core.R` functions (`trisk_prepare_sector_inputs(cfg, sector)`,
  `trisk_run_sector(cfg, sector)`, `trisk_run_grid(cfg, sector)`,
  `prioritize_sectors(cfg)`) with `cfg` as a parameter from birth. Same verbatim-move
  discipline (ASM-002 of the foundation plan), same MCB byte-identity acceptance.
  One pass, two debts retired. **ASM-A adopted: this supersedes the runway plan's
  literal PHASE-03 tasking; the plan's *acceptance criteria* stay authoritative.**
- **P0.2 — `run_engagement.R` + `R/step_runner.R` (runway PHASE-04) as package
  functions.** With `pactatrisk` now loadable, the orchestrator should call
  `pactatrisk::` functions rather than `source()`-chaining scripts — the scripts
  remain thin CLI shims. `pipeline_refresh.R`'s manifest schema must not change
  (CON-004 of the runway plan).
- **P0.3 — SDB end-to-end dress rehearsal + second golden fixture (PHASE-05).** This
  is the structural guarantee against "works only for MCB" regressions, and the
  demonstrated-capability artifact the pilot proposal cites. Friction found during
  the run is the deliverable — log it in `pilot/rehearsal_log.md`, fix with inline
  guards, don't redesign (ASM-0A carried forward).
- **P0.4 — PHASE-06 closers:** `docs/abcd_sourcing_decision.md`, ABCD intake schema,
  `data/scenarios/pdp8-2023/` versioning, Dung Quat + power-2025 NA fixes, golden
  refreeze. **ASM-B adopted (carried from 2026-07-16 ASM-2A): start the ABCD
  sourcing brief immediately in parallel — it's research-only and gates the
  commercial conversation.**

## P1 — Credibility: the analytics a bank's committee actually asks for

Carried forward from the prior brainstorm's Wave 2, still fully open, ordered by
objection-frequency:

- **P1.1 — Multi-scenario traffic-light matrix** (sector × {PDP8, NDC, NZE} with
  aligned/borderline/misaligned cells). Named the single most useful artifact in the
  original 9-week plan (`plans/PROGRESS.md` Week 3), never built. Data exists;
  it's a synthesis + one dashboard view + one CSV. Highest analytics ROI in the repo.
- **P1.2 — Automotive TRISK.** VinFast/THACO show "Not assessed" in the demo's best
  sector; removes `composite_partial` from engagement scoring. After P0.1, this is
  mostly data prep (market-share shock analogous to power).
- **P1.3 — Executive summary generator.** One page over the engagement manifest:
  coverage, top-3 gaps, top-5 stress borrowers, next steps. Trivial once
  `run_engagement.R` exists; the artifact a risk head forwards to the CRO.
- **P1.4 — Steel honesty pass.** Enrich the synthetic steel book *and* add a
  reusable "below reporting threshold" pattern for thin sectors.
- **P1.5 — Number→source lineage ("trace this number").** Manifest + checksums +
  scenario vintage + git SHA unified into one lookup artifact for live client Q&A.
- **P1.6 — Refresh-to-refresh delta view.** Extend `pipeline_manifest.json` with key
  alignment/PD metrics; render "what changed since last run." Turns a snapshot tool
  into a monitoring (recurring-revenue) tool.

## P2 — Product polish for the private instance

- **P2.1 — Vietnamese language toggle** (chrome-only scope: nav, titles, KPI labels,
  disclaimers — ASM-4A carried forward).
- **P2.2 — PDF export** via print-CSS + documented browser-print recipe (no new deps).
- **P2.3 — Scenario Builder persistence + shareable links** (query params exist;
  add copy-link + file-based save).
- **P2.4 — Reports page lazy-load** (four ~350 KB eager iframes → expanders).

## P3 — Package & platform maturation (new items surfaced by the foundation work)

- **P3.1 — Clean `R CMD check`.** ASM-005 accepted WARNINGs/NOTEs; a follow-up pass
  (`@importFrom` migration, or `check()` in CI with allowed-failures budget) makes
  the package defensible to a technical reviewer at a bank/partner. Defer until
  after P0 — same files.
- **P3.2 — `targets`-scoped caching for the 243-cell grid** — still deferred until
  the 2nd–3rd real engagement (T1.4 carried forward). The decompose has made this
  adoption nearly mechanical when the time comes.
- **P3.3 — Version discipline.** Bump `pactatrisk` to 0.2.0 when `trisk_core.R`
  lands; start a `NEWS.md`. Cheap, signals engineering maturity to due-diligence.
- **P3.4 — R linting in CI** (`lintr` with a lenient config) — opportunistic only.

## P4 — Hygiene (new findings from today's pass)

- **P4.1 — Stale front-door docs.** `plans/PROGRESS.md` is dated 2026-03-21 and
  describes `pacta_demo.R`/`pacta_synthesis.R` as current (they're in `attic/`) —
  it contradicts `CLAUDE.md`'s law file. Either mark it "historical snapshot" in a
  header or rotate it to `attic/`. `activeContext.md` is a 63 KB accreted log, last
  touched 2026-06-11 — rotate completed entries out; keep it a living plan. No
  `lessons.md` exists despite the user's global workflow expecting one.
- **P4.2 — Stray artifacts.** Empty `data/data/` directory (untracked, delete);
  `Rplots.pdf` at repo root (untracked ggplot device residue — add to `.gitignore`);
  `compare/` (AI-vs-staff comparison, 2026-02 era) and root `output/` samples are
  still tracked — candidates for `attic/` per the established retirement pattern.
- **P4.3 — Test-suite nits (T5.2 carried forward).** `dashboard/tests/test_loaders.py:66`
  hardcodes `243` instead of deriving from `grid_meta.json`; pages 6/7 coverage thin;
  Scenario Builder tests reimplement helpers instead of importing them.

---

## Recommended sequencing

| Wave | Contents | Outcome |
|---|---|---|
| **0 (now)** | P0.1 TRISK parameterize+decompose merged pass → P0.2 orchestrator → P0.3 SDB run + 2nd goldens → P0.4 closers; **P0.4's ABCD brief starts immediately in parallel** | The headline one-command promise becomes demonstrated; TRISK debt retired in the same pass |
| **1** | P1.1 traffic-light, P1.3 exec summary, P1.2 automotive TRISK, P1.4 steel | The visible methodology holes closed; the one-glance ESG artifact and CRO one-pager shipped |
| **2** | P1.5 lineage, P1.6 delta view, P2.1–P2.3 | Defensibility + monitoring narrative; private instance boardroom-ready |
| **Opportunistic** | P2.4, P3.1, P3.3, P3.4, P4.1–P4.3 | Hygiene, package maturity, page weight |
| **Deferred trigger-based** | P3.2 `targets` grid caching (at 2nd–3rd real engagement) | Runtime cost paid only when it bites |

**Rationale.** The foundation was built precisely so the runway could be finished
safely and cheaply — building P1/P2 first would repeat the original mistake of
polishing on top of code slated for parameterization. The one genuinely new insight
this cycle: the TRISK decompose and TRISK parameterization are the *same* lines of
code, so they must be one pass (P0.1). After Wave 0, every P1 item drops in effort
class (automotive TRISK: "mostly data prep"; exec summary: "a report over the
manifest").

## Assumptions adopted (unattended — no questions asked)

- **ASM-A:** Runway PHASE-03 is executed as a merged parameterize+decompose pass
  producing `R/trisk_core.R` (pacta_core pattern, verbatim moves, byte-identical MCB
  CSVs). The runway plan's phase *acceptance criteria* remain authoritative; its
  literal task text is superseded where it predates the foundation refactor.
- **ASM-B:** The ABCD sourcing brief (runway TASK-06-01) starts immediately as a
  parallel research track rather than waiting for its PHASE-06 slot (no code
  dependency; it gates the commercial conversation).
- **ASM-C:** `run_engagement.R` orchestrates via loaded `pactatrisk::` functions,
  with scripts kept as thin CLI shims — consistent with the package investment;
  default-mode manifest schema unchanged (runway CON-004).
- **ASM-D:** Business objective unchanged: convert a Vietnamese bank prospect into a
  paid real-data pilot, then productize a repeatable engagement practice. Delivery
  capability and defensibility outrank analytical breadth.
- **ASM-E:** All prior binding defaults carry forward (JSON-not-yaml configs, MCB as
  no-flag default, byte-identity acceptance, grid opt-in per engagement, synthetic
  disclaimers untouchable).

## Out of scope

- Real bank data execution (fixtures only until a signed engagement).
- Multi-tenant SaaS / real auth; new sectors beyond the existing four + automotive.
- Upstream package changes (`r2dii.*`, `trisk.model` stay pinned).
- Full-i18n (chart internals / generated reports) — chrome-only VN toggle only.

## Suggested next step

Run `/plan` scoped to Wave 0: "Complete the client-engagement runway on the package
foundation — merged TRISK parameterize+decompose (`R/trisk_core.R`), downstream
generator parameterization, `run_engagement.R` orchestrator, SDB end-to-end run with
second golden fixture, and the PHASE-06 closers," citing this brainstorm and the
2026-07-13 runway plan as inputs. Start the ABCD sourcing brief as a parallel
research task the same day.

---
title: "GTB 2026–2027 Middle-Tier Gap Closers: SLL Screening, Target Registry, Client-Neutral Reporting, Workshop Kit"
date: "2026-08-11"
type: "brainstorm"
depth: "standard"
source_request: "Close the middle-tier gaps in reports/2026-08-11-gtb-2026-drive-repo-readiness.html — the commitments that are neither already built nor out of scope, across both banks (BIDV MoU and Techcombank concept note)"
slug: "gtb-middle-tier-gap-closers"
predecessor: "research/2026-07-13-client-engagement-runway-brainstorm.md"
---

# Brainstorm: GTB 2026–2027 Middle-Tier Gap Closers

## Problem & Why Now

Two client documents on Drive — the BIDV MoU 2026-2027 v2 (edited 2026-08-11, funding confirmed, near signature) and the Techcombank concept note v2 (2026-08-05, under review) — commit Allotrope to a set of deliverables. A mapping against this repo (`reports/2026-08-11-gtb-2026-drive-repo-readiness.html`) sorted those commitments into three tiers: already built, structurally absent (PCAF financed-emissions accounting), and a **middle tier where the machinery exists but is pointed at the wrong thing**.

This brainstorm covers only that middle tier. Four workstreams:

- **(A) SLL client-readiness screening.** BIDV commits to a "client readiness screening framework" and a "shortlist of up to three priority clients". `scripts/engagement_scoring.R` already ranks borrowers — but on transition-risk severity, which answers "who is most exposed", not "who can we actually write a sustainability-linked loan with".
- **(B) Sector/hotspot prioritization reporting.** Exists and is config-wired, but the client-facing report generator is BIDV-hardcoded, and three documents still describe the pre-Wave-2 min-max scoring world.
- **(C) Sector-level interim target setting.** Shared between BIDV ("updated net zero transition roadmap") and TCB (Output 1.3, "sector-level interim emission reduction targets"). Nothing in the repo expresses a target as a governance object.
- **(D) Capacity building and knowledge products.** BIDV's virtual workshop for smaller Vietnamese banks; TCB Outputs 3.1 and 3.2.

Why now: the program period starts Q4 2026, and the BIDV MoU is close enough to signature that its named outcomes stop being aspirational.

## Current vs Desired State

- **Current state.** Wave 2 closed 2026-08-08 (`7ce3dc8`, golden freeze 0.4.0, 404 R tests green). Two engagements run end to end through one orchestrator. Borrower scoring uses absolute severity anchors (`R/severity_scoring.R`, `docs/scoring_anchors.md`), not min-max. But: the borrower composite is inline script code with no function boundary; scoring weights are CLI-only and unreachable through `run_engagement.R`; templates hardcode "Mekong Commercial Bank"; `pacta_sda()` bypasses `target_sda()` so cement and steel have no portfolio-anchored target; and three artifacts still publish the pre-Wave-2 numbers.
- **Desired state.** Each of the four commitments has a named artifact that can be demonstrated on the synthetic MCB book and re-run on a real loanbook without code changes — reached additively, with `engagement_priority.csv` and the PACTA core left byte-identical.
- **Key repo surfaces.**
  - Scoring: `scripts/engagement_scoring.R`, `R/severity_scoring.R`, `docs/scoring_anchors.md`, `output/engagement/engagement_priority.csv` (15 cols)
  - Prioritization: `scripts/sector_prioritization.R`, `R/prioritization_core.R`, `synthesis_output/prioritization/`
  - PACTA targets: `R/pacta_core.R` (`pacta_market_share`, `pacta_sda`, `pacta_alignment_gaps`), `synthesis_output/vietnam/04_vn_ms_portfolio.csv`, `05_vn_sda_portfolio.csv`, `06_vn_*_alignment_2030.csv`
  - Config: `R/engagement_config.R`, `scripts/run_engagement.R`, `scripts/new_engagement.R`, `engagements/*/engagement_config.json`
  - Templates: `templates/engagement/{letter_template.html, engagement_prompt_templates.csv}`, `templates/disclosure/disclosure_sections.md`
  - Reporting: `scripts/generate_bidv_report.R` (1,034 ln, config-blind), `docs/bidv_*.md`, `R/report_toolkit.R`
  - Teaching assets: `intake/SCHEMA.md` + `intake/templates/` (bilingual), `docs/PACTA_Beginner_Guide.md`, `docs/demo-script.md`, `dashboard/pages/5_Scenario_Builder.py`, anonymize path in `scripts/generate_disclosure_pack.R`
  - Gates: `tools/verify_refactor.R`, `tests/testthat/test_golden_numbers.R`, `tests/testthat/test_sdb_engagement.R`

## Resolved Decisions

- **DEC-001:** Build for "demonstrable now, real-ready later" — every artifact must be showable on the synthetic MCB book, built behind the engagement-config seam so the same code runs on a real loanbook. — credibility in the room without a demo-only dead end.
- **DEC-002:** Target the Q4 2026 program start. — enough runway to build complete layers rather than thin slices, so long as each lands demonstrable.
- **DEC-003:** The SLL readiness screen is a **new downstream script** — `scripts/sll_readiness.R` reads `engagement_priority.csv` as feedstock, sources `R/severity_scoring.R` for the anchor primitives, and writes `sll_readiness.csv` + a shortlist HTML. — purely additive: trips neither the golden tests nor the byte-identity gate. Accepted cost: two scoring paths that must be kept from drifting.
- **DEC-004:** The screen scores four dimensions: transition materiality (reuse `severity_alignment` + `severity_trisk`), ticket size / exposure (`exposure_vnd`, which the borrower composite deliberately ignores), data availability / KPI observability (ABCD match coverage + a per-sector KPI-feasibility table), and relationship signals. — the first three are free from existing columns; the fourth is the real-world predictor of whether an SLL closes.
- **DEC-005:** Relationship signals arrive via an **optional overlay CSV** at a config-declared path, joined on `name_abcd`. Absent (as on MCB) → the dimension drops and remaining weights renormalize, flagged by a `readiness_partial` column. — mirrors the existing `composite_partial` convention for automotive's missing TRISK, so both the pattern and the honesty precedent already exist.
- **DEC-006:** The tool ranks, bands (reusing the `classify_band()` pattern), and emits a **qualified pool**; the analyst selects the three and the rationale is recorded in the output. — defensible to the client without a synthetic-anchored score making a commercial client-selection decision.
- **DEC-007:** Build **real SDA convergence for cement and steel**, so all four sectors carry portfolio-anchored interim targets. — cement is BIDV's largest financed-emissions sector (5.84 MtCO₂e in the Jan 2026 assessment); a target set excluding it guts the deliverable. `attic/pacta_demo.R:350` and `attic/pacta_synthesis.R:427` hold reference `target_sda()` implementations (reference only — `attic/` is do-not-touch).
- **DEC-008:** The target layer's primary artifact is a **target registry CSV** — sector, metric, unit, baseline year/value, target year/value, scope, method, scenario vintage, status — rendered by the roadmap report, the disclosure pack's Metrics & Targets section, and any client deck. — makes "which scenario vintage produced this target" answerable, and fixes a section that currently calls its own targets illustrative.
- **DEC-009:** Reconciling the three stale artifacts is a **blocking prerequisite**, done first. `docs/bidv_sector_prioritization_methodology.md` (§2.1–2.3 min-max formulas, §9 results), `synthesis_output/prioritization/interpretation_notes.md`, and `scripts/generate_bidv_report.R:587` ("scoring maximum (1.0)") all publish Power 1.000 / Steel 0.158 Low / Cement 0.011 Low; the code now produces power 0.863 Critical, steel 0.646 High, cement 0.556 High. — the qualitative story inverted; any sector deliverable currently ships the contradicted version.
- **DEC-010:** SDA convergence lives in a **new downstream module** (`R/target_setting.R` + `scripts/generate_targets.R`) reading `05_vn_sda_portfolio.csv` and the scenario CSV; `pacta_sda()` stays frozen. — fixing the core would change cement/steel `gap_pct`, which feeds the A2 severity anchors and cascades into `engagement_priority.csv` and the sector ranking. Accepted cost: a stated duality — alignment gaps measured against the scenario benchmark, targets computed by convergence — which needs one explicit sentence in the methodology.
- **DEC-011:** Add a `{{bank_name}}` token and keep **one shared template set**; strip the "Mekong Commercial Bank" literals from all four sector rows of `engagement_prompt_templates.csv` and from `disclosure_sections.md`. — `cfg$bank_name` already flows into chart titles, and the existing residual-token guard fails the run on any literal missed.
- **DEC-012:** **Parameterize** `generate_bidv_report.R` rather than rewriting it: add `--config`, replace literals with `cfg$bank_name`, and split its six source docs into client-neutral methodology plus a per-engagement content overlay. — reuses 1,034 lines of working assembly code and the framework comparison, which is already neutral at the methodology level.
- **DEC-013:** Add **weight keys to the engagement config schema** with defaults that reproduce today's numbers exactly, and have `run_engagement.R` forward them. — unblocks per-bank weighting for both (A) and (B) without stepping outside the orchestrator; trips no gate while defaults hold.
- **DEC-014:** The capacity-building deliverable is a **workshop kit assembled from existing assets** — a `workshop/` directory sequencing the bilingual intake templates and their whole-VND unit contract as the data-readiness exercise, `docs/scoring_anchors.md` as the methodology walkthrough, the Scenario Builder page as the live surface, and an anonymized disclosure pack as the worked example. — packaging and facilitation notes, not new content; the same kit serves BIDV's small-bank workshop and TCB's team sessions.
- **DEC-015:** The two TCB knowledge products are (i) a portfolio alignment and transition-risk **methodology note** (the honest substitute for the PCAF half, and already owed under Output 1.2) and (ii) a **sector transition-finance note** running alignment gap → interim target → SLL structure end to end. — the second ties three workstreams into one artifact.
- **DEC-016:** **No `engagements/tcb/` config yet.** Produce the TCB-addressed methodology report using the MCB demo as an explicitly labelled illustrative example; reserve the slug until a real loanbook exists. — a directory named for a real bank holding synthetic numbers is a mislabeling hazard against CLAUDE.md's disclaimer rule.
- **DEC-017:** Sequence after the prerequisite: **SLL screen → target registry → report parameterization → workshop kit + knowledge products.** — the SLL screen is BIDV's most concrete commitment and is purely additive; targets follow because the sector knowledge product needs them; the kit packages what the others produce.

## Assumptions & Constraints

- **ASM-001:** No real BIDV or Techcombank loanbook is available this cycle; everything is demonstrated on the synthetic MCB book.
- **ASM-002:** PCAF financed-emissions accounting stays out of scope, so targets and hotspots derive from PACTA alignment and TRISK stress, not from an emissions inventory. Any client-facing framing must say so.
- **ASM-003:** `data/vietnam_abcd.csv` remains synthetic and MCB-shaped; the ABCD sourcing decision (`docs/abcd_sourcing_decision.md`) is unresolved and unblocked by this work.
- **ASM-004:** `engagement_scoring.R` reads the *published snapshot* (`<snapshot_dir>/trisk/<sector>/`), not `synthesis_output/trisk` — so `sll_readiness.R` inherits the same ordering constraint and must run after the snapshot step.
- **CON-001:** Law 5 — `synthesis_output/vietnam/*.csv`, `synthesis_output/prioritization/*.csv`, `output/engagement/engagement_priority.csv` and the committed SDB outputs must stay byte-identical; `tools/verify_refactor.R` runs in `ci.yml` on every push and gates the weekly refresh.
- **CON-002:** Law 4 — `test_golden_numbers.R` pins `composite_score[1] == 0.9113849765258216`, 23 rows, rank-1 `"Nghi Son Power LLC"`, plus an anti-min-max guard; `test_sdb_engagement.R` pins the SDB equivalent. No workstream here may move them.
- **CON-003:** Law 2 — VND is never rescaled. The SLL screen's ticket-size dimension operates on raw `loan_size_outstanding` sums via `R/format_money.R` for display only.
- **CON-004:** The Streamlit dashboard reads only `dashboard/data` and `public_snapshot_allowed` deliberately blocks engagements from writing there — so client-specific outputs are HTML-file delivery, not dashboard views.
- **CON-005:** Synthetic-data disclaimers are mandatory in every generated artifact (README banner, dashboard banners, report footers).
- **CON-006:** `supported_sectors` is duplicated across four files and cross-checked by `verify_refactor.R --invariants`; the target registry must not become a fifth uncoordinated copy.

## Approaches Considered

- **Chosen:** Additive downstream modules that read frozen outputs as feedstock, plus config-schema widening whose defaults reproduce today's numbers. — delivers all four commitments without a golden refreeze, which keeps the Wave 2 acceptance bar intact while the methodology is still moving.
- **ALT-001:** Extract the borrower composite into `R/engagement_scoring_core.R` first, then branch both screens off one parameterized function. — cleaner long-run structure, but spends a refactor under the byte-identity gate before any new value ships. Worth revisiting once the SLL anchors settle.
- **ALT-002:** Fix `pacta_sda()` to do real convergence and refreeze goldens to 0.5.0. — methodologically superior, since alignment gaps and targets would finally derive from the same construct. Deferred because the cascade reaches every frozen number: `gap_pct` → `severity_alignment` → `composite_score` → sector ranking.
- **ALT-003:** Per-engagement template directories. — rejected: divergent copies drift and multiply every future template fix.
- **ALT-004:** A new client-neutral report generator on `R/report_toolkit.R`, retiring the BIDV one. — rejected: rewrites 1,034 lines of working code to reach the same output.
- **ALT-005:** An `engagements/tcb-demo/` config exercising the full chain under the TCB name. — rejected on mislabeling risk; the methodology deliverable needs no portfolio data anyway.

## Out of Scope

- The PCAF financed-emissions build — a separate structural decision that determines whether the platform gains a Layer 1 at all.
- Advisory-only commitments: KPI/SPT design, deal identification and structuring, Scope 1 & 2 assessment, the two hand-off trainings, rooftop solar / BESS / REC feasibility.
- Automotive TRISK (still open from `research/2026-07-13-client-engagement-runway-brainstorm.md` T3.1) — it would remove the `composite_partial` caveat but is not required by any middle-tier commitment.
- Multi-engagement dashboard viewing (blocked by `CON-004` by design).
- Any change to the MCB public snapshot's published numbers.

## Open Questions

1. **Q-001:** Which priority sector should the transition-finance knowledge product cover?
   - **Recommended default:** Power. It is the only sector with borrower-level TRISK, the richest data support, and it matches TCB's EIB-linked renewable ambition. Cement is the natural BIDV-specific second if the note is later split per client.
   - **Why this matters:** determines which alignment-gap → target → SLL narrative gets built end to end, and therefore which sector's target must be most defensible.

2. **Q-002:** What breakpoints should the new SLL readiness anchor tables use?
   - **Recommended default:** Mirror the existing five-breakpoint structure from `docs/scoring_anchors.md` and calibrate against the MCB book so the qualified pool lands at roughly 5–8 borrowers out of 23 — then tune once a real book exists.
   - **Why this matters:** anchors are the methodology; picking them arbitrarily undermines the same "reviewer with a calculator" standard `scoring_anchors.md` set.

3. **Q-003:** Should the target registry carry a single 2030 horizon or multiple (2030 / 2035 / 2050)?
   - **Recommended default:** Multi-horizon schema, populated for 2030 only at first. Both documents say "interim", which implies a longer target the interim sits against, and a schema change later is more expensive than an unpopulated column now.
   - **Why this matters:** fixes whether the registry can express a net-zero trajectory or only a single checkpoint.

4. **Q-004:** Does the workshop kit ship in the public repo or as private material?
   - **Recommended default:** Public. Every asset it assembles is already public and client-neutral, and BIDV's MoU explicitly frames the workshop as disseminating "anonymized (non-BIDV specific) GTB-developed tools" to the wider market.
   - **Why this matters:** affects whether the kit can reference the live dashboard and whether it needs its own anonymization pass.

## Suggested Next Step

Run `/plan gtb-middle-tier-gap-closers` to turn this into a multi-phase implementation plan.

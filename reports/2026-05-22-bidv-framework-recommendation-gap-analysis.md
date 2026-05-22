# Gap Analysis: BIDV Portfolio Alignment Framework Recommendation Report

**Date:** 2026-05-22
**Scope:** Assess the current pacta-trisk repo against the target of delivering a practical framework recommendation report for BIDV — covering sector prioritization, internationally recognized portfolio alignment frameworks, and a concrete implementation roadmap for aligning BIDV's lending with decarbonization pathways, grounded in Decision 263 compliance for thermal power, steel, and cement clients.
**Status:** Draft for Review

---

## Executive Summary

The repo has **strong analytical foundations** — a complete PACTA alignment pipeline for power/cement/steel, a package-backed TRISK stress-test covering all three Decision 263 sectors, an interactive scenario builder with 243-scenario precomputed grid, and an operational BYOL intake path. However, **no framework comparison or recommendation layer exists**: the repo produces alignment analytics and stress-test results but contains zero content evaluating PACTA against peer frameworks (PCAF, SBTi, Paris Agreement Capital Transition Assessment variants, NGFS scenarios), no Decision 263 compliance mapping, no BIDV-specific sector exposure analysis module, no structured recommendation output, and no regulatory advisory narrative. There are **7 gaps** (3 CRITICAL, 2 HIGH, 2 MEDIUM) to bridge before a framework recommendation report can be delivered.

---

## Current Capabilities (What We Have)

| Capability | Status | Key Surfaces |
|---|---|---|
| PACTA alignment pipeline (power, auto, cement, steel) | Mature | `scripts/pacta_vietnam_scenario.R`, `synthesis_output/vietnam/` |
| TRISK stress test (power, cement, steel) | Mature | `scripts/trisk_sector_demo.R`, `synthesis_output/trisk/`, `dashboard/data/trisk/` |
| Multi-parameter sensitivity analysis | Mature | `scripts/trisk_scenario_grid.R`, 243-scenario grid per sector |
| Interactive scenario builder dashboard | Working | `dashboard/pages/5_Scenario_Builder.py`, precomputed grid |
| BYOL loanbook intake | Working | `intake/`, `scripts/intake_validate_and_map.R`, `dashboard/pages/6_Intake_Wizard.py` |
| Vietnamese synthetic data (MCB proxy) | Working | `data/vietnam_loanbook.csv`, `data/vietnam_abcd.csv`, `data/vietnam_scenario_*.csv` |
| VSIC→ISIC→PACTA sector mapping | Working | `scripts/pacta_vietnam_scenario.R` (lines 100–135) |
| Streamlit dashboard (alignment + risk + methodology) | Working | `dashboard/app.py`, `dashboard/pages/1-6` |
| HTML report generation | Working | `reports/*.html` (23 reports), `scripts/generate_report.R` |
| TRISK research brief & methodology doc | Working | `research/2026-04-08_integration-trisk-model-existing.md`, `docs/TRISK_Demo_Assumptions.md` |
| Engagement scoring (composite alignment + TRISK) | Planned | Described in `research/future_planning_ideas.md` Idea 3, not implemented |
| Disclosure/engagement output layer | Planned | Described in `plans/2026-05-02-commercial-demo-expansion-ideas.md` Idea 3, not implemented |
| Framework comparison / recommendation content | Missing | No files |
| Decision 263 compliance mapping | Missing | No files |
| BIDV-specific sector exposure analysis | Missing | No files |

---

## Target State

> A self-contained, professional framework recommendation report delivered to BIDV that:
>
> 1. **Maps BIDV's sector exposure** across its high-emitting client base (20+ clients in thermal power, steel, cement mandated under Decision 263) and identifies which sectors to prioritize for climate risk reduction.
> 2. **Evaluates leading portfolio alignment frameworks** (PACTA, PCAF, SBTi FI, NGFS climate scenarios, Paris Agreement Capital Transition Assessment variants, GFANZ sector pathways) against BIDV's actual data availability, sector mix, and regulatory context (Decision 263 quotas, SBV green taxonomy).
> 3. **Recommends the most practical tools and processes** for BIDV — which frameworks to adopt, in what sequence, with what data prerequisites, and at what cost/complexity.
> 4. **Provides a concrete implementation roadmap** for aligning BIDV's lending with decarbonization pathways, including sector-specific GHG quota alignment under Decision 263, borrower engagement prioritization, and integration with BIDV's existing risk management workflows.
> 5. **Demonstrates the recommended approach** using the repo's existing PACTA+TRISK pipeline outputs against the three Decision 263 sectors as proof-of-concept evidence.

---

## Gap Analysis

### GAP-01: Framework Comparison and Evaluation Module

**Severity:** CRITICAL — Blocks the target entirely. The deliverable is a *framework recommendation report*, and the repo contains no content comparing or evaluating any portfolio alignment framework.

**Current state:** The repo implements one framework (PACTA for Banks via `r2dii.*` packages) and one stress-test layer (TRISK via `trisk.model`). The methodology page (`dashboard/pages/4_Methodology.py`) explains PACTA and TRISK but does not compare them against peer approaches. `research/2026-04-08_integration-trisk-model-existing.md` positions TRISK relative to PACTA but does not survey the broader landscape. No file in `docs/`, `research/`, or `reports/` evaluates PCAF, SBTi Financial Institutions, GFANZ sector pathways, NGFS climate scenarios (as a portfolio alignment tool), or other recognized frameworks.

**What's needed:**
- A structured evaluation matrix comparing 5-7 leading frameworks across dimensions relevant to BIDV: data input requirements, sector coverage (especially thermal power/steel/cement), Vietnam regulatory compatibility, output types (alignment metric, risk metric, disclosure output), implementation complexity, cost, and open-source availability.
- Scored assessment of each framework's fit for BIDV's specific context: 20+ high-emitting clients, Decision 263 reporting obligations, SBV green taxonomy, PCAF-based financed emissions baseline (Output 2.1), and limited in-house quantitative capacity.
- A clear recommendation with primary/secondary/tertiary framework choices and rationale.

**Existing assets to reuse:**
- `research/2026-04-08_integration-trisk-model-existing.md` — has a strong PACTA-TRISK positioning analysis that can anchor the PACTA+TRISK section of the comparison.
- `docs/PACTA_Beginner_Guide.md` — 439-line guide covering the PACTA methodology end-to-end; can be condensed into the PACTA evaluation section.
- `docs/TRISK_Demo_Assumptions.md` — documents TRISK's input requirements and limitations; reusable for the TRISK evaluation.
- `dashboard/pages/4_Methodology.py` — has PACTA and TRISK framing copy and citations.

**Effort estimate:** 1 focused research + writing phase. Requires domain research (web search for framework documentation) plus structured comparison authoring. ~2-3 days.

---

### GAP-02: Decision 263 Compliance Mapping Layer

**Severity:** CRITICAL — The entire engagement is framed around Decision 263 as the regulatory driver. Without mapping the repo's sector outputs to Decision 263's sector-specific GHG emission quotas and reporting requirements, the recommendation cannot answer BIDV's core question: "How do these frameworks help us meet our regulatory obligations?"

**Current state:** The repo knows about Vietnamese regulatory context at a high level — `plans/vietnam_bank_pacta_scenario_plan.md` references PDP8, Vietnam NDC, and JETP. The synthetic scenarios in `data/vietnam_scenario_ms.csv` and `data/vietnam_scenario_co2.csv` use PDP8 and NDC targets. However:
- No file references Decision 263 by name or number.
- No mapping exists between Decision 263's sector-specific GHG quota structure and the repo's PACTA/TRISK sector taxonomy.
- No analysis connects Decision 263's 2025 reporting mandate or emission reduction plan requirements to the pipeline's outputs.
- The repo covers power, cement, and steel (the three Decision 263 sectors) but does not frame them through the lens of Decision 263 compliance.

**What's needed:**
- A Decision 263 reference document: what the decision requires (emission inventories since 2025, GHG quotas, reduction plans), which sectors/entities are covered, enforcement mechanisms, and timeline.
- A mapping table: Decision 263 sector categories → PACTA sectors → TRISK sectors → repo data files, showing how the existing pipeline directly supports Decision 263 compliance monitoring.
- Explicit framing in the recommendation report showing BIDV how its financed emissions baseline (Output 2.1) + portfolio alignment analysis (PACTA) + transition stress testing (TRISK) together constitute a compliance and risk management stack for Decision 263.

**Existing assets to reuse:**
- `data/vietnam_abcd.csv` — already covers power, cement, and steel companies that are typical Decision 263 entities (EVN subsidiaries, VICEM, Hoa Phat, Vinacomin).
- `data/vietnam_scenario_co2.csv` — SDA emission intensity pathways for cement and steel can be mapped directly to Decision 263 quota trajectories.
- `docs/trisk_multisector_contract.md` — sector mapping rules (power/cement/steel) already documented, reusable for Decision 263 alignment.
- `intake/SCHEMA.md` — the VSIC code-based intake already aligns with how Vietnamese entities are classified.

**Effort estimate:** 1 research phase (Decision 263 content gathering and structuring) + 1 writing phase. ~2-3 days.

---

### GAP-03: BIDV-Specific Sector Exposure Analysis and Prioritization Module

**Severity:** CRITICAL — The report must recommend which sectors BIDV should prioritize. The repo currently uses a fictional "Mekong Commercial Bank" (MCB) portfolio. No BIDV-specific exposure data exists, and no module produces a sector prioritization analysis from a given portfolio.

**Current state:** The PACTA pipeline produces sector-level alignment gaps and TRISK produces sector-level stress rankings, but these are computed for the MCB synthetic portfolio. The BYOL intake (`intake/`, `scripts/intake_validate_and_map.R`) can ingest a real bank's loanbook, but:
- No script or module takes alignment + stress outputs and produces a sector prioritization recommendation (e.g., "prioritize cement first because it has the largest alignment gap AND the highest stress exposure").
- No template exists for a "sector prioritization" analysis section in a report.
- The engagement scoring concept from `research/future_planning_ideas.md` (Idea 3) is described but not implemented.
- No BIDV portfolio data has been ingested.

**What's needed:**
- A sector prioritization scoring script that takes PACTA alignment gaps + TRISK priority scores + portfolio exposure weights and produces a ranked sector priority list with rationale.
- A report section template showing: (a) BIDV's exposure distribution across Decision 263 sectors, (b) alignment status per sector against relevant pathways, (c) transition risk severity per sector, (d) composite priority ranking.
- For the recommendation report specifically: even without real BIDV data, the framework should be demonstrated using the synthetic MCB portfolio as an illustrative example, with explicit placeholders for BIDV data.

**Existing assets to reuse:**
- `dashboard/data/trisk/*/top_borrowers_alignment_trisk.csv` — borrower-level priority scores for power, cement, and steel; can be aggregated to sector level.
- `synthesis_output/vietnam/` — PACTA alignment outputs including technology mix, trajectory, and alignment gap CSVs.
- `research/future_planning_ideas.md` Idea 3 — engagement scoring design (composite `0.5 × alignment_gap + 0.5 × trisk_priority_score`) that can be adapted to sector-level prioritization.
- `plans/2026-05-02-commercial-demo-expansion-ideas.md` Idea 3 — engagement and disclosure output layer design.

**Effort estimate:** 1 multi-phase plan (2-3 phases): scoring script, report template, demonstration run. ~3-4 days.

---

### GAP-04: Framework Recommendation Report Generator

**Severity:** HIGH — Significantly degrades the target. The repo has report generation capability (`scripts/generate_report.R`, multiple HTML reports) but nothing produces the specific deliverable format required: a structured advisory report with executive summary, framework comparison, sector prioritization, implementation roadmap, and methodology appendix.

**Current state:** The repo generates two types of reports:
1. Phase-level HTML reports under `reports/` (23 exist) — these are internal project artifacts documenting implementation progress, not client-facing advisory documents.
2. PACTA alignment HTML reports (`reports/PACTA_Vietnam_Bank_Report.html`, `reports/PACTA_Synthesis_Report.html`) — these present analytical outputs but do not contain advisory content, framework comparisons, or implementation recommendations.

No report template or generator exists for a framework recommendation deliverable.

**What's needed:**
- A report template (HTML, and optionally DOCX/PDF) structured for advisory delivery: cover page, executive summary, BIDV context section, framework comparison matrix, sector prioritization, recommended approach, implementation roadmap (phased with timelines), risk assessment, methodology appendix.
- A report generation script that populates the template with data from the analytical pipeline (alignment gaps, TRISK scores, sector rankings) plus authored advisory content.
- Bilingual capability (Vietnamese/English) as established in existing repo patterns (`intake/templates/README_vi.md`).

**Existing assets to reuse:**
- `scripts/generate_report.R` — HTML report generation with base64-embedded charts; the rendering pattern is directly reusable.
- `reports/PACTA_Vietnam_Bank_Report.html` — 12-section bilingual HTML report; the template structure (KPI cards, chart panels, methodology section) can be extended.
- `plans/2026-05-02-commercial-demo-expansion-ideas.md` Idea 3 — describes a "regulator/board disclosure pack generator" aligned to TCFD/ISSB pillars; this is architecturally similar.
- `dashboard/lib/branding.py` — Allotrope branding and styling patterns reusable for report theming.

**Effort estimate:** 1 multi-phase plan (2 phases): template design + generator script. ~3-4 days.

---

### GAP-05: Implementation Roadmap and Institutional Adoption Guidance

**Severity:** HIGH — Without a concrete roadmap, the recommendation is advice without an action plan. BIDV needs to know: what to do first, what data to prepare, which team to assign, and how long it takes.

**Current state:** The repo has detailed implementation roadmaps for its *own* development (`activeContext.md`, `plans/PROGRESS.md`, 7 multi-phase plans under `plans/`), but nothing that describes an implementation roadmap for a *client bank*. The BYOL intake plan (`plans/2026-05-19-byol-pilot-intake-plan.md`) is the closest artifact — it describes what a bank needs to provide — but it is an internal engineering plan, not a client-facing adoption guide.

**What's needed:**
- A phased implementation roadmap for BIDV covering: (a) data preparation phase (loanbook extraction, VSIC mapping, emissions data collection from Decision 263 clients), (b) baseline establishment phase (financed emissions calculation, first PACTA alignment run), (c) risk assessment phase (TRISK stress test, sector prioritization), (d) action phase (borrower engagement, sector limit setting, portfolio rebalancing), (e) monitoring phase (quarterly re-runs, progress tracking).
- Resource and capability requirements: staffing (risk team, data team, ESG team), technology (R environment, data infrastructure), and external support needs.
- Integration guidance: how framework outputs connect to BIDV's existing credit risk management, ESG governance, and SBV regulatory reporting processes.
- Timeline estimates anchored to Decision 263 milestones (2025 reporting mandate, quota implementation schedule).

**Existing assets to reuse:**
- `plans/vietnam_bank_pacta_scenario_plan.md` — 1,221-line blueprint with a 9-week roadmap structure; the phasing pattern is reusable.
- `intake/SCHEMA.md` and `intake/README.md` — document exactly what a bank needs to provide; directly reusable for the "data preparation phase" of the roadmap.
- `docs/demo-script.md` — demo walkthrough that shows the analytical journey; can inform the "how to interpret results" section.
- `docs/streamlit-deploy.md` — deployment documentation reusable for technology requirements section.

**Effort estimate:** 1 focused writing phase with domain research. ~2-3 days.

---

## Second-Tier Gaps

| Gap | Severity | Summary | Existing Assets |
|---|---|---|---|
| GAP-06: NGFS / SBTi / PCAF scenario integration | MEDIUM | The repo uses custom PDP8/NDC/NZE scenarios but does not integrate official NGFS Phase V scenarios, PCAF methodologies, or SBTi sectoral pathways — the report should demonstrate awareness of these standards even if recommending PACTA as primary. Carbon price families in the grid (`docs/trisk_scenario_grid_contract.md`) are aliased, not real NGFS data. | `data/vietnam_scenario_*.csv`, `docs/trisk_scenario_grid_contract.md`, grid aliasing infrastructure |
| GAP-07: Borrower engagement and disclosure output templates | MEDIUM | The recommendation report should include sample outputs showing BIDV what actionable artifacts the recommended framework produces (engagement letters, disclosure packs). These are designed in `research/future_planning_ideas.md` Idea 3 and `plans/2026-05-02-commercial-demo-expansion-ideas.md` Idea 3 but not implemented. | Design docs in `research/future_planning_ideas.md`, `plans/2026-05-02-commercial-demo-expansion-ideas.md` |

---

## Recommended Sprint Sequencing

| Priority | Gap | Rationale |
|---|---|---|
| Sprint 1 (Week 1) | GAP-02: Decision 263 Compliance Mapping | The entire engagement is regulatory-driven. Without this mapping, every other gap's content floats without an anchor. This is also a pure research + writing task with no code dependencies. |
| Sprint 1 (Week 1, parallel) | GAP-01: Framework Comparison Module | This is the intellectual core of the deliverable. Can be researched and drafted in parallel with GAP-02 since they share the regulatory context research. |
| Sprint 2 (Week 2) | GAP-03: Sector Prioritization Module | Depends on GAP-01 (framework evaluation informs which prioritization criteria to use) and GAP-02 (Decision 263 mapping informs which sectors matter). Requires a scoring script and demonstration run. |
| Sprint 2 (Week 2, parallel) | GAP-05: Implementation Roadmap | Can be drafted in parallel with GAP-03. The roadmap depends on knowing which framework is recommended (GAP-01) and what Decision 263 requires (GAP-02). |
| Sprint 3 (Week 3) | GAP-04: Report Generator | Depends on all content being drafted (GAP-01 through GAP-05). This is assembly and templating — taking the authored content and pipeline outputs and rendering them into a professional deliverable. |
| Sprint 3 (Week 3, parallel) | GAP-06 + GAP-07: Scenario integration + output templates | Polish work to strengthen the report with recognized standard references and sample borrower-facing artifacts. |

---

## Risk Register

| Risk | Impact | Likelihood | Mitigation |
|---|---|---|---|
| Decision 263 text not publicly available in English | Blocks accurate compliance mapping; report may misstate regulatory requirements | M | Use Vietnamese-language official sources (Government Portal, MONRE), supplement with GTB/GIZ advisory publications that reference Decision 263 requirements. Engage BIDV counterpart to validate the compliance mapping. |
| BIDV portfolio data not available for the report | Report can only demonstrate with synthetic MCB data, reducing credibility with BIDV stakeholders | H | Frame the synthetic demo as a methodology proof-of-concept. Include explicit "placeholder for BIDV data" markers. Leverage the BYOL intake (`intake/`) to show the data onboarding path is ready. |
| Framework evaluation perceived as biased toward PACTA (since the repo only implements PACTA) | BIDV or GTB may question objectivity of the recommendation | M | Include genuine trade-off analysis for each framework. Acknowledge PACTA's limitations (e.g., requires asset-level data, limited oil & gas coverage for Vietnam). Include frameworks where PCAF or SBTi may be better fits for specific use cases. |
| Scope creep into building new analytical modules instead of writing the report | Delays delivery; the report is the deliverable, not new code | M | Limit code changes to one scoring script (GAP-03) and one report generator (GAP-04). All other gaps are research + writing tasks using existing pipeline outputs. |
| Vietnam-specific scenario data (PDP8/NDC) becomes outdated if national policy updates | Report anchored to stale reference targets | L | Date-stamp all scenario references. Note that scenarios should be refreshed when MoIT/MONRE update PDP8 implementation plan. The existing `scripts/refresh_dashboard_data.R` provides a rerun path. |
| TRISK model outputs misinterpreted as regulatory credit risk numbers | Reputational risk if BIDV uses stress-test PD changes in production credit models | M | Include the existing disclaimer language (`DISCLAIMER` in `dashboard/pages/2_TRISK_Risk.py`) prominently in the report. Frame TRISK outputs as comparative ranking tools, not regulatory PD substitutes. |

---

## Assumptions

- **ASM-01:** BIDV's financed emissions baseline (Output 2.1) uses PCAF methodology and covers the 20+ Decision 263 clients. The recommendation report assumes this baseline exists and focuses on the "what to do with it" layer.
- **ASM-02:** The three Decision 263 sectors (thermal power, steel, cement) map cleanly to the repo's existing PACTA sectors (`power`, `steel`, `cement`). "Thermal power" specifically maps to coal and gas technologies within the `power` sector.
- **ASM-03:** The report will be delivered as a self-contained HTML document with embedded charts, consistent with the repo's existing report format. DOCX/PDF export is desirable but not blocking.
- **ASM-04:** Real BIDV portfolio data will NOT be available before the initial report delivery. The demonstration will use the synthetic MCB portfolio with Decision 263-relevant borrowers (EVN, VICEM, Hoa Phat, Vinacomin) as illustrative examples.
- **ASM-05:** The recommendation report is a GTB deliverable to BIDV — not a public document. It does not need to be deployed on the public Streamlit dashboard.

---

## Suggested Next Step

Review this gap analysis report, then invoke `/plan` for each critical gap in sprint order:
1. `/plan` for GAP-01 + GAP-02 combined (Framework Comparison + Decision 263 Mapping — these share research context)
2. `/plan` for GAP-03 (Sector Prioritization Module)
3. `/plan` for GAP-04 + GAP-05 combined (Report Generator + Implementation Roadmap)

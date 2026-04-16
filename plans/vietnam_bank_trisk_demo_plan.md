# Vietnam Bank TRISK Demo: Multi-Phase Plan

> **Status:** Draft - planning artifact for implementation
> **Author:** OpenCode / Tung context
> **Last updated:** 2026-04-16
> **Purpose:** Detailed multi-phase plan to showcase TRISK, optionally combined with PACTA, using synthetic but publicly anchored Vietnam market data to produce a credible demo final report for a prospective Vietnam bank.

---

## Table of Contents

1. [Executive Intent](#1-executive-intent)
2. [Why TRISK Needs PACTA in This Repo](#2-why-trisk-needs-pacta-in-this-repo)
3. [Demo Thesis and Target Audience](#3-demo-thesis-and-target-audience)
4. [Design Principles](#4-design-principles)
5. [Target End-State Deliverables](#5-target-end-state-deliverables)
6. [Phase Overview](#6-phase-overview)
7. [Phase 0 - Scope Lock and Research Consolidation](#7-phase-0---scope-lock-and-research-consolidation)
8. [Phase 1 - Stabilize the Vietnam PACTA Baseline](#8-phase-1---stabilize-the-vietnam-pacta-baseline)
9. [Phase 2 - Public-Data-to-Synthetic TRISK Input Design](#9-phase-2---public-data-to-synthetic-trisk-input-design)
10. [Phase 3 - Power-Sector TRISK Pilot](#10-phase-3---power-sector-trisk-pilot)
11. [Phase 4 - PACTA plus TRISK Integrated Bank Story](#11-phase-4---pacta-plus-trisk-integrated-bank-story)
12. [Phase 5 - Final Demo Report for a Prospective Vietnam Bank](#12-phase-5---final-demo-report-for-a-prospective-vietnam-bank)
13. [Data Strategy](#13-data-strategy)
14. [Scenario Strategy](#14-scenario-strategy)
15. [Synthetic Financial Features Strategy](#15-synthetic-financial-features-strategy)
16. [Technical Build Plan](#16-technical-build-plan)
17. [Validation and QA Plan](#17-validation-and-qa-plan)
18. [Risks, Caveats, and How to Present Them](#18-risks-caveats-and-how-to-present-them)
19. [Suggested File and Artifact Map](#19-suggested-file-and-artifact-map)
20. [Detailed Workplan by Week](#20-detailed-workplan-by-week)
21. [Decision Log to Resolve Early](#21-decision-log-to-resolve-early)
22. [Definition of Done](#22-definition-of-done)

---

## 1. Executive Intent

The objective is not just to "run TRISK." The objective is to build a bank-facing demo that answers two linked questions for a prospective Vietnam bank:

1. **PACTA question:** Which sectors, technologies, and named borrowers in the bank's climate-relevant portfolio are misaligned with Vietnam and global transition pathways?
2. **TRISK question:** If a disorderly transition materializes under those same pathways, how much firm value deterioration and credit-risk deterioration could the bank face?

The research in `research/2026-04-08_integration-trisk-model-existing.md` makes the core strategic point: TRISK is best treated here as a **second-stage transition-risk stress layer** downstream of PACTA, not as a replacement for the existing PACTA work.

This plan therefore proposes a **PACTA-first, TRISK-second** showcase, with a power-sector TRISK pilot as the most credible initial demonstration and a bank-ready final report that integrates both alignment and risk results.

---

## 2. Why TRISK Needs PACTA in This Repo

This repo already contains most of the hard upstream ingredients TRISK needs:

- synthetic Vietnam loanbook data for a fictional bank (`data/vietnam_loanbook.csv`)
- synthetic Vietnam production and asset data (`data/vietnam_abcd.csv`)
- custom Vietnam market-share and CO2 scenario tables (`data/vietnam_scenario_ms.csv`, `data/vietnam_scenario_co2.csv`)
- company-level and portfolio-level PACTA outputs (`synthesis_output/vietnam/04_vn_ms_company.csv`)

But the research also identifies the main missing TRISK ingredients:

- `pd`
- `net_profit_margin`
- `debt_equity_ratio`
- `volatility`
- commodity or electricity price curves
- carbon price curves
- schema mapping from PACTA naming into TRISK naming

That means the fastest credible route is:

1. finish and stabilize the Vietnam PACTA run
2. create synthetic but transparent TRISK financial and scenario inputs
3. build a TRISK bridge around power first
4. integrate the outputs into a final bank-facing story

---

## 3. Demo Thesis and Target Audience

### 3.1 Demo Thesis

For a Vietnamese commercial bank, the most compelling climate-risk demo is:

"We can use public Vietnam market context plus synthetic portfolio data to identify which borrowers are misaligned today and estimate how transition stress could translate into borrower valuation stress and credit stress tomorrow."

### 3.2 Primary Audience

- bank ESG lead
- wholesale credit-risk team
- strategy or sustainability office
- senior corporate banker covering power and industry

### 3.3 Secondary Audience

- internal innovation or data team
- donors, climate-finance partners, or consultants
- regulators or quasi-regulators evaluating green-credit capability

### 3.4 What This Demo Must Feel Like

- serious enough to be discussable with a bank
- transparent enough that synthetic assumptions are not mistaken for real bank data
- concrete enough to show named sectors, named borrowers, and risk rankings
- modest enough not to overclaim precision

---

## 4. Design Principles

1. **Use PACTA where it is strongest.** Alignment, technology mix, sector pathways, borrower prioritization.
2. **Use TRISK where it adds new value.** Firm-value stress, VaR-style outputs, PD-change stress, sensitivity analysis.
3. **Power sector first.** The research and the paper both point to power as the highest-confidence pilot.
4. **Publicly anchored, synthetically completed.** Use public sources to shape directional assumptions, then fill missing fields with clearly labeled synthetic values.
5. **Scenario transparency over false precision.** The final report should show ranges, sensitivities, and caveats.
6. **Bank actionability matters more than methodological maximalism.** The output should translate into engagement, limits, monitoring, and origination ideas.
7. **Keep implementation target concrete.** Pin the first TRISK implementation to the legacy folder-and-CSV workflow if that minimizes friction.

---

## 5. Target End-State Deliverables

The intended deliverable set is:

### 5.1 Core Analytical Artifacts

- a completed Vietnam PACTA baseline run
- a TRISK-ready input package for at least the power sector
- a first successful TRISK run on synthetic Vietnam power-sector data
- a combined borrower-level ranking table joining alignment and stress outputs

### 5.2 Narrative Deliverables

- a markdown implementation and interpretation pack
- a self-contained HTML final report for a prospective Vietnam bank
- optionally, a lighter executive memo or slide appendix later

### 5.3 Data and Reproducibility Deliverables

- documented public-source log
- synthetic-assumptions register
- mapping tables from local PACTA schema to TRISK schema
- sensitivity parameter register

### 5.4 Proposed Final Files

- `plans/vietnam_bank_trisk_demo_plan.md`
- `scripts/trisk_prepare_inputs.R`
- `scripts/trisk_power_demo.R`
- `data/vietnam_trisk_financial_features.csv`
- `data/vietnam_trisk_price_data_long.csv`
- `data/vietnam_trisk_ngfs_carbon_price.csv`
- `output/trisk/` or `synthesis_output/trisk/` for run outputs
- `reports/PACTA_TRISK_Vietnam_Bank_Demo_Report.html`

---

## 6. Phase Overview

The work should be executed in six phases:

| Phase | Name | Main Outcome |
|---|---|---|
| 0 | Scope lock and research consolidation | One agreed demo boundary, pinned implementation target, assumption strategy |
| 1 | Stabilize Vietnam PACTA baseline | A reproducible Vietnam PACTA run with complete outputs |
| 2 | Public-data-to-synthetic TRISK input design | Financial features, price curves, carbon curves, and schema maps ready |
| 3 | Power-sector TRISK pilot | First successful TRISK pilot with interpretable results |
| 4 | PACTA plus TRISK integration | Combined bank story and borrower prioritization outputs |
| 5 | Final report production | Stakeholder-ready HTML report with appendices and caveats |

---

## 7. Phase 0 - Scope Lock and Research Consolidation

### 7.1 Objective

Avoid a fuzzy "TRISK integration" effort by locking down exactly what the first demo does and does not include.

### 7.2 Decisions to Lock in This Phase

1. **Implementation target:** legacy TRISK folder-and-CSV workflow first
2. **Pilot sector:** power only for first TRISK run
3. **Bank story:** PACTA multi-sector plus TRISK power-sector deep dive
4. **Final benchmark set:** PDP8/NDC as domestic benchmark; IEA NZE as global ambition benchmark; optional STEPS as current-policy baseline
5. **Primary audience language:** English-first with Vietnam-specific terminology and optional bilingual labels

### 7.3 Work Items

- consolidate TRISK notes from `research/2026-04-08_integration-trisk-model-existing.md`
- extract implementation-relevant caveats from `research/Baer_TRISK_2022_extracted.txt`
- define which public sources will anchor synthetic assumptions
- define what counts as "demo acceptable" vs "production required"

### 7.4 Output of Phase 0

- this plan approved as working blueprint
- assumption categories defined
- first-pass file map agreed

---

## 8. Phase 1 - Stabilize the Vietnam PACTA Baseline

### 8.1 Objective

TRISK should not be built on top of a half-complete or unstable PACTA run. The upstream PACTA script must complete reproducibly because its company-level trajectories are the foundation of the stress story.

### 8.2 Why This Matters

The TRISK research note is explicit: the credibility of the TRISK layer depends on the credibility of the forward production paths it consumes.

### 8.3 Required Tasks

1. Run and fix `scripts/pacta_vietnam_scenario.R` until it completes through:
   - matching
   - market share outputs
   - SDA outputs
   - alignment calculations
   - final HTML report generation
2. Use `scripts/debug_ms.R` to resolve the known region or metric mismatch blocking completion.
3. Verify the company-level outputs needed downstream still exist and are stable.
4. Freeze a "baseline demo dataset" version for the first TRISK pilot.

### 8.4 Specific Validation Checks

- `synthesis_output/vietnam/04_vn_ms_company.csv` exists and is reproducible
- cement and steel SDA outputs exist
- alignment summary table is generated
- final PACTA Vietnam HTML report exists
- match quality is reviewed for critical borrowers: EVN, PVN Power, Trung Nam, VinFast, VICEM, Hoa Phat, TKV

### 8.5 Exit Criteria for Phase 1

- a complete PACTA Vietnam demo report exists
- company-level trajectory outputs are frozen for the pilot run
- known data quality issues are documented, not silently ignored

---

## 9. Phase 2 - Public-Data-to-Synthetic TRISK Input Design

### 9.1 Objective

Create the missing TRISK inputs using public Vietnam and international reference material, with synthetic completion where public data is incomplete.

### 9.2 Core Gap Categories

The new inputs to design are:

1. financial features by company
2. price pathways
3. carbon price pathways
4. capacity factors if targeting the legacy interface
5. schema mappings and export logic

### 9.3 Public Data Philosophy

Use public sources to anchor direction and relative ranking, not to pretend that private borrower financials are available. This means the synthetic layer should preserve plausibility across:

- sector differences
- ownership model differences
- maturity and technology differences
- listed vs SOE vs project-finance style borrowers

### 9.4 Public Sources to Leverage

- PDP8 targets and annexes
- Vietnam NDC documents
- JETP documents and analysis
- EVN, PVN Power, Vinacomin, Hoa Phat, VinFast, VICEM annual reports or investor materials where public
- IEA WEO regional pathways
- NGFS scenario explorer for carbon and demand pathways
- public regional power-price proxies where direct Vietnam forward curves are unavailable

### 9.5 Synthetic Completion Strategy

For each missing field, define:

- source anchor
- synthetic interpolation rule
- confidence level
- presentation caveat

Example categories:

| Input | Public anchor | Synthetic fill approach | Confidence |
|---|---|---|---|
| `pd` | sector risk bucket, public ratings analogs, borrower type | assign by borrower cluster and leverage proxy | medium-low |
| `net_profit_margin` | public issuer margins, sector averages | assign ranges by sector and technology | medium |
| `debt_equity_ratio` | annual reports, sector leverage norms | assign by SOE/project/industrial archetype | medium |
| `volatility` | listed comps or sector proxy | use peer-set proxy and cap extreme values | low-medium |
| power price curves | public market or regional proxy | use indexed baseline plus stress spread | medium-low |
| carbon prices | NGFS or TRISK examples | use scenario-consistent curves | medium |

### 9.6 Key Output of Phase 2

By the end of this phase, the repo should have a documented synthetic input package suitable for a power-sector TRISK run, with every field traceable to an assumption note.

---

## 10. Phase 3 - Power-Sector TRISK Pilot

### 10.1 Objective

Run the first credible TRISK pilot on the Vietnam synthetic power book because it has the strongest data fit and the closest match to the original TRISK proof of concept.

### 10.2 Why Power First

- power is the deepest local sector in the repo
- PACTA already models coal, gas, hydro, and renewables trajectories
- TRISK literature is power-centric in its proof of concept
- bank storytelling is strongest in Vietnam power because PDP8, JETP, coal retirement, LNG, and renewables all matter directly

### 10.3 Pilot Scope

Include:

- EVN-related coal and hydro exposure
- PVN Power gas exposure
- renewable IPPs such as Trung Nam, BIM, TTC, T&T where represented
- BOT coal where contract lock-in is a material stress-story feature

Exclude from the first run if needed:

- automotive
- cement
- steel
- coal mining outside simple narrative context

### 10.4 Modeling Goal

Produce outputs that answer:

- which power borrowers face the largest NPV deterioration under transition stress?
- which borrowers face the largest modeled PD increase?
- how does a disorderly transition re-rank borrower risk relative to a simple alignment view?

### 10.5 Work Items

1. Create `scripts/trisk_prepare_inputs.R` to export the minimum legacy TRISK folder structure.
2. Map local fields into TRISK-compatible names.
3. Generate price and carbon curves for a baseline and stress scenario.
4. Build `scripts/trisk_power_demo.R` to run the first pilot.
5. Record all chosen parameters:
   - shock year
   - discount rate
   - risk-free rate
   - market passthrough
   - calibration assumptions

### 10.6 Required Output Tables

- company-level NPV baseline vs stress
- company-level VaR or equivalent stress loss metric
- company-level PD change
- portfolio aggregated expected-loss style summary if feasible in first pass
- sensitivity tables for key parameters

### 10.7 Minimum Sensitivity Package

At minimum, run one-parameter-at-a-time variations for:

- `shock_year`
- `discount_rate`
- `risk_free_rate`
- `market_passthrough`

### 10.8 Exit Criteria for Phase 3

- at least one successful TRISK pilot run on power data
- interpretable company-level ranking table
- sensitivity ranges available for discussion
- methodological caveats documented clearly

---

## 11. Phase 4 - PACTA plus TRISK Integrated Bank Story

### 11.1 Objective

Combine the alignment lens and the stress lens into one bank-facing interpretation layer.

### 11.2 Core Integrated Story Structure

For each relevant borrower or subsector, answer three things:

1. **Alignment:** Is the borrower or exposure aligned with PDP8 and with NZE?
2. **Stress:** If a disorderly transition happens, how large is the estimated valuation or credit shock?
3. **Action:** What should a bank do differently - engage, limit, reprice, monitor, or grow?

### 11.3 Integration Outputs to Build

- borrower prioritization table: alignment gap + TRISK stress score
- sector prioritization matrix: alignment vs stress severity
- portfolio narrative by strategic theme:
  - coal lock-in risk
  - LNG transition ambiguity
  - renewables upside and execution risk
  - SOE vs private borrower differences

### 11.4 Example Borrower Narratives

- **EVN coal subsidiaries:** moderate or severe alignment challenge, potentially meaningful stress under accelerated coal transition, but constrained by public-service and policy context
- **BOT coal plants:** especially important to flag as legally locked-in even when misaligned
- **PVN Power gas assets:** potentially better than coal under domestic transition, but still exposed under stricter NZE pathways
- **Renewable IPPs:** likely better alignment profile, but still exposed to price and execution assumptions

### 11.5 What This Phase Produces

This is the phase where the demo becomes useful to a bank rather than merely technically interesting.

---

## 12. Phase 5 - Final Demo Report for a Prospective Vietnam Bank

### 12.1 Objective

Package the results into a report that feels like a credible prototype advisory deliverable for a prospective client bank.

### 12.2 Report Positioning

The report should be framed as:

"A demonstration of how a Vietnam bank could combine portfolio alignment analytics and transition stress testing using synthetic, publicly anchored data."

It should never imply:

- real borrower financial confidentiality
- production-grade credit modeling
- regulatory capital calculation readiness

### 12.3 Proposed Report Structure

1. Executive summary
2. Why this matters for Vietnam banks now
3. What PACTA shows in the synthetic Vietnam portfolio
4. What TRISK adds beyond PACTA
5. Portfolio snapshot and methodology boundaries
6. Vietnam transition context: PDP8, NDC, JETP, NZE benchmark
7. Power-sector alignment results
8. Power-sector TRISK results
9. Integrated borrower prioritization
10. Strategic implications for the bank
11. Assumptions, caveats, and sensitivity analysis
12. Technical appendix and data dictionary

### 12.4 Required Visuals

- portfolio sector composition
- power technology mix vs scenario targets
- coal trajectory vs PDP8 and NZE
- renewables trajectory vs PDP8 and NZE
- TRISK borrower ranking chart
- alignment vs stress quadrant chart
- sensitivity tornado or table for top borrowers
- assumptions and confidence legend

### 12.5 Required Executive Messages

The report should land three messages:

1. **Coal concentration creates transition vulnerability.**
2. **Renewables and better-positioned power assets create transition resilience and origination opportunity.**
3. **Alignment metrics and stress metrics together are more decision-useful than either alone.**

---

## 13. Data Strategy

### 13.1 Data Layers

Organize the demo around four data layers:

1. **Loanbook layer:** synthetic MCB-style bank exposure
2. **Asset and production layer:** synthetic Vietnam borrower production pathways anchored in public market context
3. **Scenario layer:** PDP8/NDC/NZE and TRISK-compatible stress inputs
4. **Financial features layer:** synthetic but transparent borrower financial-risk parameters

### 13.2 Confidence Tiers

Each dataset or field should be labeled with one of:

- `public_direct`
- `public_derived`
- `synthetic_structural`
- `synthetic_placeholder`

### 13.3 Suggested Metadata Fields

For every synthetic TRISK input table, add optional metadata columns such as:

- `assumption_source`
- `assumption_note`
- `confidence_tier`
- `created_for_demo`

### 13.4 Important Presentation Rule

Where the plan uses real company names, the report should say clearly that exposures, financial features, and stress results are synthetic demonstration inputs, not real bank positions or audited borrower metrics.

---

## 14. Scenario Strategy

### 14.1 PACTA Scenarios

For alignment storytelling, use:

- **PDP8/NDC** as the main domestic benchmark
- **IEA NZE** as the Paris-aligned ambition benchmark
- **optional IEA STEPS** as current-policy baseline if it improves explanation

### 14.2 TRISK Scenarios

TRISK requires a baseline and one or more stress narratives with prices and carbon paths. The practical approach is:

- baseline: domestic-policy-consistent or softer transition scenario
- stress: late-and-sudden or disorderly transition variant with sharper carbon and price shifts

### 14.3 Recommended First Narrative Pair

1. **Baseline:** PDP8-consistent domestic transition with moderate carbon and price shifts
2. **Stress:** disorderly acceleration toward a harsher transition with stronger carbon price and demand effects

### 14.4 Scenario Coherence Rule

Do not create a TRISK stress scenario that is disconnected from the PACTA story. The transition narrative should stay logically linked across:

- production pathway
- power prices
- carbon prices
- shock timing

---

## 15. Synthetic Financial Features Strategy

### 15.1 Objective

Build a transparent synthetic financial feature table keyed by `company_id` for the power pilot.

### 15.2 Company Archetypes

Assign borrowers to archetypes such as:

- state-owned utility
- project-finance coal SPV or BOT
- listed industrial utility
- renewable IPP growth platform
- state energy affiliate

### 15.3 Parameter Logic by Archetype

Example directionality:

- **SOE utility:** lower baseline PD, moderate leverage, lower volatility
- **BOT coal project:** lower short-term cash-flow uncertainty under contract but high transition-stranding sensitivity
- **renewable IPP:** potentially higher leverage during buildout but better long-run alignment
- **gas platform:** intermediate case with ambiguity under different scenarios

### 15.4 Deliverable Table Schema

Recommended first-pass schema:

```text
company_id, company_name, sector, archetype, pd, net_profit_margin,
debt_equity_ratio, volatility, assumption_source, confidence_tier, assumption_note
```

### 15.5 Validation Rule

Every synthetic value should be plausible relative to peer type and should be explainable in one sentence.

---

## 16. Technical Build Plan

### 16.1 Recommended First Implementation Target

Use the legacy TRISK workflow first because the repo's current outputs already look close to that contract and the research brief explicitly recommends it as the lowest-friction starting point.

### 16.2 Proposed Script Sequence

1. `scripts/pacta_vietnam_scenario.R`
2. `scripts/trisk_prepare_inputs.R`
3. `scripts/trisk_power_demo.R`
4. `scripts/generate_trisk_report.R` or integrate into existing report generation pattern

### 16.3 Bridge Responsibilities

The bridge script should:

- read frozen PACTA outputs
- map sector and technology naming to TRISK naming
- export production data in TRISK-ready form
- attach synthetic financial features
- write price and carbon input files
- optionally write capacity factors
- save a manifest of assumptions used in the run

### 16.4 Suggested Legacy Output Folder

Example:

```text
output/trisk_inputs/power_demo/
  abcd_stress_test_input.csv
  prewrangled_financial_data_stress_test.csv
  Scenarios_AnalysisInput.csv
  price_data_long.csv
  ngfs_carbon_price.csv
  prewrangled_capacity_factors.csv
  assumptions_manifest.csv
```

### 16.5 Suggested Run Output Folder

```text
synthesis_output/trisk/power_demo/
  company_npv_results.csv
  company_pd_results.csv
  portfolio_summary.csv
  sensitivity_results.csv
  top_borrowers_alignment_trisk.csv
  figures/
```

---

## 17. Validation and QA Plan

### 17.1 Conceptual QA

- TRISK outputs should line up directionally with PACTA alignment logic
- heavily misaligned coal exposures should not appear as transition winners without a strong reason
- renewables should not appear artificially risk-free if the scenario includes price pressure or financing stress

### 17.2 Data QA

- no missing key identifiers between PACTA and TRISK bridge
- all scenario years covered consistently
- all borrower names mapped consistently across tables
- price and carbon curves checked for monotonicity or intended shape

### 17.3 Model QA

- confirm parameter ranges are economically plausible
- inspect top and bottom outliers manually
- run sensitivity checks before trusting point outputs

### 17.4 Communication QA

- every chart labels whether data is synthetic
- report states whether outputs are alignment metrics, stress metrics, or both
- caveats appear near the findings, not only in the appendix

---

## 18. Risks, Caveats, and How to Present Them

### 18.1 Main Risks

1. the upstream PACTA pipeline is not yet fully stabilized
2. TRISK interface drift between legacy and newer package lines
3. financial features are synthetic and could dominate outputs if poorly calibrated
4. Vietnam-specific price and carbon curves may require proxy logic
5. stakeholders may over-read PD outputs as literal credit-default forecasts

### 18.2 Presentation Mitigations

- use explicit labels like "demo estimate" and "synthetic assumption"
- emphasize ranking and comparative stress, not exact forecast precision
- show sensitivity ranges for the biggest borrowers
- frame PD change as stress-direction indicator, not regulatory PD replacement

### 18.3 Critical Caveat Language for Final Report

Recommended wording:

"These TRISK outputs are best interpreted as comparative transition-stress indicators for scenario analysis and portfolio triage, not as production credit-risk measures or regulatory capital inputs."

---

## 19. Suggested File and Artifact Map

### 19.1 New Data Files

- `data/vietnam_trisk_financial_features.csv`
- `data/vietnam_trisk_price_data_long.csv`
- `data/vietnam_trisk_ngfs_carbon_price.csv`
- `data/vietnam_trisk_capacity_factors.csv`
- `data/vietnam_trisk_name_mapping.csv`

### 19.2 New Scripts

- `scripts/trisk_prepare_inputs.R`
- `scripts/trisk_power_demo.R`
- `scripts/trisk_sensitivity.R` or sensitivity section inside the main demo script

### 19.3 New Outputs

- `output/trisk_inputs/power_demo/`
- `synthesis_output/trisk/power_demo/`
- `reports/PACTA_TRISK_Vietnam_Bank_Demo_Report.html`

### 19.4 New Documentation

- `docs/TRISK_Demo_Assumptions.md`
- `docs/TRISK_PACTA_Integration_Notes.md`

---

## 20. Detailed Workplan by Week

### Week 1 - Lock scope and finish PACTA baseline

- confirm pilot scope and implementation target
- complete debugging of `scripts/pacta_vietnam_scenario.R`
- generate full Vietnam PACTA outputs and freeze baseline artifacts

### Week 2 - Design synthetic TRISK input framework

- define borrower archetypes for power names in the synthetic Vietnam portfolio
- draft synthetic financial features table
- draft PACTA-to-TRISK mapping table
- draft price and carbon path logic

### Week 3 - Build TRISK bridge

- implement `scripts/trisk_prepare_inputs.R`
- export legacy TRISK-ready CSV package
- validate file schemas and identifiers

### Week 4 - Run first power-sector TRISK pilot

- implement `scripts/trisk_power_demo.R`
- run baseline plus stress scenario
- inspect company-level NPV and PD results

### Week 5 - Add sensitivity analysis and refine assumptions

- run parameter sensitivities
- adjust implausible synthetic financial assumptions
- produce top borrower ranking tables and visuals

### Week 6 - Integrate with PACTA results

- build combined alignment and stress tables
- create integrated visuals and executive messages
- draft report outline and appendix materials

### Week 7 - Produce final report draft

- write stakeholder-facing narrative
- embed charts and caveats
- create final HTML report draft

### Week 8 - Review and polish

- methodology review
- wording and disclosure review
- final outputs and handoff notes

---

## 21. Decision Log to Resolve Early

The following decisions should be made before implementation starts in earnest:

1. **Legacy or new TRISK interface first?** Recommendation: legacy first.
2. **Power-only TRISK or multi-sector TRISK in first demo?** Recommendation: power-only TRISK, multi-sector PACTA.
3. **Primary report language?** Recommendation: English with selective Vietnamese labels and examples.
4. **Benchmark set in final report?** Recommendation: PDP8/NDC and IEA NZE, with STEPS optional.
5. **VinFast treatment in the integrated story?** Recommendation: leave in PACTA narrative first; do not force it into the first TRISK pilot if power-only scope is cleaner.
6. **How to present PD outputs?** Recommendation: explicitly as stress indicators, not production PD forecasts.

---

## 22. Definition of Done

This plan is considered successfully executed when all of the following are true:

- the Vietnam PACTA baseline completes reproducibly
- a power-sector TRISK pilot runs successfully from repo-generated inputs
- the repo contains documented synthetic financial and scenario assumptions
- a combined borrower prioritization view exists linking alignment and stress
- a final HTML report exists that a prospective Vietnam bank could read end-to-end
- the report clearly distinguishes public facts, synthetic assumptions, and model outputs
- the result feels decision-useful without overstating certainty

---

*End of Vietnam Bank TRISK Demo Multi-Phase Plan*
*Recommended first implementation step: complete and freeze the Vietnam PACTA baseline before building any TRISK bridge code.*

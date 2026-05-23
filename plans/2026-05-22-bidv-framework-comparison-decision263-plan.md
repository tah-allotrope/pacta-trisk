---
title: "BIDV Framework Comparison and Decision 263 Compliance Mapping"
date: "2026-05-22"
status: "completed"
request: "GAP-01 + GAP-02 from the BIDV gap analysis: build a structured evaluation matrix comparing 5-7 leading portfolio alignment frameworks against BIDV's context, and a Decision 263 compliance mapping document linking the repo's PACTA+TRISK outputs to Vietnam's GHG quota regime for thermal power, steel, and cement."
plan_type: "multi-phase"
research_inputs:
  - "research/2026-04-08_integration-trisk-model-existing.md"
  - "research/future_planning_ideas.md"
  - "reports/2026-05-22-bidv-framework-recommendation-gap-analysis.md"
---

# Plan: BIDV Framework Comparison and Decision 263 Compliance Mapping

## Objective
Produce two tightly coupled advisory documents that form the intellectual core of the BIDV framework recommendation report: (1) a structured evaluation matrix comparing leading portfolio alignment and climate risk frameworks against BIDV's specific context, and (2) a Decision 263 compliance mapping that shows how the repo's PACTA+TRISK analytical stack directly supports BIDV's regulatory obligations under Vietnam's GHG quota regime. These documents convert the repo from a demonstration tool into an advisory deliverable.

## Context Snapshot
- **Current state:** The repo implements PACTA (via `r2dii.*` packages) and TRISK (via `trisk.model`) for power, cement, and steel. The methodology page (`dashboard/pages/4_Methodology.py`) explains these two tools but does not compare them against peer frameworks. No file in the repo references Decision 263, PCAF methodology details, SBTi Financial Institutions, GFANZ sector pathways, or NGFS climate scenarios as portfolio alignment alternatives. The repo's scenario data (`data/vietnam_scenario_ms.csv`, `data/vietnam_scenario_co2.csv`) uses PDP8 and NDC targets but does not frame them through Decision 263 compliance.
- **Desired state:** Two new documents under `docs/`: (a) `docs/bidv_framework_comparison.md` — a scored evaluation matrix comparing 7 frameworks across 10 dimensions relevant to BIDV, with a clear primary/secondary recommendation; (b) `docs/bidv_decision263_mapping.md` — a reference document mapping Decision 263 requirements to the repo's sector taxonomy, data files, and pipeline outputs, showing the full compliance stack. Additionally, a new research brief `research/2026-05-22_portfolio-alignment-frameworks.md` capturing the domain research underpinning the comparison.
- **Key repo surfaces:** `research/2026-04-08_integration-trisk-model-existing.md` (PACTA-TRISK positioning), `docs/PACTA_Beginner_Guide.md` (PACTA methodology), `docs/TRISK_Demo_Assumptions.md` (TRISK inputs/limitations), `docs/trisk_multisector_contract.md` (sector mappings), `intake/SCHEMA.md` (VSIC→ISIC mapping), `data/vietnam_scenario_co2.csv` (SDA pathways), `data/vietnam_abcd.csv` (company data), `dashboard/pages/4_Methodology.py` (existing framing copy).
- **Out of scope:** Building new analytical pipelines, implementing any framework beyond PACTA+TRISK, modifying dashboard pages, ingesting real BIDV data, writing the final compiled report (that is GAP-04).

## Research Inputs
- `research/2026-04-08_integration-trisk-model-existing.md` — Provides the PACTA-TRISK positioning analysis (alignment vs. stress-test, upstream vs. downstream) that will anchor the framework comparison's treatment of PACTA and TRISK. Confirms that TRISK is designed as a downstream complement to PACTA, not a standalone framework. This directly informs how to position the combined PACTA+TRISK stack against single-method alternatives like PCAF or SBTi.
- `research/future_planning_ideas.md` — Idea 3 (Engagement Action Layer) describes how PACTA+TRISK outputs feed borrower engagement, which is relevant for the "output types" dimension of the framework comparison. Confirms the repo's intended use case for BIDV goes beyond measurement to active portfolio management.
- `reports/2026-05-22-bidv-framework-recommendation-gap-analysis.md` — The source gap analysis defining GAP-01 and GAP-02 requirements, BIDV context (20+ Decision 263 clients, PCAF baseline as Output 2.1), and the assumptions this plan must honor (ASM-01 through ASM-05).

## Assumptions and Constraints
- **ASM-001:** Decision 263 (Quyết định 263/QĐ-TTg, 2022) mandates GHG emission inventories, sector-specific quotas, and emission reduction plans for thermal power, steel, and cement facilities. The repo's three TRISK sectors (power, cement, steel) correspond directly to these. Thermal power maps to `coalcap` and `gascap` technologies within the `power` sector.
- **ASM-002:** BIDV's financed emissions baseline (Output 2.1) is PCAF-based. The framework comparison must acknowledge PCAF as the emissions accounting foundation and position PACTA/TRISK as the portfolio alignment and risk layer that sits on top.
- **ASM-003:** The framework comparison will evaluate 7 frameworks: PACTA for Banks, TRISK, PCAF (Partnership for Carbon Accounting Financials), SBTi Financial Institutions, GFANZ Sector Pathways, NGFS Climate Scenarios, and TCFD/ISSB S2 disclosure frameworks.
- **CON-001:** The Decision 263 regulatory text may not be fully available in English. Research must use Vietnamese-language official sources supplemented by GIZ/GTB/World Bank advisory publications. Key requirements will be documented with source citations.
- **CON-002:** No new code or pipeline modifications in this plan. All outputs are markdown documents and research briefs.
- **DEC-001:** The recommendation will position PACTA+TRISK as the primary analytical framework while acknowledging PCAF as the prerequisite accounting layer and TCFD/ISSB as the disclosure output layer. This reflects the repo's existing implementation and the engagement's stated scope.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Domain research on portfolio alignment frameworks and Decision 263 | None | `research/2026-05-22_portfolio-alignment-frameworks.md`, `research/2026-05-22_decision263-vietnam-ghg.md` |
| PHASE-02 | Framework comparison matrix with scored evaluation | PHASE-01 | `docs/bidv_framework_comparison.md` |
| PHASE-03 | Decision 263 compliance mapping document | PHASE-01 | `docs/bidv_decision263_mapping.md` |
| PHASE-04 | Cross-validation and integration review | PHASE-02, PHASE-03 | Updated docs with cross-references, verification checklist |

## Detailed Phases

### PHASE-01 - Domain Research
**Goal**
Gather authoritative information on (a) the 7 portfolio alignment frameworks to be compared, and (b) Vietnam's Decision 263 requirements, producing two research briefs that serve as the evidence base for the subsequent documents.

**Tasks**
- [x] TASK-01-01: Research PCAF methodology — data requirements, sector coverage, output types, implementation complexity, cost, open-source tooling. Focus on PCAF's relationship to PACTA (PCAF = emissions accounting, PACTA = alignment assessment). Document the PCAF Standard v3 scope and its treatment of thermal power, steel, and cement asset classes.
- [x] TASK-01-02: Research SBTi Financial Institutions framework — target-setting methodology, sector-specific SDA and convergence approaches, data requirements for power/steel/cement, validation process, cost/time commitment, public tools (SBTi Target Validation Tool). Note SBTi's 2024 updates to financial institution targets.
- [x] TASK-01-03: Research GFANZ sector pathways — Net Zero Banking Alliance (NZBA) guidelines, sector-specific transition plans for power/steel/cement, reporting requirements, how GFANZ pathways relate to IEA NZE and NGFS scenarios. Note that GFANZ is a voluntary commitment framework, not a quantitative tool.
- [x] TASK-01-04: Research NGFS climate scenarios as portfolio alignment inputs — NGFS Phase V scenario framework, how banks use NGFS for climate stress testing (supervisory vs. internal use), relationship to the repo's existing scenario grid (which uses NGFS-named aliases per `docs/trisk_scenario_grid_contract.md`), Vietnam-specific NGFS data availability.
- [x] TASK-01-05: Research TCFD/ISSB S2 as disclosure framework — TCFD's four pillars, ISSB IFRS S2 Climate-related Disclosures, how these create demand for the analytical outputs that PACTA/TRISK produce, Vietnam's adoption status (SBV green taxonomy, TCFD-equivalent requirements).
- [x] TASK-01-06: Research IFC Performance Standards and Equator Principles — relevance to Vietnamese commercial banks, E&S requirements for project finance in power/cement/steel, how IFC PS relates to portfolio-level climate risk tools.
- [x] TASK-01-07: Condense existing repo knowledge on PACTA and TRISK into comparison-ready summaries by extracting key dimensions from `docs/PACTA_Beginner_Guide.md`, `docs/TRISK_Demo_Assumptions.md`, and `research/2026-04-08_integration-trisk-model-existing.md`.
- [x] TASK-01-08: Research Decision 263 (Quyết định 263/QĐ-TTg) — scope of coverage (which sectors, which facility size thresholds), GHG inventory requirements (reporting since 2025), sector-specific emission quotas (thermal power, steel, cement), emission reduction plan requirements, enforcement mechanisms, relationship to Law on Environmental Protection 2020, MONRE implementation guidance. Use Vietnamese government sources, GIZ Vietnam publications, and World Bank/IFC advisory documents.
- [x] TASK-01-09: Research the SBV green taxonomy and its relationship to Decision 263 — how SBV classifies green/transition lending, what reporting Vietnamese commercial banks must do, how BIDV's climate risk management obligations relate to both Decision 263 (borrower-side) and SBV taxonomy (bank-side).
- [x] TASK-01-10: Write `research/2026-05-22_portfolio-alignment-frameworks.md` — structured research brief covering all 7 frameworks with consistent dimensions: purpose, methodology type, data inputs, sector coverage, output types, cost, open-source availability, Vietnam relevance.
- [x] TASK-01-11: Write `research/2026-05-22_decision263-vietnam-ghg.md` — structured research brief covering Decision 263 requirements, sector coverage, timeline, enforcement, and the regulatory landscape (Law on Environmental Protection, SBV taxonomy, MONRE guidance).

**Files / Surfaces**
- `research/2026-05-22_portfolio-alignment-frameworks.md` - New: framework research brief.
- `research/2026-05-22_decision263-vietnam-ghg.md` - New: Decision 263 research brief.
- `docs/PACTA_Beginner_Guide.md` - Read: extract PACTA methodology dimensions.
- `docs/TRISK_Demo_Assumptions.md` - Read: extract TRISK input requirements and caveats.
- `research/2026-04-08_integration-trisk-model-existing.md` - Read: extract PACTA-TRISK positioning.
- `docs/trisk_scenario_grid_contract.md` - Read: confirm NGFS alias structure.

**Dependencies**
- None. This phase is pure research.

**Exit Criteria**
- [x] `research/2026-05-22_portfolio-alignment-frameworks.md` exists and covers all 7 frameworks with consistent dimensions.
- [x] `research/2026-05-22_decision263-vietnam-ghg.md` exists and documents Decision 263's sector coverage, quota structure, and timeline.
- [x] Each framework entry includes: purpose, methodology type, data inputs, sector coverage (power/steel/cement explicitly), output types, cost, open-source availability, and Vietnam relevance rating.

**Phase Risks**
- **RISK-01-01:** Decision 263 text may be difficult to source in English. Mitigation: use Vietnamese-language official sources and cross-reference with GIZ/GTB advisory publications; document source URLs and access dates. Flag any requirements that could not be independently verified.
- **RISK-01-02:** Framework documentation may be paywalled (e.g., SBTi validation tools, PCAF Standard v3 full text). Mitigation: use publicly available methodology summaries, official website descriptions, and peer-reviewed publications that cite the frameworks. Note any dimensions where full documentation was not accessible.

### PHASE-02 - Framework Comparison Matrix
**Goal**
Build a scored evaluation matrix comparing the 7 frameworks across dimensions relevant to BIDV, producing a clear primary/secondary recommendation with rationale.

**Tasks**
- [x] TASK-02-01: Define the 10 evaluation dimensions for the comparison matrix:
  1. Data input requirements (what BIDV needs to provide)
  2. Sector coverage (thermal power, steel, cement specifically)
  3. Vietnam regulatory compatibility (Decision 263, SBV taxonomy)
  4. Output types (alignment metric, risk metric, disclosure output, engagement artifact)
  5. Implementation complexity (technical capacity needed)
  6. Cost (licensing, external advisory, ongoing maintenance)
  7. Open-source availability (tools, code, data)
  8. Time to first results (from data preparation to actionable output)
  9. Complementarity with PCAF baseline (since Output 2.1 is PCAF-based)
  10. Maturity and institutional adoption (track record with ASEAN/emerging market banks)
- [x] TASK-02-02: Score each of the 7 frameworks across all 10 dimensions using a 3-level scale: Strong Fit (framework addresses this dimension well for BIDV), Partial Fit (framework addresses this but with limitations for BIDV's context), Weak Fit (framework does not meaningfully address this for BIDV). Include a one-line justification for each score.
- [x] TASK-02-03: Write a framework-by-framework evaluation narrative (one section per framework, ~200-400 words each) covering: what the framework does, how it works, what BIDV would need to use it, and its specific strengths/weaknesses for the Decision 263 context.
- [x] TASK-02-04: Write the recommendation section: primary framework recommendation (PACTA+TRISK for portfolio alignment and transition stress testing), secondary recommendation (PCAF as the prerequisite accounting layer, already in place as Output 2.1), tertiary recommendation (TCFD/ISSB S2 as the disclosure output framework). Include rationale anchored to the scored matrix.
- [x] TASK-02-05: Write the complementarity analysis: how the recommended stack (PCAF → PACTA → TRISK → TCFD/ISSB) creates a complete pipeline from emissions measurement through alignment assessment to risk quantification to external disclosure. Map this to BIDV's stated needs.
- [x] TASK-02-06: Write the limitations section: where the recommended approach falls short (e.g., PACTA requires asset-level data that may be incomplete, TRISK outputs are not regulatory PDs, no oil & gas coverage), and what BIDV should consider for future phases.
- [x] TASK-02-07: Save as `docs/bidv_framework_comparison.md` with the evaluation matrix as a markdown table, framework narratives, recommendation, complementarity analysis, and limitations.

**Files / Surfaces**
- `docs/bidv_framework_comparison.md` - New: the framework comparison deliverable.
- `research/2026-05-22_portfolio-alignment-frameworks.md` - Read: source evidence for framework evaluations.
- `research/2026-04-08_integration-trisk-model-existing.md` - Read: PACTA-TRISK complementarity analysis.
- `dashboard/pages/4_Methodology.py` - Read: existing PACTA/TRISK framing copy to maintain consistency.

**Dependencies**
- PHASE-01 research briefs must be complete.

**Exit Criteria**
- [x] `docs/bidv_framework_comparison.md` exists with a scored 7×10 evaluation matrix.
- [x] Each framework has a narrative section with BIDV-specific strengths/weaknesses.
- [x] The recommendation section clearly states primary/secondary/tertiary framework choices with rationale tied to matrix scores.
- [x] The complementarity analysis shows the PCAF → PACTA → TRISK → TCFD/ISSB pipeline.
- [x] Limitations are documented honestly, including where peer frameworks outperform the recommendation.

**Phase Risks**
- **RISK-02-01:** Evaluation may appear biased toward PACTA since the repo only implements PACTA. Mitigation: include genuine trade-off analysis; document specific scenarios where SBTi or PCAF may be better fits (e.g., SBTi for target validation, PCAF for multi-asset-class coverage). Acknowledge that the repo's implementation of PACTA+TRISK is both a strength (proven demonstration) and a potential bias source.

### PHASE-03 - Decision 263 Compliance Mapping
**Goal**
Produce a mapping document that shows exactly how the repo's PACTA+TRISK outputs support BIDV's compliance with Decision 263, creating a direct line from regulatory requirements to analytical capabilities.

**Tasks**
- [x] TASK-03-01: Write the Decision 263 overview section: what the decision requires, which sectors are covered, key dates (2025 inventory reporting, quota implementation timeline), enforcement mechanisms, relationship to Law on Environmental Protection 2020 (Article 91).
- [x] TASK-03-02: Build the sector mapping table:

  | Decision 263 Sector | Facility Type | PACTA Sector | PACTA Technologies | TRISK Sector | TRISK Technologies | Repo Data Files |
  |---|---|---|---|---|---|---|
  | Thermal power | Coal, gas plants | `power` | `coalcap`, `gascap` | `Power` | `CoalCap`, `GasCap` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_ms.csv` |
  | Steel | BF/BOF, EAF | `steel` | `open_hearth`, `electric` | `Steel` | `OpenHearth`, `ElectricArc` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_co2.csv` |
  | Cement | Integrated | `cement` | `integrated facility` | `Cement` | `IntegratedFacility` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_co2.csv` |

- [x] TASK-03-03: Build the compliance capability mapping: for each Decision 263 requirement (emission inventory, GHG quotas, emission reduction plans), show which repo capability addresses it:
  - Emission inventory → PCAF financed emissions baseline (Output 2.1) + PACTA matching (`scripts/pacta_vietnam_scenario.R`)
  - Sector-specific quotas → PACTA SDA analysis (emission intensity pathways in `data/vietnam_scenario_co2.csv`) + PACTA alignment gap calculation
  - Emission reduction plans → TRISK stress testing (scenario-based NPV/PD impact) + sector prioritization (to be built in GAP-03) + borrower engagement (to be built in GAP-07)
- [x] TASK-03-04: Write the "BIDV compliance stack" narrative: how PCAF (Output 2.1) + PACTA alignment + TRISK stress testing together form a three-layer compliance and risk management architecture that maps to Decision 263's three requirements (measure → compare → act).
- [x] TASK-03-05: Map the repo's synthetic borrowers to typical Decision 263 entities to demonstrate the analytical coverage:
  - EVN subsidiaries (Vinh Tan, Duyen Hai, Mong Duong) → thermal power quota entities
  - VICEM → cement quota entity
  - Hoa Phat Group → steel quota entity
  - Vinacomin → coal mining (not directly Decision 263 but indirectly relevant)
- [x] TASK-03-06: Write the data availability assessment: what emissions data BIDV can expect from its Decision 263 clients (since they are legally required to collect and report emissions data from 2025), and how that data feeds into the PACTA+TRISK pipeline via the BYOL intake (`intake/SCHEMA.md`).
- [x] TASK-03-07: Write the gap acknowledgment: what Decision 263 requirements the current pipeline does NOT address (e.g., verification of borrower-reported emissions, quota trading mechanisms if implemented, facility-level vs. company-level analysis).
- [x] TASK-03-08: Save as `docs/bidv_decision263_mapping.md` with all sections above.

**Files / Surfaces**
- `docs/bidv_decision263_mapping.md` - New: the Decision 263 mapping deliverable.
- `research/2026-05-22_decision263-vietnam-ghg.md` - Read: source evidence for Decision 263 requirements.
- `docs/trisk_multisector_contract.md` - Read: sector mapping rules to ensure consistency.
- `intake/SCHEMA.md` - Read: VSIC→ISIC mapping that connects to Decision 263 entity classification.
- `data/vietnam_abcd.csv` - Read: confirm synthetic borrower coverage of Decision 263 entity types.
- `data/vietnam_scenario_co2.csv` - Read: confirm SDA pathways cover cement and steel emission intensity.

**Dependencies**
- PHASE-01 research briefs must be complete (especially the Decision 263 research brief).

**Exit Criteria**
- [x] `docs/bidv_decision263_mapping.md` exists with Decision 263 overview, sector mapping table, compliance capability mapping, and data availability assessment.
- [x] The sector mapping table is consistent with `docs/trisk_multisector_contract.md`.
- [x] The compliance capability mapping covers all three Decision 263 requirements (inventory, quotas, reduction plans).
- [x] Gaps and limitations are honestly documented.
- [x] Source citations are provided for all Decision 263 requirements.

**Phase Risks**
- **RISK-03-01:** Decision 263 implementation details (quota levels, facility size thresholds) may not be publicly available yet. Mitigation: document what is known from the decision text and MONRE guidance; flag specific quota levels as "TBD — subject to MONRE implementing regulations" where necessary. The mapping structure remains valid even without exact quota numbers.

### PHASE-04 - Cross-Validation and Integration
**Goal**
Verify internal consistency between the framework comparison and Decision 263 mapping, add cross-references, and confirm the documents are ready to feed into the final report generator (GAP-04).

**Tasks**
- [x] TASK-04-01: Cross-reference the framework comparison's "Vietnam regulatory compatibility" scores against the Decision 263 mapping. Verify that the scoring is consistent — if PACTA scores "Strong Fit" on regulatory compatibility, the Decision 263 mapping must demonstrate that fit concretely.
- [x] TASK-04-02: Verify that every sector mentioned in the Decision 263 mapping has a corresponding entry in the framework comparison's sector coverage assessment.
- [x] TASK-04-03: Add a "How to Read These Documents Together" section to `docs/bidv_framework_comparison.md` that explains the relationship: the comparison evaluates frameworks → the mapping shows how the recommended framework connects to Decision 263 → together they form the advisory core of the final report.
- [x] TASK-04-04: Review all documents for consistency in terminology: Decision 263 sector names, PACTA sector names, TRISK sector names, technology names. Create a terminology note if needed.
- [x] TASK-04-05: Verify that the documents can be consumed by a report generator that reads markdown and produces HTML — no embedded binary assets, all tables in standard markdown format, all references as inline citations.

**Files / Surfaces**
- `docs/bidv_framework_comparison.md` - Update: add cross-references and "how to read" section.
- `docs/bidv_decision263_mapping.md` - Update: add cross-references to framework comparison.
- `research/2026-05-22_portfolio-alignment-frameworks.md` - Read: verify consistency with framework comparison.
- `research/2026-05-22_decision263-vietnam-ghg.md` - Read: verify consistency with mapping document.

**Dependencies**
- PHASE-02 and PHASE-03 must be complete.

**Exit Criteria**
- [x] Framework comparison regulatory compatibility scores are consistent with Decision 263 mapping evidence.
- [x] All sector names and technology names are consistent across both documents.
- [x] Both documents contain cross-references to each other.
- [x] Documents are valid markdown with no formatting issues that would break HTML rendering.

**Phase Risks**
- **RISK-04-01:** Inconsistencies discovered between documents may require rework in earlier phases. Mitigation: this is expected and accounted for — PHASE-04 is intentionally a review phase. Budget time for one revision pass on each document.

## Verification Strategy
- **MANUAL-001:** Read both deliverable documents end-to-end and verify that a reader with no repo context can understand the framework recommendation and Decision 263 mapping.
- **MANUAL-002:** Check the 7×10 evaluation matrix for internal consistency — no framework should score "Strong Fit" on a dimension that contradicts its documented limitations.
- **MANUAL-003:** Verify all cited repo file paths exist by running `ls` on each referenced path.
- **MANUAL-004:** Confirm the sector mapping table in `docs/bidv_decision263_mapping.md` matches the mappings in `docs/trisk_multisector_contract.md`.
- **MANUAL-005:** Verify that the recommended framework stack (PCAF → PACTA → TRISK → TCFD/ISSB) is logically ordered and that each layer's outputs are the next layer's inputs.

## Risks and Alternatives
- **RISK-001:** The framework comparison may be seen as a literature review rather than a practical recommendation. Mitigation: every framework evaluation must include a "What BIDV would need to do" subsection with concrete steps, not just methodology descriptions.
- **RISK-002:** Decision 263 is relatively new (2022) and implementation details may be evolving. Mitigation: date-stamp all regulatory references and include a "Regulatory Update Note" section advising BIDV to re-validate against MONRE's latest implementing guidelines.
- **ALT-001:** Alternative approach — hire a Vietnamese regulatory consultant to write the Decision 263 mapping instead of researching from public sources. Not chosen because: (a) the mapping structure must align with the repo's sector taxonomy, which requires codebase knowledge; (b) the timeline is tight; (c) the consultant's output would still need to be integrated with the framework comparison. However, the mapping document should be reviewed by a Vietnamese regulatory expert before final delivery to BIDV.

## Grill Me
1. **Q-001:** Should the framework comparison include frameworks beyond the 7 listed (PACTA, TRISK, PCAF, SBTi FI, GFANZ, NGFS, TCFD/ISSB)? For example, should it cover the Transition Pathway Initiative (TPI), Carbon Tracker's Carbon Budget analysis, or UNEP FI TCFD Banking Pilots?
   - **Recommended default:** Stick with 7. These cover the major categories (accounting, alignment, stress testing, target setting, disclosure) without bloating the comparison. Mention TPI and Carbon Tracker in a "Other Frameworks" footnote.
   - **Why this matters:** Adding more frameworks increases research time proportionally (~0.5 day per framework) and makes the matrix harder to read.
   - **If answered differently:** Add the additional frameworks to PHASE-01 research tasks and expand the matrix dimensions. May push the plan from 1 week to 1.5 weeks.

2. **Q-002:** Should the Decision 263 mapping include sector-specific GHG quota levels (e.g., tonnes CO2e per MWh for thermal power), or is the structural mapping (which requirements → which pipeline outputs) sufficient?
   - **Recommended default:** Include quota levels where publicly available, with "TBD" placeholders where not. The structural mapping is the primary deliverable; specific quota numbers are a bonus that increases credibility.
   - **Why this matters:** If exact quota levels are included, the document becomes a quantitative reference that BIDV can use directly. If not, it remains a qualitative framework guide.
   - **If answered differently:** If quota levels are required, additional research time (~1 day) is needed, and BIDV or GTB may need to supply MONRE implementing regulations that are not publicly available.

3. **Q-003:** What level of bilingual (Vietnamese/English) content is expected in these documents?
   - **Recommended default:** English-only for the framework comparison and Decision 263 mapping documents. Vietnamese terminology used inline where it aids precision (e.g., "Quyết định 263/QĐ-TTg" for Decision 263, "Bộ Tài nguyên và Môi trường" for MONRE). The final compiled report (GAP-04) will add Vietnamese executive summary.
   - **Why this matters:** Full bilingual documents roughly double the writing effort.
   - **If answered differently:** Add a Vietnamese translation task to PHASE-02 and PHASE-03.

## Suggested Next Step
Accept the recommended defaults for the Grill Me questions, then begin PHASE-01 domain research. The research tasks can be parallelized: TASK-01-01 through TASK-01-07 (framework research) are independent of TASK-01-08 through TASK-01-09 (Decision 263 research).

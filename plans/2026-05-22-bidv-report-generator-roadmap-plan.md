---
title: "BIDV Framework Recommendation Report Generator and Implementation Roadmap"
date: "2026-05-22"
status: "draft"
request: "GAP-04 + GAP-05 from the BIDV gap analysis: build a report generator that assembles the framework comparison, Decision 263 mapping, sector prioritization, and implementation roadmap into a professional advisory HTML report for BIDV delivery. Additionally, write the client-facing implementation roadmap content that guides BIDV through data preparation, baseline establishment, risk assessment, action, and monitoring phases."
plan_type: "multi-phase"
research_inputs:
  - "research/future_planning_ideas.md"
  - "reports/2026-05-22-bidv-framework-recommendation-gap-analysis.md"
---

# Plan: BIDV Framework Recommendation Report Generator and Implementation Roadmap

## Objective
Build the final assembly layer that converts all upstream advisory content (framework comparison, Decision 263 mapping, sector prioritization, implementation roadmap) into a professional, self-contained HTML report deliverable for BIDV. This includes writing the client-facing implementation roadmap content and building an R script that renders the compiled report with embedded charts, data tables, and advisory narrative.

## Context Snapshot
- **Current state:** The repo has a proven HTML report generation pattern (`scripts/generate_report.R`, 23 existing reports in `reports/`) that uses base64-encoded images and inline CSS. The Vietnam PACTA report (`reports/PACTA_Vietnam_Bank_Report.html`) is a 12-section bilingual document that demonstrates the template architecture. The upstream advisory content (framework comparison, Decision 263 mapping, sector prioritization) will be produced by companion plans (`plans/2026-05-22-bidv-framework-comparison-decision263-plan.md` and `plans/2026-05-22-bidv-sector-prioritization-plan.md`). No implementation roadmap content for a client bank exists — the closest artifact is the BYOL intake plan (`plans/2026-05-19-byol-pilot-intake-plan.md`), which is an internal engineering plan.
- **Desired state:** (a) A new document `docs/bidv_implementation_roadmap.md` containing a 5-phase adoption roadmap for BIDV with timelines, resource requirements, and integration guidance tied to Decision 263 milestones. (b) A new script `scripts/generate_bidv_report.R` that reads all advisory content (markdown documents + pipeline CSVs + chart PNGs) and renders a single self-contained HTML report. (c) The rendered report `reports/BIDV_Framework_Recommendation_Report.html` — the final deliverable.
- **Key repo surfaces:** `scripts/generate_report.R` (existing HTML generation pattern), `reports/PACTA_Vietnam_Bank_Report.html` (template reference for section structure), `docs/bidv_framework_comparison.md` (upstream — from companion plan), `docs/bidv_decision263_mapping.md` (upstream — from companion plan), `synthesis_output/prioritization/` (upstream — from companion plan), `intake/SCHEMA.md` and `intake/README.md` (data preparation reference), `dashboard/lib/branding.py` (Allotrope styling reference), `plans/vietnam_bank_pacta_scenario_plan.md` (phasing pattern reference).
- **Out of scope:** Dashboard modifications, BIDV real data ingestion, Vietnamese full translation (English with Vietnamese terminology inline), DOCX/PDF rendering (HTML is primary; PDF can be browser-printed).

## Research Inputs
- `research/future_planning_ideas.md` — Idea 3 (Engagement & Disclosure Output Layer) describes a "regulator/board disclosure pack generator" aligned to TCFD pillars. The report generator in this plan serves a similar purpose but is broader (advisory recommendation, not just disclosure). The TCFD pillar structure (Governance, Strategy, Risk Management, Metrics & Targets) is reusable as a framing device for the implementation roadmap's "integration with existing risk management" section.
- `reports/2026-05-22-bidv-framework-recommendation-gap-analysis.md` — GAP-04 specification: requires a report template with executive summary, framework comparison, sector prioritization, implementation roadmap, and methodology appendix. GAP-05 specification: requires a phased adoption roadmap with data preparation, baseline, risk assessment, action, and monitoring phases.

## Assumptions and Constraints
- **ASM-001:** All upstream advisory content will be available as markdown documents and CSV/PNG files before this plan's PHASE-03 (report assembly). The companion plans produce: `docs/bidv_framework_comparison.md`, `docs/bidv_decision263_mapping.md`, `docs/bidv_sector_prioritization_methodology.md`, `synthesis_output/prioritization/sector_priority_ranking.csv`, `synthesis_output/prioritization/sector_priority_chart.png`.
- **ASM-002:** The report is a GTB deliverable to BIDV — professional advisory format, not an internal project artifact. Tone should be consultative, not technical. The audience is BIDV's senior risk management and ESG leadership.
- **ASM-003:** The report uses the synthetic MCB portfolio as an illustrative demonstration. All data-driven sections must include a prominent note: "Illustrative results based on synthetic portfolio. BIDV-specific results will be produced upon data onboarding."
- **CON-001:** The report must be a single self-contained HTML file (no external dependencies) consistent with the repo's existing report format. Target size: under 2 MB.
- **CON-002:** The R report generator must work with the existing R package set (`dplyr`, `readr`, `ggplot2`, `base64enc`, `htmltools` or raw HTML string construction). No new package dependencies.
- **DEC-001:** The implementation roadmap targets a 6-month horizon for BIDV adoption, broken into 5 phases of roughly 4-6 weeks each. This is based on the assumption that BIDV already has a PCAF baseline (Output 2.1) and 20+ Decision 263 clients with emissions data collection underway since 2025.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Write the BIDV implementation roadmap content | None | `docs/bidv_implementation_roadmap.md` |
| PHASE-02 | Design the report template structure | PHASE-01 | `docs/bidv_report_template_spec.md` |
| PHASE-03 | Build the report generator script | PHASE-02, upstream plans | `scripts/generate_bidv_report.R` |
| PHASE-04 | Render, verify, and package the final report | PHASE-03 | `reports/BIDV_Framework_Recommendation_Report.html` |

## Detailed Phases

### PHASE-01 - Implementation Roadmap Content
**Goal**
Write the client-facing implementation roadmap that guides BIDV through adopting the recommended PACTA+TRISK framework, anchored to Decision 263 milestones and structured around BIDV's organizational reality.

**Tasks**
- [ ] TASK-01-01: Write Phase 1 — Data Preparation (Weeks 1-6):
  - Extract BIDV's loanbook for Decision 263 sectors (thermal power, steel, cement) in the format defined by `intake/SCHEMA.md`
  - Collect emissions data from Decision 263 clients (leveraging the 2025 reporting mandate — clients are legally required to have this data)
  - Map borrower VSIC codes to ISIC/PACTA sectors using the BYOL intake validation (`scripts/intake_validate_and_map.R`)
  - Identify data gaps: which borrowers have emissions data, which need follow-up requests
  - Resource requirements: 1 data analyst (part-time), ESG team coordination with relationship managers
  - Deliverable: normalized loanbook CSV ready for PACTA pipeline ingestion

- [ ] TASK-01-02: Write Phase 2 — Baseline Establishment (Weeks 5-10):
  - Run PACTA alignment analysis on BIDV's Decision 263 portfolio
  - Produce sector-level alignment gaps for power (market share vs. PDP8/NZE), cement (SDA vs. emission intensity targets), steel (SDA vs. emission intensity targets)
  - Cross-reference PACTA alignment results with PCAF financed emissions baseline (Output 2.1) to create a combined view: total emissions AND alignment trajectory
  - Resource requirements: 1 quantitative analyst (or GTB support), R environment setup
  - Deliverable: PACTA alignment report for BIDV's Decision 263 portfolio

- [ ] TASK-01-03: Write Phase 3 — Risk Assessment (Weeks 9-16):
  - Run TRISK transition stress tests on BIDV's Decision 263 borrowers for power, cement, and steel
  - Produce borrower-level NPV change and PD change estimates under baseline vs. stress scenarios
  - Run the sector prioritization module to rank sectors by composite alignment + stress + exposure score
  - Conduct sensitivity analysis across shock year, discount rate, and market passthrough parameters
  - Resource requirements: 1 quantitative analyst, risk team review of stress-test methodology
  - Deliverable: sector prioritization ranking with borrower-level stress-test detail

- [ ] TASK-01-04: Write Phase 4 — Action Planning (Weeks 15-20):
  - Prioritize borrower engagement based on sector ranking and individual stress scores
  - Draft borrower engagement communications requesting transition plans, capex commitments, and emissions reduction timelines
  - Establish sector exposure limits or concentration guidelines informed by alignment and stress results
  - Integrate climate risk signals into BIDV's credit review process for Decision 263 borrowers
  - Resource requirements: credit risk team, ESG team, relationship management coordination
  - Deliverable: borrower engagement plan with sector-level exposure management strategy

- [ ] TASK-01-05: Write Phase 5 — Monitoring and Reporting (Weeks 19-24, then quarterly):
  - Establish quarterly re-run schedule for PACTA alignment and TRISK stress testing
  - Track borrower progress against requested transition plans
  - Update Decision 263 compliance status as MONRE publishes implementing regulations
  - Prepare TCFD-aligned or ISSB S2-aligned disclosure materials using PACTA+TRISK outputs
  - Report to BIDV board and SBV as required
  - Resource requirements: ongoing ESG team capacity (0.5-1 FTE), quarterly GTB support for pipeline re-runs
  - Deliverable: quarterly climate risk monitoring report and annual disclosure pack

- [ ] TASK-01-06: Write the integration guidance section:
  - How PACTA alignment outputs connect to BIDV's credit risk appetite framework
  - How TRISK stress-test outputs complement (not replace) BIDV's existing stress testing under SBV Circular 13
  - How Decision 263 compliance monitoring integrates with BIDV's ESG governance structure
  - How TCFD/ISSB disclosure outputs connect to BIDV's annual sustainability reporting

- [ ] TASK-01-07: Write the resource requirements summary table:
  | Phase | Duration | BIDV Staff | GTB Support | Technology |
  |---|---|---|---|---|
  | Data Preparation | 6 weeks | 1 data analyst (PT) | Template + validation | BYOL intake tools |
  | Baseline | 6 weeks | 1 quant analyst | PACTA pipeline run | R environment |
  | Risk Assessment | 8 weeks | 1 quant + risk review | TRISK pipeline run | R environment |
  | Action Planning | 6 weeks | Credit + ESG teams | Advisory | None |
  | Monitoring | Ongoing | 0.5-1 FTE ESG | Quarterly re-runs | R environment |

- [ ] TASK-01-08: Save as `docs/bidv_implementation_roadmap.md` with all sections, resource table, and Decision 263 milestone cross-references.

**Files / Surfaces**
- `docs/bidv_implementation_roadmap.md` - New: the roadmap deliverable.
- `intake/SCHEMA.md` - Read: data preparation requirements for Phase 1.
- `intake/README.md` - Read: intake workflow overview for Phase 1.
- `plans/vietnam_bank_pacta_scenario_plan.md` - Read: phasing pattern reference (9-week roadmap structure).
- `docs/demo-script.md` - Read: analytical journey reference for Phase 2-3 descriptions.

**Dependencies**
- None for the roadmap content itself. The framework comparison and Decision 263 mapping (from companion plan) will be cross-referenced but are not blocking for the roadmap writing.

**Exit Criteria**
- [ ] `docs/bidv_implementation_roadmap.md` exists with 5 phases, resource table, and integration guidance.
- [ ] Each phase has: timeline, activities, resource requirements, and deliverable.
- [ ] Decision 263 milestones are referenced where relevant.
- [ ] The roadmap is actionable by a BIDV team with GTB support — no steps require unexplained technical knowledge.

**Phase Risks**
- **RISK-01-01:** Roadmap timelines may not reflect BIDV's actual organizational capacity. Mitigation: present timelines as "recommended" with a note that BIDV should adjust based on internal capacity and competing priorities. Include a "fast track" variant (16 weeks) for banks with strong existing ESG teams.

### PHASE-02 - Report Template Design
**Goal**
Design the section structure, visual layout, and content flow for the BIDV framework recommendation report, producing a specification that guides the R script development.

**Tasks**
- [ ] TASK-02-01: Define the report section structure (10 sections):
  1. Cover page — title, date, confidentiality notice, GTB/Allotrope branding
  2. Executive summary — 1-page overview: what BIDV should do, why, and by when
  3. BIDV context — Decision 263 obligations, sector exposure summary, PCAF baseline status
  4. Framework landscape — evaluation matrix from `docs/bidv_framework_comparison.md`
  5. Framework recommendation — primary/secondary/tertiary stack with rationale
  6. Sector prioritization — ranking table and chart from `synthesis_output/prioritization/`
  7. Decision 263 compliance mapping — from `docs/bidv_decision263_mapping.md`
  8. Implementation roadmap — 5-phase plan from `docs/bidv_implementation_roadmap.md`
  9. Risk assessment — key risks to implementation and mitigation strategies
  10. Methodology appendix — PACTA and TRISK methodology summaries, data sources, caveats

- [ ] TASK-02-02: Define the visual design elements:
  - CSS color scheme: Allotrope blue (#1a5276) for headers, GTB green accent for call-to-action boxes, neutral grays for body text
  - Typography: system sans-serif stack for screen readability
  - KPI cards for executive summary (3-4 key numbers: number of Decision 263 clients, portfolio exposure in Decision 263 sectors, highest-priority sector, recommended framework)
  - Tables styled consistently with the existing `reports/PACTA_Vietnam_Bank_Report.html` pattern
  - Chart embedding: base64-encoded PNGs in `<img>` tags (existing pattern)
  - Synthetic data disclaimer: red-bordered box at top of every data-driven section

- [ ] TASK-02-03: Define the content sourcing map — for each section, specify exactly which source file provides the content and whether it is rendered as markdown→HTML, copied verbatim, or extracted from CSV:
  - Section 1: hardcoded HTML
  - Section 2: authored in the R script (summary of key findings)
  - Section 3: authored in the R script + data from `data/vietnam_loanbook.csv` sector exposure table
  - Section 4: rendered from `docs/bidv_framework_comparison.md` (the evaluation matrix section)
  - Section 5: rendered from `docs/bidv_framework_comparison.md` (the recommendation section)
  - Section 6: data from `synthesis_output/prioritization/sector_priority_ranking.csv` + chart from `sector_priority_chart.png`
  - Section 7: rendered from `docs/bidv_decision263_mapping.md`
  - Section 8: rendered from `docs/bidv_implementation_roadmap.md`
  - Section 9: authored in the R script (risk register table)
  - Section 10: condensed from `docs/PACTA_Beginner_Guide.md` and `docs/TRISK_Demo_Assumptions.md`

- [ ] TASK-02-04: Save as `docs/bidv_report_template_spec.md` with section list, visual design specification, and content sourcing map.

**Files / Surfaces**
- `docs/bidv_report_template_spec.md` - New: template specification.
- `reports/PACTA_Vietnam_Bank_Report.html` - Read: reference for existing report CSS and section structure.
- `scripts/generate_report.R` - Read: reference for existing HTML generation pattern.
- `dashboard/lib/branding.py` - Read: Allotrope color scheme and footer copy reference.

**Dependencies**
- PHASE-01 implementation roadmap content must be available (to confirm section 8 structure).

**Exit Criteria**
- [ ] Template spec exists with all 10 sections defined.
- [ ] Content sourcing map specifies the exact source file and rendering method for every section.
- [ ] Visual design elements are specified with enough detail for R script implementation.

**Phase Risks**
- **RISK-02-01:** Minimal risk — this is a design document, not code.

### PHASE-03 - Report Generator Script
**Goal**
Build the R script that reads all upstream content and pipeline outputs and renders the complete BIDV framework recommendation report as a self-contained HTML file.

**Tasks**
- [ ] TASK-03-01: Create `scripts/generate_bidv_report.R` with the following structure:
  - Section 1: Configuration — input file paths, output path, branding parameters
  - Section 2: Markdown readers — functions to read markdown files and convert key sections to HTML (using simple regex-based markdown→HTML conversion for headers, tables, bold, italic, lists — consistent with the existing `scripts/generate_report.R` pattern which does not use an external markdown renderer)
  - Section 3: Data loaders — read `synthesis_output/prioritization/sector_priority_ranking.csv`, `data/vietnam_loanbook.csv` for sector exposure, framework comparison and Decision 263 content from markdown files
  - Section 4: Chart embedder — base64-encode `synthesis_output/prioritization/sector_priority_chart.png` and any existing PACTA/TRISK charts needed for the methodology appendix
  - Section 5: Section renderers — one function per report section, each returning an HTML string
  - Section 6: CSS — inline stylesheet matching the template spec
  - Section 7: Assembly — concatenate all sections into a complete HTML document
  - Section 8: Write — save to `reports/BIDV_Framework_Recommendation_Report.html`

- [ ] TASK-03-02: Implement the executive summary section renderer:
  - 3-4 KPI cards: number of Decision 263 sectors covered (3), total portfolio exposure in Decision 263 sectors (from loanbook), highest-priority sector (from prioritization ranking), recommended primary framework (PACTA+TRISK)
  - 3-paragraph narrative summarizing: (1) what the report found, (2) what BIDV should do, (3) what's next

- [ ] TASK-03-03: Implement the framework comparison section renderer:
  - Extract the evaluation matrix table from `docs/bidv_framework_comparison.md`
  - Extract the recommendation narrative
  - Extract the complementarity analysis
  - Render as styled HTML tables and paragraphs

- [ ] TASK-03-04: Implement the sector prioritization section renderer:
  - Read `synthesis_output/prioritization/sector_priority_ranking.csv` and render as a styled table
  - Embed `synthesis_output/prioritization/sector_priority_chart.png` as a base64 image
  - Include the interpretation narrative from `synthesis_output/prioritization/interpretation_notes.md`
  - Add the synthetic data disclaimer box

- [ ] TASK-03-05: Implement the Decision 263 mapping section renderer:
  - Extract the sector mapping table and compliance capability mapping from `docs/bidv_decision263_mapping.md`
  - Render as styled HTML

- [ ] TASK-03-06: Implement the implementation roadmap section renderer:
  - Extract the 5 phases and resource table from `docs/bidv_implementation_roadmap.md`
  - Render as a phased timeline with deliverables highlighted

- [ ] TASK-03-07: Implement the methodology appendix section renderer:
  - Condense PACTA methodology from `docs/PACTA_Beginner_Guide.md` (key concepts only: matching, alignment, SDA, market share)
  - Condense TRISK methodology from `docs/TRISK_Demo_Assumptions.md` (key concepts only: DCF stress, NPV, PD change, sensitivity)
  - Include the existing disclaimer language from `dashboard/pages/2_TRISK_Risk.py`
  - Add source citations

- [ ] TASK-03-08: Implement the CSS stylesheet:
  - Allotrope blue headers, clean table styling, KPI card layout, responsive width, print-friendly
  - Synthetic data disclaimer box: red border, light red background
  - Confidentiality notice in footer

**Files / Surfaces**
- `scripts/generate_bidv_report.R` - New: the report generator script.
- `docs/bidv_framework_comparison.md` - Read: framework comparison content.
- `docs/bidv_decision263_mapping.md` - Read: Decision 263 mapping content.
- `docs/bidv_implementation_roadmap.md` - Read: roadmap content.
- `docs/bidv_sector_prioritization_methodology.md` - Read: methodology content.
- `synthesis_output/prioritization/sector_priority_ranking.csv` - Read: ranking data.
- `synthesis_output/prioritization/sector_priority_chart.png` - Read: chart for embedding.
- `synthesis_output/prioritization/interpretation_notes.md` - Read: narrative.
- `data/vietnam_loanbook.csv` - Read: exposure data for BIDV context section.
- `docs/PACTA_Beginner_Guide.md` - Read: methodology appendix source.
- `docs/TRISK_Demo_Assumptions.md` - Read: methodology appendix source.
- `scripts/generate_report.R` - Read: reference for existing HTML generation pattern.
- `dashboard/pages/2_TRISK_Risk.py` - Read: disclaimer language.

**Dependencies**
- PHASE-02 template spec (defines what to build).
- Upstream plans completed: `docs/bidv_framework_comparison.md`, `docs/bidv_decision263_mapping.md`, `synthesis_output/prioritization/` must exist.

**Exit Criteria**
- [ ] `scripts/generate_bidv_report.R` exists and runs without errors.
- [ ] Script produces a single self-contained HTML file under 2 MB.
- [ ] All 10 report sections are present in the rendered HTML.
- [ ] Embedded charts display correctly.
- [ ] Synthetic data disclaimers are present in data-driven sections.

**Phase Risks**
- **RISK-03-01:** Markdown→HTML conversion may not handle complex tables or nested lists. Mitigation: keep the markdown content in upstream documents simple — use flat tables, avoid nested lists deeper than 2 levels. The R script can fall back to hardcoded HTML for sections that don't render cleanly from markdown.
- **RISK-03-02:** Upstream documents may not be available when this phase starts. Mitigation: the script should gracefully handle missing files by inserting "[Section pending — awaiting upstream content]" placeholders, allowing incremental rendering as content becomes available.

### PHASE-04 - Render and Package
**Goal**
Run the report generator, verify the rendered HTML, and package the final deliverable.

**Tasks**
- [ ] TASK-04-01: Run `Rscript scripts/generate_bidv_report.R` and verify it produces `reports/BIDV_Framework_Recommendation_Report.html`.
- [ ] TASK-04-02: Open the rendered HTML in a browser and verify:
  - Cover page renders with correct title, date, and branding
  - Executive summary KPI cards display correctly
  - Framework comparison matrix table is readable (all 7×10 cells visible)
  - Sector prioritization chart displays and is readable
  - Decision 263 mapping tables render correctly
  - Implementation roadmap 5 phases are all present with timelines
  - Methodology appendix is present
  - Synthetic data disclaimers are visible in all data sections
  - Footer confidentiality notice is present
- [ ] TASK-04-03: Check file size — must be under 2 MB for email delivery.
- [ ] TASK-04-04: Test browser print-to-PDF to verify the report prints cleanly (reasonable page breaks, no clipped tables).
- [ ] TASK-04-05: Write `reports/BIDV_Framework_Recommendation_Report_README.md` — a one-page companion document explaining: what the report is, who produced it, what data it uses (synthetic MCB), how to re-run it with real BIDV data, and contact information.

**Files / Surfaces**
- `reports/BIDV_Framework_Recommendation_Report.html` - New: the final deliverable.
- `reports/BIDV_Framework_Recommendation_Report_README.md` - New: companion README.

**Dependencies**
- PHASE-03 script must be complete.
- All upstream content files must exist.

**Exit Criteria**
- [ ] Report HTML file exists and renders correctly in Chrome/Edge.
- [ ] File size is under 2 MB.
- [ ] All 10 sections are populated (no "[pending]" placeholders).
- [ ] Print-to-PDF produces a readable document.
- [ ] README companion exists.

**Phase Risks**
- **RISK-04-01:** If upstream content is incomplete, the report will have placeholder sections. Mitigation: this phase should only begin after confirming all upstream content exists. Use a pre-flight check at the top of the R script that validates file existence before rendering.

## Verification Strategy
- **TEST-001:** Run `Rscript scripts/generate_bidv_report.R` and confirm exit code 0.
- **TEST-002:** Verify file size: `ls -la reports/BIDV_Framework_Recommendation_Report.html` shows < 2 MB.
- **MANUAL-001:** Open report in browser, visually inspect all 10 sections, verify charts display, tables are readable, and disclaimers are present.
- **MANUAL-002:** Print-to-PDF from browser, verify page breaks and table rendering.
- **MANUAL-003:** Read the executive summary and verify it accurately summarizes the report's findings and recommendation.

## Risks and Alternatives
- **RISK-001:** The report may be too long for executive attention. Mitigation: the executive summary (Section 2) should stand alone as a 1-page briefing. Include a "For the Executive" note at the top recommending which sections to read (2, 5, 6, 8) vs. reference sections (3, 4, 7, 9, 10).
- **RISK-002:** The implementation roadmap may feel generic without BIDV-specific organizational details. Mitigation: frame the roadmap as "recommended structure" that BIDV should customize during a joint planning session with GTB. Include blank fields for BIDV to fill in (team names, budget, internal approval gates).
- **ALT-001:** Alternative approach — use R Markdown / Quarto instead of raw HTML generation. Not chosen because: (a) the repo's existing pattern is raw HTML via R scripts, maintaining consistency; (b) Quarto would require additional installation; (c) raw HTML gives full control over the advisory formatting and branding.
- **ALT-002:** Alternative approach — deliver as a PowerPoint presentation instead of HTML report. Not chosen because: (a) HTML is consistent with the repo's existing deliverable format; (b) HTML supports interactive elements (expandable sections, linked tables) that PPT does not; (c) HTML is more suitable for detailed advisory content. However, a companion PPT slide deck could be created as a future phase.

## Grill Me
1. **Q-001:** Should the report include PACTA/TRISK visualizations from the existing MCB pipeline outputs (e.g., power technology mix chart, coal trajectory chart, NPV change by company chart), or should it only include the sector prioritization chart plus the framework comparison matrix?
   - **Recommended default:** Include 3-4 key pipeline charts as "illustrative outputs" in the methodology appendix to demonstrate what BIDV will see when they run the framework on their own data. Use: `synthesis_output/vietnam/05_vn_power_techmix.png`, `dashboard/data/trisk/power/01_npv_change_by_company.png`, and `synthesis_output/prioritization/sector_priority_chart.png`.
   - **Why this matters:** More charts make the report more visually compelling and demonstrate the framework's analytical depth. Fewer charts keep the report focused on the advisory recommendation.
   - **If answered differently:** Add or remove chart embedding tasks in PHASE-03. No structural changes needed.

2. **Q-002:** Should the report include a cost estimate for BIDV's implementation (GTB advisory fees, technology costs, internal staff allocation)?
   - **Recommended default:** No. The report should describe resource requirements in qualitative terms (FTE counts, duration) but not include specific cost figures. Pricing is a commercial discussion, not an advisory document matter.
   - **Why this matters:** Including costs makes the report a de facto proposal. Excluding costs keeps it as technical advisory.
   - **If answered differently:** Add a "Cost Estimate" section to PHASE-01 roadmap tasks and a corresponding report section in PHASE-02.

## Suggested Next Step
Begin PHASE-01 to write the implementation roadmap content. This can start immediately and in parallel with the companion plans for framework comparison and sector prioritization.

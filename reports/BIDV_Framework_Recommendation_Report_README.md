# BIDV Framework Recommendation Report

## What This Report Is

A professional, self-contained HTML report evaluating leading portfolio alignment and climate risk frameworks against BIDV's specific context, with a clear recommendation for a **PACTA + TRISK** analytical stack supported by PCAF for emissions accounting and IFRS S2 for disclosure.

## Who Produced It

Prepared by **GTB Advisory** (with Allotrope VC technical support) for BIDV Senior Risk Management and ESG Leadership.

## What Data It Uses

All analytical results in this report are based on a **synthetic MCB portfolio** (43 loans, ~19.3 billion VND Decision 263 exposure across thermal power, cement, and steel sectors). This is an illustrative demonstration — BIDV-specific results will be produced upon data onboarding.

## Report Structure (10 Sections)

1. **Cover Page** — Title, date, confidentiality notice
2. **Executive Summary** — Key findings, KPI cards, recommended actions
3. **BIDV Context** — Decision 263 obligations, illustrative sector exposure
4. **Framework Landscape** — 7×10 scored evaluation matrix of 7 frameworks
5. **Framework Recommendation** — Primary/secondary/tertiary stack with rationale
6. **Sector Prioritization** — Ranking of power, cement, steel by composite priority score
7. **Decision 263 Compliance Mapping** — How the recommended framework maps to regulatory requirements
8. **Implementation Roadmap** — 5-phase, 24-week adoption pathway
9. **Risk Register** — Key implementation risks and mitigations
10. **Methodology Appendix** — PACTA, TRISK, and scoring methodology summaries with illustrative charts

## How to Re-Run with Real BIDV Data

1. **Prepare loanbook data** using the BYOL intake template (`intake/templates/loanbook_template.csv`)
2. **Place the normalized loanbook** at `data/vietnam_loanbook.csv` (replacing the synthetic MCB data)
3. **Run the sector prioritization pipeline:**
   ```
   Rscript scripts/sector_prioritization.R
   ```
4. **Run the report generator:**
   ```
   Rscript scripts/generate_bidv_report.R
   ```
5. **Open the output:** `reports/BIDV_Framework_Recommendation_Report.html`

### Prerequisites

- R 4.4+ with packages: `dplyr`, `readr`, `base64enc`
- Upstream advisory documents must exist:
  - `docs/bidv_framework_comparison.md`
  - `docs/bidv_decision263_mapping.md`
  - `docs/bidv_implementation_roadmap.md`
  - `docs/bidv_sector_prioritization_methodology.md`
- Prioritization outputs must exist:
  - `synthesis_output/prioritization/sector_priority_ranking.csv`
  - `synthesis_output/prioritization/sector_priority_chart.png`
  - `synthesis_output/prioritization/interpretation_notes.md`

## File Size

~133 KB (well under 2 MB email delivery target).

## Contact

For questions about this report or to schedule a joint planning session for BIDV-specific implementation, contact GTB Advisory.

---

*Generated: 2026-05-22 | Script: `scripts/generate_bidv_report.R` | CONFIDENTIAL*

# Loanbook Data Specification

*For prospective bank partners considering a real-data PACTA + TRISK phase.*

> **This is a specification, not a data request.** No real loanbook data is
> collected during the pilot. This sheet describes exactly what a future
> real-data phase would need, so your team can assess feasibility and
> anonymization requirements before committing.

## What this feeds

Your loanbook maps 1:1 onto the same pipeline that produces the demo you've
seen: sector classification → PACTA portfolio alignment (vs. PDP8 / NDC 2022
/ IEA NZE) → TRISK transition-risk stress test → engagement and disclosure
outputs (Decision 263 / TCFD-aligned). The column list below is the minimum
the pipeline's intake validator (`scripts/intake_validate_and_map.R`)
requires; everything maps directly to the fields used in the demo dashboard.

## Required columns

| Column | Type | Description | Feeds |
|---|---|---|---|
| `counterparty_name` | text | Borrower/company name | Report labeling, disclosure pack |
| `exposure_vnd` | numeric, ≥ 0 | Outstanding loan exposure (VND) | Portfolio weighting, NPV stress magnitude |
| `sector_code` | text | Industry classification code | Sector mapping (see below) |
| `sector_code_system` | `VSIC` or `ISIC` | Which classification system `sector_code` uses | Sector mapping |
| `credit_limit_vnd` | numeric, ≥ 0 | Approved credit limit (VND) | Exposure-at-default context |

## Optional columns (recommended)

| Column | Type | Description | Feeds |
|---|---|---|---|
| `lei` | text | Legal Entity Identifier | Higher-confidence ABCD matching |
| `tax_id` | text | Tax/business registration ID | Borrower ID assignment, deduplication |
| `parent_name` | text | Ultimate parent company name | Group-level roll-up (e.g., EVN, THACO, VICEM subsidiaries) |
| `parent_id` | text | Parent company identifier | Group-level roll-up |
| `currency` | text | Currency code (defaults to `VND`) | Currency normalization |

## Currently in-scope PACTA sectors

| ISIC code | Sector | PACTA/TRISK coverage |
|---|---|---|
| 3511 | Power generation | Full borrower-level market-share TRISK |
| 2394 | Cement | Sector-level SDA TRISK |
| 2410 | Steel | Sector-level SDA TRISK (match coverage ~4% in the demo — a real loanbook with LEI/tax ID improves this materially) |
| 2910 | Automotive | PACTA alignment only (no TRISK stress in this build) |
| 0510 | Coal mining | Partial (excluded from TRISK stress) |
| 0610 | Oil & gas | Partial (excluded from TRISK stress) |

Any other sector code is marked "not in scope" and excluded from PACTA/TRISK
analysis but still counted in overall portfolio composition.

## Format and delivery

- **File format:** CSV (UTF-8 or Latin-1), one row per loan facility.
- **Template:** see `intake/templates/loanbook_template.csv` and the Vietnamese
  guide `intake/templates/README_vi.md`.
- **Anonymization:** `counterparty_name` may be pseudonymized (e.g.,
  `"Borrower_0042"`) as long as it stays internally consistent — the pipeline
  does not require real legal names to run PACTA/TRISK, only for the final
  disclosure pack rendering. Tax ID / LEI can be omitted or hashed if their
  presence alone is sensitive; omitting them only reduces match-rate quality,
  it does not block the analysis.
- **Validation:** every submitted file is run through the same automated
  validator used in the demo (`scripts/intake_validate_and_map.R`), producing
  a validation report (`validation_summary.txt`) before any analysis runs —
  your team sees exactly what passed, what failed, and why, before results
  are generated.

## What you get back

1. A normalized, matched loanbook (sector-mapped, deduplicated to parent
   groups).
2. PACTA portfolio alignment results against PDP8 / NDC 2022 / IEA NZE.
3. TRISK transition-risk stress results (NPV and PD deltas) for covered
   sectors.
4. Engagement and disclosure outputs (priority scoring, engagement letters,
   Decision 263-aligned disclosure pack).

---
*All figures produced by this pipeline are illustrative transition-risk
indicators for portfolio screening, not production credit-risk or regulatory
capital outputs.*

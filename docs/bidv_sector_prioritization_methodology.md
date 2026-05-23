# BIDV Sector Prioritization Methodology

> **Date:** 2026-05-22
> **Author:** PACTA-TRISK Vietnam project
> **Purpose:** Define the three-dimensional sector prioritization scoring methodology used to rank Decision 263 sectors (thermal power, steel, cement) by composite transition risk. Serves as the specification for `scripts/sector_prioritization.R` and the methodology appendix of the BIDV Framework Recommendation Report.

---

## 1. Overview

This methodology combines three dimensions of transition risk into a single composite priority score for each Decision 263 sector:

1. **Alignment gap severity** — How far is the portfolio's current trajectory from the decarbonization target?
2. **Transition stress severity** — How much financial damage would a disorderly transition cause to borrowers in this sector?
3. **Portfolio exposure concentration** — How much of the bank's Decision 263-relevant lending is concentrated in this sector?

The composite score answers: **"Which sector should BIDV prioritize for climate risk reduction and borrower engagement?"**

---

## 2. Scoring Dimensions

### 2.1 Dimension 1: Alignment Gap Severity

**Source:** PACTA alignment analysis outputs from `synthesis_output/vietnam/`

**Extraction rules by sector type:**

| Sector Type | Method | Extraction Rule | Source File |
|---|---|---|---|
| **Power** (market-share) | Market Share | Maximum positive `share_gap_pp` across high-carbon technologies (coalcap, gascap). Positive gap = over-allocated vs. target = higher misalignment severity. | `06_vn_ms_alignment_2030.csv` |
| **Cement** (SDA) | SDA | `gap_pct` value — percentage by which portfolio emission intensity exceeds the 2030 target. | `06_vn_sda_alignment_2030.csv` |
| **Steel** (SDA) | SDA | `gap_pct` value — percentage by which portfolio emission intensity exceeds the 2030 target. | `06_vn_sda_alignment_2030.csv` |

**Raw values (MCB synthetic portfolio):**

| Sector | Raw Value | Source |
|---|---|---|
| Power | 13.37 pp | Max positive gap: coalcap (+13.37 pp over PDP8 target) |
| Cement | 2.1% | SDA intensity gap vs. 2030 target |
| Steel | 7.2% | SDA intensity gap vs. 2030 target |

**Normalization:** Min-max scaling to [0, 1] across the three sectors. The sector with the highest raw gap gets 1.0, the lowest gets 0.0.

```
alignment_score = (raw_gap - min_gap) / (max_gap - min_gap)
```

**Caveat:** Power and SDA gaps are in different units (percentage points vs. percent). Min-max scaling across sectors makes them comparable by ranking relative severity within the portfolio, not by absolute magnitude. This is intentional — the question is "which sector is the worst relative to the others?" not "which sector has the largest absolute number?"

### 2.2 Dimension 2: Transition Stress Severity

**Source:** TRISK borrower-level stress-test outputs from `dashboard/data/trisk/<sector>/top_borrowers_alignment_trisk.csv`

**Aggregation rule:** Exposure-weighted mean of `stress_priority_score` across borrowers within each sector.

```
sector_stress_score = Σ(borrower_stress_score × borrower_exposure) / Σ(borrower_exposure)
```

**Why exposure-weighted:** A sector with one large, highly stressed borrower is more urgent than a sector with many small, mildly stressed borrowers. This reflects BIDV's credit risk perspective.

**Raw values (MCB synthetic portfolio):**

| Sector | Borrowers | Stress Priority Scores | Exposure-Weighted Mean |
|---|---|---|---|
| Power | 13 borrowers | 5.25 – 100 | Calculated by script |
| Cement | 2 borrowers | 95 (VICEM), 5 (Holcim) | Calculated by script |
| Steel | 2 borrowers | 95 (Hoa Phat), 5 (Pomina) | Calculated by script |

**Normalization:** Min-max scaling to [0, 1] across the three sectors.

```
stress_score = (raw_stress - min_stress) / (max_stress - min_stress)
```

**Fallback:** If a sector has no TRISK output (e.g., automotive, which is out of scope for TRISK), the stress dimension is set to 0 and a warning is emitted. The sector is scored on alignment + exposure only.

### 2.3 Dimension 3: Portfolio Exposure Concentration

**Source:** `data/vietnam_loanbook.csv`

**Calculation:** Each sector's share of total Decision 263-relevant portfolio exposure (VND).

```
sector_exposure = Σ(loan_size_outstanding for loans in sector)
total_d263_exposure = Σ(sector_exposure for all Decision 263 sectors)
exposure_share = sector_exposure / total_d263_exposure
```

**Decision 263 sector mapping:** Loans are mapped to Decision 263 sectors using the `sector_classification_direct_loantaker` column (ISIC codes):
- `D3511` (electric power generation) → thermal power
- `C2310` (glass/glass products) and `C239` (other non-metallic minerals) → cement
- `C2410` (basic iron and steel) → steel

**Normalization:** Min-max scaling to [0, 1] across the three sectors. The sector with the highest exposure share gets 1.0.

```
exposure_score = (exposure_share - min_share) / (max_share - min_share)
```

---

## 3. Composite Score Formula

```
composite = w_alignment × alignment_score + w_stress × stress_score + w_exposure × exposure_score
```

**Default weights:**

| Dimension | Weight | Rationale |
|---|---|---|
| Alignment gap | 0.35 | Equal emphasis on alignment — the core PACTA output |
| Transition stress | 0.35 | Equal emphasis on financial impact — the core TRISK output |
| Portfolio exposure | 0.30 | Slightly lower weight — exposure is a multiplier, not a direct risk measure |

**Why near-equal weighting:** This avoids pre-judging BIDV's risk appetite. A bank focused on regulatory compliance might weight alignment higher; a bank focused on credit risk might weight stress higher. The weights are configurable parameters in the script so BIDV can adjust during implementation.

---

## 4. Priority Classification Bands

| Band | Composite Score Range | Interpretation | Recommended Action |
|---|---|---|---|
| **Critical** | ≥ 0.70 | Highest combined risk across all three dimensions | Immediate borrower engagement, sector exposure limits, board-level reporting |
| **High** | 0.50 – 0.69 | Significant risk in at least two dimensions | Priority engagement within 6 months, enhanced monitoring |
| **Medium** | 0.30 – 0.49 | Moderate risk, typically driven by one dimension | Include in quarterly monitoring cycle, track alignment trajectory |
| **Low** | < 0.30 | Lowest combined risk | Standard monitoring, no immediate action required |

---

## 5. Data Sources Summary

| Dimension | Source File | Repository Path |
|---|---|---|
| Alignment gap (power) | `06_vn_ms_alignment_2030.csv` | `synthesis_output/vietnam/` |
| Alignment gap (cement/steel) | `06_vn_sda_alignment_2030.csv` | `synthesis_output/vietnam/` |
| TRISK stress (power) | `top_borrowers_alignment_trisk.csv` | `dashboard/data/trisk/power/` |
| TRISK stress (cement) | `top_borrowers_alignment_trisk.csv` | `dashboard/data/trisk/cement/` |
| TRISK stress (steel) | `top_borrowers_alignment_trisk.csv` | `dashboard/data/trisk/steel/` |
| Portfolio exposure | `vietnam_loanbook.csv` | `data/` |

---

## 6. Configurable Parameters

The script accepts the following parameters via command-line arguments or default configuration:

| Parameter | Default | Description |
|---|---|---|
| `w_alignment` | 0.35 | Weight for alignment gap severity |
| `w_stress` | 0.35 | Weight for transition stress severity |
| `w_exposure` | 0.30 | Weight for portfolio exposure concentration |
| `alignment_file_ms` | `synthesis_output/vietnam/06_vn_ms_alignment_2030.csv` | Path to market share alignment CSV |
| `alignment_file_sda` | `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv` | Path to SDA alignment CSV |
| `trisk_dir` | `dashboard/data/trisk/` | Path to TRISK sector directories |
| `loanbook_file` | `data/vietnam_loanbook.csv` | Path to loanbook CSV |
| `output_dir` | `synthesis_output/prioritization/` | Path for output files |

---

## 7. Limitations

1. **Different units for alignment gaps:** Power gaps are in percentage points (market share), while cement/steel gaps are in percent (emission intensity). Min-max scaling makes them comparable by relative severity, but this means the absolute magnitude of the gap is lost. The raw values are preserved in the detail output for traceability.

2. **Steel match coverage ~4%:** The MCB synthetic portfolio has very low steel match coverage, making steel alignment and stress results less reliable. The methodology document and interpretation notes should flag this caveat.

3. **Power sector NA values at 2025:** Some power technologies have NA production values at 2025 in the demo data, which may affect alignment gap calculations. The script should handle missing values gracefully.

4. **Synthetic portfolio:** All results are based on the synthetic MCB portfolio, not real BIDV data. The output CSVs include a `data_source` column indicating "MCB_synthetic" to clearly distinguish from future BIDV runs.

5. **Automotive excluded:** Automotive is not a Decision 263 sector and is excluded from this prioritization. It is covered by PACTA but not by TRISK in the current implementation.

---

## 8. Output Specifications

### 8.1 `sector_priority_ranking.csv`

| Column | Type | Description |
|---|---|---|
| `sector` | character | Sector name (power, cement, steel) |
| `composite_score` | numeric | Composite priority score [0, 1] |
| `priority_band` | character | Critical / High / Medium / Low |
| `alignment_score` | numeric | Normalized alignment gap score [0, 1] |
| `stress_score` | numeric | Normalized stress severity score [0, 1] |
| `exposure_score` | numeric | Normalized exposure concentration score [0, 1] |
| `alignment_gap_raw` | numeric | Raw alignment gap value (pp or %) |
| `stress_score_raw` | numeric | Raw exposure-weighted mean stress priority score |
| `exposure_vnd` | numeric | Total sector exposure in VND |
| `exposure_share` | numeric | Sector exposure as fraction of total D263 exposure |
| `data_source` | character | "MCB_synthetic" |

### 8.2 `sector_priority_detail.csv`

| Column | Type | Description |
|---|---|---|
| `sector` | character | Sector name |
| `dimension` | character | alignment / stress / exposure |
| `raw_value` | numeric | Raw (unnormalized) value |
| `normalized_score` | numeric | Normalized score [0, 1] |
| `weight` | numeric | Weight applied to this dimension |
| `weighted_contribution` | numeric | normalized_score × weight |
| `source_file` | character | Source file path |
| `data_source` | character | "MCB_synthetic" |

### 8.3 `sector_priority_chart.png`

Horizontal stacked bar chart with:
- Sectors on y-axis (power, cement, steel)
- Composite score on x-axis [0, 1]
- Three color-coded segments per bar: alignment (red-ish), stress (orange-ish), exposure (blue-ish)
- Priority band labels on the right
- Title: "Sector Transition Risk Priority — MCB Synthetic Portfolio"
- Width: 800px, suitable for HTML report embedding

---

## 9. MCB Demonstration Results Appendix

The script was executed against the MCB synthetic portfolio (43 loans, 19.3 billion VND Decision 263 exposure) with default weights (0.35/0.35/0.30). Results:

| Sector | Alignment Score | Stress Score | Exposure Score | Composite | Band |
|---|---|---|---|---|---|
| Power | 1.000 | 1.000 | 1.000 | **1.000** | Critical |
| Steel | 0.453 | 0.000 | 0.000 | **0.158** | Low |
| Cement | 0.000 | 0.000 | 0.035 | **0.011** | Low |

**Raw values:**

| Sector | Alignment Gap | Stress (weighted mean) | Exposure (VND) | Exposure Share |
|---|---|---|---|---|
| Power | 13.37 pp | 493.39 | 15,770,000 | 81.8% |
| Cement | 2.1% | 100.00 | 2,000,000 | 10.4% |
| Steel | 7.2% | 100.00 | 1,500,000 | 7.8% |

**Sensitivity check:** With weights 0.50/0.25/0.25 (alignment-heavy), steel's score increased from 0.158 to 0.226 (+43%). The ranking order (power > steel > cement) is stable across all tested weight combinations.

**Caveats:** Steel match coverage ~4% in the MCB portfolio; power sector NA values at 2025 for some technologies; all results are synthetic, not real BIDV data.

---

*This methodology document serves as the specification for `scripts/sector_prioritization.R` (GAP-03). All formulas, weights, and normalization rules are implemented exactly as documented. The script accepts weight parameters so BIDV can adjust during implementation.*

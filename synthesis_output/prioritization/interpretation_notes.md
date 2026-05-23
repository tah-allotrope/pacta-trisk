# Sector Prioritization — Interpretation Notes (MCB Synthetic Portfolio)

> **Date:** 2026-05-22
> **Data source:** MCB synthetic portfolio (43 loans, ~19.3 billion VND Decision 263 exposure)
> **Weights:** alignment = 0.35, stress = 0.35, exposure = 0.30

---

## Ranking Results

| Rank | Sector | Composite Score | Priority Band | Key Driver |
|---|---|---|---|---|
| 1 | **Power** | 1.000 | Critical | Dominates all three dimensions |
| 2 | **Steel** | 0.158 | Low | Moderate alignment gap (7.2%) |
| 3 | **Cement** | 0.011 | Low | Lowest alignment gap (2.1%) |

## Interpretation

**Power is the unequivocal priority sector** for BIDV's climate risk management, scoring maximum (1.0) on the composite scale. This is driven by three converging factors:

1. **Alignment gap:** Power's coal capacity is 13.4 percentage points above the PDP8 target — the largest misalignment across all Decision 263 sectors. The portfolio is over-allocated to coal (37% vs. 24% target) and under-allocated to renewables (21% vs. 35% target).

2. **Transition stress:** The power sector has 13 borrowers with TRISK stress-test results, including three coal-heavy entities (Nghi Son Power LLC, Vinacomin Power JSC, International Power Mong Duong) with stress priority scores of 95–100. The exposure-weighted mean stress score is 493, far exceeding cement and steel (both 100, the floor value).

3. **Portfolio exposure:** Power accounts for 81.8% of total Decision 263-relevant exposure (15.8 billion VND of 19.3 billion VND). This concentration amplifies both the alignment and stress dimensions.

**Steel ranks second** (0.158) despite having only two borrowers because its SDA alignment gap (7.2% above 2030 target) is significantly higher than cement's (2.1%). However, steel's stress and exposure scores are both at or near zero, limiting its composite score.

**Cement ranks last** (0.011) with the smallest alignment gap (2.1%) and low exposure share (10.4%). The sector's two borrowers (VICEM, Holcim Group) show divergent stress scores (95 and 5), but the exposure-weighted mean is at the floor.

## Sensitivity Analysis

When weights shift toward alignment (0.50) and away from stress/exposure (0.25 each), steel's score increases from 0.158 to 0.226 — a 43% increase — reflecting its moderate alignment gap. The ranking order (power > steel > cement) is stable across all tested weight combinations, confirming that power's dominance is robust to reasonable weight variations.

## Caveats

- **Steel match coverage ~4%:** The MCB synthetic portfolio has very low steel match coverage, making steel alignment and stress results less reliable. Steel's true priority may be higher if additional borrowers were matched.
- **Synthetic portfolio:** All results are based on the synthetic MCB portfolio, not real BIDV data. BIDV-specific results will differ based on actual sector exposure and borrower composition.
- **Different alignment units:** Power gaps are in percentage points (market share) while cement/steel gaps are in percent (emission intensity). Min-max scaling makes them comparable by relative severity within the portfolio.

---

*These notes are suitable for copy-pasting into the BIDV Framework Recommendation Report (GAP-04) as the sector prioritization interpretation section.*

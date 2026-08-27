# Scoring Anchors — Absolute Severity Tables

This document is the single source of truth for the anchor tables that
`R/severity_scoring.R` implements (Wave 2 PHASE-03,
`plans/2026-07-27-contracts-units-and-guardrails-plan.md`). It exists so a
reviewer with a calculator — not a code reader — can recompute any severity
score and argue with the thresholds independently of the implementation.

## Why absolute anchors instead of min-max normalization

Before this change, every priority score in this repository was **min-max
normalized**: the worst-scoring entity in a set was rescaled to exactly
`1.0` and the best to exactly `0.0`, regardless of how good or bad either
actually was. Two consequences followed:

1. **The top-ranked entity was always exactly `1.0`.** This held for any
   input — a tautology, not a finding. `tests/testthat/test_golden_numbers.R`
   pinned this before PHASE-04's refreeze.
2. **Two structurally different banks (or a bank with only one sector in
   scope) could not be compared.** A score of `0.83` meant "worst of these
   three sectors this refresh" — nothing about the underlying quantity.

An **absolute anchor table** fixes this: each raw metric (an alignment gap
in percentage points, a fraction of NPV lost, a share of exposure) is mapped
to a severity in `[0, 1]` by **clamped piecewise-linear interpolation** over
five fixed breakpoints, chosen once and documented here — not recomputed
from whatever happens to be in today's dataset.

## The interpolation rule

```
severity(x) = approx(x = anchors_x, y = anchors_y, xout = clamp(x, min(anchors_x), max(anchors_x)))$y
```

- `x` — the raw metric being scored.
- `anchors_x` — the five breakpoint values of that metric, ascending.
- `anchors_y` — always `0.00, 0.25, 0.50, 0.75, 1.00`.
- `clamp(x, lo, hi) = min(max(x, lo), hi)` — a value beyond the last
  breakpoint **saturates** at `1.00` (or below the first, at `0.00`); it is
  never extrapolated past the table. An unboundedly bad input reads as "as
  bad as this scale can express," not as some arbitrarily large number.
- Interpolation is linear (base R's `stats::approx()`, default
  `method = "linear"`) between the two breakpoints straddling `x`.

## The four tables

Two tables are required for alignment gaps because percentage points of
technology market share and percent-of-target emission intensity share a
numeric scale but not a meaning — the same numeric gap does not represent
the same severity of misalignment in the two families. Conflating them (as
the pre-PHASE-03 code did, by min-maxing them together across sectors) is
the specific defect this document exists to prevent from recurring.

### Table A1 — market-share alignment gap

Sectors: **power**, **automotive**. Unit: percentage points of technology
market share, absolute value (`abs()` applied before lookup).

| gap (pp) | 0 | 5 | 10 | 20 | 40 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

### Table A2 — SDA emission-intensity gap

Sectors: **cement**, **steel**. Unit: percent of the sector's 2030 target
intensity, absolute value — the `gap_pct` column.

| gap (%) | 0 | 2 | 5 | 10 | 20 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

### Table B — TRISK value-loss severity

Input: `loss = max(0, -npv_change)`. A positive `npv_change` (a value *gain*
under the shock) always scores `0.00` — a gain is not stress.

| loss (fraction of baseline NPV) | 0.00 | 0.05 | 0.15 | 0.30 | 0.60 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

### Table C — exposure-concentration severity

Unit: fraction of the engagement's total Decision-263-relevant exposure, in
`[0, 1]` — **not a percentage**. `severity_exposure(0.82)` is correct;
`severity_exposure(82)` silently saturates at `1.00` and hides the bug.

| share | 0.00 | 0.05 | 0.15 | 0.30 | 0.50 |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

### Table SLL-1 — SLL readiness exposure severity

Wave 3 PHASE-06. Sectors: all (`R/sll_readiness.R`). Unit: a single
borrower's own exposure, whole VND — not a share of portfolio exposure
(Table C, above, is portfolio share; this is absolute ticket size, because a
bank's appetite to structure a sustainability-linked loan scales with
absolute deal size, not portfolio concentration).

| exposure (VND) | 2.5×10¹¹ | 8×10¹¹ | 1.5×10¹² | 3×10¹² | 5.77×10¹² |
|---|---|---|---|---|---|
| severity | 0.00 | 0.25 | 0.50 | 0.75 | 1.00 |

Calibrated against the MCB synthetic book's own borrower-exposure range
(250 billion to 5.77 trillion VND), not a generic round-number scale —
retune against a real loanbook's exposure distribution once one exists.

**SLL readiness bands** (`sll_readiness_band()` in `R/sll_readiness.R`) are
similarly calibrated against the MCB book rather than using generic
breakpoints: `Ready >= 0.75`, `Near-ready >= 0.70`, `Developing >= 0.50`,
else `Not ready`. With every borrower in `engagement_priority.csv`
already ABCD-matched by construction, the readiness score's
`data_availability` dimension is a near-constant 1.0 on this synthetic
book, so materiality and exposure severity are the only two dimensions
that actually discriminate — narrower bands than Table A-D's are needed to
land the qualified pool (Ready + Near-ready) at the target ~5-8 of 23
borrowers rather than qualifying nearly everyone.

## Band thresholds

`classify_band()` in `R/prioritization_core.R` keeps its pre-existing cut
points; they now describe an absolute quantity instead of a rank-relative one:

```
score >= 0.70 -> "Critical"
score >= 0.50 -> "High"
score >= 0.30 -> "Medium"
otherwise     -> "Low"
```

## Worked example (MCB, sector level)

Using MCB's inputs from `synthesis_output/prioritization/sector_priority_ranking.csv`:

- **Power**, `alignment_gap_raw = 14.39` pp. Table A1: `14.39` sits between
  breakpoints `10` (severity `0.50`) and `20` (severity `0.75`):
  `0.50 + (14.39 - 10) / (20 - 10) * 0.25 = 0.50 + 0.439 * 0.25 = 0.60975`.
- **Power**, `exposure_share = 0.8184`. Table C: `0.8184` is at or beyond
  the last breakpoint `0.50`, so it **saturates** to `1.00`.
- **Cement**, `alignment_gap_raw = 2.1` (SDA `gap_pct`). Table A2: between
  `2` (`0.25`) and `5` (`0.50`):
  `0.25 + (2.1 - 2) / (5 - 2) * 0.25 = 0.25 + 0.0333 * 0.25 = 0.2583`.
- **Steel**, `alignment_gap_raw = 7.2`. Table A2: between `5` (`0.50`) and
  `10` (`0.75`): `0.50 + (7.2 - 5) / (10 - 5) * 0.25 = 0.50 + 0.44 * 0.25 = 0.61`.
- **Cement**, `exposure_share = 0.1038`. Table C: between `0.05` (`0.25`)
  and `0.15` (`0.50`):
  `0.25 + (0.1038 - 0.05) / (0.15 - 0.05) * 0.25 = 0.25 + 0.538 * 0.25 = 0.3845`.

Under the old min-max scheme, cement's alignment score with three sectors
in scope was exactly `0` and steel's was `0.4150` — purely artifacts of
cement being last of three, not a statement about either sector's actual
gap. Under the anchors above they are `0.2583` and `0.61`, and neither
number depends on how many sectors happen to be in scope this refresh.

## Composite formulas

**Borrower composite** (`scripts/engagement_scoring.R`), for borrower `b`:

```
severity_alignment_b = severity(alignment_gap_b, table A1 if sector in {power, automotive} else table A2)
severity_trisk_b     = severity(max(0, -npv_change_b), table B)          # NA when the borrower has no TRISK coverage
composite_score_b    = (w_align * severity_alignment_b + w_trisk * severity_trisk_b) / (w_align + w_trisk)
                       when severity_trisk_b is not NA
composite_score_b    = severity_alignment_b
                       when severity_trisk_b is NA  (composite_partial = TRUE)
```

`w_align` and `w_trisk` default to `0.5` each (CLI flags `--w_align`,
`--w_trisk`).

> **Wave 3 PHASE-07 S1 (rounding):** the raw composite is rounded to
> **10 decimal places** (`round(composite_score, 10)`) before it is written
> and before `composite_rank_pct = rank(composite_score, ties.method="average")/n()`
> is computed. The published number and the published rank therefore agree,
> and a 1-ULP floating-point residue (≈1e-14) can no longer split six
> otherwise-identical renewables borrowers across thirteen percentile points.

**Sector composite** (`R/prioritization_core.R`), for sector `s`:

```
alignment_score_s = severity(alignment_gap_raw_s, table A1 if s == "power" else table A2)
stress_score_s    = severity(weighted_mean_loss_s, table B)
exposure_score_s  = severity(exposure_share_s, table C)
composite_score_s = w_alignment * alignment_score_s + w_stress * stress_score_s + w_exposure * exposure_score_s
```

`w_alignment = 0.35`, `w_stress = 0.35`, `w_exposure = 0.30` (unchanged
defaults). `weighted_mean_loss_s` is the exposure-weighted mean of
`max(0, -npv_change)` across the sector's TRISK-covered borrowers.

## trisk_stress_rank_pct (Wave 3 PHASE-07, ASM-004)

`engagement_priority.csv`'s former `trisk_priority_score` column is renamed
`trisk_stress_rank_pct` in the 0.5.0 refreeze. It is a **within-engagement
percentile rank** (`rank(stress_priority_score, ties.method="average")/n()`),
is **not comparable across banks or across refreshes**, and **must never be
fed into a composite score** — the composite uses absolute severities
(`severity_alignment`, `severity_trisk`) only. The column is retained
because downstream consumers (letters, disclosure) still render it as a
dashboard sort key, but its name now advertises its limits.

## Reviewing or changing these numbers

These breakpoints are a documented judgment call (`plans/2026-07-27-contracts-units-and-guardrails-plan.md`
ASM-003), chosen so MCB's power sector lands in "Critical" and its cement
sector lands in "Low" — preserving the qualitative ordering a reader of the
prior (broken) scores would have expected — while producing non-degenerate
interior values for everything in between. There is no external standard
being copied. If a bank's risk committee wants different breakpoints,
change the five `x` values in the relevant table in `R/severity_scoring.R`
and in this document together; `R/severity_scoring.R`'s functions take
anchors as parameters, so no scoring logic elsewhere needs to change.

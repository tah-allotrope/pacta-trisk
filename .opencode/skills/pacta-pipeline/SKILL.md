---
name: pacta-pipeline
description: Run PACTA for Banks alignment pipelines in R with r2dii packages, including matching, coverage, market share, SDA, visualization, and reporting workflows.
license: MIT
compatibility: opencode
metadata:
  domain: climate-finance
  runtime: R
---

## What I do

- Execute the PACTA matching pipeline (fuzzy match, review, prioritize)
- Compute alignment targets with market share and SDA methods
- Generate standardized PACTA charts using r2dii.plot
- Produce alignment gap summaries and HTML-ready outputs

## When to use me

Use this when you are running or modifying a PACTA pipeline, interpreting alignment outputs, or debugging unexpected results from r2dii packages.
Ask clarifying questions only if the input data source or desired scenario set is unclear.

## Pipeline workflow (recommended)

1) Load packages and data (demo or real)
   - `pacta.loanbook` loads `r2dii.data`, `r2dii.match`, `r2dii.analysis`
2) Pre-join sector classifications to the loanbook
   - Enables sector mismatch validation after matching
3) Match names and review
   - `match_name()` with `min_score = 0.9` for production
   - Export and manually validate any matches with score < 1.0
4) Prioritize matches
   - `prioritize()` to pick one match per loan
5) Coverage analysis
   - Include both matched/unmatched and an explicit "Not in Scope" category
6) Market share alignment (power, automotive, etc.)
   - `target_market_share()` for portfolio and optionally `by_company = TRUE`
7) SDA alignment (cement, steel, aviation)
   - `target_sda()` for emissions intensity trajectories
8) Visualization and reporting
   - Use `r2dii.plot` for standardized charts
   - Add custom ggplot2 charts for multi-sector alignment overview

## Critical gotchas (from project experience)

- Demo metric naming asymmetry: SDA metrics use `target_demo`, not `target_sds`.
  Always inspect `unique(sda_targets$emission_factor_metric)` before filtering.
- Power sector demo data has NA values at 2025 for several technologies.
  Filter NA values before alignment calculations to avoid silent failures.
- Steel match coverage can be extremely low; do not over-interpret results.
- `r2dii.plot` expects tight filtering by scenario_source, sector, region, and metric.
  Filter before calling `qplot_techmix()` or `qplot_trajectory()`.
- Windows user library is required for installs; use `install.packages(..., lib = Sys.getenv("R_LIBS_USER"))`.
- `by_company = TRUE` explodes row count; filter sectors first to avoid huge outputs.

## Matching strategy (recommended defaults)

| Setting | Precision | Coverage | Manual Review | Best For |
|---|---|---|---|---|
| `min_score = 1.0` | Highest | Lowest | None | Demo data |
| `min_score = 0.9` | High | Moderate | Some | Production with good names |
| `min_score = 0.8` | Moderate | Highest | Heavy | Messy real-world data |

Recommended production workflow:

```r
matched <- match_name(loanbook, abcd, min_score = 0.9)
readr::write_csv(matched, "matched_for_review.csv")
# Manual review: set score = 1 for confirmed matches
reviewed <- readr::read_csv("matched_reviewed.csv")
prioritized <- prioritize(reviewed)
```

## Visualization patterns

Use r2dii.plot on filtered data only:

```r
market_share_targets %>%
  filter(scenario_source == "demo_2020", sector == "power",
         region == "global",
         metric %in% c("projected", "corporate_economy", "target_sds")) %>%
  qplot_techmix()
```

For alignment gap summaries, use custom ggplot2 to compare projected vs target at a fixed year.

## Supporting references

- Use `docs/PACTA_Beginner_Guide.md` for full methodology and data dictionaries.
- Use `activeContext.md` for the latest project state and outputs.

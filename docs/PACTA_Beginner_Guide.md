# Complete PACTA for Banks Demo Guide

## What is PACTA?

PACTA (Paris Agreement Capital Transition Assessment) assesses whether corporate lending portfolios align with climate goals. It covers 7 sectors: **power, automotive, cement, steel, coal mining, oil & gas, and aviation**.

The analysis pipeline has 3 packages plus a convenience wrapper:

```
r2dii.data ──> r2dii.match ──> r2dii.analysis ──> (r2dii.plot)
     │               │                │
  demo data    fuzzy-match       calculate         visualize
  & reference  loans to          climate scenario
  datasets     companies         alignment targets
```

There is also `pacta.loanbook`, which bundles all of the above into a single install and adds cookbook helpers.

---

## Phase 0: Prerequisites & Install

### Software needed

- **R** (version 4.1.0+): https://cran.r-project.org/
- **RStudio** (optional but recommended): https://posit.co/downloads/

### Install the packages (run once in R)

```r
# Option A: Install the all-in-one wrapper (pulls in all r2dii.* packages)
install.packages("pacta.loanbook")

# Option B: Install individually
install.packages(c("r2dii.data", "r2dii.match", "r2dii.analysis"))

# Optional: for visualization
install.packages("r2dii.plot")

# For data import/export helpers
install.packages(c("readxl", "readr", "writexl", "dplyr", "ggplot2"))
```

---

## Phase 1: Setup & Load Data

```r
library(pacta.loanbook)   # loads r2dii.data, r2dii.match, r2dii.analysis
library(dplyr)
library(readxl)
library(readr)
```

### Demo datasets (included with the packages)

| Dataset | Description | Package |
|---|---|---|
| `loanbook_demo` | 283 fake bank loans with borrower names, sectors, amounts | r2dii.data |
| `abcd_demo` | ~4,970 rows of company production + emissions data | r2dii.data |
| `scenario_demo_2020` | Technology-level scenario pathways (TMSR/SMSP) | r2dii.data |
| `co2_intensity_scenario_demo` | CO2 intensity pathways for SDA sectors | r2dii.data |
| `region_isos_demo` / `region_isos` | Country-to-region mappings | r2dii.data |

### For real analysis

You would import your own data from files:

```r
# Loanbook: CSV/XLSX from your bank's system
loanbook <- readxl::read_excel("path/to/loanbook.xlsx")

# ABCD: XLSX from Asset Impact or other provider
abcd <- readxl::read_excel("path/to/abcd.xlsx")

# Scenarios: CSV files from PACTA website
scenario <- readr::read_csv("path/to/scenario.csv")
co2 <- readr::read_csv("path/to/co2_intensity_scenario.csv")
```

### Required loanbook columns (minimum)

- `id_loan`, `id_direct_loantaker`, `name_direct_loantaker`
- `id_ultimate_parent`, `name_ultimate_parent`
- `loan_size_outstanding`, `loan_size_outstanding_currency`
- `loan_size_credit_limit`, `loan_size_credit_limit_currency`
- `sector_classification_system` (e.g. "NACE", "NAICS", "ISIC")
- `sector_classification_direct_loantaker` (the sector code)
- `lei_direct_loantaker`, `isin_direct_loantaker`

Run `names(loanbook_demo)` to see the exact column names.

---

## Phase 2: Matching (r2dii.match)

This is a 3-step process: fuzzy match, manual validate, prioritize.

### Step 2a: Fuzzy Match

```r
loanbook <- loanbook_demo
abcd <- abcd_demo

matched <- match_name(loanbook, abcd)
# ~326 rows of potential matches with similarity scores (0 to 1)
```

**Key parameters:**

- `by_sector = TRUE` (default): Only matches within the same PACTA sector. Set `FALSE` if your sector codes are unreliable.
- `min_score = 0.8` (default): Minimum string similarity. Raise to 0.9 for stricter matching; lower for more coverage.

```r
# Stricter matching
match_name(loanbook, abcd, min_score = 0.9)

# Cross-sector matching (slower, more false positives)
match_name(loanbook, abcd, by_sector = FALSE)
```

### Step 2b: Manual Validation (critical for real data)

This is the most time-consuming but most important step. You export results, review in a spreadsheet, and set `score = 1` only for correct matches.

```r
# Export for review
readr::write_csv(matched, "matched_for_review.csv")

# --- MANUAL STEP ---
# Open matched_for_review.csv in Excel/Google Sheets
# Compare "name" (loanbook) vs "name_abcd" (ABCD)
# For CORRECT matches: set score = 1
# For INCORRECT matches: leave score as-is or set to 0
# Save as valid_matches.csv

# Re-import
valid_matches <- readr::read_csv("valid_matches.csv")
```

For the demo, the data is pre-designed to match correctly, so you can skip this and use `matched` directly.

### Step 2c: Prioritize

```r
# For demo (skipping manual validation):
prioritized_matches <- prioritize(matched)

# For real data (after validation):
# prioritized_matches <- prioritize(valid_matches)
# ~177 rows: one best match per loan
```

Priority order: `direct_loantaker` > `intermediate_parent_*` > `ultimate_parent`

### Step 2d: Check Match Coverage (recommended)

```r
library(ggplot2)

merge_by <- c(
  sector_classification_system = "code_system",
  sector_classification_direct_loantaker = "code"
)

loanbook_with_sectors <- loanbook %>%
  left_join(sector_classifications, by = merge_by)

coverage <- left_join(loanbook_with_sectors, prioritized_matches) %>%
  mutate(
    matched = ifelse(!is.na(score) & score == 1, "Matched", "Not Matched"),
    sector = ifelse(borderline == TRUE & matched == "Not Matched", "not in scope", sector)
  )

# Plot coverage by dollar value
coverage %>%
  filter(sector != "not in scope") %>%
  summarize(total = sum(as.numeric(loan_size_outstanding)), .by = c(matched)) %>%
  ggplot(aes(matched, total, fill = matched)) + geom_col()
```

---

## Phase 3: Calculate Alignment Targets (r2dii.analysis)

Two methods, applied to different sectors:

| Method | Sectors | What it measures |
|---|---|---|
| **Market Share** (`target_market_share()`) | Automotive, Power, Coal, Oil & Gas | Technology mix (e.g. % renewables, % EVs) |
| **SDA** (`target_sda()`) | Cement, Steel, Aviation | CO2 intensity (tCO2/unit production) |

### 3a: Market Share Approach

```r
scenario <- scenario_demo_2020
regions <- region_isos_demo

# Portfolio-level targets
market_share_targets <- target_market_share(
  data = prioritized_matches,
  abcd = abcd,
  scenario = scenario,
  region_isos = regions
)
```

**Output columns explained:**

- `sector` / `technology`: e.g. "power" / "renewablescap"
- `year`: 2020 through 2025+
- `metric`:
  - `"projected"` -- where the portfolio is heading based on companies' capital plans
  - `"target_sds"` -- target if following the Sustainable Development Scenario
  - `"target_cps"` -- target if following the Current Policies Scenario
  - `"target_sps"` -- target if following the Stated Policies Scenario
  - `"corporate_economy"` -- the whole-market benchmark
- `production`: absolute production volume
- `technology_share`: that technology's share of the sector (0 to 1)
- `percentage_of_initial_production_by_scope`: % change from the base year

**Company-level:**

```r
market_share_by_company <- target_market_share(
  data = prioritized_matches,
  abcd = abcd,
  scenario = scenario,
  region_isos = regions,
  by_company = TRUE,
  weight_production = FALSE
)
```

### 3b: Sectoral Decarbonization Approach (SDA)

```r
co2 <- co2_intensity_scenario_demo

sda_targets <- target_sda(
  data = prioritized_matches,
  abcd = abcd,
  co2_intensity_scenario = co2,
  region_isos = regions
)
```

**Output columns:**

- `emission_factor_metric`:
  - `"projected"` -- portfolio's current emission intensity trajectory
  - `"target_sds"` / `"target_cps"` -- scenario-aligned targets (converges by ~2050)
  - `"corporate_economy"` -- sector-wide benchmark
  - `"adjusted_*"` -- scenario trajectory adjusted for ABCD vs. scenario data differences
- `emission_factor_value`: CO2 intensity (e.g. tCO2 per tonne of cement)

---

## Phase 4: Interpret Results

### Alignment check

- Compare `projected` vs `target_sds` for each sector/technology
- If `projected` is better than (or equal to) the SDS target, the portfolio is aligned for that sector

### Technology Mix (Market Share sectors)

A higher share of low-carbon tech (renewables, EVs) than the benchmark = leader. Lower = laggard.

### Emission Intensity (SDA sectors)

Lower starting intensity = less decarbonization needed. If your portfolio's intensity exceeds the target trajectory, you're misaligned.

---

## Phase 5: Visualize (optional)

```r
library(r2dii.plot)

# Technology mix chart
market_share_targets %>%
  filter(sector == "power", region == "global", scenario_source == "demo_2020") %>%
  qplot_techmix()

# Emission intensity chart
sda_targets %>%
  filter(sector == "cement") %>%
  qplot_emission_intensity()

# Production trajectory chart
market_share_targets %>%
  filter(technology == "renewablescap", region == "global") %>%
  qplot_trajectory()
```

---

## Phase 6: Export Results

```r
readr::write_csv(market_share_targets, "market_share_targets_portfolio.csv")
readr::write_csv(market_share_by_company, "market_share_targets_company.csv")
readr::write_csv(sda_targets, "sda_targets_portfolio.csv")
```

---

## Complete Copy-Paste Demo Script

```r
# ===== INSTALL (run once) =====
install.packages("pacta.loanbook")
install.packages(c("dplyr", "readr", "ggplot2"))

# ===== SETUP =====
library(pacta.loanbook)
library(dplyr)

# ===== MATCHING =====
matched <- match_name(loanbook_demo, abcd_demo)
# In real use: export, validate, re-import here
prioritized <- prioritize(matched)

# ===== MARKET SHARE TARGETS =====
ms_targets <- target_market_share(
  data = prioritized,
  abcd = abcd_demo,
  scenario = scenario_demo_2020,
  region_isos = region_isos_demo
)
head(ms_targets)

# ===== SDA TARGETS =====
sda_targets <- target_sda(
  data = prioritized,
  abcd = abcd_demo,
  co2_intensity_scenario = co2_intensity_scenario_demo,
  region_isos = region_isos_demo
)
head(sda_targets)

# ===== QUICK LOOK =====
# Projected vs target for automotive EVs
ms_targets %>%
  filter(sector == "automotive", technology == "electric", region == "global") %>%
  select(year, metric, production, technology_share)

# Projected vs target for cement emissions
sda_targets %>%
  filter(sector == "cement", region == "global") %>%
  select(year, emission_factor_metric, emission_factor_value)
```

---

## Key References

| Resource | URL |
|---|---|
| PACTA Cookbook (official) | https://rmi-pacta.github.io/pacta.loanbook/articles/cookbook_overview.html |
| Loanbook data dictionary | https://rmi-pacta.github.io/pacta.loanbook/articles/data_loanbook.html |
| ABCD data dictionary | https://rmi-pacta.github.io/pacta.loanbook/articles/data_abcd.html |
| Scenario data sources | https://pacta.rmi.org/pacta-for-banks-2020/methodology-and-supporting-materials/ |
| Metrics deep-dive | https://rmi-pacta.github.io/pacta.loanbook/articles/cookbook_metrics.html |
| Training materials | https://pacta.rmi.org/pacta-for-banks-2020/training-materials/ |
| r2dii.match docs | https://rmi-pacta.github.io/r2dii.match/ |
| r2dii.analysis docs | https://rmi-pacta.github.io/r2dii.analysis/ |
| PACTA for Banks Methodology (v1.2.3) | https://pacta.rmi.org/wp-content/uploads/2024/05/PACTA-for-Banks-Methodology-document_v1.2.3_030524.pdf |
| PACTA Scenario Support Document | https://pacta.rmi.org/wp-content/uploads/2022/10/20221010-PACTA-for-Banks_Scenario-Supporting-document_v1.3.1_final.pdf |
| PACTA Knowledge Hub | https://rmi.gitbook.io/pacta-knowledge-hub/introduction/pacta |

---

## Gotchas & Lessons Learned

These are practical issues discovered while running the full demo pipeline. They are not documented in the official PACTA guides and can cause silent errors or crashes.

### 1. Windows: User Library Required

The R system library (`C:\Program Files\R\...\library`) is read-only without administrator privileges. You **must** install packages to the user library:

```r
# Install
install.packages("pacta.loanbook", lib = Sys.getenv("R_LIBS_USER"))

# Load
library(pacta.loanbook, lib.loc = Sys.getenv("R_LIBS_USER"))
```

Without this, `install.packages()` will fail silently or prompt for admin access.

### 2. Demo Scenario Metric Naming Asymmetry (Critical Bug Trap)

The `demo_2020` scenario data produces **different metric naming conventions** depending on the analysis method:

| Method | Metric names | Pattern |
|---|---|---|
| Market Share (`target_market_share()`) | `target_sds`, `target_cps`, `target_sps` | `target_<scenario_name>` |
| SDA (`target_sda()`) | `target_demo`, `adjusted_scenario_demo` | `target_<scenario_source_suffix>` |

If you write a script that hardcodes `target_sds` for filtering SDA results, it will either return zero rows (silent failure) or crash on `pivot_wider`. **Always inspect the actual metric values first:**

```r
unique(sda_targets$emission_factor_metric)
# Expected with demo data: "projected", "corporate_economy", "target_demo", "adjusted_scenario_demo"
# NOT: "target_sds", "adjusted_scenario_sds"
```

With real IEA/NGFS scenario data, the SDA metrics would use the actual scenario name (e.g., `target_sds`, `adjusted_scenario_sds`), so this trap is specific to the demo datasets.

### 3. Power Sector: NA Values at Forward Years

Several power technologies (gascap, hydrocap, nuclearcap, renewablescap) return `NA` for `projected` production at 2025. This happens because the demo ABCD data lacks forward-looking production plans for these technologies. Consequences:

- `pivot_wider` produces NA columns
- Alignment gap calculations return NA (not errors — silent failure)
- Plots may show missing lines without warning

**Workaround:** Filter out NA values before alignment calculations, or only assess technologies with complete data.

### 4. Steel Match Coverage Can Be Very Low

With demo data, steel match coverage is only ~4% of loan exposure. This means:

- Alignment results represent a tiny, potentially unrepresentative sample
- Do not use low-coverage results for decision-making
- In production: manually review unmatched borrowers, add intermediate parent company names, and consider lowering `min_score` in `match_name()`

### 5. ggplot2 Silently Ignores Unused Scale Mappings

When you provide `scale_color_manual(values = ...)` or `scale_linetype_manual(values = ...)` with keys that don't appear in the filtered data, ggplot2 drops them without warning. This is technically correct behavior, but it can mask the fact that expected data is missing from your plot.

**Tip:** After filtering, always check `unique(data$metric)` to confirm the expected values are present before plotting.

### 6. `by_company = TRUE` Explodes Row Count

`target_market_share(..., by_company = TRUE)` returns results disaggregated per company. In the demo, this goes from 1,210 rows (portfolio level) to 37,349 rows (company level). With a real loanbook of thousands of borrowers, this can easily produce millions of rows. Consider filtering by sector/region before requesting company-level detail.

### 7. Loan Size Weighting Is Implicit

The Market Share and SDA functions internally weight by `loan_size_outstanding`. This means larger loans have proportionally more influence on the portfolio's projected trajectory. If your loanbook has a few very large loans to misaligned companies, they will dominate the results — even if most loans go to aligned companies. Review the company-level output to identify concentration risk.

### 8. `r2dii.plot` Functions Require Specific Filtering

The `qplot_techmix()`, `qplot_trajectory()`, and `qplot_emission_intensity()` functions from `r2dii.plot` expect data filtered to specific columns and values. Common requirements:

- **`qplot_techmix()`** expects `scenario_source`, `sector`, `region`, and `metric` to be filtered. It plots the "extreme years" (first and last) by default. If your data contains multiple scenario sources or regions, you get unexpected facets.
- **`qplot_trajectory()`** expects data filtered to a single technology. Pass the full set of metrics (`projected`, `corporate_economy`, `target_*`) — it handles colors/linetypes internally.
- **`qplot_emission_intensity()`** works on SDA output. Filter to a single sector and region before calling.

```r
# Correct: filter before passing to qplot_techmix
market_share_targets %>%
  filter(scenario_source == "demo_2020", sector == "power",
         region == "global",
         metric %in% c("projected", "corporate_economy", "target_sds")) %>%
  qplot_techmix()
```

### 9. Exact vs Fuzzy Matching: Trade-offs

The `min_score` parameter in `match_name()` controls the trade-off between precision and coverage:

| Setting | Precision | Coverage | Manual Review | Best For |
|---|---|---|---|---|
| `min_score = 1.0` (exact) | Highest | Lowest | None needed | Demo data, clean names |
| `min_score = 0.9` (strict fuzzy) | High | Moderate | Some review | Production with decent data |
| `min_score = 0.8` (default) | Moderate | Highest | Heavy review | Messy real-world data |

In testing with demo data, exact matching (289 raw) and fuzzy matching (326 raw) converge to the same 177 prioritized matches after `prioritize()`. With real bank data containing abbreviations, misspellings, and varying name formats, fuzzy matching will capture significantly more valid matches — but requires mandatory manual validation of every match scoring below 1.0.

**Recommended production workflow:**
```r
# Step 1: Fuzzy match with moderately strict threshold
matched <- match_name(loanbook, abcd, min_score = 0.9, method = "jw", p = 0.1)

# Step 2: Export, manually review matches where score < 1.0
readr::write_csv(matched, "matched_for_review.csv")

# Step 3: After manual review, re-import and prioritize
reviewed <- readr::read_csv("matched_reviewed.csv")
prioritized <- prioritize(reviewed)
```

### 10. Pre-join Sector Classifications for Validation

Joining `sector_classifications` to your loanbook *before* matching enables a sector mismatch validation step. This catches cases where a borrower's bank-assigned sector disagrees with the ABCD sector assignment:

```r
# Pre-join sector codes to human-readable PACTA sectors
loanbook_with_sectors <- loanbook %>%
  mutate(sector_classification_direct_loantaker =
           as.character(sector_classification_direct_loantaker)) %>%
  left_join(sector_classifications, by = c(
    "sector_classification_system" = "code_system",
    "sector_classification_direct_loantaker" = "code"
  )) %>%
  rename(sector_matched = sector, borderline_matched = borderline)

# After matching, check for mismatches
mismatches <- prioritized %>%
  filter(sector_matched != sector)
# If nrow(mismatches) > 0, investigate — the bank's sector code
# disagrees with what ABCD thinks the company does
```

# Intake Schema Contract

## Units

`exposure_vnd` and `credit_limit_vnd` are **whole VND** — not thousands of
VND ("nghìn đồng") and not millions of VND ("triệu đồng"), which are common
denominations in Vietnamese bank MIS reports. A 1 billion VND loan is
`1000000000`, not `1000` and not `1000000`.

Every downstream money figure in this pipeline (loan exposure, credit
limits, sector rankings, engagement priority scores) is computed and
displayed on this same whole-VND scale. If your loanbook extract is
denominated in millions of VND, multiply every exposure and credit-limit
value by 1,000,000 before submitting it.

## Submission size

**Measured for intake validation and name matching** (`docs/scale_benchmark.md`
has the full grid and machine details): on a single busy developer machine,
50,000 loan rows across up to 5,000 distinct counterparties completed intake in
about 28 seconds and fuzzy name matching (`r2dii.match::match_name()`) in about
27 seconds — under a minute for the two stages together. Larger submissions are
accepted — intake has no hard row limit — but have not been characterized.

Two cost drivers behave differently, which matters when sizing a real
submission: **intake scales with the loan row count** and is flat in
counterparty count, while **matching scales with the number of distinct
counterparties** (at 50,000 loans, going from 200 to 5,000 counterparties takes
matching from 6.8 to 26.9 seconds). A book with many loans to few borrowers is
cheap; a book with many distinct borrowers is the one to watch.

These numbers cover **intake and matching only**, not the full pipeline. The
PACTA analysis stages (`target_market_share()`, `target_sda()`) and the
per-sector TRISK runs have still not been benchmarked at this scale; do not
assume the full chain completes quickly just because these two stages do.

## Input Schema (Bank Provides)

### Required Columns

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `counterparty_name` | string | Legal name of the borrowing entity | Cong ty CP Nhiet Dien Vinh Tan |
| `exposure_vnd` | numeric (≥ 0) | Outstanding exposure in VND | 800000000000 |
| `sector_code` | string | Industry classification code | D3511 |
| `sector_code_system` | string | Code system: `VSIC` or `ISIC` | VSIC |
| `credit_limit_vnd` | numeric (≥ 0) | Total credit limit in VND | 960000000000 |

### Optional Columns

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `lei` | string | Legal Entity Identifier (20 chars) | 5493000IBP32UQZ0KL24 |
| `tax_id` | string | Local tax ID | 0301452948 |
| `parent_name` | string | Name of ultimate parent group | Tap doan Dien luc Viet Nam (EVN) |
| `parent_id` | string | Parent identifier (if known) | EVN_001 |
| `currency` | string | Currency of exposure (`VND` or `USD`) | VND |

## Validation Rules

Every submitted row is classified into exactly one of two tiers:

- **Errors** are genuine schema violations that make a row unusable and the
  row is **dropped** from `normalized_loanbook.csv`:
  - missing or empty `counterparty_name`
  - non-numeric or negative `exposure_vnd`
  - non-numeric or negative `credit_limit_vnd`
  - `sector_code_system` other than `VSIC` or `ISIC`
  - missing or empty `sector_code`, or a VSIC `sector_code` that is not
    alphanumeric-with-a-digit-core (a *format* problem)
  - a duplicate row

- **Warnings** leave the row usable but reduced in scope and **never** drop it
  from `normalized_loanbook.csv`:
  - `sector_out_of_scope` — a well-formed sector code with no PACTA mapping.
    The row is retained with its normalized code and PACTA sector
    `"not in scope"` so downstream exposure accounting can still see it.
  - `fx_converted` — a `USD` row converted to VND at the configured rate.
  - `fx_rate_missing` — a `USD` row retained but with exposure/credit limit
    set to `NA` because no `inputs.fx_rate_usd_vnd` is configured.
  - `unsupported_currency` — a currency other than `VND` or `USD`; retained
    with exposure set to `NA`.

Warnings are written to `validation_warnings.csv` (columns `row`, `column`,
`classification`, `message`) on every run, even when empty. The reconciliation
report (PHASE-06) consumes this file and the raw loanbook to show exactly what
was submitted, processed, and dropped — in both row counts and VND.

### Currency Policy

- `VND` rows pass through unchanged.
- `USD` rows are converted to VND **once, at intake**, using the engagement
  config's `inputs.fx_rate_usd_vnd` (VND per 1 USD). Without a configured rate
  they are retained with exposure set to `NA` and the intake exits non-zero
  naming the missing key — they are never silently dropped and never silently
  converted at a guessed rate. The rate is recorded in the engagement's
  `pipeline_manifest.json`.
- Any other currency is retained with exposure set to `NA` and flagged
  `unsupported_currency`, so it is visibly excluded from money totals rather
  than silently counted at the wrong scale.

### Accepted Sector Codes

The following codes map to PACTA sectors (both the ISIC Rev.4 4-digit parents
and the VSIC 2018 5-digit sub-classes). Any other well-formed code is
classified `"not in scope"` (a warning, not an error):

| Code(s) | PACTA sector |
|---------|--------------|
| `3510`, `35101`, `35102`, `35103`, `3511` | `power` |
| `2910`, `29101`, `29102` | `automotive` |
| `2394`, `23941`, `23942` | `cement` |
| `2410`, `24101`, `24102` | `steel` |
| `0510`, `05101` | `coal` |
| `0610`, `0620`, `06101` | `oil and gas` |

## Output Schema (Pipeline-Ready)

The normalized output matches the 13-column format of `data/vietnam_loanbook.csv`.

### Column Derivation Rules

| Output Column | Type | Derivation |
|--------------|------|------------|
| `id_loan` | string | Auto-generated: `CL_L001`, `CL_L002`, … |
| `id_direct_loantaker` | string | Derived from row index or tax ID: `CL_C001`, … |
| `name_direct_loantaker` | string | Pass-through from `counterparty_name` |
| `id_ultimate_parent` | string | From `parent_id` if provided, else `CL_UP001` |
| `name_ultimate_parent` | string | From `parent_name` if provided, else `counterparty_name` |
| `loan_size_outstanding` | numeric | Pass-through from `exposure_vnd` |
| `loan_size_outstanding_currency` | string | Normalized to `VND` |
| `loan_size_credit_limit` | numeric | Pass-through from `credit_limit_vnd` |
| `loan_size_credit_limit_currency` | string | Normalized to `VND` |
| `sector_classification_system` | string | Normalized to `ISIC` (VSIC codes have letter prefix stripped) |
| `sector_classification_direct_loantaker` | string | ISIC code (4-digit zero-padded, or 5-digit VSIC sub-class preserved) |
| `lei_direct_loantaker` | string | From `lei` if provided, else `NA` |
| `isin_direct_loantaker` | string | Always `NA` in v1 |

### VSIC→ISIC Normalization

- Strip the leading letter prefix from VSIC codes (e.g., `D3511` → `3511`)
- Zero-pad to 4 digits only when the code is shorter than 4 digits — VSIC 2018
  5-digit sub-classes (e.g., `35101`) are preserved intact, not truncated
- Codes outside the accepted table above are classified as `"not in scope"`
  (a warning, never a dropped row)

## ABCD (Asset-Based Company Data) Schema

The pipeline also consumes an ABCD file that maps companies to physical assets. For a real engagement this is a sourcing decision (see `docs/abcd_sourcing_decision.md`); in the demo it is the synthetic `data/vietnam_abcd.csv`.

### Required Columns

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `company_id` | string | Stable company identifier | VN_ABCD_001 |
| `name_company` | string | Company name (must match loanbook ultimate-parent or direct-loantaker names after normalization) | EVN (Electricity of Vietnam) |
| `lei` | string | Legal Entity Identifier, or `NA` | NA |
| `sector` | string | PACTA sector | power |
| `technology` | string | PACTA technology | coalcap |
| `production_unit` | string | Unit of production | MW |
| `year` | integer | Year of the observation | 2025 |
| `production` | numeric | Production / capacity value | 12500 |
| `emission_factor` | numeric | Emission factor where applicable; `NA` otherwise | NA |
| `plant_location` | string | ISO country code | VN |
| `is_ultimate_owner` | logical | Whether this row represents the ultimate owner | TRUE |
| `emission_factor_unit` | string | Unit for emission factor, or `NA` | NA |

### Provenance Columns

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `data_source` | string | Origin of the row (e.g., Asset Impact, company report, GEM tracker) | synthetic_demo |
| `as_of_year` | integer | Year the data was collected / valid for | 2025 |

A template with illustrative synthetic rows is available at `intake/templates/abcd_template.csv`.

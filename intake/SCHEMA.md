# Intake Schema Contract

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
| `sector_classification_direct_loantaker` | string | ISIC code (4-digit, zero-padded) |
| `lei_direct_loantaker` | string | From `lei` if provided, else `NA` |
| `isin_direct_loantaker` | string | Always `NA` in v1 |

### VSIC→ISIC Normalization

- Strip the leading letter prefix from VSIC codes (e.g., `D3511` → `3511`)
- Zero-pad to 4 digits (e.g., `511` → `0511`)
- Codes outside the known ISIC→PACTA mapping are classified as "not in scope"

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

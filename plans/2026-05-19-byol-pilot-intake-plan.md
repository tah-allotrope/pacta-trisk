---
title: "Bring-Your-Own-Loanbook (BYOL) Pilot Intake"
date: "2026-05-19"
status: "completed"
request: "Build an intake contract, Excel/CSV template, validation/mapping wizard script, and operator-gated dashboard upload page so a real Vietnamese bank can plug in their own loanbook and get normalized PACTA+TRISK-ready output."
plan_type: "multi-phase"
research_inputs:
  - "research/2026-04-08_integration-trisk-model-existing.md"
  - "research/future_planning_ideas.md"
---

# Plan: Bring-Your-Own-Loanbook (BYOL) Pilot Intake

## Objective
Enable a real Vietnamese bank to submit their loanbook and receive a normalized, pipeline-ready dataset without manual CSV engineering. Today, converting a demo conversation into a paid pilot requires hand-rebuilding `data/vietnam_loanbook.csv` and related inputs — this plan closes that gap by defining an intake contract, providing bilingual templates, building an R validation/mapping script, and adding an operator-gated Streamlit page for upload and review.

## Context Snapshot
- **Current state:** The repo's PACTA and TRISK pipelines consume hand-built CSVs under `data/` (e.g., `vietnam_loanbook.csv` with 43 loans, 13 columns). The VSIC→ISIC→PACTA sector mapping logic exists in `scripts/pacta_vietnam_scenario.R` (lines 100–108) as a hardcoded `vsic_to_pacta` tribble joined against `r2dii.data::sector_classifications`. The dashboard is publicly deployed on Streamlit Cloud with no auth layer; operator-only features use environment-variable gating (precedent: `TRISK_LIVE_RERUN=1` in `dashboard/lib/live_rerun.py`).
- **Desired state:** A new `intake/` directory with a documented input contract and downloadable templates. A new `scripts/intake_validate_and_map.R` that reads any conforming loanbook, validates it, applies VSIC/ISIC mapping, runs fuzzy matching, and emits a normalized loanbook plus a validation report. A new `dashboard/pages/6_Intake_Wizard.py` gated behind `BYOL_INTAKE=1` that lets an operator upload, review, and download the mapped output. A privacy posture document at `docs/intake_privacy.md`.
- **Key repo surfaces:** `data/vietnam_loanbook.csv` (target schema), `scripts/pacta_vietnam_scenario.R` (VSIC mapping at lines 100–135, fuzzy matching at lines 140+), `dashboard/lib/live_rerun.py` (env-flag gating pattern), `dashboard/lib/loaders.py` (cached loader pattern), `dashboard/pages/5_Scenario_Builder.py` (latest page), `dashboard/requirements.txt`, `dashboard/tests/`, `docs/`.
- **Out of scope:** ABCD intake (banks do not have asset-level company data — we provide that), scenario intake, multi-bank comparison, persistent user auth, public-facing intake on Streamlit Cloud, automated full-pipeline rerun from intake output.

## Research Inputs
- `research/2026-04-08_integration-trisk-model-existing.md` - Confirms that `trisk.model::run_trisk()` expects `assets.csv`, `scenarios.csv`, `financial_features.csv`, and `ngfs_carbon_price.csv` as inputs. The BYOL intake only needs to produce a normalized loanbook; the ABCD and scenario files remain provider-supplied. This scopes the intake contract to loanbook columns only.
- `research/future_planning_ideas.md` - Idea 3 (Engagement Action Layer) depends on company-level alignment joined with TRISK scores. The intake pipeline must preserve `name_direct_loantaker` and `id_direct_loantaker` linkage so downstream engagement scoring can join on `name_abcd` after matching. This informs the required output schema.

## Assumptions and Constraints
- **ASM-001:** Vietnamese banks use VSIC 2018 codes, which are structurally ISIC Rev.4 with a letter prefix. The mapping table in `pacta_vietnam_scenario.R` (6 sector codes) is sufficient for the PACTA-covered sectors; codes outside this set are classified as "not in scope."
- **ASM-002:** The intake wizard runs operator-side only (local or private deployment). The public `pactavn.streamlit.app` will never expose the upload page. Gating follows the `TRISK_LIVE_RERUN` env-var precedent.
- **ASM-003:** Banks will provide exposure in VND. The pipeline already handles VND natively (`loan_size_outstanding_currency = "VND"`).
- **CON-001:** No raw counterparty-level data may be committed to the repo or displayed on the public dashboard. The intake wizard operates on the operator's local machine only; normalized output stays on disk.
- **CON-002:** The R validation script must work without additional package installs beyond what the repo already uses (`dplyr`, `readr`, `stringi`, `r2dii.match`, `r2dii.data`).
- **DEC-001:** The intake output schema must match the existing `data/vietnam_loanbook.csv` column set exactly (13 columns) so `scripts/pacta_vietnam_scenario.R` can consume it without modification.

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Define intake contract, column schema, and privacy posture | None | `intake/README.md`, `intake/SCHEMA.md`, `docs/intake_privacy.md` |
| PHASE-02 | Build intake templates with examples and Vietnamese instructions | PHASE-01 | `intake/templates/loanbook_template.xlsx`, `intake/templates/loanbook_template.csv`, `intake/templates/README_vi.md` |
| PHASE-03 | Build the R validation and mapping script | PHASE-01 | `scripts/intake_validate_and_map.R`, validation report output |
| PHASE-04 | Build the operator-gated Streamlit intake page | PHASE-02, PHASE-03 | `dashboard/pages/6_Intake_Wizard.py`, `dashboard/lib/intake.py`, updated tests |
| PHASE-05 | End-to-end verification, docs, and packaging | PHASE-04 | Updated `dashboard/README.md`, `docs/demo-script.md`, phase report HTML |

## Detailed Phases

### PHASE-01 - Intake Contract and Privacy Posture
**Goal**
Define the minimum loanbook columns a bank must provide, the normalized output schema the pipeline expects, and the privacy rules governing how client data is handled.

**Tasks**
- [ ] TASK-01-01: Create `intake/README.md` documenting the intake workflow overview: what the bank provides, what the operator runs, what comes out, and where it goes.
- [ ] TASK-01-02: Create `intake/SCHEMA.md` with two tables: (a) **Input schema** — minimum required columns (`counterparty_name`, `exposure_vnd`, `sector_code`, `sector_code_system`, `credit_limit_vnd`) plus optional columns (`lei`, `tax_id`, `parent_name`, `parent_id`, `currency`); (b) **Output schema** — the 13 columns of `data/vietnam_loanbook.csv` (`id_loan`, `id_direct_loantaker`, `name_direct_loantaker`, `id_ultimate_parent`, `name_ultimate_parent`, `loan_size_outstanding`, `loan_size_outstanding_currency`, `loan_size_credit_limit`, `loan_size_credit_limit_currency`, `sector_classification_system`, `sector_classification_direct_loantaker`, `lei_direct_loantaker`, `isin_direct_loantaker`).
- [ ] TASK-01-03: Define mapping rules from input to output columns: auto-generated `id_loan` (sequential `CL_L001`..`CL_LNNN`), `id_direct_loantaker` derived from row index or tax ID, VSIC-to-ISIC code normalization (strip letter prefix if present, zero-pad to 4 digits), currency normalization to VND.
- [ ] TASK-01-04: Create `docs/intake_privacy.md` covering: (a) no raw client data is committed to git, (b) no raw counterparty names appear on the public dashboard, (c) the intake wizard runs behind `BYOL_INTAKE=1` env flag only, (d) optional pre-anonymization of borrower names before pipeline run, (e) aggregated views only in dashboard output.
- [ ] TASK-01-05: Add `intake/.gitignore` with patterns to prevent accidental commits of client files: `*.xlsx`, `*.xls`, `*.csv`, `!templates/*.csv`, `output/`.

**Files / Surfaces**
- `intake/README.md` - New: workflow overview.
- `intake/SCHEMA.md` - New: column-level input/output contract.
- `docs/intake_privacy.md` - New: privacy posture document.
- `intake/.gitignore` - New: safety net against accidental client data commits.
- `data/vietnam_loanbook.csv` - Reference: defines the target 13-column output schema.

**Dependencies**
- None.

**Exit Criteria**
- [ ] `intake/SCHEMA.md` documents all 13 output columns with types, nullability, and derivation rules.
- [ ] `docs/intake_privacy.md` exists and covers the four privacy rules listed above.
- [ ] `intake/.gitignore` blocks `*.xlsx` and `*.csv` except template files.

**Phase Risks**
- **RISK-01-01:** Input schema may be too narrow for some banks (e.g., banks using GICS instead of VSIC/ISIC). Mitigation: document VSIC and ISIC as the supported code systems in v1; add a `sector_hint` freetext column as a fallback that the validation script can use for manual review flagging.

### PHASE-02 - Intake Templates
**Goal**
Provide downloadable Excel and CSV templates with example rows, column descriptions, and a Vietnamese-language instruction sheet so a bank data team can populate the file without a call.

**Tasks**
- [ ] TASK-02-01: Create `intake/templates/loanbook_template.csv` with the input schema columns as headers and 3 example rows using fictional but realistic Vietnamese company names (not MCB names to avoid confusion with the synthetic demo).
- [ ] TASK-02-02: Create `intake/templates/loanbook_template.xlsx` with two sheets: (a) "Data" — same columns and examples as the CSV; (b) "Instructions" — Vietnamese + English column descriptions, data types, and examples per column, plus a note on VSIC code format.
- [ ] TASK-02-03: Add Excel data validation rules on the "Data" sheet: `sector_code_system` as a dropdown (`VSIC`, `ISIC`), `currency` as a dropdown (`VND`, `USD`), `exposure_vnd` as numeric ≥ 0.
- [ ] TASK-02-04: Create `intake/templates/README_vi.md` — a Vietnamese-language quick-start guide explaining what to fill, how to export from the bank's core system, and where to send the file.

**Files / Surfaces**
- `intake/templates/loanbook_template.csv` - New: CSV template.
- `intake/templates/loanbook_template.xlsx` - New: Excel template with instructions sheet.
- `intake/templates/README_vi.md` - New: Vietnamese instructions.

**Dependencies**
- PHASE-01 schema contract.

**Exit Criteria**
- [ ] CSV template opens in Excel and has the correct column headers matching `intake/SCHEMA.md` input schema.
- [ ] XLSX template has "Data" and "Instructions" sheets; dropdowns work for `sector_code_system` and `currency`.
- [ ] Vietnamese README is present and references the correct column names.

**Phase Risks**
- **RISK-02-01:** Excel template generation from R or Python may produce inconsistent formatting. Mitigation: use the `openpyxl` Python library (already available via pandas dependency) for template generation, or hand-create the XLSX once and commit it as a binary artifact.

### PHASE-03 - R Validation and Mapping Script
**Goal**
Build `scripts/intake_validate_and_map.R` that reads any conforming client loanbook, validates it against the intake schema, applies VSIC→ISIC→PACTA sector mapping, runs diacritic normalization and fuzzy matching against ABCD, and emits a normalized loanbook plus a structured validation report.

**Tasks**
- [ ] TASK-03-01: Create `scripts/intake_validate_and_map.R` that accepts a `--input` file path and an `--output-dir` path via `commandArgs()`. Default output dir: `intake/output/`.
- [ ] TASK-03-02: Implement schema validation: check required columns exist, check `exposure_vnd` is numeric and non-negative, check `sector_code_system` is one of `VSIC` or `ISIC`, flag rows with missing `counterparty_name`. Emit a `validation_errors.csv` listing row number, column, and error message for every failing row.
- [ ] TASK-03-03: Implement VSIC→ISIC normalization: strip letter prefix (e.g., `D3511` → `3511`), zero-pad to 4 digits. Reuse the `vsic_to_pacta` mapping table from `pacta_vietnam_scenario.R` lines 100–108.
- [ ] TASK-03-04: Implement diacritic normalization using `stringi::stri_trans_general(name, "Latin-ASCII")` (same as `pacta_vietnam_scenario.R`).
- [ ] TASK-03-05: Implement column mapping from input schema to the 13-column output schema per the rules in `intake/SCHEMA.md`. Auto-generate `id_loan`, `id_direct_loantaker`, and `id_ultimate_parent` as sequential IDs with a `CL_` prefix.
- [ ] TASK-03-06: Implement optional fuzzy pre-matching against `data/vietnam_abcd.csv` using `r2dii.match::match_name()` with `min_score = 0.8`. Emit a `match_preview.csv` showing each input counterparty, best ABCD match, score, and a `review_needed` flag for scores < 1.0.
- [ ] TASK-03-07: Emit a `validation_summary.txt` plain-text report: total rows, rows passing validation, rows failing, sector distribution, match coverage preview, and a list of unresolved ISIC codes.
- [ ] TASK-03-08: Emit the normalized loanbook as `intake/output/normalized_loanbook.csv` in the exact 13-column format of `data/vietnam_loanbook.csv`.

**Files / Surfaces**
- `scripts/intake_validate_and_map.R` - New: main validation/mapping script.
- `scripts/pacta_vietnam_scenario.R` - Reference: VSIC mapping table (lines 100–108), diacritic normalization pattern.
- `data/vietnam_abcd.csv` - Reference: fuzzy match target for preview.
- `intake/output/` - New: default output directory (gitignored).

**Dependencies**
- PHASE-01 schema contract.

**Exit Criteria**
- [ ] Running `Rscript scripts/intake_validate_and_map.R --input intake/templates/loanbook_template.csv --output-dir intake/output/` produces `normalized_loanbook.csv`, `validation_errors.csv`, `match_preview.csv`, and `validation_summary.txt` without errors.
- [ ] `normalized_loanbook.csv` has exactly 13 columns matching the `data/vietnam_loanbook.csv` header.
- [ ] Rows with invalid `sector_code` appear in `validation_errors.csv` but do not block output (they are classified as "not in scope").
- [ ] The script runs using only packages already in the repo's R library: `dplyr`, `readr`, `stringi`, `r2dii.match`, `r2dii.data`, `tibble`.

**Phase Risks**
- **RISK-03-01:** `r2dii.match::match_name()` may fail if the client loanbook has unusual encoding (e.g., Windows-1258 Vietnamese). Mitigation: add an explicit `readr::read_csv(locale = locale(encoding = "UTF-8"))` with a fallback to `latin1` and a warning.
- **RISK-03-02:** The fuzzy match preview against `data/vietnam_abcd.csv` uses the synthetic ABCD, not real company data. Mitigation: document in the validation summary that match preview results will improve when production ABCD data is loaded.

### PHASE-04 - Operator-Gated Streamlit Intake Page
**Goal**
Add a `dashboard/pages/6_Intake_Wizard.py` page visible only when `BYOL_INTAKE=1` is set, allowing an operator to upload a client loanbook, view the validation report inline, and download the normalized output — all without committing anything to the repo or exposing data publicly.

**Tasks**
- [ ] TASK-04-01: Create `dashboard/lib/intake.py` with: (a) `is_intake_enabled() -> bool` checking `os.environ.get("BYOL_INTAKE") == "1"` (following the `live_rerun.py` pattern); (b) `run_intake_validation(uploaded_path: Path, output_dir: Path) -> dict` that calls `Rscript scripts/intake_validate_and_map.R` via subprocess with a 60-second timeout; (c) `parse_validation_summary(output_dir: Path) -> dict` that reads the summary text into structured fields.
- [ ] TASK-04-02: Create `dashboard/pages/6_Intake_Wizard.py` with: (a) early return with `st.stop()` if `is_intake_enabled()` is False; (b) `st.file_uploader` for CSV or XLSX; (c) a "Validate & Map" button that saves the upload to a temp file and calls `run_intake_validation`; (d) display of `validation_summary.txt` as a card; (e) display of `validation_errors.csv` as a table if non-empty; (f) display of `match_preview.csv` as a table with score-colored rows; (g) download buttons for `normalized_loanbook.csv` and the full validation bundle as a ZIP.
- [ ] TASK-04-03: Add XLSX-to-CSV conversion in the upload handler: if the uploaded file is `.xlsx`, read the "Data" sheet with `pandas.read_excel()` and write to a temp CSV before passing to the R script. Add `openpyxl` to `dashboard/requirements.txt`.
- [ ] TASK-04-04: Add a startup banner in `dashboard/app.py` when `BYOL_INTAKE=1` is enabled, following the same pattern as the `TRISK_LIVE_RERUN` banner: `st.sidebar.success("Intake Wizard enabled (operator mode)")`.
- [ ] TASK-04-05: Add `dashboard/tests/test_intake.py` covering: (a) `is_intake_enabled()` returns True/False based on env var; (b) uploaded XLSX converts to valid CSV; (c) mock subprocess call returns expected output structure.
- [ ] TASK-04-06: Add the synthetic-data banner and privacy disclaimer to the intake page header, referencing `docs/intake_privacy.md`.

**Files / Surfaces**
- `dashboard/pages/6_Intake_Wizard.py` - New: operator-only intake page.
- `dashboard/lib/intake.py` - New: intake adapter module.
- `dashboard/lib/live_rerun.py` - Reference: env-flag gating pattern to follow.
- `dashboard/requirements.txt` - Add `openpyxl`.
- `dashboard/app.py` - Add intake-enabled sidebar banner.
- `dashboard/tests/test_intake.py` - New: intake-specific tests.

**Dependencies**
- PHASE-02 templates (for XLSX-to-CSV conversion testing).
- PHASE-03 R script (called via subprocess).

**Exit Criteria**
- [ ] With `BYOL_INTAKE=1` set, the Intake Wizard page appears in the sidebar and loads without errors.
- [ ] Without the env flag, the page does not appear and `st.stop()` prevents any rendering.
- [ ] Uploading `intake/templates/loanbook_template.csv` triggers validation and displays the summary, errors, and match preview.
- [ ] Uploading `intake/templates/loanbook_template.xlsx` auto-converts and produces the same result.
- [ ] Download buttons produce `normalized_loanbook.csv` and a ZIP bundle.
- [ ] `python -m pytest dashboard/tests` passes with the new intake tests included.

**Phase Risks**
- **RISK-04-01:** Subprocess call to Rscript may fail on Streamlit Cloud even though the page is gated. Mitigation: the env flag gate prevents the page from loading at all on the public deployment; additionally, the subprocess call checks for `R_RSCRIPT` env var before attempting execution.
- **RISK-04-02:** Large loanbook files (10k+ rows) may cause the 60-second subprocess timeout to fire. Mitigation: document a 5,000-row soft limit in the intake contract; add a row-count pre-check in the upload handler that warns before proceeding.

### PHASE-05 - Verification, Docs, and Packaging
**Goal**
Run the full intake flow end-to-end with the template file, update operator docs, and produce a phase report artifact.

**Tasks**
- [ ] TASK-05-01: Run the R validation script standalone: `Rscript scripts/intake_validate_and_map.R --input intake/templates/loanbook_template.csv --output-dir intake/output/` and verify all 4 output files.
- [ ] TASK-05-02: Run the dashboard with `BYOL_INTAKE=1` and walk the full upload→validate→download flow manually, capturing a screenshot of each step.
- [ ] TASK-05-03: Feed `intake/output/normalized_loanbook.csv` into `scripts/pacta_vietnam_scenario.R` by temporarily replacing `data/vietnam_loanbook.csv` and confirm the pipeline runs through matching without errors.
- [ ] TASK-05-04: Run `python -m pytest dashboard/tests` and confirm all tests pass (existing + new intake tests).
- [ ] TASK-05-05: Update `dashboard/README.md` with an "Intake Wizard" section documenting the `BYOL_INTAKE=1` flag, operator setup, and the upload flow.
- [ ] TASK-05-06: Update `docs/demo-script.md` with an intake demo segment: "Here's the template we send the bank, here's what comes back, here's how it flows into the pipeline."
- [ ] TASK-05-07: Generate `reports/2026-05-XX-byol-intake.html` summarizing the intake contract, template artifacts, validation script, dashboard page, and privacy posture.

**Files / Surfaces**
- `dashboard/README.md` - Update with intake section.
- `docs/demo-script.md` - Update with intake demo flow.
- `reports/` - Phase report artifact.
- `intake/output/` - Verification artifacts (gitignored).

**Dependencies**
- PHASE-04.

**Exit Criteria**
- [ ] All `dashboard/tests` pass.
- [ ] The normalized loanbook from the template is consumable by `pacta_vietnam_scenario.R` without modification.
- [ ] `dashboard/README.md` documents the intake wizard setup.
- [ ] Phase report HTML is generated.

**Phase Risks**
- **RISK-05-01:** Template example rows may not exercise all validation edge cases. Mitigation: add at least one deliberately invalid row (missing counterparty, unknown ISIC code) to the template examples to demonstrate error handling.

## Verification Strategy
- **TEST-001:** `python -m pytest dashboard/tests` — must pass with existing tests plus `test_intake.py`.
- **TEST-002:** `Rscript scripts/intake_validate_and_map.R --input intake/templates/loanbook_template.csv --output-dir intake/output/` — must produce 4 output files without errors.
- **TEST-003:** Unit test for `scenario_id`-style intake column mapping round-trip in `dashboard/tests/test_intake.py`.
- **MANUAL-001:** With `BYOL_INTAKE=1`, upload the CSV template, verify summary card, download normalized loanbook, and confirm it has 13 columns matching `data/vietnam_loanbook.csv`.
- **MANUAL-002:** With `BYOL_INTAKE=1`, upload the XLSX template, verify auto-conversion produces the same result as the CSV upload.
- **MANUAL-003:** Without `BYOL_INTAKE=1`, confirm the Intake Wizard page does not appear in the sidebar.
- **OBS-001:** The R validation script prints a structured summary to stdout; the dashboard adapter surfaces this in the page.
- **OBS-002:** `dashboard/app.py` prints a startup banner when `BYOL_INTAKE=1` is detected.

## Risks and Alternatives
- **RISK-001:** A real bank's loanbook may have columns or naming conventions not anticipated by the v1 intake schema. Mitigation: the schema includes optional columns and the validation script emits warnings rather than hard failures for unexpected columns. The `sector_hint` freetext column provides a manual fallback.
- **RISK-002:** Vietnamese character encoding issues (Windows-1258 vs UTF-8) may corrupt counterparty names. Mitigation: the R script uses explicit UTF-8 locale, falls back to latin1, and applies `stringi::stri_trans_general` normalization before matching.
- **RISK-003:** Accidental commit of client data to the public repo. Mitigation: `intake/.gitignore` blocks all CSVs and XLSX files except templates; `docs/intake_privacy.md` documents the rules; `intake/output/` is gitignored.
- **ALT-001:** Build the intake wizard as a standalone CLI tool instead of a Streamlit page. Rejected because the operator already runs the dashboard locally for live-rerun mode, and the Streamlit page provides a visual validation report that is harder to achieve in a CLI.
- **ALT-002:** Use Python instead of R for the validation script. Rejected because the fuzzy matching and sector classification logic (`r2dii.match`, `r2dii.data`) are R packages with no Python equivalent, and the existing pipeline is R-based.

## Grill Me
1. **Q-001:** Should the intake support GICS sector codes in addition to VSIC/ISIC, or is VSIC/ISIC sufficient for v1?
   - **Recommended default:** VSIC and ISIC only for v1. GICS support deferred.
   - **Why this matters:** Adding GICS requires a GICS→PACTA mapping table that `r2dii.data::sector_classifications` already contains, but it also requires the bank to provide GICS codes — uncommon for Vietnamese banks that use VSIC.
   - **If answered differently:** Add GICS as a third accepted value in `sector_code_system` and extend the validation script to resolve GICS codes via the existing `sector_classifications` table.

2. **Q-002:** Should the optional pre-anonymization of borrower names be automated (hash-based replacement before pipeline run) or manual (bank does it before sending)?
   - **Recommended default:** Manual — the bank anonymizes before sending if they choose to. The template README documents this option.
   - **Why this matters:** Automated anonymization requires a reversible mapping stored securely, which adds complexity and a new security surface.
   - **If answered differently:** Add a `--anonymize` flag to `intake_validate_and_map.R` that replaces names with SHA-256 hashes and stores a lookup table in a password-protected ZIP in `intake/output/`.

3. **Q-003:** Should the intake wizard support direct upload of the bank's raw export format (e.g., T24 core banking extract), or only the standardized template?
   - **Recommended default:** Standardized template only for v1. Raw-format adapters are a future phase.
   - **Why this matters:** Each core banking system (T24, Flexcube, Silverlake) has a different export format. Building adapters is a separate, larger effort.
   - **If answered differently:** Add a `scripts/intake_adapters/` directory with per-system parsers and a format-detection step in the R script. Scope grows significantly.

4. **Q-004:** What is the target turnaround time for the intake→pipeline→output flow, and should the intake wizard trigger a full pipeline run or just the normalization step?
   - **Recommended default:** Normalization only in v1. The operator manually runs the PACTA/TRISK pipeline with the normalized loanbook as a separate step.
   - **Why this matters:** A full auto-run (PACTA match → analysis → TRISK stress) would require orchestrating multiple R scripts from the Streamlit subprocess, significantly increasing complexity and runtime.
   - **If answered differently:** Add a "Run full pipeline" button in the intake wizard that chains `pacta_vietnam_scenario.R` and `trisk_sector_demo.R` via subprocess. Requires a 10+ minute timeout and progress reporting.

## Suggested Next Step
Answer the Grill Me questions (or accept the recommended defaults), then begin PHASE-01 by creating the `intake/` directory structure and writing `intake/SCHEMA.md` and `docs/intake_privacy.md`.

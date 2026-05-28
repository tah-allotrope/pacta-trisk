---
title: "Engagement & Disclosure Output Layer"
date: "2026-05-28"
status: "draft"
request: "Turn Idea 3 (Engagement & Disclosure Output Layer) from plans/2026-05-02-commercial-demo-expansion-ideas.md into a multi-phase implementation plan."
plan_type: "multi-phase"
research_inputs:
  - "research/future_planning_ideas.md"
  - "research/2026-04-08_integration-trisk-model-existing.md"
  - "research/2026-05-22_decision263-vietnam-ghg.md"
---

# Plan: Engagement & Disclosure Output Layer

## Objective
Convert the pipeline's analytical outputs (PACTA alignment + TRISK transition-risk results) into tangible, client-facing deliverables: per-borrower engagement letters and a board/regulator-ready disclosure pack. This closes the last gap identified in the commercial-demo triage (`plans/2026-05-02-commercial-demo-expansion-ideas.md`, Idea 3) — the layer that turns a one-off analytical demo into a recurring, "what do I do Monday morning and what do I file with SBV" deliverable.

## Context Snapshot
- **Current state:** The repo ends at analytics. PACTA company-level alignment lives in `synthesis_output/vietnam/04_vn_ms_company.csv` and `06_vn_ms_alignment_2030.csv` / `06_vn_sda_alignment_2030.csv`; TRISK borrower-level results live in `dashboard/data/trisk/<sector>/` (`npv_results_latest.csv`, `pd_results_latest.csv`, `top_borrowers_alignment_trisk.csv`). A proven self-contained-HTML report generator pattern exists (`scripts/generate_report.R`, `scripts/generate_bidv_report.R`) using base64-embedded PNGs, inline CSS, and a regex `md_to_html()` converter. The dashboard has an operator-gating pattern (`dashboard/lib/intake.py`: `is_intake_enabled()` keyed on env flag `BYOL_INTAKE=1`; `dashboard/pages/6_Intake_Wizard.py` gates on it). Branding helpers are in `dashboard/lib/branding.py`. **None of Idea 3's deliverables exist:** no `scripts/generate_engagement_letters.R`, no `scripts/generate_disclosure_pack.R`, no `dashboard/pages/*Outputs.py`, no `templates/engagement|disclosure/`.
- **Desired state:** (a) `scripts/engagement_scoring.R` produces a composite borrower priority list; (b) `scripts/generate_engagement_letters.R` produces a one-page bilingual letter per top-N borrower; (c) `scripts/generate_disclosure_pack.R` produces a TCFD/ISSB-framed disclosure pack; (d) an operator-gated `dashboard/pages/7_Outputs.py` lists and downloads the artifacts; (e) editable templates under `templates/engagement/` and `templates/disclosure/`. Every artifact carries a synthetic-data watermark and a "requires human review before external use" disclaimer.
- **Key repo surfaces:** `scripts/generate_bidv_report.R` (HTML-gen + base64 + md_to_html pattern to copy), `scripts/sector_prioritization.R` (existing scoring/ranking logic to mirror), `dashboard/data/trisk/<sector>/top_borrowers_alignment_trisk.csv` (TRISK priority scores), `synthesis_output/vietnam/04_vn_ms_company.csv` (PACTA company alignment), `dashboard/lib/intake.py` + `dashboard/pages/6_Intake_Wizard.py` (operator-gating + watermark pattern), `dashboard/lib/branding.py` (colors, `apply_page_frame`, `footer_note`), `docs/TRISK_Demo_Assumptions.md` + `docs/PACTA_Beginner_Guide.md` (methodology-appendix source), `docs/bidv_decision263_mapping.md` (Decision 263 / SBV framing for disclosure).
- **Out of scope:** New PACTA/TRISK model runs (this layer only synthesizes existing snapshot outputs); real bank data ingestion; full Vietnamese translation of methodology prose; hosting the operator pages on the public Streamlit deployment; native DOCX rendering via `officer` (deferred — see Grill Me Q-001).

## Research Inputs
- `research/future_planning_ideas.md` — its "Idea 3: Bank Engagement Action Layer" is the most directly reusable brief. It specifies the composite scoring approach (`0.5 × normalized_alignment_gap + 0.5 × normalized_trisk_priority_score`, joined on `name_abcd`), the prompt-template-in-CSV approach (so the bank can rebrand without code), the "TRISK N/A — power pilot only" handling for non-power borrowers, and the mandatory disclaimers (render values from the data row, never hardcode numbers). This plan adopts that scoring math in PHASE-01 and the CSV-template approach in PHASE-02.
- `research/2026-04-08_integration-trisk-model-existing.md` — establishes that the PACTA+TRISK methodology is explicitly designed to inform "portfolio action: exposure reduction, engagement prioritization, sector limits." This is the justification framing reused in the disclosure pack's Risk Management section.
- `research/2026-05-22_decision263-vietnam-ghg.md` — source for the SBV/Decision 263 regulatory framing and the Vietnamese GHG-disclosure obligations that the disclosure pack must speak to (anchors the "what do I file with SBV" narrative).

## Assumptions and Constraints
- **ASM-001:** All inputs already exist in the committed snapshot. The engagement/disclosure layer reads `dashboard/data/trisk/<sector>/` and `synthesis_output/vietnam/` CSVs; no model re-run is required to produce a deliverable.
- **ASM-002:** The join key between PACTA and TRISK borrower tables is the company name column (`name_abcd` per the research brief). PHASE-01 must verify the exact column names in the current CSVs before relying on them (TRISK currently covers power, cement, steel; automotive has PACTA alignment but no TRISK score).
- **CON-001:** No new R or Python package dependencies beyond what the repo already uses (`dplyr`, `readr`, `ggplot2`, `base64enc`, `stringr`; Python: `pandas`, `streamlit`). PDF is produced by browser print-to-PDF from self-contained HTML, consistent with the BIDV report plan — not by a new PDF library. (See Grill Me Q-001.)
- **CON-002:** Generated engagement letters and disclosure packs are the only artifacts in this layer that could leave the operator's machine. They MUST carry a synthetic-data watermark and an explicit "illustrative — requires human and legal review before any external use" disclaimer, and the dashboard page that produces them MUST be operator-gated (env flag), mirroring `BYOL_INTAKE`.
- **CON-003:** Generated artifacts must not be committed to git (same privacy posture as `intake/output/`). Output directories (`output/engagement_letters/`, `output/disclosure/`) must be git-ignored except for a `.gitkeep` and the templates.
- **DEC-001:** The HTML-generation pattern is fixed: raw HTML string assembly + inline CSS + base64 PNGs + regex `md_to_html()`, copied from `scripts/generate_bidv_report.R`. No Quarto/RMarkdown (consistent with the repo's existing rejected-alternative in the BIDV report plan).
- **DEC-002:** Composite engagement score weighting is 50/50 alignment-gap vs TRISK-priority, exposed as a script parameter and a dashboard slider labeled "illustrative — adjust to your institution's risk appetite" (from research Idea 3).

## Phase Summary
| Phase | Goal | Dependencies | Primary outputs |
|---|---|---|---|
| PHASE-01 | Build the composite engagement scoring backbone | None | `scripts/engagement_scoring.R`, `output/engagement/engagement_priority.csv` |
| PHASE-02 | Engagement letter generator + editable templates | PHASE-01 | `scripts/generate_engagement_letters.R`, `templates/engagement/`, per-borrower HTML letters |
| PHASE-03 | Disclosure pack generator (TCFD/ISSB) + templates | PHASE-01 | `scripts/generate_disclosure_pack.R`, `templates/disclosure/`, `output/disclosure/disclosure_pack.html` |
| PHASE-04 | Operator-gated dashboard Outputs page | PHASE-02, PHASE-03 | `dashboard/pages/7_Outputs.py`, `dashboard/lib/outputs.py` |
| PHASE-05 | Verification, docs, packaging, phase report | PHASE-01..04 | `docs/outputs_layer.md`, `.gitignore` update, phase report |

## Detailed Phases

### PHASE-01 - Engagement Scoring Backbone
**Goal**
Produce one canonical, data-driven priority table that both downstream generators (letters, disclosure pack) consume, so borrower numbers are computed once and never hardcoded.

**Tasks**
- [ ] TASK-01-01: Inspect the real column names and join keys in `synthesis_output/vietnam/04_vn_ms_company.csv`, `synthesis_output/vietnam/06_sda_alignment_2030.csv` (cement/steel), and `dashboard/data/trisk/power/top_borrowers_alignment_trisk.csv` (plus cement/steel equivalents). Record the confirmed schema in a header comment.
- [ ] TASK-01-02: Create `scripts/engagement_scoring.R` that loads PACTA company alignment (market-share gap for power/automotive; SDA emission-intensity gap for cement/steel) and TRISK borrower results (NPV change, PD change, priority score) for all available sectors.
- [ ] TASK-01-03: Join on the confirmed company-name key; normalize alignment gap and TRISK priority score to [0,1]; compute `composite_score = w_align * norm_align_gap + w_trisk * norm_trisk_priority` with `w_align = w_trisk = 0.5` as default parameters.
- [ ] TASK-01-04: For borrowers with PACTA alignment but no TRISK coverage (e.g. automotive), set TRISK fields to `NA` and flag `trisk_status = "N/A — sector not in TRISK pilot"`; compute the composite from the alignment component only and mark `composite_partial = TRUE`.
- [ ] TASK-01-05: Write `output/engagement/engagement_priority.csv` with columns: `name_abcd`, `sector`, `exposure_vnd`, `alignment_gap`, `npv_change`, `pd_change`, `trisk_priority_score`, `trisk_status`, `composite_score`, `composite_partial`, sorted descending by `composite_score`.
- [ ] TASK-01-06: Add a console summary (top-10 borrowers + count by sector + coverage caveat) on run.

**Files / Surfaces**
- `scripts/engagement_scoring.R` - New: the scoring backbone.
- `scripts/sector_prioritization.R` - Read: mirror its normalization/ranking idioms and CSV-writing style.
- `synthesis_output/vietnam/04_vn_ms_company.csv`, `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv` - Read: PACTA alignment inputs.
- `dashboard/data/trisk/power|cement|steel/top_borrowers_alignment_trisk.csv`, `npv_results_latest.csv`, `pd_results_latest.csv` - Read: TRISK inputs.

**Dependencies**
- None.

**Exit Criteria**
- [ ] `Rscript scripts/engagement_scoring.R` exits 0 and writes `output/engagement/engagement_priority.csv`.
- [ ] Every numeric field is sourced from input CSVs (no literals); non-power-pilot sectors are flagged, not dropped.
- [ ] Top-10 ordering is reproducible across runs.

**Phase Risks**
- **RISK-01-01:** Join key mismatch (diacritics / name variants between PACTA and TRISK tables) drops borrowers silently. Mitigation: TASK-01-01 verifies keys first; log any unmatched names and emit a `unmatched_names.csv` rather than dropping silently.

### PHASE-02 - Engagement Letter Generator
**Goal**
Generate a one-page, bilingual (Vietnamese/English) engagement letter per top-N borrower, with all gap/stress figures rendered from the PHASE-01 data row, using an editable external template.

**Tasks**
- [ ] TASK-02-01: Create `templates/engagement/letter_template.html` — a single-borrower letter skeleton with placeholder tokens (`{{borrower}}`, `{{sector}}`, `{{alignment_gap}}`, `{{npv_change}}`, `{{pd_change}}`, `{{scenario_name}}`, `{{engagement_actions}}`, `{{date}}`) and inline CSS. Bilingual layout: Vietnamese block above English block per section.
- [ ] TASK-02-02: Create `templates/engagement/engagement_prompt_templates.csv` — one row per sector with a parameterized prompt and three suggested engagement actions (data request, transition-plan ask, covenant-tightening trigger), so the bank can edit voice/framing without touching code.
- [ ] TASK-02-03: Create `scripts/generate_engagement_letters.R` that: reads `output/engagement/engagement_priority.csv`, takes a `top_n` parameter (default 10), loads the template + prompt CSV, substitutes tokens per borrower, and writes `output/engagement_letters/<borrower_slug>/letter.html` (self-contained).
- [ ] TASK-02-04: Stamp every letter with a synthetic-data watermark band and a footer disclaimer: "Illustrative — based on synthetic portfolio data. Requires human and legal review before any external use." Reuse the disclaimer language style from `dashboard/pages/6_Intake_Wizard.py`.
- [ ] TASK-02-05: Write an index `output/engagement_letters/index.html` linking all generated letters, and a manifest `output/engagement_letters/manifest.csv` (borrower, sector, composite_score, file path, generated_at).
- [ ] TASK-02-06: Pre-flight check: if `engagement_priority.csv` is missing, instruct the user to run PHASE-01 first and exit non-zero.

**Files / Surfaces**
- `scripts/generate_engagement_letters.R` - New: the letter generator.
- `templates/engagement/letter_template.html`, `templates/engagement/engagement_prompt_templates.csv` - New: editable templates.
- `scripts/generate_bidv_report.R` - Read: copy `img_to_base64()`, token-substitution, and HTML-assembly idioms.
- `output/engagement_letters/` - New (git-ignored): generated artifacts.

**Dependencies**
- PHASE-01 (`engagement_priority.csv`).

**Exit Criteria**
- [ ] `Rscript scripts/generate_engagement_letters.R` produces N self-contained HTML letters + an index + manifest.
- [ ] Opening a letter in a browser shows correct, data-sourced figures (spot-check 2 borrowers against the CSV).
- [ ] Every letter shows the watermark and the human/legal-review disclaimer.
- [ ] Editing a row in `engagement_prompt_templates.csv` changes the rendered prompt on re-run.

**Phase Risks**
- **RISK-02-01:** Token left unsubstituted (e.g. a sector lacking a prompt row) ships a raw `{{token}}` to a client-facing letter. Mitigation: after substitution, scan output for residual `{{` patterns and fail the run with the offending borrower/token listed.

### PHASE-03 - Disclosure Pack Generator
**Goal**
Produce a single self-contained HTML board/regulator disclosure pack structured on the four TCFD pillars with ISSB IFRS S2 cross-references and a Decision 263 / SBV note, suitable for browser print-to-PDF.

**Tasks**
- [ ] TASK-03-01: Create `templates/disclosure/disclosure_sections.md` — the editable narrative skeleton organized as: Governance, Strategy, Risk Management, Metrics & Targets (TCFD pillars), each annotated with the matching ISSB IFRS S2 disclosure topic and, where relevant, the Decision 263 obligation it satisfies.
- [ ] TASK-03-02: Create `scripts/generate_disclosure_pack.R` that assembles: (1) executive summary; (2) portfolio alignment vs PDP8 / NDC / NZE (embed `synthesis_output/vietnam/12_vn_alignment_overview.png`); (3) top-10 transition-risk borrowers from `engagement_priority.csv` (with an `anonymize` flag → "Borrower A/B/C"); (4) the four TCFD-pillar narrative from the template; (5) methodology appendix condensed from `docs/PACTA_Beginner_Guide.md` and `docs/TRISK_Demo_Assumptions.md`.
- [ ] TASK-03-03: Reuse the `md_to_html()` + `img_to_base64()` helpers and CSS scheme from `scripts/generate_bidv_report.R` (Allotrope blue headers, synthetic-data disclaimer box).
- [ ] TASK-03-04: Add an `anonymize` parameter (default `FALSE`); when `TRUE`, replace borrower names with stable pseudonyms in the borrower table and any embedded narrative.
- [ ] TASK-03-05: Write `output/disclosure/disclosure_pack.html` (self-contained, target < 2 MB) plus a footer confidentiality + synthetic-data notice.
- [ ] TASK-03-06: Pre-flight file-existence check (same pattern as `generate_bidv_report.R`); insert "[section pending]" placeholders for any missing input rather than crashing.

**Files / Surfaces**
- `scripts/generate_disclosure_pack.R` - New: the disclosure-pack generator.
- `templates/disclosure/disclosure_sections.md` - New: editable TCFD/ISSB narrative.
- `synthesis_output/vietnam/12_vn_alignment_overview.png`, `13_vn_coal_stranded_risk.png` - Read: embed as base64.
- `docs/PACTA_Beginner_Guide.md`, `docs/TRISK_Demo_Assumptions.md`, `docs/bidv_decision263_mapping.md` - Read: appendix + SBV framing.
- `scripts/generate_bidv_report.R` - Read: helpers + CSS + assembly pattern.
- `output/disclosure/` - New (git-ignored): generated artifact.

**Dependencies**
- PHASE-01 (`engagement_priority.csv`).

**Exit Criteria**
- [ ] `Rscript scripts/generate_disclosure_pack.R` produces `output/disclosure/disclosure_pack.html` under 2 MB, all four TCFD pillars present.
- [ ] `anonymize=TRUE` removes all real borrower names from the rendered output (grep confirms).
- [ ] Browser print-to-PDF yields a readable document with sensible page breaks.
- [ ] Synthetic-data disclaimer is present in every data-driven section.

**Phase Risks**
- **RISK-03-01:** Anonymization misses a name embedded in narrative prose. Mitigation: anonymization operates on a single borrower-name list applied with whole-word replacement across all assembled HTML before write; exit criteria includes a grep verification.

### PHASE-04 - Operator-Gated Outputs Page
**Goal**
Add a dashboard page that lets a logged-in operator generate, preview, and download engagement letters and the disclosure pack — gated so it never appears on the public deployment.

**Tasks**
- [ ] TASK-04-01: Create `dashboard/lib/outputs.py` mirroring `dashboard/lib/intake.py`: an `ENV_FLAG = "OUTPUTS_LAYER"`, an `is_outputs_enabled()` helper, and thin wrappers that invoke the two R generators as subprocesses (reuse the Rscript-resolution pattern from `intake.py`).
- [ ] TASK-04-02: Create `dashboard/pages/7_Outputs.py` that: gates on `is_outputs_enabled()` (else `st.info` + `st.stop()`); renders the operator-mode banner + synthetic-data pill from `branding.py`; requires an explicit "I confirm these are illustrative, synthetic-data artifacts requiring human review" checkbox before any generate button is enabled.
- [ ] TASK-04-03: Add controls: a `top_n` number input and composite-weight slider (alignment vs TRISK) for letters; an `anonymize` toggle for the disclosure pack; "Generate engagement letters" and "Generate disclosure pack" buttons.
- [ ] TASK-04-04: After generation, list produced artifacts from the manifests with `st.download_button`s; show the disclosure-pack HTML inline in an expander preview.
- [ ] TASK-04-05: Apply `footer_note()` and ensure no raw borrower data is rendered unless the operator has confirmed (consistent with intake privacy posture).

**Files / Surfaces**
- `dashboard/pages/7_Outputs.py` - New: operator page (numbered 7 because 6_Intake_Wizard.py exists).
- `dashboard/lib/outputs.py` - New: gating + subprocess wrappers.
- `dashboard/lib/intake.py`, `dashboard/pages/6_Intake_Wizard.py` - Read: gating, subprocess, and watermark patterns to mirror.
- `dashboard/lib/branding.py` - Read: `apply_page_frame`, `footer_note`, synthetic pill.

**Dependencies**
- PHASE-02 and PHASE-03 (the R generators must exist).

**Exit Criteria**
- [ ] With `OUTPUTS_LAYER` unset, the page shows the disabled message and does not run any generator.
- [ ] With `OUTPUTS_LAYER=1`, the confirmation checkbox gates the generate buttons; clicking generate runs the R script and surfaces download buttons.
- [ ] The public deployment (flag unset) never exposes generation controls.

**Phase Risks**
- **RISK-04-01:** Subprocess R invocation fails silently on the operator machine (wrong Rscript path). Mitigation: reuse `intake.py`'s Rscript resolution + surface stderr in an `st.error` block on non-zero exit.

### PHASE-05 - Verification, Docs, and Packaging
**Goal**
Prove the layer works end-to-end, document it, ensure artifacts stay out of git, and write the phase report.

**Tasks**
- [ ] TASK-05-01: Add `output/engagement_letters/` and `output/disclosure/` to `.gitignore` (keep `templates/` tracked; add `.gitkeep` to output dirs). Verify generated artifacts are untracked via `git status`.
- [ ] TASK-05-02: Run the full chain: `engagement_scoring.R` → `generate_engagement_letters.R` → `generate_disclosure_pack.R`; confirm all exit 0 and produce expected files.
- [ ] TASK-05-03: Write `docs/outputs_layer.md` — what the layer is, how to run each script, the env flag for the dashboard page, the privacy/disclaimer posture, and how the bank edits templates without code.
- [ ] TASK-05-04: Spot-check 2 letters and the disclosure pack in a browser; verify figures match `engagement_priority.csv`, watermarks/disclaimers present, anonymization works.
- [ ] TASK-05-05: Write a phase report under `reports/` summarizing what was built and verification evidence (mirroring prior `PHASE-05` report commits).

**Files / Surfaces**
- `.gitignore` - Edit: ignore generated outputs.
- `docs/outputs_layer.md` - New: operator + bank-facing documentation.
- `reports/` - New phase report.

**Dependencies**
- PHASE-01..04.

**Exit Criteria**
- [ ] `git status` shows no generated letters/packs staged; templates and docs are tracked.
- [ ] Full chain runs clean from a fresh `output/` directory.
- [ ] `docs/outputs_layer.md` lets a new operator run the layer without this conversation.

**Phase Risks**
- **RISK-05-01:** A generated artifact gets committed by accident (privacy breach in a real engagement). Mitigation: `.gitignore` first (TASK-05-01) before any generation run; exit criteria explicitly checks `git status`.

## Verification Strategy
- **TEST-001:** `Rscript scripts/engagement_scoring.R` exits 0 and `output/engagement/engagement_priority.csv` has the documented columns with no `NA` composite for covered sectors.
- **TEST-002:** `Rscript scripts/generate_engagement_letters.R` produces N letters; automated grep over outputs finds zero residual `{{` tokens.
- **TEST-003:** `Rscript scripts/generate_disclosure_pack.R` produces an HTML < 2 MB; with `anonymize=TRUE`, grep finds zero real borrower names.
- **MANUAL-001:** Open 2 letters + the disclosure pack in a browser; verify figures match the CSV, watermarks and human/legal-review disclaimers are present, print-to-PDF is clean.
- **MANUAL-002:** Load the dashboard with `OUTPUTS_LAYER` unset (page disabled) and `=1` (gated by confirmation checkbox); confirm public deployment never exposes generation.
- **OBS-001:** `git status` after a full run shows only templates/docs/scripts tracked — no generated artifacts.

## Risks and Alternatives
- **RISK-001:** Client-facing letters with wrong figures are reputationally damaging. Mitigation (cross-phase): all numbers render from the PHASE-01 data row, never hardcoded; residual-token scan; mandatory human/legal-review disclaimer on every artifact.
- **RISK-002:** Operator generation surface accidentally reaches the public deployment. Mitigation: env-flag gating reused from the proven `BYOL_INTAKE` pattern + explicit confirmation checkbox.
- **ALT-001:** Native DOCX/PDF via the `officer`/`rmarkdown` R packages (as the original Idea 3 text suggested). Not chosen for v1: adds dependencies and Windows PDF-toolchain risk, against CON-001. Self-contained HTML + browser print-to-PDF matches the repo's existing deliverable pattern; DOCX can be a fast follow-up (see Q-001).
- **ALT-002:** Embed engagement output directly in the existing TRISK page rather than a new page. Not chosen: the output layer is operator-gated and write-producing, which is a different trust boundary than the read-only public TRISK view.

## Grill Me
1. **Q-001:** Output formats for engagement letters — self-contained HTML (+ browser print-to-PDF) only, or also native DOCX/PDF via `officer`?
   - **Recommended default:** HTML + browser print-to-PDF only for v1 (no new deps, matches repo pattern). Defer DOCX to a follow-up.
   - **Why this matters:** DOCX/`officer` adds a dependency and Windows rendering risk, expanding PHASE-02 scope.
   - **If answered differently:** Add an `officer`-based DOCX renderer task to PHASE-02 and a dependency note to CON-001.

2. **Q-002:** Bilingual posture — full Vietnamese/English side-by-side for both letters and disclosure pack, or bilingual letters but English-with-Vietnamese-key-terms for the disclosure pack?
   - **Recommended default:** Bilingual letters (borrower-facing); English-with-Vietnamese-terminology disclosure pack (matches the BIDV report convention).
   - **Why this matters:** Full bilingual disclosure prose roughly doubles the template/translation effort in PHASE-03.
   - **If answered differently:** Expand `templates/disclosure/disclosure_sections.md` to dual-language and add a translation-review task.

3. **Q-003:** Disclosure-pack framing — TCFD four-pillar primary with ISSB IFRS S2 cross-references (recommended), pure ISSB IFRS S2, or SBV/Decision 263-native structure?
   - **Recommended default:** TCFD pillars as the skeleton + ISSB cross-refs + a Decision 263 mapping note.
   - **Why this matters:** Determines the section structure and template headings in PHASE-03; a domain reviewer should confirm regulatory wording.
   - **If answered differently:** Restructure `disclosure_sections.md` headings and the PHASE-03 assembly order.

4. **Q-004:** Composite engagement-score weighting — fixed 50/50 alignment vs TRISK, or operator-adjustable (slider) as the default?
   - **Recommended default:** 50/50 default, exposed as a script parameter and a dashboard slider labeled "illustrative."
   - **Why this matters:** Affects the ordering of which borrowers get letters; a fixed weight is simpler but less defensible to a bank.
   - **If answered differently:** If fixed-only, drop the PHASE-04 slider; if more factors (e.g. exposure), extend the PHASE-01 formula.

5. **Q-005:** Anonymization default for the disclosure pack — off (real names, internal board use) or on (pseudonyms, shareable)?
   - **Recommended default:** Off by default (internal board pack), with an operator toggle to anonymize for wider sharing.
   - **Why this matters:** Sets the safe default for an artifact that may be forwarded externally.
   - **If answered differently:** Flip the default in PHASE-03 TASK-03-04 and the PHASE-04 toggle.

6. **Q-006:** Engagement-letter recipient scope — top-N by composite score (default N=10), all covered borrowers, or an operator-selected subset?
   - **Recommended default:** Top-N (N=10) by composite score, with N adjustable on the dashboard.
   - **Why this matters:** Drives how many letters are generated and the PHASE-04 controls.
   - **If answered differently:** Add a borrower multiselect to PHASE-04 and a filtered-list path to PHASE-02.

## Suggested Next Step
Answer the Grill Me questions (especially Q-001 output format and Q-003 disclosure framing), fold the answers into the affected phases, then begin PHASE-01 — the scoring backbone is dependency-free and unblocks both generators.

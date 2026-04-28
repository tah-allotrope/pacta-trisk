# Future Planning Ideas: PACTA-TRISK Vietnam

**Date:** 2026-04-28
**Author:** Claude Sonnet 4.6
**Context:** This file captures three substantive, actionable planning ideas for the next phase of the pacta-trisk Vietnam project. They are grounded in the current state of the codebase: a completed Streamlit dashboard (Phases 01–05), a running TRISK power-sector pilot with sensitivity analysis, a fully executed Vietnam PACTA baseline, and the pending Phase 06 Streamlit Community Cloud deployment.

---

## Idea 1: Expand TRISK from Power-Only to a Multi-Sector Portfolio Stress Test

### Problem it solves
The current TRISK pilot (`scripts/trisk_power_demo.R`) covers only the power sector. The Vietnam PACTA baseline already surfaces misalignment in four sectors — power, automotive, cement, and steel — and the dashboard's TRISK tab presents only power-sector NPV/PD results. A bank client reviewing the dashboard will correctly ask: "What about the cement and steel borrowers? They had the worst alignment gaps (+76% and +37% above target)." Without multi-sector TRISK coverage, the stress-test narrative is incomplete precisely where the alignment risk is highest.

### What to build
1. **Extend `scripts/trisk_prepare_inputs.R`** to generate TRISK-formatted `assets`, `financial_features`, and `scenarios` tables for cement and steel sectors using `data/vietnam_abcd.csv` and `data/vietnam_scenario_co2.csv`. Map SDA emission-intensity pathways to TRISK's `scenarios` contract (CO2 intensity as the shock variable rather than market-share production targets).
2. **Add `scripts/trisk_cement_steel_demo.R`** mirroring the structure of `trisk_power_demo.R`: base run + one-at-a-time sensitivities over `shock_year`, `discount_rate`, and `market_passthrough`. Key borrowers to cover: VICEM (cement), Hoa Phat Group (steel), and their MCB loanbook counterparts.
3. **Update `dashboard/data/trisk/`** snapshot to include the new sector outputs. Update `scripts/refresh_dashboard_data.R` to copy them.
4. **Update `dashboard/pages/2_TRISK_Risk.py`** with a sector selector so users can switch between Power, Cement, and Steel stress-test views without leaving the page.

### Why this is the highest-leverage next step
- The cement and steel gaps are the largest in the portfolio (SDA alignment off by +76% and +37%) but currently have zero TRISK coverage. This is the most visible gap in the bank demo narrative.
- The data infrastructure is already in place: `data/vietnam_scenario_co2.csv` encodes the CO2 trajectories; `data/vietnam_abcd.csv` has VICEM and Hoa Phat production data; the loanbook maps to them.
- The TRISK package's SDA-compatible path uses the same `run_trisk()` interface with emission-intensity inputs rather than production-capacity inputs — no new package dependencies.

### Key risks and mitigations
- **SDA-to-TRISK schema mismatch:** The `trisk.model` package's `scenarios` table expects commodity price paths, not emission-intensity paths directly. Mitigation: represent CO2 intensity as an implicit carbon-price shock (price rises until borrowers must hit the SDA target) — same approach used in Baer et al.'s cement proof-of-concept.
- **Thin data coverage:** Steel match coverage in the demo is ~4%, making stress-test outputs unreliable at company level. Mitigation: aggregate steel to sector level for the dashboard view and flag the coverage caveat explicitly, as already done for alignment.

---

## Idea 2: Build a Quarterly Pipeline Refresh Automation with a Reproducibility Report

### Problem it solves
The current dashboard consumes a static snapshot (`dashboard/data/`) that was hand-copied once. The `scripts/refresh_dashboard_data.R` script exists to republish the snapshot, but it must be run manually, there is no audit trail of when data was last refreshed, and nothing catches the case where the underlying pipeline outputs have changed but the dashboard data has not been updated. As the project matures and is shown to more bank clients, data staleness becomes a credibility risk — a client could reasonably ask "when was this last run?"

### What to build
1. **Add a `scripts/pipeline_refresh.R` orchestrator** that runs the full chain in dependency order: `data/generate_vietnam_data.R` → `scripts/pacta_vietnam_scenario.R` → `scripts/trisk_prepare_inputs.R` → `scripts/trisk_power_demo.R` (and the proposed multi-sector scripts from Idea 1) → `scripts/refresh_dashboard_data.R`. Accept a `--dry-run` flag that checks whether source outputs are newer than the dashboard snapshot without re-executing.
2. **Add a `reports/pipeline_manifest.json`** written by the orchestrator on each successful run. Fields: `run_timestamp`, `git_sha`, `r_version`, `pacta_match_rows`, `trisk_company_count`, `dashboard_data_size_mb`. The dashboard landing page reads this file and displays "Last updated: {date}" with a link to the manifest.
3. **Add a `reports/reproducibility_report.Rmd`** (R Markdown) that renders on each refresh and captures: input file checksums, match coverage by sector, key alignment gaps, TRISK top-5 borrowers by priority score, and a "changed since last run" diff table comparing the manifest to the previous run's values. Export as `reports/reproducibility_report.html`.
4. **Add a GitHub Actions workflow (`.github/workflows/refresh.yml`)** that can be triggered manually (`workflow_dispatch`) or on a schedule (e.g., quarterly). It runs the orchestrator, commits updated `dashboard/data/` and the reproducibility report, and pushes — triggering an automatic Streamlit Cloud redeploy via GitHub push.

### Why this matters for the bank demo context
- A "last updated" badge on the landing page is a concrete signal of methodological rigor to bank clients who know PACTA runs need to be refreshed annually as ABCD data and scenarios are updated.
- The reproducibility report creates an audit artifact that makes the project defensible if a client questions a number — you can show exactly which pipeline run produced which output.
- The orchestrator also unblocks the multi-sector TRISK expansion (Idea 1) by providing a single entry point to re-run everything in order rather than remembering which scripts depend on which.

### Key risks and mitigations
- **Long R runtime:** The full PACTA + TRISK pipeline can take 30–60 minutes on Windows. Mitigation: use GitHub Actions with a step timeout, and cache the R library across runs using `actions/cache` keyed on `renv.lock` or the package version list.
- **GitHub Actions free-tier limits:** 2,000 minutes/month for public repos. A quarterly run of ~60 minutes consumes 240 minutes/quarter — well within limits. Mitigation: keep the workflow `workflow_dispatch`-only initially; add the `schedule` trigger only after timing is confirmed.

---

## Idea 3: Add a "Bank Engagement Action Layer" to the Dashboard — Priority Borrower Cards with Engagement Prompts

### Problem it solves
The current dashboard shows alignment gaps and stress-test scores, but it stops at the diagnostic layer. A bank credit officer or sustainability head reviewing the dashboard will immediately ask: "Given these results, which borrowers should we engage first, and what do we ask them?" Today there is no answer in the tool — the officer must mentally synthesize the PACTA tab (alignment gaps by borrower) and the TRISK tab (NPV/PD stress by borrower) into a prioritized engagement list, then draft their own talking points. This is the gap between an analytical demo and a working bank tool.

### What to build
1. **Add a `scripts/engagement_scoring.R`** that joins PACTA company-level alignment results (`dashboard/data/pacta/04_vn_ms_company.csv`) with TRISK priority scores (`dashboard/data/trisk/top_borrowers_alignment_trisk.csv`) on `name_abcd`. Compute a composite engagement priority score as a weighted sum: `0.5 × normalized_alignment_gap + 0.5 × normalized_trisk_priority_score`. Export as `dashboard/data/engagement/engagement_priority.csv`.
2. **Add a `dashboard/pages/5_Engagement.py`** page with:
   - A ranked table of the top 10 priority borrowers, showing alignment gap, TRISK priority score, composite score, and sector.
   - A borrower detail expander for each row that shows: sector, technology mix, alignment verdict (from PACTA), NPV change and PD change under the stress scenario (from TRISK), and a **templated engagement prompt** (e.g., "Mekong Commercial Bank is engaging [borrower] regarding its [sector] transition plan. Under the Vietnam NDC scenario, the bank's analysis suggests [X]% misalignment in [technology]. Under a disorderly transition, the bank models [Y]% NPV deterioration. The bank requests [borrower] provide a forward capex plan for renewable capacity by [date].").
   - A "Download engagement pack" button that exports the full priority list + prompts as a CSV and a formatted HTML briefing document.
3. **Add a `data/engagement_prompt_templates.csv`** with one row per sector, containing a sector-specific prompt template parameterized by `{borrower}`, `{sector}`, `{alignment_gap}`, `{npv_change}`, `{scenario_name}`. This separates the bank's voice/framing from the code.

### Why this is the right next narrative step
- The PACTA + TRISK methodology is explicitly designed to inform "portfolio action: exposure reduction, engagement prioritization, sector limits" (as stated in `research/2026-04-08_integration-trisk-model-existing.md`). The engagement layer is the most visible missing link between analysis and action.
- It does not require new model runs — it only synthesizes outputs already in the `dashboard/data/` snapshot. The implementation risk is low; the storytelling payoff for a bank client demo is high.
- Prompt templates stored in a CSV mean the bank can customize the language for their own letterhead and regulatory context without touching Python code — which is a realistic requirement for any institution that routes external communications through compliance review.

### Key risks and mitigations
- **Composite score subjectivity:** The 50/50 weighting of alignment gap vs. TRISK priority is arbitrary. Mitigation: expose the weight as a slider on the dashboard page, clearly labeled "For illustration — adjust weights to reflect your institution's risk appetite."
- **Prompt template accuracy:** Engagement prompts that misstate a gap percentage would be damaging in a real client context. Mitigation: the page must render prompt values directly from the data row (no hardcoded numbers), and include a visible disclaimer that prompts are templates for illustrative purposes and require human review before any real engagement.
- **Automotive borrowers missing from TRISK:** The current TRISK pilot covers only power sector, so automotive borrowers (VinFast, THACO) will have alignment gaps but no TRISK scores. Mitigation: in the engagement table, show "TRISK N/A — power pilot only" for non-power borrowers until Idea 1 is implemented.

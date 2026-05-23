# BIDV Implementation Roadmap: PACTA + TRISK Adoption

> **Audience:** BIDV Senior Risk Management, ESG Leadership, GTB Advisory
> **Date:** 2026-05-22
> **Status:** Recommended structure — to be customized during joint planning with BIDV
> **Horizon:** 24 weeks (6 months) for initial adoption, then quarterly monitoring

---

## For the Executive

This roadmap outlines a **5-phase adoption pathway** for BIDV to operationalize portfolio alignment assessment and transition stress testing for Decision 263 sectors (thermal power, steel, cement). It assumes BIDV already has a PCAF financed emissions baseline (Output 2.1) and that Decision 263 clients are collecting emissions data under the 2025 reporting mandate.

**Recommended reading:** Sections 1-5 (phases) and Section 6 (resource summary). Sections 7-8 provide integration guidance for risk and compliance teams.

---

## Phase 1: Data Preparation (Weeks 1–6)

### Objective
Extract, normalize, and validate BIDV's loanbook data for Decision 263 sectors to produce a pipeline-ready dataset.

### Activities

1. **Extract Decision 263 portfolio exposure**
   - Query BIDV's credit system for all outstanding exposures to thermal power, steel, and cement borrowers
   - Include: counterparty legal name, outstanding balance (VND), credit limit, VSIC/ISIC sector code, parent company name, tax ID, LEI (if available)
   - Target: complete census of Decision 263 clients (estimated 20+ entities based on 2025 reporting mandate)

2. **Collect emissions data from Decision 263 clients**
   - Leverage the 2025 GHG inventory reporting requirement — clients are legally obligated to have this data
   - Request: Scope 1 emissions (tonnes CO2e), production volumes (MWh for power, tonnes for cement/steel), technology mix (coal/gas for power; BF-BOF/EAF for steel; integrated/kiln type for cement)
   - Track: which clients have submitted data, which require follow-up, which are non-responsive

3. **Map VSIC codes to PACTA sectors**
   - Apply the VSIC→ISIC→PACTA mapping defined in the intake schema (`intake/SCHEMA.md`)
   - Strip VSIC letter prefixes (e.g., `D3511` → `3511`), zero-pad to 4 digits
   - Classify borrowers into: `power` (coalcap, gascap), `cement` (integrated facility), `steel` (open hearth, electric arc), or "not in scope"
   - Flag any borrowers with ambiguous or missing sector classifications for manual review

4. **Validate data quality**
   - Run the intake validation script to check: required fields present, exposure values non-negative, sector codes mappable, parent company names resolved
   - Produce a validation report listing errors (blocking) and warnings (advisory)
   - Resolve errors before proceeding to Phase 2

### Resource Requirements

| Role | Time | Responsibility |
|------|------|----------------|
| Data analyst (BIDV) | Part-time (~10 hrs/week) | Data extraction, VSIC mapping, validation |
| ESG team coordinator | Part-time (~5 hrs/week) | Client outreach for emissions data collection |
| Relationship managers | As needed | Follow-up with non-responsive clients |
| GTB advisory support | Template + validation tools | Provide intake schema, validation script, mapping tables |

### Deliverable
- `normalized_loanbook.csv` — 13-column pipeline-ready dataset conforming to the intake output schema
- `validation_errors.csv` — list of data quality issues (target: zero blocking errors)
- Data completeness report: percentage of Decision 263 clients with emissions data received

### Decision 263 Cross-Reference
- Supports: GHG inventory data collection mandate (2025 reporting year)
- Enables: downstream alignment and stress-test analysis on actual BIDV portfolio

---

## Phase 2: Baseline Establishment (Weeks 5–10)

### Objective
Run PACTA alignment analysis on BIDV's Decision 263 portfolio to produce sector-level alignment gaps against Vietnam-relevant transition pathways.

### Activities

1. **Set up the analytical environment**
   - Install R (v4.4+) and required packages (`r2dii.data`, `r2dii.match`, `r2dii.analysis`, `r2dii.plot`)
   - Configure scenario data: PDP8 (Vietnam Power Development Plan 8), Vietnam NDC, and IEA NZE pathways
   - Validate that the normalized loanbook from Phase 1 loads correctly

2. **Run PACTA matching**
   - Fuzzy-match BIDV borrowers to the ABCD (Asset-Level Company Database) using company names
   - Set minimum match score ≥ 0.8; flag matches < 1.0 for manual review
   - Check for sector mismatches (borrower classified as "power" but matched to "steel" asset)
   - Produce match coverage report: percentage of portfolio exposure linked to physical assets

3. **Produce sector-level alignment analysis**
   - **Power:** Market share analysis — compare BIDV's portfolio technology mix (coal, gas, hydro, solar, wind) against PDP8 and NZE targets for 2030 and 2040
   - **Cement:** SDA (Sectoral Decarbonization Approach) — compare emission intensity (tonnes CO2e/tonne cement) against Vietnam NDC and IEA NZE pathways
   - **Steel:** SDA — compare emission intensity (tonnes CO2e/tonne steel) against sector-specific decarbonization targets

4. **Cross-reference with PCAF baseline**
   - Combine PACTA alignment gaps with PCAF financed emissions (Output 2.1) to create a unified view:
     - Total financed emissions by sector (PCAF)
     - Alignment trajectory: is the portfolio moving toward or away from targets? (PACTA)
   - Identify sectors where emissions are high AND misaligned (priority for engagement)

### Resource Requirements

| Role | Time | Responsibility |
|------|------|----------------|
| Quantitative analyst (BIDV or GTB) | Full-time during run (~2 weeks) | Pipeline execution, result interpretation |
| R environment setup | 1-2 days | IT support or GTB technical team |
| ESG team review | 1 week | Validate alignment results against internal knowledge |

### Deliverable
- PACTA alignment report for BIDV's Decision 263 portfolio (HTML, self-contained)
- Sector alignment gap tables: percentage point gaps vs. targets for each sector and scenario
- Match coverage report: which borrowers were successfully linked to asset-level data
- Combined PCAF + PACTA view: emissions + alignment by sector

### Decision 263 Cross-Reference
- Supports: sector-specific emission quota assessment (comparing portfolio exposure to quota-aligned pathways)
- Provides: evidence base for emission reduction plan requirements

---

## Phase 3: Risk Assessment (Weeks 9–16)

### Objective
Run TRISK transition stress tests and sector prioritization to quantify financial impact and rank engagement priorities.

### Activities

1. **Run TRISK stress tests for Decision 263 borrowers**
   - Configure baseline scenario (e.g., PDP8-aligned transition) and stress scenario (e.g., NZE-accelerated transition)
   - Model borrower-level financial impact: NPV change (VND), probability of default (PD) change, and priority score
   - Cover all three sectors: power, cement, steel (using sector-appropriate TRISK configurations)
   - Produce borrower-level ranking: which borrowers face the highest transition stress under accelerated decarbonization

2. **Run sector prioritization module**
   - Combine three dimensions into a composite priority score for each sector:
     - **Alignment gap** (weight: 0.35): how far the sector is from its transition target
     - **Stress severity** (weight: 0.35): average NPV/PD impact across borrowers in the sector
     - **Portfolio exposure** (weight: 0.30): total VND exposure relative to total Decision 263 portfolio
   - Produce ranked sector list with composite scores and classification (Critical / High / Medium / Low)
   - Run sensitivity analysis: test how rankings change under different weight combinations

3. **Conduct sensitivity analysis**
   - Vary key TRISK parameters one-at-a-time:
     - Shock year (when transition policy takes effect)
     - Discount rate (cost of capital)
     - Market passthrough (ability to pass carbon costs to customers)
   - Identify which borrowers are most sensitive to parameter changes (ranking instability = higher uncertainty = higher risk)
   - Document which parameters drive the largest ranking shifts

4. **Synthesize findings**
   - Produce a combined risk assessment: sector priority ranking + borrower-level stress detail + sensitivity analysis
   - Identify "hot spots": borrowers that are highly stressed, highly exposed, AND sensitive to parameter assumptions
   - Prepare narrative for credit risk team: which borrowers warrant immediate attention

### Resource Requirements

| Role | Time | Responsibility |
|------|------|----------------|
| Quantitative analyst | Full-time during run (~3 weeks) | TRISK pipeline execution, sensitivity analysis |
| Risk team reviewer | 1-2 weeks | Validate stress-test methodology, review outputs |
| GTB advisory support | Pipeline execution + interpretation | Run TRISK scripts, produce prioritization outputs |

### Deliverable
- Sector prioritization ranking: composite scores and classification for power, cement, steel
- Borrower-level stress-test detail: NPV change, PD change, priority score for each Decision 263 borrower
- Sensitivity analysis report: parameter impact on borrower rankings
- Risk assessment narrative: "hot spot" identification and recommended engagement order

### Decision 263 Cross-Reference
- Supports: emission reduction plan development (quantified financial impact of transition scenarios)
- Provides: borrower-level evidence for targeted engagement and credit risk integration

---

## Phase 4: Action Planning (Weeks 15–20)

### Objective
Translate analytical findings into concrete borrower engagement actions and portfolio management strategies.

### Activities

1. **Prioritize borrower engagement**
   - Use sector ranking and individual stress scores to create an engagement priority list
   - Tier 1 (immediate): borrowers with Critical/High composite scores — engage within 30 days
   - Tier 2 (near-term): borrowers with Medium scores — engage within 90 days
   - Tier 3 (monitoring): borrowers with Low scores — include in quarterly monitoring

2. **Draft borrower engagement communications**
   - Prepare standardized engagement letters requesting:
     - Current transition plan (if any)
     - Capex commitments for emissions reduction
     - Emissions reduction timelines and milestones
     - Technology roadmap (e.g., coal-to-gas switching, renewable capacity additions for power)
   - Customize communications by sector: power borrowers receive technology-mix-specific requests; cement/steel borrowers receive emission-intensity-specific requests
   - Include a clear timeline for response (e.g., 60 days from letter date)

3. **Establish sector exposure management guidelines**
   - Based on alignment and stress results, recommend sector-level exposure limits or concentration thresholds
   - Example: if power sector composite score is "Critical," recommend no new coal power lending and a target to reduce coal exposure by X% within 3 years
   - Define "green/transition" lending criteria aligned with SBV green taxonomy
   - Set internal review triggers: when a borrower's stress score crosses a threshold, trigger credit review

4. **Integrate climate risk signals into credit review**
   - Work with BIDV's credit risk team to incorporate PACTA alignment scores and TRISK stress scores into the credit review process for Decision 263 borrowers
   - Define how alignment/stress scores affect: credit rating, pricing, collateral requirements, covenant design
   - Pilot integration with 3-5 Tier 1 borrowers before full rollout

### Resource Requirements

| Role | Time | Responsibility |
|------|------|----------------|
| Credit risk team | Ongoing during phase | Credit review integration, exposure limit setting |
| ESG team | Ongoing during phase | Engagement communication drafting, borrower coordination |
| Relationship managers | As needed | Direct borrower outreach and follow-up |
| GTB advisory support | Advisory | Engagement communication templates, exposure management framework |

### Deliverable
- Borrower engagement plan: tiered priority list with engagement timelines and communication templates
- Sector exposure management strategy: recommended limits, concentration thresholds, green lending criteria
- Credit review integration framework: how PACTA/TRISK scores feed into BIDV's credit decision process
- Pilot engagement results: responses from first 3-5 Tier 1 borrowers

### Decision 263 Cross-Reference
- Supports: emission reduction plan enforcement (engaging borrowers to develop and commit to reduction plans)
- Aligns with: MONRE's expectation that financial institutions support regulated entities in meeting quota obligations

---

## Phase 5: Monitoring and Reporting (Weeks 19–24, then Quarterly)

### Objective
Establish an ongoing monitoring cycle to track portfolio alignment progress, borrower engagement outcomes, and regulatory compliance.

### Activities

1. **Establish quarterly re-run schedule**
   - Re-run PACTA alignment analysis quarterly to track: changes in sector alignment gaps, new borrower matches, technology mix shifts
   - Re-run TRISK stress tests quarterly to track: changes in borrower stress scores, sensitivity to updated scenario assumptions
   - Automate the re-run pipeline where possible (scripted execution with standardized outputs)

2. **Track borrower engagement progress**
   - Monitor responses to engagement communications: which borrowers submitted transition plans, which did not respond
   - Track borrower-reported emissions data against baseline: are emissions decreasing, stable, or increasing?
   - Update borrower stress scores based on new information (e.g., announced capex for renewable capacity)

3. **Update Decision 263 compliance status**
   - Monitor MONRE implementing regulations: new quota levels, updated reporting requirements, enforcement actions
   - Update the analytical pipeline's scenario data if MONRE publishes revised quota pathways
   - Track which BIDV clients are compliant with 2025+ GHG inventory reporting requirements

4. **Prepare disclosure materials**
   - Use PACTA + TRISK outputs to prepare TCFD-aligned or ISSB IFRS S2-aligned disclosure materials:
     - **Governance:** board oversight of climate risk, ESG governance structure
     - **Strategy:** scenario analysis results (PACTA alignment + TRISK stress), strategic response
     - **Risk Management:** how climate risk is integrated into credit review (Phase 4 output)
     - **Metrics & Targets:** financed emissions (PCAF), alignment gaps (PACTA), stress-test results (TRISK)
   - Prepare annual sustainability report section on climate risk for BIDV's public reporting

5. **Report to BIDV board and SBV**
   - Prepare quarterly board briefing: portfolio alignment status, top stress borrowers, engagement progress
   - Prepare SBV reporting as required: green taxonomy alignment, climate risk exposure summary
   - Annual comprehensive report: full-year alignment trajectory, stress-test evolution, borrower engagement outcomes

### Resource Requirements

| Role | Time | Responsibility |
|------|------|----------------|
| ESG team | 0.5-1 FTE ongoing | Quarterly monitoring, disclosure preparation, board reporting |
| GTB advisory support | Quarterly re-runs (1-2 days each) | Pipeline execution, result interpretation |
| IT support | Initial automation setup | Script scheduling, output archiving |

### Deliverable
- Quarterly climate risk monitoring report: updated alignment gaps, stress scores, engagement status
- Annual disclosure pack: TCFD/ISSB S2-aligned materials for public reporting
- Board briefing materials: quarterly summary of portfolio climate risk status
- SBV compliance reports: green taxonomy alignment, climate risk exposure

### Decision 263 Cross-Reference
- Supports: ongoing compliance monitoring as MONRE regulations evolve
- Enables: annual reporting on emission reduction progress for regulated entities in BIDV's portfolio

---

## Integration Guidance

### How PACTA Connects to BIDV's Credit Risk Appetite Framework

PACTA alignment outputs provide a **forward-looking, scenario-based view** of portfolio transition risk that complements BIDV's existing credit risk metrics:

- **Alignment gap as a risk indicator:** Sectors with large alignment gaps (e.g., power sector 20pp below NZE target for coal phase-out) represent higher transition risk. These should feed into BIDV's sector-level risk appetite limits.
- **Technology mix as a concentration metric:** PACTA's technology mix analysis reveals concentration in transition-vulnerable technologies (e.g., coal capacity). This can be treated as a sub-sector concentration limit within the broader power sector.
- **Trajectory tracking:** Quarterly PACTA re-runs show whether the portfolio is moving toward or away from targets. A deteriorating trajectory should trigger risk appetite review.

### How TRISK Complements SBV Circular 13 Stress Testing

TRISK stress-test outputs are **not regulatory PDs** and should not replace BIDV's existing stress testing under SBV Circular 13. Instead, they provide:

- **Transition-specific scenarios:** SBV Circular 13 focuses on traditional credit risk factors. TRISK adds climate transition scenarios (carbon pricing, technology cost shifts, demand changes) that are not covered in standard stress tests.
- **Borrower-level granularity:** TRISK produces borrower-level NPV and PD change estimates, enabling targeted risk management rather than portfolio-level aggregations only.
- **Sensitivity analysis:** TRISK's multi-parameter sensitivity grid shows which assumptions drive risk estimates, helping BIDV understand the robustness of its stress-test conclusions.

### How Decision 263 Compliance Integrates with BIDV's ESG Governance

Decision 263 creates obligations on **both sides** of the lending relationship:

- **Borrower-side:** regulated entities must report emissions, comply with quotas, and develop reduction plans.
- **Bank-side:** BIDV should monitor borrower compliance as part of its ESG governance, since non-compliant borrowers face regulatory risk that translates to credit risk.

The recommended integration:
1. ESG team owns the monitoring dashboard (PACTA + TRISK outputs)
2. Credit risk team uses monitoring outputs in credit review
3. Relationship managers engage borrowers on compliance and transition planning
4. Board receives quarterly summary reports

### How TCFD/ISSB Disclosure Connects to Annual Sustainability Reporting

PACTA and TRISK outputs map directly to TCFD's four pillars and ISSB IFRS S2 requirements:

| TCFD Pillar | PACTA/TRISK Output | ISSB S2 Reference |
|-------------|-------------------|-------------------|
| Governance | ESG governance structure for climate risk monitoring | Paragraph 10-12 |
| Strategy | PACTA alignment gaps, TRISK stress-test results under multiple scenarios | Paragraph 15-22 |
| Risk Management | Credit review integration framework, sector exposure limits | Paragraph 23-26 |
| Metrics & Targets | Financed emissions (PCAF), alignment gaps (PACTA), stress scores (TRISK) | Paragraph 29-34 |

---

## Resource Requirements Summary

| Phase | Duration | BIDV Staff | GTB Support | Technology |
|-------|----------|------------|-------------|------------|
| 1. Data Preparation | 6 weeks | 1 data analyst (PT, ~10 hrs/wk) + ESG coordinator (PT, ~5 hrs/wk) | Intake template, validation script, VSIC→ISIC mapping | BYOL intake tools, R environment |
| 2. Baseline | 6 weeks | 1 quant analyst (FT during run, ~2 weeks) | PACTA pipeline execution, result interpretation | R + r2dii packages, scenario data |
| 3. Risk Assessment | 8 weeks | 1 quant analyst (FT during run, ~3 weeks) + risk reviewer (1-2 weeks) | TRISK pipeline execution, sensitivity analysis, prioritization | R + trisk.model package |
| 4. Action Planning | 6 weeks | Credit risk team + ESG team + relationship managers (as needed) | Engagement templates, exposure management framework | None (process work) |
| 5. Monitoring | Ongoing (quarterly) | 0.5-1 FTE ESG team | Quarterly pipeline re-runs (1-2 days each) | R environment, automated scripts |

**Total initial investment (Phases 1-4):** ~24 weeks, with peak staffing during Phases 2-3.

**Ongoing investment (Phase 5):** 0.5-1 FTE ESG team + quarterly GTB support.

---

## Fast-Track Variant (16 Weeks)

For organizations with strong existing ESG teams and pre-existing data infrastructure, the following compressed timeline is possible:

| Phase | Compressed Duration | Prerequisites |
|-------|---------------------|---------------|
| 1. Data Preparation | 3 weeks | Loanbook data readily extractable; VSIC codes already mapped |
| 2. Baseline | 4 weeks | R environment pre-configured; scenario data pre-loaded |
| 3. Risk Assessment | 5 weeks | TRISK inputs pre-prepared; risk team available for immediate review |
| 4. Action Planning | 4 weeks | Credit review process already has climate risk integration point |

**Note:** The fast-track variant assumes BIDV has: (a) a dedicated ESG team of 2+ FTE, (b) pre-existing data extraction capabilities, (c) an R or Python analytics environment, and (d) an existing credit review process that can incorporate climate signals without process redesign.

---

## Customization Fields for BIDV

The following fields should be filled in during a joint planning session between BIDV and GTB:

| Field | BIDV to Provide |
|-------|-----------------|
| Estimated number of Decision 263 clients in portfolio | ___ |
| Current PCAF baseline status (completed / in progress / not started) | ___ |
| Existing ESG team size (FTE) | ___ |
| Available data analyst capacity (hrs/week) | ___ |
| Internal approval gates for credit policy changes | ___ |
| Board reporting cadence (monthly / quarterly / semi-annual) | ___ |
| Preferred timeline for first PACTA run | ___ |
| Preferred timeline for first TRISK run | ___ |
| Budget allocation for external advisory support | ___ |

---

## Known Limitations

- **Automotive sector not covered:** This roadmap focuses on Decision 263 sectors (power, cement, steel). Automotive alignment analysis is available in the repo but not included in the recommended initial scope.
- **TRISK outputs are not regulatory PDs:** TRISK probability of default changes are scenario-horizon stress summaries for comparative ranking, not regulatory capital model inputs.
- **Cement and steel are sector-context demos:** Borrower-level market-share alignment is available for power; cement and steel currently use sector-level SDA context for orientation.
- **Scenario data is synthetic:** PDP8, NDC, and NZE pathways used in this roadmap are illustrative. BIDV should validate against MONRE's latest published quota levels and IEA's latest NZE update.

---

## Regulatory Update Note

Decision 263 (Quyết định 263/QĐ-TTg, 2022) is implemented through MONRE (Bộ Tài nguyên và Môi trường) regulations that may evolve. BIDV should:

1. Re-validate quota levels and reporting requirements against MONRE's latest implementing guidelines before each PACTA/TRISK re-run
2. Monitor for any amendments to the Law on Environmental Protection 2020 (Luật Bảo vệ Môi trường 2020) that affect GHG quota mechanisms
3. Track SBV (State Bank of Vietnam) green taxonomy updates that may affect sector classification

*Last updated: 2026-05-22. Regulatory references current as of this date.*

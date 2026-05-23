# BIDV Decision 263 Compliance Mapping

> **Date:** 2026-05-22
> **Audience:** BIDV Senior Risk Management and ESG Leadership
> **Classification:** Advisory — Prepared by GTB / Allotrope VC
> **Status:** Draft for Review

---

## How to Read This Document

This document maps **Decision 263's regulatory requirements** to the **analytical capabilities** of the recommended PACTA+TRISK framework. It shows exactly how the repo's pipeline outputs support BIDV's compliance with Vietnam's GHG quota regime for thermal power, steel, and cement.

**For the executive:** Read Sections 1 (Overview) and 4 (Compliance Stack). These tell you what Decision 263 requires and how the recommended framework addresses each requirement.

**For the technical team:** Read Sections 2–3 (sector mapping, compliance capability mapping) for the detailed line-by-line mapping between regulatory requirements and pipeline outputs.

**For data teams:** Read Sections 5–6 (borrower mapping, data availability) to understand what data BIDV can expect from Decision 263 clients and how it flows into the analytical pipeline.

**Related documents:**
- `docs/bidv_framework_comparison.md` — Evaluates 7 frameworks and recommends PACTA+TRISK as the primary analytical stack
- `research/2026-05-22_decision263-vietnam-ghg.md` — Full research brief on Decision 263 with source citations

---

## 1. Decision 263 Overview

### What Is Decision 263?

**Decision 263/QĐ-TTg** (2025) establishes **pilot greenhouse gas emission quotas** for Vietnam's highest-emitting industrial sectors. It is the key implementing instrument for Vietnam's carbon market pilot phase (2025–2027), with full market launch planned for 2028.

**Issued by:** Prime Minister of Vietnam
**Legal basis:** Law on Environmental Protection 2020, Article 91; Decree 06/2022/ND-CP

### Three Requirements for Covered Entities

| # | Requirement | Description | Timeline |
|---|---|---|---|
| 1 | **GHG emission inventory** | Covered facilities must measure, report, and submit their direct emissions (Scope 1) to MONRE for verification | Annual reporting since 2025 |
| 2 | **Sector-specific GHG quotas** | Facilities must stay within allocated emission caps set by MONRE based on historical emissions and sector benchmarks | 2025–2027 pilot; full market 2028+ |
| 3 | **Emission reduction plans** | Facilities must develop and implement plans to reduce emissions in line with their allocated quotas and Vietnam's NDC targets | Ongoing, aligned with quota period |

### Three Covered Sectors

| Sector | Facility Types | Key Entities (Illustrative) |
|---|---|---|
| **Thermal power** | Coal-fired and gas-fired power plants | EVN subsidiaries (Vinh Tan, Duyen Hai), Mong Duong, Nghi Son, O Mon |
| **Steel** | Blast furnace/basic oxygen furnace (BF/BOF) and electric arc furnace (EAF) mills | Hoa Phat Group, Pomina, Formosa Ha Tinh |
| **Cement** | Integrated cement plants (clinker production + grinding) | VICEM subsidiaries, Holcim Vietnam, Xi măng Hà Tiên |

### Facility Thresholds

Under Decree 06/2022/ND-CP, facilities emitting **≥3,000 tonnes CO2e/year** (or meeting sector-specific thresholds set by MONRE) must conduct GHG inventories. The exact threshold for quota obligations under Decision 263 is set by MONRE implementing guidance.

**Note:** Exact quota levels (tonnes CO2e per facility) and specific capacity thresholds are published in Vietnamese-language government gazettes and MONRE circulars. These could not be independently verified from English-language sources. BIDV or GTB may need to supply MONRE implementing regulations for precise quota numbers.

### Enforcement and Timeline

| Phase | Period | Characteristics |
|---|---|---|
| **Pilot** | 2025–2027 | Learning phase — facilities report emissions, MONRE allocates quotas, emission reduction plans developed |
| **Full market** | 2028+ | Carbon credit exchange operational — facilities can buy/sell credits to meet compliance |

**Compliance monitoring:** MONRE is the primary enforcement authority. The national MRV (Measurement, Reporting, Verification) system is under development with GIZ support.

**Penalties:** Non-compliance with GHG inventory and reporting obligations carries administrative fines under Vietnam's environmental protection enforcement framework. Specific penalty amounts are set in Vietnamese administrative penalty decrees.

---

## 2. Sector Mapping: Decision 263 → PACTA → TRISK

This table maps each Decision 263 sector to the corresponding PACTA sector, TRISK sector, technologies, and repo data files.

| Decision 263 Sector | Facility Type | PACTA Sector | PACTA Technologies | TRISK Sector | TRISK Technologies | Repo Data Files |
|---|---|---|---|---|---|---|
| **Thermal power** | Coal plants | `power` | `coalcap` | `Power` | `CoalCap` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_ms.csv`, `data/vietnam_scenario_co2.csv` |
| **Thermal power** | Gas plants | `power` | `gascap` | `Power` | `GasCap` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_ms.csv` |
| **Steel** | BF/BOF mills | `steel` | `open_hearth` | `Steel` | `OpenHearth` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_co2.csv` |
| **Steel** | EAF mills | `steel` | `electric` | `Steel` | `ElectricArc` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_co2.csv` |
| **Cement** | Integrated plants | `cement` | `integrated facility` | `Cement` | `IntegratedFacility` | `data/vietnam_abcd.csv`, `data/vietnam_scenario_co2.csv` |

### Mapping Consistency

This mapping is consistent with:
- `docs/trisk_multisector_contract.md` — sector mapping rules for TRISK
- `intake/SCHEMA.md` — VSIC→ISIC mapping that connects to Decision 263 entity classification
- `scripts/pacta_vietnam_scenario.R` (lines 100–135) — VSIC→PACTA sector mapping logic

### Scenario Pathways by Sector

| Sector | Primary Scenario | Secondary Benchmarks | Method |
|---|---|---|---|
| Thermal power | Vietnam PDP8 (Power Development Plan 8, 2023) | IEA NZE 2050, Vietnam NDC 2022 | Market Share |
| Steel | Vietnam NDC emission intensity targets | IEA NZE steel pathway | SDA |
| Cement | Vietnam NDC emission intensity targets | IEA NZE cement pathway | SDA |

---

## 3. Compliance Capability Mapping

For each Decision 263 requirement, this section shows which repo capability addresses it, what outputs are produced, and how BIDV can use them.

### 3.1 GHG Emission Inventory (Requirement 1)

**Decision 263 requires:** Covered facilities must measure, report, and submit their direct emissions (Scope 1) to MONRE for verification.

**How the repo addresses this:**

| Repo Capability | Output | How BIDV Uses It |
|---|---|---|
| **PCAF financed emissions baseline** (Output 2.1) | Financed emissions inventory (tCO2e by sector), data quality scores | BIDV's own emissions accounting foundation. PCAF measures BIDV's financed emissions, which is the bank-side counterpart to borrower-reported emissions. |
| **PACTA matching pipeline** (`scripts/pacta_vietnam_scenario.R`) | Matched loanbook with borrower names, sector codes, and exposure amounts | Identifies which of BIDV's borrowers are Decision 263-covered entities. The matching pipeline links loanbook counterparties to asset-level company data. |
| **BYOL intake validation** (`scripts/intake_validate_and_map.R`) | Normalized loanbook with VSIC→ISIC→PACTA sector mapping | Converts BIDV's raw loanbook export into the format required for PACTA analysis. Validates sector codes and flags mismatches. |

**Data flow:**
```
BIDV loanbook ──▶ BYOL intake ──▶ Normalized loanbook ──▶ PACTA matching ──▶ Identified Decision 263 borrowers
                      │
                      ▼
              PCAF emissions baseline (Output 2.1)
```

**Gap acknowledgment:** The repo does not collect or verify borrower-reported emissions data. BIDV must obtain this data directly from Decision 263 clients (who are legally required to report to MONRE from 2025). The repo's role is to consume this data once obtained.

### 3.2 Sector-Specific GHG Quotas (Requirement 2)

**Decision 263 requires:** Facilities must stay within allocated emission caps set by MONRE.

**How the repo addresses this:**

| Repo Capability | Output | How BIDV Uses It |
|---|---|---|
| **PACTA SDA analysis** (cement, steel) | Emission intensity gap vs. 2030 target (e.g., +76% for cement, +37% for steel in synthetic MCB portfolio) | Shows which borrowers are above their emission intensity targets — a proxy for quota non-compliance risk. |
| **PACTA market-share analysis** (power) | Technology mix gap vs. PDP8 target (coal capacity reduction trajectory, renewables buildout) | Shows whether the power portfolio is aligned with PDP8's coal phase-down and renewable buildout targets — directly relevant to quota compliance. |
| **PACTA alignment gap calculation** | Alignment gap percentages by sector and technology | Quantifies the gap between current portfolio trajectory and scenario target. BIDV can use these gaps to assess which borrowers are at risk of exceeding their quotas. |
| **TRISK stress testing** (`scripts/trisk_sector_demo.R`) | Borrower-level NPV change and PD change under stress scenarios | Models the financial impact of quota-driven transitions on borrower creditworthiness. If a borrower must reduce emissions to meet their quota, TRISK estimates the NPV and PD impact. |

**Data flow:**
```
Decision 263 quota ──▶ PACTA scenario pathway ──▶ Alignment gap calculation
                           │
                           ▼
                    TRISK stress scenario ──▶ NPV/PD change per borrower
```

**Gap acknowledgment:** The repo does not have access to MONRE's exact quota allocations for individual facilities. The PACTA scenario pathways (PDP8, NDC) serve as proxies for quota trajectories. When MONRE publishes specific quota levels, these should be incorporated into the scenario data.

### 3.3 Emission Reduction Plans (Requirement 3)

**Decision 263 requires:** Covered facilities must develop and implement emission reduction plans aligned with their allocated quotas.

**How the repo addresses this:**

| Repo Capability | Output | How BIDV Uses It |
|---|---|---|
| **Sector prioritization module** (`scripts/sector_prioritization.R`) | Ranked sector priority list with composite scores (alignment + stress + exposure) | Tells BIDV which sectors to prioritize for borrower engagement based on combined alignment gaps, stress-test severity, and portfolio exposure. |
| **TRISK borrower-level stress testing** | Priority score ranking of borrowers by stress severity | Identifies which individual borrowers face the highest financial risk under transition scenarios — the first candidates for engagement. |
| **PACTA company-level alignment** | Company-level alignment gaps by technology | Shows exactly where each borrower is off-track (e.g., "too much coal capacity, not enough renewables") — specific talking points for engagement discussions. |
| **Interactive scenario builder** (`dashboard/pages/5_Scenario_Builder.py`) | Side-by-side baseline vs. scenario comparison with top movers | Allows BIDV to show borrowers "what happens if policy tightens" — a powerful engagement tool for motivating transition plan development. |
| **Report generator** (`scripts/generate_bidv_report.R`) | Professional HTML report with framework recommendation, sector prioritization, and implementation roadmap | The final deliverable that BIDV can use internally and share with borrowers to communicate the analytical basis for engagement requests. |

**Data flow:**
```
Alignment gaps + Stress scores + Exposure weights
                    │
                    ▼
          Sector prioritization module
                    │
                    ▼
          Ranked borrower engagement list
                    │
                    ▼
          Borrower-specific engagement prompts
          (alignment gap + financial impact + timeline request)
```

**Gap acknowledgment:** The repo produces analytical outputs that inform engagement but does not generate the actual engagement communications (letters, meeting agendas, transition plan templates). These should be developed by BIDV's relationship management team using the analytical outputs as evidence.

---

## 4. BIDV Compliance Stack: Three-Layer Architecture

The repo's PACTA+TRISK analytical stack forms a **three-layer compliance and risk management architecture** that maps directly to Decision 263's three requirements.

```
Layer 1: MEASURE ──▶ PCAF + PACTA Matching
                     "Which of our borrowers are covered by Decision 263,
                      and what are their emissions?"
                     Addresses: GHG emission inventory (Req 1)

Layer 2: COMPARE ──▶ PACTA Alignment Analysis
                     "Are our borrowers' emission trajectories aligned with
                      their quotas and Vietnam's PDP8/NDC targets?"
                     Addresses: Sector-specific GHG quotas (Req 2)

Layer 3: ACT ──────▶ TRISK Stress Testing + Sector Prioritization
                     "Which borrowers face the highest financial risk from
                      quota-driven transitions, and who should we engage first?"
                     Addresses: Emission reduction plans (Req 3)
```

### How Each Layer Feeds the Next

1. **Measure → Compare:** PCAF establishes the emissions baseline. PACTA matching identifies which borrowers are Decision 263-covered entities. This data feeds into PACTA alignment analysis.

2. **Compare → Act:** PACTA alignment gaps (e.g., "coal capacity 40% above PDP8 target") inform TRISK stress-test scenario design. TRISK translates these gaps into borrower-level NPV and PD changes. Sector prioritization combines alignment gaps, stress scores, and exposure weights into an engagement priority ranking.

3. **Act → Disclose:** All three layers produce outputs that feed into IFRS S2 disclosure requirements: financed emissions (Layer 1), scenario analysis results (Layer 2), and transition risk management actions (Layer 3).

---

## 5. Synthetic Borrower Mapping to Decision 263 Entities

This section maps the repo's synthetic borrowers (from the MCB portfolio) to typical Decision 263 entity types to demonstrate the analytical coverage.

| Synthetic Borrower | Sector | Decision 263 Entity Type | PACTA Coverage | TRISK Coverage |
|---|---|---|---|---|
| EVN subsidiaries (Vinh Tan 1/4, Duyen Hai 1/3) | Thermal power — coal | Coal-fired power plant (quota entity) | ✅ Market-share analysis | ✅ DCF stress testing |
| EVN subsidiaries (Nhon Trach, O Mon) | Thermal power — gas | Gas-fired power plant (quota entity) | ✅ Market-share analysis | ✅ DCF stress testing |
| International Power Mong Duong | Thermal power — coal | Coal-fired power plant (quota entity) | ✅ Market-share analysis | ✅ DCF stress testing |
| Nghi Son Power LLC | Thermal power — coal | Coal-fired power plant (quota entity) | ✅ Market-share analysis | ✅ DCF stress testing |
| Trung Nam Group | Thermal power — wind | Renewable power plant (transition beneficiary) | ✅ Market-share analysis | ✅ DCF stress testing |
| BIM Group | Thermal power — solar | Renewable power plant (transition beneficiary) | ✅ Market-share analysis | ✅ DCF stress testing |
| VICEM subsidiaries | Cement | Integrated cement plant (quota entity) | ✅ SDA analysis | ✅ DCF stress testing |
| Hoa Phat Group JSC | Steel | BF/BOF steel mill (quota entity) | ✅ SDA analysis | ✅ DCF stress testing |
| Pomina Group | Steel | Steel mill (quota entity) | ✅ SDA analysis | ✅ DCF stress testing |
| Vinacomin (TKV) | Coal mining | Coal producer (indirectly relevant) | ❌ Not a Decision 263 sector | ❌ Not covered by TRISK |
| VinFast | Automotive — EV | Not a Decision 263 sector | ✅ Market-share analysis | ❌ Automotive not covered by TRISK |
| THACO | Automotive — ICE | Not a Decision 263 sector | ✅ Market-share analysis | ❌ Automotive not covered by TRISK |

**Note:** Vinacomin (coal mining) and automotive borrowers (VinFast, THACO) are not Decision 263 sectors. They are included in the synthetic portfolio for analytical completeness but are not part of the BIDV compliance mapping.

---

## 6. Data Availability Assessment

### What Emissions Data BIDV Can Expect from Decision 263 Clients

Since 2025, Decision 263 clients are **legally required** to collect and report emissions data to MONRE. This means:

| Data Type | Availability | Quality | Notes |
|---|---|---|---|
| **Scope 1 emissions (direct)** | Available from 2025 | Improving over time | Legally mandated reporting to MONRE. First-year data may have quality issues. |
| **Scope 2 emissions (indirect)** | May be available | Variable | Depends on sector guidance from MONRE. Not all sectors require Scope 2 reporting. |
| **Production data** | Available | Good | Required for quota compliance monitoring. Includes capacity by technology, production volumes. |
| **Emission reduction plans** | Developing | Early stage | Facilities must develop plans aligned with quotas. Quality and detail will vary. |
| **Carbon price exposure** | Not directly available | N/A | Must be modeled using NGFS or MONRE guidance scenarios. |

### How This Data Feeds into the PACTA+TRISK Pipeline

```
Borrower emissions data (from Decision 263 reporting)
                    │
                    ▼
          BYOL intake validation ──▶ Normalized loanbook
                    │
                    ▼
          PACTA matching ──▶ Asset-level company data enriched with real emissions
                    │
                    ▼
          PACTA alignment analysis ──▶ Real alignment gaps (not synthetic)
                    │
                    ▼
          TRISK stress testing ──▶ Real financial impact estimates
                    │
                    ▼
          Sector prioritization ──▶ Real engagement priority ranking
```

### Data Quality Improvement Pathway

| Phase | Data Source | Quality | Timeline |
|---|---|---|---|
| **Phase 1 (now)** | PCAF database proxies, synthetic estimates | Low–Medium (data quality score 3–4) | Current state |
| **Phase 2 (2025–2026)** | Borrower-reported emissions from Decision 263 reporting | Medium (data quality score 2–3) | As MONRE MRV system matures |
| **Phase 3 (2027+)** | Verified emissions data from MONRE-recognized verifiers | High (data quality score 1–2) | Full MRV system operational |

---

## 7. Gap Acknowledgment

The current pipeline does **not** address the following Decision 263 requirements:

| Gap | Description | Mitigation |
|---|---|---|
| **Verification of borrower-reported emissions** | The repo does not verify the accuracy of emissions data reported by borrowers to MONRE. Verification requires independent third-party auditors. | BIDV should request MONRE-verified emissions data from borrowers when available. The repo's role is analytical, not verification. |
| **Quota trading mechanisms** | If MONRE implements a quota trading system (facilities can buy/sell unused quota), the repo does not model the financial impact of quota trading on borrower creditworthiness. | This can be added as a future enhancement to TRISK — modeling quota purchase costs as an additional operating expense under stress scenarios. |
| **Facility-level vs. company-level analysis** | Decision 263 quotas are set at the facility level (individual power plant, cement kiln, steel mill). The repo's PACTA analysis operates at the company level (aggregated across all facilities owned by a company). | For most Decision 263 entities, the company and facility are the same (single-plant operators). For multi-plant companies (EVN, VICEM), company-level analysis is a reasonable proxy but facility-level refinement may be needed. |
| **Physical risk assessment** | Decision 263 focuses on transition risk (emission quotas). The repo does not assess physical climate risk (flood, drought, sea-level rise exposure of borrower facilities). | Physical risk requires a separate analytical layer. NGFS physical risk variables and vendor platforms can address this. |
| **Oil & gas sector coverage** | If BIDV has oil & gas lending, the current PACTA+TRISK pipeline does not cover this sector. | The `r2dii.*` packages support oil & gas analysis. Extending the pipeline would require additional ABCD data and scenario pathways. |

---

## 8. Regulatory Update Note

**Date-stamp:** All regulatory references in this document are current as of May 2026.

**Recommendation:** BIDV should re-validate this mapping against MONRE's latest implementing guidelines before final delivery. Decision 263 implementation details (quota levels, facility size thresholds, MRV methodology) may evolve as the pilot phase progresses.

**Key documents to monitor:**
- MONRE implementing circulars on MRV methodology (Vietnamese-language)
- MONRE guidance on quota allocation methodology
- SBV updates to the green taxonomy (Decision 1604/QĐ-NHNN)
- GIZ Vietnam carbon market project updates

---

## 9. Cross-Reference to Framework Comparison

This document shows **how** the recommended framework connects to Decision 263. The companion document (`docs/bidv_framework_comparison.md`) shows **why** PACTA+TRISK was recommended over peer frameworks.

**Key cross-references:**

| Decision 263 Requirement | Framework Comparison Section | Compliance Mapping Section |
|---|---|---|
| GHG emission inventory | PCAF evaluation (Section 3.3) | Section 3.1 |
| Sector-specific GHG quotas | PACTA evaluation (Section 3.1) | Section 3.2 |
| Emission reduction plans | TRISK evaluation (Section 3.2) | Section 3.3 |
| Sector coverage (power/steel/cement) | All frameworks scored on Dimension 2 | Section 2 |
| Vietnam regulatory compatibility | All frameworks scored on Dimension 3 | Sections 1, 4 |

**Consistency check:** The framework comparison scores PACTA as "Strong Fit" on Vietnam regulatory compatibility (Dimension 3). This document demonstrates that fit concretely through the sector mapping table (Section 2) and compliance capability mapping (Section 3).

---

*This document maps Decision 263 requirements to the repo's analytical capabilities. All sector mappings are consistent with `docs/trisk_multisector_contract.md`. Items flagged as gaps should be addressed in future phases. Source citations for Decision 263 requirements are available in `research/2026-05-22_decision263-vietnam-ghg.md`.*

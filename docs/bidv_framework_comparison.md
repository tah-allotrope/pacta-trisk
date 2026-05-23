# BIDV Framework Comparison: Portfolio Alignment & Climate Risk Tools

> **Date:** 2026-05-22
> **Audience:** BIDV Senior Risk Management and ESG Leadership
> **Classification:** Advisory — Prepared by GTB / Allotrope VC
> **Status:** Draft for Review

---

## How to Read This Document

This document evaluates 7 leading portfolio alignment and climate risk frameworks against BIDV's specific context: 20+ Decision 263 clients in thermal power, steel, and cement, a PCAF-based financed emissions baseline (Output 2.1), and limited in-house quantitative capacity.

**For the executive:** Read Sections 1 (Executive Summary), 5 (Recommendation), and 6 (Sector Prioritization). These tell you what to do, why, and where to start.

**For the technical team:** Read Sections 2–4 (evaluation matrix, framework narratives, complementarity analysis) for the detailed evidence base.

**For reference:** Sections 7–8 (limitations, other frameworks) provide honest trade-off analysis and context.

**Related documents:**
- `docs/bidv_decision263_mapping.md` — Shows how the recommended framework connects to Decision 263 compliance requirements
- `research/2026-05-22_portfolio-alignment-frameworks.md` — Full research briefs with source citations for every framework

---

## 1. Executive Summary

BIDV faces a dual regulatory imperative: **Decision 263** (GHG emission quotas for thermal power, steel, and cement borrowers) and the **SBV Green Taxonomy** (portfolio classification and reporting). Neither can be addressed with emissions accounting alone — BIDV needs tools that measure alignment with decarbonization pathways, quantify financial risk under transition scenarios, and produce actionable outputs for borrower engagement and external disclosure.

This document evaluates 7 frameworks across 10 dimensions relevant to BIDV's context. The recommendation is a **three-layer stack**:

| Layer | Framework | Role | Status |
|---|---|---|---|
| **Prerequisite** | PCAF | Financed emissions accounting | Already in place (Output 2.1) |
| **Primary analytical** | PACTA + TRISK | Portfolio alignment + transition stress testing | Proven in this repo's demo pipeline |
| **Disclosure output** | IFRS S2 (TCFD successor) | Climate-related financial disclosure | Globally adopted; Vietnam trajectory aligned |

**Why this stack:** PCAF measures the baseline; PACTA tells BIDV whether its portfolio is building too much coal and not enough renewables compared to Vietnam's PDP8 and NDC targets; TRISK translates misalignment into borrower-level NPV and PD changes; IFRS S2 provides the disclosure framework that turns all of this into investor-ready reporting. GFANZ/NZBA provides the governance wrapper; NGFS provides scenario inputs; SBTi FI provides target validation — all complementary but not substitutes for the core analytical layer.

---

## 2. Evaluation Matrix

Each framework is scored across 10 dimensions on a 3-level scale:

| Score | Meaning |
|---|---|
| **Strong Fit** | Framework addresses this dimension well for BIDV's context |
| **Partial Fit** | Framework addresses this but with limitations for BIDV |
| **Weak Fit** | Framework does not meaningfully address this for BIDV |

### 7 × 10 Scored Matrix

| Dimension | PACTA | TRISK | PCAF | SBTi FI | GFANZ/NZBA | NGFS | IFRS S2 |
|---|---|---|---|---|---|---|---|
| **1. Data inputs** | Partial | Partial | Partial | Weak | Partial | Strong | Weak |
| **2. Sector coverage (power/steel/cement)** | Strong | Strong | Strong | Strong | Strong | Strong | Strong |
| **3. Vietnam regulatory compatibility** | Strong | Partial | Strong | Partial | Strong | Partial | Strong |
| **4. Output types** | Strong | Strong | Partial | Partial | Partial | Partial | Strong |
| **5. Implementation complexity** | Partial | Weak | Partial | Weak | Partial | Weak | Partial |
| **6. Cost** | Strong | Strong | Strong | Weak | Partial | Strong | Partial |
| **7. Open-source availability** | Strong | Strong | Strong | Partial | Strong | Partial | Partial |
| **8. Time to first results** | Strong | Partial | Strong | Weak | Partial | Weak | Weak |
| **9. Complementarity with PCAF** | Strong | Strong | — | Strong | Strong | Strong | Strong |
| **10. Maturity & ASEAN adoption** | Strong | Weak | Strong | Partial | Strong | Strong | Strong |

### Scoring Justifications

#### 1. Data Input Requirements

| Framework | Score | Justification |
|---|---|---|
| PACTA | Partial | Requires loanbook + asset-level company data (ABCD). ABCD coverage for Vietnamese companies is thinner than OECD markets, but the tool works with any data that can be provided. |
| TRISK | Partial | Requires asset-level financial features (revenue projections, operating costs) that are typically estimated for Vietnamese borrowers. Synthetic data works for demos; real data improves credibility. |
| PCAF | Partial | Requires borrower-level emissions data. Vietnamese corporates rarely report verified emissions, so PCAF database proxies must be used (lower data quality scores). |
| SBTi FI | Weak | Requires mature PCAF-aligned emissions inventory plus sector-level portfolio analysis and counterparty engagement data — all challenging for a Vietnamese bank at early data maturity. |
| GFANZ/NZBA | Partial | Banks choose their own tools and data sources. Flexibility is an advantage, but BIDV still needs the underlying data infrastructure. |
| NGFS | Strong | Scenario data is fully open and free. No borrower-level data needed — only macroeconomic and sector-level variables that NGFS provides. |
| IFRS S2 | Weak | Requires Scope 3 Category 15 (financed emissions) data from borrowers — the single biggest data gap for Vietnamese banks. |

#### 2. Sector Coverage (Thermal Power, Steel, Cement)

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | Full coverage of all three sectors with dedicated methodologies: market-share for power, SDA for cement and steel. |
| TRISK | Strong | Full coverage: DCF-based for power, SDA-to-TRISK translation for cement and steel. |
| PCAF | Strong | All three covered through business loans and project finance asset classes. |
| SBTi FI | Strong | Dedicated sector methodologies exist for all three (Steel Guidance 2023, Cement Guidance 2022, Power Quick Start Guide). |
| GFANZ/NZBA | Strong | Dedicated sector papers published for all three (Power Oct 2024, Steel May 2024, Cement Jan 2026). |
| NGFS | Strong | Scenario variables explicitly cover all three sectors with carbon prices, energy mix shifts, and demand destruction pathways. |
| IFRS S2 | Strong | SASB Commercial Banks standard requires sector-level disclosure for all three. |

#### 3. Vietnam Regulatory Compatibility (Decision 263, SBV Taxonomy)

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | Works with Vietnam-specific scenarios (PDP8, NDC) alongside global benchmarks. VSIC→ISIC mapping is straightforward. Directly addresses Decision 263 sectors. |
| TRISK | Partial | Works with any sector but requires Vietnam-specific carbon price curves for full regulatory relevance. Package's built-in carbon tax scenarios are useful for demos but not Vietnam policy forecasts. |
| PCAF | Strong | Jurisdiction-agnostic methodology. Vietnamese banks can use it to comply with SBV green credit guidelines. |
| SBTi FI | Partial | Globally applicable standards, but Vietnamese corporates rarely have SBTi targets, making counterparty engagement harder. Validation cost may be significant. |
| GFANZ/NZBA | Strong | UNEP FI Asia Pacific regional engagement. Flexible methodology choice allows BIDV to use approaches appropriate to its data maturity. |
| NGFS | Partial | Includes EMDE profile relevant to Vietnam. SBV observers NGFS outputs but Vietnam is not yet an NGFS member. |
| IFRS S2 | Strong | SBV green taxonomy (Decision 1604/QĐ-NHNN) is a prerequisite for ISSB-aligned disclosure. Vietnam's SSC is moving toward mandatory sustainability disclosure with ISSB alignment. |

#### 4. Output Types

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | Technology mix charts, trajectory charts, emission intensity charts, alignment summary tables, company-level match coverage — comprehensive analytical outputs. |
| TRISK | Strong | Borrower-level NPV change, PD change, priority score ranking, sensitivity analysis — translates alignment into financial risk. |
| PCAF | Partial | Financed emissions inventory and intensity metrics. Foundation layer only — does not produce alignment or risk outputs. |
| SBTi FI | Partial | Validated targets and public commitment. Does not produce analytical outputs — it validates targets set using other tools. |
| GFANZ/NZBA | Partial | Transition plans and progress reports. Guidance framework, not an analytical tool. |
| NGFS | Partial | Macroeconomic projections and scenario variables. Feeds into other tools but does not produce portfolio-level outputs. |
| IFRS S2 | Strong | Requires disclosure of financed emissions, scenario analysis results, transition plans, and metrics/targets — creates demand for all upstream analytical outputs. |

#### 5. Implementation Complexity

| Framework | Score | Justification |
|---|---|---|
| PACTA | Partial | Requires R environment and data preparation. Well-documented with official cookbook. Biggest challenge: obtaining ABCD data for Vietnamese borrowers. |
| TRISK | Weak | Requires understanding of DCF modeling, Merton model assumptions, and folder-based input contract. Documentation is limited compared to PACTA. |
| PCAF | Partial | Requires GHG accounting capability and borrower emissions data. Free tools and e-learning available. Biggest challenge: data availability from Vietnamese SMEs. |
| SBTi FI | Weak | Rigorous validation process requiring dedicated climate team, data infrastructure, and likely external advisory. Highest complexity of all frameworks evaluated. |
| GFANZ/NZBA | Partial | Less prescriptive than SBTi but requires robust internal capability for target setting, transition planning, and progress reporting. |
| NGFS | Weak | Requires macroeconomic modeling capability and statistical/actuarial capacity to translate macro shocks into credit risk parameters. Typically requires external modeling support. |
| IFRS S2 | Partial | Narrative disclosure (governance, strategy) is lower complexity. Financed emissions and scenario analysis components are higher complexity. |

#### 6. Cost

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | Free and open-source. No licensing fees. Costs are internal staff time. |
| TRISK | Strong | Free and open-source (R package on CRAN). No licensing fees. |
| PCAF | Strong | Free to join. No membership fee. PCAF Database access included for signatories. |
| SBTi FI | Weak | Validation fees USD 10,000–50,000+. Additional advisory costs can be significant. Annual reporting costs ongoing. |
| GFANZ/NZBA | Partial | UNEP FI membership required (fee-based). No separate NZBA fee. Generally lower than SBTi validation costs. |
| NGFS | Strong | Scenario data is fully free and open. Implementation costs are in the modeling layer, not the data. |
| IFRS S2 | Partial | Standard is free. Implementation costs $100K–$500K for first-year reporting. Ongoing $50K–$200K/year. |

#### 7. Open-Source Availability

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | Full stack is open-source R packages on CRAN. Source code on GitHub. Official documentation. |
| TRISK | Strong | R package on CRAN. Academic paper available. |
| PCAF | Strong | Standard is free and open. Methodology is transparent. No proprietary software required. |
| SBTi FI | Partial | Standards and tools are free. Validation service is paid. Temperature Rating tool is open-source on GitHub. |
| GFANZ/NZBA | Strong | All guidance papers, reports, and tools are free to download. |
| NGFS | Partial | Scenario data is fully open. No open-source implementation tools — banks must build or buy the modeling layer. |
| IFRS S2 | Partial | Standard text and SASB Standards are free. Implementation tools are mixed (some open, some commercial). |

#### 8. Time to First Results

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | 1–3 months from data preparation to alignment analysis. |
| TRISK | Partial | 2–4 months from data preparation to stress-test outputs. Requires PACTA outputs as upstream input. |
| PCAF | Strong | 3–6 months for first financed emissions calculation. |
| SBTi FI | Weak | 6–18 months from data prep to validated targets. Includes validation review bottleneck. |
| GFANZ/NZBA | Partial | 6–12 months to set targets and publish transition plan. No validation bottleneck. |
| NGFS | Weak | 6–12 months for basic stress test. 12–24 months for fully integrated portfolio-level stress testing. |
| IFRS S2 | Weak | 12–24 months for first complete IFRS S2-aligned report. |

#### 9. Complementarity with PCAF Baseline

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | PACTA uses PCAF-aligned emissions data as input. The two tools are designed to work together. |
| TRISK | Strong | TRISK stress tests build on PACTA alignment outputs, which build on PCAF accounting. Full pipeline compatibility. |
| SBTi FI | Strong | SBTi requires PCAF-aligned emissions inventory as input. Direct complementarity. |
| GFANZ/NZBA | Strong | NZBA guidance recommends PCAF for emissions accounting. |
| NGFS | Strong | NGFS scenarios feed into PACTA alignment analysis and TRISK stress testing, which both use PCAF data. |
| IFRS S2 | Strong | IFRS S2 requires financed emissions disclosure (PCAF output) and scenario analysis (PACTA/TRISK output). |

#### 10. Maturity and Institutional Adoption (ASEAN/Emerging Markets)

| Framework | Score | Justification |
|---|---|---|
| PACTA | Strong | 1,500+ institutions globally. MAS, Bank Indonesia, and several ASEAN commercial banks have used PACTA. |
| TRISK | Weak | Academic framework with working R package. Less institutional adoption than PACTA. PACTA-TRISK integration is novel. |
| PCAF | Strong | 700+ signatories globally, 250+ published disclosures. Growing rapidly in Asia (PCAF Japan, PCAF India). |
| SBTi FI | Partial | 180+ FIs with validated targets. ASEAN presence growing but still limited — most adopters are European, North American, and Japanese banks. |
| GFANZ/NZBA | Strong | ~150 member banks globally. UNEP FI Asia Pacific regional engagement. Several Southeast Asian banks are members. |
| NGFS | Strong | 150+ central banks and supervisors. MAS, BI, BSP all use NGFS scenarios. Phase V (2024) has improved EMDE granularity. |
| IFRS S2 | Strong | Jurisdictional adoption in 30+ countries. In ASEAN: Singapore (mandatory from FY2025), Malaysia (phased from 2025), Thailand (voluntary → mandatory). |

---

## 3. Framework-by-Framework Evaluation

### 3.1 PACTA for Banks

**What it does:** PACTA assesses whether a financial portfolio's real-economy exposure to climate-relevant sectors is aligned with Paris Agreement scenarios. It matches a bank's loanbook to asset-level company data, then compares the portfolio's technology mix and production trajectory against scenario pathways (IEA NZE, national plans like Vietnam's PDP8, NDC targets).

**How it works:** The tool uses two analytical methods. For sectors with production targets (power), it uses the Market Share method — comparing the portfolio's share of each technology against the scenario's target share. For emission-intensity sectors (cement, steel), it uses the Sectoral Decarbonization Approach (SDA) — comparing the portfolio's weighted-average emission intensity against the scenario's intensity pathway.

**What BIDV would need:** A loanbook with counterparty names, exposure amounts, and sector codes (VSIC or ISIC). Asset-level company data for Vietnamese borrowers — this is the main data gap, as global ABCD coverage is thinner for emerging markets. An R environment to run the open-source `r2dii.*` packages. The repo already demonstrates this pipeline with a synthetic Vietnamese bank portfolio covering power, cement, and steel.

**Strengths for Decision 263 context:** Directly addresses all three Decision 263 sectors with dedicated methodologies. Works with Vietnam-specific scenarios (PDP8) alongside global benchmarks. Open-source and free. Produces concrete alignment gap percentages that BIDV can use to prioritize borrower engagement. 1,500+ institutions globally, including ASEAN central banks.

**Weaknesses for Decision 263 context:** ABCD data coverage for Vietnamese companies is thinner than for OECD markets. The tool measures alignment but does not translate misalignment into financial risk metrics (NPV, PD) — this requires a complementary tool like TRISK. Does not produce disclosure-ready outputs for IFRS S2 reporting.

### 3.2 TRISK

**What it does:** TRISK quantifies the financial impact of climate transition scenarios on individual borrowers' creditworthiness. It uses discounted cash flow (DCF) models to estimate how scenario-driven changes (carbon prices, commodity price shifts, policy timing) affect borrower-level net present value (NPV) and probability of default (PD).

**How it works:** TRISK takes asset-level production data, financial features (discount rate, risk-free rate, market passthrough), and scenario pathways (baseline vs. stress) as inputs. It runs a DCF model under each scenario, computes the change in NPV, and applies a Merton model to estimate the change in PD. Sensitivity analysis is available for key parameters.

**What BIDV would need:** Asset-level data for borrowers (production capacity by technology, operating costs, revenue projections). Scenario data with carbon price curves and commodity price paths. Financial feature estimates for Vietnamese borrowers. The `trisk.model` R package on CRAN.

**Strengths for Decision 263 context:** Translates PACTA alignment gaps into borrower-level financial risk metrics — exactly what credit risk teams need. Produces a priority ranking of borrowers by stress severity. Sensitivity analysis shows which assumptions drive the ranking. Covers all three Decision 263 sectors.

**Weaknesses for Decision 263 context:** Less mature than PACTA — primarily used in research and pilot contexts. Requires realistic financial data for Vietnamese borrowers, which is typically estimated. Package documentation is limited. The built-in carbon tax scenarios are useful for demo behavior but are not Vietnam policy forecasts.

### 3.3 PCAF (Partnership for Carbon Accounting Financials)

**What it does:** PCAF provides a standardized methodology for financial institutions to measure and disclose the GHG emissions associated with their loans and investments (Scope 3, Category 15 — financed emissions). It is the accounting foundation that all other frameworks build upon.

**How it works:** PCAF uses an attribution factor — `outstanding_amount / enterprise_value_plus_debt` — to allocate a borrower's emissions to the financier. It provides sector-specific methodologies for 6 asset classes and a data quality scoring system (1–5).

**What BIDV would need:** Loan book data with outstanding amounts and asset classes. Borrower-level emissions data (or PCAF database proxies). The PCAF Standard (free PDF) and associated calculation tools.

**Strengths for Decision 263 context:** Free to join, no membership fee. Globally recognized methodology used as the accounting foundation by SBTi, NZBA, and PACTA. Works for all three Decision 263 sectors through business loans and project finance asset classes. Growing rapidly in Asia.

**Weaknesses for Decision 263 context:** Measures emissions but does not assess alignment or risk. Vietnamese corporate emissions data is sparse — PCAF database proxies will produce lower data quality scores. Does not answer "is my portfolio aligned?" or "what is my transition risk?" — only "what are my financed emissions?"

### 3.4 SBTi Financial Institutions

**What it does:** SBTi FI provides a framework for financial institutions to set science-based emissions reduction targets for their portfolios, with independent validation that adds credibility. It offers two pathways: Near-Term Criteria (10-year targets) and Net-Zero Standard (full net-zero by 2050).

**How it works:** SBTi uses the Sectoral Decarbonization Approach (SDA) to allocate sector carbon budgets to portfolios, a Portfolio Temperature Rating for implied temperature rise scoring, and Climate Alignment Targets for the percentage of portfolio aligned with net-zero pathways. Targets are submitted for independent validation by SBTi Services.

**What BIDV would need:** A mature PCAF-aligned emissions inventory. Sector-level portfolio analysis. Counterparty-level emissions and reduction targets. Target modeling using SBTi's FINZ Target-Setting Tool. A dedicated climate/sustainability team and likely external advisory support.

**Strengths for Decision 263 context:** Dedicated sector methodologies exist for all three Decision 263 sectors. Validation provides a strong credibility signal. Globally recognized standard with 180+ FI adopters.

**Weaknesses for Decision 263 context:** Highest implementation complexity and cost of all frameworks evaluated (USD 10,000–50,000+ for validation). Vietnamese corporates rarely have verified emissions data or SBTi targets themselves, making counterparty engagement harder. 6–18 month timeline to validated targets. ASEAN adoption still limited.

### 3.5 GFANZ / NZBA (Net-Zero Banking Alliance)

**What it does:** NZBA is a commitment and transition planning alliance for banks under the GFANZ umbrella. It provides governance framework, peer learning, and sector-specific guidance for setting and managing net-zero targets. Unlike SBTi, it is not a validation body — targets are self-reported with progress reviews.

**How it works:** Banks commit to net zero by 2050, set interim 2030 targets using their chosen methodologies (SBTi, PACTA, IEA pathways, etc.), publish transition plans, and report annually. NZBA provides Guidelines for Climate Target Setting (v4, Oct 2025) and dedicated sector papers for power, steel, cement, and others.

**What BIDV would need:** UNEP FI membership (fee-based). Internal capability for target setting, transition planning, and progress reporting. Chosen analytical tools (PCAF for accounting, PACTA for alignment, etc.).

**Strengths for Decision 263 context:** More flexible than SBTi — BIDV can use methodologies appropriate to its data maturity. UNEP FI Asia Pacific regional engagement. Can start with commitment and build targets progressively. Peer learning with other emerging market banks. No validation bottleneck.

**Weaknesses for Decision 263 context:** Less prescriptive than SBTi — more flexibility means more internal judgment required. Still requires significant data and capacity investment. Membership fees apply. Self-reported targets carry less credibility than independently validated ones.

### 3.6 NGFS Climate Scenarios

**What it does:** NGFS provides a common set of forward-looking climate scenarios for central banks and supervisors to assess climate-related financial risks. It bridges climate science (IPCC/IEA pathways) and financial risk modeling.

**How it works:** NGFS offers six core scenarios spanning orderly transition, disorderly transition, and hot house world outcomes, plus a Net Zero 2050 scenario. Each scenario provides macroeconomic variables (GDP, inflation, carbon prices, energy prices), sector-specific transition variables, and physical risk variables at country/region level.

**What BIDV would need:** Access to NGFS scenario data (free). Macroeconomic modeling capability or a vendor platform to translate scenario variables into credit risk parameters. Dedicated climate risk team or external modeling support.

**Strengths for Decision 263 context:** Scenario data is fully free and open. Includes an EMDE profile relevant to Vietnam. 150+ central banks and supervisors are NGFS members. ASEAN adoption growing (MAS, BI, BSP). Provides the scenario inputs that feed into PACTA alignment analysis and TRISK stress testing.

**Weaknesses for Decision 263 context:** Does not produce portfolio-level outputs — it provides inputs that must be modeled. Highest implementation complexity for the modeling layer ($200K–$2M+). 12–24 months for fully integrated portfolio-level stress testing. Vietnam is not yet an NGFS member.

### 3.7 TCFD / IFRS S2

**What it does:** IFRS S2 (which incorporated the TCFD recommendations after TCFD disbanded in Oct 2023) creates a global baseline for investor-focused climate disclosures. It requires narrative and quantitative disclosures across four pillars: Governance, Strategy, Risk Management, and Metrics & Targets.

**How it works:** IFRS S2 requires financed emissions disclosure (Scope 3, Category 15), scenario analysis results, transition plan details, and sector-level metrics using SASB Standards. It does not prescribe how to calculate these — it creates the demand for outputs that other tools (PCAF, PACTA, NGFS-based models) produce.

**What BIDV would need:** Financed emissions data (PCAF output). Scenario analysis results (PACTA/TRISK or NGFS-based). Transition plan details. Governance and risk management process documentation. Data systems for ongoing reporting.

**Strengths for Decision 263 context:** Jurisdictional adoption in 30+ countries, with ASEAN momentum (Singapore mandatory from FY2025, Malaysia phased from 2025). SBV green taxonomy is a prerequisite for ISSB-aligned disclosure. Creates direct demand for the analytical outputs that PACTA and TRISK produce. Globally recognized.

**Weaknesses for Decision 263 context:** Does not produce analytical outputs — it requires them. Financed emissions data from borrowers is the single biggest gap for Vietnamese banks. 12–24 months for first complete report. Implementation costs $100K–$500K for first-year reporting.

---

## 4. Recommendation

### Primary / Secondary / Tertiary Framework Stack

| Priority | Framework | Role | Rationale |
|---|---|---|---|
| **Primary (analytical)** | **PACTA + TRISK** | Portfolio alignment assessment + transition stress testing | Directly addresses Decision 263 sectors with proven analytical outputs. Open-source and free. Already demonstrated in this repo's pipeline with synthetic Vietnamese bank data. Produces concrete alignment gaps and borrower-level financial risk metrics. |
| **Secondary (prerequisite)** | **PCAF** | Financed emissions accounting | Already in place as Output 2.1. The accounting foundation that PACTA and TRISK build upon. Free, globally recognized, and required by SBTi, NZBA, and IFRS S2. |
| **Tertiary (disclosure)** | **IFRS S2** | Climate-related financial disclosure | The globally recognized disclosure framework that turns PACTA/TRISK analytical outputs into investor-ready reporting. Vietnam's regulatory trajectory (SBV taxonomy, SSC sustainability reporting) is aligned with ISSB adoption. |

### Why This Stack

The recommended stack creates a **complete analytical pipeline** from measurement to action to disclosure:

```
PCAF (measure) → PACTA (align) → TRISK (stress) → IFRS S2 (disclose)
     ↓                ↓              ↓                 ↓
  "What are my    "Is my portfolio  "What is the     "How do I report
  financed         aligned with      financial        to investors and
  emissions?"      PDP8/NDC?"        impact?"         regulators?"
```

- **PCAF** establishes the emissions baseline that all downstream analysis depends on.
- **PACTA** tells BIDV whether its portfolio is aligned with Vietnam's PDP8 and NDC targets — producing concrete gap percentages by sector and technology.
- **TRISK** translates PACTA's alignment gaps into borrower-level NPV and PD changes — giving credit risk teams the financial metrics they need to prioritize action.
- **IFRS S2** provides the disclosure framework that turns all upstream analytical outputs into investor-ready reporting, satisfying both international investor expectations and Vietnam's emerging sustainability disclosure requirements.

### Complementary Frameworks (Not Primary but Relevant)

| Framework | Role in BIDV's Stack | When to Consider |
|---|---|---|
| **GFANZ/NZBA** | Governance wrapper and peer learning network | When BIDV is ready to make a public net-zero commitment and engage in peer learning with other emerging market banks |
| **SBTi FI** | Independent target validation | After PCAF accounting is mature and PACTA alignment gaps are understood — adds credibility but requires significant investment |
| **NGFS** | Scenario input provider | When BIDV needs more sophisticated macroeconomic scenario analysis beyond PDP8/NDC/NZE — feeds into both PACTA and TRISK |

---

## 5. Complementarity Analysis: The Complete Pipeline

The recommended framework stack is not a menu of alternatives — it is an **integrated pipeline** where each layer's outputs are the next layer's inputs.

### Layer 1: PCAF — Emissions Accounting

**Input:** BIDV's loanbook (counterparty names, exposure amounts, sector codes).

**Process:** Apply PCAF attribution factor to allocate borrower emissions to BIDV. Use PCAF database proxies where borrower-reported data is unavailable. Score data quality (1–5).

**Output:** Financed emissions inventory (tCO2e by sector), emissions intensity metrics (tCO2e per $M revenue), data quality scores.

**Feeds into:** PACTA (scenario alignment requires emissions baseline), SBTi FI (target-setting requires PCAF-aligned inventory), IFRS S2 (requires financed emissions disclosure).

### Layer 2: PACTA — Portfolio Alignment

**Input:** PCAF emissions baseline + loanbook + asset-level company data (ABCD) + scenario pathways (PDP8, NDC, IEA NZE).

**Process:** Match loanbook to ABCD using fuzzy matching with manual review. Run market-share analysis for power and SDA analysis for cement/steel. Calculate alignment gaps by sector and technology.

**Output:** Technology mix charts, trajectory charts, emission intensity charts, alignment summary tables (gap percentages), company-level match coverage.

**Feeds into:** TRISK (alignment gaps inform stress-test scenario design), borrower engagement (gap percentages show where borrowers are off-track), SBV taxonomy classification (sector/technology data for transition activity assessment).

### Layer 3: TRISK — Transition Stress Testing

**Input:** PACTA alignment outputs + asset-level financial features + scenario pathways (baseline vs. stress with carbon price curves).

**Process:** Run DCF models under baseline and stress scenarios. Compute NPV change and PD change for each borrower. Apply sensitivity analysis for key parameters (shock year, discount rate, market passthrough).

**Output:** Borrower-level NPV change, PD change, priority score ranking, sensitivity analysis results.

**Feeds into:** Credit risk management (PD changes inform provisioning), borrower engagement prioritization (priority ranking shows which borrowers to engage first), Decision 263 compliance monitoring (stress-test results show financial urgency of quota-driven transitions).

### Layer 4: IFRS S2 — Climate Disclosure

**Input:** PCAF financed emissions + PACTA alignment results + TRISK stress-test outputs + governance/risk management process documentation.

**Process:** Compile narrative disclosures across four pillars (Governance, Strategy, Risk Management, Metrics & Targets). Include scenario analysis results, financed emissions by sector, transition plan details.

**Output:** Annual sustainability/climate disclosure report (integrated into financial filings), investor-ready climate risk reporting.

**Feeds into:** International investor relations, SBV regulatory reporting, correspondent bank requirements.

### The Complete Flow

```
Loanbook ──▶ PCAF ──▶ Financed Emissions ──▶ PACTA ──▶ Alignment Gaps
    │                    │                        │
    │                    │                        ▼
    │                    │                   TRISK ──▶ NPV/PD Changes
    │                    │                        │
    │                    ▼                        ▼
    │              IFRS S2 Disclosure ◀───────────┘
    │              (Governance, Strategy,
    │               Risk Management,
    │               Metrics & Targets)
    │
    └──▶ Decision 263 Compliance Monitoring
         (Borrower GHG data, quota tracking,
          emission reduction plan review)
```

---

## 6. Limitations and Honest Trade-Offs

No framework is perfect. The recommended PACTA+TRISK stack has genuine limitations that BIDV should understand before adoption.

### Where Peer Frameworks Outperform the Recommendation

| Limitation | Peer Framework That Does Better | Why It Matters |
|---|---|---|
| **PACTA requires asset-level data that may be incomplete for Vietnamese borrowers** | PCAF (uses emissions proxies when borrower data is unavailable) | PACTA's alignment results are only as good as the ABCD data. Thin coverage for Vietnamese companies means some borrowers will be unmatched, reducing portfolio coverage. PCAF's proxy approach is less precise but more complete. |
| **TRISK outputs are not regulatory PDs** | NGFS-based supervisory stress testing (produces regulatory-grade credit risk parameters) | TRISK's PD estimates are model-based and illustrative, not regulatory capital parameters. BIDV's risk team should treat TRISK outputs as comparative transition-stress ranking tools, not as inputs to regulatory capital calculations. |
| **No oil & gas coverage in current PACTA+TRISK implementation** | PCAF (covers all asset classes where borrower emissions data exists) | The repo's current pipeline covers power, cement, and steel (the three Decision 263 sectors). If BIDV has significant oil & gas exposure, PCAF can measure financed emissions for that sector, but PACTA/TRISK analytical coverage would need to be extended. |
| **PACTA does not produce disclosure-ready outputs** | IFRS S2 (defines the exact disclosure format regulators and investors expect) | PACTA produces analytical charts and tables, not formatted disclosure reports. The report generator (`scripts/generate_bidv_report.R`) bridges this gap by assembling PACTA/TRISK outputs into a professional HTML report, but IFRS S2-aligned disclosure requires additional narrative and governance content. |
| **TRISK is less mature than established stress-testing frameworks** | NGFS (150+ central banks, supervisory-grade scenario design) | TRISK is an academic framework with a working R package but limited institutional adoption. NGFS scenarios are used by central banks worldwide for supervisory stress tests. TRISK's value is in translating alignment gaps into borrower-level financial metrics — a capability NGFS does not provide directly. |

### What BIDV Should Consider for Future Phases

1. **Oil & gas sector coverage:** If BIDV has material oil & gas lending, extend the PACTA pipeline to cover fossil fuel extraction sectors. The `r2dii.*` packages support this.

2. **Physical risk assessment:** The current stack covers transition risk only. Physical risk (flood, drought, sea-level rise exposure of collateral) requires a separate analytical layer. NGFS physical risk variables and vendor platforms (e.g., Jupiter, Four Twenty Seven) can address this.

3. **Automotive sector TRISK coverage:** The current TRISK pilot covers power, cement, and steel. Automotive (VinFast, THACO in the synthetic portfolio) is covered by PACTA but not TRISK. Extending TRISK to automotive would complete the sector coverage.

4. **Vietnam-specific carbon price curves:** TRISK's built-in carbon tax scenarios are useful for demos but not Vietnam policy forecasts. Developing Vietnam-specific carbon price curves (e.g., from NGFS EMDE scenarios or MONRE guidance) would improve TRISK credibility.

5. **Borrower-level emissions data collection:** As Decision 263 clients begin reporting emissions to MONRE (2025+), BIDV should establish a data collection process to obtain this data directly from borrowers. This will improve both PCAF data quality scores and PACTA matching accuracy.

---

## 7. Other Frameworks (Briefly Noted)

The following frameworks were considered but not included in the scored matrix. They are relevant but operate at a different level or scope.

| Framework | Category | Why Not in Matrix |
|---|---|---|
| **Transition Pathway Initiative (TPI)** | Sector-level transition assessment | Overlaps with PACTA's alignment function; less bank-specific. TPI assesses individual companies' management of climate risk and carbon performance, not portfolio-level alignment. |
| **Carbon Tracker Carbon Budget Analysis** | Stranded asset analysis | Narrower scope (fossil fuels only); not a portfolio tool. Useful for understanding coal asset stranding risk but does not cover steel or cement. |
| **IFC Performance Standards / Equator Principles** | Project-level E&S due diligence | Operate at the transaction level, not the portfolio level. Highly relevant for BIDV's project finance deals in power, cement, and steel — they complement but do not replace portfolio tools. No Vietnamese bank is currently an EP signatory; BIDV could be a first-mover. |
| **UNEP FI TCFD Banking Pilots** | TCFD implementation guidance | Subsumed by IFRS S2. The Banking Pilots provided early TCFD implementation guidance for banks, but IFRS S2 now provides the definitive disclosure standard. |

---

## 8. How to Read This Document Together with the Decision 263 Mapping

This document evaluates **which frameworks** BIDV should adopt. The companion document (`docs/bidv_decision263_mapping.md`) shows **how the recommended framework connects to Decision 263 compliance requirements**.

**Read them together to answer:**
1. **This document:** "Which frameworks should we use, and why?" → Recommendation: PCAF → PACTA → TRISK → IFRS S2
2. **Decision 263 mapping:** "How do these frameworks help us meet our regulatory obligations?" → Maps each Decision 263 requirement (emission inventory, GHG quotas, emission reduction plans) to specific repo capabilities and pipeline outputs

**Together, they form the advisory core** of the final BIDV Framework Recommendation Report, which will also include sector prioritization results, an implementation roadmap, and illustrative PACTA/TRISK outputs from the synthetic MCB portfolio.

---

*This document is based on publicly available framework documentation as of May 2026. All source citations are available in `research/2026-05-22_portfolio-alignment-frameworks.md`. Framework evaluations include honest trade-off analysis — where peer frameworks outperform the recommendation, this is documented in Section 6.*

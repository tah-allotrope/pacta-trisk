# Research Brief: Portfolio Alignment Frameworks

> **Date:** 2026-05-22
> **Author:** PACTA-TRISK Vietnam project
> **Purpose:** Evidence base for the BIDV framework comparison matrix (GAP-01). Covers 7 frameworks evaluated across consistent dimensions relevant to a Vietnamese commercial bank with 20+ Decision 263 clients in thermal power, steel, and cement.

---

## Framework Inventory

| # | Framework | Category | Primary Role |
|---|---|---|---|
| 1 | PACTA for Banks | Portfolio alignment | Scenario-based alignment assessment |
| 2 | TRISK | Transition stress testing | Borrower-level NPV/PD impact under climate scenarios |
| 3 | PCAF | Emissions accounting | Financed emissions measurement (Scope 3, Cat. 15) |
| 4 | SBTi Financial Institutions | Target-setting + validation | Science-based portfolio targets with independent validation |
| 5 | GFANZ / NZBA | Commitment + transition planning | Net-zero banking alliance with sector guidance |
| 6 | NGFS Climate Scenarios | Scenario design | Macroeconomic climate scenarios for stress testing |
| 7 | TCFD / IFRS S2 | Disclosure standard | Climate-related financial disclosure requirements |

**Note on IFC Performance Standards / Equator Principles:** These are project-level E&S due diligence frameworks, not portfolio alignment tools. They complement the 7 frameworks above but operate at the transaction level rather than the portfolio level. They are discussed in the framework comparison document under "Other Frameworks."

---

## 1. PACTA for Banks

**Purpose:** Assess whether a financial portfolio's real-economy exposure to climate-relevant sectors is aligned with Paris Agreement scenarios. Answers: "Is my portfolio building too much coal and not enough renewables compared to what climate science says we need?"

**Methodology type:** Portfolio alignment analysis. Uses asset-level company data (ABCD) matched to a loanbook, then compares portfolio production/technology mix against scenario pathways (IEA NZE, NDC, national plans) using two methods: Market Share (for sectors with production targets like power) and Sectoral Decarbonization Approach / SDA (for emission-intensity sectors like cement and steel).

**Data inputs:**
- Loanbook with counterparty names, exposure amounts, and sector codes (ISIC/NACE)
- Asset-level company data (ABCD): production capacity by technology, company-level emissions
- Climate scenario data: market-share pathways and/or emission-intensity targets
- Region mapping (ISO codes)
- Open-source R packages: `r2dii.data`, `r2dii.match`, `r2dii.analysis`, `r2dii.plot`

**Sector coverage (thermal power, steel, cement):**
- **Thermal power:** Full coverage — `coalcap`, `gascap`, and renewable technologies. Market-share method.
- **Steel:** Full coverage — `open_hearth`, `electric` (EAF). SDA method.
- **Cement:** Full coverage — `integrated facility`. SDA method.
- Also covers: automotive, aviation, shipping, fossil fuel extraction.

**Output types:**
- Technology mix charts (portfolio vs. scenario target)
- Trajectory charts (coal phase-down, renewables buildout, EV adoption)
- Emission intensity charts (cement, steel vs. SDA targets)
- Alignment summary tables (gap percentages by sector/technology)
- Company-level match coverage reports

**Implementation complexity:** Medium. Requires R environment, data preparation (loanbook + ABCD), and understanding of PACTA methodology. The `r2dii.*` packages are well-documented with an official cookbook. Biggest challenge for Vietnamese banks: obtaining asset-level company data for Vietnamese borrowers (ABCD coverage is global but thinner for emerging markets).

**Cost:** Free and open-source. No licensing fees. Costs are internal: staff time for data preparation, pipeline execution, and interpretation.

**Open-source availability:** Full stack is open-source R packages on CRAN. Source code on GitHub. Official documentation at 2degrees-investing.org. PACTA for Banks web platform also available (free registration).

**Time to first results:** 1–3 months from data preparation to alignment analysis. Faster if loanbook data is clean and ABCD coverage is good.

**Vietnam relevance:** High. PACTA works with any jurisdiction's data — it is not region-locked. Vietnam-specific scenarios (PDP8, NDC) can be used alongside global benchmarks (IEA NZE). The VSIC→ISIC→PACTA sector mapping is straightforward since VSIC 2018 is structurally ISIC Rev.4. Challenge: ABCD data coverage for Vietnamese companies is thinner than for OECD markets.

**Maturity/institutional adoption:** 1,500+ institutions use PACTA globally, including central banks (Bank of England, ECB, MAS), commercial banks, and asset owners. 2° Investing Initiative (now Climate Policy Initiative) has been developing PACTA since 2017. Strong track record in ASEAN: MAS (Singapore), Bank Indonesia, and several commercial banks in the region have used PACTA for portfolio analysis.

**Sources:**
- [PACTA for Banks](https://www.pacta-for-banks.org/)
- [2° Investing Initiative / r2dii packages](https://2degrees-investing.org/)
- [PACTA Cookbook](https://r2dii.github.io/pacta.cookbook/)

---

## 2. TRISK

**Purpose:** Quantify the financial impact of climate transition scenarios on individual borrowers' creditworthiness. Answers: "If policy tightens or carbon prices rise, how much will my borrowers' NPV and probability of default change?" Complements PACTA (which measures alignment) by translating misalignment into financial risk metrics.

**Methodology type:** Transition stress testing. Uses discounted cash flow (DCF) models to estimate how scenario-driven changes (carbon prices, commodity prices, policy timing) affect borrower-level NPV and probability of default (PD). Applies Merton model for PD estimation. One-at-a-time sensitivity analysis available for key parameters.

**Data inputs:**
- Asset-level data: production capacity by technology, operating costs, revenue projections
- Scenario data: baseline and stress scenarios with carbon price curves, commodity price paths
- Financial features: discount rate, risk-free rate, market passthrough, shock year
- R package: `trisk.model` (CRAN)

**Sector coverage (thermal power, steel, cement):**
- **Thermal power:** Full coverage — coal, gas, hydro, solar, wind, nuclear. DCF-based NPV and PD estimation.
- **Steel:** Coverage via emission-intensity pathways — SDA-to-TRISK translation (CO2 intensity as shock variable).
- **Cement:** Coverage via emission-intensity pathways — same approach as steel.
- Automotive: Out of scope for current TRISK implementation.

**Output types:**
- Borrower-level NPV change (baseline vs. stress)
- Borrower-level PD change (baseline vs. stress)
- Priority score ranking (composite of alignment gap + stress severity)
- Sensitivity analysis results (one parameter at a time)
- Company-level figures (NPV/PD change charts)

**Implementation complexity:** Medium-high. Requires understanding of DCF modeling, Merton model assumptions, and TRISK's folder-based input contract. The `trisk.model` package is on CRAN but documentation is limited compared to PACTA. Biggest challenge: generating realistic financial features for borrowers (revenue projections, operating costs) — these are typically estimated or synthetic in demo contexts.

**Cost:** Free and open-source (R package on CRAN). No licensing fees. Costs are internal: staff time for input preparation, model execution, and interpretation.

**Open-source availability:** `trisk.model` package on CRAN. Source code available. Academic paper: Baer et al. (2022) "TRISK: A framework for climate transition risk assessment."

**Time to first results:** 2–4 months from data preparation to stress-test outputs. Requires PACTA alignment outputs as upstream input for the full analytical narrative.

**Vietnam relevance:** Moderate-high. TRISK works with any sector and jurisdiction but requires realistic financial data for Vietnamese borrowers. The package's built-in carbon tax scenarios (e.g., `increasing_carbon_tax_50`) are useful for demo stress behavior but are not Vietnam policy forecasts. Vietnam-specific carbon price curves (e.g., from NGFS EMDE scenarios) would improve credibility.

**Maturity/institutional adoption:** Academic framework (Baer et al., 2022) with a working R package. Less institutional adoption than PACTA — primarily used in research and pilot contexts. The PACTA-TRISK integration (alignment + stress testing) is novel and not yet widely deployed commercially.

**Sources:**
- [trisk.model on CRAN](https://cran.r-project.org/package=trisk.model)
- Baer, M. et al. (2022). "TRISK: A framework for climate transition risk assessment."

---

## 3. PCAF (Partnership for Carbon Accounting Financials)

**Purpose:** Standardized GHG emissions accounting for financial institutions. Answers: "What is the carbon footprint of my loan/investment portfolio?" Foundation layer — you must measure before you can set targets or assess alignment.

**Methodology type:** Emissions accounting (Scope 3, Category 15 — financed emissions). Uses attribution factor: `outstanding_amount / enterprise_value_plus_debt` to allocate borrower emissions to the financier. Built on GHG Protocol. Not target-setting — purely measurement.

**Data inputs:**
- Loan/investment book data (outstanding amounts, asset class)
- Borrower-level emissions data (Scope 1+2, some Scope 3)
- Sector classification (NACE/ISIC)
- PCAF emission factor database (physical & economic activity-based)
- Data quality scored 1–5

**Sector coverage (thermal power, steel, cement):**
- **All three covered** through business loans and project finance asset classes.
- 6 core asset classes: listed equity & corporate bonds, business loans & unlisted equity, project finance, commercial real estate, mortgages, motor vehicle loans.
- Any sector where borrower emissions data exists is covered.

**Output types:**
- Financed emissions inventory (tCO2e)
- Emissions intensity metrics (tCO2e per $M revenue or per physical unit)
- Data quality scores
- PCAF-aligned disclosure reports
- Input to: SBTi target-setting, PACTA scenario analysis, TCFD/ISSB disclosures

**Implementation complexity:** Medium. Requires GHG accounting capability, loan book data mapping, access to borrower emissions data (or use of PCAF database/proxies). Free tools, templates, and PCAF Academy e-learning platform available. Biggest challenge for Vietnamese banks: borrower emissions data availability (many SMEs don't report).

**Cost:** Free to join (no membership fee). Sign the commitment letter. Costs are internal: staff time for data collection, calculation, and disclosure. PCAF Database access included for signatories.

**Open-source availability:** Standard is free and open (PDF download). PCAF Database is free for signatories. Methodology is transparent. No proprietary software — can be implemented in Excel, R, or any system.

**Time to first results:** 3–6 months for a first financed emissions calculation with available data. First full disclosure: 6–12 months. Depends heavily on data availability from borrowers.

**Vietnam relevance:** High. PCAF has regional implementation teams in Asia. Methodology works for any jurisdiction. Vietnamese banks can use it to comply with emerging SBV green credit guidelines and international investor expectations. Challenge: Vietnamese corporate emissions data is sparse; will need to use PCAF database proxies or estimated data (lower data quality scores).

**Maturity/institutional adoption:** 700+ signatories globally, 250+ published disclosures. Growing rapidly in Asia (PCAF Japan, PCAF India active). Backed by major global banks. Well-established methodology (v3 Part A published 2025). Used as the accounting foundation by SBTi, NZBA, and PACTA.

**Sources:**
- [PCAF Standard](https://carbonaccountingfinancials.com/en/standard)
- [PCAF Part A v3 (2025)](https://carbonaccountingfinancials.com/files/standard-launch-2025/PCAF-PartA-2025-V3-15012026.pdf)
- [Join PCAF](https://carbonaccountingfinancials.com/en/join-pcaf)

---

## 4. SBTi Financial Institutions

**Purpose:** Target-setting framework with independent validation. Answers: "What emissions reduction targets should my lending/investment portfolio have to be Paris-aligned?" Provides credibility signal via third-party validation.

**Methodology type:** Target-setting with validation. Uses: (a) Sectoral Decarbonization Approach (SDA) — allocates sector carbon budgets to portfolios; (b) Portfolio Temperature Rating — implied temperature rise scoring; (c) Climate Alignment Targets — % of portfolio aligned with net-zero pathways. Requires PCAF-style financed emissions as input. Two pathways: Near-Term Criteria (10-year targets) and Net-Zero Standard (full net-zero by 2050).

**Data inputs:**
- Financed emissions inventory (PCAF-aligned)
- Portfolio composition by sector
- Counterparty-level emissions and reduction targets
- Sector-specific data (for power, steel, cement — requires physical activity data)
- Scenario pathway data (IEA NZE, etc.)
- FINZ Target-Setting Tool (Excel) provided

**Sector coverage (thermal power, steel, cement):**
- **All three have dedicated SBTi sector methodologies.**
- Power: Quick Start Guide for Electric Utilities; Net-Zero Standard in draft.
- Steel: Full 1.5°C Guidance + Target-Setting Tool published 2023.
- Cement: Full 1.5°C Guidance + Corporate Near-Term Tool integration published 2022.

**Output types:**
- Validated science-based targets (near-term and/or long-term)
- Public commitment and SBTi dashboard listing
- Progress reporting requirements
- Targets can be: absolute emissions reduction, portfolio intensity targets, climate alignment targets (% aligned), counterparty engagement targets

**Implementation complexity:** High. Requires robust financed emissions accounting (PCAF), sector-level portfolio analysis, target modeling using SBTi tools, counterparty engagement strategy, ongoing monitoring and recalculation. Validation process is rigorous. For a Vietnamese bank: need dedicated climate/sustainability team, data infrastructure, and likely external advisory support.

**Cost:** Validation fees via SBTi Services (for-profit subsidiary): approximately USD 10,000–50,000+ for target validation (scales by revenue). Additional costs: internal staff time, data systems, potential advisory/consulting fees. Annual reporting costs ongoing.

**Open-source availability:** Standards, guidance, and tools are free (PDF + Excel downloads). Target-Setting Tools (FINZ Tool, Corporate Near-Term Tool, Steel Tool) are free Excel files. Validation service is paid. Finance Temperature Rating tool is open-source on GitHub.

**Time to first results:** 6–18 months from data prep to validated targets. Timeline: emissions inventory (3–6 mo) → target modeling (2–4 mo) → submission → validation review (3–6 mo).

**Vietnam relevance:** Moderate-high. 180+ FIs globally have validated targets (growing in Asia). SBTi standards are globally applicable. Challenges: (a) data quality — Vietnamese corporates rarely have verified emissions data; (b) many Vietnamese steel/cement/power companies lack SBTi targets themselves, making counterparty engagement harder; (c) cost of validation may be significant. Opportunity: early mover advantage in Vietnam's banking sector. SBTi FI Net-Zero Standard launched July 2025 — very new, still being adopted.

**Maturity/institutional adoption:** Near-Term Criteria V2 (May 2024): 180+ FIs with validated targets. Net-Zero Standard (July 2025): newly launched, still early adoption (pilot tested by 33 FIs). Strong institutional backing (CDP, WRI, WWF, UN Global Compact). ASEAN presence: growing but still limited — most adopters are European, North American, and Japanese banks.

**Sources:**
- [SBTi Financial Institutions](https://sciencebasedtargets.org/financial-institutions)
- [FI Net-Zero Standard (July 2025)](https://files.sciencebasedtargets.org/production/files/Financial-Institutions-Net-Zero-Standard.pdf)
- [Validation services](https://sbtiservices.com/)
- [Steel Guidance](https://sciencebasedtargets.org/sectors/steel)
- [Cement Guidance](https://sciencebasedtargets.org/sectors/cement)

---

## 5. GFANZ / NZBA (Net-Zero Banking Alliance)

**Purpose:** Commitment + target-setting + transition planning alliance for banks. Answers: "How do I commit to, plan for, and execute a net-zero transition across my banking book?" Provides governance framework, peer learning, and sector-specific guidance. Not a validation body — self-reported with progress reviews.

**Methodology type:** Framework/guidelines (not prescriptive). Banks set their own targets using chosen methodologies (SBTi, PACTA, IEA pathways, etc.). NZBA provides: Guidelines for Climate Target Setting for Banks (v4, Oct 2025), sector papers, transition finance guidance, transition planning guidance. Relies on IEA NZE and NGFS scenarios as reference pathways.

**Data inputs:**
- Similar to SBTi: financed emissions, portfolio composition, sector-level data, scenario pathway data
- Banks choose their own tools
- NZBA guidance recommends PCAF for emissions accounting and references SBTi, PACTA, and other methodologies as eligible approaches

**Sector coverage (thermal power, steel, cement):**
- **All three have dedicated NZBA sector guidance papers.**
- Power Generation (Oct 2024), Steel (May 2024), Cement (Jan 2026).
- Each paper includes methodologies, metrics, and scenario recommendations.

**Output types:**
- Public net-zero commitment
- Interim 2030 targets
- Transition plans
- Annual progress reports
- Not validated — self-reported with peer review through NZBA governance

**Implementation complexity:** Medium-high. Less prescriptive than SBTi (more flexibility in methodology choice) but requires robust internal capability for target setting, transition planning, client engagement, transition finance, progress reporting. UNEP FI provides guidance, templates, and peer learning.

**Cost:** UNEP FI membership required (fee-based, scales by institution size). No separate NZBA fee. Internal costs: staff time, data systems, potential advisory support. Generally lower than SBTi validation costs but membership fees apply.

**Open-source availability:** All guidance papers, reports, and tools are free to download. No proprietary software. Methodologies reference open scenarios (IEA, NGFS). UNEP FI Climate Pathways Navigator tool available.

**Time to first results:** 6–12 months to set targets and publish a transition plan. Faster than SBTi validation because there's no external validation bottleneck.

**Vietnam relevance:** High. UNEP FI has an Asia Pacific regional team and active engagement in Southeast Asia. NZBA has ~150 member banks globally (~USD 53 trillion in assets). More flexible than SBTi — banks can use methodologies appropriate to their data maturity. Key advantage for BIDV: can start with commitment and build targets progressively; peer learning with other emerging market banks.

**Maturity/institutional adoption:** ~150 member banks globally. Established 2021. Annual progress reports published (2022, 2023, 2024). Strong institutional backing (UNEP FI). ASEAN presence: several Southeast Asian banks are members or supporters. Growing but still dominated by large global banks.

**Sources:**
- [UNEP FI Net-Zero Banking Resources](https://www.unepfi.org/net-zero-banking/)
- NZBA sector papers: Power (Oct 2024), Steel (May 2024), Cement (Jan 2026)

---

## 6. NGFS Climate Scenarios

**Purpose:** Provide a common set of forward-looking climate scenarios for central banks and supervisors to assess climate-related financial risks. Bridges the gap between climate science (IPCC/IEA pathways) and financial risk modeling. Used for both supervisory stress testing and internal bank risk management.

**Methodology type:** Scenario design and stress testing. Not a disclosure standard — it provides the *inputs* (macroeconomic and financial variables under different climate pathways) that feed into stress testing models. Six core scenarios spanning orderly transition, disorderly transition, and hot house world outcomes, plus a "Net Zero 2050" scenario aligned with IEA NZE.

**Data inputs:**
- Global macroeconomic variables: GDP, inflation, interest rates, carbon prices, energy prices
- Sector-specific transition variables (power, industry, transport, buildings)
- Physical risk variables: temperature, precipitation, sea level, extreme weather frequency
- Country/region-level breakdowns (including EMDE profiles)
- Financial variables: equity prices, credit spreads, property values

**Sector coverage (thermal power, steel, cement):**
- Covers all major emitting sectors explicitly.
- Scenario variables include carbon prices, energy mix shifts, demand destruction, and technology cost curves that directly impact thermal power, steel, and cement.
- Mapped to IEA World Energy Outlook pathways with granular sectoral detail.

**Output types:**
- Macroeconomic projections (GDP, inflation under each scenario)
- Financial risk metrics: PD/LGD shifts, credit losses, market value impacts
- Transition risk indicators: stranded asset estimates, carbon price trajectories
- Physical risk loss estimates
- Not a portfolio alignment output — feeds *into* tools like PACTA for alignment analysis

**Implementation complexity:** High. Requires macroeconomic modeling capability or access to NGFS scenario data, ability to map scenario variables to bank-specific portfolio exposures, statistical/actuarial capacity to translate macro shocks into credit risk parameters. Typically requires dedicated climate risk team + external modeling support.

**Cost:** Scenario data: Free (open access via NGFS Scenarios Portal). Implementation: $200K–$2M+ depending on approach. Advisory support (Big 4, specialist firms): $100K–$500K for initial setup.

**Open-source availability:** Scenario data and documentation are fully open and free at NGFS Scenarios Portal. No open-source *implementation* tools — banks must build or buy the modeling layer.

**Time to first results:** 6–12 months for basic supervisory-grade stress test. 12–24 months for fully integrated portfolio-level climate stress testing.

**Vietnam relevance:** High and growing. SBV has issued directives on environmental risk management (Decision 1604/QD-NHNN, 2023). NGFS member institutions include Bank Indonesia, Bangko Sentral ng Pilipinas, and MAS — regional momentum is building. NGFS scenarios include an EMDE profile relevant to Vietnam's energy transition trajectory. Vietnam is not yet an NGFS member but SBV observers NGFS outputs closely.

**Maturity/institutional adoption:** Very high globally. 150+ central banks and supervisors are NGFS members. Used by ECB, Bank of England, MAS, and others for supervisory stress tests. Phase V (latest) released 2024 with improved country-level granularity. ASEAN adoption growing: MAS, BI, BSP all use NGFS scenarios.

**Sources:**
- [NGFS Homepage](https://www.ngfs.net/en)
- [NGFS Scenarios Portal](https://www.ngfs.net/ngfs-scenarios-portal/)
- [NGFS Scenario Design and Analysis](https://www.ngfs.net/en/what-we-do/scenario-design-and-analysis)

---

## 7. TCFD / IFRS S2

**Purpose:** TCFD (disbanded Oct 2023) established the foundational four-pillar framework for climate-related financial disclosure. Its work was fully incorporated into IFRS S2 by the ISSB. IFRS S2 creates a global baseline for investor-focused climate disclosures. For banks, this creates direct demand for portfolio-level analytical outputs (financed emissions, alignment metrics, scenario analysis results) that tools like PACTA/TRISK can provide.

**Methodology type:** Disclosure standard (not stress testing or accounting). Requires narrative + quantitative disclosures across four pillars: Governance, Strategy, Risk Management, Metrics & Targets. Requires Scope 1, 2, and Scope 3 Category 15 (financed emissions) disclosure. Requires scenario analysis for the Strategy pillar.

**Data inputs:**
- Scope 1, 2, and Scope 3 Category 15 (financed emissions) — key demand driver for PACTA/TRISK
- Climate scenario analysis results (often using NGFS scenarios)
- Portfolio alignment metrics (temperature alignment, production vs. scenario benchmarks)
- Transition plan details and capital allocation data
- Physical risk exposure data (asset-level location data)
- Governance and risk management process documentation

**Sector coverage (thermal power, steel, cement):**
- IFRS S2 requires industry-based metrics using SASB Standards.
- For banks, this includes sector-level financed emissions disclosure.
- SASB Commercial Banks standard covers exposure to thermal power (coal-fired generation), steel, cement, plus oil & gas, automotive, agriculture, real estate.

**Output types:**
- Annual sustainability/climate disclosure reports (integrated into financial filings)
- Financed emissions disclosures (tCO2e by sector, by counterparty)
- Scenario analysis narratives and quantitative results
- Transition plan disclosures
- Not a calculation tool — it *demands* outputs that other tools (PACTA, PCAF, NGFS-based models) produce

**Implementation complexity:** Medium to High for financed emissions and scenario analysis components. Data collection from borrowers (especially Scope 3) is the biggest challenge. Requires emissions factor databases, portfolio mapping, and calculation methodologies (PCAF standard). Scenario analysis capability needed for the Strategy pillar.

**Cost:** Standard itself: Free. Non-commercial use: Free (no license required). Implementation: $100K–$500K for data systems, consulting, and first-year reporting. Ongoing: $50K–$200K/year. Advisory (Big 4 climate disclosure practice): $150K–$400K for first-year readiness.

**Open-source availability:** IFRS S2 standard text: Free via IFRS Sustainability Standards Navigator. SASB Standards: Free under IFRS Foundation stewardship. TCFD recommendations (legacy): Still available at fsb-tcfd.org. Implementation guidance: Free at IFRS Knowledge Hub.

**Time to first results:** Basic governance/strategy narrative disclosure: 3–6 months. Full financed emissions calculation + scenario analysis: 9–18 months. First complete IFRS S2-aligned report: 12–24 months.

**Vietnam relevance:** Very high and accelerating. SBV has issued the Green Taxonomy (Decision 1604/QD-NHNN, 2023) — a prerequisite for ISSB-aligned disclosure. Vietnam's securities regulator (SSC) is moving toward mandatory sustainability disclosure for listed companies, with ISSB alignment under consideration. BIDV, as Vietnam's largest state-owned commercial bank, faces increasing pressure from international investors and correspondent banks to disclose climate risks. IFRS Foundation has a Partnership Framework for Capacity Building to support emerging markets in ISSB adoption.

**Maturity/institutional adoption:** TCFD was the dominant framework (10+ years, 5,000+ supporters) before disbanding in Oct 2023. IFRS S2: Issued June 2023. Jurisdictional adoption underway in 30+ countries including UK, Japan, Canada, Australia, Singapore, Malaysia, and Brazil. In ASEAN: Singapore (SGX mandatory from FY2025), Malaysia (Bursa mandatory phased from 2025), Thailand (SET voluntary → mandatory pathway). Vietnam: Not yet mandated, but SBV green taxonomy and SSC sustainability reporting roadmap signal direction of travel.

**Sources:**
- [ISSB and TCFD (IFRS Foundation)](https://www.ifrs.org/sustainability/tcfd/)
- [IFRS Sustainability Standards Navigator](https://www.ifrs.org/issued-standards/ifrs-sustainability-standards-navigator/)
- [IFRS S2 Around the World](https://www.ifrs.org/ifrs-sustainability-disclosure-standards-around-the-world/)

---

## Cross-Framework Relationships

```
PCAF (Accounting) → PACTA (Alignment) → TRISK (Stress Testing) → IFRS S2 (Disclosure)
       ↓                  ↓                    ↓                      ↓
  "What are my      "Is my portfolio     "What is the          "How do I report
  emissions?"        aligned?"           financial impact?"    to investors?"

GFANZ/NZBA (Commitment + Transition Planning) — wraps around all layers
NGFS Scenarios — provides scenario inputs for PACTA, TRISK, and IFRS S2 scenario analysis
SBTi FI (Target-Setting + Validation) — sits between PCAF and PACTA
```

- **PCAF is the foundation**: Both SBTi FI and NZBA expect/require PCAF-aligned emissions accounting as input.
- **PACTA measures alignment** against scenarios; **TRISK translates misalignment into financial risk** (NPV/PD).
- **SBTi FI and NZBA are complementary**: A bank can join NZBA (commitment + guidance) AND submit targets for SBTi validation (credibility signal).
- **IFRS S2 creates the demand** for all upstream analytical outputs — it requires scenario analysis, financed emissions, and transition plan disclosures.
- **NGFS provides the scenario inputs** that feed into PACTA alignment analysis, TRISK stress testing, and IFRS S2 scenario analysis narratives.

---

## Other Frameworks (Not Evaluated in Matrix)

| Framework | Relevance | Why Not in Matrix |
|---|---|---|
| Transition Pathway Initiative (TPI) | Moderate — provides sector-level transition assessments | Overlaps with PACTA's alignment function; less bank-specific |
| Carbon Tracker Carbon Budget Analysis | Moderate — stranded asset analysis for fossil fuels | Narrower scope (fossil fuels only); not a portfolio tool |
| IFC Performance Standards / Equator Principles | High for project finance — E&S due diligence | Project-level, not portfolio-level; complements but does not replace portfolio tools |
| UNEP FI TCFD Banking Pilots | Moderate — TCFD implementation guidance for banks | Subsumed by IFRS S2; not a standalone analytical framework |

---

*This research brief serves as the evidence base for `docs/bidv_framework_comparison.md` (GAP-02). All framework entries include consistent dimensions for scored comparison. Sources are cited with URLs where publicly accessible.*

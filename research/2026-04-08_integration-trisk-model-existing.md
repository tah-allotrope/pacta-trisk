# Research Brief: Integrating TRISK Into PACTA Vietnam

**Date:** 2026-04-08
**Modes run:** domain, codebase, math, literature
**Invocation context:** invoke research skill mode all regarding integration of trisk model into existing work with pacta with a guide section on practical use given methodology pdf in `docs/Baer_TRISK_2022.pdf` and DeepWiki at `https://deepwiki.com/2DegreesInvesting/trisk.model`

---

## Synthesis
TRISK is a good conceptual next layer for this repository because it does something the current PACTA Vietnam work does not yet do: it converts sector alignment and production-pathway misalignment into firm-value and credit-risk stress outputs such as NPV change, Value at Risk, and Probability of Default change. The Baer et al. methodology and the package docs are explicit that TRISK is designed as a bottom-up, forward-looking stress test built on asset-level data and is meant to sit downstream of a PACTA-style matching and trajectory setup, not replace it. (Local repo: `scripts/pacta_vietnam_scenario.R`; https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; https://deepwiki.com/2DegreesInvesting/trisk.model/1-overview)

The strongest fit in this repo is the Vietnam power workflow. Your current project already has borrower matching, company identifiers, sector and technology production trajectories, company-level market-share outputs, and custom Vietnam scenarios. Those are the hardest PACTA-side ingredients to create, and they map naturally into TRISK's production-side inputs. The biggest missing pieces are not alignment math but stress-test inputs: company financial features (`pd`, `net_profit_margin`, `debt_equity_ratio`, `volatility`), scenario price paths, carbon price paths, and some schema harmonization between your lowercase PACTA naming and TRISK's input contracts. (Local repo: `data/vietnam_abcd.csv`, `data/vietnam_scenario_ms.csv`, `data/vietnam_scenario_co2.csv`, `synthesis_output/vietnam/04_vn_ms_company.csv`; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)

[NOTE] There are effectively two public TRISK code lines visible in the sources. The DeepWiki and `2DegreesInvesting/trisk.model` repository describe an older folder-and-CSV workflow under the `r2dii.climate.stress.test` naming, while the public pkgdown site under Theia Finance Labs documents a newer `trisk.model` interface centered on four data frames: `assets`, `financial_features`, `ngfs_carbon_price`, and `scenarios`. For this repo, the lowest-friction practical path is to build a bridge script to the older folder-based interface first because your current outputs already look close to its `production_data` contract; after that, you can decide whether to migrate the bridge to the newer Theia interface. (https://deepwiki.com/2DegreesInvesting/trisk.model/1.1-getting-started; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R; https://theia-finance-labs.github.io/trisk.model/; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html)

---

## Domain

TRISK is not another alignment metric; it is a transition-risk stress-test layer. The paper defines TRISK as the expected loss a financial institution may suffer under the uncertain materialization of a transition stress scenario, while also reporting firm-level NPV and PD changes between baseline and stress scenarios. That makes it complementary to your current repo, which today stops at PACTA-style alignment views and sector gap reporting. (https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; `scripts/pacta_vietnam_scenario.R`; `scripts/pacta_demo.R`)

The package and paper both position TRISK as downstream of PACTA or comparable ALD workflows. The prerequisite language is explicit: users are expected to have already run at least the matching part of PACTA for Banks and prepared project-specific raw inputs before running TRISK. In other words, your current repo is already solving the right upstream problem. (https://deepwiki.com/2DegreesInvesting/trisk.model/1.1-getting-started; https://2degreesinvesting.github.io/r2dii.climate.stress.test/articles/02-run-stress-test.html; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/README.md)

For practical use in this repo, TRISK should be treated as a second-stage risk module with this decision framing:

1. Use PACTA to answer: "Which sectors, technologies, and companies are misaligned?" (Local repo: `scripts/pacta_vietnam_scenario.R`, `synthesis_output/vietnam/04_vn_ms_company.csv`)
2. Use TRISK to answer: "If a disorderly transition hits in year X under scenario Y, how much firm value and credit quality deteriorate?" (https://deepwiki.com/2DegreesInvesting/trisk.model/3-core-stress-test-model; https://deepwiki.com/2DegreesInvesting/trisk.model/4-risk-quantification)
3. Use both together for portfolio action: exposure reduction, engagement prioritization, sector limits, and sensitivity analysis over shock timing and financial assumptions. (https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; https://deepwiki.com/2DegreesInvesting/trisk.model/5-outputs-and-sensitivity-analysis)

The most natural pilot is power, not the whole Vietnam repo at once. Baer et al.'s exploratory application is power-sector based, and your local Vietnam data is deepest in power with named coal, gas, hydro, solar, and wind borrowers already modeled through 2030. That minimizes methodology drift during first integration. (https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; `data/vietnam_abcd.csv`; `data/vietnam_loanbook.csv`)

## Codebase

### Fit With Current Repo

This repo already contains several inputs that are structurally close to TRISK requirements:

- `data/vietnam_abcd.csv` already has `company_id`, `name_company`, `sector`, `technology`, `year`, `production`, and `emission_factor`, which is enough to serve as the backbone for a TRISK production/assets bridge. (Local repo: `data/vietnam_abcd.csv`; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html)
- `synthesis_output/vietnam/04_vn_ms_company.csv` already shows company-level scenario results by `sector`, `technology`, `year`, `region`, `scenario_source`, `name_abcd`, and `metric`, which means the repo already materializes firm-level forward-looking pathways instead of only portfolio aggregates. (Local repo: `synthesis_output/vietnam/04_vn_ms_company.csv`)
- `data/vietnam_scenario_ms.csv` and `data/vietnam_scenario_co2.csv` encode custom Vietnam pathways, which is important because the paper stresses jurisdiction-specific calibration for practical relevance. (Local repo: `data/vietnam_scenario_ms.csv`, `data/vietnam_scenario_co2.csv`; https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk)

The main gaps are equally clear:

- The repo does not currently store company financial features in the form TRISK expects: `pd`, `net_profit_margin`, `debt_equity_ratio`, and `volatility`. Those are mandatory in both the old 2DII workflow and the newer Theia interface. (Local repo: `data/vietnam_loanbook.csv`, `data/vietnam_abcd.csv`; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html)
- The repo has alignment scenarios but not TRISK-style commodity price curves or NGFS carbon price tables. The older reader expects `price_data_long.csv` and `ngfs_carbon_price.csv`; the newer interface expects `scenarios` plus `ngfs_carbon_price`. (https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html)
- The local naming is PACTA-oriented and lowercase (`power`, `automotive`, `coalcap`, `renewablescap`, `electric`), while public TRISK examples use different sector and technology vocabularies (`Power`, `Coal`, `Gas`, etc.). A deterministic mapping layer will be needed. (Local repo: `data/vietnam_abcd.csv`, `data/vietnam_scenario_ms.csv`; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html)

### Old vs New TRISK Interface

The older 2DII code path reads six CSVs from disk: capacity factors, price data, scenario data, financial data, production data, and carbon price data. That interface is spelled out directly in `st_read_agnostic()`. (https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)

The newer Theia docs describe a simplified four-dataframe interface:

- `assets`
- `financial_features`
- `ngfs_carbon_price`
- `scenarios`

That is simpler conceptually, but the old interface is a better first target for this repo because your current outputs already look close to old `production_data` with `company_id`, company name, sector, business unit, year, production, and emission factor. (https://theia-finance-labs.github.io/trisk.model/; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)

### Practical Integration Guide

The most practical integration sequence for this repository is:

1. Stabilize the upstream Vietnam PACTA script so the company-level trajectories are reproducible through the chosen horizon; TRISK is only as credible as the forward production paths it consumes. (Local repo: `scripts/pacta_vietnam_scenario.R`)
2. Add a bridge script, e.g. `scripts/trisk_prepare_inputs.R`, that writes a TRISK-ready input folder from current repo outputs instead of asking analysts to hand-build files. The bridge should emit at minimum `abcd_stress_test_input.csv`, `prewrangled_financial_data_stress_test.csv`, `Scenarios_AnalysisInput.csv`, `price_data_long.csv`, `ngfs_carbon_price.csv`, and `prewrangled_capacity_factors.csv` if you target the legacy 2DII workflow. (https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)
3. Build the first bridge around power only. Your current Vietnam power data already includes coal, gas, hydro, and renewables trajectories, and the paper's first proof-of-concept is also power. That keeps the first run close to the published methodology. (Local repo: `data/vietnam_abcd.csv`, `data/vietnam_scenario_ms.csv`; https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk)
4. Introduce a separate company financial feature table keyed by `company_id` with `pd`, `net_profit_margin`, `debt_equity_ratio`, and `volatility`. This is the single biggest missing dependency today. If real vendor data is unavailable, create transparent placeholder assumptions for a sandbox run and label them as such. (https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/vignettes/articles/03-advanced-data-settings.Rmd)
5. Treat local PDP8/NDC/NZE pathways as the transition story, but supplement them with external price and carbon-tax curves. The current repo has market-share and CO2-intensity pathways, not the market price and carbon price inputs TRISK uses for profit shocks. (Local repo: `data/vietnam_scenario_ms.csv`, `data/vietnam_scenario_co2.csv`; https://deepwiki.com/2DegreesInvesting/trisk.model/3-core-stress-test-model; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)
6. Run sensitivity analysis from day one on `shock_year`, `discount_rate`, `risk_free_rate`, and `market_passthrough`, because both the paper and the package emphasize uncertainty and one-parameter-at-a-time sensitivity as core use, not optional polish. (https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; https://deepwiki.com/2DegreesInvesting/trisk.model/5-outputs-and-sensitivity-analysis; https://2degreesinvesting.github.io/r2dii.climate.stress.test/articles/02-run-stress-test.html)

### Minimal Mapping Proposal

For a first bridge, the mapping can be intentionally narrow:

- Local `company_id` -> TRISK `company_id` (Local repo: `data/vietnam_abcd.csv`)
- Local `name_company` -> TRISK `company_name` (Local repo: `data/vietnam_abcd.csv`)
- Local `sector` -> TRISK `ald_sector` or `sector` after controlled vocabulary mapping (Local repo: `data/vietnam_abcd.csv`; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)
- Local `technology` -> TRISK `ald_business_unit` or `technology` after controlled vocabulary mapping (Local repo: `data/vietnam_abcd.csv`; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html)
- Local `year` -> TRISK production/scenario year (Local repo: `data/vietnam_abcd.csv`, `data/vietnam_scenario_ms.csv`)
- Local `production` -> TRISK `plan_tech_prod` in the legacy interface (Local repo: `data/vietnam_abcd.csv`; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)
- Local `emission_factor` -> TRISK `plan_emission_factor` or asset `emission_factor` (Local repo: `data/vietnam_abcd.csv`; https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R)
- Local `plant_location = VN` -> TRISK `scenario_geography` or `country_iso2 = VN` depending on target interface (Local repo: `data/vietnam_abcd.csv`; https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html)

## Math

The paper structures the methodology in three layers: scenarios, economy, and financial system. Transition shocks alter production, costs, market shares, and stranded-asset exposure at firm level; those effects are then translated into asset value and credit risk. This layered design is exactly why TRISK belongs after PACTA-style scenario alignment, not inside the matching step itself. (https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; `docs/Baer_TRISK_2022.pdf`)

At the firm level, the economic core is discounted cash flow. Asset value is the discounted sum of expected profits plus terminal value, with profits driven by revenues minus costs, and revenues and costs themselves changing under scenario pathways, market prices, carbon costs, pass-through, and technology effects. The package mirrors this with `calculate_trisk_trajectory()`, `calculate_net_profits()`, and `calculate_annual_profits()`. (https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/calculate.R; https://deepwiki.com/2DegreesInvesting/trisk.model/3-core-stress-test-model; `docs/Baer_TRISK_2022.pdf`)

The market-risk output is NPV-based VaR. In the implementation, VaR is calculated from the relative change between discounted NPV in the late-and-sudden scenario and the baseline scenario, scaled by `div_netprofit_prop_coef` and `flat_multiplier`. In the paper's notation, firm-level TRISK can be written as stress NPV minus baseline NPV. (https://deepwiki.com/2DegreesInvesting/trisk.model/4.1-asset-value-at-risk-(npv-var); https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/company_technology_asset_value_at_risk.R; `docs/Baer_TRISK_2022.pdf`)

The credit-risk output is structural, not reduced-form. The package reconstructs debt from baseline equity and `debt_equity_ratio`, treats equity as a call-option-like residual claim, and then computes survival probabilities and PD changes with a Merton-style model over a 1-to-5-year term structure. This is why `debt_equity_ratio` and `volatility` are not optional metadata but core mathematical inputs. (https://deepwiki.com/2DegreesInvesting/trisk.model/4.2-probability-of-default-change-(merton-model); https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/calc_pd_change_overall.R; `docs/Baer_TRISK_2022.pdf`)

The most important mathematical caveat for practical use is interpretation. The paper explicitly warns that TRISK-related PD changes should not be read as ordinary one-year default probabilities; they are horizon-spanning shock summaries over a long-dated transition scenario. It also notes scenario-independent volatility and Merton assumptions as important limitations. That means the safest use in this repo is comparative stress ranking, sensitivity analysis, and scenario-aware risk triage, not direct substitution into regulatory credit models. (`docs/Baer_TRISK_2022.pdf`; https://deepwiki.com/2DegreesInvesting/trisk.model/4-risk-quantification)

## Literature

The central literature anchor remains Baer et al. (2022). Its contribution is to move climate stress testing away from purely backward-looking emissions proxies toward a forward-looking, firm-strategy-sensitive framework rooted in asset-level data, technological change, and scenario-dependent transition channels. For your repo, that is the strongest methodological reason to integrate TRISK after PACTA: PACTA already gives you the forward production and technology posture that the paper argues is necessary. (https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; https://doi.org/10.2139/ssrn.4254114)

The paper's empirical proof-of-concept is narrower than your current repo ambitions: international power firms, not a full multi-sector country case. That actually supports a phased Vietnam rollout. A power-sector pilot would remain closest to the published evidence base before extending to automotive, cement, and steel. (`docs/Baer_TRISK_2022.pdf`; https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk)

The package documentation adds an important implementation-level literature signal: TRISK is presented as experimental/beta in the 2DII line, and the public Theia line shows active evolution of the interface and docs. So the integration risk is not theoretical only; there is real version drift between methodology write-up, legacy package workflow, and newer package interface. For planning, assume that "TRISK integration" means pinning one concrete implementation target and documenting its data contract locally. (https://deepwiki.com/2DegreesInvesting/trisk.model/1.2-package-architecture-and-design-principles; https://theia-finance-labs.github.io/trisk.model/)

From a practical-use standpoint, the literature and docs align on one recurring theme: uncertainty is a feature, not a bug, of transition-risk stress testing. The paper emphasizes scenario and parameter sensitivity throughout, and the package exposes that directly by supporting one-parameter-at-a-time sensitivity runs. In this repo, the right output is therefore not a single "true" risk number for MCB, but a bounded range across plausible shock years, financing assumptions, and scenario combinations. (https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk; https://2degreesinvesting.github.io/r2dii.climate.stress.test/articles/02-run-stress-test.html; https://deepwiki.com/2DegreesInvesting/trisk.model/5-outputs-and-sensitivity-analysis)

## Sources
- `docs/Baer_TRISK_2022.pdf` - local methodology paper supplied for this brief; foundational model logic and caveats.
- `research/Baer_TRISK_2022_extracted.txt` - local text extraction used because direct PDF ingestion was unavailable in this environment.
- `scripts/pacta_vietnam_scenario.R` - current Vietnam PACTA pipeline and the best local anchor for where TRISK would attach.
- `data/vietnam_abcd.csv` - local asset/production-style dataset closest to TRISK production inputs.
- `data/vietnam_scenario_ms.csv` - local market-share scenarios showing current repo scenario structure.
- `data/vietnam_scenario_co2.csv` - local SDA scenario inputs showing what exists today and what still differs from TRISK price/carbon inputs.
- `synthesis_output/vietnam/04_vn_ms_company.csv` - local firm-level scenario output proving the repo already produces company-level forward-looking trajectories.
- [TRISK - A Climate Stress Test for Transition Risk | INET Oxford](https://www.inet.ox.ac.uk/publications/trisk-a-climate-stress-test-for-transition-risk) - stable public summary, abstract, and citation for Baer et al. (2022).
- [SSRN DOI landing page for Baer et al. (2022)](https://doi.org/10.2139/ssrn.4254114) - canonical paper citation target.
- [DeepWiki Overview for `2DegreesInvesting/trisk.model`](https://deepwiki.com/2DegreesInvesting/trisk.model/1-overview) - high-level package architecture and PACTA relationship.
- [DeepWiki Getting Started](https://deepwiki.com/2DegreesInvesting/trisk.model/1.1-getting-started) - prerequisites, required inputs, and execution pattern.
- [DeepWiki Package Architecture and Design Principles](https://deepwiki.com/2DegreesInvesting/trisk.model/1.2-package-architecture-and-design-principles) - modular pipeline and beta-stage caveats.
- [DeepWiki Core Stress Test Model](https://deepwiki.com/2DegreesInvesting/trisk.model/3-core-stress-test-model) - trajectory, profit, and risk flow.
- [DeepWiki Risk Quantification](https://deepwiki.com/2DegreesInvesting/trisk.model/4-risk-quantification) - NPV/VaR and PD-change outputs.
- [DeepWiki Asset Value at Risk (NPV / VaR)](https://deepwiki.com/2DegreesInvesting/trisk.model/4.1-asset-value-at-risk-(npv-var)) - market-risk formula and output semantics.
- [DeepWiki Probability of Default Change (Merton Model)](https://deepwiki.com/2DegreesInvesting/trisk.model/4.2-probability-of-default-change-(merton-model)) - structural credit-risk method and required inputs.
- [DeepWiki Outputs and Sensitivity Analysis](https://deepwiki.com/2DegreesInvesting/trisk.model/5-outputs-and-sensitivity-analysis) - output files and parameter-variation workflow.
- [Legacy TRISK reader source (`read.R`)](https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/read.R) - exact CSV input contract for the older 2DII workflow.
- [Legacy TRISK runner source (`run_trisk.R`)](https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/run_trisk.R) - main parameters and orchestration.
- [Legacy TRISK calculation source (`calculate.R`)](https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/calculate.R) - DCF and trajectory implementation details.
- [Legacy PD-change source (`calc_pd_change_overall.R`)](https://raw.githubusercontent.com/2DegreesInvesting/trisk.model/main/R/calc_pd_change_overall.R) - debt reconstruction and Merton-style PD calculation.
- [Theia `trisk.model` package home](https://theia-finance-labs.github.io/trisk.model/) - newer maintained public interface and version context.
- [Theia `trisk.model` data input description](https://theia-finance-labs.github.io/trisk.model/articles/data-input-description.html) - newer four-dataframe input contract.
- [2DII vignette: Run transition risk stress test](https://2degreesinvesting.github.io/r2dii.climate.stress.test/articles/02-run-stress-test.html) - old public workflow, parameter semantics, and sensitivity analysis guidance.
- [2DII vignette: Read the outputs](https://2degreesinvesting.github.io/r2dii.climate.stress.test/articles/04-read-the-outputs.html) - meaning of output files and argument-tagged results.

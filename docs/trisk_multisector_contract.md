# TRISK Multi-Sector Contract

## Scope

Phase 1 multi-sector TRISK support covers `power`, `cement`, and `steel`.
`automotive` remains out of scope for this pass.

## Output Layout

- Input packages: `output/trisk_inputs/<sector>_demo/`
- Sector CSV snapshots in `data/`:
  - `vietnam_trisk_assets_<sector>.csv`
  - `vietnam_trisk_scenarios_<sector>.csv`
  - `vietnam_trisk_ngfs_carbon_price_<sector>.csv`
- Shared cross-sector files in `data/`:
  - `vietnam_trisk_financial_features.csv`
  - `vietnam_trisk_company_mapping.csv`

Each runnable input folder contains the same four files expected by the current `trisk.model` workflow:

- `assets.csv`
- `scenarios.csv`
- `financial_features.csv`
- `ngfs_carbon_price.csv`

## Sector Mappings

### Power

- Local sector: `power`
- TRISK sector: `Power`
- Scenario source: `data/vietnam_scenario_ms.csv`
- Technologies:
  - `coalcap` -> `CoalCap`
  - `gascap` -> `GasCap`
  - `hydrocap` -> `HydroCap`
  - `renewablescap` -> `RenewablesCap`
- Units: `MW`, `USD/MWh-equivalent`

### Cement

- Local sector: `cement`
- TRISK sector: `Cement`
- Scenario source: `data/vietnam_scenario_co2.csv`
- Technology:
  - `integrated facility` -> `IntegratedFacility`
- Units: `tonnes`, `USD/unit-equivalent`

### Steel

- Local sector: `steel`
- TRISK sector: `Steel`
- Scenario source: `data/vietnam_scenario_co2.csv`
- Technologies:
  - `open_hearth` -> `OpenHearth`
  - `electric` -> `ElectricArc`
- Units: `tonnes`, `USD/unit-equivalent`

## Alignment Context Rule

For the current expansion plan, `cement` and `steel` may use sector-level SDA context from `synthesis_output/vietnam/06_vn_sda_alignment_2030.csv` in later TRISK ranking outputs and dashboard copy.
That context must be labeled as sector-level, not borrower-specific alignment.

## Scenario Translation Rule

### Power

Power continues to use market-share scenario inputs from `data/vietnam_scenario_ms.csv`.
`scenario_pathway` is derived from baseline production multiplied by the sector technology share shock.
`scenario_price` and `scenario_capacity_factor` continue to use technology-specific synthetic demo curves.

### Cement and Steel

`cement` and `steel` use SDA emission-intensity pathways from `data/vietnam_scenario_co2.csv`.
The TRISK `scenarios.csv` translation is:

- `scenario_price`: a synthetic unit-price path anchored by sector and year, then increased as the pathway requires more intensity reduction versus the sector baseline.
- `scenario_pathway`: baseline production adjusted by a technology-type multiplier derived from the ratio between target intensity and baseline intensity.
- `scenario_capacity_factor`: a normalized utilization-style factor derived from the same intensity ratio.

This keeps the repo on the current four-file `trisk.model` contract without introducing a separate sector-specific input schema.

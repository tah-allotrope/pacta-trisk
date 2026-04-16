# TRISK Demo Assumptions

This note documents the synthetic but publicly anchored assumptions used for the Vietnam power-sector TRISK demo in this repository.

## Purpose

The TRISK pilot is a demonstration layer built on top of the synthetic Vietnam PACTA work. It is designed to show how a prospective Vietnam bank could move from alignment analytics to transition-stress analytics.

The pilot therefore uses:

- real-world-inspired company names and sector context
- synthetic exposure values from the repo's MCB portfolio
- public-policy anchors such as PDP8, IEA NZE, and generic carbon-price logic
- synthetic financial risk parameters where borrower-level confidential data is unavailable

These assumptions are appropriate for a demo. They are not production credit inputs.

## Modeling Boundary

- Sector in scope for TRISK pilot: `power`
- Geography in scope: `Vietnam`
- Companies in scope: the power-sector parent borrowers represented in the synthetic MCB loanbook and matched Vietnam ABCD dataset
- Baseline scenario: domestic-transition style pathway aligned with PDP8/NDC direction
- Stress scenario: stronger Paris-style transition shock aligned with a harsher NZE-style pathway

## Data Translation Assumptions

### Asset Table

The current repo stores power production plans in `data/vietnam_abcd.csv` as yearly production or capacity-style values by company and technology. The installed `trisk.model` package expects an assets table with:

- `capacity`
- `capacity_factor`
- `emission_factor`

For the demo pilot:

- `capacity_factor` is assigned by technology archetype
- `capacity` is back-calculated so that `capacity * capacity_factor` reproduces the existing repo production plan
- `emission_factor` is assigned synthetically for power technologies where needed for carbon-tax stress

### Technology Capacity Factors

These are demo assumptions used to preserve relative production while fitting the `trisk.model` asset schema.

| Technology | Capacity factor |
|---|---:|
| `CoalCap` | 0.70 |
| `GasCap` | 0.55 |
| `HydroCap` | 0.45 |
| `RenewablesCap` | 0.30 |

### Power Technology Emission Factors

These are synthetic transition-risk inputs used only for the TRISK pilot.

| Technology | Emission factor |
|---|---:|
| `CoalCap` | 0.95 |
| `GasCap` | 0.45 |
| `HydroCap` | 0.02 |
| `RenewablesCap` | 0.01 |

The values are intended to preserve directional carbon-risk differences, not to reproduce audited plant-level emissions.

## Financial Feature Assumptions

The TRISK package requires the following company-level financial fields:

- `pd`
- `net_profit_margin`
- `debt_equity_ratio`
- `volatility`

Because this repo does not contain borrower-confidential financials, these fields are assigned by borrower archetype.

### Archetypes Used

- state-owned utility
- state-affiliated generation platform
- BOT coal project
- LNG growth platform
- hydropower operator
- renewable IPP platform

### Directional Logic

- SOE-style platforms have lower baseline PD and lower volatility than smaller private platforms.
- BOT coal projects have lower short-term cash-flow uncertainty but higher leverage and significant transition lock-in.
- Renewable IPPs have stronger transition alignment but higher execution-style leverage and volatility than mature SOEs.
- Gas platforms sit between coal and renewables in the demo stress story.

## Scenario Assumptions

### Baseline Scenario

The baseline scenario represents a Vietnam domestic transition path broadly aligned with PDP8/NDC direction for power-sector technology mix.

### Stress Scenario

The stress scenario represents a harsher transition path aligned with a stronger NZE-style power mix shift.

### Price Paths

The installed `trisk.model` package requires scenario prices by technology and year. The pilot uses synthetic price paths that are directionally consistent with the scenario narrative:

- coal prices soften under stress
- gas prices soften moderately under stress
- hydro prices remain relatively stable
- renewables become more favored under stress

These price paths are used to create internally coherent model behavior, not to replicate a tradable Vietnam forward market.

### Carbon Price Path

The pilot uses the package's `increasing_carbon_tax_50` pattern as the active carbon-price model. In practical terms, this means:

- no carbon tax before the shock year
- a 50-unit carbon tax at the shock year
- a 4% annual escalation after the shock year

This is a synthetic stress device for the demo.

## Interpretation Guardrails

The TRISK pilot should be read as:

- a comparative transition-stress ranking tool
- an extension of the PACTA alignment story
- a way to prioritize borrowers and sectors for engagement, monitoring, and strategic discussion

The pilot should not be read as:

- a production-grade expected-loss engine
- a regulatory PD model
- a substitute for borrower financial statements, ratings, or bank internal models

## Recommended Disclosure Language

Use wording like this in stakeholder-facing materials:

"The TRISK outputs in this demo are synthetic, scenario-based stress indicators derived from publicly anchored assumptions and a synthetic Vietnam bank portfolio. They are intended for comparative portfolio triage and methodology demonstration, not for production credit decisions or regulatory use."

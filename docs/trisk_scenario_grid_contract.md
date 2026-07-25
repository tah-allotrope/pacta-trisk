# TRISK Scenario Grid Contract

## Purpose

This document defines the Phase 01 contract for the precomputed Scenario Builder grid.
It extends the existing multisector TRISK snapshot with a deterministic scenario lookup layer that works on Streamlit Community Cloud without an R runtime.

## Scope

- Covered sectors: `power`, `cement`, `steel`
- Out of scope for Phase 01:
  - `automotive`
  - custom carbon-price uploads
  - cross-session scenario persistence
  - public live reruns

## Accepted Defaults

Phase 01 accepts the recommended defaults from `plans/2026-05-02-interactive-scenario-builder-plan.md`:

- `carbon_price_family` uses NGFS-named aliases over existing in-repo curves for v1
- operator-only live rerun stays in the broader plan, but not in the public grid contract
- save/load remains single-session only for v1
- each lever uses 3 discrete values for the precomputed demo grid

## Lever Enumeration

The grid is the cartesian product of five banker-facing levers.

| Lever | Type | Allowed values | Notes |
|---|---|---|---|
| `shock_year` | integer | `2026`, `2028`, `2030` | Chosen to show early, mid, and later policy timing shifts |
| `discount_rate` | numeric | `0.06`, `0.08`, `0.10` | Stored with two decimal places in `scenario_id` |
| `risk_free_rate` | numeric | `0.02`, `0.03`, `0.04` | Stored with two decimal places in `scenario_id` |
| `market_passthrough` | numeric | `0.15`, `0.25`, `0.35` | Stored with two decimal places in `scenario_id` |
| `carbon_price_family` | string | `NGFS_NetZero2050`, `NGFS_Below2C`, `NGFS_Delayed` | Aliases mapped to existing curve names |

This yields `3 x 3 x 3 x 3 x 3 = 243` scenarios per sector.

## Carbon-Price Family Mapping

**Updated in Wave 1 PHASE-04.** Phase 01 originally aliased all three
`carbon_price_family` values onto the same backing curve per sector, so the
"strict / moderate / mild" choice had no effect on any output — confirmed
empirically (C7 in `research/2026-07-25-post-wave0-platform-hardening-brainstorm.md`).
Each family now maps to its own derived curve: `NGFS_NetZero2050` keeps the
original curve and values unchanged (so the base, non-grid TRISK run is
unaffected); `NGFS_Below2C` and `NGFS_Delayed` scale that curve's
`carbon_tax` path to 60% and 30% respectively, rounded to 2 decimals
(`R/trisk_core.R:.trisk_build_carbon_price()`).

| Sector | `carbon_price_family` | Backing `carbon_price_model` | Notes |
|---|---|---|---|
| `power` | `NGFS_NetZero2050` | `increasing_carbon_tax_50` | Unchanged original curve |
| `power` | `NGFS_Below2C` | `increasing_carbon_tax_50_below2c` | 60% of the NetZero2050 carbon_tax path |
| `power` | `NGFS_Delayed` | `increasing_carbon_tax_50_delayed` | 30% of the NetZero2050 carbon_tax path |
| `cement` | `NGFS_NetZero2050` | `cement_intensity_transition` | Unchanged original curve |
| `cement` | `NGFS_Below2C` | `cement_intensity_transition_below2c` | 60% of the NetZero2050 carbon_tax path |
| `cement` | `NGFS_Delayed` | `cement_intensity_transition_delayed` | 30% of the NetZero2050 carbon_tax path |
| `steel` | `NGFS_NetZero2050` | `steel_intensity_transition` | Unchanged original curve |
| `steel` | `NGFS_Below2C` | `steel_intensity_transition_below2c` | 60% of the NetZero2050 carbon_tax path |
| `steel` | `NGFS_Delayed` | `steel_intensity_transition_delayed` | 30% of the NetZero2050 carbon_tax path |

The scaling is intentionally illustrative, not sourced from actual NGFS
Phase V carbon-price data. Methodology copy must describe these as demo
families derived from existing repo curves, not as newly ingested NGFS data.

## Scenario Identifier

Every precomputed scenario row must be addressed by a deterministic `scenario_id`:

```text
s{shock_year}_d{discount_rate}_rf{risk_free_rate}_mp{market_passthrough}_c{carbon_price_family}
```

Formatting rules:

- numeric values are serialized with two decimal places
- decimal points are preserved
- `carbon_price_family` keeps the canonical case shown in the lever table
- no whitespace is allowed

### Worked Example

Inputs:

- `shock_year = 2028`
- `discount_rate = 0.08`
- `risk_free_rate = 0.03`
- `market_passthrough = 0.25`
- `carbon_price_family = NGFS_Below2C`

Builds to:

```text
s2028_d0.08_rf0.03_mp0.25_cNGFS_Below2C
```

Round-trip parse of that identifier must recover the exact same five lever values.

## Baseline Rule

The baseline comparison target is the existing `base` row already present in each sector's `sensitivity_results.csv` snapshot.
The baseline is not assigned a generated `scenario_id`.
All scenario-builder comparisons are defined as `baseline row` versus `scenario_id row` for the selected sector.

## Output Layout

For each sector, the precomputed grid snapshot lives under:

```text
dashboard/data/trisk/grid/<sector>/
```

Required artifacts:

- `scenarios.csv`
- `borrower_results.parquet`
- `grid_meta.json`

The same structure is mirrored in synthesis output before refresh:

```text
synthesis_output/trisk/grid/<sector>/
```

## Artifact Schemas

### `scenarios.csv`

One row per scenario combination.

Required columns:

| Column | Type | Description |
|---|---|---|
| `scenario_id` | string | Deterministic scenario key used by the dashboard |
| `sector` | string | `power`, `cement`, or `steel` |
| `shock_year` | integer | Selected shock year |
| `discount_rate` | numeric | Selected discount rate |
| `risk_free_rate` | numeric | Selected risk-free rate |
| `market_passthrough` | numeric | Selected passthrough assumption |
| `carbon_price_family` | string | Banker-facing scenario family |
| `carbon_price_model` | string | Backing repo curve string passed to TRISK |
| `grid_label` | string | Human-readable summary label for tables/downloads |

### `borrower_results.parquet`

One row per `(scenario_id, company_id)` pair.

Required columns:

| Column | Type | Description |
|---|---|---|
| `scenario_id` | string | Foreign key to `scenarios.csv` |
| `sector` | string | Sector for the run |
| `company_id` | string | Borrower identifier |
| `company_name` | string | Borrower label shown in the dashboard |
| `npv_change_pct` | numeric | Scenario NPV percent change |
| `pd_change_pct` | numeric | Scenario PD percent change |
| `stress_priority_score` | numeric | Existing stress ranking score reused by the dashboard |
| `delta_npv_change_vs_base` | numeric | Borrower-level delta versus the existing baseline row |
| `delta_pd_change_vs_base` | numeric | Borrower-level delta versus the existing baseline row |
| `rank_within_scenario` | integer | Rank by `stress_priority_score` within the scenario |

Additional columns already produced by the sector runner may be retained so long as these required columns remain stable.

### `grid_meta.json`

One metadata object per sector refresh.

Required keys:

| Key | Type | Description |
|---|---|---|
| `sector` | string | Sector name |
| `scenario_count` | integer | Expected to be `243` for the default grid |
| `generated_at` | string | ISO-style timestamp for the grid refresh |
| `runtime_seconds` | numeric | Total runtime for the sector grid |
| `trisk_model_version` | string | Package version used for generation |
| `grid_contract_version` | string | Version tag for this contract, starting at `v1` |
| `input_fingerprint` | string | **Added Wave 1 PHASE-04.** md5 of the sector's four TRISK input files (`assets.csv`, `financial_features.csv`, `ngfs_carbon_price.csv`, `scenarios.csv`), computed by `grid_input_fingerprint()`. `trisk_run_grid()` discards the entire cached grid and regenerates all `scenario_count` scenarios whenever this, `trisk_model_version`, or `grid_contract_version` no longer matches the current environment (`grid_cache_is_valid()`, Specification S2) — this is the fix for the grid staleness defect (C1/INV-001): before PHASE-04, the cache was keyed on `scenario_id` alone with no dependency on the underlying input data. |

## Lever Sensitivity (measured, Wave 1 PHASE-04)

Every lever was confirmed to move at least one output metric before being
kept in the grid:

| Lever | Affects `npv_change_pct`? | Affects `pd_change_pct`? | Evidence |
|---|---|---|---|
| `shock_year` | Yes | Yes | 3 distinct `npv_change_pct` sums when holding other levers fixed |
| `discount_rate` | Yes | Yes | 3 distinct `npv_change_pct` sums when holding other levers fixed |
| `market_passthrough` | Yes | Yes | 3 distinct `npv_change_pct` sums when holding other levers fixed |
| `risk_free_rate` | **No** | **Yes** | Two ad-hoc power runs differing only in `risk_free_rate` (0.02 vs 0.04) produced identical `npv_change` (max diff `0.0`) but `pd_change` differed by up to `0.028` (2.8 percentage points of PD) per borrower. `risk_free_rate` is a Merton-model credit-risk input (drives distance-to-default / PD), not a firm-value input (drives NPV) — this is expected model behavior, not a plumbing bug. An earlier pass mistakenly read this as the lever being fully inert because it compared only `npv_change` sums. |
| `carbon_price_family` | Yes (after this phase) | Yes (after this phase) | Previously a true no-op — all three families aliased to one backing curve (see Carbon-Price Family Mapping above). Fixed this phase. |

**Specification S3 outcome:** `risk_free_rate` is live (confirmed empirically,
not a plumbing bug) — kept in `grid_levers`, `trisk_sensitivity_specs`,
`build_scenario_id()`, and `build_grid_label()` unchanged. The grid remains
the full `3^5 = 243`-scenario cartesian product.

## Per-Scenario Input Horizon (`grid_contract_version` v2, Wave 1 PHASE-04 follow-up)

`build_grid_input_dir()` builds ONE shared input package per sector,
extending `scenarios.csv` and `ngfs_carbon_price.csv` to
`max(grid_levers$shock_year) + 2` (2032) so all 243 scenarios can reuse it
without re-extending per run. This is correct for scenarios whose own
`shock_year` equals the grid-wide max (2030), but WRONG for every other
scenario: `trisk.model` sums NPV over every year present in the scenario
data, so a `shock_year = 2026` cell still carrying 2031-2032 rows produces a
different (and wrong) result than a standalone run at `shock_year = 2026`
would.

This was discovered empirically after PHASE-04's initial input-fingerprinting
fix: a **fully fresh** grid regeneration (fixed staleness, C1) still
disagreed with the base run at identical parameters. Isolating the cause
showed the shared package's extended horizon was the culprit, not staleness.

**Fix:** `build_scenario_input_dir()` builds a per-scenario copy of the
shared package, truncating `scenarios.csv`/`ngfs_carbon_price.csv` to
`max(shock_year + 2, assets.csv's own max year)` before each `execute_trisk_run()`
call. The floor term matters: naively truncating to `shock_year + 2` alone
crashed `trisk.model:::extend_to_full_analysis_timeframe()` for
`shock_year = 2026` (horizon 2028), because `assets.csv` is never truncated
and still spans the full 2025-2030 base window — the floor keeps
scenarios/carbon-price truncation from ever going narrower than that.

Verified: truncating a `shock_year = 2028` cell to its own horizon (2030)
reproduced the base run's `company_summary.csv` to floating-point noise
(max abs diff `1.1e-16`, previously `1.1e-16` after the fix vs. `0.01`-`0.14`
before it). This changes every grid cell's numeric output for the same
nominal parameters (nothing about the shared input package's own bytes
changed, so `input_fingerprint` alone could not have detected it) — hence
the `grid_contract_version` bump to `v2` to force every existing cache to
discard and regenerate.

## Manifest Extension

`dashboard/data/trisk/manifest.csv` must add a new boolean column:

| Column | Type | Default | Meaning |
|---|---|---|---|
| `grid_available` | boolean | `false` | Whether `dashboard/data/trisk/grid/<sector>/` exists and is ready for the Scenario Builder |

Backward-compatibility rule:

- existing sectors default to `false` until the grid generator and refresh script publish grid artifacts

## Compatibility Rules

- This contract extends `docs/trisk_multisector_contract.md`; it does not replace the existing sector snapshot contract
- `power` keeps borrower-level market-share alignment context
- `cement` and `steel` keep sector-level SDA context and must not be relabeled as borrower-specific alignment
- public deployment must remain snapshot-only and must not depend on an R runtime

## Loader Expectations

The future Python loader should be able to:

- read `manifest.csv` and filter to sectors with `grid_available = true`
- map the current lever widget state to a single `scenario_id`
- join `scenario_id` rows against the existing sector baseline from `sensitivity_results.csv`
- fail gracefully when a sector is present in the main manifest but missing grid artifacts

## Verification Checklist

- `scenario_id` build and parse round-trip succeeds for the worked example
- each supported sector is documented against the same five-lever grid
- `grid_available` defaults to `false` in the manifest until Phase 02 generates artifacts
- the contract remains consistent with the current multi-sector TRISK snapshot and public Streamlit deployment constraints

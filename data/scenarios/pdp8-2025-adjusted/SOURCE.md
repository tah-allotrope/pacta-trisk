# Source: Adjusted PDP8 (Decision 768/QĐ-TTg)

## Primary source (power sector only)

On 2025-04-15 the Prime Minister of Vietnam issued **Decision No. 768/QĐ-TTg**,
approving the revised National Power Development Plan for 2021–2030 (vision to
2050) — the "Adjusted PDP8" — replacing **Decision No. 500/QĐ-TTg**
(2023-05-15), which the `pdp8-2023` vintage is based on. Cited figures used
below (verified against multiple independent legal-update summaries at the
time this vintage was built; **re-verify against the Vietnamese-language
decision text or an updated legal summary before any real client-facing
use** — see the caveats below):

- Total installed capacity range by 2030: **183,291–236,363 MW** (up from
  ~150 GW under the 2023 plan).
- Coal capacity target by 2030: **30,127 MW** (little changed in absolute
  terms from the 2023 plan's coal target — the Adjusted PDP8 largely kept
  committed/under-construction coal plants rather than accelerating
  retirement).
- Renewable energy (excluding hydropower) share target by 2030: **28%–36%**.
- Onshore/nearshore wind: 26,066–38,029 MW (up from 21,880 MW). Offshore
  wind: 17,032 MW (up from 6,000 MW). Battery storage: 10,000–16,300 MW (up
  from 300 MW).

## Derivation method for `vietnam_scenario_ms.csv` (power rows)

`smsp` (scenario market share of production, i.e. each technology's share of
total power capacity) for the five power technologies this repo tracks
(`coalcap`, `gascap`, `hydrocap`, `renewablescap`, `oilcap`) is **derived**,
not directly quoted, because the cited sources give capacity *ranges* and a
partial technology breakdown, not a single five-technology share table for
every year 2025–2030. The method, fully reproducible from the cited figures
above:

1. **2030 coal share** = 30,127 MW ÷ midpoint of the total capacity range
   (209,827 MW) = **0.1436**.
2. **2030 renewables (ex-hydro) share** = midpoint of the cited 28%–36%
   range = **0.32**.
3. **2030 gas/hydro/oil shares**: the residual (1 − 0.1436 − 0.32 = 0.5364)
   is allocated across gas/hydro/oil in the same *proportions* the
   `pdp8-2023` vintage used for 2030 (0.17 / 0.21 / 0.02, summing to 0.40),
   scaled up by 0.5364 ÷ 0.40 = 1.341 → gas 0.228, hydro 0.2816, oil 0.0268.
   (Sums to 1.0000.) **This step is an assumption, not a cited figure** — the
   sources found did not give an independent 2030 gas/hydro/oil breakdown.
4. **2025–2029 `smsp`**: linear interpolation between the unchanged 2025
   starting shares (carried over from `pdp8-2023` — both vintages observe
   the same starting-point mix) and the step-3 2030 endpoints.
5. **`tmsr`** (technology capacity relative to its own 2025 level): the
   `pdp8-2023` vintage's own per-technology `tmsr` trajectory is scaled by
   the ratio (new 2030 `smsp` ÷ old 2030 `smsp`) for that technology, to
   preserve the file's internal growth-shape consistency. **This is an
   extrapolation, not a cited figure** — per-technology absolute capacity
   pathways for the Adjusted PDP8 were not available at the time this
   vintage was built.

`automotive` rows (electric/hybrid/ICE) are **unchanged** from `pdp8-2023`
— PDP8 covers only the power sector, so there is no adjusted-plan basis to
update them.

## `vietnam_scenario_co2.csv` (cement/steel emission-intensity rows)

**Unchanged** from `pdp8-2023`, relabeled to `pdp8_2025_adjusted`. PDP8 (both
the 2023 and 2025-adjusted versions) covers only the power sector; the
cement/steel emission-intensity pathways were never actually sourced from
PDP8 in the original vintage either (see `docs/bidv_sector_prioritization_methodology.md`
and `docs/bidv_framework_comparison.md`, which already describe PDP8/NDC as
a proxy benchmark for non-power sectors). There is no adjusted-plan basis to
change them, so re-labeling without changing values is the honest choice.

## Adding a new vintage: region_isos needs a vintage-scoped copy, not an edit to the shared file

`r2dii.analysis::target_market_share()` joins the scenario data against a
region-ISO mapping file (`inputs.region_isos_csv`) on its `source` column,
which must equal `scenario_source`. The repo's shared file,
`data/vietnam_region_isos.csv`, has rows only for `pdp8_2023`, `steps_2023`
and `nze_2023`. **Without a matching row, a vintage's scenario data is
silently dropped during the join — no error is raised, the run just never
produces a `target_pdp8_ndc` metric.** This was discovered building this
vintage (Wave 3 PHASE-03) — the vintage-directory mechanism had never had a
second tenant before, so this join dependency had never been exercised.

**The fix is a vintage-scoped file, not an edit to the shared one.** The
first attempt at this vintage added `pdp8_2025_adjusted` rows directly to
`data/vietnam_region_isos.csv` — that broke byte-identity: `r2dii.analysis`
emits one `projected`/`corporate_economy` baseline row **per row present in
region_isos**, regardless of whether any scenario data references that
`source`, so adding rows there changed the row *count* of
`synthesis_output/vietnam/04_vn_ms_portfolio.csv` and `04_vn_ms_company.csv`
for `mcb-demo`, which had not changed vintage at all. The correct pattern,
used here: `data/scenarios/pdp8-2025-adjusted/vietnam_region_isos.csv`
carries this vintage's `pdp8_2025_adjusted` rows plus the vintage-independent
`steps_2023`/`nze_2023` rows (IEA benchmarks, not PDP8-specific), and
`scripts/compare_scenario_vintages.R` points `inputs.region_isos_csv` at it
for this vintage's run only — the shared `data/vietnam_region_isos.csv` is
never modified.

## Caveats (read before any client-facing use)

- Steps 3 and 5 above are **derived, not cited** — they are a documented,
  reproducible extrapolation method applied to genuinely cited aggregate
  figures, not a transcription of an official year-by-year technology-mix
  table (no such public table was located at the time this vintage was
  built).
- The cited figures themselves come from secondary legal-update summaries
  (law firm client alerts), not a direct read of the Vietnamese-language
  decision text. They should be cross-checked against the primary source or
  an authoritative English translation before this vintage is used in any
  deliverable shown to BIDV, Techcombank, or any other real client.
- `NZE_2023` and `STEPS_2023` (IEA) rows are unchanged in this vintage
  directory — this vintage only updates the Vietnam-specific PDP8 pathway.

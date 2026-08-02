# pactatrisk 0.4.0

Wave 2 "Contracts, Units, and Guard Rails": fixes the two client-facing
correctness defects that made the platform's output wrong rather than merely
incomplete — money units and rank-relative scores — gated by a byte-identity
CI check that previously ran nowhere. The third known defect (the intake
validator dropping rows its own published schema promises to accept) is
scheduled for the follow-up wave.

- **Byte-identity now runs in CI** (`ci.yml`'s `byte-identity` job, every
  push) and **gates** the weekly public-snapshot auto-publish
  (`refresh.yml`, via `tools/verify_refactor.R --skip-refresh`, overridable
  only through a manual `allow_drift: true` dispatch for an intentional,
  reviewed refreeze). `CLAUDE.md` law 5 corrected to match.
- **Money is true VND everywhere.** The synthetic MCB loanbook was
  denominated in *millions* of VND while every column and label said `VND`
  — the public demo portfolio read as ~USD 950 instead of the ~USD 950M its
  own pitch deck claims (MCB's book is 25.02 trillion VND, ~USD 950M at
  26,300 VND/USD). Fixed at the source (`make_loan()` in
  `scripts/generate_vietnam_data.R`); every money renderer now goes through
  one shared `R/format_money.R`; a new cross-artifact invariant (`INV-006`)
  fails if any engagement's VND-declared loanbook is implausibly small.
- **Priority scores are now absolute, not rank-relative.** Every score that
  fed a composite was min-max normalized — in two cases, three times over
  the same quantity — so the top-ranked sector or borrower was *always
  exactly 1.0* for any input, and two structurally different banks produced
  identical score patterns. `R/severity_scoring.R` replaces every min-max
  block with clamped piecewise-linear interpolation over four documented
  anchor tables (`docs/scoring_anchors.md`): a score of 0.61 now means the
  same thing for every bank, every sector, every refresh. The former
  tautological golden assertions (`composite_score[1] == 1.0`, true for any
  input) are re-pinned to real, falsifiable values, plus a non-degeneracy
  regression guard (`composite_score` strictly between 0 and 1).
  `stress_priority_score` (the dashboard's rank-relative sort key) is
  unchanged; a new `stress_severity_score` column carries the absolute view.
- **Golden refreeze.** One commit regenerates every artifact PHASE-02's
  rescale and PHASE-03's rescoring affect (`data/vietnam_loanbook.csv`,
  `sector_priority_ranking.csv`, `engagement_priority.csv`,
  `top_borrowers_alignment_trisk.csv`, and their SDB-rehearsal
  counterparts); the TRISK scenario grid parquet is untouched
  (`grid_contract_version` stays `"v2"`).

# pactatrisk 0.3.0

Wave 1 "Consistency": the platform's acceptance discipline previously only
verified that a run reproduced itself (byte-identity); this release closes
the sibling question it could not ask — does one committed artifact agree
with another — and fixes every defect that gap let through.

- `tools/verify_refactor.R --invariants`: a new acceptance mode alongside
  the existing byte-identity check, running five cross-artifact consistency
  rules (`INV-001`..`INV-005`) against the current tree without executing
  anything: the TRISK scenario grid's base-parameter cell must equal the
  base (non-grid) TRISK run; no scenario vintage may exist at two paths;
  every engagement's `data_source` column must equal its own `bank_slug`;
  the supported-sector literal must agree across every file that hardcodes
  it; every published TRISK manifest sector must be a known registry
  sector. Wired into both CI workflows.
- **Grid staleness fixed (the headline defect):** the precomputed TRISK
  scenario grid was keyed only on lever values, with no dependency on the
  underlying input data, and had silently gone stale for three months.
  `grid_input_fingerprint()` + `grid_cache_is_valid()` now discard and
  regenerate the entire cached grid whenever the sector's input files,
  `trisk.model` version, or `grid_contract_version` no longer match.
  A second, deeper defect surfaced only after fixing the first: the grid's
  shared input package extended every scenario's data to the grid-wide max
  `shock_year + 2`, which measurably changed NPV/PD even for scenarios at
  the base parameters. `build_scenario_input_dir()` now truncates each
  scenario's inputs to its own horizon before running it. All three sector
  grids regenerated (`grid_contract_version` `v1` -> `v2`); the base grid
  cell now reproduces the base TRISK run to floating-point noise.
- **Two of the Scenario Builder's five levers were inert; both fixed.**
  `carbon_price_family` aliased all three choices to one backing curve —
  `.trisk_build_carbon_price()` now emits three genuinely distinct curves
  per sector. `risk_free_rate` turned out to be live, not inert — it moves
  `pd_change_pct` (up to 2.8 points of PD) but never `npv_change_pct`
  (a Merton-model credit-risk input, not a firm-value one); the original
  "inert" finding had only checked `npv_change`. No plumbing bug, no lever
  removed.
- **Provenance and config fixes:** `data_source` in engagement deliverables
  is now always `cfg$bank_slug`, never a hardcoded literal; sector-level
  prioritization now derives its sector list and exposure map from
  `cfg$trisk_sectors` instead of a fixed three-sector list; engagement
  configs gained `raw_loanbook_csv` and `public_snapshot_allowed` so a
  config can reproduce its own documented run and the public-snapshot
  guard rail is an explicit opt-in rather than a `bank_slug` string
  comparison.
- **Single source of truth for scenario vintages and ABCD provenance:**
  the byte-identical duplicate `data/vietnam_scenario_*.csv` files were
  retired in favor of `data/scenarios/pdp8-2023/`; the demo's own
  `data/vietnam_abcd.csv` now carries the `data_source`/`as_of_year`
  provenance columns its own documented schema requires, and
  `validate_abcd_schema()` enforces the full 14-column contract at
  pipeline entry.
- **Orchestrator convergence:** `scripts/run_engagement.R` is now the
  single orchestrator for the public MCB demo and every client engagement.
  `scripts/pipeline_refresh.R` is a thin wrapper forwarding its flags
  (`--full`, `--dry-run`) unchanged. `scripts/trisk_power_demo.R` retired
  (`scripts/trisk_sector_demo.R power` already did the same thing).
  Four new config keys (`run_data_generation`, `run_refresh_audit`,
  `run_outputs`, `row_count_files`) let one step list serve both callers.
- **Multi-bank CI guard:** a weekly-and-per-push `sdb-engagement` CI job
  now actually executes `scripts/run_engagement.R` for the Saigon Delta
  Bank rehearsal end to end and asserts no cross-contamination outside its
  own engagement directory — closing a gap where the second golden fixture
  validated only committed artifacts, never the orchestrator that produces
  them.

# pactatrisk 0.2.0

- TRISK core: `R/trisk_core.R` and `R/prioritization_core.R` expose the TRISK
  prepare/run/grid chain and sector prioritization as config-parameterized
  package functions (`trisk_prepare_sector_inputs()`, `trisk_run_sector()`,
  `trisk_run_grid()`, `prioritize_sectors()`), mirroring the existing
  `R/pacta_core.R` pattern; all four TRISK/prioritization scripts are now
  thin CLI wrappers.
- Downstream generators (`refresh_dashboard_data.R`, `engagement_scoring.R`,
  `generate_engagement_letters.R`, `generate_disclosure_pack.R`) accept an
  engagement config via `--config`, publishing to engagement-scoped paths
  with no change to default (MCB) behavior.
- Engagement orchestrator: `R/step_runner.R` (`run_steps()`,
  `write_pipeline_manifest()`) extracted from `scripts/pipeline_refresh.R`,
  and `scripts/run_engagement.R` runs the full delivery flow — intake,
  validation report, PACTA, TRISK, prioritization, snapshot, scoring,
  letters, disclosure — for any engagement config in one command, with a
  `--dry-run` mode and a guard rail against writing into the public
  `dashboard/data` snapshot.
- `tools/verify_refactor.R`: a one-command byte-identity acceptance check
  (see `README.md`, "Refactor acceptance check").

# pactatrisk 0.1.0

- Initial loadable package: `R/pacta_core.R` PACTA functions,
  `R/engagement_config.R` config loader, `R/sector_registry.R`,
  `R/report_toolkit.R`, `R/matching_helpers.R`.

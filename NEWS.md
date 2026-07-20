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

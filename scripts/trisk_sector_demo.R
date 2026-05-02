# ==============================================================================
# trisk_sector_demo.R
# Run a package-backed TRISK demo for a selected synthetic Vietnam sector.
#
# Usage:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R power
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R cement
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_sector_demo.R steel
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(fs)
  library(ggplot2)
  library(purrr)
  library(readr)
  library(scales)
  library(tibble)
  library(tidyr)
})

lib <- Sys.getenv("R_LIBS_USER")
library(trisk.model, lib.loc = lib)

trisk_supported_sectors <- c("power", "cement", "steel")

trisk_sector_meta <- list(
  power = list(
    label = "power",
    title = "Power",
    subtitle = "Firm-level transition-stress view for the Vietnam synthetic power book.",
    scenario_geography = "Vietnam",
    carbon_price_model = "increasing_carbon_tax_50",
    baseline_scenario = "VN_PDP8_BASELINE",
    target_scenario = "VN_NZE_STRESS",
    alignment_mode = "company_ms",
    company_aliases = c("PVN Power Corporation" = "PVN Power Corporation")
  ),
  cement = list(
    label = "cement",
    title = "Cement",
    subtitle = "Borrower stress view for Vietnam cement producers with sector-level SDA context.",
    scenario_geography = "Vietnam",
    carbon_price_model = "cement_intensity_transition",
    baseline_scenario = "VN_PDP8_BASELINE",
    target_scenario = "VN_NZE_STRESS",
    alignment_mode = "sector_sda",
    company_aliases = c("Holcim Group" = "Holcim Group", "VICEM" = "VICEM")
  ),
  steel = list(
    label = "steel",
    title = "Steel",
    subtitle = "Borrower stress view for Vietnam steel producers with sector-level SDA context.",
    scenario_geography = "Vietnam",
    carbon_price_model = "steel_intensity_transition",
    baseline_scenario = "VN_PDP8_BASELINE",
    target_scenario = "VN_NZE_STRESS",
    alignment_mode = "sector_sda",
    company_aliases = c("Hoa Phat Group JSC" = "Hoa Phat Group JSC", "Pomina Group" = "Pomina Group")
  )
)

trisk_base_params <- list(
  shock_year = 2028,
  discount_rate = 0.08,
  risk_free_rate = 0.03,
  growth_rate = 0.02,
  div_netprofit_prop_coef = 1,
  market_passthrough = 0.25,
  show_params_cols = TRUE
)

trisk_sensitivity_specs <- tribble(
  ~run_label,                  ~parameter_name,       ~parameter_value, ~shock_year, ~discount_rate, ~risk_free_rate, ~market_passthrough,
  "base",                    "base",               "base",          2028,        0.08,           0.03,            0.25,
  "shock_year_2027",         "shock_year",         "2027",          2027,        0.08,           0.03,            0.25,
  "shock_year_2029",         "shock_year",         "2029",          2029,        0.08,           0.03,            0.25,
  "discount_rate_0.06",      "discount_rate",      "0.06",          2028,        0.06,           0.03,            0.25,
  "discount_rate_0.10",      "discount_rate",      "0.10",          2028,        0.10,           0.03,            0.25,
  "risk_free_rate_0.02",     "risk_free_rate",     "0.02",          2028,        0.08,           0.02,            0.25,
  "risk_free_rate_0.04",     "risk_free_rate",     "0.04",          2028,        0.08,           0.04,            0.25,
  "market_passthrough_0.15", "market_passthrough", "0.15",          2028,        0.08,           0.03,            0.15,
  "market_passthrough_0.35", "market_passthrough", "0.35",          2028,        0.08,           0.03,            0.35
)

assert_supported_sector <- function(sector) {
  if (!(sector %in% trisk_supported_sectors)) {
    stop(sprintf(
      "Unsupported sector '%s'. Supported sectors: %s",
      sector,
      paste(trisk_supported_sectors, collapse = ", ")
    ))
  }
}

resolve_trisk_paths <- function(sector, output_root = NULL) {
  input_dir <- file.path(getwd(), "output", "trisk_inputs", paste0(sector, "_demo"))
  if (is.null(output_root)) {
    output_root <- file.path(getwd(), "synthesis_output", "trisk", paste0(sector, "_demo"))
  }

  dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

  list(
    input_dir = input_dir,
    output_root = output_root
  )
}

assert_required_input_files <- function(input_dir) {
  required_input_files <- c(
    "assets.csv",
    "scenarios.csv",
    "financial_features.csv",
    "ngfs_carbon_price.csv"
  )

  missing <- required_input_files[!file.exists(file.path(input_dir, required_input_files))]
  if (length(missing) > 0) {
    stop(sprintf(
      "Missing TRISK input files. Run scripts/trisk_prepare_inputs.R first.\nMissing:\n  %s",
      paste(missing, collapse = "\n  ")
    ))
  }
}

load_alignment_context <- function(sector, meta, input_dir) {
  power_alignment <- read_csv(
    file.path(getwd(), "synthesis_output", "vietnam", "04_vn_ms_company.csv"),
    show_col_types = FALSE
  ) %>%
    filter(
      sector == "power",
      scenario_source == "pdp8_2023",
      year == 2030,
      metric %in% c("projected", "target_pdp8_ndc")
    ) %>%
    select(name_abcd, technology, metric, technology_share) %>%
    group_by(name_abcd, technology, metric) %>%
    summarise(technology_share = mean(technology_share, na.rm = TRUE), .groups = "drop") %>%
    pivot_wider(names_from = metric, values_from = technology_share) %>%
    mutate(
      target_share = target_pdp8_ndc,
      projected_share = projected,
      alignment_gap_pp = (projected_share - target_share) * 100
    ) %>%
    filter(!is.na(alignment_gap_pp)) %>%
    group_by(name_abcd) %>%
    summarise(
      mean_abs_alignment_gap_pp = if_else(
        all(is.na(alignment_gap_pp)),
        0,
        mean(abs(alignment_gap_pp), na.rm = TRUE)
      ),
      worst_alignment_gap_pp = if_else(
        all(is.na(alignment_gap_pp)),
        0,
        alignment_gap_pp[which.max(abs(alignment_gap_pp))]
      ),
      alignment_context = "Borrower-level PACTA market-share gap",
      .groups = "drop"
    )

  sda_alignment <- read_csv(
    file.path(getwd(), "synthesis_output", "vietnam", "06_vn_sda_alignment_2030.csv"),
    show_col_types = FALSE
  ) %>%
    mutate(
      mean_abs_alignment_gap_pp = abs(gap_pct),
      worst_alignment_gap_pp = gap_pct,
      alignment_context = sprintf("Sector-level SDA gap (%s, 2030)", sector)
    ) %>%
    select(sector, mean_abs_alignment_gap_pp, worst_alignment_gap_pp, alignment_context)

  if (meta$alignment_mode == "company_ms") {
    power_alignment %>% rename(company_name = name_abcd)
  } else {
    sector_gap <- sda_alignment %>% filter(sector == !!sector)
    assets <- read_csv(file.path(input_dir, "assets.csv"), show_col_types = FALSE)
    tibble(company_name = unique(assets$company_name)) %>%
      mutate(
        mean_abs_alignment_gap_pp = sector_gap$mean_abs_alignment_gap_pp[[1]],
        worst_alignment_gap_pp = sector_gap$worst_alignment_gap_pp[[1]],
        alignment_context = sector_gap$alignment_context[[1]]
      )
  }
}

build_run_params <- function(meta, input_dir, output_path, overrides = list()) {
  modifyList(
    c(
      list(
        input_path = input_dir,
        output_path = output_path,
        baseline_scenario = meta$baseline_scenario,
        target_scenario = meta$target_scenario,
        scenario_geography = meta$scenario_geography,
        carbon_price_model = meta$carbon_price_model
      ),
      trisk_base_params
    ),
    overrides
  )
}

summarize_trisk_run <- function(npv_results, pd_results, alignment_company) {
  pd_summary <- pd_results %>%
    group_by(company_id, company_name, sector) %>%
    summarise(
      pd_baseline = suppressWarnings(max(pd_baseline, na.rm = TRUE)),
      pd_shock = suppressWarnings(max(pd_shock, na.rm = TRUE)),
      .groups = "drop"
    ) %>%
    mutate(
      pd_baseline = if_else(is.infinite(pd_baseline), NA_real_, pd_baseline),
      pd_shock = if_else(is.infinite(pd_shock), NA_real_, pd_shock),
      pd_change = pd_shock - pd_baseline
    )

  company_summary <- npv_results %>%
    group_by(company_id, company_name, sector) %>%
    summarise(
      assets = n_distinct(asset_id),
      npv_baseline = sum(net_present_value_baseline, na.rm = TRUE),
      npv_shock = sum(net_present_value_shock, na.rm = TRUE),
      npv_difference = sum(net_present_value_difference, na.rm = TRUE),
      .groups = "drop"
    ) %>%
    mutate(
      npv_change = if_else(npv_baseline != 0, npv_difference / npv_baseline, NA_real_)
    ) %>%
    left_join(pd_summary, by = c("company_id", "company_name", "sector")) %>%
    arrange(npv_change)

  npv_range <- range(-company_summary$npv_change, na.rm = TRUE)
  pd_range <- range(company_summary$pd_change, na.rm = TRUE)

  prioritization <- company_summary %>%
    left_join(alignment_company, by = "company_name") %>%
    mutate(
      mean_abs_alignment_gap_pp = replace_na(mean_abs_alignment_gap_pp, 0),
      worst_alignment_gap_pp = replace_na(worst_alignment_gap_pp, 0),
      alignment_context = replace_na(alignment_context, "No alignment context available")
    )

  gap_range <- range(prioritization$mean_abs_alignment_gap_pp, na.rm = TRUE)

  prioritization <- prioritization %>%
    mutate(
      stress_priority_score = rescale(-npv_change, to = c(0, 100), from = npv_range) * 0.7 +
        rescale(pd_change, to = c(0, 100), from = pd_range) * 0.2 +
        rescale(mean_abs_alignment_gap_pp, to = c(0, 100), from = gap_range) * 0.1
    ) %>%
    arrange(desc(stress_priority_score))

  list(
    pd_summary = pd_summary,
    company_summary = company_summary,
    prioritization = prioritization
  )
}

execute_trisk_run <- function(sector, run_label, output_path, overrides = list(), meta = NULL, input_dir = NULL, alignment_company = NULL) {
  assert_supported_sector(sector)
  if (is.null(meta)) {
    meta <- trisk_sector_meta[[sector]]
  }

  paths <- resolve_trisk_paths(sector, output_root = dirname(output_path))
  if (is.null(input_dir)) {
    input_dir <- paths$input_dir
  }
  assert_required_input_files(input_dir)

  if (is.null(alignment_company)) {
    alignment_company <- load_alignment_context(sector, meta, input_dir)
  }

  dir.create(output_path, recursive = TRUE, showWarnings = FALSE)
  run_args <- build_run_params(meta, input_dir, output_path, overrides)
  run_path <- do.call(trisk.model::run_trisk, run_args)

  npv_results <- read_csv(file.path(run_path, "npv_results.csv"), show_col_types = FALSE)
  pd_results <- read_csv(file.path(run_path, "pd_results.csv"), show_col_types = FALSE)
  company_trajectories <- read_csv(file.path(run_path, "company_trajectories.csv"), show_col_types = FALSE)
  params <- read_csv(file.path(run_path, "params.csv"), show_col_types = FALSE)

  summaries <- summarize_trisk_run(npv_results, pd_results, alignment_company)

  list(
    run_label = run_label,
    run_path = run_path,
    params = params,
    npv_results = npv_results,
    pd_results = pd_results,
    company_trajectories = company_trajectories,
    pd_summary = summaries$pd_summary,
    company_summary = summaries$company_summary,
    prioritization = summaries$prioritization
  )
}

run_trisk_sensitivity_case <- function(run_label, parameter_name, parameter_value, shock_year, discount_rate, risk_free_rate, market_passthrough, sector, output_root, meta, input_dir, alignment_company) {
  run_output_dir <- file.path(output_root, "runs", run_label)
  result <- execute_trisk_run(
    sector = sector,
    run_label = run_label,
    output_path = run_output_dir,
    overrides = list(
      shock_year = shock_year,
      discount_rate = discount_rate,
      risk_free_rate = risk_free_rate,
      market_passthrough = market_passthrough
    ),
    meta = meta,
    input_dir = input_dir,
    alignment_company = alignment_company
  )

  c(
    result,
    list(
      parameter_name = parameter_name,
      parameter_value = parameter_value
    )
  )
}

write_trisk_demo_outputs <- function(sector, output_root, meta, run_results) {
  base_run <- run_results[["base"]]

  write_csv(base_run$company_summary, file.path(output_root, "company_summary.csv"))
  write_csv(base_run$prioritization, file.path(output_root, "top_borrowers_alignment_trisk.csv"))
  write_csv(base_run$params, file.path(output_root, "params_latest.csv"))
  write_csv(base_run$pd_summary, file.path(output_root, "pd_summary.csv"))
  write_csv(base_run$npv_results, file.path(output_root, "npv_results_latest.csv"))
  write_csv(base_run$pd_results, file.path(output_root, "pd_results_latest.csv"))
  write_csv(base_run$company_trajectories, file.path(output_root, "company_trajectories_latest.csv"))

  sensitivity_results <- imap_dfr(run_results, function(result, result_run_label) {
    result$prioritization %>%
      transmute(
        run_label = result_run_label,
        parameter_name = result$parameter_name,
        parameter_value = result$parameter_value,
        company_id,
        company_name,
        sector,
        npv_change,
        pd_change,
        mean_abs_alignment_gap_pp,
        worst_alignment_gap_pp,
        alignment_context,
        stress_priority_score
      )
  })

  base_metrics <- sensitivity_results %>%
    filter(run_label == "base") %>%
    select(
      company_id,
      base_npv_change = npv_change,
      base_pd_change = pd_change,
      base_stress_priority_score = stress_priority_score
    )

  sensitivity_results <- sensitivity_results %>%
    left_join(base_metrics, by = "company_id") %>%
    mutate(
      delta_npv_change_vs_base = npv_change - base_npv_change,
      delta_pd_change_vs_base = pd_change - base_pd_change,
      delta_priority_vs_base = stress_priority_score - base_stress_priority_score
    )

  sensitivity_summary <- sensitivity_results %>%
    filter(run_label != "base") %>%
    group_by(run_label, parameter_name, parameter_value) %>%
    summarise(
      borrower_count = sum(!is.na(stress_priority_score)),
      average_npv_change = mean(npv_change, na.rm = TRUE),
      average_pd_change = mean(pd_change, na.rm = TRUE),
      average_priority_delta = mean(delta_priority_vs_base, na.rm = TRUE),
      max_priority_delta = max(delta_priority_vs_base, na.rm = TRUE),
      max_priority_delta_company = company_name[which.max(replace_na(delta_priority_vs_base, -Inf))],
      min_priority_delta = min(delta_priority_vs_base, na.rm = TRUE),
      min_priority_delta_company = company_name[which.min(replace_na(delta_priority_vs_base, Inf))],
      top_ranked_company = company_name[which.max(replace_na(stress_priority_score, -Inf))],
      .groups = "drop"
    )

  run_catalog <- tibble(
    run_label = map_chr(run_results, "run_label"),
    parameter_name = map_chr(run_results, "parameter_name"),
    parameter_value = map_chr(run_results, "parameter_value"),
    run_path = map_chr(run_results, "run_path")
  )

  write_csv(sensitivity_results, file.path(output_root, "sensitivity_results.csv"))
  write_csv(sensitivity_summary, file.path(output_root, "sensitivity_summary.csv"))
  write_csv(run_catalog, file.path(output_root, "run_catalog.csv"))

  figures_dir <- file.path(output_root, "figures")
  dir.create(figures_dir, recursive = TRUE, showWarnings = FALSE)

  p_npv <- base_run$company_summary %>%
    mutate(company_name = reorder(company_name, npv_change)) %>%
    ggplot(aes(x = company_name, y = npv_change, fill = npv_change < 0)) +
    geom_col(show.legend = FALSE) +
    coord_flip() +
    scale_fill_manual(values = c("TRUE" = "#c0392b", "FALSE" = "#27ae60")) +
    scale_y_continuous(labels = percent_format(accuracy = 1)) +
    labs(
      title = sprintf("Vietnam TRISK Pilot: NPV Change by %s Borrower", meta$title),
      subtitle = sprintf("Baseline: %s | Stress: %s | shock year 2028", meta$baseline_scenario, meta$target_scenario),
      x = NULL,
      y = "NPV change"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(figures_dir, "01_npv_change_by_company.png"), p_npv, width = 10, height = 6, dpi = 150)

  p_pd <- base_run$pd_summary %>%
    mutate(company_name = reorder(company_name, pd_change)) %>%
    ggplot(aes(x = company_name, y = pd_change, fill = pd_change > 0)) +
    geom_col(show.legend = FALSE) +
    coord_flip() +
    scale_fill_manual(values = c("TRUE" = "#d35400", "FALSE" = "#2980b9")) +
    scale_y_continuous(labels = percent_format(accuracy = 0.1)) +
    labs(
      title = sprintf("Vietnam TRISK Pilot: PD Change by %s Borrower", meta$title),
      subtitle = "Stress-induced change in model PD summary",
      x = NULL,
      y = "PD change"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(figures_dir, "02_pd_change_by_company.png"), p_pd, width = 10, height = 6, dpi = 150)

  p_priority <- base_run$prioritization %>%
    slice_max(order_by = stress_priority_score, n = 10, with_ties = FALSE) %>%
    mutate(company_name = reorder(company_name, stress_priority_score)) %>%
    ggplot(aes(x = company_name, y = stress_priority_score, fill = mean_abs_alignment_gap_pp)) +
    geom_col() +
    coord_flip() +
    scale_fill_gradient(low = "#74b9ff", high = "#e74c3c") +
    labs(
      title = sprintf("Vietnam TRISK Pilot: Top %s Borrower Priority Score", meta$title),
      subtitle = "Composite of NPV deterioration, PD change, and alignment context",
      x = NULL,
      y = "Priority score",
      fill = "Avg abs\nalignment gap (pp)"
    ) +
    theme_minimal(base_size = 12) +
    theme(plot.title = element_text(face = "bold"))

  ggsave(file.path(figures_dir, "03_priority_score_top10.png"), p_priority, width = 10, height = 6, dpi = 150)

  list(
    base_run = base_run,
    sensitivity_results = sensitivity_results,
    sensitivity_summary = sensitivity_summary,
    run_catalog = run_catalog,
    figures_dir = figures_dir
  )
}

run_sector_demo <- function(sector = "power") {
  sector <- tolower(sector)
  assert_supported_sector(sector)

  meta <- trisk_sector_meta[[sector]]

  cat("========================================\n")
  cat(sprintf("Running Vietnam TRISK %s demo\n", meta$title))
  cat("========================================\n\n")

  paths <- resolve_trisk_paths(sector)
  input_dir <- paths$input_dir
  output_root <- paths$output_root

  assert_required_input_files(input_dir)
  alignment_company <- load_alignment_context(sector, meta, input_dir)

  cat("Executing base and sensitivity TRISK runs...\n\n")

  run_results <- pmap(
    trisk_sensitivity_specs,
    run_trisk_sensitivity_case,
    sector = sector,
    output_root = output_root,
    meta = meta,
    input_dir = input_dir,
    alignment_company = alignment_company
  )
  names(run_results) <- trisk_sensitivity_specs$run_label

  written_outputs <- write_trisk_demo_outputs(sector, output_root, meta, run_results)
  base_run <- written_outputs$base_run

  cat(sprintf("Base TRISK run folder: %s\n\n", base_run$run_path))
  cat("Top borrower stress summary:\n")
  print(as.data.frame(base_run$prioritization %>%
    select(company_name, npv_change, pd_change, mean_abs_alignment_gap_pp, alignment_context, stress_priority_score) %>%
    mutate(
      npv_change = round(npv_change, 4),
      pd_change = round(pd_change, 5),
      mean_abs_alignment_gap_pp = round(mean_abs_alignment_gap_pp, 2),
      stress_priority_score = round(stress_priority_score, 1)
    ) %>%
    head(10)))

  cat("\nSaved outputs:\n")
  cat(sprintf("  %s\n", file.path(output_root, "company_summary.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "top_borrowers_alignment_trisk.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "sensitivity_results.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "sensitivity_summary.csv")))
  cat(sprintf("  %s\n", file.path(output_root, "run_catalog.csv")))
  cat(sprintf("  %s\n", written_outputs$figures_dir))

  invisible(list(
    sector = sector,
    meta = meta,
    paths = paths,
    alignment_company = alignment_company,
    run_results = run_results,
    written_outputs = written_outputs
  ))
}

if (sys.nframe() == 0) {
  args <- commandArgs(trailingOnly = TRUE)
  sector <- if (length(args) >= 1) tolower(args[[1]]) else "power"
  run_sector_demo(sector)
}

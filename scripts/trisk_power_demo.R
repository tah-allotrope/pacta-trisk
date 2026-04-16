# ==============================================================================
# trisk_power_demo.R
# Run a package-backed TRISK pilot for the synthetic Vietnam power portfolio.
#
# Prerequisite:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_power_demo.R
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

cat("========================================\n")
cat("Running Vietnam TRISK power demo\n")
cat("========================================\n\n")

input_dir <- file.path(getwd(), "output", "trisk_inputs", "power_demo")
output_root <- file.path(getwd(), "synthesis_output", "trisk", "power_demo")
dir.create(output_root, recursive = TRUE, showWarnings = FALSE)

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

alignment_company <- read_csv(
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
    .groups = "drop"
  )

base_params <- list(
  input_path = input_dir,
  output_path = output_root,
  baseline_scenario = "VN_PDP8_BASELINE",
  target_scenario = "VN_NZE_STRESS",
  scenario_geography = "Vietnam",
  carbon_price_model = "increasing_carbon_tax_50",
  shock_year = 2028,
  discount_rate = 0.08,
  risk_free_rate = 0.03,
  growth_rate = 0.02,
  div_netprofit_prop_coef = 1,
  market_passthrough = 0.25,
  show_params_cols = TRUE
)

sensitivity_specs <- tribble(
  ~run_label,                         ~parameter_name,       ~parameter_value, ~shock_year, ~discount_rate, ~risk_free_rate, ~market_passthrough,
  "base",                            "base",               "base",          2028,        0.08,           0.03,            0.25,
  "shock_year_2027",                "shock_year",         "2027",          2027,        0.08,           0.03,            0.25,
  "shock_year_2029",                "shock_year",         "2029",          2029,        0.08,           0.03,            0.25,
  "discount_rate_0.06",             "discount_rate",      "0.06",          2028,        0.06,           0.03,            0.25,
  "discount_rate_0.10",             "discount_rate",      "0.10",          2028,        0.10,           0.03,            0.25,
  "risk_free_rate_0.02",            "risk_free_rate",     "0.02",          2028,        0.08,           0.02,            0.25,
  "risk_free_rate_0.04",            "risk_free_rate",     "0.04",          2028,        0.08,           0.04,            0.25,
  "market_passthrough_0.15",        "market_passthrough", "0.15",          2028,        0.08,           0.03,            0.15,
  "market_passthrough_0.35",        "market_passthrough", "0.35",          2028,        0.08,           0.03,            0.35
)

summarize_run <- function(npv_results, pd_results, alignment_company) {
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

  prioritization <- company_summary %>%
    left_join(alignment_company, by = c("company_name" = "name_abcd")) %>%
    mutate(
      mean_abs_alignment_gap_pp = replace_na(mean_abs_alignment_gap_pp, 0),
      worst_alignment_gap_pp = replace_na(worst_alignment_gap_pp, 0),
      stress_priority_score = rescale(-npv_change, to = c(0, 100), from = range(-npv_change, na.rm = TRUE)) * 0.7 +
        rescale(pd_change, to = c(0, 100), from = range(pd_change, na.rm = TRUE)) * 0.2 +
        rescale(mean_abs_alignment_gap_pp, to = c(0, 100), from = range(mean_abs_alignment_gap_pp, na.rm = TRUE)) * 0.1
    ) %>%
    arrange(desc(stress_priority_score))

  list(
    pd_summary = pd_summary,
    company_summary = company_summary,
    prioritization = prioritization
  )
}

run_trisk_case <- function(run_label, parameter_name, parameter_value, shock_year, discount_rate, risk_free_rate, market_passthrough) {
  run_output_dir <- file.path(output_root, "runs", run_label)
  dir.create(run_output_dir, recursive = TRUE, showWarnings = FALSE)

  run_args <- modifyList(base_params, list(
    output_path = run_output_dir,
    shock_year = shock_year,
    discount_rate = discount_rate,
    risk_free_rate = risk_free_rate,
    market_passthrough = market_passthrough
  ))

  run_path <- do.call(trisk.model::run_trisk, run_args)

  npv_results <- read_csv(file.path(run_path, "npv_results.csv"), show_col_types = FALSE)
  pd_results <- read_csv(file.path(run_path, "pd_results.csv"), show_col_types = FALSE)
  company_trajectories <- read_csv(file.path(run_path, "company_trajectories.csv"), show_col_types = FALSE)
  params <- read_csv(file.path(run_path, "params.csv"), show_col_types = FALSE)

  summaries <- summarize_run(npv_results, pd_results, alignment_company)

  list(
    run_label = run_label,
    parameter_name = parameter_name,
    parameter_value = parameter_value,
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

cat("Executing base and sensitivity TRISK runs...\n\n")

run_results <- pmap(
  sensitivity_specs,
  run_trisk_case
)

names(run_results) <- sensitivity_specs$run_label

base_run <- run_results[["base"]]

cat(sprintf("Base TRISK run folder: %s\n\n", base_run$run_path))

write_csv(base_run$company_summary, file.path(output_root, "company_summary.csv"))
write_csv(base_run$prioritization, file.path(output_root, "top_borrowers_alignment_trisk.csv"))
write_csv(base_run$params, file.path(output_root, "params_latest.csv"))
write_csv(base_run$pd_summary, file.path(output_root, "pd_summary.csv"))
write_csv(base_run$npv_results, file.path(output_root, "npv_results_latest.csv"))
write_csv(base_run$pd_results, file.path(output_root, "pd_results_latest.csv"))
write_csv(base_run$company_trajectories, file.path(output_root, "company_trajectories_latest.csv"))

sensitivity_results <- imap_dfr(run_results, function(result, run_label) {
  result$prioritization %>%
    transmute(
      run_label = run_label,
      parameter_name = result$parameter_name,
      parameter_value = result$parameter_value,
      company_id,
      company_name,
      sector,
      npv_change,
      pd_change,
      mean_abs_alignment_gap_pp,
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
    title = "Vietnam TRISK Pilot: NPV Change by Power Borrower",
    subtitle = "Baseline: VN_PDP8_BASELINE | Stress: VN_NZE_STRESS | shock year 2028",
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
    title = "Vietnam TRISK Pilot: PD Change by Power Borrower",
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
    title = "Vietnam TRISK Pilot: Top Borrower Priority Score",
    subtitle = "Composite of NPV deterioration, PD change, and PACTA alignment gap",
    x = NULL,
    y = "Priority score",
    fill = "Avg abs\nalignment gap (pp)"
  ) +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

ggsave(file.path(figures_dir, "03_priority_score_top10.png"), p_priority, width = 10, height = 6, dpi = 150)

cat("Top borrower stress summary:\n")
print(as.data.frame(base_run$prioritization %>%
  select(company_name, npv_change, pd_change, mean_abs_alignment_gap_pp, stress_priority_score) %>%
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
cat(sprintf("  %s\n", figures_dir))

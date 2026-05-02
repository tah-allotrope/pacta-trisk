#!/usr/bin/env Rscript
# ==============================================================================
# trisk_scenario_grid.R
# Build the precomputed multi-parameter TRISK scenario grid for the Scenario Builder.
#
# Usage:
#   Rscript scripts/trisk_scenario_grid.R
#   Rscript scripts/trisk_scenario_grid.R power
# ==============================================================================

suppressPackageStartupMessages({
  library(arrow)
  library(dplyr)
  library(jsonlite)
  library(purrr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source(file.path(getwd(), "scripts", "trisk_sector_demo.R"), local = TRUE)

grid_contract_version <- "v1"

grid_levers <- list(
  shock_year = c(2026L, 2028L, 2030L),
  discount_rate = c(0.06, 0.08, 0.10),
  risk_free_rate = c(0.02, 0.03, 0.04),
  market_passthrough = c(0.15, 0.25, 0.35),
  carbon_price_family = c("NGFS_NetZero2050", "NGFS_Below2C", "NGFS_Delayed")
)

carbon_price_model_map <- list(
  power = c(
    NGFS_NetZero2050 = "increasing_carbon_tax_50",
    NGFS_Below2C = "increasing_carbon_tax_50",
    NGFS_Delayed = "increasing_carbon_tax_50"
  ),
  cement = c(
    NGFS_NetZero2050 = "cement_intensity_transition",
    NGFS_Below2C = "cement_intensity_transition",
    NGFS_Delayed = "cement_intensity_transition"
  ),
  steel = c(
    NGFS_NetZero2050 = "steel_intensity_transition",
    NGFS_Below2C = "steel_intensity_transition",
    NGFS_Delayed = "steel_intensity_transition"
  )
)

build_scenario_id <- function(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family) {
  sprintf(
    "s%s_d%.2f_rf%.2f_mp%.2f_c%s",
    shock_year,
    discount_rate,
    risk_free_rate,
    market_passthrough,
    carbon_price_family
  )
}

build_grid_label <- function(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family) {
  paste(
    sprintf("shock %s", shock_year),
    sprintf("disc %.2f", discount_rate),
    sprintf("rf %.2f", risk_free_rate),
    sprintf("pass %.2f", market_passthrough),
    carbon_price_family,
    sep = " | "
  )
}

build_sector_grid <- function(sector_name) {
  tibble(
    shock_year = grid_levers$shock_year
  ) %>%
    crossing(
      discount_rate = grid_levers$discount_rate,
      risk_free_rate = grid_levers$risk_free_rate,
      market_passthrough = grid_levers$market_passthrough,
      carbon_price_family = grid_levers$carbon_price_family
    ) %>%
    mutate(
      sector = sector_name,
      carbon_price_model = unname(carbon_price_model_map[[sector_name]][carbon_price_family]),
      scenario_id = pmap_chr(
        list(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family),
        build_scenario_id
      ),
      grid_label = pmap_chr(
        list(shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family),
        build_grid_label
      )
    ) %>%
    select(
      scenario_id,
      sector,
      shock_year,
      discount_rate,
      risk_free_rate,
      market_passthrough,
      carbon_price_family,
      carbon_price_model,
      grid_label
    )
}

read_existing_grid <- function(grid_dir) {
  scenarios_path <- file.path(grid_dir, "scenarios.csv")
  borrower_path <- file.path(grid_dir, "borrower_results.parquet")

  scenarios <- if (file.exists(scenarios_path)) {
    read_csv(scenarios_path, show_col_types = FALSE)
  } else {
    tibble()
  }

  borrower_results <- if (file.exists(borrower_path)) {
    read_parquet(borrower_path) %>% as_tibble()
  } else {
    tibble()
  }

  list(
    scenarios = scenarios,
    borrower_results = borrower_results
  )
}

extend_yearly_inputs <- function(df, group_cols, year_col, value_cols, target_year, lower_bounds = list()) {
  year_sym <- rlang::sym(year_col)

  df %>%
    group_by(across(all_of(group_cols))) %>%
    group_modify(function(.x, .y) {
      data <- .x %>% arrange(!!year_sym)
      current_max_year <- max(data[[year_col]], na.rm = TRUE)

      if (current_max_year >= target_year) {
        return(data)
      }

      for (new_year in seq(current_max_year + 1, target_year)) {
        next_row <- data[nrow(data), , drop = FALSE]
        next_row[[year_col]] <- new_year

        for (col in value_cols) {
          values <- data[[col]]
          years <- data[[year_col]]
          non_na_idx <- which(!is.na(values))

          if (length(non_na_idx) >= 2) {
            last_two <- tail(non_na_idx, 2)
            delta <- values[last_two[2]] - values[last_two[1]]
            next_value <- values[last_two[2]] + delta * (new_year - years[last_two[2]])
          } else if (length(non_na_idx) == 1) {
            next_value <- values[non_na_idx]
          } else {
            next_value <- NA_real_
          }

          lower_bound <- lower_bounds[[col]]
          if (!is.null(lower_bound) && !is.na(next_value)) {
            next_value <- max(lower_bound, next_value)
          }

          next_row[[col]] <- next_value
        }

        data <- bind_rows(data, next_row)
      }

      data
    }) %>%
    ungroup()
}

build_grid_input_dir <- function(sector, source_input_dir, grid_dir) {
  grid_input_dir <- file.path(grid_dir, "input")
  dir.create(grid_input_dir, recursive = TRUE, showWarnings = FALSE)

  file.copy(file.path(source_input_dir, "assets.csv"), file.path(grid_input_dir, "assets.csv"), overwrite = TRUE)
  file.copy(file.path(source_input_dir, "financial_features.csv"), file.path(grid_input_dir, "financial_features.csv"), overwrite = TRUE)

  target_year <- max(grid_levers$shock_year) + 2L

  scenarios <- read_csv(file.path(source_input_dir, "scenarios.csv"), show_col_types = FALSE) %>%
    extend_yearly_inputs(
      group_cols = c("scenario", "scenario_type", "scenario_geography", "sector", "technology", "technology_type", "price_unit", "pathway_unit", "country_iso2_list", "scenario_provider"),
      year_col = "scenario_year",
      value_cols = c("scenario_price", "scenario_pathway", "scenario_capacity_factor"),
      target_year = target_year,
      lower_bounds = list(
        scenario_price = 0,
        scenario_pathway = 0,
        scenario_capacity_factor = 0
      )
    )

  carbon_price <- read_csv(file.path(source_input_dir, "ngfs_carbon_price.csv"), show_col_types = FALSE) %>%
    extend_yearly_inputs(
      group_cols = c("model", "scenario", "scenario_geography", "variable", "unit"),
      year_col = "year",
      value_cols = c("carbon_tax"),
      target_year = target_year,
      lower_bounds = list(carbon_tax = 0)
    )

  write_csv(scenarios, file.path(grid_input_dir, "scenarios.csv"))
  write_csv(carbon_price, file.path(grid_input_dir, "ngfs_carbon_price.csv"))

  grid_input_dir
}

find_cached_run_path <- function(run_output_dir) {
  if (!dir.exists(run_output_dir)) {
    return(NULL)
  }

  subdirs <- list.dirs(run_output_dir, recursive = FALSE, full.names = TRUE)
  if (length(subdirs) == 0) {
    return(NULL)
  }

  valid_subdirs <- subdirs[file.exists(file.path(subdirs, "npv_results.csv"))]
  if (length(valid_subdirs) == 0) {
    return(NULL)
  }

  valid_subdirs[which.max(file.info(valid_subdirs)$mtime)]
}

load_cached_run <- function(run_path, alignment_company, scenario_id, sector) {
  npv_results <- read_csv(file.path(run_path, "npv_results.csv"), show_col_types = FALSE)
  pd_results <- read_csv(file.path(run_path, "pd_results.csv"), show_col_types = FALSE)

  summaries <- summarize_trisk_run(npv_results, pd_results, alignment_company)

  build_borrower_results(
    summaries$prioritization,
    tibble(scenario_id = scenario_id, sector = sector)
  )
}

build_borrower_results <- function(prioritization, grid_row) {
  prioritization %>%
    mutate(
      scenario_id = grid_row$scenario_id,
      sector = grid_row$sector,
      rank_within_scenario = row_number(desc(stress_priority_score))
    ) %>%
    transmute(
      scenario_id,
      sector,
      company_id,
      company_name,
      npv_change_pct = npv_change,
      pd_change_pct = pd_change,
      stress_priority_score,
      delta_npv_change_vs_base = NA_real_,
      delta_pd_change_vs_base = NA_real_,
      rank_within_scenario,
      mean_abs_alignment_gap_pp,
      worst_alignment_gap_pp,
      alignment_context,
      npv_baseline,
      npv_shock,
      npv_difference,
      pd_baseline,
      pd_shock,
      pd_change,
      assets
    )
}

apply_base_deltas <- function(borrower_results, sector) {
  base_results_path <- file.path(getwd(), "synthesis_output", "trisk", paste0(sector, "_demo"), "sensitivity_results.csv")
  base_results <- read_csv(base_results_path, show_col_types = FALSE) %>%
    filter(run_label == "base") %>%
    select(company_id, base_npv_change = npv_change, base_pd_change = pd_change)

  borrower_results %>%
    left_join(base_results, by = "company_id") %>%
    mutate(
      delta_npv_change_vs_base = npv_change_pct - base_npv_change,
      delta_pd_change_vs_base = pd_change_pct - base_pd_change
    ) %>%
    select(-base_npv_change, -base_pd_change)
}

run_sector_grid <- function(sector) {
  assert_supported_sector(sector)
  meta <- trisk_sector_meta[[sector]]
  paths <- resolve_trisk_paths(sector)
  input_dir <- paths$input_dir

  assert_required_input_files(input_dir)
  alignment_company <- load_alignment_context(sector, meta, input_dir)

  grid_dir <- file.path(getwd(), "synthesis_output", "trisk", "grid", sector)
  runs_dir <- file.path(grid_dir, "runs")
  dir.create(runs_dir, recursive = TRUE, showWarnings = FALSE)
  grid_input_dir <- build_grid_input_dir(sector, input_dir, grid_dir)

  existing <- read_existing_grid(grid_dir)
  sector_grid <- build_sector_grid(sector)
  completed_ids <- if ("scenario_id" %in% names(existing$borrower_results)) {
    unique(existing$borrower_results$scenario_id)
  } else {
    character()
  }
  pending_grid <- sector_grid %>% filter(!(scenario_id %in% completed_ids))
  scenarios_path <- file.path(grid_dir, "scenarios.csv")
  borrower_path <- file.path(grid_dir, "borrower_results.parquet")
  meta_path <- file.path(grid_dir, "grid_meta.json")

  cat(sprintf("\n[%s] %d total scenarios, %d cached, %d pending.\n",
    sector,
    nrow(sector_grid),
    length(completed_ids),
    nrow(pending_grid)
  ))

  if (nrow(pending_grid) == 0 && nrow(existing$borrower_results) > 0 && file.exists(scenarios_path) && file.exists(borrower_path) && file.exists(meta_path)) {
    cat(sprintf("  [%s] grid already complete, skipping regeneration.\n", sector))
    return(invisible(list(
      sector = sector,
      scenarios = sector_grid,
      borrower_results = existing$borrower_results,
      grid_meta = jsonlite::read_json(meta_path, simplifyVector = TRUE)
    )))
  }

  started_at <- Sys.time()

  new_results <- pmap_dfr(pending_grid, function(scenario_id, sector, shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family, carbon_price_model, grid_label) {
    run_output_dir <- file.path(runs_dir, scenario_id)
    cached_run_path <- find_cached_run_path(run_output_dir)

    if (!is.null(cached_run_path)) {
      cat(sprintf("  [%s] reusing cached %s\n", sector, scenario_id))
      return(load_cached_run(cached_run_path, alignment_company, scenario_id, sector))
    }

    cat(sprintf("  [%s] running %s\n", sector, scenario_id))

    result <- execute_trisk_run(
      sector = sector,
      run_label = scenario_id,
      output_path = run_output_dir,
      overrides = list(
        shock_year = shock_year,
        discount_rate = discount_rate,
        risk_free_rate = risk_free_rate,
        market_passthrough = market_passthrough,
        carbon_price_model = carbon_price_model
      ),
      meta = modifyList(meta, list(carbon_price_model = carbon_price_model)),
      input_dir = grid_input_dir,
      alignment_company = alignment_company
    )

    build_borrower_results(
      result$prioritization,
      tibble(
        scenario_id = scenario_id,
        sector = sector,
        shock_year = shock_year,
        discount_rate = discount_rate,
        risk_free_rate = risk_free_rate,
        market_passthrough = market_passthrough,
        carbon_price_family = carbon_price_family,
        carbon_price_model = carbon_price_model,
        grid_label = grid_label
      )
    )
  })

  borrower_results <- bind_rows(existing$borrower_results, new_results) %>%
    distinct(scenario_id, company_id, .keep_all = TRUE) %>%
    arrange(scenario_id, desc(stress_priority_score), company_name)

  borrower_results <- apply_base_deltas(borrower_results, sector)

  write_csv(sector_grid, scenarios_path)

  parquet_tmp_path <- file.path(grid_dir, "borrower_results.tmp.parquet")
  write_parquet(borrower_results, parquet_tmp_path)
  if (file.exists(borrower_path)) {
    unlink(borrower_path, force = TRUE)
  }
  file.rename(parquet_tmp_path, borrower_path)

  runtime_seconds <- as.numeric(difftime(Sys.time(), started_at, units = "secs"))
  grid_meta <- list(
    sector = sector,
    scenario_count = nrow(sector_grid),
    generated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    runtime_seconds = round(runtime_seconds, 3),
    trisk_model_version = as.character(utils::packageVersion("trisk.model", lib.loc = lib)),
    grid_contract_version = grid_contract_version,
    cached_scenarios = length(completed_ids),
    generated_scenarios = nrow(pending_grid)
  )

  write_json(grid_meta, meta_path, auto_unbox = TRUE, pretty = TRUE)

  invisible(list(
    sector = sector,
    scenarios = sector_grid,
    borrower_results = borrower_results,
    grid_meta = grid_meta
  ))
}

args <- commandArgs(trailingOnly = TRUE)
selected_sectors <- if (length(args) == 0) {
  trisk_supported_sectors
} else {
  unique(tolower(args))
}

walk(selected_sectors, assert_supported_sector)

cat("========================================\n")
cat("Building TRISK scenario grid\n")
cat("========================================\n")

walk(selected_sectors, run_sector_grid)

cat("\nScenario grid generation complete.\n")

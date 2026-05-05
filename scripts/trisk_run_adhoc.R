#!/usr/bin/env Rscript
# ==============================================================================
# trisk_run_adhoc.R
# Operator-side live-rerun adapter for the Scenario Builder.
# Runs a single TRISK scenario with arbitrary lever values and writes a
# borrower-level CSV to a temp path printed on stdout.
#
# Usage:
#   Rscript scripts/trisk_run_adhoc.R \
#     --sector=power \
#     --shock_year=2027 \
#     --discount_rate=0.07 \
#     --risk_free_rate=0.025 \
#     --market_passthrough=0.30 \
#     --carbon_price_family=NGFS_NetZero2050
#
# The output CSV path is the ONLY line printed to stdout.
# Stderr is reserved for progress / diagnostics.
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(tibble)
  library(tidyr)
})

source(file.path(getwd(), "scripts", "trisk_sector_demo.R"), local = TRUE)

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

parse_arg <- function(args, name, default = NULL) {
  prefix <- paste0("--", name, "=")
  match <- args[startsWith(args, prefix)]
  if (length(match) > 0) {
    sub(prefix, "", match[[1]])
  } else {
    default
  }
}

args <- commandArgs(trailingOnly = TRUE)

sector <- parse_arg(args, "sector")
shock_year <- as.integer(parse_arg(args, "shock_year"))
discount_rate <- as.numeric(parse_arg(args, "discount_rate"))
risk_free_rate <- as.numeric(parse_arg(args, "risk_free_rate"))
market_passthrough <- as.numeric(parse_arg(args, "market_passthrough"))
carbon_price_family <- parse_arg(args, "carbon_price_family")

if (is.null(sector) || is.na(shock_year) || is.na(discount_rate) || is.na(risk_free_rate) || is.na(market_passthrough) || is.null(carbon_price_family)) {
  cat("ERROR: Missing or invalid arguments.\n", file = stderr())
  cat("Usage: Rscript scripts/trisk_run_adhoc.R --sector=power --shock_year=2028 --discount_rate=0.08 --risk_free_rate=0.03 --market_passthrough=0.25 --carbon_price_family=NGFS_NetZero2050\n", file = stderr())
  quit(status = 1)
}

assert_supported_sector(sector)

carbon_price_model <- unname(carbon_price_model_map[[sector]][carbon_price_family])
if (is.na(carbon_price_model)) {
  cat(sprintf("ERROR: Unknown carbon_price_family '%s' for sector '%s'.\n", carbon_price_family, sector), file = stderr())
  quit(status = 1)
}

meta <- trisk_sector_meta[[sector]]
meta$carbon_price_model <- carbon_price_model

paths <- resolve_trisk_paths(sector)
input_dir <- paths$input_dir
assert_required_input_files(input_dir)

cat(sprintf("Loading alignment context for %s...\n", sector), file = stderr())
alignment_company <- load_alignment_context(sector, meta, input_dir)

run_output_dir <- tempfile(pattern = paste0("trisk_adhoc_", sector, "_"))
cat(sprintf("Running TRISK for %s: shock_year=%d, discount_rate=%.2f, risk_free_rate=%.2f, market_passthrough=%.2f, carbon=%s\n",
    sector, shock_year, discount_rate, risk_free_rate, market_passthrough, carbon_price_family), file = stderr())

result <- execute_trisk_run(
  sector = sector,
  run_label = "adhoc",
  output_path = run_output_dir,
  overrides = list(
    shock_year = shock_year,
    discount_rate = discount_rate,
    risk_free_rate = risk_free_rate,
    market_passthrough = market_passthrough,
    carbon_price_model = carbon_price_model
  ),
  meta = meta,
  input_dir = input_dir,
  alignment_company = alignment_company
)

prioritization <- result$prioritization %>%
  mutate(
    npv_change_pct = npv_change,
    pd_change_pct = pd_change
  )

output_csv <- tempfile(pattern = paste0("trisk_adhoc_", sector, "_"), fileext = ".csv")
write_csv(prioritization, output_csv)

cat(sprintf("Wrote %d rows to %s\n", nrow(prioritization), output_csv), file = stderr())
cat(output_csv)
cat("\n")

invisible(0)

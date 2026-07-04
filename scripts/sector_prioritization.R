#!/usr/bin/env Rscript
# =============================================================================
# Sector Prioritization Module (GAP-03)
# =============================================================================
# Combines PACTA alignment gaps, TRISK stress-test scores, and portfolio
# exposure weights into a ranked sector priority list for Decision 263 sectors.
#
# Usage: Rscript scripts/sector_prioritization.R [--w_alignment 0.35] [--w_stress 0.35] [--w_exposure 0.30]
# =============================================================================

# --- Section 1: Configuration ------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

parse_arg <- function(args, name, default) {
  idx <- which(args == paste0("--", name))
  if (length(idx) > 0 && idx < length(args)) {
    return(as.numeric(args[idx + 1]))
  }
  default
}

w_alignment  <- parse_arg(args, "w_alignment",  0.35)
w_stress     <- parse_arg(args, "w_stress",     0.35)
w_exposure   <- parse_arg(args, "w_exposure",   0.30)

base_dir <- getwd()

alignment_file_ms <- file.path(base_dir, "synthesis_output", "vietnam", "06_vn_ms_alignment_2030.csv")
alignment_file_sda <- file.path(base_dir, "synthesis_output", "vietnam", "06_vn_sda_alignment_2030.csv")
trisk_dir <- file.path(base_dir, "dashboard", "data", "trisk")
loanbook_file <- file.path(base_dir, "data", "vietnam_loanbook.csv")
output_dir <- file.path(base_dir, "synthesis_output", "prioritization")

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

sectors <- c("power", "cement", "steel")
data_source <- "MCB_synthetic"

cat(sprintf("Sector Prioritization — weights: alignment=%.2f, stress=%.2f, exposure=%.2f\n",
            w_alignment, w_stress, w_exposure))

# --- Section 2: Load alignment data ------------------------------------------

cat("\n[1/6] Loading alignment data...\n")

ms_align <- readr::read_csv(alignment_file_ms, show_col_types = FALSE)
sda_align <- readr::read_csv(alignment_file_sda, show_col_types = FALSE)

# Extract alignment gap severity per sector
# Power: max positive share_gap_pp among high-carbon technologies (coalcap, gascap)
# Cement/Steel: gap_pct from SDA analysis

high_carbon_techs <- c("coalcap", "gascap")

power_gap <- ms_align |>
  dplyr::filter(sector == "power", technology %in% high_carbon_techs) |>
  dplyr::slice_max(share_gap_pp, n = 1) |>
  dplyr::pull(share_gap_pp)

cement_gap <- sda_align |>
  dplyr::filter(sector == "cement") |>
  dplyr::pull(gap_pct)

steel_gap <- sda_align |>
  dplyr::filter(sector == "steel") |>
  dplyr::pull(gap_pct)

alignment_raw <- c(
  power  = as.numeric(power_gap),
  cement = as.numeric(cement_gap),
  steel  = as.numeric(steel_gap)
)

cat(sprintf("  Power alignment gap:  %.2f pp (coalcap max positive)\n", alignment_raw["power"]))
cat(sprintf("  Cement alignment gap: %.1f%% (SDA intensity)\n", alignment_raw["cement"]))
cat(sprintf("  Steel alignment gap:  %.1f%% (SDA intensity)\n", alignment_raw["steel"]))

# --- Section 3: Load TRISK data ----------------------------------------------

cat("\n[2/6] Loading TRISK data...\n")

trisk_data <- list()
for (sector in sectors) {
  trisk_file <- file.path(trisk_dir, sector, "top_borrowers_alignment_trisk.csv")
  if (file.exists(trisk_file)) {
    df <- readr::read_csv(trisk_file, show_col_types = FALSE)
    trisk_data[[sector]] <- df
    cat(sprintf("  %s: %d borrowers loaded\n", sector, nrow(df)))
  } else {
    cat(sprintf("  %s: No TRISK data found — stress dimension will be 0\n", sector))
    trisk_data[[sector]] <- NULL
  }
}

# --- Section 4: Load exposure data -------------------------------------------

cat("\n[3/6] Loading exposure data...\n")

loanbook <- readr::read_csv(loanbook_file, show_col_types = FALSE)

# Map ISIC codes to Decision 263 sectors
isic_to_d263 <- c(
  "D3511" = "power",
  "C2394" = "cement",
  "C2410" = "steel"
)

loanbook <- loanbook |>
  dplyr::mutate(
    d263_sector = dplyr::recode(sector_classification_direct_loantaker, !!!isic_to_d263)
  ) |>
  dplyr::filter(!is.na(d263_sector))

exposure_by_sector <- loanbook |>
  dplyr::group_by(d263_sector) |>
  dplyr::summarise(
    exposure_vnd = sum(loan_size_outstanding, na.rm = TRUE),
    .groups = "drop"
  ) |>
  dplyr::filter(d263_sector %in% sectors)

total_d263_exposure <- sum(exposure_by_sector$exposure_vnd)

exposure_by_sector <- exposure_by_sector |>
  dplyr::mutate(exposure_share = exposure_vnd / total_d263_exposure)

cat(sprintf("  Total Decision 263 exposure: %s VND\n", formatC(total_d263_exposure, format = "f", big.mark = ",")))
for (row in seq_len(nrow(exposure_by_sector))) {
  cat(sprintf("  %s: %s VND (%.1f%%)\n",
              exposure_by_sector$d263_sector[row],
              formatC(exposure_by_sector$exposure_vnd[row], format = "f", big.mark = ","),
              exposure_by_sector$exposure_share[row] * 100))
}

# --- Section 5: Compute dimension scores -------------------------------------

cat("\n[4/6] Computing dimension scores...\n")

# 5a. Alignment gap severity — min-max normalization
align_min <- min(alignment_raw)
align_max <- max(alignment_raw)
align_range <- align_max - align_min

if (align_range > 0) {
  alignment_score <- (alignment_raw - align_min) / align_range
} else {
  alignment_score <- rep(0.5, length(alignment_raw))
  names(alignment_score) <- names(alignment_raw)
}

cat("  Alignment scores (normalized):\n")
for (s in sectors) {
  cat(sprintf("    %s: %.4f (raw: %s)\n", s, alignment_score[s],
              if (s == "power") sprintf("%.2f pp", alignment_raw[s]) else sprintf("%.1f%%", alignment_raw[s])))
}

# 5b. Transition stress severity — exposure-weighted mean, then min-max
stress_raw <- numeric(length(sectors))
names(stress_raw) <- sectors

for (i in seq_along(sectors)) {
  sector <- sectors[i]
  if (!is.null(trisk_data[[sector]]) && nrow(trisk_data[[sector]]) > 0) {
    trisk_df <- trisk_data[[sector]]
    # Join with exposure data on company name
    sector_exposure <- exposure_by_sector |>
      dplyr::filter(d263_sector == sector) |>
      dplyr::pull(exposure_vnd)

    n_borrowers <- nrow(trisk_df)
    per_borrower_exposure <- sector_exposure / n_borrowers

    stress_raw[sector] <- sum(trisk_df$stress_priority_score * per_borrower_exposure) /
      sum(per_borrower_exposure)
  } else {
    stress_raw[sector] <- 0
  }
}

stress_min <- min(stress_raw)
stress_max <- max(stress_raw)
stress_range <- stress_max - stress_min

if (stress_range > 0) {
  stress_score <- (stress_raw - stress_min) / stress_range
} else {
  stress_score <- rep(0.5, length(stress_raw))
  names(stress_score) <- names(stress_raw)
}

cat("  Stress scores (normalized):\n")
for (s in sectors) {
  cat(sprintf("    %s: %.4f (raw: %.2f)\n", s, stress_score[s], stress_raw[s]))
}

# 5c. Portfolio exposure concentration — min-max normalization
exposure_share_vec <- setNames(
  exposure_by_sector$exposure_share,
  exposure_by_sector$d263_sector
)
# Ensure all sectors present
for (s in sectors) {
  if (!(s %in% names(exposure_share_vec))) {
    exposure_share_vec[s] <- 0
  }
}
exposure_share_vec <- exposure_share_vec[sectors]

exp_min <- min(exposure_share_vec)
exp_max <- max(exposure_share_vec)
exp_range <- exp_max - exp_min

if (exp_range > 0) {
  exposure_score <- (exposure_share_vec - exp_min) / exp_range
} else {
  exposure_score <- rep(0.5, length(exposure_share_vec))
  names(exposure_score) <- names(exposure_share_vec)
}

cat("  Exposure scores (normalized):\n")
for (s in sectors) {
  cat(sprintf("    %s: %.4f (share: %.1f%%)\n", s, exposure_score[s], exposure_share_vec[s] * 100))
}

# --- Section 6: Composite score and classification ---------------------------

cat("\n[5/6] Computing composite scores...\n")

composite <- w_alignment * alignment_score + w_stress * stress_score + w_exposure * exposure_score

classify_band <- function(score) {
  if (score >= 0.70) return("Critical")
  if (score >= 0.50) return("High")
  if (score >= 0.30) return("Medium")
  return("Low")
}

priority_band <- sapply(composite, classify_band)

cat("  Composite scores and priority bands:\n")
for (s in sectors) {
  cat(sprintf("    %s: %.4f [%s]\n", s, composite[s], priority_band[s]))
}

# --- Section 7: Write outputs ------------------------------------------------

cat("\n[6/6] Writing outputs...\n")

# 7a. Ranking CSV
ranking <- tibble::tibble(
  sector = sectors,
  composite_score = as.numeric(composite),
  priority_band = priority_band,
  alignment_score = as.numeric(alignment_score[sectors]),
  stress_score = as.numeric(stress_score[sectors]),
  exposure_score = as.numeric(exposure_score[sectors]),
  alignment_gap_raw = as.numeric(alignment_raw[sectors]),
  stress_score_raw = as.numeric(stress_raw[sectors]),
  exposure_vnd = as.numeric(exposure_share_vec[sectors]) * total_d263_exposure,
  exposure_share = as.numeric(exposure_share_vec[sectors]),
  data_source = data_source
)

ranking_file <- file.path(output_dir, "sector_priority_ranking.csv")
readr::write_csv(ranking, ranking_file)
cat(sprintf("  Written: %s\n", ranking_file))

# 7b. Detail CSV
detail_rows <- list()
for (s in sectors) {
  detail_rows[[length(detail_rows) + 1]] <- tibble::tibble(
    sector = s,
    dimension = "alignment",
    raw_value = alignment_raw[s],
    normalized_score = alignment_score[s],
    weight = w_alignment,
    weighted_contribution = alignment_score[s] * w_alignment,
    source_file = if (s == "power") basename(alignment_file_ms) else basename(alignment_file_sda),
    data_source = data_source
  )
  detail_rows[[length(detail_rows) + 1]] <- tibble::tibble(
    sector = s,
    dimension = "stress",
    raw_value = stress_raw[s],
    normalized_score = stress_score[s],
    weight = w_stress,
    weighted_contribution = stress_score[s] * w_stress,
    source_file = sprintf("%s/top_borrowers_alignment_trisk.csv", s),
    data_source = data_source
  )
  detail_rows[[length(detail_rows) + 1]] <- tibble::tibble(
    sector = s,
    dimension = "exposure",
    raw_value = exposure_share_vec[s],
    normalized_score = exposure_score[s],
    weight = w_exposure,
    weighted_contribution = exposure_score[s] * w_exposure,
    source_file = "vietnam_loanbook.csv",
    data_source = data_source
  )
}

detail <- dplyr::bind_rows(detail_rows)
detail_file <- file.path(output_dir, "sector_priority_detail.csv")
readr::write_csv(detail, detail_file)
cat(sprintf("  Written: %s\n", detail_file))

# 7c. Chart
chart_file <- file.path(output_dir, "sector_priority_chart.png")

ggplot2::ggplot() +
  ggplot2::geom_col(
    data = tibble::tibble(
      sector = factor(sectors, levels = rev(sectors)),
      alignment = alignment_score[sectors] * w_alignment,
      stress = stress_score[sectors] * w_stress,
      exposure = exposure_score[sectors] * w_exposure
    ) |> tidyr::pivot_longer(cols = c(alignment, stress, exposure),
                              names_to = "dimension", values_to = "contribution"),
    ggplot2::aes(x = sector, y = contribution, fill = dimension),
    position = "stack", width = 0.6
  ) +
  ggplot2::geom_text(
    data = tibble::tibble(
      sector = factor(sectors, levels = rev(sectors)),
      composite = as.numeric(composite[sectors]),
      band = priority_band[sectors]
    ),
    ggplot2::aes(x = sector, y = composite + 0.03, label = band),
    fontface = "bold", size = 4, color = "#1f1912"
  ) +
  ggplot2::scale_fill_manual(
    values = c(alignment = "#c0392b", stress = "#e67e22", exposure = "#2980b9"),
    labels = c(alignment = "Alignment gap", stress = "Transition stress", exposure = "Exposure")
  ) +
  ggplot2::scale_y_continuous(limits = c(0, 1.15), breaks = seq(0, 1, 0.2)) +
  ggplot2::labs(
    title = "Sector Transition Risk Priority — MCB Synthetic Portfolio",
    subtitle = sprintf("Weights: alignment=%.2f, stress=%.2f, exposure=%.2f", w_alignment, w_stress, w_exposure),
    x = NULL, y = "Composite Score", fill = "Dimension"
  ) +
  ggplot2::theme_minimal(base_size = 14) +
  ggplot2::theme(
    panel.grid.minor = ggplot2::element_blank(),
    legend.position = "bottom",
    plot.title = ggplot2::element_text(face = "bold", size = 15),
    axis.text = ggplot2::element_text(size = 12)
  )

ggplot2::ggsave(chart_file, width = 8, height = 5, dpi = 150, bg = "white")
cat(sprintf("  Written: %s\n", chart_file))

# --- Summary -----------------------------------------------------------------

cat("\n=== Sector Prioritization Complete ===\n")
cat(sprintf("Ranking (highest to lowest composite score):\n"))
for (s in order(composite, decreasing = TRUE)) {
  cat(sprintf("  %d. %s: %.4f [%s]\n",
              which(order(composite, decreasing = TRUE) == s),
              sectors[s], composite[s], priority_band[s]))
}
cat(sprintf("\nOutputs in: %s\n", output_dir))

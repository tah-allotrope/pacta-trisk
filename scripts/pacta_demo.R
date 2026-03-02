# ==============================================================================
# PACTA for Banks - Complete Demo Script
# Runs the full pipeline: matching -> analysis -> visualization
# ==============================================================================

library(pacta.loanbook)
library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)

# NOTE: This script expects to be run from the project root directory:
#   Rscript scripts/pacta_demo.R
# Or set working directory to project root first.
output_dir <- file.path(getwd(), "output")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

cat("========================================\n")
cat("PACTA DEMO: Full Pipeline\n")
cat("========================================\n\n")

# ==============================================================================
# PHASE 1: EXPLORE THE INPUT DATA
# ==============================================================================

cat("--- PHASE 1: Input Data Overview ---\n\n")

cat("Loanbook demo:\n")
cat(sprintf("  Rows: %d | Columns: %d\n", nrow(loanbook_demo), ncol(loanbook_demo)))
cat(sprintf("  Columns: %s\n\n", paste(names(loanbook_demo), collapse=", ")))

cat("ABCD demo:\n")
cat(sprintf("  Rows: %d | Columns: %d\n", nrow(abcd_demo), ncol(abcd_demo)))
cat(sprintf("  Sectors: %s\n", paste(unique(abcd_demo$sector), collapse=", ")))
cat(sprintf("  Years: %d to %d\n", min(abcd_demo$year), max(abcd_demo$year)))
cat(sprintf("  Unique companies: %d\n\n", n_distinct(abcd_demo$name_company)))

cat("Scenario demo 2020:\n")
cat(sprintf("  Rows: %d\n", nrow(scenario_demo_2020)))
cat(sprintf("  Scenarios: %s\n", paste(unique(scenario_demo_2020$scenario), collapse=", ")))
cat(sprintf("  Sectors: %s\n\n", paste(unique(scenario_demo_2020$sector), collapse=", ")))

cat("CO2 intensity scenario demo:\n")
cat(sprintf("  Rows: %d\n", nrow(co2_intensity_scenario_demo)))
cat(sprintf("  Sectors: %s\n\n", paste(unique(co2_intensity_scenario_demo$sector), collapse=", ")))

# Save loanbook head to CSV for inspection
write_csv(head(loanbook_demo, 20), file.path(output_dir, "01_loanbook_sample.csv"))
write_csv(head(abcd_demo, 20), file.path(output_dir, "01_abcd_sample.csv"))

# ==============================================================================
# PHASE 2: MATCHING
# ==============================================================================

cat("--- PHASE 2: Matching ---\n\n")

cat("Running match_name()...\n")
matched <- match_name(loanbook_demo, abcd_demo)
cat(sprintf("  Potential matches found: %d rows\n", nrow(matched)))
cat(sprintf("  Score range: %.2f to %.2f\n", min(matched$score), max(matched$score)))
cat(sprintf("  Match levels: %s\n\n", paste(unique(matched$level), collapse=", ")))

# Save full match results
write_csv(matched, file.path(output_dir, "02_matched_raw.csv"))

# Score distribution
score_dist <- matched %>%
  mutate(score_bin = cut(score, breaks=seq(0.7, 1.0, 0.05), include.lowest=TRUE)) %>%
  count(score_bin)
cat("Score distribution:\n")
print(as.data.frame(score_dist))
cat("\n")

# Prioritize
cat("Running prioritize()...\n")
prioritized <- prioritize(matched)
cat(sprintf("  Prioritized matches: %d rows (one per loan)\n", nrow(prioritized)))
cat(sprintf("  Match levels used: \n"))
print(as.data.frame(prioritized %>% count(level)))
cat("\n")

# Save prioritized matches
write_csv(prioritized, file.path(output_dir, "02_matched_prioritized.csv"))

# Sectors matched
cat("Sectors matched:\n")
print(as.data.frame(prioritized %>% count(sector_abcd)))
cat("\n")

# ==============================================================================
# PHASE 2.5: MATCH COVERAGE ANALYSIS
# ==============================================================================

cat("--- PHASE 2.5: Match Coverage ---\n\n")

merge_by <- c(
  sector_classification_system = "code_system",
  sector_classification_direct_loantaker = "code"
)

loanbook_with_sectors <- loanbook_demo %>%
  left_join(sector_classifications, by = merge_by)

coverage <- left_join(loanbook_with_sectors, prioritized,
  by = intersect(names(loanbook_with_sectors), names(prioritized))) %>%
  mutate(
    matched = case_when(
      !is.na(score) & score == 1 ~ "Matched",
      TRUE ~ "Not Matched"
    ),
    sector = case_when(
      borderline == TRUE & matched == "Not Matched" ~ "not in scope",
      TRUE ~ sector
    )
  )

# Coverage by sector (dollar value)
coverage_by_sector <- coverage %>%
  filter(sector != "not in scope", !is.na(sector)) %>%
  group_by(sector, matched) %>%
  summarize(
    total_outstanding = sum(as.numeric(loan_size_outstanding), na.rm=TRUE),
    n_loans = n(),
    .groups = "drop"
  )

cat("Coverage by sector (loan_size_outstanding):\n")
print(as.data.frame(coverage_by_sector))
cat("\n")

# Coverage bar chart
p_coverage <- ggplot(coverage_by_sector, aes(x = sector, y = total_outstanding / 1e6, fill = matched)) +
  geom_col(position = "dodge") +
  labs(
    title = "PACTA Match Coverage by Sector",
    subtitle = "Loan size outstanding (millions EUR)",
    x = "Sector", y = "Loan Size Outstanding (M EUR)",
    fill = "Status"
  ) +
  scale_fill_manual(values = c("Matched" = "#2E86AB", "Not Matched" = "#E8505B")) +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))

ggsave(file.path(output_dir, "03_match_coverage_by_sector.png"), p_coverage, width = 10, height = 6, dpi = 150)
cat("  Saved: 03_match_coverage_by_sector.png\n\n")

# ==============================================================================
# PHASE 3: MARKET SHARE TARGETS
# ==============================================================================

cat("--- PHASE 3: Market Share Targets ---\n\n")

market_share_targets <- target_market_share(
  data = prioritized,
  abcd = abcd_demo,
  scenario = scenario_demo_2020,
  region_isos = region_isos_demo
)

cat(sprintf("  Result rows: %d\n", nrow(market_share_targets)))
cat(sprintf("  Sectors: %s\n", paste(unique(market_share_targets$sector), collapse = ", ")))
cat(sprintf("  Metrics: %s\n", paste(unique(market_share_targets$metric), collapse = ", ")))
cat(sprintf("  Years: %d to %d\n\n", min(market_share_targets$year), max(market_share_targets$year)))

write_csv(market_share_targets, file.path(output_dir, "04_market_share_targets_portfolio.csv"))

# Also company-level
market_share_company <- target_market_share(
  data = prioritized,
  abcd = abcd_demo,
  scenario = scenario_demo_2020,
  region_isos = region_isos_demo,
  by_company = TRUE,
  weight_production = FALSE
)
write_csv(market_share_company, file.path(output_dir, "04_market_share_targets_company.csv"))
cat(sprintf("  Company-level result rows: %d\n\n", nrow(market_share_company)))

# --- POWER SECTOR: Detailed View ---
cat("=== Power Sector Analysis ===\n")

power_data <- market_share_targets %>%
  filter(sector == "power", region == "global")

# Technology shares for year 2020 and 2025
power_techmix <- power_data %>%
  filter(metric %in% c("projected", "target_sds", "corporate_economy"),
         year %in% c(2020, 2025)) %>%
  select(technology, year, metric, technology_share)

cat("Power sector technology shares (global):\n")
power_wide <- power_techmix %>%
  pivot_wider(names_from = c(metric, year), values_from = technology_share)
print(as.data.frame(power_wide))
cat("\n")

# PLOT: Power sector tech mix (projected vs SDS at 2020 and 2025)
power_techmix_plot <- power_data %>%
  filter(metric %in% c("projected", "target_sds"),
         year %in% c(2020, 2025)) %>%
  mutate(
    label = paste0(metric, " (", year, ")"),
    label = factor(label, levels = c("projected (2020)", "projected (2025)",
                                      "target_sds (2020)", "target_sds (2025)"))
  )

p_techmix <- ggplot(power_techmix_plot, aes(x = label, y = technology_share, fill = technology)) +
  geom_col(position = "stack") +
  labs(
    title = "Power Sector: Technology Mix",
    subtitle = "Projected vs SDS Target (Global)",
    x = "", y = "Technology Share",
    fill = "Technology"
  ) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_brewer(palette = "Set3") +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

ggsave(file.path(output_dir, "05_power_techmix.png"), p_techmix, width = 10, height = 6, dpi = 150)
cat("  Saved: 05_power_techmix.png\n")

# PLOT: Power sector renewables trajectory
renewables_trajectory <- power_data %>%
  filter(technology == "renewablescap",
         metric %in% c("projected", "target_sds", "target_cps", "corporate_economy"))

p_renew <- ggplot(renewables_trajectory, aes(x = year, y = production, color = metric, linetype = metric)) +
  geom_line(linewidth = 1.2) +
  labs(
    title = "Power Sector: Renewables Production Trajectory",
    subtitle = "Portfolio projected vs scenario targets (Global)",
    x = "Year", y = "Production (MW)",
    color = "Metric", linetype = "Metric"
  ) +
  scale_color_manual(values = c(
    "projected" = "black",
    "corporate_economy" = "grey50",
    "target_sds" = "#27AE60",
    "target_cps" = "#E67E22"
  )) +
  scale_linetype_manual(values = c(
    "projected" = "solid",
    "corporate_economy" = "dashed",
    "target_sds" = "solid",
    "target_cps" = "dotted"
  )) +
  theme_minimal(base_size = 13)

ggsave(file.path(output_dir, "06_power_renewables_trajectory.png"), p_renew, width = 10, height = 6, dpi = 150)
cat("  Saved: 06_power_renewables_trajectory.png\n")

# PLOT: Power sector coal trajectory
coal_trajectory <- power_data %>%
  filter(technology == "coalcap",
         metric %in% c("projected", "target_sds", "target_cps", "corporate_economy"))

p_coal <- ggplot(coal_trajectory, aes(x = year, y = production, color = metric, linetype = metric)) +
  geom_line(linewidth = 1.2) +
  labs(
    title = "Power Sector: Coal Capacity Trajectory",
    subtitle = "Portfolio projected vs scenario targets (Global)",
    x = "Year", y = "Production (MW)",
    color = "Metric", linetype = "Metric"
  ) +
  scale_color_manual(values = c(
    "projected" = "black",
    "corporate_economy" = "grey50",
    "target_sds" = "#27AE60",
    "target_cps" = "#E67E22"
  )) +
  scale_linetype_manual(values = c(
    "projected" = "solid",
    "corporate_economy" = "dashed",
    "target_sds" = "solid",
    "target_cps" = "dotted"
  )) +
  theme_minimal(base_size = 13)

ggsave(file.path(output_dir, "07_power_coal_trajectory.png"), p_coal, width = 10, height = 6, dpi = 150)
cat("  Saved: 07_power_coal_trajectory.png\n")

# --- AUTOMOTIVE SECTOR ---
cat("\n=== Automotive Sector Analysis ===\n")

auto_data <- market_share_targets %>%
  filter(sector == "automotive", region == "global")

auto_techmix_plot <- auto_data %>%
  filter(metric %in% c("projected", "target_sds"),
         year %in% c(2020, 2025)) %>%
  mutate(
    label = paste0(metric, " (", year, ")"),
    label = factor(label, levels = c("projected (2020)", "projected (2025)",
                                      "target_sds (2020)", "target_sds (2025)"))
  )

p_auto_techmix <- ggplot(auto_techmix_plot, aes(x = label, y = technology_share, fill = technology)) +
  geom_col(position = "stack") +
  labs(
    title = "Automotive Sector: Technology Mix",
    subtitle = "Projected vs SDS Target (Global)",
    x = "", y = "Technology Share",
    fill = "Technology"
  ) +
  scale_y_continuous(labels = scales::percent) +
  scale_fill_brewer(palette = "Set2") +
  theme_minimal(base_size = 13) +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))

ggsave(file.path(output_dir, "08_automotive_techmix.png"), p_auto_techmix, width = 10, height = 6, dpi = 150)
cat("  Saved: 08_automotive_techmix.png\n")

# EV trajectory
ev_trajectory <- auto_data %>%
  filter(technology == "electric",
         metric %in% c("projected", "target_sds", "target_cps", "corporate_economy"))

p_ev <- ggplot(ev_trajectory, aes(x = year, y = production, color = metric, linetype = metric)) +
  geom_line(linewidth = 1.2) +
  labs(
    title = "Automotive Sector: Electric Vehicle Production Trajectory",
    subtitle = "Portfolio projected vs scenario targets (Global)",
    x = "Year", y = "Production (vehicles)",
    color = "Metric", linetype = "Metric"
  ) +
  scale_color_manual(values = c(
    "projected" = "black",
    "corporate_economy" = "grey50",
    "target_sds" = "#27AE60",
    "target_cps" = "#E67E22"
  )) +
  scale_linetype_manual(values = c(
    "projected" = "solid",
    "corporate_economy" = "dashed",
    "target_sds" = "solid",
    "target_cps" = "dotted"
  )) +
  theme_minimal(base_size = 13)

ggsave(file.path(output_dir, "09_automotive_ev_trajectory.png"), p_ev, width = 10, height = 6, dpi = 150)
cat("  Saved: 09_automotive_ev_trajectory.png\n")

# ==============================================================================
# PHASE 4: SDA TARGETS
# ==============================================================================

cat("\n--- PHASE 4: Sectoral Decarbonization Approach (SDA) ---\n\n")

sda_targets <- target_sda(
  data = prioritized,
  abcd = abcd_demo,
  co2_intensity_scenario = co2_intensity_scenario_demo,
  region_isos = region_isos_demo
)

cat(sprintf("  Result rows: %d\n", nrow(sda_targets)))
cat(sprintf("  Sectors: %s\n", paste(unique(sda_targets$sector), collapse = ", ")))
cat(sprintf("  Metrics: %s\n", paste(unique(sda_targets$emission_factor_metric), collapse = ", ")))
cat(sprintf("  Regions: %s\n\n", paste(unique(sda_targets$region), collapse = ", ")))

write_csv(sda_targets, file.path(output_dir, "10_sda_targets_portfolio.csv"))

# --- CEMENT SECTOR ---
cat("=== Cement Sector Analysis ===\n")

cement_global <- sda_targets %>%
  filter(sector == "cement", region == "global") %>%
  filter(emission_factor_metric %in% c("projected", "target_demo", "corporate_economy", "adjusted_scenario_demo"))

cat("Cement emission intensity (global, selected years):\n")
cement_table <- cement_global %>%
  filter(year %in% c(2020, 2022, 2025)) %>%
  select(year, emission_factor_metric, emission_factor_value) %>%
  pivot_wider(names_from = emission_factor_metric, values_from = emission_factor_value)
print(as.data.frame(cement_table))
cat("\n")

p_cement <- ggplot(cement_global, aes(x = year, y = emission_factor_value, color = emission_factor_metric, linetype = emission_factor_metric)) +
  geom_line(linewidth = 1.2) +
  labs(
    title = "Cement Sector: Emission Intensity Trajectory",
    subtitle = "Portfolio projected vs scenario targets (Global)",
    x = "Year", y = "Emission Factor (tCO2/tonne)",
    color = "Metric", linetype = "Metric"
  ) +
  scale_color_manual(values = c(
    "projected" = "black",
    "corporate_economy" = "grey50",
    "target_demo" = "#27AE60",
    "adjusted_scenario_demo" = "#8E44AD"
  )) +
  scale_linetype_manual(values = c(
    "projected" = "solid",
    "corporate_economy" = "dashed",
    "target_demo" = "solid",
    "adjusted_scenario_demo" = "longdash"
  )) +
  theme_minimal(base_size = 13)

ggsave(file.path(output_dir, "11_cement_emission_intensity.png"), p_cement, width = 10, height = 6, dpi = 150)
cat("  Saved: 11_cement_emission_intensity.png\n")

# --- STEEL SECTOR (if available) ---
steel_global <- sda_targets %>%
  filter(sector == "steel", region == "global")

if (nrow(steel_global) > 0) {
  cat("\n=== Steel Sector Analysis ===\n")

  steel_plot_data <- steel_global %>%
    filter(emission_factor_metric %in% c("projected", "target_demo", "corporate_economy", "adjusted_scenario_demo"))

  p_steel <- ggplot(steel_plot_data, aes(x = year, y = emission_factor_value, color = emission_factor_metric, linetype = emission_factor_metric)) +
    geom_line(linewidth = 1.2) +
    labs(
      title = "Steel Sector: Emission Intensity Trajectory",
      subtitle = "Portfolio projected vs scenario targets (Global)",
      x = "Year", y = "Emission Factor (tCO2/tonne)",
      color = "Metric", linetype = "Metric"
    ) +
    scale_color_manual(values = c(
      "projected" = "black",
      "corporate_economy" = "grey50",
      "target_demo" = "#27AE60",
      "adjusted_scenario_demo" = "#8E44AD"
    )) +
    scale_linetype_manual(values = c(
      "projected" = "solid",
      "corporate_economy" = "dashed",
      "target_demo" = "solid",
      "adjusted_scenario_demo" = "longdash"
    )) +
    theme_minimal(base_size = 13)

  ggsave(file.path(output_dir, "12_steel_emission_intensity.png"), p_steel, width = 10, height = 6, dpi = 150)
  cat("  Saved: 12_steel_emission_intensity.png\n")
}

# ==============================================================================
# PHASE 5: SUMMARY ALIGNMENT DASHBOARD
# ==============================================================================

cat("\n--- PHASE 5: Alignment Summary ---\n\n")

# Market Share sectors: compare projected vs target_sds at year 2025
alignment_ms <- market_share_targets %>%
  filter(region == "global", year == 2025,
         metric %in% c("projected", "target_sds")) %>%
  select(sector, technology, metric, production, technology_share) %>%
  pivot_wider(names_from = metric, values_from = c(production, technology_share))

cat("Market Share Alignment Summary (2025, global):\n")
alignment_summary <- alignment_ms %>%
  mutate(
    production_gap = production_projected - production_target_sds,
    aligned = ifelse(production_gap >= 0, "YES", "NO")
  ) %>%
  select(sector, technology, production_projected, production_target_sds, production_gap, aligned)
print(as.data.frame(alignment_summary))
cat("\n")

write_csv(alignment_summary, file.path(output_dir, "13_alignment_summary_market_share.csv"))

# SDA alignment: projected vs target_demo at 2025
alignment_sda <- sda_targets %>%
  filter(region == "global", year == 2025,
         emission_factor_metric %in% c("projected", "target_demo")) %>%
  select(sector, emission_factor_metric, emission_factor_value) %>%
  pivot_wider(names_from = emission_factor_metric, values_from = emission_factor_value) %>%
  mutate(
    intensity_gap = projected - target_demo,
    aligned = ifelse(projected <= target_demo, "YES", "NO")
  )

cat("SDA Alignment Summary (2025, global):\n")
print(as.data.frame(alignment_sda))
cat("\n")

write_csv(alignment_sda, file.path(output_dir, "13_alignment_summary_sda.csv"))

# ==============================================================================
# PHASE 6: MULTI-SECTOR ALIGNMENT OVERVIEW PLOT
# ==============================================================================

# For low-carbon technologies: aligned if projected >= target
# For high-carbon technologies: aligned if projected <= target
low_carbon_tech <- c("electric", "fuelcell", "hybrid", "renewablescap", "hydrocap", "nuclearcap")

alignment_plot_data <- market_share_targets %>%
  filter(region == "global", metric %in% c("projected", "target_sds")) %>%
  select(sector, technology, year, metric, technology_share) %>%
  pivot_wider(names_from = metric, values_from = technology_share) %>%
  filter(year == 2025) %>%
  mutate(
    gap = projected - target_sds,
    is_low_carbon = technology %in% low_carbon_tech,
    alignment_direction = case_when(
      is_low_carbon & gap >= 0 ~ "Aligned",
      !is_low_carbon & gap <= 0 ~ "Aligned",
      TRUE ~ "Misaligned"
    )
  )

p_alignment <- ggplot(alignment_plot_data, aes(x = reorder(technology, gap), y = gap, fill = alignment_direction)) +
  geom_col() +
  coord_flip() +
  facet_wrap(~sector, scales = "free_y") +
  labs(
    title = "Portfolio Alignment Gap at 2025 (vs SDS)",
    subtitle = "Technology share gap: Projected minus SDS Target (Global)",
    x = "Technology", y = "Share Gap (positive = above target)",
    fill = "Alignment"
  ) +
  scale_fill_manual(values = c("Aligned" = "#27AE60", "Misaligned" = "#E74C3C")) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  theme_minimal(base_size = 12)

ggsave(file.path(output_dir, "14_alignment_overview.png"), p_alignment, width = 12, height = 7, dpi = 150)
cat("  Saved: 14_alignment_overview.png\n")

# ==============================================================================
# DONE
# ==============================================================================

cat("\n========================================\n")
cat("DEMO COMPLETE\n")
cat("========================================\n")
cat(sprintf("All outputs saved to: %s\n", output_dir))
cat("\nFiles generated:\n")
cat(paste(" -", list.files(output_dir), collapse = "\n"))
cat("\n")

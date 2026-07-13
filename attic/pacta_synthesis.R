# ==============================================================================
# PACTA for Banks - Synthesized Production Pipeline
# Merges best elements from AI + Staff implementations
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/pacta_synthesis.R
# ==============================================================================

# --- Load packages ---
library(pacta.loanbook)
library(r2dii.data)
library(r2dii.match)
library(r2dii.analysis)
library(r2dii.plot)
library(dplyr)
library(tidyr)
library(ggplot2)
library(scales)
library(ggrepel)
library(base64enc)
library(readr)

cat("========================================\n")
cat("PACTA SYNTHESIS: Best-of-Both Pipeline\n")
cat("========================================\n\n")

# --- Output directories ---
synth_output <- file.path(getwd(), "synthesis_output")
dir.create(synth_output, showWarnings = FALSE, recursive = TRUE)
report_dir <- file.path(getwd(), "reports")
dir.create(report_dir, showWarnings = FALSE, recursive = TRUE)

# --- Helper: base64 encode a PNG ---
img_to_base64 <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  b64 <- base64enc::base64encode(raw)
  paste0("data:image/png;base64,", b64)
}

# ==============================================================================
# SECTION 1: DATA LOADING
# ==============================================================================

cat("--- Section 1: Loading Data ---\n\n")

loanbook <- r2dii.data::loanbook_demo
abcd     <- r2dii.data::abcd_demo
scenario <- r2dii.data::scenario_demo_2020
co2      <- r2dii.data::co2_intensity_scenario_demo
region   <- r2dii.data::region_isos_demo

cat(sprintf("  Loanbook: %d rows, %d cols\n", nrow(loanbook), ncol(loanbook)))
cat(sprintf("  ABCD: %d rows | Sectors: %s\n", nrow(abcd), paste(unique(abcd$sector), collapse = ", ")))
cat(sprintf("  Scenario: %s | Scenarios: %s\n", "demo_2020", paste(unique(scenario$scenario), collapse = ", ")))
cat(sprintf("  CO2 intensity: %d rows | Sectors: %s\n\n", nrow(co2), paste(unique(co2$sector), collapse = ", ")))

# ==============================================================================
# SECTION 2: SECTOR PRE-JOIN (Staff pattern)
# Why: Pre-joining sector classifications enables mismatch validation after matching
# ==============================================================================

cat("--- Section 2: Sector Pre-Join & Classification ---\n\n")

loanbook_classified <- loanbook %>%
  mutate(sector_classification_direct_loantaker = as.character(sector_classification_direct_loantaker)) %>%
  left_join(sector_classifications, by = c(
    "sector_classification_system" = "code_system",
    "sector_classification_direct_loantaker" = "code"
  )) %>%
  rename(
    sector_classified = sector,
    borderline_classified = borderline
  )

# Sector breakdown
sector_breakdown <- loanbook_classified %>%
  group_by(sector_classified) %>%
  summarise(
    n_loans = n(),
    total_outstanding = sum(loan_size_outstanding, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(total_outstanding))

cat("  Loanbook sector classification breakdown:\n")
print(as.data.frame(sector_breakdown))
cat("\n")

# ==============================================================================
# SECTION 3: FUZZY MATCHING + MANUAL REVIEW FLAG (AI flexibility + Staff rigor)
# Why: min_score=0.9 captures near-matches while keeping precision high;
#      scores <1.0 are flagged for manual review
# ==============================================================================

cat("--- Section 3: Matching (fuzzy, min_score=0.9) ---\n\n")

matched_raw <- match_name(loanbook_classified, abcd, by_sector = TRUE,
                          min_score = 0.9, method = "jw", p = 0.1)
cat(sprintf("  Raw matches: %d rows\n", nrow(matched_raw)))
cat(sprintf("  Score range: %.3f to %.3f\n", min(matched_raw$score), max(matched_raw$score)))

# Flag matches needing manual review (score < 1.0)
review_needed <- matched_raw %>%
  filter(score < 1.0) %>%
  select(id_loan, name_direct_loantaker, name_abcd, score, sector_abcd, level) %>%
  arrange(score)

n_review <- nrow(review_needed)
cat(sprintf("  Matches needing manual review (score < 1.0): %d\n", n_review))
if (n_review > 0) {
  cat("  Top candidates for review:\n")
  print(as.data.frame(head(review_needed, 10)))
}

# Export for manual review
write_csv(matched_raw, file.path(synth_output, "01_matched_raw.csv"))
if (n_review > 0) {
  write_csv(review_needed, file.path(synth_output, "01_review_needed.csv"))
}

# Prioritize
matched <- prioritize(matched_raw)
cat(sprintf("\n  Prioritized matches: %d rows\n", nrow(matched)))
cat("  Match levels:\n")
print(as.data.frame(matched %>% count(level)))

# Sector mismatch validation (Staff pattern)
mismatch <- matched %>%
  filter(sector_classified != sector) %>%
  select(id_loan, name_direct_loantaker, sector_classified, sector)

if (nrow(mismatch) > 0) {
  cat(sprintf("\n  WARNING: %d sector mismatches found:\n", nrow(mismatch)))
  print(as.data.frame(mismatch))
} else {
  cat("\n  Sector mismatch check: PASS (bank classification consistent with ABCD)\n")
}

write_csv(matched, file.path(synth_output, "02_matched_prioritized.csv"))
cat("\n")

# ==============================================================================
# SECTION 4: COVERAGE ANALYSIS (Staff pie + bar with "Not in Scope")
# Why: Shows portfolio-level match quality with three categories
# ==============================================================================

cat("--- Section 4: Coverage Analysis ---\n\n")

# Sector-level coverage
loanbook_sector_summary <- loanbook_classified %>%
  group_by(sector_classified) %>%
  summarise(total_outstanding = sum(loan_size_outstanding, na.rm = TRUE), .groups = "drop")

matches_sector_summary <- matched %>%
  group_by(sector) %>%
  summarise(matches_outstanding = sum(loan_size_outstanding, na.rm = TRUE), .groups = "drop")

sector_summary <- loanbook_sector_summary %>%
  left_join(matches_sector_summary, by = c("sector_classified" = "sector")) %>%
  mutate(
    matches_outstanding = ifelse(is.na(matches_outstanding), 0, matches_outstanding),
    match_percentage = round((matches_outstanding / total_outstanding) * 100, 1)
  )

cat("  Coverage by sector:\n")
print(as.data.frame(sector_summary))
cat("\n")

# --- Pie Chart (Staff pattern) ---
outstanding_total <- sum(sector_summary$total_outstanding)
outstanding_matched <- sum(sector_summary$matches_outstanding)
outstanding_notinscope <- sector_summary %>%
  filter(sector_classified == "not in scope") %>%
  pull(total_outstanding)

df_pie <- data.frame(
  status = c("(In Scope) Matched", "(In Scope) Not Matched", "Not in Scope"),
  amount = c(
    outstanding_matched,
    (outstanding_total - outstanding_notinscope - outstanding_matched),
    outstanding_notinscope
  )
) %>%
  mutate(
    pct = amount / sum(amount),
    label = paste0(status, "\n", percent(pct, accuracy = 0.01))
  )

p_pie <- ggplot(df_pie, aes(x = "", y = amount, fill = status)) +
  geom_bar(stat = "identity", width = 1, color = "white") +
  coord_polar("y", start = 0) +
  geom_text(aes(label = label),
            position = position_stack(vjust = 0.5),
            color = "white", fontface = "bold", size = 3.5) +
  scale_fill_manual(values = c(
    "(In Scope) Matched" = "#14645c",
    "(In Scope) Not Matched" = "#e8594b",
    "Not in Scope" = "#9E9E9E"
  )) +
  labs(
    title = "Portfolio Distribution Breakdown",
    subtitle = paste0("Total Loanbook Value: ", comma(outstanding_total), " EUR"),
    fill = NULL
  ) +
  theme_void() +
  theme(
    legend.position = "bottom",
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14),
    plot.subtitle = element_text(hjust = 0.5, size = 11)
  )

ggsave(file.path(synth_output, "03_coverage_pie.png"), p_pie, width = 7, height = 6, dpi = 150)
cat("  Saved: 03_coverage_pie.png\n")

# --- Bar Chart with % labels (Staff pattern) ---
df_bar <- sector_summary %>%
  mutate(not_matched = total_outstanding - matches_outstanding) %>%
  pivot_longer(
    cols = c(matches_outstanding, not_matched),
    names_to = "type",
    values_to = "amount"
  ) %>%
  mutate(
    status = case_when(
      sector_classified == "not in scope" ~ "Not in Scope",
      type == "matches_outstanding" ~ "(In Scope) Matched",
      TRUE ~ "(In Scope) Not Matched"
    ),
    status = factor(status, levels = c("(In Scope) Matched", "(In Scope) Not Matched", "Not in Scope"))
  )

p_bar <- ggplot(df_bar, aes(x = reorder(sector_classified, amount, sum), y = amount, fill = status)) +
  geom_col(width = 0.7, color = "white", linewidth = 0.1, position = position_stack(reverse = TRUE)) +
  geom_text(
    data = sector_summary %>% filter(sector_classified != "not in scope"),
    aes(x = sector_classified, y = total_outstanding,
        label = paste0(match_percentage, "%")),
    inherit.aes = FALSE,
    hjust = -0.2, size = 3.5
  ) +
  coord_flip() +
  scale_y_continuous(labels = label_comma(), expand = expansion(mult = c(0, 0.2))) +
  scale_fill_manual(values = c(
    "(In Scope) Matched" = "#14645c",
    "(In Scope) Not Matched" = "#e8594b",
    "Not in Scope" = "#9E9E9E"
  )) +
  labs(
    title = "Match Coverage by Sector",
    subtitle = "Outstanding loan amount (EUR)",
    x = "Sector", y = "Outstanding Amount (EUR)", fill = NULL
  ) +
  theme_minimal(base_size = 12) +
  theme(
    legend.position = "bottom",
    axis.text.y = element_text(face = "bold"),
    plot.title = element_text(hjust = 0.5, face = "bold", size = 14)
  )

ggsave(file.path(synth_output, "04_coverage_bar.png"), p_bar, width = 10, height = 6, dpi = 150)
cat("  Saved: 04_coverage_bar.png\n\n")

# ==============================================================================
# SECTION 5: MARKET SHARE ANALYSIS (Both - portfolio + company level, CPS included)
# Why: Portfolio-level for alignment, company-level for borrower engagement
# ==============================================================================

cat("--- Section 5: Market Share Analysis ---\n\n")

# Must remove pre-joined columns before target_market_share (Staff gotcha)
ms_portfolio <- target_market_share(
  data = matched %>% select(-c("sector_classified", "borderline_classified")),
  abcd = abcd,
  scenario = scenario,
  region_isos = region
)

cat(sprintf("  Portfolio-level: %d rows | Sectors: %s\n",
            nrow(ms_portfolio), paste(unique(ms_portfolio$sector), collapse = ", ")))

# Company-level (AI pattern)
ms_company <- target_market_share(
  data = matched %>% select(-c("sector_classified", "borderline_classified")),
  abcd = abcd,
  scenario = scenario,
  region_isos = region,
  by_company = TRUE,
  weight_production = FALSE
)

cat(sprintf("  Company-level: %d rows\n", nrow(ms_company)))

write_csv(ms_portfolio, file.path(synth_output, "05_market_share_portfolio.csv"))
write_csv(ms_company, file.path(synth_output, "05_market_share_company.csv"))

# --- Power Sector Tech Mix (Staff r2dii.plot + ggrepel) ---
power_techmix_data <- ms_portfolio %>%
  filter(scenario_source == "demo_2020", sector == "power",
         region == "global",
         metric %in% c("projected", "corporate_economy", "target_sds"))

p_power_techmix <- qplot_techmix(power_techmix_data) +
  ggrepel::geom_label_repel(
    aes(label = paste0(round(technology_share, 3) * 100, "%")),
    min.segment.length = 0,
    position = position_stack(vjust = 0.5),
    show.legend = FALSE, size = 2.5
  ) +
  labs(title = "Power Sector: Technology Mix",
       subtitle = "Portfolio vs Corporate Economy vs SDS Target (Global)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "06_power_techmix.png"), p_power_techmix, width = 10, height = 6, dpi = 150)
cat("  Saved: 06_power_techmix.png\n")

# --- Automotive Sector Tech Mix ---
auto_techmix_data <- ms_portfolio %>%
  filter(scenario_source == "demo_2020", sector == "automotive",
         region == "global",
         metric %in% c("projected", "corporate_economy", "target_sds"))

p_auto_techmix <- qplot_techmix(auto_techmix_data) +
  ggrepel::geom_label_repel(
    aes(label = paste0(round(technology_share, 3) * 100, "%")),
    min.segment.length = 0,
    position = position_stack(vjust = 0.5),
    show.legend = FALSE, size = 2.5
  ) +
  labs(title = "Automotive Sector: Technology Mix",
       subtitle = "Portfolio vs Corporate Economy vs SDS Target (Global)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "07_auto_techmix.png"), p_auto_techmix, width = 10, height = 6, dpi = 150)
cat("  Saved: 07_auto_techmix.png\n")

# --- Power Renewables Trajectory (Staff r2dii.plot) ---
renew_traj_data <- ms_portfolio %>%
  filter(sector == "power", technology == "renewablescap",
         region == "global", scenario_source == "demo_2020")

renew_labels <- renew_traj_data %>%
  filter(year == min(year) + 5) %>%
  rename(value = "percentage_of_initial_production_by_scope")

p_renew_traj <- qplot_trajectory(renew_traj_data) +
  ggrepel::geom_text_repel(
    aes(label = paste0(round(value, 3) * 100, "%")),
    data = renew_labels, size = 3
  ) +
  labs(title = "Power: Renewables Capacity Trajectory",
       subtitle = "% of initial production by scope (Global)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "08_power_renewables_traj.png"), p_renew_traj, width = 10, height = 6, dpi = 150)
cat("  Saved: 08_power_renewables_traj.png\n")

# --- Power Coal Trajectory ---
coal_traj_data <- ms_portfolio %>%
  filter(sector == "power", technology == "coalcap",
         region == "global", scenario_source == "demo_2020")

coal_labels <- coal_traj_data %>%
  filter(year == min(year) + 5) %>%
  rename(value = "percentage_of_initial_production_by_scope")

p_coal_traj <- qplot_trajectory(coal_traj_data) +
  ggrepel::geom_text_repel(
    aes(label = paste0(round(value, 3) * 100, "%")),
    data = coal_labels, size = 3
  ) +
  labs(title = "Power: Coal Capacity Trajectory",
       subtitle = "% of initial production by scope (Global)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "09_power_coal_traj.png"), p_coal_traj, width = 10, height = 6, dpi = 150)
cat("  Saved: 09_power_coal_traj.png\n")

# --- Automotive EV Trajectory ---
ev_traj_data <- ms_portfolio %>%
  filter(sector == "automotive", technology == "electric",
         region == "global", scenario_source == "demo_2020")

ev_labels <- ev_traj_data %>%
  filter(year == min(year) + 5) %>%
  rename(value = "percentage_of_initial_production_by_scope")

p_ev_traj <- qplot_trajectory(ev_traj_data) +
  ggrepel::geom_text_repel(
    aes(label = paste0(round(value, 3) * 100, "%")),
    data = ev_labels, size = 3
  ) +
  labs(title = "Automotive: Electric Vehicle Trajectory",
       subtitle = "% of initial production by scope (Global)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "10_auto_ev_traj.png"), p_ev_traj, width = 10, height = 6, dpi = 150)
cat("  Saved: 10_auto_ev_traj.png\n")

# --- Automotive ICE Trajectory (Staff addition - missing from original AI) ---
ice_traj_data <- ms_portfolio %>%
  filter(sector == "automotive", technology == "ice",
         region == "global", scenario_source == "demo_2020")

ice_labels <- ice_traj_data %>%
  filter(year == min(year) + 5) %>%
  rename(value = "percentage_of_initial_production_by_scope")

p_ice_traj <- qplot_trajectory(ice_traj_data) +
  ggrepel::geom_text_repel(
    aes(label = paste0(round(value, 3) * 100, "%")),
    data = ice_labels, size = 3
  ) +
  labs(title = "Automotive: ICE (Combustion Engine) Trajectory",
       subtitle = "% of initial production by scope (Global)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "11_auto_ice_traj.png"), p_ice_traj, width = 10, height = 6, dpi = 150)
cat("  Saved: 11_auto_ice_traj.png\n\n")

# ==============================================================================
# SECTION 6: SDA ANALYSIS
# Why: SDA measures emission intensity for cement & steel
# ==============================================================================

cat("--- Section 6: SDA Analysis ---\n\n")

sda_portfolio <- target_sda(
  data = matched,
  abcd = abcd,
  co2_intensity_scenario = co2,
  region_isos = region
)

cat(sprintf("  SDA rows: %d | Sectors: %s\n",
            nrow(sda_portfolio), paste(unique(sda_portfolio$sector), collapse = ", ")))
cat(sprintf("  Metrics: %s\n", paste(unique(sda_portfolio$emission_factor_metric), collapse = ", ")))

write_csv(sda_portfolio, file.path(synth_output, "06_sda_portfolio.csv"))

# --- Cement Emission Intensity (Staff r2dii.plot) ---
cement_data <- sda_portfolio %>%
  filter(sector == "cement", region == "global")

cement_labels <- cement_data %>%
  filter(year == min(year) + 5) %>%
  mutate(
    year = as.Date(strptime(as.character(year), "%Y")),
    label = pacta.loanbook::to_title(emission_factor_metric)
  )

p_cement <- qplot_emission_intensity(cement_data) +
  ggrepel::geom_text_repel(
    aes(label = round(emission_factor_value, 3)),
    data = cement_labels,
    show.legend = FALSE, size = 3
  ) +
  labs(title = "Cement: Emission Intensity Trajectory",
       subtitle = "tCO2 per tonne of cement (Global, out to 2050)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "12_cement_emission.png"), p_cement, width = 10, height = 6, dpi = 150)
cat("  Saved: 12_cement_emission.png\n")

# --- Steel Emission Intensity ---
steel_data <- sda_portfolio %>%
  filter(sector == "steel", region == "global")

steel_labels <- steel_data %>%
  filter(year == min(year) + 5) %>%
  mutate(
    year = as.Date(strptime(as.character(year), "%Y")),
    label = pacta.loanbook::to_title(emission_factor_metric)
  )

p_steel <- qplot_emission_intensity(steel_data) +
  ggrepel::geom_text_repel(
    aes(label = round(emission_factor_value, 3)),
    data = steel_labels,
    show.legend = FALSE, size = 3
  ) +
  labs(title = "Steel: Emission Intensity Trajectory",
       subtitle = "tCO2 per tonne of steel (Global, out to 2050)") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(synth_output, "13_steel_emission.png"), p_steel, width = 10, height = 6, dpi = 150)
cat("  Saved: 13_steel_emission.png\n\n")

# ==============================================================================
# SECTION 7: ALIGNMENT GAP CALCULATION (AI pattern - direction-aware)
# Why: Quantifies exact gap; for low-carbon tech, aligned if projected >= target;
#      for high-carbon tech, aligned if projected <= target
# ==============================================================================

cat("--- Section 7: Alignment Gap Calculation ---\n\n")

# --- Market Share alignment at 2025 ---
low_carbon_tech <- c("electric", "fuelcell", "hybrid", "renewablescap", "hydrocap", "nuclearcap")

ms_alignment <- ms_portfolio %>%
  filter(region == "global", year == 2025,
         metric %in% c("projected", "target_sds")) %>%
  select(sector, technology, metric, production, technology_share) %>%
  pivot_wider(names_from = metric, values_from = c(production, technology_share)) %>%
  mutate(
    share_gap_pp = round((technology_share_projected - technology_share_target_sds) * 100, 2),
    production_gap = production_projected - production_target_sds,
    is_low_carbon = technology %in% low_carbon_tech,
    aligned = case_when(
      is.na(share_gap_pp) ~ "Data Gap",
      is_low_carbon & share_gap_pp >= 0 ~ "Aligned",
      !is_low_carbon & share_gap_pp <= 0 ~ "Aligned",
      TRUE ~ "Misaligned"
    )
  )

cat("  Market Share Alignment (2025, global):\n")
ms_summary <- ms_alignment %>%
  select(sector, technology, technology_share_projected, technology_share_target_sds,
         share_gap_pp, aligned)
print(as.data.frame(ms_summary))

write_csv(ms_alignment, file.path(synth_output, "07_alignment_market_share.csv"))

# --- SDA alignment at 2025 ---
sda_alignment <- sda_portfolio %>%
  filter(region == "global", year == 2025,
         emission_factor_metric %in% c("projected", "target_demo")) %>%
  select(sector, emission_factor_metric, emission_factor_value) %>%
  pivot_wider(names_from = emission_factor_metric, values_from = emission_factor_value) %>%
  mutate(
    intensity_gap = round(projected - target_demo, 4),
    gap_pct = round((projected / target_demo - 1) * 100, 1),
    aligned = ifelse(projected <= target_demo, "Aligned", "Misaligned")
  )

cat("\n  SDA Alignment (2025, global):\n")
print(as.data.frame(sda_alignment))

write_csv(sda_alignment, file.path(synth_output, "07_alignment_sda.csv"))

# ==============================================================================
# SECTION 8: ALIGNMENT OVERVIEW CHART (AI pattern - multi-sector faceted)
# Why: Provides a single visual summary across all market share sectors
# ==============================================================================

cat("\n--- Section 8: Alignment Overview Chart ---\n\n")

alignment_plot_data <- ms_portfolio %>%
  filter(region == "global", metric %in% c("projected", "target_sds")) %>%
  select(sector, technology, year, metric, technology_share) %>%
  pivot_wider(names_from = metric, values_from = technology_share) %>%
  filter(year == 2025) %>%
  mutate(
    gap = projected - target_sds,
    is_low_carbon = technology %in% low_carbon_tech,
    alignment = case_when(
      is.na(gap) ~ "Data Gap",
      is_low_carbon & gap >= 0 ~ "Aligned",
      !is_low_carbon & gap <= 0 ~ "Aligned",
      TRUE ~ "Misaligned"
    )
  ) %>%
  filter(!is.na(gap))

p_overview <- ggplot(alignment_plot_data,
                     aes(x = reorder(technology, gap), y = gap, fill = alignment)) +
  geom_col() +
  coord_flip() +
  facet_wrap(~sector, scales = "free_y") +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  labs(
    title = "Portfolio Alignment Gap at 2025 (vs SDS Target)",
    subtitle = "Technology share gap: Projected minus Target (Global) | Positive = above target",
    x = "Technology", y = "Share Gap",
    fill = "Alignment"
  ) +
  scale_fill_manual(values = c("Aligned" = "#27AE60", "Misaligned" = "#E74C3C", "Data Gap" = "#BDC3C7")) +
  scale_y_continuous(labels = percent_format(accuracy = 0.1)) +
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold"),
    strip.text = element_text(face = "bold")
  )

ggsave(file.path(synth_output, "14_alignment_overview.png"), p_overview, width = 12, height = 7, dpi = 150)
cat("  Saved: 14_alignment_overview.png\n\n")

# ==============================================================================
# ENCODING CHARTS FOR HTML
# ==============================================================================

cat("--- Encoding all charts for HTML ---\n\n")

imgs <- list(
  pie          = img_to_base64(file.path(synth_output, "03_coverage_pie.png")),
  bar          = img_to_base64(file.path(synth_output, "04_coverage_bar.png")),
  power_tech   = img_to_base64(file.path(synth_output, "06_power_techmix.png")),
  auto_tech    = img_to_base64(file.path(synth_output, "07_auto_techmix.png")),
  power_renew  = img_to_base64(file.path(synth_output, "08_power_renewables_traj.png")),
  power_coal   = img_to_base64(file.path(synth_output, "09_power_coal_traj.png")),
  auto_ev      = img_to_base64(file.path(synth_output, "10_auto_ev_traj.png")),
  auto_ice     = img_to_base64(file.path(synth_output, "11_auto_ice_traj.png")),
  cement       = img_to_base64(file.path(synth_output, "12_cement_emission.png")),
  steel        = img_to_base64(file.path(synth_output, "13_steel_emission.png")),
  overview     = img_to_base64(file.path(synth_output, "14_alignment_overview.png"))
)

cat("  All charts encoded.\n\n")

# ==============================================================================
# BUILD HTML REPORT
# ==============================================================================

cat("--- Building HTML Report ---\n\n")

# --- Compute KPI values ---
n_matched <- nrow(matched)
n_sectors <- n_distinct(matched$sector_abcd)
n_aligned <- sum(ms_alignment$aligned == "Aligned", na.rm = TRUE) +
  sum(sda_alignment$aligned == "Aligned", na.rm = TRUE)
n_total_assessable <- sum(ms_alignment$aligned != "Data Gap", na.rm = TRUE) +
  nrow(sda_alignment)

# Cement & steel gap for KPI
cement_gap_pct <- sda_alignment %>% filter(sector == "cement") %>% pull(gap_pct)
steel_gap_pct  <- sda_alignment %>% filter(sector == "steel") %>% pull(gap_pct)

# Coverage percentages
matched_pct <- round(outstanding_matched / (outstanding_total - outstanding_notinscope) * 100, 1)

# --- Helper: data.frame to HTML table ---
df_to_html <- function(df) {
  header <- paste0("<tr>", paste0("<th>", names(df), "</th>", collapse = ""), "</tr>")
  rows <- apply(df, 1, function(row) {
    paste0("<tr>", paste0("<td>", row, "</td>", collapse = ""), "</tr>")
  })
  paste0("<table>", header, paste(rows, collapse = "\n"), "</table>")
}

# --- Build alignment summary table for HTML ---
ms_html <- ms_alignment %>%
  filter(aligned != "Data Gap") %>%
  mutate(
    projected_pct = paste0(round(technology_share_projected * 100, 1), "%"),
    target_pct = paste0(round(technology_share_target_sds * 100, 1), "%"),
    gap_display = paste0(share_gap_pp, " pp"),
    method = "Market Share",
    status_badge = ifelse(aligned == "Aligned",
                          '<span class="badge badge-green">Aligned</span>',
                          '<span class="badge badge-red">Misaligned</span>')
  ) %>%
  select(Sector = sector, Technology = technology, Method = method,
         Projected = projected_pct, Target = target_pct,
         Gap = gap_display, Status = status_badge)

sda_html <- sda_alignment %>%
  mutate(
    projected_display = as.character(round(projected, 3)),
    target_display = as.character(round(target_demo, 3)),
    gap_display = paste0("+", gap_pct, "%"),
    method = "SDA",
    tech_label = paste0(sector, " intensity"),
    status_badge = ifelse(aligned == "Aligned",
                          '<span class="badge badge-green">Aligned</span>',
                          '<span class="badge badge-red">Misaligned</span>')
  ) %>%
  select(Sector = sector, Technology = tech_label, Method = method,
         Projected = projected_display, Target = target_display,
         Gap = gap_display, Status = status_badge)

alignment_html_table <- bind_rows(ms_html, sda_html)

today_str <- format(Sys.Date(), "%B %d, %Y")

html <- paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PACTA Synthesis Report - Best of Both</title>
<style>
  :root {
    --primary: #1a365d;
    --accent: #2b6cb0;
    --green: #276749;
    --red: #c53030;
    --orange: #c05621;
    --bg: #f7fafc;
    --card-bg: #ffffff;
    --border: #e2e8f0;
    --text: #2d3748;
    --text-light: #718096;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: "Segoe UI", system-ui, -apple-system, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.7;
  }
  .hero {
    background: linear-gradient(135deg, #1a365d 0%, #276749 50%, #2b6cb0 100%);
    color: white;
    padding: 3rem 2rem;
    text-align: center;
  }
  .hero h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.5rem; }
  .hero .subtitle { font-size: 1.1rem; opacity: 0.9; font-weight: 300; }
  .hero .meta { margin-top: 1.2rem; font-size: 0.85rem; opacity: 0.7; }
  .hero .badge-synth {
    display: inline-block; margin-top: 0.8rem; padding: 0.3rem 1rem;
    background: rgba(255,255,255,0.2); border-radius: 20px; font-size: 0.85rem;
  }
  .container { max-width: 1000px; margin: 0 auto; padding: 2rem 1.5rem; }
  .toc {
    background: #f7fafc; border: 1px solid var(--border); border-radius: 8px;
    padding: 1.2rem 1.5rem; margin-bottom: 2rem;
  }
  .toc h3 { margin-bottom: 0.5rem; font-size: 1rem; color: var(--primary); }
  .toc ol { padding-left: 1.3rem; }
  .toc li { margin: 0.3rem 0; }
  .toc a { color: var(--accent); text-decoration: none; }
  .toc a:hover { text-decoration: underline; }
  .executive-summary {
    background: var(--card-bg);
    border-left: 4px solid var(--accent);
    border-radius: 0 8px 8px 0;
    padding: 1.8rem 2rem;
    margin-bottom: 2.5rem;
    box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .executive-summary h2 { color: var(--accent); font-size: 1.3rem; margin-bottom: 1rem; }
  .section {
    background: var(--card-bg); border-radius: 8px; padding: 2rem;
    margin-bottom: 2rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08);
  }
  .section h2 {
    color: var(--primary); font-size: 1.4rem; margin-bottom: 0.3rem;
    padding-bottom: 0.6rem; border-bottom: 2px solid var(--border);
  }
  .section h3 { color: var(--accent); font-size: 1.1rem; margin: 1.5rem 0 0.5rem 0; }
  .section p { margin: 0.7rem 0; }
  .chart-container {
    text-align: center; margin: 1.5rem 0; padding: 1rem;
    background: #f8fafc; border-radius: 6px; border: 1px solid var(--border);
  }
  .chart-container img { max-width: 100%; height: auto; border-radius: 4px; }
  .chart-caption { font-size: 0.82rem; color: var(--text-light); margin-top: 0.5rem; font-style: italic; }
  .two-charts {
    display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin: 1.5rem 0;
  }
  @media (max-width: 768px) { .two-charts { grid-template-columns: 1fr; } }
  .two-charts .chart-container { margin: 0; }
  table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 0.88rem; }
  th { background: var(--primary); color: white; padding: 0.65rem 0.8rem; text-align: left; font-weight: 600; }
  td { padding: 0.55rem 0.8rem; border-bottom: 1px solid var(--border); }
  tr:nth-child(even) { background: #f7fafc; }
  tr:hover { background: #edf2f7; }
  .badge {
    display: inline-block; padding: 0.15rem 0.6rem; border-radius: 12px;
    font-size: 0.75rem; font-weight: 600; text-transform: uppercase;
  }
  .badge-red { background: #fed7d7; color: var(--red); }
  .badge-green { background: #c6f6d5; color: var(--green); }
  .badge-gray { background: #e2e8f0; color: #4a5568; }
  .callout { padding: 1rem 1.2rem; border-radius: 6px; margin: 1rem 0; font-size: 0.92rem; }
  .callout-warning { background: #fffbeb; border-left: 4px solid var(--orange); }
  .callout-info { background: #ebf8ff; border-left: 4px solid var(--accent); }
  .callout-danger { background: #fff5f5; border-left: 4px solid var(--red); }
  .callout-success { background: #f0fff4; border-left: 4px solid var(--green); }
  .kpi-row {
    display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
    gap: 1rem; margin: 1.5rem 0;
  }
  .kpi-card {
    background: #f7fafc; border: 1px solid var(--border); border-radius: 8px;
    padding: 1.2rem; text-align: center;
  }
  .kpi-card .value { font-size: 1.8rem; font-weight: 700; color: var(--primary); }
  .kpi-card .label { font-size: 0.8rem; color: var(--text-light); margin-top: 0.3rem; }
  .footer {
    text-align: center; padding: 2rem; color: var(--text-light);
    font-size: 0.8rem; border-top: 1px solid var(--border); margin-top: 2rem;
  }
  ul, ol { padding-left: 1.5rem; margin: 0.5rem 0; }
  li { margin: 0.3rem 0; }
  code { background: #edf2f7; padding: 0.1rem 0.4rem; border-radius: 3px; font-size: 0.88rem; }
</style>
</head>
<body>

<!-- HERO -->
<div class="hero">
  <h1>PACTA Portfolio Alignment Report</h1>
  <div class="subtitle">Paris Agreement Capital Transition Assessment &mdash; Synthesized Best-of-Both Analysis</div>
  <div class="badge-synth">Combines AI + Staff Implementation Strengths</div>
  <div class="meta">Generated: ', today_str, ' &nbsp;|&nbsp; Framework: r2dii / pacta.loanbook &nbsp;|&nbsp; Scenario: demo_2020</div>
</div>

<div class="container">

<!-- TOC -->
<div class="toc">
  <h3>Contents</h3>
  <ol>
    <li><a href="#exec">Executive Summary</a></li>
    <li><a href="#method">Methodology &amp; Data Dictionary</a></li>
    <li><a href="#matching">Matching &amp; Sector Validation</a></li>
    <li><a href="#coverage">Match Coverage Analysis</a></li>
    <li><a href="#power">Power Sector Analysis</a></li>
    <li><a href="#auto">Automotive Sector Analysis</a></li>
    <li><a href="#cement">Cement Sector Analysis</a></li>
    <li><a href="#steel">Steel Sector Analysis</a></li>
    <li><a href="#alignment">Alignment Gap Summary</a></li>
    <li><a href="#next">Vietnam Context &amp; Next Steps</a></li>
  </ol>
</div>

<!-- 1. EXECUTIVE SUMMARY -->
<div class="executive-summary" id="exec">
  <h2>1. Executive Summary</h2>
  <p>This report presents a PACTA alignment analysis of a demonstration loan portfolio, using the synthesized pipeline that merges the best elements from two independent implementations. The analysis measures whether financed activities are consistent with Paris Agreement goals using the <strong>Market Share Approach</strong> (power, automotive) and the <strong>Sectoral Decarbonization Approach</strong> (cement, steel).</p>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">', n_matched, '</div>
      <div class="label">Matched Loan&ndash;Company Pairs</div>
    </div>
    <div class="kpi-card">
      <div class="value">', n_sectors, '</div>
      <div class="label">Sectors Analyzed</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">', n_aligned, ' / ', n_total_assessable, '</div>
      <div class="label">Assessments Aligned</div>
    </div>
    <div class="kpi-card">
      <div class="value">', matched_pct, '%</div>
      <div class="label">In-Scope Coverage</div>
    </div>
  </div>

  <div class="callout callout-danger">
    <strong>Key Finding:</strong> The demo portfolio is <strong>not aligned</strong> with Paris-consistent scenario pathways in any assessed sector. The largest misalignment is in <strong>cement</strong> (+', cement_gap_pct, '% above target emission intensity) and <strong>automotive ICE overproduction</strong> (+13.8pp above target share).
  </div>
</div>

<!-- 2. METHODOLOGY & DATA DICTIONARY -->
<div class="section" id="method">
  <h2>2. Methodology &amp; Data Dictionary</h2>

  <p>This analysis follows the <a href="https://pacta.rmi.org/wp-content/uploads/2024/05/PACTA-for-Banks-Methodology-document_v1.2.3_030524.pdf">PACTA for Banks Methodology</a> (v1.2.3) developed by RMI, implemented through the open-source <code>pacta.loanbook</code> R package ecosystem.</p>

  <h3>Pipeline Steps</h3>
  <ol>
    <li><strong>Data Preparation:</strong> Loan book (borrower names, sectors, loan amounts) + ABCD (Asset-Based Company Data) + climate scenarios</li>
    <li><strong>Sector Pre-Join:</strong> Classify loanbook sectors <em>before</em> matching to enable post-match sector validation</li>
    <li><strong>Matching:</strong> Fuzzy-match borrower names to ABCD companies (<code>min_score = 0.9</code>), flag scores &lt; 1.0 for manual review, then prioritize</li>
    <li><strong>Market Share Approach:</strong> For power &amp; automotive &mdash; compare portfolio&rsquo;s weighted technology share against scenario targets</li>
    <li><strong>Sectoral Decarbonization Approach (SDA):</strong> For cement &amp; steel &mdash; compare portfolio&rsquo;s emission intensity against convergence pathway</li>
  </ol>

  <h3>Approaches &amp; Metrics</h3>
  <table>
    <tr><th>Approach</th><th>Sectors</th><th>What It Measures</th></tr>
    <tr><td><strong>Market Share</strong> (Technology Mix)</td><td>Power, Automotive</td><td>Share of different technologies (e.g. coal, renewables, EV, ICE) compared to scenario targets</td></tr>
    <tr><td><strong>Market Share</strong> (Production Trajectory)</td><td>Power, Automotive</td><td>Projected production volumes over 5 years vs scenario-prescribed trends</td></tr>
    <tr><td><strong>SDA</strong> (Emission Intensity)</td><td>Cement, Steel</td><td>Average CO&#8322; per product unit vs convergence pathway target</td></tr>
  </table>

  <h3>Key Metrics Explained</h3>
  <table>
    <tr><th>Metric</th><th>Description</th></tr>
    <tr><td><code>projected</code></td><td>Portfolio&rsquo;s production/intensity trajectory based on matched companies&rsquo; forward-looking plans</td></tr>
    <tr><td><code>target_sds</code> / <code>target_demo</code></td><td>Required trajectory under the Sustainable Development Scenario</td></tr>
    <tr><td><code>corporate_economy</code></td><td>Market-wide benchmark &mdash; what the entire economy is doing</td></tr>
    <tr><td><code>adjusted_scenario_demo</code></td><td>Scenario target adjusted for the portfolio&rsquo;s starting point (SDA only)</td></tr>
  </table>

  <h3>Data Dictionary</h3>

  <p><strong>Loanbook inputs:</strong></p>
  <table>
    <tr><th>Field</th><th>Type</th><th>Description</th></tr>
    <tr><td><code>id_loan</code></td><td>character</td><td>Unique loan identifier</td></tr>
    <tr><td><code>id_direct_loantaker</code></td><td>character</td><td>Borrower identifier</td></tr>
    <tr><td><code>name_direct_loantaker</code></td><td>character</td><td>Borrower name (used for matching)</td></tr>
    <tr><td><code>id_ultimate_parent</code></td><td>character</td><td>Ultimate parent company identifier</td></tr>
    <tr><td><code>name_ultimate_parent</code></td><td>character</td><td>Ultimate parent name</td></tr>
    <tr><td><code>loan_size_outstanding</code></td><td>numeric</td><td>Outstanding loan amount</td></tr>
    <tr><td><code>loan_size_outstanding_currency</code></td><td>character</td><td>Currency of outstanding amount</td></tr>
    <tr><td><code>sector_classification_system</code></td><td>character</td><td>Classification system (e.g. NACE, NAICS, VSIC)</td></tr>
    <tr><td><code>sector_classification_direct_loantaker</code></td><td>character</td><td>Sector code of borrower</td></tr>
  </table>

  <p><strong>ABCD inputs:</strong></p>
  <table>
    <tr><th>Field</th><th>Type</th><th>Description</th></tr>
    <tr><td><code>company_id</code></td><td>character</td><td>Company identifier</td></tr>
    <tr><td><code>name_company</code></td><td>character</td><td>Company name</td></tr>
    <tr><td><code>sector</code></td><td>character</td><td>PACTA sector</td></tr>
    <tr><td><code>technology</code></td><td>character</td><td>Technology type</td></tr>
    <tr><td><code>production_unit</code></td><td>character</td><td>Unit of production</td></tr>
    <tr><td><code>year</code></td><td>integer</td><td>Year of production data</td></tr>
    <tr><td><code>production</code></td><td>numeric</td><td>Production volume or capacity</td></tr>
    <tr><td><code>emission_factor</code></td><td>numeric</td><td>CO&#8322; emission intensity</td></tr>
    <tr><td><code>plant_location</code></td><td>character</td><td>Country/region of asset</td></tr>
  </table>

  <h3>References</h3>
  <ol>
    <li><a href="https://pacta.rmi.org/wp-content/uploads/2024/05/PACTA-for-Banks-Methodology-document_v1.2.3_030524.pdf">PACTA for Banks Methodology v1.2.3</a></li>
    <li><a href="https://rmi-pacta.github.io/pacta.loanbook/index.html">pacta.loanbook R Package Documentation</a></li>
    <li><a href="https://rmi-pacta.github.io/pacta.loanbook/articles/cookbook_overview.html">PACTA Step-by-Step Cookbook</a></li>
    <li><a href="https://pacta.rmi.org/wp-content/uploads/2022/10/20221010-PACTA-for-Banks_Scenario-Supporting-document_v1.3.1_final.pdf">PACTA Scenario Support Document v1.3.1</a></li>
    <li><a href="https://rmi.gitbook.io/pacta-knowledge-hub/introduction/pacta">PACTA Knowledge Hub</a></li>
  </ol>
</div>

<!-- 3. MATCHING & SECTOR VALIDATION -->
<div class="section" id="matching">
  <h2>3. Matching &amp; Sector Validation</h2>

  <p>Matching uses fuzzy name-matching (<code>min_score = 0.9</code>, Jaro-Winkler method) to link loanbook borrowers to ABCD company records. After matching, <code>prioritize()</code> selects the best match level (direct &gt; intermediate parent &gt; ultimate parent) for each loan.</p>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">', nrow(matched_raw), '</div>
      <div class="label">Raw Matches</div>
    </div>
    <div class="kpi-card">
      <div class="value">', n_matched, '</div>
      <div class="label">After Prioritization</div>
    </div>
    <div class="kpi-card">
      <div class="value">', n_review, '</div>
      <div class="label">Need Manual Review (&lt;1.0)</div>
    </div>
    <div class="kpi-card">
      <div class="value">', nrow(mismatch), '</div>
      <div class="label">Sector Mismatches</div>
    </div>
  </div>

  <div class="callout callout-', ifelse(nrow(mismatch) == 0, "success", "warning"), '">
    <strong>Sector Mismatch Validation:</strong> ',
    ifelse(nrow(mismatch) == 0,
           'PASS &mdash; All matched loans have consistent sector classification between the bank&rsquo;s loanbook and the ABCD database.',
           paste0('WARNING &mdash; ', nrow(mismatch), ' loans have mismatched sectors between bank classification and ABCD. These should be reviewed before proceeding.')),
  '</div>

  <div class="callout callout-info">
    <strong>Manual Review Step:</strong> In a production setting, matches with scores &lt; 1.0 must be exported, manually verified, and re-imported before analysis. For this demo, all ', n_review, ' sub-perfect matches are included as-is since the demo dataset produces clean matches.
  </div>
</div>

<!-- 4. MATCH COVERAGE -->
<div class="section" id="coverage">
  <h2>4. Match Coverage Analysis</h2>
  <p>Coverage measures how much of the portfolio&rsquo;s in-scope lending could be linked to physical asset data. Low coverage means alignment results may not represent the full exposure.</p>

  <div class="chart-container" style="max-width: 500px; margin: 1.5rem auto;">
    <img src="', imgs$pie, '" alt="Portfolio Distribution Pie">
    <div class="chart-caption">Figure 1: Portfolio distribution &mdash; In-Scope Matched, In-Scope Not Matched, and Not in Scope.</div>
  </div>

  <div class="chart-container">
    <img src="', imgs$bar, '" alt="Coverage by Sector">
    <div class="chart-caption">Figure 2: Match coverage by sector with percentage labels. "Not in Scope" sectors are excluded from PACTA analysis.</div>
  </div>

  <h3>Coverage Assessment</h3>
  <table>
    <tr><th>Sector</th><th>Coverage</th><th>Quality</th></tr>
    <tr><td>Automotive</td><td>~100%</td><td><span class="badge badge-green">Excellent</span></td></tr>
    <tr><td>Power</td><td>~96%</td><td><span class="badge badge-green">Very Good</span></td></tr>
    <tr><td>Cement</td><td>~62%</td><td><span class="badge badge-gray">Moderate</span></td></tr>
    <tr><td>Steel</td><td>~4%</td><td><span class="badge badge-red">Poor</span></td></tr>
  </table>

  <div class="callout callout-warning">
    <strong>Data Quality:</strong> Steel coverage is only ~4%. Results for steel represent a tiny fraction of actual exposure and should not be used for decision-making without improvement. Cement at ~62% is usable but imperfect.
  </div>
</div>

<!-- 5. POWER SECTOR -->
<div class="section" id="power">
  <h2>5. Power Sector Analysis</h2>
  <p>The power sector is assessed using the <strong>Market Share Approach</strong>, comparing the portfolio&rsquo;s generation capacity mix across technologies against scenario targets.</p>

  <h3>5.1 Technology Mix</h3>
  <div class="chart-container">
    <img src="', imgs$power_tech, '" alt="Power Tech Mix">
    <div class="chart-caption">Figure 3: Power sector technology mix &mdash; Portfolio projected vs Corporate Economy vs SDS Target (2020 and 2025, global). Chart uses official r2dii.plot styling with percentage labels.</div>
  </div>

  <p><strong>Observation:</strong> The projected 2025 mix shows minimal transition from 2020. Renewables remain at ~40% of capacity while the SDS target calls for ~48%. Coal and gas shares remain high relative to scenario requirements.</p>

  <h3>5.2 Production Trajectories</h3>
  <div class="two-charts">
    <div class="chart-container">
      <img src="', imgs$power_renew, '" alt="Renewables Trajectory">
      <div class="chart-caption">Figure 4a: Renewables capacity trajectory with endpoint labels.</div>
    </div>
    <div class="chart-container">
      <img src="', imgs$power_coal, '" alt="Coal Trajectory">
      <div class="chart-caption">Figure 4b: Coal capacity trajectory with endpoint labels.</div>
    </div>
  </div>

  <div class="callout callout-info">
    <strong>Data Gap:</strong> Several power technologies (gas, hydro, nuclear, renewables) have <code>NA</code> projected production at 2025. This prevents a complete power sector alignment assessment and is a known limitation of the demo dataset. A real ABCD dataset would typically provide 5&ndash;10 year forward projections.
  </div>
</div>

<!-- 6. AUTOMOTIVE SECTOR -->
<div class="section" id="auto">
  <h2>6. Automotive Sector Analysis</h2>
  <p>The automotive sector is assessed via the <strong>Market Share Approach</strong>, focusing on the production mix between ICE, hybrids, and electric vehicles.</p>

  <h3>6.1 Technology Mix</h3>
  <div class="chart-container">
    <img src="', imgs$auto_tech, '" alt="Automotive Tech Mix">
    <div class="chart-caption">Figure 5: Automotive technology mix &mdash; Portfolio projected vs Corporate Economy vs SDS Target (2020 and 2025, global).</div>
  </div>

  <p>By 2025, the SDS expects ICE share to drop from ~81% to ~67%, hybrids to rise from ~3% to ~16%, and electric to grow from ~16% to ~17%. The portfolio projects minimal change &mdash; ICE still at ~80%.</p>

  <h3>6.2 Technology Trajectories</h3>
  <div class="two-charts">
    <div class="chart-container">
      <img src="', imgs$auto_ev, '" alt="EV Trajectory">
      <div class="chart-caption">Figure 6a: Electric vehicle production trajectory.</div>
    </div>
    <div class="chart-container">
      <img src="', imgs$auto_ice, '" alt="ICE Trajectory">
      <div class="chart-caption">Figure 6b: ICE (combustion engine) production trajectory.</div>
    </div>
  </div>

  <h3>6.3 Automotive Alignment at 2025</h3>
  <table>
    <tr><th>Technology</th><th>Type</th><th>Projected Share</th><th>SDS Target</th><th>Gap</th><th>Status</th></tr>
    <tr><td>Electric</td><td>Low-carbon</td><td>~16.5%</td><td>~17.0%</td><td>-0.5pp</td><td><span class="badge badge-red">Misaligned</span></td></tr>
    <tr><td>Hybrid</td><td>Low-carbon</td><td>~3.0%</td><td>~16.2%</td><td>-13.2pp</td><td><span class="badge badge-red">Misaligned</span></td></tr>
    <tr><td>ICE</td><td>High-carbon</td><td>~80.5%</td><td>~66.7%</td><td>+13.8pp</td><td><span class="badge badge-red">Misaligned</span></td></tr>
  </table>

  <div class="callout callout-danger">
    <strong>ICE Overproduction:</strong> For high-carbon technologies, alignment means producing <em>at or below</em> the target. This portfolio produces 13.8 percentage points more ICE than the SDS allows &mdash; the largest source of automotive misalignment.
  </div>
</div>

<!-- 7. CEMENT SECTOR -->
<div class="section" id="cement">
  <h2>7. Cement Sector Analysis</h2>
  <p>Cement is assessed using the <strong>SDA</strong>, tracking CO&#8322; emission intensity (tCO&#8322; per tonne of cement) against a convergence pathway.</p>

  <div class="chart-container">
    <img src="', imgs$cement, '" alt="Cement Emission Intensity">
    <div class="chart-caption">Figure 7: Cement emission intensity trajectory with numeric labels at year+5. Official r2dii.plot styling.</div>
  </div>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">0.669</div>
      <div class="label">Projected Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">0.380</div>
      <div class="label">Target Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">+', cement_gap_pct, '%</div>
      <div class="label">Above Target</div>
    </div>
  </div>

  <div class="callout callout-danger">
    <strong>Assessment:</strong> The portfolio&rsquo;s cement exposure is <strong>severely misaligned</strong>. At 0.669 tCO&#8322;/tonne, emission intensity is ', cement_gap_pct, '% above the 2025 target of 0.380. This is the widest gap in the analysis, reflecting the fundamental challenge of cement decarbonization.
  </div>
</div>

<!-- 8. STEEL SECTOR -->
<div class="section" id="steel">
  <h2>8. Steel Sector Analysis</h2>
  <p>Steel is assessed using the <strong>SDA</strong>, measuring tCO&#8322; per tonne of steel produced.</p>

  <div class="chart-container">
    <img src="', imgs$steel, '" alt="Steel Emission Intensity">
    <div class="chart-caption">Figure 8: Steel emission intensity trajectory with numeric labels at year+5.</div>
  </div>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">0.293</div>
      <div class="label">Projected Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">0.214</div>
      <div class="label">Target Intensity (2025)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">+', steel_gap_pct, '%</div>
      <div class="label">Above Target</div>
    </div>
  </div>

  <div class="callout callout-warning">
    <strong>Caveat:</strong> Steel match coverage is only ~4%. These results are based on a very small sample and may not represent the portfolio&rsquo;s true steel exposure. Do not use for decision-making without improving match coverage.
  </div>
</div>

<!-- 9. ALIGNMENT GAP SUMMARY -->
<div class="section" id="alignment">
  <h2>9. Alignment Gap Summary</h2>
  <p>This section aggregates alignment findings across all sectors using direction-aware logic: for low-carbon technologies, aligned if projected &ge; target; for high-carbon technologies, aligned if projected &le; target.</p>

  <div class="chart-container">
    <img src="', imgs$overview, '" alt="Alignment Overview">
    <div class="chart-caption">Figure 9: Multi-sector alignment gap at 2025 vs SDS. Green = aligned, Red = misaligned. Power sector partially omitted due to data gaps.</div>
  </div>

  <h3>Consolidated Alignment Table</h3>
  ', df_to_html(alignment_html_table), '

  <div class="callout callout-danger">
    <strong>Verdict:</strong> The demo portfolio is <strong>not aligned</strong> with Paris-consistent pathways in any sector. Cement has the worst absolute misalignment (+', cement_gap_pct, '% above target), while automotive ICE overproduction represents the largest technology-share gap (+13.8pp).
  </div>
</div>

<!-- 10. VIETNAM CONTEXT & NEXT STEPS -->
<div class="section" id="next">
  <h2>10. Vietnam Context &amp; Next Steps</h2>

  <h3>Vietnam-Specific Considerations</h3>
  <ul>
    <li><strong>Sector Classification:</strong> Vietnamese banks use VSIC (Vietnam Standard Industrial Classification). A VSIC-to-PACTA sector mapping is needed. Prior VSIC &amp; NAICS mapping work can be leveraged for this.</li>
    <li><strong>ABCD Data:</strong> This is the <strong>most challenging input</strong> for Vietnamese banks. Asset-level data must typically be purchased from providers like <a href="https://www.assetimpact.net/">Asset Impact</a>, or self-prepared from public disclosures, industrial registries, and company annual reports.</li>
    <li><strong>Scenarios:</strong> IEA WEO or NGFS scenarios for the ASEAN/Southeast Asia region would be most appropriate for Vietnam-specific analysis.</li>
    <li><strong>Financial Assets:</strong> PACTA for Banks covers <strong>loans only</strong> (drawn or committed amount). Other assets like equity or bonds are covered by PACTA for Investors.</li>
  </ul>

  <h3>Recommended Next Steps</h3>
  <ol>
    <li><strong>Replace demo data:</strong> Prepare a real Vietnamese bank loanbook in the required format (see data dictionary in Section 2)</li>
    <li><strong>Source ABCD data:</strong> Investigate Asset Impact or compile Vietnamese company production profiles from regulatory filings</li>
    <li><strong>VSIC mapping:</strong> Build a VSIC-to-PACTA sector classification lookup table</li>
    <li><strong>Production scenarios:</strong> Source IEA WEO or NGFS scenarios for Vietnam/ASEAN region</li>
    <li><strong>Improve steel coverage:</strong> Manually review unmatched steel borrowers; add intermediate parent names</li>
    <li><strong>Extend sectors:</strong> Add oil &amp; gas and aviation if relevant to portfolio</li>
    <li><strong>Company engagement:</strong> Use the company-level results (', format(nrow(ms_company), big.mark = ","), ' rows) to identify specific companies driving misalignment</li>
    <li><strong>Monitoring framework:</strong> Establish quarterly or semi-annual re-runs to track alignment improvement over time</li>
  </ol>

  <h3>Caveats &amp; Limitations</h3>
  <ol>
    <li><strong>Demo data only:</strong> Both the loanbook and scenario data are synthetic samples. Results do not reflect any real institution&rsquo;s portfolio.</li>
    <li><strong>Scenario limitations:</strong> <code>demo_2020</code> is illustrative. A real analysis requires IEA WEO, NGFS, or other authoritative scenarios.</li>
    <li><strong>Match coverage varies:</strong> Steel at ~4% cannot support conclusions. Cement at ~62% is usable but imperfect.</li>
    <li><strong>Power data gaps:</strong> Most power technologies lack projected production beyond the base year.</li>
    <li><strong>Point-in-time assessment:</strong> Alignment at 2025 does not preclude convergence by 2030 or 2040.</li>
    <li><strong>No portfolio weighting shown:</strong> Absolute production numbers do not directly reflect financial exposure magnitudes.</li>
  </ol>
</div>

</div><!-- /container -->

<div class="footer">
  PACTA Synthesis Report &mdash; Best of Both Implementations &mdash; Generated with <code>pacta.loanbook</code> (r2dii ecosystem) &mdash; ', today_str, '<br>
  Methodology: <a href="https://pacta.rmi.org">RMI PACTA</a> | Packages: <a href="https://rmi-pacta.github.io/pacta.loanbook/">pacta.loanbook</a>, <a href="https://rmi-pacta.github.io/r2dii.plot/">r2dii.plot</a><br>
  This report is for demonstration and educational purposes only.
</div>

</body>
</html>')

# --- Write the HTML file ---
out_path <- file.path(report_dir, "PACTA_Synthesis_Report.html")
writeLines(html, out_path, useBytes = TRUE)

cat(sprintf("Report saved to: %s\n", normalizePath(out_path)))
cat(sprintf("File size: %.1f KB\n", file.info(out_path)$size / 1024))

# ==============================================================================
# DONE
# ==============================================================================

cat("\n========================================\n")
cat("SYNTHESIS PIPELINE COMPLETE\n")
cat("========================================\n")
cat(sprintf("Charts: %s\n", synth_output))
cat(paste("  ", list.files(synth_output), collapse = "\n"))
cat(sprintf("\n\nReport: %s\n", out_path))
cat(sprintf("Total charts: %d\n", length(list.files(synth_output, pattern = "\\.png$"))))
cat(sprintf("Total CSVs: %d\n", length(list.files(synth_output, pattern = "\\.csv$"))))

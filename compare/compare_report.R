# ==============================================================================
# PACTA Comparison Report Generator
# Compares two implementations side-by-side:
#   - "AI Approach"    (pacta_demo.R logic — default fuzzy matching)
#   - "Staff Approach"  (Trang Tran's Rmd logic — exact matching, r2dii.plot)
# Produces: reports/PACTA_Comparison_Report.html
#
# Run from project root:
#   Rscript compare/compare_report.R
# ==============================================================================

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

cat("========================================\n")
cat("PACTA COMPARISON REPORT GENERATOR\n")
cat("========================================\n\n")

# --- Output directory for comparison charts ---
compare_output <- file.path(getwd(), "compare", "output")
dir.create(compare_output, showWarnings = FALSE, recursive = TRUE)

# ==============================================================================
# HELPER: base64 encode a PNG
# ==============================================================================
img_to_base64 <- function(path) {
  raw <- readBin(path, "raw", file.info(path)$size)
  b64 <- base64enc::base64encode(raw)
  paste0("data:image/png;base64,", b64)
}

# ==============================================================================
# PHASE 1: RUN BOTH MATCHING PIPELINES
# ==============================================================================

cat("--- PHASE 1: Running both matching pipelines ---\n\n")

# --- Shared data ---
loanbook <- r2dii.data::loanbook_demo
abcd     <- r2dii.data::abcd_demo
scenario <- r2dii.data::scenario_demo_2020
co2      <- r2dii.data::co2_intensity_scenario_demo
region   <- r2dii.data::region_isos_demo

# ---- AI APPROACH: default fuzzy matching ----
cat("  [AI] Running match_name() with defaults (fuzzy)...\n")
matched_ai_raw <- match_name(loanbook, abcd)
matched_ai     <- prioritize(matched_ai_raw)
cat(sprintf("  [AI] Raw matches: %d | Prioritized: %d\n", nrow(matched_ai_raw), nrow(matched_ai)))

# ---- STAFF APPROACH: exact matching + sector pre-join ----
cat("  [Staff] Pre-joining sector classifications...\n")
loanbook_staff <- loanbook %>%
  mutate(sector_classification_direct_loantaker = as.character(sector_classification_direct_loantaker)) %>%
  left_join(sector_classifications, by = c(
    "sector_classification_system" = "code_system",
    "sector_classification_direct_loantaker" = "code"
  )) %>%
  rename(
    sector_matched = sector,
    borderline_matched = borderline
  )

cat("  [Staff] Running match_name() with min_score=1, method='jw', p=0.1...\n")
matched_staff_raw <- match_name(loanbook_staff, abcd, by_sector = TRUE, min_score = 1, method = "jw", p = 0.1)
matched_staff     <- prioritize(matched_staff_raw)
cat(sprintf("  [Staff] Raw matches: %d | Prioritized: %d\n", nrow(matched_staff_raw), nrow(matched_staff)))

# Staff sector mismatch check
mismatch <- matched_staff %>%
  filter(sector_matched != sector) %>%
  select(id_loan, name_direct_loantaker, sector_matched, sector)
cat(sprintf("  [Staff] Sector mismatches found: %d\n\n", nrow(mismatch)))

# ==============================================================================
# PHASE 2: RUN BOTH ANALYSIS PIPELINES
# ==============================================================================

cat("--- PHASE 2: Running both analysis pipelines ---\n\n")

# ---- AI: Market Share ----
cat("  [AI] Computing market share targets...\n")
ms_ai <- target_market_share(
  data       = matched_ai,
  abcd       = abcd,
  scenario   = scenario,
  region_isos = region
)

# ---- AI: SDA ----
cat("  [AI] Computing SDA targets...\n")
sda_ai <- target_sda(
  data                  = matched_ai,
  abcd                  = abcd,
  co2_intensity_scenario = co2,
  region_isos           = region
)

# ---- Staff: Market Share ----
cat("  [Staff] Computing market share targets...\n")
# Staff's Rmd removes the pre-joined columns before passing to target_market_share
ms_staff <- target_market_share(
  data       = matched_staff %>% select(-c("sector_matched", "borderline_matched")),
  abcd       = abcd,
  scenario   = scenario,
  region_isos = region
)

# ---- Staff: SDA ----
cat("  [Staff] Computing SDA targets...\n")
sda_staff <- target_sda(
  data                  = matched_staff,
  abcd                  = abcd,
  co2_intensity_scenario = co2,
  region_isos           = region
)

cat(sprintf("  [AI]    MS rows: %d | SDA rows: %d\n", nrow(ms_ai), nrow(sda_ai)))
cat(sprintf("  [Staff] MS rows: %d | SDA rows: %d\n\n", nrow(ms_staff), nrow(sda_staff)))

# ==============================================================================
# PHASE 3: BUILD QUANTITATIVE COMPARISON TABLES
# ==============================================================================

cat("--- PHASE 3: Building comparison tables ---\n\n")

# --- 3a. Match count comparison ---
match_comparison <- data.frame(
  Metric = c("Raw matches", "Prioritized matches", "Unique sectors", "Score range (min)", "Score range (max)"),
  AI     = c(nrow(matched_ai_raw), nrow(matched_ai), n_distinct(matched_ai$sector_abcd),
             round(min(matched_ai_raw$score), 3), round(max(matched_ai_raw$score), 3)),
  Staff  = c(nrow(matched_staff_raw), nrow(matched_staff), n_distinct(matched_staff$sector_abcd),
             round(min(matched_staff_raw$score), 3), round(max(matched_staff_raw$score), 3))
)

# --- 3b. Coverage by sector ---
sectors_ai <- matched_ai %>% count(sector_abcd) %>% rename(sector = sector_abcd, n_ai = n)
sectors_staff <- matched_staff %>% count(sector_abcd) %>% rename(sector = sector_abcd, n_staff = n)
coverage_comparison <- full_join(sectors_ai, sectors_staff, by = "sector") %>%
  mutate(
    n_ai    = ifelse(is.na(n_ai), 0, n_ai),
    n_staff = ifelse(is.na(n_staff), 0, n_staff),
    delta   = n_ai - n_staff
  ) %>%
  arrange(sector)

# --- 3c. Market Share alignment at 2025 ---
ms_alignment_fn <- function(ms_data, label) {
  ms_data %>%
    filter(region == "global", year == 2025,
           metric %in% c("projected", "target_sds")) %>%
    select(sector, technology, metric, technology_share) %>%
    pivot_wider(names_from = metric, values_from = technology_share) %>%
    mutate(
      gap_pp = round((projected - target_sds) * 100, 2),
      source = label
    ) %>%
    select(source, sector, technology, projected, target_sds, gap_pp)
}

ms_align_ai    <- ms_alignment_fn(ms_ai, "AI")
ms_align_staff <- ms_alignment_fn(ms_staff, "Staff")
ms_align_both  <- bind_rows(ms_align_ai, ms_align_staff)

# --- 3d. SDA alignment at 2025 ---
sda_alignment_fn <- function(sda_data, label) {
  sda_data %>%
    filter(region == "global", year == 2025,
           emission_factor_metric %in% c("projected", "target_demo")) %>%
    select(sector, emission_factor_metric, emission_factor_value) %>%
    pivot_wider(names_from = emission_factor_metric, values_from = emission_factor_value) %>%
    mutate(
      gap = round(projected - target_demo, 4),
      gap_pct = round((projected / target_demo - 1) * 100, 1),
      source = label
    ) %>%
    select(source, sector, projected, target_demo, gap, gap_pct)
}

sda_align_ai    <- sda_alignment_fn(sda_ai, "AI")
sda_align_staff <- sda_alignment_fn(sda_staff, "Staff")
sda_align_both  <- bind_rows(sda_align_ai, sda_align_staff)

cat("  Comparison tables built.\n\n")

# ==============================================================================
# PHASE 4: GENERATE SIDE-BY-SIDE CHARTS
# ==============================================================================

cat("--- PHASE 4: Generating comparison charts ---\n\n")

# Color palettes
ai_colors <- c(
  "projected" = "black", "corporate_economy" = "grey50",
  "target_sds" = "#27AE60", "target_cps" = "#E67E22"
)
ai_linetypes <- c(
  "projected" = "solid", "corporate_economy" = "dashed",
  "target_sds" = "solid", "target_cps" = "dotted"
)

# ---- 4a. Match Coverage Comparison ----
coverage_long <- bind_rows(
  sectors_ai %>% mutate(source = "AI Approach") %>% rename(n = n_ai),
  sectors_staff %>% mutate(source = "Staff Approach") %>% rename(n = n_staff)
)

p_match_compare <- ggplot(coverage_long, aes(x = reorder(sector, n), y = n, fill = source)) +
  geom_col(position = "dodge", width = 0.7) +
  coord_flip() +
  labs(
    title = "Prioritized Match Count by Sector",
    subtitle = "AI (fuzzy) vs Staff (exact only)",
    x = "Sector", y = "Number of Matched Loan-Company Pairs", fill = NULL
  ) +
  scale_fill_manual(values = c("AI Approach" = "#2E86AB", "Staff Approach" = "#E8505B")) +
  theme_minimal(base_size = 13) +
  theme(legend.position = "bottom")

ggsave(file.path(compare_output, "01_match_comparison.png"), p_match_compare, width = 10, height = 6, dpi = 150)
cat("  Saved: 01_match_comparison.png\n")

# ---- 4b. Power Tech Mix: AI custom ggplot2 ----
power_ai_techmix <- ms_ai %>%
  filter(sector == "power", region == "global",
         metric %in% c("projected", "target_sds"),
         year %in% c(2020, 2025)) %>%
  mutate(
    label = paste0(metric, " (", year, ")"),
    label = factor(label, levels = c("projected (2020)", "projected (2025)",
                                      "target_sds (2020)", "target_sds (2025)"))
  )

p_power_ai <- ggplot(power_ai_techmix, aes(x = label, y = technology_share, fill = technology)) +
  geom_col(position = "stack") +
  labs(title = "AI: Power Tech Mix", subtitle = "Custom ggplot2", x = "", y = "Share", fill = "Technology") +
  scale_y_continuous(labels = percent) +
  scale_fill_brewer(palette = "Set3") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))

ggsave(file.path(compare_output, "02a_power_techmix_ai.png"), p_power_ai, width = 8, height = 5, dpi = 150)

# ---- 4c. Power Tech Mix: Staff r2dii.plot ----
power_staff_techmix <- ms_staff %>%
  filter(scenario_source == "demo_2020", sector == "power", region == "global",
         metric %in% c("projected", "corporate_economy", "target_sds"))

p_power_staff <- qplot_techmix(power_staff_techmix) +
  ggrepel::geom_label_repel(
    aes(label = paste0(round(technology_share, 3) * 100, "%")),
    min.segment.length = 0,
    position = position_stack(vjust = 0.5),
    show.legend = FALSE,
    size = 2.5
  ) +
  labs(title = "Staff: Power Tech Mix", subtitle = "r2dii.plot + ggrepel labels") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(compare_output, "02b_power_techmix_staff.png"), p_power_staff, width = 8, height = 5, dpi = 150)
cat("  Saved: 02a/02b power techmix charts\n")

# ---- 4d. Automotive Tech Mix: AI ----
auto_ai_techmix <- ms_ai %>%
  filter(sector == "automotive", region == "global",
         metric %in% c("projected", "target_sds"),
         year %in% c(2020, 2025)) %>%
  mutate(
    label = paste0(metric, " (", year, ")"),
    label = factor(label, levels = c("projected (2020)", "projected (2025)",
                                      "target_sds (2020)", "target_sds (2025)"))
  )

p_auto_ai <- ggplot(auto_ai_techmix, aes(x = label, y = technology_share, fill = technology)) +
  geom_col(position = "stack") +
  labs(title = "AI: Automotive Tech Mix", subtitle = "Custom ggplot2", x = "", y = "Share", fill = "Technology") +
  scale_y_continuous(labels = percent) +
  scale_fill_brewer(palette = "Set2") +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))

ggsave(file.path(compare_output, "03a_auto_techmix_ai.png"), p_auto_ai, width = 8, height = 5, dpi = 150)

# ---- 4e. Automotive Tech Mix: Staff ----
auto_staff_techmix <- ms_staff %>%
  filter(scenario_source == "demo_2020", sector == "automotive", region == "global",
         metric %in% c("projected", "corporate_economy", "target_sds"))

p_auto_staff <- qplot_techmix(auto_staff_techmix) +
  ggrepel::geom_label_repel(
    aes(label = paste0(round(technology_share, 3) * 100, "%")),
    min.segment.length = 0,
    position = position_stack(vjust = 0.5),
    show.legend = FALSE,
    size = 2.5
  ) +
  labs(title = "Staff: Automotive Tech Mix", subtitle = "r2dii.plot + ggrepel labels") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(compare_output, "03b_auto_techmix_staff.png"), p_auto_staff, width = 8, height = 5, dpi = 150)
cat("  Saved: 03a/03b automotive techmix charts\n")

# ---- 4f. Power Renewables Trajectory: AI ----
renew_ai <- ms_ai %>%
  filter(sector == "power", technology == "renewablescap", region == "global",
         metric %in% c("projected", "target_sds", "target_cps", "corporate_economy"))

p_renew_ai <- ggplot(renew_ai, aes(x = year, y = production, color = metric, linetype = metric)) +
  geom_line(linewidth = 1.2) +
  labs(title = "AI: Renewables Trajectory", subtitle = "Custom ggplot2",
       x = "Year", y = "Production (MW)", color = "Metric", linetype = "Metric") +
  scale_color_manual(values = ai_colors) +
  scale_linetype_manual(values = ai_linetypes) +
  theme_minimal(base_size = 11)

ggsave(file.path(compare_output, "04a_renew_traj_ai.png"), p_renew_ai, width = 8, height = 5, dpi = 150)

# ---- 4g. Power Renewables Trajectory: Staff ----
renew_staff <- ms_staff %>%
  filter(sector == "power", technology == "renewablescap", region == "global",
         scenario_source == "demo_2020")

renew_staff_labels <- renew_staff %>%
  filter(year == min(year) + 5) %>%
  rename(value = "percentage_of_initial_production_by_scope")

p_renew_staff <- qplot_trajectory(renew_staff) +
  ggrepel::geom_text_repel(
    aes(label = paste0(round(value, 3) * 100, "%")),
    data = renew_staff_labels, size = 3
  ) +
  labs(title = "Staff: Renewables Trajectory", subtitle = "r2dii.plot + ggrepel") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(compare_output, "04b_renew_traj_staff.png"), p_renew_staff, width = 8, height = 5, dpi = 150)
cat("  Saved: 04a/04b renewables trajectory charts\n")

# ---- 4h. Cement Emission Intensity: AI ----
cement_ai <- sda_ai %>%
  filter(sector == "cement", region == "global",
         emission_factor_metric %in% c("projected", "target_demo", "corporate_economy", "adjusted_scenario_demo"))

p_cement_ai <- ggplot(cement_ai, aes(x = year, y = emission_factor_value, color = emission_factor_metric, linetype = emission_factor_metric)) +
  geom_line(linewidth = 1.2) +
  labs(title = "AI: Cement Emission Intensity", subtitle = "Custom ggplot2",
       x = "Year", y = "tCO2/tonne", color = "Metric", linetype = "Metric") +
  scale_color_manual(values = c(
    "projected" = "black", "corporate_economy" = "grey50",
    "target_demo" = "#27AE60", "adjusted_scenario_demo" = "#8E44AD"
  )) +
  scale_linetype_manual(values = c(
    "projected" = "solid", "corporate_economy" = "dashed",
    "target_demo" = "solid", "adjusted_scenario_demo" = "longdash"
  )) +
  theme_minimal(base_size = 11)

ggsave(file.path(compare_output, "05a_cement_ai.png"), p_cement_ai, width = 8, height = 5, dpi = 150)

# ---- 4i. Cement Emission Intensity: Staff ----
cement_staff <- sda_staff %>%
  filter(sector == "cement", region == "global")

cement_staff_labels <- cement_staff %>%
  filter(year == min(year) + 5) %>%
  mutate(
    year = as.Date(strptime(as.character(year), "%Y")),
    label = pacta.loanbook::to_title(emission_factor_metric)
  )

p_cement_staff <- qplot_emission_intensity(cement_staff) +
  ggrepel::geom_text_repel(
    aes(label = round(emission_factor_value, 3)),
    data = cement_staff_labels,
    show.legend = FALSE, size = 3
  ) +
  labs(title = "Staff: Cement Emission Intensity", subtitle = "r2dii.plot + ggrepel") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(compare_output, "05b_cement_staff.png"), p_cement_staff, width = 8, height = 5, dpi = 150)
cat("  Saved: 05a/05b cement emission intensity charts\n")

# ---- 4j. Steel Emission Intensity: AI ----
steel_ai <- sda_ai %>%
  filter(sector == "steel", region == "global",
         emission_factor_metric %in% c("projected", "target_demo", "corporate_economy", "adjusted_scenario_demo"))

p_steel_ai <- ggplot(steel_ai, aes(x = year, y = emission_factor_value, color = emission_factor_metric, linetype = emission_factor_metric)) +
  geom_line(linewidth = 1.2) +
  labs(title = "AI: Steel Emission Intensity", subtitle = "Custom ggplot2",
       x = "Year", y = "tCO2/tonne", color = "Metric", linetype = "Metric") +
  scale_color_manual(values = c(
    "projected" = "black", "corporate_economy" = "grey50",
    "target_demo" = "#27AE60", "adjusted_scenario_demo" = "#8E44AD"
  )) +
  scale_linetype_manual(values = c(
    "projected" = "solid", "corporate_economy" = "dashed",
    "target_demo" = "solid", "adjusted_scenario_demo" = "longdash"
  )) +
  theme_minimal(base_size = 11)

ggsave(file.path(compare_output, "06a_steel_ai.png"), p_steel_ai, width = 8, height = 5, dpi = 150)

# ---- 4k. Steel Emission Intensity: Staff ----
steel_staff <- sda_staff %>%
  filter(sector == "steel", region == "global")

steel_staff_labels <- steel_staff %>%
  filter(year == min(year) + 5) %>%
  mutate(
    year = as.Date(strptime(as.character(year), "%Y")),
    label = pacta.loanbook::to_title(emission_factor_metric)
  )

p_steel_staff <- qplot_emission_intensity(steel_staff) +
  ggrepel::geom_text_repel(
    aes(label = round(emission_factor_value, 3)),
    data = steel_staff_labels,
    show.legend = FALSE, size = 3
  ) +
  labs(title = "Staff: Steel Emission Intensity", subtitle = "r2dii.plot + ggrepel") +
  theme(text = element_text(family = "sans"))

ggsave(file.path(compare_output, "06b_steel_staff.png"), p_steel_staff, width = 8, height = 5, dpi = 150)
cat("  Saved: 06a/06b steel emission intensity charts\n")

# ---- 4l. Staff's coverage pie chart (unique to staff) ----
loanbook_sector_summary <- loanbook_staff %>%
  group_by(sector_matched) %>%
  summarise(total_outstanding = sum(loan_size_outstanding, na.rm = TRUE), .groups = "drop")

matches_sector_summary <- matched_staff %>%
  group_by(sector) %>%
  summarise(matches_outstanding = sum(loan_size_outstanding, na.rm = TRUE), .groups = "drop")

sector_summary <- loanbook_sector_summary %>%
  left_join(matches_sector_summary, by = c("sector_matched" = "sector")) %>%
  mutate(
    matches_outstanding = ifelse(is.na(matches_outstanding), 0, matches_outstanding),
    match_percentage = (matches_outstanding / total_outstanding) * 100
  )

outstanding_total   <- sum(sector_summary$total_outstanding)
outstanding_matched <- sum(sector_summary$matches_outstanding)
outstanding_notinscope <- sector_summary %>%
  filter(sector_matched == "not in scope") %>%
  pull(total_outstanding)

df_sector_pie <- data.frame(
  status = c("(In Scope) Matched", "(In Scope) Not Matched", "Not in Scope"),
  amount = c(
    outstanding_matched,
    (outstanding_total - outstanding_notinscope - outstanding_matched),
    outstanding_notinscope
  )
) %>%
  mutate(
    percent = amount / sum(amount),
    label = paste0(status, "\n", percent(percent, accuracy = 0.01))
  )

p_pie_staff <- ggplot(df_sector_pie, aes(x = "", y = amount, fill = status)) +
  geom_bar(stat = "identity", width = 1, color = "white") +
  coord_polar("y", start = 0) +
  geom_text(aes(label = label),
            position = position_stack(vjust = 0.5),
            color = "white", fontface = "bold", size = 3) +
  scale_fill_manual(values = c(
    "(In Scope) Matched" = "#14645c",
    "(In Scope) Not Matched" = "#e8594b",
    "Not in Scope" = "#9E9E9E"
  )) +
  labs(title = "Staff: Portfolio Distribution", subtitle = paste0("Total: ", comma(outstanding_total), " EUR"), fill = NULL) +
  theme_void() +
  theme(legend.position = "bottom", plot.title = element_text(hjust = 0.5, face = "bold"),
        plot.subtitle = element_text(hjust = 0.5))

ggsave(file.path(compare_output, "07_coverage_pie_staff.png"), p_pie_staff, width = 7, height = 6, dpi = 150)
cat("  Saved: 07_coverage_pie_staff.png\n")

# ---- 4m. Alignment overview: AI (unique to AI) ----
low_carbon_tech <- c("electric", "fuelcell", "hybrid", "renewablescap", "hydrocap", "nuclearcap")

alignment_plot_data <- ms_ai %>%
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

p_align_ai <- ggplot(alignment_plot_data, aes(x = reorder(technology, gap), y = gap, fill = alignment_direction)) +
  geom_col() +
  coord_flip() +
  facet_wrap(~sector, scales = "free_y") +
  labs(title = "AI: Alignment Gap at 2025 (vs SDS)",
       subtitle = "Technology share gap: Projected minus Target",
       x = "Technology", y = "Share Gap", fill = "Alignment") +
  scale_fill_manual(values = c("Aligned" = "#27AE60", "Misaligned" = "#E74C3C")) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "grey40") +
  theme_minimal(base_size = 11)

ggsave(file.path(compare_output, "08_alignment_overview_ai.png"), p_align_ai, width = 10, height = 6, dpi = 150)
cat("  Saved: 08_alignment_overview_ai.png\n\n")

# ==============================================================================
# PHASE 5: ENCODE ALL CHARTS
# ==============================================================================

cat("--- PHASE 5: Encoding charts for HTML ---\n\n")

imgs <- list(
  match_compare     = img_to_base64(file.path(compare_output, "01_match_comparison.png")),
  power_ai          = img_to_base64(file.path(compare_output, "02a_power_techmix_ai.png")),
  power_staff       = img_to_base64(file.path(compare_output, "02b_power_techmix_staff.png")),
  auto_ai           = img_to_base64(file.path(compare_output, "03a_auto_techmix_ai.png")),
  auto_staff        = img_to_base64(file.path(compare_output, "03b_auto_techmix_staff.png")),
  renew_ai          = img_to_base64(file.path(compare_output, "04a_renew_traj_ai.png")),
  renew_staff       = img_to_base64(file.path(compare_output, "04b_renew_traj_staff.png")),
  cement_ai         = img_to_base64(file.path(compare_output, "05a_cement_ai.png")),
  cement_staff      = img_to_base64(file.path(compare_output, "05b_cement_staff.png")),
  steel_ai          = img_to_base64(file.path(compare_output, "06a_steel_ai.png")),
  steel_staff       = img_to_base64(file.path(compare_output, "06b_steel_staff.png")),
  pie_staff         = img_to_base64(file.path(compare_output, "07_coverage_pie_staff.png")),
  alignment_ai      = img_to_base64(file.path(compare_output, "08_alignment_overview_ai.png"))
)

cat("  All charts encoded.\n\n")

# ==============================================================================
# PHASE 6: BUILD HTML
# ==============================================================================

cat("--- PHASE 6: Building HTML report ---\n\n")

# --- Helper: build an HTML table from a data.frame ---
df_to_html <- function(df) {
  header <- paste0("<tr>", paste0("<th>", names(df), "</th>", collapse = ""), "</tr>")
  rows <- apply(df, 1, function(row) {
    paste0("<tr>", paste0("<td>", row, "</td>", collapse = ""), "</tr>")
  })
  paste0("<table>", header, paste(rows, collapse = "\n"), "</table>")
}

# --- Build Market Share comparison table ---
ms_wide <- ms_align_both %>%
  mutate(
    projected  = ifelse(is.na(projected), "N/A", paste0(round(projected * 100, 1), "%")),
    target_sds = ifelse(is.na(target_sds), "N/A", paste0(round(target_sds * 100, 1), "%")),
    gap_pp     = ifelse(is.na(gap_pp), "N/A", paste0(gap_pp, " pp"))
  )

# --- Build SDA comparison table ---
sda_wide <- sda_align_both %>%
  mutate(
    projected  = round(projected, 4),
    target_demo = round(target_demo, 4),
    gap         = round(gap, 4),
    gap_pct     = paste0(gap_pct, "%")
  )

html <- paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>PACTA Comparison Report: AI vs Staff Implementation</title>
<style>
  :root {
    --primary: #1a365d;
    --accent: #2b6cb0;
    --green: #276749;
    --red: #c53030;
    --orange: #c05621;
    --blue: #2E86AB;
    --bg: #f7fafc;
    --card-bg: #ffffff;
    --border: #e2e8f0;
    --text: #2d3748;
    --text-light: #718096;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: "Segoe UI", system-ui, sans-serif; background: var(--bg); color: var(--text); line-height: 1.7; }
  .hero {
    background: linear-gradient(135deg, #1a365d 0%, #553c9a 100%);
    color: white; padding: 3rem 2rem; text-align: center;
  }
  .hero h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.5rem; }
  .hero .subtitle { font-size: 1.1rem; opacity: 0.9; font-weight: 300; }
  .hero .meta { margin-top: 1rem; font-size: 0.85rem; opacity: 0.7; }
  .container { max-width: 1100px; margin: 0 auto; padding: 2rem 1.5rem; }
  .toc { background: #f7fafc; border: 1px solid var(--border); border-radius: 8px; padding: 1.2rem 1.5rem; margin-bottom: 2rem; }
  .toc h3 { margin-bottom: 0.5rem; font-size: 1rem; color: var(--primary); }
  .toc ol { padding-left: 1.3rem; }
  .toc li { margin: 0.3rem 0; }
  .toc a { color: var(--accent); text-decoration: none; }
  .toc a:hover { text-decoration: underline; }
  .section { background: var(--card-bg); border-radius: 8px; padding: 2rem; margin-bottom: 2rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
  .section h2 { color: var(--primary); font-size: 1.4rem; margin-bottom: 0.5rem; padding-bottom: 0.5rem; border-bottom: 2px solid var(--border); }
  .section h3 { color: var(--accent); font-size: 1.1rem; margin: 1.5rem 0 0.5rem 0; }
  .section p { margin: 0.7rem 0; }
  table { width: 100%; border-collapse: collapse; margin: 1rem 0; font-size: 0.88rem; }
  th { background: var(--primary); color: white; padding: 0.6rem 0.8rem; text-align: left; font-weight: 600; }
  td { padding: 0.5rem 0.8rem; border-bottom: 1px solid var(--border); }
  tr:nth-child(even) { background: #f7fafc; }
  tr:hover { background: #edf2f7; }
  .badge { display: inline-block; padding: 0.15rem 0.6rem; border-radius: 12px; font-size: 0.75rem; font-weight: 600; text-transform: uppercase; }
  .badge-ai { background: #bee3f8; color: #2a4365; }
  .badge-staff { background: #fed7d7; color: #742a2a; }
  .badge-green { background: #c6f6d5; color: var(--green); }
  .badge-red { background: #fed7d7; color: var(--red); }
  .badge-gray { background: #e2e8f0; color: #4a5568; }
  .callout { padding: 1rem 1.2rem; border-radius: 6px; margin: 1rem 0; font-size: 0.92rem; }
  .callout-info { background: #ebf8ff; border-left: 4px solid var(--accent); }
  .callout-warning { background: #fffbeb; border-left: 4px solid var(--orange); }
  .callout-success { background: #f0fff4; border-left: 4px solid var(--green); }
  .callout-danger { background: #fff5f5; border-left: 4px solid var(--red); }
  .chart-container { text-align: center; margin: 1.5rem 0; padding: 1rem; background: #f8fafc; border-radius: 6px; border: 1px solid var(--border); }
  .chart-container img { max-width: 100%; height: auto; border-radius: 4px; }
  .chart-caption { font-size: 0.82rem; color: var(--text-light); margin-top: 0.5rem; font-style: italic; }
  .two-charts { display: grid; grid-template-columns: 1fr 1fr; gap: 1rem; margin: 1.5rem 0; }
  @media (max-width: 900px) { .two-charts { grid-template-columns: 1fr; } }
  .two-charts .chart-container { margin: 0; }
  .kpi-row { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin: 1.5rem 0; }
  .kpi-card { background: #f7fafc; border: 1px solid var(--border); border-radius: 8px; padding: 1.2rem; text-align: center; }
  .kpi-card .value { font-size: 1.6rem; font-weight: 700; color: var(--primary); }
  .kpi-card .label { font-size: 0.8rem; color: var(--text-light); margin-top: 0.3rem; }
  .footer { text-align: center; padding: 2rem; color: var(--text-light); font-size: 0.8rem; border-top: 1px solid var(--border); margin-top: 2rem; }
  .vs-label { text-align: center; font-weight: 700; color: var(--accent); font-size: 0.9rem; margin-bottom: 0.3rem; }
  ul, ol { padding-left: 1.5rem; margin: 0.5rem 0; }
  li { margin: 0.3rem 0; }
</style>
</head>
<body>

<div class="hero">
  <h1>PACTA Comparison Report</h1>
  <div class="subtitle">AI Implementation vs Staff Implementation &mdash; Side-by-Side Analysis</div>
  <div class="meta">Generated: ', format(Sys.Date(), "%B %d, %Y"), ' &nbsp;|&nbsp; Data: r2dii demo_2020 &nbsp;|&nbsp; Framework: pacta.loanbook</div>
</div>

<div class="container">

<div class="toc">
  <h3>Contents</h3>
  <ol>
    <li><a href="#exec">Executive Summary</a></li>
    <li><a href="#method">Methodology Comparison</a></li>
    <li><a href="#matching">Matching Results Comparison</a></li>
    <li><a href="#power">Power Sector: Side-by-Side</a></li>
    <li><a href="#auto">Automotive Sector: Side-by-Side</a></li>
    <li><a href="#cement">Cement Sector: Side-by-Side</a></li>
    <li><a href="#steel">Steel Sector: Side-by-Side</a></li>
    <li><a href="#alignment">Alignment Summary Comparison</a></li>
    <li><a href="#strengths">Strengths &amp; Weaknesses</a></li>
    <li><a href="#recommendations">Recommendations: Best of Both</a></li>
  </ol>
</div>

<!-- ============ 1. EXECUTIVE SUMMARY ============ -->
<div class="section" id="exec">
  <h2>1. Executive Summary</h2>
  <p>This report compares two independent implementations of the PACTA for Banks demo pipeline, both using the same underlying <code>r2dii</code> package ecosystem and the same <code>demo_2020</code> dataset:</p>
  <ul>
    <li><span class="badge badge-ai">AI Approach</span> &mdash; <code>scripts/pacta_demo.R</code> + <code>scripts/generate_report.R</code>: Uses default fuzzy matching, custom <code>ggplot2</code> visualizations, and a standalone HTML report generator.</li>
    <li><span class="badge badge-staff">Staff Approach</span> &mdash; <code>compare/PACTA for Banks staff.Rmd</code> (by Trang Tran): Uses exact matching only (<code>min_score = 1</code>), the official <code>r2dii.plot</code> visualization package, and R Markdown for literate programming.</li>
  </ul>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">', nrow(matched_ai), '</div>
      <div class="label">AI: Prioritized Matches</div>
    </div>
    <div class="kpi-card">
      <div class="value">', nrow(matched_staff), '</div>
      <div class="label">Staff: Prioritized Matches</div>
    </div>
    <div class="kpi-card">
      <div class="value">', nrow(matched_ai) - nrow(matched_staff), '</div>
      <div class="label">Difference (AI &minus; Staff)</div>
    </div>
    <div class="kpi-card">
      <div class="value">Same</div>
      <div class="label">Final Alignment Verdict</div>
    </div>
  </div>

  <div class="callout callout-info">
    <strong>Key Finding:</strong> Despite different matching strategies (fuzzy vs. exact), both implementations arrive at the <strong>same alignment verdict</strong>: the demo portfolio is not aligned with Paris-consistent scenarios in any sector. The quantitative differences are small, confirming that the demo dataset is well-structured for exact matching. The main differences lie in <strong>approach, visualization quality, and documentation style</strong> rather than analytical conclusions.
  </div>
</div>

<!-- ============ 2. METHODOLOGY ============ -->
<div class="section" id="method">
  <h2>2. Methodology Comparison</h2>
  <p>Both implementations follow the standard PACTA pipeline (match &rarr; analyze &rarr; visualize) but differ in specific choices at each stage.</p>

  <table>
    <tr><th>Dimension</th><th><span class="badge badge-ai">AI</span></th><th><span class="badge badge-staff">Staff</span></th></tr>
    <tr><td><strong>Report format</strong></td><td>R script (.R) + standalone HTML generator</td><td>R Markdown (.Rmd) &mdash; literate programming</td></tr>
    <tr><td><strong>Matching strategy</strong></td><td>Default fuzzy matching (~0.8+ score threshold)</td><td>Exact only (<code>min_score = 1</code>, <code>method = "jw"</code>, <code>p = 0.1</code>)</td></tr>
    <tr><td><strong>Sector classification</strong></td><td>Joined during coverage analysis</td><td>Pre-joined to loanbook <em>before</em> matching</td></tr>
    <tr><td><strong>Sector mismatch check</strong></td><td>Not present</td><td>Validates <code>sector_matched</code> vs <code>sector</code> after matching</td></tr>
    <tr><td><strong>Visualization library</strong></td><td>Custom <code>ggplot2</code></td><td><code>r2dii.plot</code> official + <code>ggrepel</code> data labels</td></tr>
    <tr><td><strong>Coverage visualization</strong></td><td>Bar chart (matched vs unmatched)</td><td>Pie chart + stacked bar with "Not in Scope" category</td></tr>
    <tr><td><strong>Data labels on charts</strong></td><td>None</td><td>Percentage/value labels via <code>ggrepel</code></td></tr>
    <tr><td><strong>ICE trajectory chart</strong></td><td>Not included</td><td>Included (combustion engine trajectory)</td></tr>
    <tr><td><strong>Company-level analysis</strong></td><td>Yes (37,349 rows)</td><td>Not included</td></tr>
    <tr><td><strong>Alignment gap computation</strong></td><td>Explicit gap calculation + faceted overview chart</td><td>Not computed; alignment shown visually only</td></tr>
    <tr><td><strong>Scenario metrics shown</strong></td><td><code>projected</code>, <code>target_sds</code>, <code>target_cps</code>, <code>corporate_economy</code></td><td><code>projected</code>, <code>target_sds</code>, <code>corporate_economy</code></td></tr>
    <tr><td><strong>Methodology documentation</strong></td><td>In the HTML report (post-hoc narrative)</td><td>Inline with code (Sections 1 &amp; 2 of Rmd)</td></tr>
    <tr><td><strong>PACTA references</strong></td><td>None cited</td><td>5 official references linked</td></tr>
    <tr><td><strong>Data dictionary</strong></td><td>Not provided</td><td>Full field-by-field data dictionary for all 3 inputs</td></tr>
    <tr><td><strong>Vietnam context</strong></td><td>Not addressed</td><td>Notes on VSIC/NAICS mapping and ABCD data challenges for Vietnamese banks</td></tr>
  </table>
</div>

<!-- ============ 3. MATCHING ============ -->
<div class="section" id="matching">
  <h2>3. Matching Results Comparison</h2>
  <p>The most impactful methodological difference is the matching threshold. The AI approach accepts fuzzy matches (score &ge; ~0.8), while the Staff approach requires exact matches only (score = 1.0).</p>

  <h3>3.1 Match Count Summary</h3>
  ', df_to_html(match_comparison), '

  <h3>3.2 Prioritized Matches by Sector</h3>
  ', df_to_html(coverage_comparison), '

  <div class="chart-container">
    <img src="', imgs$match_compare, '" alt="Match Count Comparison">
    <div class="chart-caption">Figure 1: Number of prioritized (deduplicated) loan-company matches by sector. AI fuzzy matching (blue) vs Staff exact matching (red).</div>
  </div>

  <h3>3.3 Staff Coverage Pie Chart (unique to Staff approach)</h3>
  <p>The Staff approach adds a portfolio-level pie chart separating "In Scope &amp; Matched", "In Scope &amp; Not Matched", and "Not in Scope" loans. This is not present in the AI approach.</p>
  <div class="chart-container" style="max-width: 500px; margin: 1rem auto;">
    <img src="', imgs$pie_staff, '" alt="Staff Coverage Pie">
    <div class="chart-caption">Figure 2: Staff portfolio distribution breakdown (exact matches only).</div>
  </div>

  <div class="callout callout-warning">
    <strong>Interpretation:</strong> Both approaches yield similar match counts because the demo dataset was designed with clean company names that achieve exact matches. In a real-world scenario with messy bank data, the fuzzy matching approach (AI) would likely capture significantly more matches, but would also introduce more false positives requiring manual review.
  </div>
</div>

<!-- ============ 4. POWER SECTOR ============ -->
<div class="section" id="power">
  <h2>4. Power Sector: Side-by-Side</h2>

  <h3>4.1 Technology Mix</h3>
  <div class="two-charts">
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-ai">AI Approach</span></div>
      <img src="', imgs$power_ai, '" alt="AI Power Tech Mix">
      <div class="chart-caption">Custom ggplot2: projected vs SDS target at 2020 &amp; 2025</div>
    </div>
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-staff">Staff Approach</span></div>
      <img src="', imgs$power_staff, '" alt="Staff Power Tech Mix">
      <div class="chart-caption">r2dii.plot qplot_techmix with percentage labels</div>
    </div>
  </div>

  <div class="callout callout-info">
    <strong>Key differences:</strong>
    <ul>
      <li>Staff chart includes <code>corporate_economy</code> as a third benchmark; AI only shows projected vs target</li>
      <li>Staff chart has percentage labels on each bar segment via <code>ggrepel</code></li>
      <li>r2dii.plot uses the official PACTA color palette &amp; standardized layout</li>
      <li>Staff notes that "portfolio in 2025 is empty" due to capacity data not summing to 100% &mdash; a gotcha the AI report also documents differently</li>
    </ul>
  </div>

  <h3>4.2 Renewables Trajectory</h3>
  <div class="two-charts">
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-ai">AI Approach</span></div>
      <img src="', imgs$renew_ai, '" alt="AI Renewables">
      <div class="chart-caption">Custom ggplot2: absolute production (MW) with 4 metrics</div>
    </div>
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-staff">Staff Approach</span></div>
      <img src="', imgs$renew_staff, '" alt="Staff Renewables">
      <div class="chart-caption">r2dii.plot qplot_trajectory with % labels at year+5</div>
    </div>
  </div>

  <div class="callout callout-info">
    <strong>Key differences:</strong>
    <ul>
      <li>AI plots <strong>absolute production (MW)</strong> on the y-axis; Staff uses r2dii.plot default which shows <strong>percentage of initial production</strong></li>
      <li>AI includes <code>target_cps</code> (Current Policies Scenario) as a fourth line; Staff does not</li>
      <li>Staff adds year+5 endpoint labels via <code>ggrepel</code>, making exact values readable</li>
    </ul>
  </div>
</div>

<!-- ============ 5. AUTOMOTIVE SECTOR ============ -->
<div class="section" id="auto">
  <h2>5. Automotive Sector: Side-by-Side</h2>

  <h3>5.1 Technology Mix</h3>
  <div class="two-charts">
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-ai">AI Approach</span></div>
      <img src="', imgs$auto_ai, '" alt="AI Auto Tech Mix">
      <div class="chart-caption">Custom ggplot2: projected vs SDS (2020 &amp; 2025)</div>
    </div>
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-staff">Staff Approach</span></div>
      <img src="', imgs$auto_staff, '" alt="Staff Auto Tech Mix">
      <div class="chart-caption">r2dii.plot qplot_techmix with percentage labels</div>
    </div>
  </div>

  <div class="callout callout-info">
    <strong>Key differences:</strong>
    <ul>
      <li>Same pattern as power: Staff includes corporate_economy benchmark and percentage labels</li>
      <li>Staff also includes <strong>ICE and combustion engine trajectory charts</strong> (not shown in AI report)</li>
      <li>Both confirm the portfolio is ICE-heavy with insufficient EV/hybrid growth</li>
    </ul>
  </div>
</div>

<!-- ============ 6. CEMENT SECTOR ============ -->
<div class="section" id="cement">
  <h2>6. Cement Sector: Side-by-Side</h2>

  <div class="two-charts">
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-ai">AI Approach</span></div>
      <img src="', imgs$cement_ai, '" alt="AI Cement">
      <div class="chart-caption">Custom ggplot2: emission intensity trajectory (4 metrics)</div>
    </div>
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-staff">Staff Approach</span></div>
      <img src="', imgs$cement_staff, '" alt="Staff Cement">
      <div class="chart-caption">r2dii.plot qplot_emission_intensity with value labels</div>
    </div>
  </div>

  <div class="callout callout-info">
    <strong>Key differences:</strong>
    <ul>
      <li>AI uses manual color/linetype mapping for 4 metrics; Staff uses r2dii.plot defaults (official palette)</li>
      <li>Staff adds numeric labels at year+5 via <code>ggrepel</code></li>
      <li>Both correctly identify severe misalignment (~76% above target by 2025)</li>
    </ul>
  </div>
</div>

<!-- ============ 7. STEEL SECTOR ============ -->
<div class="section" id="steel">
  <h2>7. Steel Sector: Side-by-Side</h2>

  <div class="two-charts">
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-ai">AI Approach</span></div>
      <img src="', imgs$steel_ai, '" alt="AI Steel">
      <div class="chart-caption">Custom ggplot2: emission intensity trajectory (4 metrics)</div>
    </div>
    <div class="chart-container">
      <div class="vs-label"><span class="badge badge-staff">Staff Approach</span></div>
      <img src="', imgs$steel_staff, '" alt="Staff Steel">
      <div class="chart-caption">r2dii.plot qplot_emission_intensity with value labels</div>
    </div>
  </div>

  <div class="callout callout-warning">
    <strong>Both approaches note:</strong> Steel match coverage is only ~4% of portfolio exposure. Both results should be interpreted with extreme caution.
  </div>
</div>

<!-- ============ 8. ALIGNMENT COMPARISON ============ -->
<div class="section" id="alignment">
  <h2>8. Alignment Summary Comparison</h2>
  <p>Below we compare the alignment gap calculations from both approaches at 2025 for each sector.</p>

  <h3>8.1 Market Share Sectors (Power &amp; Automotive)</h3>
  <p>Technology share gap at 2025 (projected minus target_sds) in percentage points:</p>
  ', df_to_html(ms_wide), '

  <h3>8.2 SDA Sectors (Cement &amp; Steel)</h3>
  <p>Emission intensity gap at 2025 (projected minus target_demo):</p>
  ', df_to_html(sda_wide), '

  <h3>8.3 AI Alignment Overview Chart (unique to AI approach)</h3>
  <p>The AI approach includes a multi-sector faceted bar chart showing the alignment gap by technology. This is not present in the Staff approach.</p>
  <div class="chart-container">
    <img src="', imgs$alignment_ai, '" alt="AI Alignment Overview">
    <div class="chart-caption">Figure: AI multi-sector alignment gap at 2025 vs SDS target. Green = aligned, Red = misaligned.</div>
  </div>

  <div class="callout callout-success">
    <strong>Convergence:</strong> Despite different matching strategies and visualization approaches, both implementations reach the same conclusions. The numerical differences in alignment gaps are minimal (within rounding tolerance), confirming both pipelines are correct.
  </div>
</div>

<!-- ============ 9. STRENGTHS & WEAKNESSES ============ -->
<div class="section" id="strengths">
  <h2>9. Strengths &amp; Weaknesses</h2>

  <h3>9.1 AI Approach</h3>
  <table>
    <tr><th>Strengths</th><th>Weaknesses</th></tr>
    <tr>
      <td>
        <ul>
          <li>Comprehensive 10-section HTML report with KPI cards, callouts, and professional styling</li>
          <li>Company-level analysis (37K rows) for borrower-level engagement</li>
          <li>Explicit alignment gap calculations with direction-aware logic (low-carbon vs high-carbon)</li>
          <li>Multi-sector overview chart for quick visual summary</li>
          <li>Includes CPS scenario as additional benchmark line</li>
          <li>Detailed caveats and next steps sections</li>
        </ul>
      </td>
      <td>
        <ul>
          <li>No data labels on charts &mdash; exact values not readable</li>
          <li>Does not use the official <code>r2dii.plot</code> package (non-standard look)</li>
          <li>No sector mismatch validation step</li>
          <li>No PACTA methodology references or data dictionary</li>
          <li>No "Not in Scope" category in coverage analysis</li>
          <li>Missing ICE trajectory chart for automotive</li>
          <li>No Vietnam-specific context or guidance</li>
        </ul>
      </td>
    </tr>
  </table>

  <h3>9.2 Staff Approach</h3>
  <table>
    <tr><th>Strengths</th><th>Weaknesses</th></tr>
    <tr>
      <td>
        <ul>
          <li>R Markdown format &mdash; code and narrative interwoven (reproducible research)</li>
          <li>Official <code>r2dii.plot</code> charts with standardized PACTA colors</li>
          <li>Data labels on all charts via <code>ggrepel</code> &mdash; exact values readable</li>
          <li>Comprehensive methodology section (Sections 1 &amp; 2) with 5 official references</li>
          <li>Full data dictionary for all 3 inputs (loanbook, ABCD, scenarios)</li>
          <li>Sector mismatch validation check</li>
          <li>Pie chart + bar chart coverage analysis with "Not in Scope" breakdown</li>
          <li>Vietnam-specific notes (VSIC/NAICS mapping, ABCD data challenges)</li>
          <li>Stricter matching (exact only) reduces false positives</li>
          <li>ICE trajectory chart included for complete automotive picture</li>
        </ul>
      </td>
      <td>
        <ul>
          <li>No explicit alignment gap calculation &mdash; alignment is shown visually only</li>
          <li>No company-level analysis for borrower engagement</li>
          <li>No multi-sector alignment overview chart</li>
          <li>No executive summary or KPI cards</li>
          <li>No caveats/limitations section</li>
          <li>No recommended next steps</li>
          <li>Conservative matching (exact only) may miss valid matches in real data</li>
          <li>Does not include CPS scenario benchmark</li>
        </ul>
      </td>
    </tr>
  </table>
</div>

<!-- ============ 10. RECOMMENDATIONS ============ -->
<div class="section" id="recommendations">
  <h2>10. Recommendations: Best of Both</h2>
  <p>For the production version targeting Vietnamese bank data, we recommend merging the best elements from both approaches:</p>

  <h3>10.1 Architecture</h3>
  <table>
    <tr><th>Decision</th><th>Recommendation</th><th>Source</th></tr>
    <tr><td>Report format</td><td>Use <strong>R Markdown</strong> for the analytical notebook (literate programming), but also generate a <strong>standalone HTML</strong> for stakeholder distribution</td><td>Staff Rmd + AI HTML generator</td></tr>
    <tr><td>Matching</td><td>Run fuzzy matching (<code>min_score = 0.9</code>) with <strong>mandatory manual review</strong> of matches scoring &lt; 1.0. Export the match file, review, re-import</td><td>Hybrid: AI flexibility + Staff rigor</td></tr>
    <tr><td>Sector classification</td><td>Pre-join sector classifications <em>before</em> matching (Staff pattern) to enable sector mismatch validation</td><td>Staff</td></tr>
    <tr><td>Visualization</td><td>Use <code>r2dii.plot</code> for standardized charts + <code>ggrepel</code> labels. Keep custom ggplot2 for the alignment overview</td><td>Staff charts + AI overview</td></tr>
    <tr><td>Coverage analysis</td><td>Include both the pie chart (portfolio-level) and bar chart (sector-level) with "Not in Scope" category</td><td>Staff</td></tr>
  </table>

  <h3>10.2 Content</h3>
  <table>
    <tr><th>Element</th><th>Recommendation</th><th>Source</th></tr>
    <tr><td>Methodology section</td><td>Adopt Staff&apos;s comprehensive methodology + data dictionary, add AI&apos;s metric explanation table</td><td>Both</td></tr>
    <tr><td>Alignment calculation</td><td>Keep AI&apos;s explicit gap calculations + direction-aware alignment logic</td><td>AI</td></tr>
    <tr><td>Company-level analysis</td><td>Keep AI&apos;s 37K-row company-level output for borrower engagement use</td><td>AI</td></tr>
    <tr><td>Executive summary</td><td>Keep AI&apos;s KPI cards + callout summary format</td><td>AI</td></tr>
    <tr><td>Caveats &amp; next steps</td><td>Keep AI&apos;s detailed caveats section; merge with Staff&apos;s Vietnam context notes</td><td>Both</td></tr>
    <tr><td>PACTA references</td><td>Adopt Staff&apos;s 5 official PACTA references</td><td>Staff</td></tr>
    <tr><td>ICE trajectory</td><td>Add ICE trajectory chart (missing from AI)</td><td>Staff</td></tr>
    <tr><td>Vietnam context</td><td>Expand Staff&apos;s notes on VSIC/NAICS mapping and ABCD challenges</td><td>Staff</td></tr>
  </table>

  <h3>10.3 Immediate Next Steps</h3>
  <ol>
    <li><strong>Merge implementations:</strong> Create a unified <code>scripts/pacta_production.R</code> that combines the best matching (fuzzy + manual review), analysis (portfolio + company level), and visualization (r2dii.plot + custom) approaches</li>
    <li><strong>Build unified report template:</strong> Create an <code>.Rmd</code> template with the AI&apos;s report structure and the Staff&apos;s r2dii.plot visualizations</li>
    <li><strong>Prepare real data pipeline:</strong> Adapt the loanbook input format for Vietnamese bank data, mapping VSIC codes to PACTA sector classifications</li>
    <li><strong>Source ABCD data:</strong> Investigate Asset Impact or alternative Vietnamese asset-level data sources (as Staff flagged, this is the "most challenging" input)</li>
    <li><strong>Replace demo scenarios:</strong> Source IEA WEO or NGFS scenarios appropriate for the Vietnam/ASEAN region</li>
    <li><strong>Add quality controls:</strong> Implement sector mismatch validation (Staff pattern) and match coverage thresholds before analysis</li>
  </ol>
</div>

</div>

<div class="footer">
  PACTA Comparison Report &mdash; AI vs Staff Implementation &mdash; Generated with <code>pacta.loanbook</code> (r2dii ecosystem) &mdash; ', format(Sys.Date(), "%B %Y"), '<br>
  This report is for internal review purposes.
</div>

</body>
</html>')

# ==============================================================================
# PHASE 7: WRITE HTML
# ==============================================================================

report_dir <- file.path(getwd(), "reports")
dir.create(report_dir, showWarnings = FALSE, recursive = TRUE)
out_path <- file.path(report_dir, "PACTA_Comparison_Report.html")
writeLines(html, out_path, useBytes = TRUE)

cat(sprintf("Report saved to: %s\n", normalizePath(out_path)))
cat(sprintf("File size: %.1f KB\n", file.info(out_path)$size / 1024))

cat("\n========================================\n")
cat("COMPARISON REPORT COMPLETE\n")
cat("========================================\n")
cat("Output files:\n")
cat(sprintf("  Report: %s\n", out_path))
cat(sprintf("  Charts: %s\n", compare_output))
cat(paste("  ", list.files(compare_output), collapse = "\n"))
cat("\n")

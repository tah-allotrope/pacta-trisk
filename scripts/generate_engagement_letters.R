#!/usr/bin/env Rscript
# =============================================================================
# Engagement Letter Generator
# Engagement & Disclosure Output Layer — PHASE-02
# Plan: plans/2026-05-28-engagement-disclosure-output-layer-plan.md
# =============================================================================
# Renders one self-contained, English-primary (Vietnamese key terms inline)
# engagement letter per top-N borrower from the PHASE-01 priority table. Every
# figure is pulled from the borrower's data row — never hardcoded. Letter voice
# and per-sector wording come from an editable external template + prompt CSV,
# so the bank can rebrand without touching this code (research Idea 3).
#
# Inputs:
#   output/engagement/engagement_priority.csv           (PHASE-01 output)
#   templates/engagement/letter_template.html           (token skeleton)
#   templates/engagement/engagement_prompt_templates.csv (per-sector prompts)
# Outputs (git-ignored, see PHASE-05):
#   output/engagement_letters/<slug>/letter.html         (one per borrower)
#   output/engagement_letters/index.html
#   output/engagement_letters/manifest.csv
#
# Usage:
#   Rscript scripts/generate_engagement_letters.R [--top_n 10]
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr)
  library(readr)
}))

source("R/engagement_config.R")

# --- Section 1: Configuration & pre-flight (TASK-02-06) ----------------------

args <- commandArgs(trailingOnly = TRUE)
parse_arg <- function(args, name, default) {
  idx <- which(args == paste0("--", name))
  if (length(idx) > 0 && idx < length(args)) return(as.numeric(args[idx + 1]))
  default
}
top_n <- parse_arg(args, "top_n", 10)

cfg <- load_engagement_config(get_config_arg(args))

base_dir      <- getwd()
priority_file <- file.path(base_dir, cfg$paths$engagement_output_dir, "engagement_priority.csv")
template_file <- file.path(base_dir, "templates", "engagement", "letter_template.html")
prompt_file   <- file.path(base_dir, "templates", "engagement", "engagement_prompt_templates.csv")
output_dir    <- file.path(base_dir, cfg$paths$letters_output_dir)

fail <- function(msg) { cat(sprintf("ERROR: %s\n", msg)); quit(status = 1, save = "no") }

if (!file.exists(priority_file)) {
  fail(sprintf("Missing %s.\n       Run PHASE-01 first: Rscript scripts/engagement_scoring.R",
               priority_file))
}
if (!file.exists(template_file)) fail(sprintf("Missing letter template: %s", template_file))
if (!file.exists(prompt_file))   fail(sprintf("Missing prompt CSV: %s", prompt_file))

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
generated_at <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
letter_date  <- format(Sys.Date(), "%d %B %Y")

cat(sprintf("Engagement Letters — top_n=%d (generated %s)\n", top_n, generated_at))

# --- Section 2: Load inputs --------------------------------------------------

priority <- readr::read_csv(priority_file, show_col_types = FALSE)
prompts  <- readr::read_csv(prompt_file, show_col_types = FALSE)
template <- paste(readLines(template_file, warn = FALSE, encoding = "UTF-8"), collapse = "\n")

n_take <- min(top_n, nrow(priority))
top <- head(priority, n_take)

# --- Section 3: Formatting helpers -------------------------------------------

title_case <- function(s) {
  paste0(toupper(substring(s, 1, 1)), substring(s, 2))
}

# Slug for output folders: ASCII-transliterate, lowercase, hyphenate.
slugify <- function(x) {
  x <- tryCatch(iconv(x, to = "ASCII//TRANSLIT"), error = function(e) x)
  x <- ifelse(is.na(x), "borrower", x)
  x <- tolower(x)
  x <- gsub("[^a-z0-9]+", "-", x)
  x <- gsub("^-+|-+$", "", x)
  x
}

# Alignment gap phrasing depends on the metric family (market share vs SDA).
format_gap <- function(sector, gap, basis) {
  if (is.na(gap)) return("an alignment gap that could not be quantified from the available data")
  if (grepl("SDA", basis, ignore.case = TRUE) || sector %in% c("cement", "steel")) {
    sprintf("a %.1f%% emission-intensity gap above the SDA pathway", gap)
  } else {
    sprintf("a %.1f pp average market-share gap versus the PDP8 pathway", gap)
  }
}

# NPV change is a fraction of baseline value; PD change is an absolute prob. change.
format_npv <- function(x) {
  if (is.na(x)) return("Not assessed — sector not in the TRISK transition-risk pilot")
  sprintf("%+.1f%% of baseline NPV", x * 100)
}
format_pd <- function(x) {
  if (is.na(x)) return("Not assessed — sector not in the TRISK transition-risk pilot")
  sprintf("%+.1f pp (probability of default)", x * 100)
}
format_vnd <- function(x) {
  if (is.na(x)) return("Not available")
  sprintf("%s VND (synthetic units)", formatC(x, format = "d", big.mark = ","))
}

# Single-pass token substitution with a complete map (fixed-string, no regex).
subst <- function(text, map) {
  for (k in names(map)) {
    text <- gsub(paste0("{{", k, "}}"), map[[k]], text, fixed = TRUE)
  }
  text
}

# --- Section 4: Render letters -----------------------------------------------

manifest <- list()
slug_seen <- character(0)

for (i in seq_len(nrow(top))) {
  r <- top[i, ]
  sector <- r$sector

  # A sector with no prompt row must fail the run, not ship a half-built letter.
  prow <- prompts[prompts$sector == sector, ]
  if (nrow(prow) == 0) {
    fail(sprintf("No prompt-template row for sector '%s' (borrower '%s'). Add a row to %s.",
                 sector, r$name_abcd, prompt_file))
  }
  prow <- prow[1, ]

  # Borrower-level token map (scalars). Pre-substitute into prompt prose so the
  # final template pass never encounters a nested {{token}}.
  base_map <- list(
    borrower      = r$name_abcd,
    sector        = title_case(sector),
    date          = letter_date,
    rank          = as.character(i),
    top_n         = as.character(n_take),
    scenario_name = prow$scenario_name,
    alignment_gap = format_gap(sector, r$alignment_gap, r$alignment_basis),
    npv_change    = format_npv(r$npv_change),
    pd_change     = format_pd(r$pd_change),
    exposure_vnd  = format_vnd(r$exposure_vnd),
    trisk_status  = r$trisk_status,
    generated_at  = generated_at
  )

  intro <- subst(prow$intro, base_map)
  actions <- vapply(c(prow$action_1, prow$action_2, prow$action_3),
                    function(a) subst(a, base_map), character(1))
  actions_html <- paste0(
    "<ol class=\"actions\">\n",
    paste0("      <li>", actions, "</li>", collapse = "\n"),
    "\n    </ol>"
  )

  full_map <- c(base_map, list(intro = intro, engagement_actions = actions_html))
  letter <- subst(template, full_map)

  # RISK-02-01: never ship a raw {{token}} to a client-facing letter.
  residual <- regmatches(letter, gregexpr("\\{\\{[^{}]+\\}\\}", letter))[[1]]
  if (length(residual) > 0) {
    fail(sprintf("Unsubstituted token(s) for borrower '%s': %s",
                 r$name_abcd, paste(unique(residual), collapse = ", ")))
  }

  # Unique slug per borrower
  slug <- slugify(r$name_abcd)
  if (slug %in% slug_seen) slug <- paste0(slug, "-", i)
  slug_seen <- c(slug_seen, slug)

  letter_dir <- file.path(output_dir, slug)
  dir.create(letter_dir, showWarnings = FALSE, recursive = TRUE)
  letter_path <- file.path(letter_dir, "letter.html")
  writeLines(letter, letter_path, useBytes = TRUE)

  manifest[[i]] <- tibble::tibble(
    rank = i,
    borrower = r$name_abcd,
    sector = sector,
    composite_score = round(r$composite_score, 4),
    trisk_status = r$trisk_status,
    file = file.path("output", "engagement_letters", slug, "letter.html"),
    generated_at = generated_at
  )
  cat(sprintf("  [%2d] %-32s -> %s\n", i, r$name_abcd, file.path(slug, "letter.html")))
}

manifest_df <- dplyr::bind_rows(manifest)

# --- Section 5: Manifest + index (TASK-02-05) --------------------------------

manifest_path <- file.path(output_dir, "manifest.csv")
readr::write_csv(manifest_df, manifest_path)

esc <- function(s) {
  s <- gsub("&", "&amp;", s, fixed = TRUE)
  s <- gsub("<", "&lt;", s, fixed = TRUE)
  gsub(">", "&gt;", s, fixed = TRUE)
}
rows_html <- vapply(seq_len(nrow(manifest_df)), function(j) {
  m <- manifest_df[j, ]
  sprintf(
    "      <tr><td>%d</td><td><a href=\"%s/letter.html\">%s</a></td><td>%s</td><td>%.4f</td><td>%s</td></tr>",
    m$rank, slugify(m$borrower), esc(m$borrower), esc(title_case(m$sector)),
    m$composite_score, esc(m$trisk_status)
  )
}, character(1))

index_html <- paste0(
  "<!DOCTYPE html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">",
  "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
  "<title>MCB Engagement Letters — Index</title><style>",
  "body{font-family:'Segoe UI',Arial,sans-serif;margin:0;background:#eef1f4;color:#1f2933;}",
  ".wrap{max-width:900px;margin:24px auto;background:#fff;border:1px solid #d7dee5;padding:28px 34px;}",
  ".band{background:#fff4f2;color:#b42318;border:1px solid rgba(180,35,24,0.25);padding:8px 12px;",
  "border-radius:6px;font-size:0.78rem;font-weight:700;text-transform:uppercase;letter-spacing:0.05em;margin-bottom:18px;}",
  "h1{color:#0a5ad6;font-size:1.4rem;margin:0 0 4px;} .sub{color:#5a6b78;font-size:0.9rem;margin:0 0 18px;}",
  "table{width:100%;border-collapse:collapse;font-size:0.9rem;} th,td{padding:8px 10px;border-bottom:1px solid #e7edf2;text-align:left;}",
  "th{color:#5a6b78;text-transform:uppercase;font-size:0.74rem;letter-spacing:0.06em;} a{color:#0a5ad6;}",
  ".foot{margin-top:18px;color:#5a6b78;font-size:0.74rem;}",
  "</style></head><body><div class=\"wrap\">",
  "<div class=\"band\">Synthetic data — illustrative only · Requires human &amp; legal review before any external use</div>",
  sprintf("<h1>%s — Engagement Letters</h1>", cfg$bank_name),
  sprintf("<p class=\"sub\">Top %d borrowers by composite engagement score · generated %s</p>",
          nrow(manifest_df), generated_at),
  "<table><thead><tr><th>#</th><th>Borrower</th><th>Sector</th><th>Composite</th><th>TRISK status</th></tr></thead><tbody>\n",
  paste(rows_html, collapse = "\n"),
  "\n</tbody></table>",
  "<p class=\"foot\">Illustrative — based on synthetic portfolio data (PACTA + TRISK). Not financial advice or a credit decision.</p>",
  "</div></body></html>"
)
index_path <- file.path(output_dir, "index.html")
writeLines(index_html, index_path, useBytes = TRUE)

# --- Summary -----------------------------------------------------------------

cat(sprintf("\n=== Generated %d engagement letters ===\n", nrow(manifest_df)))
cat(sprintf("  Letters:  %s/<slug>/letter.html\n", output_dir))
cat(sprintf("  Index:    %s\n", index_path))
cat(sprintf("  Manifest: %s\n", manifest_path))
cat("  Every letter carries the synthetic-data watermark + human/legal-review disclaimer.\n")

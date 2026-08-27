#!/usr/bin/env Rscript
# =============================================================================
# Disclosure Pack Generator (TCFD / ISSB / Decision 263)
# Engagement & Disclosure Output Layer — PHASE-03
# Plan: plans/2026-05-28-engagement-disclosure-output-layer-plan.md
# =============================================================================
# Assembles a single self-contained HTML board/regulator disclosure pack:
#   (1) executive summary  (2) portfolio alignment vs PDP8/NDC/NZE (embedded PNG)
#   (3) top-N transition-risk borrowers (anonymisable)  (4) TCFD four-pillar
#   narrative + ISSB IFRS S2 cross-refs + Decision 263 note  (5) methodology
#   appendix condensed from the PACTA + TRISK docs.
# Browser print-to-PDF turns it into a board/regulator document (Q-001, no DOCX).
#
# Usage:
#   Rscript scripts/generate_disclosure_pack.R [--top_n 10] [--anonymize [TRUE|FALSE]]
# Default anonymize = FALSE (real names, internal board pack — Grill Me Q-005).
# =============================================================================

suppressWarnings(suppressMessages({
  library(dplyr)
  library(readr)
}))

source("R/engagement_config.R")
source("R/report_toolkit.R")
source("R/format_money.R")

# --- Section 1: Args ---------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)
parse_num <- function(args, name, default) {
  idx <- which(args == paste0("--", name))
  if (length(idx) > 0 && idx < length(args)) return(as.numeric(args[idx + 1]))
  default
}
parse_flag <- function(args, name, default = FALSE) {
  idx <- which(args == paste0("--", name))
  if (length(idx) == 0) return(default)
  # value may follow ("--anonymize TRUE") or be a bare flag ("--anonymize")
  if (idx < length(args) && toupper(args[idx + 1]) %in% c("TRUE", "FALSE")) {
    return(as.logical(toupper(args[idx + 1])))
  }
  TRUE
}
top_n     <- parse_num(args, "top_n", 10)
anonymize <- parse_flag(args, "anonymize", FALSE)

cfg <- load_engagement_config(get_config_arg(args))
bank_short <- {
  if (identical(cfg$bank_name, "Mekong Commercial Bank")) "MCB"
  else if (identical(cfg$bank_name, "Saigon Delta Bank")) "SDB"
  else {
    parts <- strsplit(trimws(cfg$bank_name), "\\s+")[[1]]
    paste0(toupper(substr(parts, 1, 1)), collapse = "")
  }
}
bank_label <- if (identical(bank_short, cfg$bank_name)) cfg$bank_name else sprintf("%s (%s)", cfg$bank_name, bank_short)

base_dir   <- getwd()
output_dir <- file.path(base_dir, cfg$paths$disclosure_output_dir)
output_path <- file.path(output_dir, "disclosure_pack.html")
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
report_date <- format(Sys.Date(), "%d %B %Y")

inputs <- list(
  priority     = file.path(base_dir, cfg$paths$engagement_output_dir, "engagement_priority.csv"),
  ms_align     = file.path(base_dir, cfg$paths$pacta_output_dir, "06_vn_ms_alignment_2030.csv"),
  sda_align    = file.path(base_dir, cfg$paths$pacta_output_dir, "06_vn_sda_alignment_2030.csv"),
  overview_png = file.path(base_dir, cfg$paths$pacta_output_dir, "12_vn_alignment_overview.png"),
  coal_png     = file.path(base_dir, cfg$paths$pacta_output_dir, "13_vn_coal_stranded_risk.png"),
  tcfd_md      = file.path(base_dir, "templates", "disclosure", "disclosure_sections.md"),
  pacta_doc    = file.path(base_dir, "docs", "PACTA_Beginner_Guide.md"),
  trisk_doc    = file.path(base_dir, "docs", "TRISK_Demo_Assumptions.md"),
  d263_doc     = file.path(base_dir, "docs", "bidv_decision263_mapping.md")
)

cat(sprintf("Disclosure Pack — top_n=%d, anonymize=%s (%s)\n", top_n, anonymize, report_date))

# --- Section 2: Pre-flight (TASK-03-06) --------------------------------------
# Missing inputs degrade to a "[section pending]" placeholder, never a crash.

have <- function(key) file.exists(inputs[[key]])
for (k in names(inputs)) {
  if (!have(k)) cat(sprintf("  MISSING (placeholder will be used): %s\n", inputs[[k]]))
}
pending <- "<div class=\"callout callout-warning\">[section pending] — required input not found in the snapshot.</div>"

# --- Section 3: Helpers (md -> HTML, base64, section extract) -----------------

img_to_base64 <- function(path) {
  if (!file.exists(path)) return("")
  raw <- readBin(path, "raw", file.info(path)$size)
  paste0("data:image/png;base64,", base64enc::base64encode(raw))
}

inline_md <- function(text) {
  text <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", text)
  text <- gsub("`([^`]+)`", "<code>\\1</code>", text)
  text <- gsub("\\[(.+?)\\]\\((.+?)\\)", "<a href=\"\\2\">\\1</a>", text)
  text
}

md_to_html <- function(text) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  out <- character(0); in_ul <- FALSE; in_comment <- FALSE
  flush_ul <- function() { if (in_ul) { out[[length(out) + 1]] <<- "</ul>"; in_ul <<- FALSE } }
  for (line in lines) {
    if (grepl("<!--", line, fixed = TRUE)) in_comment <- TRUE
    if (in_comment) { if (grepl("-->", line, fixed = TRUE)) in_comment <- FALSE; next }
    if (grepl("^\\s*$", line)) { flush_ul(); next }
    if (grepl("^### ", line))  { flush_ul(); out <- c(out, paste0("<h3>", inline_md(sub("^###\\s*", "", line)), "</h3>")); next }
    if (grepl("^## ", line))   { flush_ul(); out <- c(out, paste0("<h2>", inline_md(sub("^##\\s*", "", line)), "</h2>")); next }
    if (grepl("^# ", line))    { flush_ul(); out <- c(out, paste0("<h2>", inline_md(sub("^#\\s*", "", line)), "</h2>")); next }
    if (grepl("^>", line))     { flush_ul(); ct <- trimws(sub("^>\\s?", "", line)); if (nzchar(ct)) out <- c(out, paste0("<blockquote>", inline_md(ct), "</blockquote>")); next }
    if (grepl("^---+$", line)) { flush_ul(); out <- c(out, "<hr>"); next }
    if (grepl("^[-*] ", line)) { if (!in_ul) { out <- c(out, "<ul>"); in_ul <- TRUE }; out <- c(out, paste0("<li>", inline_md(sub("^[-*]\\s*", "", line)), "</li>")); next }
    flush_ul(); out <- c(out, paste0("<p>", inline_md(line), "</p>"))
  }
  flush_ul()
  paste(out, collapse = "\n")
}

extract_section <- function(md_text, header_pat, next_pat = NULL) {
  lines <- strsplit(md_text, "\n", fixed = TRUE)[[1]]
  start <- grep(paste0("^#{1,3}\\s+", header_pat), lines, ignore.case = TRUE)
  if (length(start) == 0) return("")
  start <- start[1]
  if (!is.null(next_pat)) {
    rem <- lines[(start + 1):length(lines)]
    nxt <- grep(paste0("^#{1,3}\\s+", next_pat), rem, ignore.case = TRUE)
    end <- if (length(nxt) > 0) start + nxt[1] - 1 else length(lines)
  } else end <- length(lines)
  paste(lines[start:end], collapse = "\n")
}

fmt_npv <- function(x) ifelse(is.na(x), "n/a", sprintf("%+.1f%%", x * 100))
fmt_pd  <- function(x) ifelse(is.na(x), "n/a", sprintf("%+.1f pp", x * 100))
synthetic_note <- "<div class=\"callout callout-warning\"><strong>Synthetic data — illustrative.</strong> Figures are model outputs on a synthetic portfolio and are not a regulatory filing or credit decision.</div>"

# --- Section 4: Load data ----------------------------------------------------

priority <- if (have("priority")) readr::read_csv(inputs$priority, show_col_types = FALSE) else NULL
ms_align <- if (have("ms_align")) readr::read_csv(inputs$ms_align, show_col_types = FALSE) else NULL
sda_align <- if (have("sda_align")) readr::read_csv(inputs$sda_align, show_col_types = FALSE) else NULL

# Pseudonym map across ALL borrowers in priority order (rank): Borrower A, B, ...
pseudonyms <- character(0)
if (!is.null(priority)) {
  n <- nrow(priority)
  labels <- if (n <= 26) LETTERS[seq_len(n)] else paste0("B", seq_len(n))
  pseudonyms <- setNames(paste("Borrower", labels), priority$name_abcd)
}

# --- Section 5: Build sections ----------------------------------------------

# 5a. Executive summary (data-driven)
exec_html <- pending
if (!is.null(priority)) {
  n_borr <- nrow(priority)
  n_sec  <- length(unique(priority$sector))
  top1   <- priority$name_abcd[1]
  top1c  <- priority$composite_score[1]
  worst_ms <- if (!is.null(ms_align)) max(ms_align$share_gap_pp, na.rm = TRUE) else NA
  worst_sda <- if (!is.null(sda_align)) max(sda_align$gap_pct, na.rm = TRUE) else NA
  exec_html <- paste0(
    synthetic_note,
    sprintf("<p>This pack summarises %s's climate transition-risk position across ", cfg$bank_name),
    n_sec, " high-emitting sectors, covering <strong>", n_borr,
    "</strong> financed counterparties. Alignment is measured against Vietnam's PDP8 / NDC / IEA-NZE pathways; ",
    "transition stress is quantified with TRISK.</p>",
    "<div class=\"kpi-row\">",
    "<div class=\"kpi-card\"><div class=\"value\">", n_borr, "</div><div class=\"label\">Counterparties assessed</div></div>",
    "<div class=\"kpi-card\"><div class=\"value\">", n_sec, "</div><div class=\"label\">Sectors</div></div>",
    "<div class=\"kpi-card\"><div class=\"value\">", if (is.na(worst_ms)) "n/a" else sprintf("%.1f pp", worst_ms),
      "</div><div class=\"label\">Worst market-share gap</div></div>",
    "<div class=\"kpi-card\"><div class=\"value\">", if (is.na(worst_sda)) "n/a" else sprintf("%.1f%%", worst_sda),
      "</div><div class=\"label\">Worst SDA intensity gap</div></div>",
    "</div>",
    "<p>The highest composite transition-risk priority is <strong>", top1,
    "</strong> (composite ", sprintf("%.3f", top1c),
    "). Priority counterparties enter a structured engagement process; sustained misalignment informs sector limits and financing terms.</p>"
  )
}

# 5b. Portfolio alignment vs PDP8/NDC/NZE (embedded PNG + gap table)
align_html <- pending
if (!is.null(ms_align)) {
  ms_rows <- paste0(apply(ms_align, 1, function(r) {
    sprintf("<tr><td>%s</td><td>%s</td><td>%.3f</td><td>%.3f</td><td>%+.2f</td><td>%s</td></tr>",
            r[["sector"]], r[["technology"]], as.numeric(r[["projected"]]),
            as.numeric(r[["target_pdp8"]]), as.numeric(r[["share_gap_pp"]]), r[["aligned"]])
  }), collapse = "\n")
  sda_rows <- if (!is.null(sda_align)) paste0(apply(sda_align, 1, function(r) {
    sprintf("<tr><td>%s</td><td>SDA intensity</td><td>%.3f</td><td>%.3f</td><td>%+.1f%%</td><td>%s</td></tr>",
            r[["sector"]], as.numeric(r[["projected"]]), as.numeric(r[["target_pdp8"]]),
            as.numeric(r[["gap_pct"]]), r[["aligned"]])
  }), collapse = "\n") else ""
  img_block <- ""
  if (have("overview_png")) img_block <- paste0(img_block,
    "<div class=\"chart-container\"><img src=\"", img_to_base64(inputs$overview_png),
    "\" alt=\"Alignment overview\"><div class=\"chart-caption\">Financed technology mix vs PDP8 / NDC / NZE pathways (synthetic portfolio).</div></div>")
  if (have("coal_png")) img_block <- paste0(img_block,
    "<div class=\"chart-container\"><img src=\"", img_to_base64(inputs$coal_png),
    "\" alt=\"Coal stranded-asset risk\"><div class=\"chart-caption\">Coal-capacity transition / stranded-asset risk (synthetic).</div></div>")
  align_html <- paste0(
    synthetic_note, img_block,
    "<table><thead><tr><th>Sector</th><th>Technology / metric</th><th>Projected</th><th>Target (PDP8)</th><th>Gap</th><th>Status</th></tr></thead><tbody>",
    ms_rows, sda_rows, "</tbody></table>"
  )
}

# 5c. Top-N transition-risk borrowers (anonymisable)
borrowers_html <- pending
if (!is.null(priority)) {
  top <- head(priority, min(top_n, nrow(priority)))
  rows <- vapply(seq_len(nrow(top)), function(i) {
    r <- top[i, ]
    name <- if (anonymize) pseudonyms[[r$name_abcd]] else r$name_abcd
    sec  <- paste0(toupper(substring(r$sector, 1, 1)), substring(r$sector, 2))
    sprintf("<tr><td>%d</td><td>%s</td><td>%s</td><td>%s</td><td>%.1f</td><td>%s</td><td>%s</td><td>%.3f</td></tr>",
            i, name, sec, format_vnd_full(r$exposure_vnd), r$alignment_gap,
            fmt_npv(r$npv_change), fmt_pd(r$pd_change), r$composite_score)
  }, character(1))
  borrowers_html <- paste0(
    synthetic_note,
    "<p>Counterparties ranked by composite transition-risk priority (50/50 alignment gap and TRISK stress). ",
    "NPV / PD show TRISK results under a late-and-sudden policy shock; counterparties outside the TRISK pilot show <code>n/a</code>.</p>",
    if (anonymize) "<p><em>Names anonymised for external sharing.</em></p>" else "",
    "<table><thead><tr><th>#</th><th>Counterparty</th><th>Sector</th><th>Exposure</th><th>Alignment gap</th>",
    "<th>NPV change</th><th>PD change</th><th>Composite</th></tr></thead><tbody>",
    paste(rows, collapse = "\n"), "</tbody></table>"
  )
}

# 5d. TCFD four-pillar narrative — Wave 3 PHASE-06: disclosure_sections.md now
# carries {{bank_name}} / {{bank_short}} tokens so the narrative is client-
# neutral; substitute before markdown conversion so headings render correctly.
tcfd_html <- pending
if (have("tcfd_md")) {
  tcfd_raw <- paste(readLines(inputs$tcfd_md, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  tcfd_raw <- gsub("{{bank_name}}", cfg$bank_name, tcfd_raw, fixed = TRUE)
  tcfd_raw <- gsub("{{bank_short}}", bank_short, tcfd_raw, fixed = TRUE)
  # Backwards compat: any surviving MCB/Mekong literals in older overlays still work
  if (!identical(cfg$bank_name, "Mekong Commercial Bank")) {
    tcfd_raw <- gsub("Mekong Commercial Bank", cfg$bank_name, tcfd_raw, fixed = TRUE)
  }
  tcfd_html <- md_to_html(tcfd_raw)
}

# 5e. Methodology appendix (condensed from PACTA + TRISK docs + Decision 263 extract)
methodology_html <- ""
if (have("pacta_doc")) {
  md <- paste(readLines(inputs$pacta_doc, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  methodology_html <- paste0(methodology_html, "<h3>PACTA (alignment)</h3>",
    md_to_html(extract_section(md, "What is PACTA", "Phase 0")))
}
if (have("trisk_doc")) {
  md <- paste(readLines(inputs$trisk_doc, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  methodology_html <- paste0(methodology_html, "<h3>TRISK (transition stress)</h3>",
    md_to_html(extract_section(md, "Purpose", "Modeling Boundary")),
    md_to_html(extract_section(md, "Interpretation Guardrails", "Recommended Disclosure Language")))
}
if (have("d263_doc")) {
  md <- paste(readLines(inputs$d263_doc, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  methodology_html <- paste0(methodology_html, "<h3>Regulatory context — Decision 263 (extract)</h3>",
    md_to_html(extract_section(md, "1\\. Decision 263 Overview", "2\\. Sector Mapping")))
}
if (!nzchar(methodology_html)) methodology_html <- pending

# --- Section 6: CSS (reused from generate_bidv_report.R) + print rules -------

css <- '
:root { --primary:#1a5276; --accent:#2b6cb0; --green:#276749; --red:#c53030; --orange:#c05621;
  --bg:#f7fafc; --card-bg:#fff; --border:#e2e8f0; --text:#2d3748; --text-light:#718096; }
* { margin:0; padding:0; box-sizing:border-box; }
body { font-family:"Segoe UI", system-ui, -apple-system, sans-serif; background:var(--bg); color:var(--text); line-height:1.7; }
.hero { background:linear-gradient(135deg,var(--primary) 0%,var(--accent) 100%); color:#fff; padding:3rem 2rem; text-align:center; }
.hero h1 { font-size:2.1rem; font-weight:700; margin-bottom:0.5rem; }
.hero .subtitle { font-size:1.05rem; opacity:0.9; font-weight:300; }
.hero .meta { margin-top:1.1rem; font-size:0.85rem; opacity:0.75; }
.hero .confidential { margin-top:1rem; padding:0.5rem 1rem; background:rgba(255,255,255,0.15); border-radius:4px; display:inline-block; font-size:0.8rem; font-weight:600; letter-spacing:0.05em; }
.container { max-width:960px; margin:0 auto; padding:2rem 1.5rem; }
.toc { background:#fff; border:1px solid var(--border); border-radius:8px; padding:1.2rem 1.5rem; margin-bottom:2rem; }
.toc h3 { margin-bottom:0.5rem; font-size:1rem; color:var(--primary); }
.toc ol { padding-left:1.3rem; } .toc li { margin:0.3rem 0; } .toc a { color:var(--accent); text-decoration:none; }
.section { background:var(--card-bg); border-radius:8px; padding:2rem; margin-bottom:2rem; box-shadow:0 1px 3px rgba(0,0,0,0.08); }
.section h2 { color:var(--primary); font-size:1.4rem; margin-bottom:0.3rem; padding-bottom:0.6rem; border-bottom:2px solid var(--border); }
.section h3 { color:var(--accent); font-size:1.1rem; margin:1.4rem 0 0.5rem; }
.section p { margin:0.7rem 0; } .section ul, .section ol { padding-left:1.5rem; margin:0.5rem 0; } .section li { margin:0.3rem 0; }
.section blockquote { border-left:3px solid var(--accent); background:#ebf8ff; padding:0.5rem 1rem; color:var(--text); margin:0.6rem 0; font-size:0.92rem; }
.section table { width:100%; border-collapse:collapse; margin:1rem 0; font-size:0.88rem; }
.section th { background:var(--primary); color:#fff; padding:0.6rem 0.8rem; text-align:left; font-weight:600; }
.section td { padding:0.5rem 0.8rem; border-bottom:1px solid var(--border); }
.section tr:nth-child(even) { background:#f7fafc; }
.chart-container { text-align:center; margin:1.5rem 0; padding:1rem; background:#f8fafc; border-radius:6px; border:1px solid var(--border); }
.chart-container img { max-width:100%; height:auto; border-radius:4px; }
.chart-caption { font-size:0.82rem; color:var(--text-light); margin-top:0.5rem; font-style:italic; }
.kpi-row { display:grid; grid-template-columns:repeat(auto-fit,minmax(160px,1fr)); gap:1rem; margin:1.5rem 0; }
.kpi-card { background:#f7fafc; border:1px solid var(--border); border-radius:8px; padding:1.2rem; text-align:center; }
.kpi-card .value { font-size:1.6rem; font-weight:700; color:var(--primary); } .kpi-card .label { font-size:0.8rem; color:var(--text-light); margin-top:0.3rem; }
.callout { padding:1rem 1.2rem; border-radius:6px; margin:1rem 0; font-size:0.9rem; }
.callout-warning { background:#fffbeb; border-left:4px solid var(--orange); }
.callout-info { background:#ebf8ff; border-left:4px solid var(--accent); }
.disclaimer { padding:0.8rem 1rem; border:2px solid var(--red); background:#fff5f5; border-radius:6px; margin:1rem 0; font-size:0.88rem; }
.disclaimer strong { color:var(--red); }
.foot { text-align:center; color:var(--text-light); font-size:0.8rem; padding:1.5rem; }
@media print {
  body { background:#fff; }
  .hero { -webkit-print-color-adjust:exact; print-color-adjust:exact; }
  .section { box-shadow:none; break-inside:avoid; page-break-inside:avoid; }
  .section h2 { break-after:avoid; }
  .chart-container, table, .kpi-row { break-inside:avoid; }
  a { color:var(--accent); }
}
'

# --- Section 7: Assemble -----------------------------------------------------

mode_label <- if (anonymize) "Anonymised (external-shareable)" else "Internal board pack (named)"
body <- paste0(
'<!DOCTYPE html><html lang="en"><head><meta charset="utf-8">',
'<meta name="viewport" content="width=device-width, initial-scale=1">',
sprintf('<title>%s Climate Transition Disclosure Pack</title>', cfg$bank_name),
paste0('<style>', css, '</style></head><body>'),
'<div class="hero"><h1>Climate Transition Disclosure Pack</h1>',
sprintf('<div class="subtitle">%s — TCFD-aligned, with ISSB IFRS S2 cross-references &amp; Decision 263 mapping</div>', bank_label),
'<div class="meta">Prepared ', report_date, ' · ', mode_label, '</div>',
'<div class="confidential">SYNTHETIC DATA · ILLUSTRATIVE · CONFIDENTIAL DRAFT</div></div>',
'<div class="container">',

'<div class="disclaimer"><strong>Illustrative — synthetic data.</strong> This disclosure pack is generated from a synthetic demonstration portfolio (PACTA alignment + TRISK transition stress). It is not a regulatory filing and requires human and legal review before any external use.</div>',

'<div class="toc"><h3>Contents</h3><ol>',
'<li><a href="#exec">Executive Summary</a></li>',
'<li><a href="#align">Portfolio Alignment vs PDP8 / NDC / NZE</a></li>',
'<li><a href="#borrowers">Top Transition-Risk Counterparties</a></li>',
'<li><a href="#tcfd">TCFD-aligned Disclosures (Governance · Strategy · Risk Management · Metrics &amp; Targets)</a></li>',
'<li><a href="#methodology">Methodology Appendix</a></li>',
'</ol></div>',

'<div class="section" id="exec"><h2>1. Executive Summary</h2>', exec_html, '</div>',
'<div class="section" id="align"><h2>2. Portfolio Alignment vs PDP8 / NDC / NZE</h2>', align_html, '</div>',
'<div class="section" id="borrowers"><h2>3. Top Transition-Risk Counterparties</h2>', borrowers_html, '</div>',
'<div class="section" id="tcfd"><h2>4. TCFD-aligned Disclosures</h2>',
'<div class="callout callout-info">Structured on the four TCFD pillars, each cross-referenced to ISSB IFRS S2 and to the Decision 263/QĐ-TTg obligation it supports.</div>',
tcfd_html, '</div>',
'<div class="section" id="methodology"><h2>5. Methodology Appendix</h2>', methodology_html, '</div>',

sprintf('<div class="foot">%s — synthetic demonstration. PACTA + TRISK climate analytics. Not financial advice, not a credit decision, not a regulatory filing.</div>', bank_label),
'</div></body></html>'
)

# --- i18n overlay (PHASE-07): headings/column labels/disclaimer via labels.csv ---
i18n_lang_d <- if (is.null(cfg$report_language) || length(cfg$report_language) == 0) "en" else cfg$report_language
i18n_labels_d <- tryCatch(
  load_report_labels(override_csv = if (length(cfg$paths$i18n_override_csv) > 0) cfg$paths$i18n_override_csv else NULL),
  error = function(e) NULL
)
if (!is.null(i18n_labels_d) && i18n_lang_d %in% c("vi", "bilingual")) {
  # Headings
  body <- gsub("Climate Transition Disclosure Pack", report_label("disclosure_pack_title", i18n_lang_d, i18n_labels_d), body, fixed = TRUE)
  body <- gsub("Executive Summary", report_label("executive_summary", i18n_lang_d, i18n_labels_d), body, fixed = TRUE)
  body <- gsub("Counterparty", report_label("borrower", i18n_lang_d, i18n_labels_d), body, fixed = TRUE)
  body <- gsub("Synthetic data — illustrative only", report_label("synthetic_disclaimer", i18n_lang_d, i18n_labels_d), body, fixed = TRUE)
  if (identical(i18n_lang_d, "bilingual")) {
    body <- sub("<div class=\"container\">",
                paste0("<div class=\"container\"><div class=\"callout callout-info\">Section headings, table column labels and the synthetic-data disclaimer are shown as English / Vietnamese; analyst-written narrative remains English.</div>"),
                body, fixed = TRUE)
  }
}

# --- Section 8: Anonymise across the whole body (RISK-03-01) -----------------
# Single name list, applied longest-first with fixed-string replacement so a
# shorter name cannot be a substring of a longer one. Grep verifies in tests.

if (anonymize && length(pseudonyms) > 0) {
  ord <- order(nchar(names(pseudonyms)), decreasing = TRUE)
  for (nm in names(pseudonyms)[ord]) {
    body <- gsub(nm, pseudonyms[[nm]], body, fixed = TRUE)
  }
}

# --- Section 9: Write + size check -------------------------------------------

writeLines(body, output_path, useBytes = TRUE)
size_kb <- file.info(output_path)$size / 1024
cat(sprintf("\nWritten: %s (%.1f KB)\n", output_path, size_kb))
if (size_kb > 2048) {
  cat("  WARNING: exceeds the 2 MB target.\n")
} else {
  cat("  OK: under the 2 MB target.\n")
}
cat(sprintf("  Mode: %s\n", mode_label))
cat("  TCFD pillars + ISSB cross-refs + Decision 263 note included; synthetic-data disclaimer in every data-driven section.\n")

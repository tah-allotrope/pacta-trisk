# generate_bidv_report.R
# Generates the BIDV Framework Recommendation Report as a self-contained HTML file.
# Reads upstream advisory content (markdown documents + pipeline CSVs + chart PNGs)
# and renders a single HTML report with base64-embedded images.
#
# Usage: Rscript scripts/generate_bidv_report.R
# Run from project root: C:\Users\tukum\Downloads\pacta-trisk

# ============================================================================
# SECTION 1: Configuration
# ============================================================================

input_files <- list(
  framework_comparison     = "docs/bidv_framework_comparison.md",
  decision263_mapping      = "docs/bidv_decision263_mapping.md",
  implementation_roadmap   = "docs/bidv_implementation_roadmap.md",
  sector_methodology       = "docs/bidv_sector_prioritization_methodology.md",
  pacta_guide              = "docs/PACTA_Beginner_Guide.md",
  trisk_assumptions        = "docs/TRISK_Demo_Assumptions.md",
  prioritization_ranking   = "synthesis_output/prioritization/sector_priority_ranking.csv",
  prioritization_chart     = "synthesis_output/prioritization/sector_priority_chart.png",
  interpretation_notes     = "synthesis_output/prioritization/interpretation_notes.md",
  loanbook                 = "data/vietnam_loanbook.csv",
  power_techmix_chart      = "synthesis_output/vietnam/05_vn_power_techmix.png",
  trisk_npv_chart          = "dashboard/data/trisk/power/01_npv_change_by_company.png"
)

output_path <- "reports/BIDV_Framework_Recommendation_Report.html"
report_date <- format(Sys.Date(), "%B %d, %Y")

# ============================================================================
# SECTION 2: Pre-flight checks
# ============================================================================

cat("Running pre-flight checks...\n")

missing_files <- character(0)
for (name in names(input_files)) {
  path <- input_files[[name]]
  if (!file.exists(path)) {
    missing_files <- c(missing_files, path)
    cat(sprintf("  MISSING: %s\n", path))
  }
}

if (length(missing_files) > 0) {
  cat(sprintf("\nWARNING: %d file(s) missing. Placeholder sections will be inserted.\n", length(missing_files)))
} else {
  cat("  All files present.\n")
}

file_ok <- function(name) file.exists(input_files[[name]])

# ============================================================================
# SECTION 3: Helper functions
# ============================================================================

# --- Base64 image encoder ---
img_to_base64 <- function(path) {
  if (!file.exists(path)) return("")
  raw <- readBin(path, "raw", file.info(path)$size)
  b64 <- base64enc::base64encode(raw)
  paste0("data:image/png;base64,", b64)
}

# --- Simple markdown-to-HTML converter ---
md_to_html <- function(text) {
  lines <- strsplit(text, "\n")[[1]]
  out <- character(0)
  in_ul <- FALSE
  in_ol <- FALSE
  in_table <- FALSE
  table_rows <- list()

  close_list <- function() {
    r <- character(0)
    if (in_ul) { r <- c(r, "</ul>"); assign("in_ul", FALSE, envir = environment()) }
    if (in_ol) { r <- c(r, "</ol>"); assign("in_ol", FALSE, envir = environment()) }
    r
  }

  close_table <- function() {
    if (!in_table || length(table_rows) == 0) return(character(0))
    html <- "<table>"
    for (i in seq_along(table_rows)) {
      cells <- table_rows[[i]]
      tag <- if (i == 1) "th" else "td"
      row_html <- paste0("<", tag, ">", paste(cells, collapse = paste0("</", tag, "><", tag, ">")), "</", tag, ">")
      html <- paste0(html, "<tr>", row_html, "</tr>")
    }
    html <- paste0(html, "</table>")
    assign("in_table", FALSE, envir = environment())
    assign("table_rows", list(), envir = environment())
    html
  }

  for (line in lines) {
    # Skip empty lines but close open structures
    if (grepl("^\\s*$", line)) {
      out <- c(out, close_list(), close_table())
      next
    }

    # Tables (lines starting with |)
    if (grepl("^\\|", line)) {
      if (!in_table) assign("in_table", TRUE, envir = environment())
      # Skip separator rows (|---|---|)
      if (grepl("^\\|\\s*[-:]+\\s*\\|", line)) next
      cells <- strsplit(gsub("^\\|\\s*|\\s*\\|$", "", line), "\\s*\\|\\s*")[[1]]
      cells <- trimws(cells)
      assign("table_rows", c(table_rows, list(cells)), envir = environment())
      next
    } else {
      out <- c(out, close_table())
    }

    # Headers
    if (grepl("^### ", line)) {
      out <- c(out, close_list())
      txt <- gsub("^###\\s*", "", line)
      out <- c(out, paste0("<h3>", inline_md(txt), "</h3>"))
      next
    }
    if (grepl("^## ", line)) {
      out <- c(out, close_list())
      txt <- gsub("^##\\s*", "", line)
      out <- c(out, paste0("<h2>", inline_md(txt), "</h2>"))
      next
    }
    if (grepl("^# ", line)) {
      out <- c(out, close_list())
      txt <- gsub("^#\\s*", "", line)
      out <- c(out, paste0("<h1>", inline_md(txt), "</h1>"))
      next
    }

    # Unordered list
    if (grepl("^[-*]\\s+", line)) {
      if (!in_ul) {
        out <- c(out, close_list())
        out <- c(out, "<ul>")
        assign("in_ul", TRUE, envir = environment())
      }
      txt <- gsub("^[-*]\\s+", "", line)
      out <- c(out, paste0("<li>", inline_md(txt), "</li>"))
      next
    }

    # Ordered list
    if (grepl("^\\d+\\.\\s+", line)) {
      if (!in_ol) {
        out <- c(out, close_list())
        out <- c(out, "<ol>")
        assign("in_ol", TRUE, envir = environment())
      }
      txt <- gsub("^\\d+\\.\\s+", "", line)
      out <- c(out, paste0("<li>", inline_md(txt), "</li>"))
      next
    }

    # Not a list item — close any open list
    out <- c(out, close_list())

    # Blockquote
    if (grepl("^> ", line)) {
      txt <- gsub("^>\\s*", "", line)
      out <- c(out, paste0("<blockquote><em>", inline_md(txt), "</em></blockquote>"))
      next
    }

    # Horizontal rule
    if (grepl("^---+$", line)) {
      out <- c(out, "<hr>")
      next
    }

    # Regular paragraph
    out <- c(out, paste0("<p>", inline_md(line), "</p>"))
  }

  out <- c(out, close_list(), close_table())
  paste(out, collapse = "\n")
}

inline_md <- function(text) {
  # Bold
  text <- gsub("\\*\\*(.+?)\\*\\*", "<strong>\\1</strong>", text)
  # Italic
  text <- gsub("\\*(.+?)\\*", "<em>\\1</em>", text)
  # Inline code
  text <- gsub("``(.+?)``", "<code>\\1</code>", text)
  text <- gsub("`([^`]+)`", "<code>\\1</code>", text)
  # Links [text](url)
  text <- gsub("\\[(.+?)\\]\\((.+?)\\)", '<a href="\\2">\\1</a>', text)
  text
}

# --- Extract a specific section from markdown by header ---
extract_section <- function(md_text, header_pattern, next_header_pattern = NULL) {
  lines <- strsplit(md_text, "\n")[[1]]
  header_re <- paste0("^#{1,3}\\s+", header_pattern)
  start_idx <- grep(header_re, lines, ignore.case = TRUE)
  if (length(start_idx) == 0) return("")

  if (!is.null(next_header_pattern)) {
    next_re <- paste0("^#{1,3}\\s+", next_header_pattern)
    remaining <- lines[(start_idx[1] + 1):length(lines)]
    end_idx <- grep(next_re, remaining, ignore.case = TRUE)
    if (length(end_idx) > 0) {
      end_idx <- start_idx[1] + end_idx[1] - 1
    } else {
      end_idx <- length(lines)
    }
  } else {
    end_idx <- length(lines)
  }

  paste(lines[start_idx[1]:end_idx], collapse = "\n")
}

# --- Extract all markdown tables from text ---
extract_tables_html <- function(md_text) {
  lines <- strsplit(md_text, "\n")[[1]]
  in_table <- FALSE
  table_lines <- character(0)
  tables <- list()

  for (line in lines) {
    if (grepl("^\\s*\\|", line)) {
      if (!in_table) {
        in_table <- TRUE
        table_lines <- character(0)
      }
      if (!grepl("^\\s*\\|\\s*[-:]+", line)) {
        table_lines <- c(table_lines, line)
      }
    } else {
      if (in_table && length(table_lines) > 0) {
        tables <- c(tables, list(table_lines_to_html(table_lines)))
      }
      in_table <- FALSE
    }
  }
  if (in_table && length(table_lines) > 0) {
    tables <- c(tables, list(table_lines_to_html(table_lines)))
  }
  tables
}

table_lines_to_html <- function(lines) {
  if (length(lines) < 1) return("")
  html <- "<table>"
  for (i in seq_along(lines)) {
    cells <- strsplit(gsub("^\\s*\\|\\s*|\\s*\\|\\s*$", "", lines[i]), "\\s*\\|\\s*")[[1]]
    cells <- trimws(cells)
    tag <- if (i == 1) "th" else "td"
    row_html <- paste0("<", tag, ">", paste(cells, collapse = paste0("</", tag, "><", tag, ">")), "</", tag, ">")
    html <- paste0(html, "<tr>", row_html, "</tr>")
  }
  paste0(html, "</table>")
}

# ============================================================================
# SECTION 4: Data loaders
# ============================================================================

cat("Loading data...\n")

# Load prioritization ranking
ranking <- NULL
if (file_ok("prioritization_ranking")) {
  ranking <- read.csv(input_files$prioritization_ranking, stringsAsFactors = FALSE)
}

# Load loanbook for exposure computation
loanbook <- NULL
if (file_ok("loanbook")) {
  loanbook <- read.csv(input_files$loanbook, stringsAsFactors = FALSE)
}

# Compute sector exposure stats
sector_exposure <- data.frame(
  sector = character(0), loan_count = integer(0), exposure_vnd = numeric(0), stringsAsFactors = FALSE
)
if (!is.null(loanbook)) {
  # Map PACTA sectors to Decision 263 sectors
  loanbook$d263_sector <- "Other"
  # Power: ISIC 3510 (electric power generation)
  loanbook$d263_sector[grepl("^3510", loanbook$sector_classification_direct_loantaker)] <- "Power"
  # Cement: ISIC 2395 (manufacture of cement)
  loanbook$d263_sector[grepl("^2395", loanbook$sector_classification_direct_loantaker)] <- "Cement"
  # Steel: ISIC 2410 (manufacture of basic iron and steel)
  loanbook$d263_sector[grepl("^2410", loanbook$sector_classification_direct_loantaker)] <- "Steel"

  d263 <- loanbook[loanbook$d263_sector %in% c("Power", "Cement", "Steel"), ]
  if (nrow(d263) > 0) {
    sector_exposure <- aggregate(
      loan_size_outstanding ~ d263_sector,
      data = d263,
      FUN = function(x) c(count = length(x), total = sum(x))
    )
    sector_exposure <- data.frame(
      sector = sector_exposure$d263_sector,
      loan_count = sector_exposure$loan_size_outstanding[, "count"],
      exposure_vnd = sector_exposure$loan_size_outstanding[, "total"],
      stringsAsFactors = FALSE
    )
  }
}

total_d263_exposure <- sum(sector_exposure$exposure_vnd, na.rm = TRUE)
total_d263_loans <- sum(sector_exposure$loan_count, na.rm = TRUE)

# Encode images
cat("Encoding images...\n")
img_prioritization <- if (file_ok("prioritization_chart")) img_to_base64(input_files$prioritization_chart) else ""
img_power_techmix <- if (file_ok("power_techmix_chart")) img_to_base64(input_files$power_techmix_chart) else ""
img_trisk_npv <- if (file_ok("trisk_npv_chart")) img_to_base64(input_files$trisk_npv_chart) else ""

# Load markdown sources
md_framework <- if (file_ok("framework_comparison")) readLines(input_files$framework_comparison, warn = FALSE, encoding = "UTF-8") else NULL
md_decision263 <- if (file_ok("decision263_mapping")) readLines(input_files$decision263_mapping, warn = FALSE, encoding = "UTF-8") else NULL
md_roadmap <- if (file_ok("implementation_roadmap")) readLines(input_files$implementation_roadmap, warn = FALSE, encoding = "UTF-8") else NULL
md_interpretation <- if (file_ok("interpretation_notes")) readLines(input_files$interpretation_notes, warn = FALSE, encoding = "UTF-8") else NULL

md_framework_text <- if (!is.null(md_framework)) paste(md_framework, collapse = "\n") else ""
md_decision263_text <- if (!is.null(md_decision263)) paste(md_decision263, collapse = "\n") else ""
md_roadmap_text <- if (!is.null(md_roadmap)) paste(md_roadmap, collapse = "\n") else ""
md_interpretation_text <- if (!is.null(md_interpretation)) paste(md_interpretation, collapse = "\n") else ""

# ============================================================================
# SECTION 5: CSS
# ============================================================================

css <- '
:root {
  --primary: #1a5276;
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
  background: linear-gradient(135deg, var(--primary) 0%, var(--accent) 100%);
  color: white;
  padding: 3rem 2rem;
  text-align: center;
}
.hero h1 { font-size: 2.2rem; font-weight: 700; margin-bottom: 0.5rem; }
.hero .subtitle { font-size: 1.1rem; opacity: 0.9; font-weight: 300; }
.hero .meta { margin-top: 1.2rem; font-size: 0.85rem; opacity: 0.7; }
.hero .confidential {
  margin-top: 1rem;
  padding: 0.5rem 1rem;
  background: rgba(255,255,255,0.15);
  border-radius: 4px;
  display: inline-block;
  font-size: 0.8rem;
  font-weight: 600;
  letter-spacing: 0.05em;
}
.container { max-width: 960px; margin: 0 auto; padding: 2rem 1.5rem; }
.toc {
  background: #f7fafc;
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.2rem 1.5rem;
  margin-bottom: 2rem;
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
  background: var(--card-bg);
  border-radius: 8px;
  padding: 2rem;
  margin-bottom: 2rem;
  box-shadow: 0 1px 3px rgba(0,0,0,0.08);
}
.section h2 {
  color: var(--primary);
  font-size: 1.4rem;
  margin-bottom: 0.3rem;
  padding-bottom: 0.6rem;
  border-bottom: 2px solid var(--border);
}
.section h3 {
  color: var(--accent);
  font-size: 1.1rem;
  margin: 1.5rem 0 0.5rem 0;
}
.section p { margin: 0.7rem 0; }
.section ul, .section ol { padding-left: 1.5rem; margin: 0.5rem 0; }
.section li { margin: 0.3rem 0; }
.section blockquote {
  border-left: 3px solid var(--border);
  padding-left: 1rem;
  color: var(--text-light);
  margin: 0.5rem 0;
}
.section table {
  width: 100%;
  border-collapse: collapse;
  margin: 1rem 0;
  font-size: 0.9rem;
}
.section th {
  background: var(--primary);
  color: white;
  padding: 0.7rem 1rem;
  text-align: left;
  font-weight: 600;
}
.section td { padding: 0.6rem 1rem; border-bottom: 1px solid var(--border); }
.section tr:nth-child(even) { background: #f7fafc; }
.section tr:hover { background: #edf2f7; }
.chart-container {
  text-align: center;
  margin: 1.5rem 0;
  padding: 1rem;
  background: #f8fafc;
  border-radius: 6px;
  border: 1px solid var(--border);
}
.chart-container img { max-width: 100%; height: auto; border-radius: 4px; }
.chart-caption {
  font-size: 0.82rem;
  color: var(--text-light);
  margin-top: 0.5rem;
  font-style: italic;
}
.kpi-row {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  gap: 1rem;
  margin: 1.5rem 0;
}
.kpi-card {
  background: #f7fafc;
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.2rem;
  text-align: center;
}
.kpi-card .value { font-size: 1.8rem; font-weight: 700; color: var(--primary); }
.kpi-card .label { font-size: 0.8rem; color: var(--text-light); margin-top: 0.3rem; }
.badge {
  display: inline-block;
  padding: 0.15rem 0.6rem;
  border-radius: 12px;
  font-size: 0.78rem;
  font-weight: 600;
  text-transform: uppercase;
}
.badge-red { background: #fed7d7; color: var(--red); }
.badge-green { background: #c6f6d5; color: var(--green); }
.badge-orange { background: #feebc8; color: var(--orange); }
.badge-gray { background: #e2e8f0; color: #4a5568; }
.callout {
  padding: 1rem 1.2rem;
  border-radius: 6px;
  margin: 1rem 0;
  font-size: 0.92rem;
}
.callout-warning { background: #fffbeb; border-left: 4px solid var(--orange); }
.callout-info { background: #ebf8ff; border-left: 4px solid var(--accent); }
.callout-danger { background: #fff5f5; border-left: 4px solid var(--red); }
.disclaimer {
  padding: 0.8rem 1rem;
  border: 2px solid var(--red);
  background: #fff5f5;
  border-radius: 6px;
  margin: 1rem 0;
  font-size: 0.88rem;
}
.disclaimer strong { color: var(--red); }
.phase-card {
  background: #f7fafc;
  border: 1px solid var(--border);
  border-radius: 8px;
  padding: 1.5rem;
  margin: 1rem 0;
  border-left: 4px solid var(--accent);
}
.phase-card h3 { margin-top: 0; color: var(--primary); }
.phase-card .deliverable {
  background: #ebf8ff;
  padding: 0.5rem 0.8rem;
  border-radius: 4px;
  margin-top: 0.8rem;
  font-size: 0.88rem;
}
.phase-card .deliverable strong { color: var(--accent); }
.footer {
  text-align: center;
  padding: 2rem;
  color: var(--text-light);
  font-size: 0.8rem;
  border-top: 1px solid var(--border);
  margin-top: 2rem;
}
@media print {
  .section { box-shadow: none; border: 1px solid #ddd; page-break-inside: avoid; }
  .hero { padding: 1.5rem; }
  .chart-container { page-break-inside: avoid; }
  table { page-break-inside: avoid; }
}
'

# ============================================================================
# SECTION 6: Section renderers
# ============================================================================

cat("Building report sections...\n")

placeholder <- function(section_name) {
  paste0('<div class="callout callout-warning"><strong>', section_name, '</strong> — Content pending. Awaiting upstream document.</div>')
}

# --- Section 1: Cover Page ---
section_cover <- paste0('
<div class="hero">
  <h1>BIDV Framework Recommendation Report</h1>
  <div class="subtitle">Portfolio Alignment &amp; Transition Stress Testing for Decision 263 Sectors</div>
  <div class="meta">', report_date, ' &nbsp;|&nbsp; Prepared by GTB Advisory &nbsp;|&nbsp; Illustrative analysis (synthetic MCB portfolio)</div>
  <div class="confidential">CONFIDENTIAL &mdash; FOR AUTHORIZED RECIPIENTS ONLY</div>
</div>
')

# --- Section 2: Executive Summary ---
section_exec_summary <- {
  top_sector <- if (!is.null(ranking) && nrow(ranking) > 0) {
    toupper(ranking$sector[which.max(ranking$composite_score)])
  } else { "POWER" }

  d263_sectors_count <- if (!is.null(sector_exposure)) nrow(sector_exposure) else 3
  exposure_billion <- round(total_d263_exposure / 1e9, 1)

  paste0('
<div class="executive-summary" id="exec">
  <h2>Executive Summary</h2>
  <p>This report evaluates leading portfolio alignment and climate risk frameworks against BIDV\'s specific context and regulatory obligations under <strong>Decision 263</strong> (Quyết định 263/QĐ-TTg), which mandates GHG emission inventories and sector-specific quotas for thermal power, steel, and cement facilities. The analysis recommends a <strong>PACTA + TRISK</strong> analytical stack as the primary framework, supported by PCAF for emissions accounting and TCFD/ISSB S2 for disclosure.</p>

  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value">', d263_sectors_count, '</div>
      <div class="label">Decision 263 Sectors Covered</div>
    </div>
    <div class="kpi-card">
      <div class="value">', exposure_billion, 'B VND</div>
      <div class="label">Total Decision 263 Exposure (MCB demo)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--red);">', top_sector, '</div>
      <div class="label">Highest-Priority Sector</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">PACTA + TRISK</div>
      <div class="label">Recommended Framework</div>
    </div>
  </div>

  <div class="callout callout-danger">
    <strong>Key Finding:</strong> In the illustrative MCB synthetic portfolio, the <strong>power sector dominates all three priority dimensions</strong> (alignment gap, transition stress, and portfolio exposure), scoring maximum (1.0) on the composite priority scale. BIDV should prioritize power sector engagement, followed by steel and cement.
  </div>

  <p><strong>What BIDV should do:</strong> Adopt a phased 6-month implementation pathway beginning with data preparation (extracting Decision 263 portfolio exposure and collecting client emissions data), followed by PACTA alignment analysis, TRISK stress testing, borrower engagement, and quarterly monitoring. The full roadmap is detailed in Section 8.</p>

  <p><strong>What\'s next:</strong> This report provides the framework evaluation, regulatory mapping, sector prioritization, and implementation roadmap. BIDV-specific results will be produced upon data onboarding through the BYOL (Bring Your Own Loanbook) intake process.</p>
</div>
')
}

# --- Section 3: BIDV Context ---
section_bidv_context <- {
  exposure_table <- ""
  if (!is.null(sector_exposure) && nrow(sector_exposure) > 0) {
    rows <- apply(sector_exposure, 1, function(r) {
      paste0("<tr><td>", r["sector"], "</td><td>", r["loan_count"], "</td><td>",
             format(as.numeric(r["exposure_vnd"]), big.mark = ","), " VND</td><td>",
             sprintf("%.1f%%", as.numeric(r["exposure_vnd"]) / total_d263_exposure * 100), "</td></tr>")
    })
    exposure_table <- paste0("<table><tr><th>Sector</th><th>Loans</th><th>Exposure</th><th>Share</th></tr>",
                              paste(rows, collapse = ""),
                              "<tr style=\"font-weight:bold\"><td>Total</td><td>", total_d263_loans, "</td><td>",
                              format(total_d263_exposure, big.mark = ","), " VND</td><td>100%</td></tr></table>")
  }

  paste0('
<div class="section" id="context">
  <h2>BIDV Context</h2>

  <div class="disclaimer">
    <strong>Synthetic Data Notice:</strong> Illustrative results based on synthetic portfolio (MCB). BIDV-specific results will be produced upon data onboarding.
  </div>

  <h3>Decision 263 Obligations</h3>
  <p>Decision 263 (Quyết định 263/QĐ-TTg, 2022) mandates GHG emission inventories, sector-specific emission quotas, and emission reduction plans for facilities in <strong>thermal power</strong>, <strong>steel</strong>, and <strong>cement</strong>. Regulated entities must report emissions data starting from the 2025 reporting year. Commercial banks like BIDV should monitor borrower compliance as part of their ESG governance framework, since non-compliant borrowers face regulatory risk that translates to credit risk.</p>

  <h3>Illustrative Sector Exposure (MCB Synthetic Portfolio)</h3>
  <p>The table below shows the Decision 263 sector distribution in the synthetic MCB portfolio used for this demonstration:</p>

  ', if (exposure_table != "") exposure_table else placeholder("Sector exposure table"), '

  <h3>PCAF Baseline Status</h3>
  <p>BIDV\'s financed emissions baseline (Output 2.1) is PCAF-based. The framework recommendation in this report positions PACTA/TRISK as the portfolio alignment and risk layer that sits on top of the PCAF emissions accounting foundation. Together, PCAF + PACTA + TRISK create a three-layer architecture: <strong>measure</strong> (emissions) → <strong>compare</strong> (alignment) → <strong>act</strong> (stress testing and engagement).</p>
</div>
')
}

# --- Section 4: Framework Landscape ---
section_framework_landscape <- {
  if (md_framework_text == "") return(placeholder("Framework Landscape"))

  # Extract only the 7x10 scored matrix (lines ~54-65 in the source)
  lines <- strsplit(md_framework_text, "\n")[[1]]
  matrix_start <- grep("^\\| \\*\\*1\\. Data inputs\\*\\*", lines)
  matrix_end <- grep("^\\| \\*\\*10\\. Maturity", lines)
  matrix_html <- ""
  if (length(matrix_start) > 0 && length(matrix_end) > 0) {
    matrix_lines <- c(
      "| Dimension | PACTA | TRISK | PCAF | SBTi FI | GFANZ/NZBA | NGFS | IFRS S2 |",
      "|---|---|---|---|---|---|---|---|",
      lines[matrix_start[1]:matrix_end[1]]
    )
    matrix_html <- table_lines_to_html(matrix_lines)
  }

  paste0('
<div class="section" id="framework">
  <h2>Framework Landscape</h2>
  <p>Seven leading portfolio alignment and climate risk frameworks were evaluated across 10 dimensions relevant to BIDV\'s context: data input requirements, sector coverage (thermal power, steel, cement), Vietnam regulatory compatibility (Decision 263, SBV taxonomy), output types, implementation complexity, cost, open-source availability, time to first results, complementarity with PCAF baseline, and maturity/institutional adoption.</p>

  <h3>7 × 10 Scored Matrix</h3>
  <p>Each framework is scored: <strong>Strong Fit</strong> (addresses well for BIDV), <strong>Partial Fit</strong> (addresses with limitations), <strong>Weak Fit</strong> (does not meaningfully address).</p>

  ', if (matrix_html != "") matrix_html else '<p><em>Evaluation matrix could not be extracted.</em></p>', '

  <div class="callout callout-info">
    <strong>Full analysis:</strong> The complete framework comparison document (<code>docs/bidv_framework_comparison.md</code>) includes detailed scoring justifications for every cell, framework-by-framework evaluation narratives, and a complementarity analysis.
  </div>
</div>
')
}

# --- Section 5: Framework Recommendation ---
section_framework_recommendation <- {
  paste0('
<div class="section" id="recommendation">
  <h2>Framework Recommendation</h2>

  <h3>Recommended Stack</h3>
  <div class="kpi-row">
    <div class="kpi-card">
      <div class="value" style="color: var(--green);">Primary</div>
      <div class="label"><strong>PACTA + TRISK</strong><br>Portfolio alignment &amp; transition stress testing</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--accent);">Secondary</div>
      <div class="label"><strong>PCAF</strong><br>Financed emissions accounting (prerequisite)</div>
    </div>
    <div class="kpi-card">
      <div class="value" style="color: var(--primary);">Tertiary</div>
      <div class="label"><strong>TCFD / ISSB S2</strong><br>Disclosure output framework</div>
    </div>
  </div>

  <h3>Why This Stack</h3>
  <p>The recommended stack creates a <strong>complete analytical pipeline</strong> from measurement to action to disclosure:</p>
  <table>
    <tr><th>Layer</th><th>Framework</th><th>Question Answered</th></tr>
    <tr><td>1. Measure</td><td>PCAF</td><td>"What are my financed emissions?"</td></tr>
    <tr><td>2. Align</td><td>PACTA</td><td>"Is my portfolio aligned with PDP8/NDC?"</td></tr>
    <tr><td>3. Stress</td><td>TRISK</td><td>"What is the financial impact?"</td></tr>
    <tr><td>4. Disclose</td><td>IFRS S2</td><td>"How do I report to investors and regulators?"</td></tr>
  </table>

  <p><strong>PCAF</strong> establishes the emissions baseline that all downstream analysis depends on. <strong>PACTA</strong> tells BIDV whether its portfolio is aligned with Vietnam\'s PDP8 and NDC targets — producing concrete gap percentages by sector and technology. <strong>TRISK</strong> translates PACTA\'s alignment gaps into borrower-level NPV and PD changes — giving credit risk teams the financial metrics they need to prioritize action. <strong>IFRS S2</strong> provides the disclosure framework that turns all upstream analytical outputs into investor-ready reporting.</p>

  <h3>Complementary Frameworks</h3>
  <table>
    <tr><th>Framework</th><th>Role</th><th>When to Consider</th></tr>
    <tr><td>GFANZ/NZBA</td><td>Governance wrapper &amp; peer learning</td><td>When BIDV is ready for a public net-zero commitment</td></tr>
    <tr><td>SBTi FI</td><td>Independent target validation</td><td>After PCAF accounting is mature and PACTA gaps are understood</td></tr>
    <tr><td>NGFS</td><td>Scenario input provider</td><td>When more sophisticated macroeconomic scenarios are needed beyond PDP8/NDC</td></tr>
  </table>
</div>
')
}

# --- Section 6: Sector Prioritization ---
section_sector_prioritization <- {
  ranking_table <- ""
  if (!is.null(ranking) && nrow(ranking) > 0) {
    rows <- apply(ranking, 1, function(r) {
      band <- r["priority_band"]
      badge_class <- if (band == "Critical") "badge-red" else if (band == "High") "badge-orange" else "badge-gray"
      paste0("<tr><td><strong>", r["sector"], "</strong></td><td>",
             sprintf("%.3f", as.numeric(r["composite_score"])), "</td><td>",
             sprintf("%.3f", as.numeric(r["alignment_score"])), "</td><td>",
             sprintf("%.1f", as.numeric(r["stress_score_raw"])), "</td><td>",
             sprintf("%.1f%%", as.numeric(r["exposure_share"]) * 100), "</td><td>",
             '<span class="badge ', badge_class, '">', band, '</span></td></tr>')
    })
    ranking_table <- paste0(
      "<table><tr><th>Sector</th><th>Composite Score</th><th>Alignment</th><th>Stress Score</th><th>Exposure Share</th><th>Priority</th></tr>",
      paste(rows, collapse = ""),
      "</table>"
    )
  }

  interpretation_html <- if (md_interpretation_text != "") md_to_html(md_interpretation_text) else ""

  chart_html <- ""
  if (img_prioritization != "") {
    chart_html <- paste0('
    <div class="chart-container">
      <img src="', img_prioritization, '" alt="Sector Priority Chart">
      <div class="chart-caption">Figure: Sector priority ranking — composite scores across alignment, stress, and exposure dimensions.</div>
    </div>')
  }

  paste0('
<div class="section" id="prioritization">
  <h2>Sector Prioritization</h2>

  <div class="disclaimer">
    <strong>Synthetic Data Notice:</strong> Illustrative results based on synthetic portfolio (MCB). BIDV-specific results will be produced upon data onboarding.
  </div>

  <p>Sectors are ranked by a composite priority score combining three dimensions: <strong>alignment gap</strong> (weight: 0.35), <strong>transition stress</strong> (weight: 0.35), and <strong>portfolio exposure</strong> (weight: 0.30). Scores are min-max normalized across sectors to handle different units (percentage points vs. percent).</p>

  ', if (ranking_table != "") ranking_table else placeholder("Sector ranking table"), '

  ', chart_html, '

  <h3>Interpretation</h3>
  ', if (interpretation_html != "") interpretation_html else '<p><em>Interpretation notes not available.</em></p>', '
</div>
')
}

# --- Section 7: Decision 263 Mapping ---
section_decision263 <- {
  paste0('
<div class="section" id="decision263">
  <h2>Decision 263 Compliance Mapping</h2>

  <div class="disclaimer">
    <strong>Regulatory Note:</strong> Decision 263 implementing regulations may evolve. BIDV should re-validate against MONRE\'s latest guidelines before each PACTA/TRISK re-run.
  </div>

  <h3>Decision 263 Overview</h3>
  <p>Decision 263 (Quyết định 263/QĐ-TTg, 2022) mandates GHG emission inventories, sector-specific emission quotas, and emission reduction plans for facilities in <strong>thermal power</strong>, <strong>steel</strong>, and <strong>cement</strong>. Regulated entities must report emissions data starting from the 2025 reporting year. The decision is implemented under the Law on Environmental Protection 2020 (Article 91) through MONRE (Bộ Tài nguyên và Môi trường) regulations.</p>

  <h3>Sector Mapping</h3>
  <table>
    <tr><th>Decision 263 Sector</th><th>PACTA Sector</th><th>PACTA Technologies</th><th>TRISK Sector</th><th>Repo Data Files</th></tr>
    <tr><td>Thermal power</td><td><code>power</code></td><td><code>coalcap</code>, <code>gascap</code></td><td><code>Power</code></td><td><code>vietnam_abcd.csv</code>, <code>vietnam_scenario_ms.csv</code></td></tr>
    <tr><td>Steel</td><td><code>steel</code></td><td><code>open_hearth</code>, <code>electric</code></td><td><code>Steel</code></td><td><code>vietnam_abcd.csv</code>, <code>vietnam_scenario_co2.csv</code></td></tr>
    <tr><td>Cement</td><td><code>cement</code></td><td><code>integrated facility</code></td><td><code>Cement</code></td><td><code>vietnam_abcd.csv</code>, <code>vietnam_scenario_co2.csv</code></td></tr>
  </table>

  <h3>Compliance Capability Mapping</h3>
  <table>
    <tr><th>Decision 263 Requirement</th><th>Repo Capability</th><th>Pipeline Output</th></tr>
    <tr><td>Emission inventory</td><td>PCAF financed emissions + PACTA matching</td><td>Matched borrower-emission linkage</td></tr>
    <tr><td>Sector-specific quotas</td><td>PACTA SDA analysis (emission intensity pathways)</td><td>Alignment gap vs. target by sector</td></tr>
    <tr><td>Emission reduction plans</td><td>TRISK stress testing + sector prioritization</td><td>Borrower-level NPV/PD impact, priority ranking</td></tr>
  </table>

  <h3>BIDV Compliance Stack</h3>
  <p>The three-layer architecture maps directly to Decision 263\'s three requirements:</p>
  <ul>
    <li><strong>Measure (PCAF):</strong> Financed emissions baseline → supports emission inventory requirement</li>
    <li><strong>Compare (PACTA):</strong> Alignment gaps vs. PDP8/NDC targets → supports sector-specific quota assessment</li>
    <li><strong>Act (TRISK):</strong> Borrower-level stress-test results → supports emission reduction plan development</li>
  </ul>

  <div class="callout callout-info">
    <strong>Full analysis:</strong> The complete Decision 263 mapping document (<code>docs/bidv_decision263_mapping.md</code>) includes the regulatory overview, data availability assessment, synthetic borrower-to-Decision-263-entity mapping, and gap acknowledgment.
  </div>
</div>
')
}

# --- Section 8: Implementation Roadmap ---
section_implementation_roadmap <- {
  paste0('
<div class="section" id="roadmap">
  <h2>Implementation Roadmap</h2>
  <p>The following 5-phase roadmap outlines a <strong>24-week (6-month) adoption pathway</strong> for BIDV to operationalize portfolio alignment assessment and transition stress testing for Decision 263 sectors.</p>

  <div class="phase-card">
    <h3>Phase 1: Data Preparation (Weeks 1–6)</h3>
    <p>Extract BIDV\'s Decision 263 portfolio exposure, collect emissions data from regulated clients (leveraging the 2025 GHG inventory mandate), map VSIC codes to PACTA sectors, and validate data quality through the BYOL intake pipeline.</p>
    <div class="deliverable"><strong>Deliverable:</strong> <code>normalized_loanbook.csv</code> — pipeline-ready dataset with zero blocking errors.</div>
  </div>

  <div class="phase-card">
    <h3>Phase 2: Baseline Establishment (Weeks 5–10)</h3>
    <p>Run PACTA alignment analysis on BIDV\'s Decision 263 portfolio. Produce sector-level alignment gaps for power (market share vs. PDP8/NZE), cement (SDA vs. emission intensity targets), and steel (SDA vs. targets). Cross-reference with PCAF financed emissions baseline.</p>
    <div class="deliverable"><strong>Deliverable:</strong> PACTA alignment report with sector gap tables and match coverage report.</div>
  </div>

  <div class="phase-card">
    <h3>Phase 3: Risk Assessment (Weeks 9–16)</h3>
    <p>Run TRISK transition stress tests for all three sectors. Produce borrower-level NPV change and PD change estimates. Run the sector prioritization module to rank sectors by composite alignment + stress + exposure score. Conduct sensitivity analysis across shock year, discount rate, and market passthrough.</p>
    <div class="deliverable"><strong>Deliverable:</strong> Sector prioritization ranking with borrower-level stress-test detail and sensitivity analysis.</div>
  </div>

  <div class="phase-card">
    <h3>Phase 4: Action Planning (Weeks 15–20)</h3>
    <p>Prioritize borrower engagement based on sector ranking and individual stress scores. Draft engagement communications requesting transition plans and capex commitments. Establish sector exposure limits. Integrate climate risk signals into BIDV\'s credit review process.</p>
    <div class="deliverable"><strong>Deliverable:</strong> Borrower engagement plan with sector-level exposure management strategy.</div>
  </div>

  <div class="phase-card">
    <h3>Phase 5: Monitoring &amp; Reporting (Weeks 19–24, then Quarterly)</h3>
    <p>Establish quarterly re-run schedule for PACTA alignment and TRISK stress testing. Track borrower progress against transition plans. Update Decision 263 compliance status. Prepare TCFD/ISSB S2-aligned disclosure materials. Report to BIDV board and SBV.</p>
    <div class="deliverable"><strong>Deliverable:</strong> Quarterly climate risk monitoring report and annual disclosure pack.</div>
  </div>

  <h3>Resource Requirements Summary</h3>
  <table>
    <tr><th>Phase</th><th>Duration</th><th>BIDV Staff</th><th>GTB Support</th></tr>
    <tr><td>1. Data Preparation</td><td>6 weeks</td><td>1 data analyst (PT)</td><td>Template + validation</td></tr>
    <tr><td>2. Baseline</td><td>6 weeks</td><td>1 quant analyst</td><td>PACTA pipeline run</td></tr>
    <tr><td>3. Risk Assessment</td><td>8 weeks</td><td>1 quant + risk review</td><td>TRISK pipeline run</td></tr>
    <tr><td>4. Action Planning</td><td>6 weeks</td><td>Credit + ESG teams</td><td>Advisory</td></tr>
    <tr><td>5. Monitoring</td><td>Ongoing</td><td>0.5–1 FTE ESG</td><td>Quarterly re-runs</td></tr>
  </table>

  <div class="callout callout-info">
    <strong>Full roadmap:</strong> The complete implementation roadmap (<code>docs/bidv_implementation_roadmap.md</code>) includes detailed activities, resource requirements, Decision 263 cross-references, integration guidance, a fast-track variant (16 weeks), and customization fields for BIDV to fill in during joint planning.
  </div>
</div>
')
}

# --- Section 9: Risk Register ---
section_risk_register <- {
  risks <- data.frame(
    risk_id = c("R-01", "R-02", "R-03", "R-04", "R-05", "R-06"),
    description = c(
      "Decision 263 clients may not have emissions data ready for collection",
      "ABCD matching may have low coverage for Vietnamese companies",
      "TRISK outputs are scenario-horizon stress summaries, not regulatory PDs",
      "PDP8/NDC pathways may differ from MONRE\'s final quota levels",
      "BIDV may not have dedicated ESG/quant staff for the recommended timeline",
      "Decision 263 implementing regulations may change during implementation"
    ),
    likelihood = c("Medium", "Medium", "Low", "Medium", "High", "Medium"),
    impact = c("High", "High", "Medium", "High", "High", "Medium"),
    mitigation = c(
      "Leverage 2025 GHG inventory mandate; follow up with non-responsive clients",
      "Manual review of unmatched borrowers; add intermediate parent names",
      "Clearly label outputs as comparative ranking tools, not credit model inputs",
      "Re-validate scenario data against MONRE guidelines before each re-run",
      "Present timeline as recommended; offer fast-track variant (16 weeks)",
      "Monitor MONRE regulatory updates; date-stamp all regulatory references"
    ),
    stringsAsFactors = FALSE
  )

  risk_rows <- apply(risks, 1, function(r) {
    paste0("<tr><td>", r["risk_id"], "</td><td>", r["description"], "</td><td>", r["likelihood"],
           "</td><td>", r["impact"], "</td><td>", r["mitigation"], "</td></tr>")
  })

  paste0('
<div class="section" id="risks">
  <h2>Risk Register</h2>
  <p>The following risks have been identified for the recommended implementation pathway, along with mitigation strategies:</p>

  <table>
    <tr><th>ID</th><th>Risk</th><th>Likelihood</th><th>Impact</th><th>Mitigation</th></tr>
    ', paste(risk_rows, collapse = ""), '
  </table>
</div>
')
}

# --- Section 10: Methodology Appendix ---
section_methodology <- {
  charts_html <- ""
  if (img_power_techmix != "") {
    charts_html <- paste0(charts_html, '
    <div class="chart-container">
      <img src="', img_power_techmix, '" alt="Power Technology Mix">
      <div class="chart-caption">Figure A1: Power sector technology mix — illustrative output from PACTA pipeline (MCB synthetic portfolio).</div>
    </div>')
  }
  if (img_trisk_npv != "") {
    charts_html <- paste0(charts_html, '
    <div class="chart-container">
      <img src="', img_trisk_npv, '" alt="NPV Change by Company">
      <div class="chart-caption">Figure A2: TRISK NPV change by company — illustrative output from power sector stress test (MCB synthetic portfolio).</div>
    </div>')
  }

  paste0('
<div class="section" id="methodology">
  <h2>Methodology Appendix</h2>

  <h3>PACTA Methodology</h3>
  <p>PACTA (Paris Agreement Capital Transition Assessment) measures whether a financial portfolio\'s real-economy exposure to climate-relevant sectors is consistent with Paris Agreement scenarios. Two analytical methods are used:</p>
  <ul>
    <li><strong>Market Share Approach:</strong> For power, the portfolio\'s weighted share of technology-level production (coal, gas, hydro, solar, wind) is compared against scenario targets (PDP8, NZE). Alignment means the portfolio\'s technology mix converges toward the scenario target over time.</li>
    <li><strong>Sectoral Decarbonization Approach (SDA):</strong> For cement and steel, the portfolio\'s weighted-average CO₂ emission intensity (tCO₂/tonne product) is compared against a scenario-derived convergence pathway. Alignment means the portfolio\'s intensity declines at the pace required by the scenario.</li>
  </ul>
  <p>The pipeline: (1) loanbook + ABCD asset database preparation, (2) fuzzy matching (min_score ≥ 0.8) with manual review of &lt;1.0 matches, (3) market share or SDA analysis, (4) alignment gap calculation.</p>

  <h3>TRISK Methodology</h3>
  <p>TRISK quantifies the financial impact of climate transition scenarios on individual borrowers\' creditworthiness using discounted cash flow (DCF) models:</p>
  <ul>
    <li><strong>NPV change:</strong> Difference in net present value of borrower cash flows between baseline and stress scenarios (carbon prices, commodity shifts, policy timing).</li>
    <li><strong>PD change:</strong> Change in probability of default derived from Merton-model credit risk estimation under stress.</li>
    <li><strong>Priority score:</strong> Composite ranking combining NPV impact, PD impact, and exposure size.</li>
  </ul>
  <p>Sensitivity analysis is available for key parameters: shock year, discount rate, risk-free rate, and market passthrough.</p>

  <h3>Sector Prioritization Scoring</h3>
  <p>Composite score = 0.35 × alignment + 0.35 × stress + 0.30 × exposure. All three dimensions are min-max normalized across sectors to handle different units (percentage points for power market share gaps, percent for cement/steel SDA gaps). Classification: Critical (≥0.8), High (≥0.5), Medium (≥0.2), Low (&lt;0.2).</p>

  <h3>Illustrative Pipeline Outputs</h3>
  <p>The charts below demonstrate the analytical outputs BIDV will see when the framework is run on their own data:</p>
  ', charts_html, '

  <div class="callout callout-danger">
    <strong>Important Disclaimer:</strong> TRISK probability of default (PD) changes are scenario-horizon stress summaries for comparative ranking purposes only. They are <strong>not regulatory PDs</strong> and should not be used as inputs to regulatory capital models. All charts in this appendix are based on synthetic portfolio data (MCB) and illustrative scenario assumptions.
  </div>

  <h3>Source Citations</h3>
  <ul>
    <li>PACTA: RMI (Rocky Mountain Institute), r2dii package ecosystem (r2dii.data, r2dii.match, r2dii.analysis, r2dii.plot) — CRAN</li>
    <li>TRISK: Baer et al. (2022), trisk.model R package — CRAN</li>
    <li>Decision 263: Quyết định 263/QĐ-TTg (2022), MONRE implementing regulations</li>
    <li>Scenarios: Vietnam PDP8, Vietnam NDC, IEA NZE 2050</li>
  </ul>
</div>
')
}

# ============================================================================
# SECTION 7: Assembly
# ============================================================================

cat("Assembling report...\n")

html <- paste0('<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>BIDV Framework Recommendation Report</title>
<style>', css, '</style>
</head>
<body>

', section_cover, '

<div class="container">

<!-- Table of Contents -->
<div class="toc">
  <h3>Contents</h3>
  <ol>
    <li><a href="#exec">Executive Summary</a></li>
    <li><a href="#context">BIDV Context</a></li>
    <li><a href="#framework">Framework Landscape</a></li>
    <li><a href="#recommendation">Framework Recommendation</a></li>
    <li><a href="#prioritization">Sector Prioritization</a></li>
    <li><a href="#decision263">Decision 263 Compliance Mapping</a></li>
    <li><a href="#roadmap">Implementation Roadmap</a></li>
    <li><a href="#risks">Risk Register</a></li>
    <li><a href="#methodology">Methodology Appendix</a></li>
  </ol>
</div>

', section_exec_summary, '
', section_bidv_context, '
', section_framework_landscape, '
', section_framework_recommendation, '
', section_sector_prioritization, '
', section_decision263, '
', section_implementation_roadmap, '
', section_risk_register, '
', section_methodology, '

</div><!-- /container -->

<div class="footer">
  BIDV Framework Recommendation Report &mdash; ', report_date, '<br>
  Prepared by GTB Advisory &nbsp;|&nbsp; Illustrative analysis using synthetic MCB portfolio<br>
  CONFIDENTIAL &mdash; For authorized recipients only. Not for public distribution.
</div>

</body>
</html>')

# ============================================================================
# SECTION 8: Write
# ============================================================================

dir.create("reports", showWarnings = FALSE, recursive = TRUE)
writeLines(html, output_path, useBytes = TRUE)

cat(sprintf("\nReport saved to: %s\n", normalizePath(output_path)))
cat(sprintf("File size: %.1f KB\n", file.info(output_path)$size / 1024))
cat("Done.\n")

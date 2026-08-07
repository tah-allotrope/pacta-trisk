library(testthat)

root <- project_root()
withr_wd <- setwd(root)
on.exit(setwd(withr_wd))
source(file.path(root, "scripts", "generate_coverage_report.R"))

# --- Fixture helpers ----------------------------------------------------------

.new_scratch_dir <- function() {
  path <- file.path(tempdir(), paste0(
    "coverage_report_", as.integer(Sys.time()), "_", sample.int(1e6, 1)
  ))
  dir.create(path, recursive = TRUE)
  path
}

.write_raw_loanbook <- function(path, ...) {
  rows <- list(...)
  utils::write.csv(dplyr::bind_rows(rows), path, row.names = FALSE)
}

.write_normalized <- function(path, id_loans, exposures, currencies = rep("VND", length(exposures)),
                              sectors = rep("3511", length(exposures))) {
  utils::write.csv(
    data.frame(
      id_loan = id_loans,
      name_direct_loantaker = sprintf("Counterparty %s", seq_along(id_loans)),
      loan_size_outstanding = exposures,
      loan_size_outstanding_currency = currencies,
      sector_classification_direct_loantaker = sectors,
      stringsAsFactors = FALSE
    ),
    path,
    row.names = FALSE
  )
}

.write_errors <- function(path, rows = integer(), columns = character(), messages = character()) {
  utils::write.csv(
    data.frame(row = rows, column = columns, error = messages, stringsAsFactors = FALSE),
    path,
    row.names = FALSE
  )
}

.write_warnings <- function(path, rows = integer(), classifications = character(), messages = character()) {
  utils::write.csv(
    data.frame(row = rows, column = "sector_code",
               classification = classifications, message = messages, stringsAsFactors = FALSE),
    path,
    row.names = FALSE
  )
}

test_that("build_reconciliation satisfies the row identity and pct sums to 100", {
  dir <- .new_scratch_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE))

  raw <- file.path(dir, "raw.csv")
  .write_raw_loanbook(raw,
    data.frame(counterparty_name = "A", exposure_vnd = 1e12, sector_code = "D3511",
               sector_code_system = "VSIC", credit_limit_vnd = 1.2e12, currency = "VND"),
    data.frame(counterparty_name = "B", exposure_vnd = 2e12, sector_code = "D3511",
               sector_code_system = "VSIC", credit_limit_vnd = 2.4e12, currency = "VND"),
    data.frame(counterparty_name = "C", exposure_vnd = 3e12, sector_code = "D9999",
               sector_code_system = "VSIC", credit_limit_vnd = 3.6e12, currency = "VND")
  )

  norm <- file.path(dir, "normalized_loanbook.csv")
  # Rows 2 and 3 survive; row 2 is a warned row (its id_loan maps to input row 2).
  .write_normalized(norm, id_loans = c("CL_L002", "CL_L003"), exposures = c(2e12, 3e12),
                    sectors = c("3511", "9999"))

  errs <- file.path(dir, "validation_errors.csv")
  .write_errors(errs, rows = 1L, columns = "exposure_vnd", messages = "negative exposure")

  warns <- file.path(dir, "validation_warnings.csv")
  .write_warnings(warns, rows = 3L, classifications = "sector_out_of_scope",
                  messages = "not in PACTA scope")

  rec <- build_reconciliation(raw, norm, errs, warns)

  # Identity, rows: submitted == normalized + dropped. Warned is a subset of
  # normalized and must not appear in the sum.
  expect_equal(rec$totals$submitted_rows, 3)
  expect_equal(rec$totals$normalized_rows, 2)
  expect_equal(rec$totals$dropped_rows, 1)
  expect_equal(rec$totals$warned_rows, 1)
  expect_equal(rec$totals$submitted_rows, rec$totals$normalized_rows + rec$totals$dropped_rows)

  # Identity, money (whole VND).
  expect_equal(rec$totals$submitted_vnd, 6e12)
  expect_equal(rec$totals$normalized_vnd, 5e12)
  expect_equal(rec$totals$dropped_vnd, 1e12)
  expect_equal(rec$totals$warned_vnd, 3e12)
  expect_lt(abs(rec$totals$submitted_vnd - (rec$totals$normalized_vnd + rec$totals$dropped_vnd)), 1)

  # pct_of_submitted_vnd sums to 100 within 0.01.
  expect_equal(sum(rec$rows$pct_of_submitted_vnd), 100, tolerance = 0.01)
})

test_that("build_reconciliation counts NA-exposure retained rows but zero VND for them", {
  dir <- .new_scratch_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE))

  raw <- file.path(dir, "raw.csv")
  .write_raw_loanbook(raw,
    data.frame(counterparty_name = "USD 1", exposure_vnd = 50000000000, sector_code = "D3511",
               sector_code_system = "VSIC", credit_limit_vnd = 6e10, currency = "USD"),
    data.frame(counterparty_name = "VND 1", exposure_vnd = 2e12, sector_code = "D3511",
               sector_code_system = "VSIC", credit_limit_vnd = 2.4e12, currency = "VND")
  )

  norm <- file.path(dir, "normalized_loanbook.csv")
  # The USD row is retained but its exposure is NA (no fx rate configured).
  .write_normalized(norm, id_loans = c("CL_L001", "CL_L002"), exposures = c(NA_real_, 2e12))

  errs <- file.path(dir, "validation_errors.csv")
  .write_errors(errs)

  warns <- file.path(dir, "validation_warnings.csv")
  .write_warnings(warns, rows = 1L, classifications = "unsupported_currency", messages = "not VND or USD")

  rec <- build_reconciliation(raw, norm, errs, warns)

  expect_equal(rec$totals$submitted_rows, 2)
  expect_equal(rec$totals$normalized_rows, 2)   # NA-exposure row still counts as a row
  expect_equal(rec$totals$dropped_rows, 0)
  expect_equal(rec$totals$warned_rows, 1)
  expect_equal(rec$totals$normalized_vnd, 2e12) # the NA row contributes 0
  expect_equal(rec$totals$submitted_vnd, 2e12)
  expect_lt(abs(rec$totals$submitted_vnd - (rec$totals$normalized_vnd + rec$totals$dropped_vnd)), 1)
})

test_that("build_abcd_coverage computes covered share and lists unmatched by name", {
  dir <- .new_scratch_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE))

  abcd <- file.path(dir, "abcd.csv")
  utils::write.csv(
    data.frame(name_company = c("EVN (Electricity of Vietnam)", "Nghi Son Power LLC"),
               stringsAsFactors = FALSE),
    abcd, row.names = FALSE
  )

  normalized <- data.frame(
    name_direct_loantaker = c("EVN (Electricity of Vietnam)", "Unmatched Alpha", "Nghi Son Power LLC"),
    loan_size_outstanding = c(1e12, 2e12, 3e12),
    sector_classification_direct_loantaker = c("3510", "3510", "3511"),
    stringsAsFactors = FALSE
  )

  cov <- build_abcd_coverage(normalized, abcd)
  expect_equal(cov$covered_vnd, 4e12)
  expect_equal(cov$coverage_pct, 66.67, tolerance = 0.01)
  expect_equal(nrow(cov$unmatched), 1)
  expect_equal(cov$unmatched$name_direct_loantaker[1], "Unmatched Alpha")
  expect_equal(cov$unmatched$exposure_vnd[1], 2e12)
})

test_that("build_abcd_coverage returns 0 (not NaN) for an empty normalized loanbook", {
  dir <- .new_scratch_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE))

  abcd <- file.path(dir, "abcd.csv")
  utils::write.csv(
    data.frame(name_company = "EVN (Electricity of Vietnam)", stringsAsFactors = FALSE),
    abcd, row.names = FALSE
  )

  normalized <- data.frame(
    name_direct_loantaker = character(0),
    loan_size_outstanding = numeric(0),
    sector_classification_direct_loantaker = character(0),
    stringsAsFactors = FALSE
  )

  cov <- build_abcd_coverage(normalized, abcd)
  expect_equal(cov$covered_vnd, 0)
  expect_equal(cov$coverage_pct, 0)
  expect_equal(nrow(cov$unmatched), 0)
})

test_that("ABCD matching is diacritic-insensitive via normalize_vn_name", {
  dir <- .new_scratch_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE))

  abcd <- file.path(dir, "abcd.csv")
  utils::write.csv(
    data.frame(name_company = "Nhiệt Điện Vĩnh Tân 1 JSC", stringsAsFactors = FALSE),
    abcd, row.names = FALSE
  )

  normalized <- data.frame(
    name_direct_loantaker = "Nhiet Dien Vinh Tan 1 JSC",
    loan_size_outstanding = 5e11,
    sector_classification_direct_loantaker = "3511",
    stringsAsFactors = FALSE
  )

  cov <- build_abcd_coverage(normalized, abcd)
  expect_equal(cov$covered_vnd, 5e11)
  expect_equal(cov$coverage_pct, 100)
  expect_equal(nrow(cov$unmatched), 0)
})

test_that("write_coverage_metrics writes the required keys with a by_sector object", {
  dir <- .new_scratch_dir()
  on.exit(unlink(dir, recursive = TRUE, force = TRUE))

  rec <- list(
    totals = list(
      submitted_rows = 3, submitted_vnd = 6e12,
      normalized_rows = 2, normalized_vnd = 5e12,
      dropped_rows = 1, dropped_vnd = 1e12,
      warned_rows = 1, warned_vnd = 3e12
    )
  )
  cov <- list(
    covered_vnd = 4e12,
    coverage_pct = 66.67,
    by_sector = data.frame(
      sector = c("power", "not in scope"),
      exposure_vnd = c(4e12, 2e12),
      covered_vnd = c(4e12, 0),
      coverage_pct = c(100, 0),
      stringsAsFactors = FALSE
    )
  )

  out <- file.path(dir, "coverage_metrics.json")
  write_coverage_metrics(rec, cov, out)

  m <- jsonlite::read_json(out)
  expected_keys <- c(
    "submitted_rows", "submitted_vnd", "normalized_rows", "normalized_vnd",
    "dropped_rows", "dropped_vnd", "warned_rows", "warned_vnd",
    "abcd_covered_vnd", "abcd_coverage_pct", "by_sector"
  )
  expect_true(all(expected_keys %in% names(m)))
  expect_equal(m$abcd_coverage_pct, 66.67)
  expect_equal(m$by_sector$power$coverage_pct, 100)
})

test_that("SDB dry-run step list places coverage_report immediately after validation_report", {
  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) rscript <- "C:/Program Files/R/R-4.5.2/bin/Rscript.exe"
  skip_if(!nzchar(rscript) && !file.exists(rscript), "Rscript not found on PATH")

  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  config <- file.path(root, "engagements", "sdb-rehearsal", "engagement_config.json")
  skip_if_not(file.exists(config), "sdb-rehearsal engagement_config.json not present")

  out <- system2(
    rscript,
    args = c("scripts/run_engagement.R", "--config", config, "--dry-run"),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  expect_equal(status, 0L)

  step_lines <- out[grepl("^[a-z_]+: ", out)]
  step_names <- sub(":.*$", "", step_lines)

  validation_idx <- which(step_names == "validation_report")
  coverage_idx <- which(step_names == "coverage_report")
  expect_length(coverage_idx, 1)
  expect_equal(coverage_idx, validation_idx + 1L)
})

test_that("MCB dry-run step list does not include coverage_report (no raw loanbook)", {
  rscript <- Sys.which("Rscript")
  if (!nzchar(rscript)) rscript <- "C:/Program Files/R/R-4.5.2/bin/Rscript.exe"
  skip_if(!nzchar(rscript) && !file.exists(rscript), "Rscript not found on PATH")

  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  config <- file.path(root, "engagements", "mcb-demo", "engagement_config.json")
  skip_if_not(file.exists(config), "mcb-demo engagement_config.json not present")

  out <- system2(
    rscript,
    args = c("scripts/run_engagement.R", "--config", config, "--dry-run"),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  expect_equal(status, 0L)
  expect_false(any(grepl("^coverage_report:", out)))
})

test_that("SDB coverage_metrics.json on the committed tree satisfies the row and money identities", {
  metrics_path <- file.path(root, "engagements", "sdb-rehearsal", "intake", "coverage_metrics.json")
  skip_if_not(file.exists(metrics_path), "SDB coverage_metrics.json not generated yet")

  m <- jsonlite::read_json(metrics_path)
  expect_equal(m$submitted_rows, m$normalized_rows + m$dropped_rows)
  expect_lt(abs(m$submitted_vnd - (m$normalized_vnd + m$dropped_vnd)), 1)
})

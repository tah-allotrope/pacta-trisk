library(testthat)

# --- Function-level specs (PHASE-05): these are tested directly by sourcing
# the intake script, whose CLI pipeline is guarded by sys.nframe() == 0 so the
# pure helpers are available without executing the whole run.
root <- project_root()
withr_wd <- setwd(root)
on.exit(setwd(withr_wd))
source("scripts/intake_validate_and_map.R")

test_that("normalize_sector_code preserves VSIC 5-digit sub-classes and pads only short codes", {
  expect_equal(normalize_sector_code("D3510", "VSIC"), "3510")
  expect_equal(normalize_sector_code("D35101", "VSIC"), "35101")
  expect_equal(normalize_sector_code("351", "VSIC"), "0351")
  expect_equal(normalize_sector_code("D35X1", "VSIC"), NA_character_)
  expect_equal(normalize_sector_code("2410", "ISIC"), "2410")
})

test_that("map_sector_code covers the widened accepted-code table", {
  expect_equal(map_sector_code("3510"), "power")
  expect_equal(map_sector_code("35102"), "power")
  expect_equal(map_sector_code("3511"), "power")
  expect_equal(map_sector_code("29101"), "automotive")
  expect_equal(map_sector_code("23941"), "cement")
  expect_equal(map_sector_code("24102"), "steel")
  expect_equal(map_sector_code("05101"), "coal")
  expect_equal(map_sector_code("0610"), "oil and gas")
  expect_equal(map_sector_code("9999"), "not in scope")
})

test_that("convert_to_vnd converts, passes through, and errors correctly", {
  expect_equal(convert_to_vnd(1000, "VND", 26300), 1000)
  expect_equal(convert_to_vnd(1000, "USD", 26300), 26300000)
  expect_equal(convert_to_vnd(1000, "EUR", 26300), NA_real_)
  expect_error(convert_to_vnd(1000, "USD", NULL), "fx_rate_usd_vnd")
  expect_error(convert_to_vnd(1000, "USD", -5), "fx_rate_usd_vnd")
})

test_that("intake script handles dirty fixture correctly", {
  root <- project_root()
  fixture <- file.path(root, "data", "fixtures", "unseen_bank_loanbook.csv")
  skip_if_not(file.exists(fixture), "fixture not found")

  out_dir <- file.path(root, "intake", "output_test_fixture")
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  old_wd <- getwd()
  setwd(root)
  on.exit(setwd(old_wd), add = TRUE)

  exit_code <- system2(
    "Rscript",
    args = c(
      "scripts/intake_validate_and_map.R",
      "--input", fixture,
      "--output-dir", out_dir,
      "--fx-rate-usd-vnd", "26300"
    ),
    stdout = TRUE, stderr = TRUE
  )

  expect_true(file.exists(file.path(out_dir, "validation_errors.csv")))
  errors <- read.csv(file.path(out_dir, "validation_errors.csv"), stringsAsFactors = FALSE)
  expect_gte(nrow(errors), 6)

  has_credit_limit <- any(grepl("credit_limit_vnd", errors$column))
  has_sector_code <- any(grepl("sector_code", errors$column))
  has_negative_exp <- any(grepl("exposure_vnd.*negative", errors$error))
  has_duplicate <- any(grepl("duplicate", errors$column))

  expect_true(has_credit_limit, info = "Should catch credit_limit_vnd errors")
  expect_true(has_sector_code, info = "Should catch sector_code errors")
  expect_true(has_negative_exp, info = "Should catch negative exposure_vnd")
  expect_true(has_duplicate, info = "Should catch duplicate rows")

  # Widenings (PHASE-05): the seven D3510 power rows and the Z9999 row are no
  # longer hard errors -- they are retained (as power and "not in scope"
  # respectively), so the normalized loanbook gains them: at least 30 rows, up
  # from 24.
  loanbook <- read.csv(file.path(out_dir, "normalized_loanbook.csv"), stringsAsFactors = FALSE)
  expect_equal(ncol(loanbook), 13)
  expect_gte(nrow(loanbook), 30)
  expect_true(all(loanbook$loan_size_outstanding_currency == "VND" | is.na(loanbook$loan_size_outstanding_currency)))

  # USD rows are converted (not dropped) when a rate is configured.
  warnings <- read.csv(file.path(out_dir, "validation_warnings.csv"), stringsAsFactors = FALSE)
  expect_true("classification" %in% names(warnings))
  expect_gt(nrow(warnings), 0)
  expect_true(any(warnings$classification == "fx_converted"),
              info = "USD rows should be flagged fx_converted when a rate is configured")
  usd_names <- loanbook$name_direct_loantaker[grepl("USD Exposure", loanbook$name_direct_loantaker)]
  expect_length(usd_names, 2)
})

test_that("intake exits non-zero and retains NA-exposure USD rows when no fx rate is configured", {
  root <- project_root()
  fixture <- file.path(root, "data", "fixtures", "unseen_bank_loanbook.csv")
  skip_if_not(file.exists(fixture), "fixture not found")

  out_dir <- file.path(root, "intake", "output_test_norate")
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  old_wd <- getwd()
  setwd(root)
  on.exit(setwd(old_wd), add = TRUE)

  out <- system2(
    "Rscript",
    args = c(
      "scripts/intake_validate_and_map.R",
      "--input", fixture,
      "--output-dir", out_dir
    ),
    stdout = TRUE, stderr = TRUE
  )
  status <- attr(out, "status")
  if (is.null(status)) status <- 0L
  expect_equal(status, 1L, info = "missing fx rate must exit non-zero")

  expect_true(file.exists(file.path(out_dir, "validation_warnings.csv")))
  warnings <- read.csv(file.path(out_dir, "validation_warnings.csv"), stringsAsFactors = FALSE)
  expect_true(any(warnings$classification == "fx_rate_missing"),
              info = "USD rows should be flagged fx_rate_missing without a rate")

  # The row is retained, but its exposure is NA so it is visibly excluded from
  # money totals rather than silently counted at the wrong scale.
  loanbook <- read.csv(file.path(out_dir, "normalized_loanbook.csv"), stringsAsFactors = FALSE)
  usd_rows <- loanbook[grepl("USD Exposure", loanbook$name_direct_loantaker), ]
  expect_equal(nrow(usd_rows), 2)
  expect_true(all(is.na(usd_rows$loan_size_outstanding)))
})

test_that("intake --anonymize produces zero real names in output", {
  root <- project_root()
  fixture <- file.path(root, "data", "fixtures", "unseen_bank_loanbook.csv")
  skip_if_not(file.exists(fixture), "fixture not found")

  out_dir <- file.path(root, "intake", "output_test_anon")
  on.exit(unlink(out_dir, recursive = TRUE), add = TRUE)

  old_wd <- getwd()
  setwd(root)
  on.exit(setwd(old_wd), add = TRUE)

  system2(
    "Rscript",
    args = c(
      "scripts/intake_validate_and_map.R",
      "--input", fixture,
      "--output-dir", out_dir,
      "--fx-rate-usd-vnd", "26300",
      "--anonymize"
    ),
    stdout = TRUE, stderr = TRUE
  )

  loanbook <- read.csv(file.path(out_dir, "normalized_loanbook.csv"), stringsAsFactors = FALSE)
  real_names <- c("VinFast", "Hoa Phat", "EVN", "Vinacomin", "THACO")
  for (name in real_names) {
    expect_false(
      any(grepl(name, loanbook$name_direct_loantaker, fixed = TRUE)),
      info = sprintf("Real name '%s' should not appear in anonymized output", name)
    )
  }

  expect_true(file.exists(file.path(out_dir, "pseudonym_map.csv")))
  pseudo_map <- read.csv(file.path(out_dir, "pseudonym_map.csv"), stringsAsFactors = FALSE)
  expect_gt(nrow(pseudo_map), 0)
})

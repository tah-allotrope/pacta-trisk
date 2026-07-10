library(testthat)

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
      "--output-dir", out_dir
    ),
    stdout = TRUE, stderr = TRUE
  )

  expect_true(file.exists(file.path(out_dir, "validation_errors.csv")))
  errors <- read.csv(file.path(out_dir, "validation_errors.csv"), stringsAsFactors = FALSE)
  expect_gte(nrow(errors), 8)

  has_credit_limit <- any(grepl("credit_limit_vnd", errors$column))
  has_sector_code <- any(grepl("sector_code", errors$column))
  has_negative_exp <- any(grepl("exposure_vnd.*negative", errors$error))
  has_duplicate <- any(grepl("duplicate", errors$column))

  expect_true(has_credit_limit, info = "Should catch credit_limit_vnd errors")
  expect_true(has_sector_code, info = "Should catch sector_code errors")
  expect_true(has_negative_exp, info = "Should catch negative exposure_vnd")
  expect_true(has_duplicate, info = "Should catch duplicate rows")

  loanbook <- read.csv(file.path(out_dir, "normalized_loanbook.csv"), stringsAsFactors = FALSE)
  expect_equal(ncol(loanbook), 13)
  expect_lt(nrow(loanbook), 40)
  expect_true(all(loanbook$loan_size_outstanding_currency == "VND" | is.na(loanbook$loan_size_outstanding_currency)))
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

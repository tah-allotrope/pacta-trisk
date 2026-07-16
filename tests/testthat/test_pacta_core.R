library(testthat)
suppressPackageStartupMessages({
  library(dplyr)
  library(tibble)
  library(r2dii.data)
  library(ggplot2)
  library(scales)
})

root <- project_root()
source(file.path(root, "R", "matching_helpers.R"))
source(file.path(root, "R", "report_toolkit.R"))
source(file.path(root, "R", "pacta_core.R"))

# --- pacta_prejoin_sectors ---------------------------------------------------

test_that("pacta_prejoin_sectors maps ISIC codes to PACTA sectors", {
  loanbook <- tibble(
    id_loan = c("L1", "L2"),
    id_direct_loantaker = c("D1", "D2"),
    name_direct_loantaker = c("Power Co", "Auto Co"),
    id_ultimate_parent = c("D1", "D2"),
    name_ultimate_parent = c("Power Co", "Auto Co"),
    loan_size_outstanding = c(1000, 2000),
    loan_size_outstanding_currency = c("VND", "VND"),
    loan_size_credit_limit = c(1000, 2000),
    loan_size_credit_limit_currency = c("VND", "VND"),
    sector_classification_system = c("ISIC", "ISIC"),
    sector_classification_direct_loantaker = c("3511", "2910"),
    lei_direct_loantaker = c(NA_character_, NA_character_),
    isin_direct_loantaker = c(NA_character_, NA_character_)
  )

  result <- pacta_prejoin_sectors(loanbook)

  expect_equal(
    result$sector_classified[result$sector_classification_direct_loantaker == "3511"],
    "power"
  )
  expect_equal(
    result$sector_classified[result$sector_classification_direct_loantaker == "2910"],
    "automotive"
  )
})

# --- pacta_coverage -----------------------------------------------------------

test_that("pacta_coverage computes matched exposure fraction from raw VND weights", {
  loanbook_classified <- tibble(
    sector_classified = rep("power", 3),
    loan_size_outstanding = c(100, 200, 300)
  )
  matched <- tibble(
    sector = rep("power", 2),
    loan_size_outstanding = c(100, 200)
  )

  tmp_dir <- tempfile()
  dir.create(tmp_dir)
  on.exit(unlink(tmp_dir, recursive = TRUE))

  coverage <- pacta_coverage(loanbook_classified, matched, tmp_dir, "Test Bank", "TB")

  power_row <- coverage[coverage$sector_classified == "power", ]
  expect_equal(power_row$match_pct, 50, tolerance = 1e-9)
  expect_true(file.exists(file.path(tmp_dir, "03_vn_coverage_pie.png")))
})

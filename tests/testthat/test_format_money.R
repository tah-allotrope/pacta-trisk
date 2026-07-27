library(testthat)

root <- project_root()
source(file.path(root, "R", "format_money.R"))

test_that("format_vnd_full formats whole-VND figures with comma separators", {
  expect_equal(format_vnd_full(1030000000000), "1,030,000,000,000 VND")
  expect_equal(format_vnd_full(0), "0 VND")
  expect_equal(format_vnd_full(NA_real_), "Not available")
})

test_that("format_vnd_bn formats in billions of VND", {
  expect_equal(format_vnd_bn(1030000000000), "1,030.0 bn VND")
  expect_equal(format_vnd_bn(25020000000000), "25,020.0 bn VND")
  expect_equal(format_vnd_bn(500000000, digits = 3), "0.500 bn VND")
  expect_equal(format_vnd_bn(NA_real_), "Not available")
})

test_that("vnd_to_billion converts and propagates NA", {
  expect_equal(vnd_to_billion(2.5e12), 2500)
  expect_true(is.na(vnd_to_billion(NA_real_)))
})

test_that("format_vnd_full does not overflow for trillions-scale VND figures", {
  # formatC(x, format = "d") coerces via as.integer(), which silently
  # overflows past 2^31 - 1 (~2.1e9) -- a real risk once the MCB loanbook
  # is true VND (Wave 2 PHASE-02, U1). Confirm the fix holds for a value
  # well beyond that boundary.
  expect_equal(format_vnd_full(25020000000000), "25,020,000,000,000 VND")
})

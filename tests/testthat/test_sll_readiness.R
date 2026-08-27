library(testthat)

root <- project_root()
source(file.path(root, "R", "severity_scoring.R"))
source(file.path(root, "R", "sll_readiness.R"))

test_that("sll_readiness_score with a relationship signal matches the weighted-mean formula", {
  # materiality = mean(0.8, 0.6) = 0.7
  # exposure_severity(1.5e12) on breakpoints 2.5e11,8e11,1.5e12,3e12,5.77e12 = 0.5 exactly (3rd breakpoint)
  score <- sll_readiness_score(0.8, 0.6, 1.5e12, TRUE, 0.5)
  expected <- (0.30 * 0.7 + 0.25 * 0.5 + 0.25 * 1.0 + 0.20 * 0.5) / 1.0
  expect_equal(score, expected, tolerance = 1e-9)
})

test_that("sll_readiness_score without a relationship signal renormalizes the remaining weights", {
  score <- sll_readiness_score(0.8, 0.6, 1.5e12, TRUE, NA_real_)
  expected <- (0.30 * 0.7 + 0.25 * 0.5 + 0.25 * 1.0) / 0.80
  expect_equal(score, expected, tolerance = 1e-9)
})

test_that("sll_readiness_score falls back to severity_alignment alone when severity_trisk is NA", {
  score <- sll_readiness_score(0.8, NA_real_, 1.5e12, TRUE, 0.5)
  expected <- (0.30 * 0.8 + 0.25 * 0.5 + 0.25 * 1.0 + 0.20 * 0.5) / 1.0
  expect_equal(score, expected, tolerance = 1e-9)
})

test_that("sll_readiness_band thresholds match the documented (MCB-calibrated) breakpoints", {
  expect_equal(sll_readiness_band(0.75), "Ready")
  expect_equal(sll_readiness_band(0.7499), "Near-ready")
  expect_equal(sll_readiness_band(0.70), "Near-ready")
  expect_equal(sll_readiness_band(0.6999), "Developing")
  expect_equal(sll_readiness_band(0.50), "Developing")
  expect_equal(sll_readiness_band(0.4999), "Not ready")
})

.small_priority <- function() {
  data.frame(
    name_abcd = c("Coal Co", "Solar Co", "Auto Co"),
    sector = c("power", "power", "automotive"),
    exposure_vnd = c(1e12, 5e10, 2e11),
    severity_alignment = c(0.9, 0.3, 0.5),
    severity_trisk = c(0.95, 0.1, NA_real_),
    stringsAsFactors = FALSE
  )
}
.small_abcd_for_sll <- function() {
  data.frame(name_company = c("Coal Co", "Solar Co"), stringsAsFactors = FALSE)
}

test_that("sll_readiness marks data_availability 0 for a borrower with no ABCD match", {
  out <- sll_readiness(.small_priority(), .small_abcd_for_sll(), overlay = NULL)
  auto_row <- out[out$name_abcd == "Auto Co", ]
  expect_equal(auto_row$data_availability, 0L)
  coal_row <- out[out$name_abcd == "Coal Co", ]
  expect_equal(coal_row$data_availability, 1L)
})

test_that("sll_readiness is sorted by readiness descending and readiness_partial is TRUE with no overlay", {
  out <- sll_readiness(.small_priority(), .small_abcd_for_sll(), overlay = NULL)
  expect_true(all(diff(out$readiness) <= 0))
  expect_true(all(out$readiness_partial))
  expect_true(all(out$analyst_rationale == ""))
})

test_that("sll_readiness applies the relationship overlay when present, per matched borrower", {
  overlay <- data.frame(name_abcd = "Coal Co", relationship_score = 0.9, stringsAsFactors = FALSE)
  out <- sll_readiness(.small_priority(), .small_abcd_for_sll(), overlay = overlay)

  coal_row <- out[out$name_abcd == "Coal Co", ]
  expect_false(coal_row$readiness_partial)
  expect_equal(coal_row$relationship, 0.9)

  solar_row <- out[out$name_abcd == "Solar Co", ]
  expect_true(solar_row$readiness_partial)
  expect_true(is.na(solar_row$relationship))
})

library(testthat)

root <- project_root()
source(file.path(root, "R", "severity_scoring.R"))

test_that("severity_from_anchors interpolates, saturates, and clamps", {
  expect_equal(severity_from_anchors(10, c(0, 5, 10, 20, 40)), 0.50)
  expect_equal(severity_from_anchors(14.39, c(0, 5, 10, 20, 40)), 0.60975, tolerance = 1e-4)
  expect_equal(severity_from_anchors(1000, c(0, 5, 10, 20, 40)), 1.0)
  expect_equal(severity_from_anchors(-3, c(0, 5, 10, 20, 40)), 0.0)
  expect_true(is.na(severity_from_anchors(NA_real_, c(0, 5, 10, 20, 40))))
  expect_equal(severity_from_anchors(c(0, 5, 40), c(0, 5, 10, 20, 40)), c(0, 0.25, 1))
})

test_that("severity_from_anchors errors on non-ascending breakpoints", {
  expect_error(severity_from_anchors(5, c(0, 5, 5, 20, 40)))
})

test_that("severity_from_anchors errors when anchors_x and anchors_y lengths differ", {
  expect_error(severity_from_anchors(5, c(0, 5, 10, 20, 40), c(0, 1)))
})

test_that("severity_alignment uses the sector-appropriate table and abs()", {
  expect_equal(severity_alignment(2.1, "sda_intensity"), 0.2583, tolerance = 1e-4)
  expect_equal(severity_alignment(7.2, "sda_intensity"), 0.61, tolerance = 1e-4)
  expect_equal(severity_alignment(25.821596244131456, "market_share"), 0.8228, tolerance = 1e-4)
  expect_equal(severity_alignment(-14.39, "market_share"), 0.60975, tolerance = 1e-4)
  expect_error(severity_alignment(5, "emissions"), "emissions")
})

test_that("severity_trisk scores loss, not npv_change directly", {
  expect_equal(severity_trisk(-0.980411177362964), 1.0)
  expect_equal(severity_trisk(-0.15), 0.50)
  expect_equal(severity_trisk(0.000870), 0.0)
  expect_true(is.na(severity_trisk(NA_real_)))
})

test_that("severity_exposure treats share as a fraction, not a percentage", {
  expect_equal(severity_exposure(0.8183705241307733), 1.0)
  expect_equal(severity_exposure(0.1038), 0.3845, tolerance = 1e-4)
  expect_equal(severity_exposure(0), 0.0)
})

test_that("alignment_basis_for_sector maps sectors and errors on unknown ones", {
  expect_equal(alignment_basis_for_sector("power"), "market_share")
  expect_equal(alignment_basis_for_sector("automotive"), "market_share")
  expect_equal(alignment_basis_for_sector("cement"), "sda_intensity")
  expect_equal(alignment_basis_for_sector("steel"), "sda_intensity")
  expect_error(alignment_basis_for_sector("coal"), "coal")
})

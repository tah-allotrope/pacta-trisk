library(testthat)

test_that("engagement priority has expected golden numbers", {
  root <- project_root()
  ep_path <- file.path(root, "output", "engagement", "engagement_priority.csv")
  skip_if_not(file.exists(ep_path), "engagement_priority.csv not found")

  ep <- read.csv(ep_path, stringsAsFactors = FALSE)

  expect_equal(nrow(ep), 23, info = "engagement_priority.csv should have 23 rows")

  expect_equal(ep$name_abcd[1], "Nghi Son Power LLC")
  expect_equal(ep$composite_score[1], 1.0, tolerance = 1e-6)

  expect_equal(ep$name_abcd[2], "Vinacomin Power JSC")
  expect_equal(ep$composite_score[2], 0.998, tolerance = 0.005)

  expect_equal(ep$name_abcd[3], "International Power Mong Duong")
  expect_equal(ep$composite_score[3], 0.996, tolerance = 0.005)
})

test_that("TRISK top borrowers has expected top company", {
  root <- project_root()
  tb_path <- file.path(root, "dashboard", "data", "trisk", "power", "top_borrowers_alignment_trisk.csv")
  skip_if_not(file.exists(tb_path), "top_borrowers_alignment_trisk.csv not found")

  tb <- read.csv(tb_path, stringsAsFactors = FALSE)
  expect_equal(tb$company_name[1], "Nghi Son Power LLC")
})

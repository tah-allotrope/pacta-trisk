library(testthat)

test_that("engagement priority has expected golden numbers", {
  root <- project_root()
  ep_path <- file.path(root, "output", "engagement", "engagement_priority.csv")
  skip_if_not(file.exists(ep_path), "engagement_priority.csv not found")

  ep <- read.csv(ep_path, stringsAsFactors = FALSE)

  expect_equal(nrow(ep), 23, info = "engagement_priority.csv should have 23 rows")

  expect_equal(ep$name_abcd[1], "Nghi Son Power LLC")
  # Wave 2 PHASE-03/04: composite_score is now an absolute severity from
  # docs/scoring_anchors.md, not a min-max rescale -- this value is
  # falsifiable (it does NOT hold "for any input" the way the pre-PHASE-03
  # tautological 1.0 did).
  expect_equal(ep$composite_score[1], 0.9113849765258216, tolerance = 1e-4)

  expect_equal(ep$name_abcd[2], "Vinacomin Power JSC")
  expect_equal(ep$composite_score[2], 0.9113849765258216, tolerance = 1e-4)

  expect_equal(ep$name_abcd[3], "International Power Mong Duong")
  expect_equal(ep$composite_score[3], 0.9113849765258216, tolerance = 1e-4)

  # Wave 2 PHASE-04, TASK-04-05: regression guard against a min-max
  # normalization being reintroduced anywhere upstream -- under min-max the
  # top score is always exactly 1.0 and the bottom always exactly 0.0.
  expect_true(all(ep$composite_score > 0 & ep$composite_score < 1))
})

test_that("MCB and SDB top sector composite scores now differ", {
  # Wave 2 PHASE-04, TASK-04-07: under the old min-max normalization both
  # banks' top sector composite_score was exactly 1.0 regardless of how
  # structurally different their portfolios were. Under absolute severity
  # scoring, MCB's power sector (exposure_share 0.818) and SDB's power
  # sector (exposure_share 0.596, larger alignment gap) now produce
  # genuinely different composite scores.
  root <- project_root()
  mcb_path <- file.path(root, "synthesis_output", "prioritization", "sector_priority_ranking.csv")
  sdb_path <- file.path(root, "engagements", "sdb-rehearsal", "output", "prioritization", "sector_priority_ranking.csv")
  skip_if_not(file.exists(mcb_path), "MCB sector_priority_ranking.csv not found")
  skip_if_not(file.exists(sdb_path), "SDB sector_priority_ranking.csv not found")

  mcb <- read.csv(mcb_path, stringsAsFactors = FALSE)
  sdb <- read.csv(sdb_path, stringsAsFactors = FALSE)

  mcb_top <- max(mcb$composite_score)
  sdb_top <- max(sdb$composite_score)

  expect_gt(abs(mcb_top - sdb_top), 0.01)
})

test_that("TRISK top borrowers has expected top company", {
  root <- project_root()
  tb_path <- file.path(root, "dashboard", "data", "trisk", "power", "top_borrowers_alignment_trisk.csv")
  skip_if_not(file.exists(tb_path), "top_borrowers_alignment_trisk.csv not found")

  tb <- read.csv(tb_path, stringsAsFactors = FALSE)
  expect_equal(tb$company_name[1], "Nghi Son Power LLC")
})

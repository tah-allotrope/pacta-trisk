library(testthat)

root <- project_root()
source(file.path(root, "R", "format_money.R"))
source(file.path(root, "R", "severity_scoring.R"))
source(file.path(root, "R", "prioritization_core.R"))

# --- Fixture helpers ----------------------------------------------------------
# prioritize_sectors() resolves every path via getwd() (base_dir <- getwd()),
# so the fixture must be built as a real tree and the working directory
# temporarily switched into it, mirroring how the function is actually
# invoked from scripts/sector_prioritization.R.

.new_prioritization_fixture <- function(sectors = c("power", "cement")) {
  fixture_root <- file.path(tempdir(), paste0(
    "prioritization_core_", as.integer(Sys.time()), "_", sample.int(1e6, 1)
  ))
  pacta_dir <- file.path(fixture_root, "synthesis_output", "vietnam")
  trisk_dir <- file.path(fixture_root, "dashboard", "data", "trisk")
  prioritization_dir <- file.path(fixture_root, "synthesis_output", "prioritization")
  dir.create(pacta_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(prioritization_dir, recursive = TRUE, showWarnings = FALSE)

  # --- Alignment gaps -----------------------------------------------------
  ms_align <- data.frame(
    sector = "power",
    technology = "coalcap",
    share_gap_pp = 14.39,
    stringsAsFactors = FALSE
  )
  utils::write.csv(ms_align, file.path(pacta_dir, "06_vn_ms_alignment_2030.csv"), row.names = FALSE)

  sda_align <- data.frame(
    sector = "cement",
    gap_pct = 2.1,
    stringsAsFactors = FALSE
  )
  utils::write.csv(sda_align, file.path(pacta_dir, "06_vn_sda_alignment_2030.csv"), row.names = FALSE)

  # --- TRISK borrower results ----------------------------------------------
  dir.create(file.path(trisk_dir, "power"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(company_id = "P1", company_name = "Power Borrower", sector = "power",
               npv_change = -0.50, stress_priority_score = 100, stringsAsFactors = FALSE),
    file.path(trisk_dir, "power", "top_borrowers_alignment_trisk.csv"), row.names = FALSE
  )
  dir.create(file.path(trisk_dir, "cement"), recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    data.frame(company_id = "C1", company_name = "Cement Borrower", sector = "cement",
               npv_change = -0.10, stress_priority_score = 0, stringsAsFactors = FALSE),
    file.path(trisk_dir, "cement", "top_borrowers_alignment_trisk.csv"), row.names = FALSE
  )

  # --- Loanbook: 800bn power / 200bn cement -> exposure_share 0.80 / 0.20 --
  loanbook <- data.frame(
    loan_size_outstanding = c(800000000000, 200000000000),
    sector_classification_direct_loantaker = c("3511", "2394"),
    stringsAsFactors = FALSE
  )
  data_dir <- file.path(fixture_root, "data")
  dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(loanbook, file.path(data_dir, "loanbook.csv"), row.names = FALSE)

  cfg <- list(
    bank_name = "Test Bank",
    bank_slug = "test-bank",
    trisk_sectors = sectors,
    inputs = list(loanbook_csv = "data/loanbook.csv"),
    paths = list(
      pacta_output_dir = "synthesis_output/vietnam",
      snapshot_dir = "dashboard/data",
      prioritization_output_dir = "synthesis_output/prioritization"
    )
  )

  list(fixture_root = fixture_root, cfg = cfg)
}

.with_fixture_wd <- function(fixture_root, code) {
  old_wd <- getwd()
  on.exit({
    setwd(old_wd)
    unlink(fixture_root, recursive = TRUE, force = TRUE)
  }, add = TRUE)
  setwd(fixture_root)
  force(code)
}

# --- Worked example (Wave 2 plan Specification S4) ---------------------------

test_that("prioritize_sectors reproduces the plan's worked example exactly", {
  fx <- .new_prioritization_fixture(c("power", "cement"))
  result <- .with_fixture_wd(fx$fixture_root, {
    suppressWarnings(prioritize_sectors(fx$cfg))
  })

  power <- result[result$sector == "power", ]
  cement <- result[result$sector == "cement", ]

  expect_equal(power$alignment_score, 0.60975, tolerance = 1e-4)
  expect_equal(power$stress_score, 0.91667, tolerance = 1e-4)
  expect_equal(power$exposure_score, 1.0, tolerance = 1e-4)
  expect_equal(power$composite_score, 0.83425, tolerance = 1e-4)
  expect_equal(unname(power$priority_band), "Critical")

  expect_equal(cement$alignment_score, 0.25833, tolerance = 1e-4)
  expect_equal(cement$stress_score, 0.375, tolerance = 1e-4)
  expect_equal(cement$exposure_score, 0.58333, tolerance = 1e-4)
  expect_equal(cement$composite_score, 0.39667, tolerance = 1e-4)
  expect_equal(unname(cement$priority_band), "Medium")
})

# --- Degeneracy check: the point of the whole phase ---------------------------

test_that("prioritize_sectors is non-degenerate for a single-sector config", {
  fx <- .new_prioritization_fixture(c("power"))
  result <- .with_fixture_wd(fx$fixture_root, {
    suppressWarnings(prioritize_sectors(fx$cfg))
  })

  expect_true(all(result$composite_score > 0 & result$composite_score < 1))
})

# --- TASK-03-06: explicit error for an unmapped sector, not silent NA --------

test_that("prioritize_sectors errors naming a sector with no alignment source", {
  fx <- .new_prioritization_fixture(c("power", "automotive"))
  expect_error(
    .with_fixture_wd(fx$fixture_root, {
      suppressWarnings(prioritize_sectors(fx$cfg))
    }),
    "automotive"
  )
})

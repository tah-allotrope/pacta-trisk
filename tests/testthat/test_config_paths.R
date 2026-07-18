library(testthat)

root <- project_root()

rscript_bin <- function() {
  candidates <- c(
    Sys.which("Rscript"),
    "C:/Program Files/R/R-4.5.2/bin/Rscript.exe"
  )
  candidates <- candidates[nzchar(candidates) & file.exists(candidates)]
  if (length(candidates) == 0) return(NA_character_)
  candidates[[1]]
}

test_that("engagement_scoring.R --config redirects output without touching the default path", {
  rscript <- rscript_bin()
  if (is.na(rscript)) skip("Rscript not found on PATH")

  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  default_priority <- file.path(root, "output", "engagement", "engagement_priority.csv")
  skip_if_not(file.exists(default_priority), "default engagement_priority.csv not present (run pipeline_refresh.R first)")
  mtime_before <- file.info(default_priority)$mtime

  # Relative to repo root -- every script in this repo assumes getwd() is the
  # repo root (CLAUDE.md law), and cfg$paths$* is not required to be absolute.
  tmp_dir_rel <- file.path("output", paste0("test_config_paths_scratch_", as.integer(Sys.time())))
  tmp_dir_abs <- file.path(root, tmp_dir_rel)
  tmp_config <- tempfile(fileext = ".json")
  writeLines(
    sprintf('{"bank_name":"Test Bank","bank_slug":"test-bank","paths":{"engagement_output_dir":"%s"}}', tmp_dir_rel),
    tmp_config
  )
  on.exit(unlink(tmp_config), add = TRUE)
  on.exit(unlink(tmp_dir_abs, recursive = TRUE), add = TRUE)

  result <- system2(
    rscript,
    args = c("scripts/engagement_scoring.R", "--config", tmp_config),
    stdout = FALSE, stderr = FALSE
  )

  expect_equal(result, 0)
  expect_true(file.exists(file.path(tmp_dir_abs, "engagement_priority.csv")))
  expect_equal(file.info(default_priority)$mtime, mtime_before)
})

test_that("generate_engagement_letters.R --config with defaults reproduces the default output paths", {
  rscript <- rscript_bin()
  if (is.na(rscript)) skip("Rscript not found on PATH")

  withr_wd <- setwd(root)
  on.exit(setwd(withr_wd))

  skip_if_not(
    file.exists(file.path(root, "output", "engagement", "engagement_priority.csv")),
    "engagement_priority.csv not present"
  )

  result <- system2(
    rscript,
    args = c("scripts/generate_engagement_letters.R", "--config", "engagements/mcb-demo/engagement_config.json", "--top_n", "2"),
    stdout = FALSE, stderr = FALSE
  )

  expect_equal(result, 0)
  index_path <- file.path(root, "output", "engagement_letters", "index.html")
  expect_true(file.exists(index_path))
  index_text <- paste(readLines(index_path, warn = FALSE), collapse = "\n")
  expect_true(grepl("Mekong Commercial Bank", index_text, fixed = TRUE))
})

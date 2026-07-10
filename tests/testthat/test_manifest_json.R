library(testthat)

test_that("pipeline manifest is valid and complete", {
  root <- project_root()
  manifest_path <- file.path(root, "dashboard", "data", "pipeline_manifest.json")
  skip_if_not(file.exists(manifest_path), "pipeline_manifest.json not found")

  raw <- readLines(manifest_path, warn = FALSE)
  manifest <- jsonlite::fromJSON(paste(raw, collapse = "\n"), simplifyVector = FALSE)

  expect_equal(manifest$status, "ok")
  expect_gte(length(manifest$steps), 7)

  for (i in seq_along(manifest$steps)) {
    expect_equal(
      manifest$steps[[i]]$status, "ok",
      info = sprintf("Step %d (%s) should be ok", i, manifest$steps[[i]]$name)
    )
  }

  expect_true(nchar(manifest$generated_at) > 0, info = "generated_at should be non-empty")
})

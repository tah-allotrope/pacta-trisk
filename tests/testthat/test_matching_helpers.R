library(testthat)

root <- project_root()
source(file.path(root, "R", "matching_helpers.R"))
source(file.path(root, "R", "report_toolkit.R"))

test_that("normalize_vn_name strips Vietnamese diacritics", {
  expect_equal(
    normalize_vn_name("Nhiệt Điện Vĩnh Tân 1"),
    "Nhiet Dien Vinh Tan 1"
  )
})

test_that("normalize_vn_name is vectorized", {
  result <- normalize_vn_name(c("Vĩnh Tân", "Đông Bắc"))
  expect_equal(result, c("Vinh Tan", "Dong Bac"))
})

test_that("img_to_base64 encodes a PNG file as a data URI", {
  tmp_png <- tempfile(fileext = ".png")
  # 1x1 transparent PNG, base64-decoded to raw bytes.
  raw_png <- base64enc::base64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
  )
  writeBin(raw_png, tmp_png)
  on.exit(unlink(tmp_png))

  result <- img_to_base64(tmp_png)

  expect_true(startsWith(result, "data:image/png;base64,"))
  expect_gt(nchar(result), 50)
})

test_that("write_html_report creates the destination directory and writes the file", {
  tmp_dir <- tempfile()
  tmp_path <- file.path(tmp_dir, "nested", "report.html")
  on.exit(unlink(tmp_dir, recursive = TRUE))

  returned_path <- write_html_report("<html><body>hi</body></html>", tmp_path)

  expect_true(file.exists(tmp_path))
  expect_equal(returned_path, tmp_path)
  expect_equal(readLines(tmp_path, warn = FALSE), "<html><body>hi</body></html>")
})

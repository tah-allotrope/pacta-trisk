library(testthat)

root <- project_root()
source(file.path(root, "tools", "verify_refactor.R"))

# Wave 4 PHASE-01. Two surfaces are covered here:
#   1. normalize_report_html() / report_fingerprint() (R/report_fingerprint.R)
#   2. classify_path()'s new gated-HTML branch (tools/verify_refactor.R)
#
# The classify_path() tests build a throwaway git repository under tempdir()
# rather than touching the live tree, because the branch under test compares a
# working-tree file against its own HEAD blob.

# --- normalize_report_html() --------------------------------------------------

test_that("normalize_report_html replaces ISO-8601 timestamps", {
  expect_equal(
    normalize_report_html("Generated 2026-08-27T16:19:03+0700"),
    "Generated <TIMESTAMP>"
  )
  # R/trisk_core.R writes a UTC "Z" variant
  expect_equal(
    normalize_report_html("at 2026-08-27T16:19:03Z end"),
    "at <TIMESTAMP> end"
  )
})

test_that("normalize_report_html replaces space-separated timestamps", {
  expect_equal(
    normalize_report_html("Generated: 2026-08-27 16:29:07"),
    "Generated: <TIMESTAMP>"
  )
  expect_equal(
    normalize_report_html("Generated: 2026-08-27 16:29 +07"),
    "Generated: <TIMESTAMP>"
  )
  expect_equal(
    normalize_report_html("Generated: 2026-08-27 16:29"),
    "Generated: <TIMESTAMP>"
  )
})

test_that("normalize_report_html replaces both long-date formats", {
  expect_equal(normalize_report_html("<p>27 August 2026</p>"), "<p><DATE></p>")
  expect_equal(normalize_report_html("<p>August 27, 2026</p>"), "<p><DATE></p>")
})

test_that("normalize_report_html replaces git SHAs, full and abbreviated", {
  expect_equal(
    normalize_report_html("Commit: f69ceca9c347804e0b511f7ddbf9d3cfee64c831"),
    "Commit: <SHA>"
  )
  expect_equal(normalize_report_html("Commit: f69ceca"), "Commit: <SHA>")
})

test_that("normalize_report_html normalizes CRLF and tolerates empty input", {
  expect_equal(normalize_report_html("a\r\nb"), "a\nb")
  expect_equal(normalize_report_html(character(0)), character(0))
})

test_that("normalize_report_html collapses a timestamp-only difference but not a numeric one", {
  a <- normalize_report_html("<td>0.9816</td> 2026-08-27 16:29 +07")
  b <- normalize_report_html("<td>0.9816</td> 2026-09-02 08:01 +07")
  expect_identical(a, b)

  c1 <- normalize_report_html("<td>0.9816</td>")
  c2 <- normalize_report_html("<td>0.8100</td>")
  expect_false(identical(c1, c2))
})

# --- report_fingerprint() -----------------------------------------------------

test_that("report_fingerprint returns NA for a missing file and a digest otherwise", {
  expect_true(is.na(report_fingerprint(file.path(tempdir(), "no_such_report.html"))))

  p <- file.path(tempdir(), paste0("fp_", as.integer(Sys.time()), ".html"))
  writeLines("<html><body>Generated: 2026-08-27 16:29 +07</body></html>", p)
  on.exit(unlink(p), add = TRUE)
  fp <- report_fingerprint(p)
  expect_true(is.character(fp) && nchar(fp) == 32L)
})

test_that("report_fingerprint is stable across a timestamp-only edit", {
  p1 <- file.path(tempdir(), paste0("fp_a_", as.integer(Sys.time()), ".html"))
  p2 <- file.path(tempdir(), paste0("fp_b_", as.integer(Sys.time()), ".html"))
  on.exit(unlink(c(p1, p2)), add = TRUE)
  writeLines("<p>0.9816</p><p>Generated: 2026-08-27 16:29 +07</p>", p1)
  writeLines("<p>0.9816</p><p>Generated: 2026-09-02 08:01 +07</p>", p2)
  expect_identical(report_fingerprint(p1), report_fingerprint(p2))
})

# --- classify_path(): non-HTML behaviour is unchanged -------------------------

test_that("classify_path still classifies non-HTML paths exactly as before", {
  expect_equal(classify_path("dashboard/data/trisk/power/chart.png"), "png-noise")
  expect_equal(classify_path("dashboard/data/pacta/04_vn_ms_portfolio.csv"), "drift")
  expect_equal(classify_path("dashboard/data/pipeline_manifest.json"), "timestamp-class")
  expect_equal(classify_path("history/mcb-demo/run/manifest.json"), "timestamp-class")
})

test_that("classify_path leaves an ungated HTML report ignored", {
  # One of the ~40 static historical build reports: not regenerated, not gated.
  expect_equal(
    classify_path("reports/2026-04-16-trisk-power-pilot.html"),
    "timestamp-class"
  )
})

# --- classify_path(): the gated-HTML branch, against a real git fixture -------

.new_git_fixture <- function() {
  path <- file.path(tempdir(), paste0(
    "gated_html_", as.integer(Sys.time()), "_", sample.int(1e6, 1)
  ))
  dir.create(file.path(path, "reports"), recursive = TRUE)
  run <- function(...) system2("git", c("-C", path, ...), stdout = FALSE, stderr = FALSE)
  run("init", "-q")
  run("config", "user.email", "test@example.invalid")
  run("config", "user.name", "test")
  path
}

.write_file <- function(root, rel, text) {
  con <- file(file.path(root, rel), open = "wb")
  writeBin(charToRaw(text), con)
  close(con)
}

.commit_all <- function(root) {
  system2("git", c("-C", root, "add", "-A"), stdout = FALSE, stderr = FALSE)
  system2("git", c("-C", root, "commit", "-q", "-m", "fixture"), stdout = FALSE, stderr = FALSE)
}

test_that("a gated report whose only change is its timestamp is not drift", {
  fx <- .new_git_fixture()
  on.exit(unlink(fx, recursive = TRUE), add = TRUE)
  rel <- "reports/Financed_Emissions.html"

  .write_file(fx, rel, "<html><td>2,926,252</td><p>Generated: 2026-08-27 16:29 +07</p></html>")
  .commit_all(fx)

  expect_equal(classify_path(rel, gated_html_paths = rel, root = fx), "timestamp-class")

  .write_file(fx, rel, "<html><td>2,926,252</td><p>Generated: 2026-09-02 08:01 +07</p></html>")
  expect_equal(classify_path(rel, gated_html_paths = rel, root = fx), "timestamp-class")
})

test_that("a gated report with a changed number is drift", {
  fx <- .new_git_fixture()
  on.exit(unlink(fx, recursive = TRUE), add = TRUE)
  rel <- "reports/Financed_Emissions.html"

  .write_file(fx, rel, "<html><td>2,926,252</td><p>Generated: 2026-08-27 16:29 +07</p></html>")
  .commit_all(fx)

  .write_file(fx, rel, "<html><td>9,999,999</td><p>Generated: 2026-08-27 16:29 +07</p></html>")
  expect_equal(classify_path(rel, gated_html_paths = rel, root = fx), "drift")
})

test_that("a gated report that does not exist at HEAD is an addition, not drift", {
  fx <- .new_git_fixture()
  on.exit(unlink(fx, recursive = TRUE), add = TRUE)
  rel <- "reports/Financed_Emissions.html"

  .write_file(fx, "reports/other.html", "<html>seed</html>")
  .commit_all(fx)

  .write_file(fx, rel, "<html><td>1</td></html>")
  expect_equal(classify_path(rel, gated_html_paths = rel, root = fx), "timestamp-class")
})

test_that("a gated report is compared byte-for-byte through a long base64 line", {
  # Regression guard: reading `git show` through an R pipe splits very long
  # lines at a buffer boundary, which made an untouched report with an embedded
  # base64 image read as drift.
  fx <- .new_git_fixture()
  on.exit(unlink(fx, recursive = TRUE), add = TRUE)
  rel <- "reports/Financed_Emissions.html"

  long_b64 <- paste(rep("QUJDREVGR0hJSktMTU5PUFFSU1RVVldYWVowMTIzNDU2Nzg5", 400), collapse = "")
  body <- sprintf("<html><img src=\"data:image/png;base64,%s\"><td>1</td></html>", long_b64)
  .write_file(fx, rel, body)
  .commit_all(fx)

  expect_equal(classify_path(rel, gated_html_paths = rel, root = fx), "timestamp-class")
})

# --- INV-010 ------------------------------------------------------------------

test_that("inv_deliverables_carry_disclaimer flags a deliverable with no disclaimer", {
  fx <- .new_git_fixture()
  on.exit(unlink(fx, recursive = TRUE), add = TRUE)
  ok_rel <- "reports/ok.html"
  bad_rel <- "reports/bad.html"
  .write_file(fx, ok_rel, "<html>Synthetic data - illustrative only.</html>")
  .write_file(fx, bad_rel, "<html>Nothing here.</html>")

  res <- inv_deliverables_carry_disclaimer(fx, html_paths = c(ok_rel, bad_rel))
  expect_equal(res$id, "INV-010")
  expect_false(res$ok)
  expect_length(res$detail, 1L)
  expect_true(grepl("bad.html", res$detail[[1]], fixed = TRUE))
})

test_that("inv_deliverables_carry_disclaimer skips files that do not exist", {
  fx <- .new_git_fixture()
  on.exit(unlink(fx, recursive = TRUE), add = TRUE)
  res <- inv_deliverables_carry_disclaimer(fx, html_paths = "reports/absent.html")
  expect_true(res$ok)
  expect_length(res$detail, 0L)
})

test_that("every generated deliverable in the live repo carries its disclaimer", {
  res <- inv_deliverables_carry_disclaimer(root)
  expect_true(res$ok, info = paste(res$detail, collapse = "; "))
})

library(testthat)

root <- project_root()
source(file.path(root, "R", "report_toolkit.R"))

# Wave 4 PHASE-04. The i18n engine added in Wave 3 PHASE-07 -- report_label()
# and load_report_labels(), called from eight report generators -- decides
# whether a Vietnamese bank's deliverable says the right thing in Vietnamese,
# and shipped with no test coverage.

.labels_csv <- function(rows) {
  p <- file.path(tempdir(), paste0("labels_", as.integer(Sys.time()), "_",
                                   sample.int(1e6, 1), ".csv"))
  utils::write.csv(rows, p, row.names = FALSE, fileEncoding = "UTF-8")
  p
}

.base_rows <- function() {
  data.frame(
    token = c("synthetic_disclaimer", "coverage"),
    en = c("Synthetic data", "Coverage"),
    vi = c("Du lieu mo phong", "Do bao phu"),
    stringsAsFactors = FALSE
  )
}

# --- load_report_labels() -----------------------------------------------------

test_that("load_report_labels reads a well-formed table", {
  p <- .labels_csv(.base_rows())
  on.exit(unlink(p), add = TRUE)
  labels <- load_report_labels(base_csv = p)
  expect_true(all(c("token", "en", "vi") %in% names(labels)))
  expect_equal(nrow(labels), 2L)
})

test_that("load_report_labels errors when the base file is missing", {
  expect_error(
    load_report_labels(base_csv = file.path(tempdir(), "no_such_labels.csv")),
    "base label file not found"
  )
})

test_that("load_report_labels errors when a required column is absent", {
  rows <- .base_rows()
  rows$vi <- NULL
  p <- .labels_csv(rows)
  on.exit(unlink(p), add = TRUE)
  expect_error(load_report_labels(base_csv = p), "missing required columns")
})

test_that("load_report_labels applies an override, replacing and appending", {
  base <- .labels_csv(.base_rows())
  ov <- .labels_csv(data.frame(
    token = c("coverage", "extra_token"),
    en = c("Portfolio coverage", "Extra"),
    vi = c("Do bao phu danh muc", "Them"),
    stringsAsFactors = FALSE
  ))
  on.exit(unlink(c(base, ov)), add = TRUE)

  labels <- load_report_labels(base_csv = base, override_csv = ov)
  expect_equal(labels$en[labels$token == "coverage"], "Portfolio coverage")
  expect_true("extra_token" %in% labels$token)
  # An untouched base row survives unchanged.
  expect_equal(labels$en[labels$token == "synthetic_disclaimer"], "Synthetic data")
})

test_that("load_report_labels warns and ignores an override file that is missing", {
  base <- .labels_csv(.base_rows())
  on.exit(unlink(base), add = TRUE)
  missing_ov <- file.path(tempdir(), "no_such_override.csv")

  expect_warning(
    labels <- load_report_labels(base_csv = base, override_csv = missing_ov),
    "override CSV not found"
  )
  expect_equal(nrow(labels), 2L)
})

test_that("load_report_labels treats an empty override as 'not configured'", {
  # jsonlite round-trips an unset optional config field to character(0) or
  # list(), never NULL -- so the empty-shape check must be length-based.
  base <- .labels_csv(.base_rows())
  on.exit(unlink(base), add = TRUE)
  expect_silent(labels <- load_report_labels(base_csv = base, override_csv = character(0)))
  expect_equal(nrow(labels), 2L)
})

# --- report_label() -----------------------------------------------------------

test_that("report_label returns the requested language", {
  labels <- .base_rows()
  expect_equal(report_label("coverage", lang = "en", labels = labels), "Coverage")
  expect_equal(report_label("coverage", lang = "vi", labels = labels), "Do bao phu")
  expect_equal(report_label("coverage", lang = "bilingual", labels = labels),
               "Coverage / Do bao phu")
})

test_that("report_label defaults to English", {
  expect_equal(report_label("coverage", labels = .base_rows()), "Coverage")
})

test_that("report_label returns the token and warns once for an unknown token", {
  labels <- .base_rows()
  tok <- paste0("missing_token_", as.integer(Sys.time()), "_", sample.int(1e6, 1))
  expect_warning(out <- report_label(tok, labels = labels), "missing token")
  expect_equal(out, tok)
  # One warning per token per run: the second call is silent.
  expect_silent(report_label(tok, labels = labels))
})

test_that("report_label degrades to the token on a malformed label table", {
  expect_equal(report_label("anything", labels = data.frame(a = 1)), "anything")
})

# --- the shipped label table --------------------------------------------------

test_that("templates/i18n/labels.csv is well-formed and has no duplicate tokens", {
  p <- file.path(root, "templates", "i18n", "labels.csv")
  expect_true(file.exists(p))
  labels <- utils::read.csv(p, stringsAsFactors = FALSE, encoding = "UTF-8")
  expect_true(all(c("token", "en", "vi") %in% names(labels)))
  expect_gte(nrow(labels), 30L)
  expect_equal(anyDuplicated(labels$token), 0L)
  expect_false(any(is.na(labels$en) | !nzchar(labels$en)))
  expect_false(any(is.na(labels$vi) | !nzchar(labels$vi)))
})

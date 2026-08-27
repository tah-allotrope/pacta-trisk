#!/usr/bin/env Rscript
# tools/run_tests.R
# Thin wrapper around testthat::test_dir("tests/testthat") that additionally
# prints, at the end of a local run, which environment-gated test files did
# NOT execute and how to run them. Wave 3 PHASE-01 (N-010): the default local
# suite command silently skips RUN_SDB_ENGAGEMENT=1-gated coverage of
# scripts/run_engagement.R, and that skip is easy to miss in scrollback.
#
# This wrapper changes nothing about which tests run or how they are scored;
# it only makes the existing skip visible. CI runs the gated test separately
# as its own job (see .github/workflows/ci.yml's sdb-engagement job).

suppressPackageStartupMessages(library(testthat))

# name -> enabling environment variable, for every test file in
# tests/testthat/ that is conditionally skipped via skip_if_not() /
# skip_if() on an env var rather than on file presence alone. Keep in sync
# by hand; there is intentionally no test file to grep for out of respect for
# false positives (e.g. skip_if_not(file.exists(...)) is a different kind of
# skip and is not gated behind an env var at all).
GATED_TESTS <- c(
  "tests/testthat/test_sdb_engagement.R" = "RUN_SDB_ENGAGEMENT=1"
)

results <- test_dir("tests/testthat", stop_on_failure = FALSE)

cat("\n=== Environment-gated tests (may not have run above) ===\n")
for (path in names(GATED_TESTS)) {
  var <- GATED_TESTS[[path]]
  cat(sprintf("  %s -- set %s to run it\n", path, var))
  cat(sprintf("    e.g. %s Rscript -e \"testthat::test_file('%s')\"\n", var, path))
}

df <- as.data.frame(results)
n_fail <- sum(df$failed, na.rm = TRUE) + sum(df$error, na.rm = TRUE)
if (n_fail > 0) {
  quit(status = 1)
}
invisible(NULL)

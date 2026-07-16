# Standard package test entrypoint: makes `tests/testthat/` discoverable by
# devtools::test() and R CMD check. Local ad-hoc runs
# (Rscript -e "testthat::test_dir('tests/testthat')") continue to work
# unchanged and do not go through this file.

library(testthat)
library(pactatrisk)

test_check("pactatrisk")

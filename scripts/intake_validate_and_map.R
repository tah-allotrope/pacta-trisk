# ==============================================================================
# intake_validate_and_map.R
# BYOL intake validation and mapping script.
#
# Reads any conforming client loanbook, validates against the intake schema,
# applies VSIC -> ISIC -> PACTA sector mapping, runs diacritic normalization
# and fuzzy matching against ABCD, and emits a normalized loanbook plus
# a structured validation report.
#
# Wave 2 PHASE-05 (plans/2026-07-27-contracts-units-and-guardrails-plan.md):
# two-tier outcome model. Errors are genuine schema violations that make a
# row unusable (missing counterparty name, non-numeric/negative exposure or
# credit limit, invalid sector_code_system, unparseable sector_code, a
# duplicate row) and DROP the row from normalized_loanbook.csv. Warnings are
# conditions that leave the row usable but reduced in scope (an
# out-of-scope-but-well-formed sector code, a USD row converted or left
# unconverted) and NEVER drop the row. This closes the gap where
# intake/SCHEMA.md documented "classified as not in scope" and "currency may
# be VND or USD" while the implementation silently deleted those rows.
#
# Usage:
#   Rscript scripts/intake_validate_and_map.R \
#     --input /path/to/loanbook.csv \
#     --output-dir /path/to/output/ \
#     [--fx-rate-usd-vnd <rate>] [--anonymize]
#
# Default output dir: intake/output/
# ==============================================================================

library(dplyr)
library(readr)
library(stringi)
library(tibble)

source("R/matching_helpers.R")

# ==============================================================================
# Shared, sourceable functions (pure helpers; the CLI pipeline lives in main()).
# Tests and scripts/generate_coverage_report.R source() this file to reuse them.
# ==============================================================================

# ---- Sector code -> PACTA sector mapping (TASK-05-03) -----------------------
# Single source of truth for every accepted code, covering both the ISIC
# Rev.4 4-digit parents and the VSIC 2018 5-digit sub-classes (ASM-007). A
# code not in this table maps to "not in scope", not to an error.
.sector_code_map <- c(
  "3510" = "power", "35101" = "power", "35102" = "power", "35103" = "power", "3511" = "power",
  "2910" = "automotive", "29101" = "automotive", "29102" = "automotive",
  "2394" = "cement", "23941" = "cement", "23942" = "cement",
  "2410" = "steel", "24101" = "steel", "24102" = "steel",
  "0510" = "coal", "05101" = "coal",
  "0610" = "oil and gas", "0620" = "oil and gas", "06101" = "oil and gas"
)
known_isic <- names(.sector_code_map)

#' The PACTA sector for a normalized sector code, or "not in scope".
#' Vectorized. Single lookup point for every intake and downstream consumer.
#'
#' @param norm_code character — output of normalize_sector_code().
#' @return character, same length as norm_code.
map_sector_code <- function(norm_code) {
  sector <- unname(.sector_code_map[norm_code])
  sector[is.na(sector)] <- "not in scope"
  sector
}

#' Normalize a VSIC or ISIC sector code to its numeric core.
#'
#' Zero-pads only codes shorter than 4 digits — VSIC 2018 uses 5-digit
#' sub-classes (e.g. "35101") which must survive intact, not be truncated or
#' re-padded (Gotchas, Wave 2 plan). Returns NA_character_ for codes that are
#' not purely numeric after any VSIC letter-prefix is stripped.
#'
#' @param code character — the raw sector code.
#' @param code_system character — "VSIC" or "ISIC".
#' @return character — the normalized code, or NA_character_.
normalize_sector_code <- function(code, code_system) {
  code <- trimws(as.character(code))
  if (identical(code_system, "VSIC")) {
    code <- gsub("^[A-Za-z]+", "", code)
  }
  if (!grepl("^\\d+$", code)) {
    return(NA_character_)
  }
  if (nchar(code) < 4) {
    code <- stringi::stri_pad_left(code, 4, "0")
  }
  code
}

#' Convert a money amount to VND given its declared currency.
#'
#' @param amount numeric — the raw amount.
#' @param currency character — "VND", "USD", or anything else.
#' @param fx_rate_usd_vnd numeric|NULL — VND per 1 USD.
#' @return numeric — amount unchanged for "VND", amount * fx_rate_usd_vnd for
#'   "USD", NA_real_ for any other currency. Errors if currency is "USD" and
#'   fx_rate_usd_vnd is NULL, non-finite, or non-positive.
convert_to_vnd <- function(amount, currency, fx_rate_usd_vnd) {
  if (identical(currency, "VND")) {
    return(amount)
  }
  if (identical(currency, "USD")) {
    if (is.null(fx_rate_usd_vnd) || length(fx_rate_usd_vnd) == 0 ||
        is.na(fx_rate_usd_vnd) || !is.finite(fx_rate_usd_vnd) || fx_rate_usd_vnd <= 0) {
      stop("convert_to_vnd: fx_rate_usd_vnd must be a single positive number when currency is 'USD'")
    }
    return(amount * fx_rate_usd_vnd)
  }
  NA_real_
}

# ==============================================================================
# CLI pipeline
# ==============================================================================

main <- function() {
  args <- commandArgs(trailingOnly = TRUE)

  get_arg <- function(flag, default = NULL) {
    idx <- which(args == flag)
    if (length(idx) > 0 && idx < length(args)) {
      return(args[idx + 1])
    }
    default
  }

  input_file  <- get_arg("--input")
  output_dir  <- get_arg("--output-dir", file.path(getwd(), "intake", "output"))
  anonymize   <- "--anonymize" %in% args
  fx_rate_arg <- get_arg("--fx-rate-usd-vnd")
  fx_rate_usd_vnd <- if (!is.null(fx_rate_arg)) suppressWarnings(as.numeric(fx_rate_arg)) else NULL

  if (is.null(input_file)) {
    stop("Usage: Rscript scripts/intake_validate_and_map.R --input <file> [--output-dir <dir>] [--fx-rate-usd-vnd <rate>] [--anonymize]")
  }

  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

  cat("========================================\n")
  cat("BYOL INTAKE: Validation & Mapping\n")
  cat("========================================\n\n")
  cat(sprintf("  Input file:   %s\n", input_file))
  cat(sprintf("  Output dir:   %s\n\n", output_dir))

  # ---- Read input ----
  input_data <- tryCatch(
    read_csv(input_file, show_col_types = FALSE, locale = locale(encoding = "UTF-8")),
    error = function(e) {
      read_csv(input_file, show_col_types = FALSE, locale = locale(encoding = "latin1"))
    }
  )

  n_total <- nrow(input_data)
  cat(sprintf("  Rows read: %d\n\n", n_total))

  # ---- Define required and optional columns ----
  required_cols <- c("counterparty_name", "exposure_vnd", "sector_code", "sector_code_system", "credit_limit_vnd")
  optional_cols <- c("lei", "tax_id", "parent_name", "parent_id", "currency")

  # ---- Schema validation (errors: drop the row) --------------------------------
  errors <- list()
  error_counter <- 1

  add_error <- function(row, column, message) {
    errors[[error_counter]] <<- tibble(row = row, column = column, error = message)
    error_counter <<- error_counter + 1
  }

  # ---- Warnings (retained row, reduced scope): never drops a row --------------
  warnings_acc <- list()
  warning_counter <- 1

  add_warning <- function(row, column, message, classification) {
    warnings_acc[[warning_counter]] <<- tibble(
      row = row, column = column, classification = classification, message = message
    )
    warning_counter <<- warning_counter + 1
  }

  # Check required columns exist
  missing_req <- setdiff(required_cols, names(input_data))
  if (length(missing_req) > 0) {
    stop(sprintf("Missing required columns: %s", paste(missing_req, collapse = ", ")))
  }

  # Warn about unknown columns (non-fatal)
  known_cols <- c(required_cols, optional_cols)
  unknown_cols <- setdiff(names(input_data), known_cols)
  if (length(unknown_cols) > 0) {
    cat(sprintf("  WARNING: Unknown columns present: %s\n\n", paste(unknown_cols, collapse = ", ")))
  }

  # Validate each row (hard errors only -- currency and sector-scope handled
  # separately below via the warning path, not here).
  #
  # Wave 4 PHASE-05: every column-level coercion below is hoisted out of the
  # row loop and computed once over the whole column. The loop that remains
  # only *emits* errors, in the same order as before: ascending row, and within
  # a row counterparty_name -> exposure_vnd -> credit_limit_vnd ->
  # sector_code_system -> sector_code. Preserving that order matters because
  # validation_errors.csv is a committed regression fixture.
  #
  # What this removes is `row <- input_data[i, ]` -- a single-row tibble slice
  # executed once per loan, which docs/scale_benchmark.md identified as the
  # dominant intake cost (three such passes at 50,000 rows).
  nm_chr    <- trimws(as.character(input_data$counterparty_name))
  exp_num   <- suppressWarnings(as.numeric(input_data$exposure_vnd))
  cl_num    <- suppressWarnings(as.numeric(input_data$credit_limit_vnd))
  scs_chr   <- trimws(as.character(input_data$sector_code_system))
  sc_chr    <- trimws(as.character(input_data$sector_code))

  bad_name    <- is.na(nm_chr) | nm_chr == ""
  exp_missing <- is.na(exp_num)
  exp_neg     <- !exp_missing & exp_num < 0
  cl_missing  <- is.na(cl_num)
  cl_neg      <- !cl_missing & cl_num < 0
  bad_system  <- !(scs_chr %in% c("VSIC", "ISIC"))
  sc_missing  <- is.na(sc_chr) | sc_chr == ""
  # A *format* error -- distinct from a well-formed code that simply maps to no
  # PACTA sector, which is a warning below, not an error.
  sc_malformed <- !sc_missing & scs_chr == "VSIC" & !grepl("^[A-Za-z]*\\d+$", sc_chr)

  # Only rows with at least one problem need visiting at all.
  flagged <- which(bad_name | exp_missing | exp_neg | cl_missing | cl_neg |
                     bad_system | sc_missing | sc_malformed)

  for (i in flagged) {
    if (bad_name[i]) {
      add_error(i, "counterparty_name", "Counterparty name is missing or empty")
    }
    if (exp_missing[i]) {
      add_error(i, "exposure_vnd", "exposure_vnd is not a valid number")
    } else if (exp_neg[i]) {
      add_error(i, "exposure_vnd", sprintf("exposure_vnd is negative (%.0f)", exp_num[i]))
    }
    if (cl_missing[i]) {
      add_error(i, "credit_limit_vnd", "credit_limit_vnd is not a valid number")
    } else if (cl_neg[i]) {
      add_error(i, "credit_limit_vnd", sprintf("credit_limit_vnd is negative (%.0f)", cl_num[i]))
    }
    if (bad_system[i]) {
      add_error(i, "sector_code_system", sprintf("sector_code_system is '%s', expected 'VSIC' or 'ISIC'", scs_chr[i]))
    }
    if (sc_missing[i]) {
      add_error(i, "sector_code", "sector_code is missing or empty")
    } else if (sc_malformed[i]) {
      add_error(i, "sector_code", sprintf("sector_code '%s' is not a valid VSIC code", sc_chr[i]))
    }
  }

  # Check for duplicate rows
  dupes <- which(duplicated(input_data))
  for (i in dupes) {
    add_error(i, "duplicate", sprintf("Row %d is a duplicate of an earlier row", i))
  }

  errors_df <- if (length(errors) > 0) bind_rows(errors) else tibble(row = integer(), column = character(), error = character())

  # Rows with errors are excluded from the normalized output (warnings never are)
  error_rows <- unique(errors_df$row)
  valid_mask <- !seq_len(n_total) %in% error_rows

  # ---- Sector scope classification (TASK-05-02): warning, never an error ------
  # intake/SCHEMA.md has always said an out-of-scope-but-well-formed code is
  # "classified as not in scope" -- retained, not dropped. The row keeps its
  # normalized code and gets PACTA sector "not in scope" downstream.
  # Wave 4 PHASE-05: normalization and mapping are computed once over the whole
  # column (map_sector_code() is already vectorized; normalize_sector_code() is
  # applied element-wise via mapply, exactly as the mapping step further below
  # already does). Only rows that are genuinely out of scope are then visited,
  # in ascending row order as before.
  scope_norm <- mapply(normalize_sector_code, sc_chr, scs_chr, USE.NAMES = FALSE)
  scope_mapped <- map_sector_code(scope_norm)
  out_of_scope <- which(
    !sc_missing &                # blank code is already a hard error above
      !is.na(scope_norm) &       # unparseable format is already a hard error
      scope_mapped == "not in scope"
  )
  for (i in out_of_scope) {
    add_warning(
      i, "sector_code",
      sprintf("sector_code '%s' (normalized %s) is not in PACTA scope", sc_chr[i], scope_norm[i]),
      "sector_out_of_scope"
    )
  }

  cat("--- Schema validation complete ---\n")
  cat(sprintf("  Rows with errors: %d / %d\n\n", length(unique(errors_df$row)), n_total))

  # ---- Currency handling (ASM-006, TASK-05-04/05-05): warning, never drops ----
  currency_raw <- trimws(as.character(input_data$currency))
  currency_effective <- ifelse(!is.na(currency_raw) & currency_raw != "", currency_raw, "VND")

  exposure_raw_num <- suppressWarnings(as.numeric(input_data$exposure_vnd))
  credit_raw_num <- suppressWarnings(as.numeric(input_data$credit_limit_vnd))

  converted_exposure <- exposure_raw_num
  converted_credit <- credit_raw_num
  converted_currency <- currency_effective
  usd_without_rate <- FALSE
  have_fx_rate <- !is.null(fx_rate_usd_vnd) && length(fx_rate_usd_vnd) > 0 &&
    !is.na(fx_rate_usd_vnd) && is.finite(fx_rate_usd_vnd) && fx_rate_usd_vnd > 0

  # Wave 4 PHASE-05: the overwhelmingly common case is a VND row, which the old
  # loop visited only to `next`. Partition once and touch only the rows that
  # actually need conversion, preserving ascending-row warning order.
  is_vnd <- currency_effective == "VND"
  is_usd <- currency_effective == "USD"
  usd_idx <- which(is_usd)
  other_idx <- which(!is_vnd & !is_usd)

  if (length(usd_idx) > 0) {
    if (have_fx_rate) {
      converted_exposure[usd_idx] <- convert_to_vnd(exposure_raw_num[usd_idx], "USD", fx_rate_usd_vnd)
      converted_credit[usd_idx] <- convert_to_vnd(credit_raw_num[usd_idx], "USD", fx_rate_usd_vnd)
      converted_currency[usd_idx] <- "VND"
    } else {
      converted_exposure[usd_idx] <- NA_real_
      converted_credit[usd_idx] <- NA_real_
      usd_without_rate <- TRUE
    }
  }
  if (length(other_idx) > 0) {
    converted_exposure[other_idx] <- NA_real_
    converted_credit[other_idx] <- NA_real_
  }

  # Emit warnings in ascending row order across both categories, matching the
  # single-pass ordering of the loop this replaced.
  for (i in sort(c(usd_idx, other_idx))) {
    if (is_usd[i]) {
      if (have_fx_rate) {
        add_warning(
          i, "currency",
          sprintf("exposure and credit limit converted from USD to VND at rate %s", fx_rate_usd_vnd),
          "fx_converted"
        )
      } else {
        add_warning(
          i, "currency",
          "currency is USD but inputs.fx_rate_usd_vnd is not configured -- exposure and credit limit excluded from VND totals",
          "fx_rate_missing"
        )
      }
    } else {
      add_warning(
        i, "currency",
        sprintf("currency '%s' is not VND or USD -- exposure and credit limit excluded from VND totals", currency_effective[i]),
        "unsupported_currency"
      )
    }
  }

  # ---- Column mapping ----
  id_prefix <- "CL_"
  n <- n_total

  counterparty_names <- input_data$counterparty_name
  sector_codes_raw <- as.character(input_data$sector_code)
  sector_systems <- as.character(input_data$sector_code_system)

  # Normalize sector codes
  sector_codes_norm <- mapply(normalize_sector_code, sector_codes_raw, sector_systems, USE.NAMES = FALSE)

  # Normalize sector system to ISIC
  sector_system_isic <- ifelse(trimws(sector_systems) == "VSIC", "ISIC", trimws(sector_systems))

  # Resolve PACTA sector (single lookup point, TASK-05-03)
  sector_mapping <- tibble(
    code = sector_codes_norm
  ) %>%
    mutate(sector = map_sector_code(code))

  # Diacritic normalization
  names_norm <- normalize_vn_name(counterparty_names)
  parent_names <- ifelse(
    is.na(input_data$parent_name) | trimws(as.character(input_data$parent_name)) == "",
    names_norm,
    normalize_vn_name(as.character(input_data$parent_name))
  )

  # Build output loanbook
  output_loanbook <- tibble(
    id_loan = sprintf("CL_L%03d", seq_len(n)),
    id_direct_loantaker = ifelse(
      !is.na(input_data$tax_id) & trimws(as.character(input_data$tax_id)) != "",
      paste0("CL_", trimws(as.character(input_data$tax_id))),
      sprintf("CL_C%03d", seq_len(n))
    ),
    name_direct_loantaker = names_norm,
    id_ultimate_parent = ifelse(
      !is.na(input_data$parent_id) & trimws(as.character(input_data$parent_id)) != "",
      paste0("CL_", trimws(as.character(input_data$parent_id))),
      sprintf("CL_UP%03d", seq_len(n))
    ),
    name_ultimate_parent = parent_names,
    loan_size_outstanding = converted_exposure,
    loan_size_outstanding_currency = converted_currency,
    loan_size_credit_limit = converted_credit,
    loan_size_credit_limit_currency = converted_currency,
    sector_classification_system = sector_system_isic,
    sector_classification_direct_loantaker = sector_codes_norm,
    lei_direct_loantaker = ifelse(
      !is.na(input_data$lei) & trimws(as.character(input_data$lei)) != "",
      trimws(as.character(input_data$lei)),
      "NA"
    ),
    isin_direct_loantaker = "NA"
  )

  # Filter to only valid rows (hard errors only -- warnings never drop a row)
  output_loanbook <- output_loanbook[valid_mask, ]

  if (anonymize) {
    pseudonymize_names <- function(names_vec, map) {
      unique_names <- unique(names_vec[!is.na(names_vec)])
      new_pseudos <- setdiff(unique_names, map$original_name)
      if (length(new_pseudos) > 0) {
        new_rows <- tibble(
          original_name = new_pseudos,
          pseudonym = sprintf("Counterparty %03d", seq(nrow(map) + 1, length.out = length(new_pseudos)))
        )
        map <- bind_rows(map, new_rows)
      }
      lookup <- setNames(map$pseudonym, map$original_name)
      pseudonymized <- ifelse(is.na(names_vec), NA_character_, lookup[names_vec])
      list(names = pseudonymized, map = map)
    }

    pseudo_map <- tibble(original_name = character(), pseudonym = character())
    dl_result <- pseudonymize_names(output_loanbook$name_direct_loantaker, pseudo_map)
    output_loanbook$name_direct_loantaker <- dl_result$names
    pseudo_map <- dl_result$map

    up_result <- pseudonymize_names(output_loanbook$name_ultimate_parent, pseudo_map)
    output_loanbook$name_ultimate_parent <- up_result$names
    pseudo_map <- up_result$map

    map_path <- file.path(output_dir, "pseudonym_map.csv")
    write_csv(pseudo_map, map_path)
    cat(sprintf("  Written: %s\n", map_path))
  }

  # ---- Write normalized loanbook ----
  normalized_path <- file.path(output_dir, "normalized_loanbook.csv")
  write_csv(output_loanbook, normalized_path)
  cat(sprintf("  Written: %s\n", normalized_path))

  # ---- Write validation errors ----
  errors_path <- file.path(output_dir, "validation_errors.csv")
  write_csv(errors_df, errors_path)
  cat(sprintf("  Written: %s\n", errors_path))

  # ---- Write validation warnings (always written, even when empty) -----------
  warnings_df <- if (length(warnings_acc) > 0) {
    bind_rows(warnings_acc)
  } else {
    tibble(row = integer(), column = character(), classification = character(), message = character())
  }
  warnings_path <- file.path(output_dir, "validation_warnings.csv")
  write_csv(warnings_df, warnings_path)
  cat(sprintf("  Written: %s\n", warnings_path))

  # ---- Fuzzy matching against ABCD (optional, requires r2dii.match) ----
  match_preview <- tibble(
    input_counterparty = character(),
    best_abcd_match = character(),
    score = numeric(),
    review_needed = logical()
  )

  abcd_file <- file.path(getwd(), "data", "vietnam_abcd.csv")
  if (file.exists(abcd_file)) {
    cat("\n--- Running fuzzy match preview ---\n")
    tryCatch(
      {
        library(r2dii.match)
        abcd <- read_csv(abcd_file, show_col_types = FALSE)

        abcd_norm <- abcd %>%
          mutate(name_company = normalize_vn_name(name_company))

        # Extend sector classifications with the custom VSIC/ISIC mapping
        sector_classifications <- r2dii.data::sector_classifications
        vsic_to_pacta_extension <- tibble::tibble(
          code_system = "ISIC",
          code = names(.sector_code_map),
          sector = unname(.sector_code_map),
          borderline = FALSE
        )
        sector_classifications <- bind_rows(sector_classifications, vsic_to_pacta_extension)

        matched_raw <- tryCatch(
          {
            r2dii.match::match_name(
              output_loanbook, abcd_norm,
              by_sector = TRUE,
              min_score = 0.8,
              method = "jw",
              p = 0.1
            )
          },
          error = function(e) {
            cat(sprintf("  Match error: %s\n", e$message))
            NULL
          }
        )

        if (!is.null(matched_raw) && nrow(matched_raw) > 0) {
          match_preview <- matched_raw %>%
            select(id_loan, name_direct_loantaker, name_abcd, score, sector_abcd) %>%
            mutate(review_needed = score < 1.0) %>%
            rename(
              input_counterparty = name_direct_loantaker,
              best_abcd_match = name_abcd
            ) %>%
            arrange(input_counterparty, desc(score))

          if (anonymize && nrow(pseudo_map) > 0) {
            lookup <- setNames(pseudo_map$pseudonym, pseudo_map$original_name)
            match_preview$input_counterparty <- ifelse(
              is.na(match_preview$input_counterparty),
              NA_character_,
              lookup[match_preview$input_counterparty]
            )
          }

          cat(sprintf("  Matches found: %d\n", nrow(match_preview)))
        } else {
          cat("  No matches found (NULL or empty).\n")
        }
      },
      error = function(e) {
        cat(sprintf("  Match preview skipped: %s\n", e$message))
      }
    )
  } else {
    cat("\n  ABCD file not found at '%s'. Skipping match preview.\n")
  }

  match_path <- file.path(output_dir, "match_preview.csv")
  write_csv(match_preview, match_path)
  cat(sprintf("  Written: %s\n", match_path))

  # ---- Validation summary ----
  n_passing <- n_total - length(unique(errors_df$row))
  n_warned_rows <- length(unique(warnings_df$row))
  # Sector distribution
  sector_distribution <- sector_mapping %>%
    count(sector, name = "count") %>%
    arrange(desc(count))

  summary_lines <- c(
    "===== BYOL INTAKE VALIDATION SUMMARY =====",
    "",
    sprintf("Total rows processed:     %d", n_total),
    sprintf("Rows passing validation:  %d", n_passing),
    sprintf("Rows with errors:         %d", length(unique(errors_df$row))),
    sprintf("Rows with warnings:       %d", n_warned_rows),
    "",
    "--- Sector Distribution ---",
    capture.output(print(as.data.frame(sector_distribution), row.names = FALSE)),
    ""
  )

  if (nrow(warnings_df) > 0) {
    by_class <- warnings_df %>% count(classification, name = "count") %>% arrange(desc(count))
    summary_lines <- c(summary_lines, "--- Warnings by Classification ---")
    summary_lines <- c(summary_lines, capture.output(print(as.data.frame(by_class), row.names = FALSE)))
    summary_lines <- c(summary_lines, "")
  }

  if (nrow(match_preview) > 0) {
    n_review <- sum(match_preview$review_needed)
    summary_lines <- c(summary_lines, "--- Match Preview ---")
    summary_lines <- c(summary_lines, sprintf("  Total candidate matches:     %d", nrow(match_preview)))
    summary_lines <- c(summary_lines, sprintf("  Exact matches (score = 1.0): %d", nrow(match_preview) - n_review))
    summary_lines <- c(summary_lines, sprintf("  Review needed (score < 1.0): %d", n_review))
    summary_lines <- c(summary_lines, "")
    summary_lines <- c(summary_lines, "  NOTE: Match preview uses synthetic ABCD. Results will improve")
    summary_lines <- c(summary_lines, "  when production ABCD data is loaded.")
  } else {
    summary_lines <- c(summary_lines, "--- Match Preview ---")
    summary_lines <- c(summary_lines, "  No matches found or ABCD file unavailable.")
  }

  summary_lines <- c(summary_lines, "", "==============================")

  summary_text <- paste(summary_lines, collapse = "\n")

  summary_path <- file.path(output_dir, "validation_summary.txt")
  writeLines(summary_text, summary_path)
  cat(sprintf("  Written: %s\n", summary_path))

  cat("\n", summary_text, "\n", sep = "")

  cat("\n--- INTAKE COMPLETE ---\n")
  cat(sprintf("All outputs written to: %s\n", output_dir))

  if (usd_without_rate) {
    cat(sprintf(
      "\n[ERROR] One or more rows have currency 'USD' but inputs.fx_rate_usd_vnd is not configured.\n"
    ))
    cat("        Set inputs.fx_rate_usd_vnd in the engagement config, or pass\n")
    cat("        --fx-rate-usd-vnd <rate> to this script, to convert those rows.\n")
    cat("        All output files above were written; the affected rows are retained\n")
    cat("        with exposure/credit limit set to NA (see validation_warnings.csv,\n")
    cat("        classification 'fx_rate_missing').\n")
    quit(status = 1)
  }
}

if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  main()
}

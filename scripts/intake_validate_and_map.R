# ==============================================================================
# intake_validate_and_map.R
# BYOL intake validation and mapping script.
#
# Reads any conforming client loanbook, validates against the intake schema,
# applies VSIC -> ISIC -> PACTA sector mapping, runs diacritic normalization
# and fuzzy matching against ABCD, and emits a normalized loanbook plus
# a structured validation report.
#
# Usage:
#   Rscript scripts/intake_validate_and_map.R \
#     --input /path/to/loanbook.csv \
#     --output-dir /path/to/output/
#
# Default output dir: intake/output/
# ==============================================================================

library(dplyr)
library(readr)
library(stringi)
library(tibble)

source("R/matching_helpers.R")

# ---- Command-line argument parsing ----
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

if (is.null(input_file)) {
  stop("Usage: Rscript scripts/intake_validate_and_map.R --input <file> [--output-dir <dir>] [--anonymize]")
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
    # Fallback to latin1 encoding
    read_csv(input_file, show_col_types = FALSE, locale = locale(encoding = "latin1"))
  }
)

n_total <- nrow(input_data)
cat(sprintf("  Rows read: %d\n\n", n_total))

# ---- Define required and optional columns ----
required_cols <- c("counterparty_name", "exposure_vnd", "sector_code", "sector_code_system", "credit_limit_vnd")
optional_cols <- c("lei", "tax_id", "parent_name", "parent_id", "currency")

# ---- Schema validation ----
errors <- list()
error_counter <- 1

add_error <- function(row, column, message) {
  errors[[error_counter]] <<- tibble(row = row, column = column, error = message)
  error_counter <<- error_counter + 1
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

# Validate each row
for (i in seq_len(n_total)) {
  row <- input_data[i, ]

  # counterparty_name must be non-empty
  if (is.na(row$counterparty_name) || trimws(row$counterparty_name) == "") {
    add_error(i, "counterparty_name", "Counterparty name is missing or empty")
  }

  # exposure_vnd must be numeric and >= 0
  exp_val <- suppressWarnings(as.numeric(row$exposure_vnd))
  if (is.na(exp_val)) {
    add_error(i, "exposure_vnd", "exposure_vnd is not a valid number")
  } else if (exp_val < 0) {
    add_error(i, "exposure_vnd", sprintf("exposure_vnd is negative (%.0f)", exp_val))
  }

  # credit_limit_vnd must be numeric and >= 0
  cl_val <- suppressWarnings(as.numeric(row$credit_limit_vnd))
  if (is.na(cl_val)) {
    add_error(i, "credit_limit_vnd", "credit_limit_vnd is not a valid number")
  } else if (cl_val < 0) {
    add_error(i, "credit_limit_vnd", sprintf("credit_limit_vnd is negative (%.0f)", cl_val))
  }

  # sector_code_system must be VSIC or ISIC
  scs <- trimws(as.character(row$sector_code_system))
  if (!scs %in% c("VSIC", "ISIC")) {
    add_error(i, "sector_code_system", sprintf("sector_code_system is '%s', expected 'VSIC' or 'ISIC'", scs))
  }

  # sector_code must be non-empty
  sc <- trimws(as.character(row$sector_code))
  if (is.na(sc) || sc == "") {
    add_error(i, "sector_code", "sector_code is missing or empty")
  } else if (scs == "VSIC" && !grepl("^[A-Za-z]*\\d+$", sc)) {
    add_error(i, "sector_code", sprintf("sector_code '%s' is not a valid VSIC code", sc))
  }

  # currency check - output requires VND
  cur <- trimws(as.character(row$currency))
  if (!is.na(cur) && cur != "" && cur != "VND") {
    add_error(i, "currency", sprintf("currency '%s' must be VND for PACTA processing", cur))
  }
}

# Check for unmappable sector codes (normalize but don't map to PACTA sectors)
known_isic <- c("3511", "2910", "2394", "2410", "0510", "0610")
for (i in seq_len(n_total)) {
  sc <- trimws(as.character(input_data$sector_code[i]))
  scs <- trimws(as.character(input_data$sector_code_system[i]))
  if (!is.na(sc) && sc != "" && scs == "VSIC") {
    norm_code <- gsub("^[A-Za-z]+", "", sc)
    if (grepl("^\\d+$", norm_code)) {
      norm_code <- stringi::stri_pad_left(norm_code, 4, "0")
      if (!norm_code %in% known_isic) {
        add_error(i, "sector_code", sprintf("sector_code '%s' (ISIC %s) is not in PACTA scope", sc, norm_code))
      }
    }
  }
}

# Check for duplicate rows
dupes <- which(duplicated(input_data))
for (i in dupes) {
  add_error(i, "duplicate", sprintf("Row %d is a duplicate of an earlier row", i))
}

errors_df <- if (length(errors) > 0) bind_rows(errors) else tibble(row = integer(), column = character(), error = character())

# Rows with errors are excluded from the normalized output
error_rows <- unique(errors_df$row)
valid_mask <- !seq_len(n_total) %in% error_rows

# ---- VSIC -> ISIC normalization ----
normalize_sector_code <- function(code, code_system) {
  code <- trimws(as.character(code))
  if (code_system == "VSIC") {
    # Strip leading letter prefix, keep digits
    code <- gsub("^[A-Za-z]+", "", code)
    # If still contains non-digits, keep original
    if (grepl("^\\d+$", code)) {
      code <- stringi::stri_pad_left(code, 4, "0")
    } else {
      code <- NA_character_
    }
  }
  # Zero-pad ISIC codes to 4 digits
  if (grepl("^\\d+$", code)) {
    code <- stringi::stri_pad_left(code, 4, "0")
  }
  code
}

# ---- VSIC -> PACTA sector mapping ----
vsic_to_pacta <- tibble::tribble(
  ~code_system, ~code,  ~sector,      ~borderline,
  "ISIC",       "3511", "power",       FALSE,
  "ISIC",       "2910", "automotive",  FALSE,
  "ISIC",       "2394", "cement",      FALSE,
  "ISIC",       "2410", "steel",       FALSE,
  "ISIC",       "0510", "coal",        FALSE,
  "ISIC",       "0610", "oil and gas", FALSE
)

cat("--- Schema validation complete ---\n")
cat(sprintf("  Rows with errors: %d / %d\n\n", nrow(errors_df), n_total))

# ---- Column mapping ----
# Generate sequential IDs
id_prefix <- "CL_"
n <- n_total

counterparty_names <- input_data$counterparty_name
sector_codes_raw <- as.character(input_data$sector_code)
sector_systems <- as.character(input_data$sector_code_system)

# Normalize sector codes
sector_codes_norm <- mapply(normalize_sector_code, sector_codes_raw, sector_systems, USE.NAMES = FALSE)

# Normalize sector system to ISIC
sector_system_isic <- ifelse(trimws(sector_systems) == "VSIC", "ISIC", trimws(sector_systems))

# Resolve PACTA sector
sector_mapping <- tibble(
  code = sector_codes_norm,
  code_system = sector_system_isic
) %>%
  left_join(vsic_to_pacta, by = c("code" = "code", "code_system" = "code_system")) %>%
  mutate(sector = ifelse(is.na(sector), "not in scope", sector))

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
  loan_size_outstanding = suppressWarnings(as.numeric(input_data$exposure_vnd)),
  loan_size_outstanding_currency = ifelse(
    !is.na(input_data$currency) & trimws(as.character(input_data$currency)) != "",
    trimws(as.character(input_data$currency)),
    "VND"
  ),
  loan_size_credit_limit = suppressWarnings(as.numeric(input_data$credit_limit_vnd)),
  loan_size_credit_limit_currency = ifelse(
    !is.na(input_data$currency) & trimws(as.character(input_data$currency)) != "",
    trimws(as.character(input_data$currency)),
    "VND"
  ),
  sector_classification_system = sector_system_isic,
  sector_classification_direct_loantaker = sector_codes_norm,
  lei_direct_loantaker = ifelse(
    !is.na(input_data$lei) & trimws(as.character(input_data$lei)) != "",
    trimws(as.character(input_data$lei)),
    "NA"
  ),
  isin_direct_loantaker = "NA"
)

# Filter to only valid rows
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

      # Normalize names
      abcd_norm <- abcd %>%
        mutate(name_company = normalize_vn_name(name_company))

      # Extend sector classifications with the custom VSIC/ISIC mapping
      sector_classifications <- r2dii.data::sector_classifications
      sector_classifications <- bind_rows(sector_classifications, vsic_to_pacta)

      # Create a minimal loanbook-like tibble for matching
      # match_name requires specific columns
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
n_passing <- n_total - nrow(errors_df)
# Sector distribution
sector_distribution <- sector_mapping %>%
  count(sector, name = "count") %>%
  arrange(desc(count))

unresolved_raw <- which(is.na(sector_codes_norm) | sector_codes_norm == "" | sector_mapping$sector == "not in scope")
unresolved_codes <- tibble(
  original_code = sector_codes_raw[unresolved_raw],
  normalized_code = sector_codes_norm[unresolved_raw]
) %>% filter(!is.na(original_code))

summary_lines <- c(
  "===== BYOL INTAKE VALIDATION SUMMARY =====",
  "",
  sprintf("Total rows processed:     %d", n_total),
  sprintf("Rows passing validation:  %d", n_passing),
  sprintf("Rows with errors:         %d", nrow(errors_df)),
  "",
  "--- Sector Distribution ---",
  capture.output(print(as.data.frame(sector_distribution), row.names = FALSE)),
  ""
)

if (nrow(unresolved_codes) > 0) {
  summary_lines <- c(summary_lines, "--- Unresolved ISIC Codes (not in PACTA scope) ---")
  summary_lines <- c(summary_lines, capture.output(print(as.data.frame(unresolved_codes), row.names = FALSE)))
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

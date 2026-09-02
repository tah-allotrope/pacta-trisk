# ==============================================================================
# R/financed_emissions.R
# Wave 3 PHASE-05: PCAF-style financed-emissions accounting (Scope 1+2 only,
# per ASM-006 -- automotive and coal mining are excluded because Scope 3
# dominates for those sectors; every excluded row carries an explicit
# exclusion_reason rather than a silent NA).
#
# Purely additive: reads the normalized loanbook, ABCD and the two new
# lookup tables (data/vietnam_emission_factors.csv,
# data/vietnam_capacity_factors.csv) plus the borrower-capital sidecar
# (data/vietnam_borrower_capital.csv, Wave 3 PHASE-05 RISK-05-02 -- kept
# separate from the TRISK-generated data/vietnam_trisk_financial_features.csv
# to avoid any risk to TRISK's byte-identity). Writes its own output CSVs;
# never feeds composite_score, the sector ranking, or any frozen artifact.
#
# See docs/financed_emissions_methodology.md for the reviewer-facing walkthrough.
# ==============================================================================

HOURS_PER_YEAR <- 8760

# Sectors excluded from this Scope 1+2 inventory because Scope 3 dominates
# their financed-emissions profile (ASM-006).
SCOPE_3_DOMINANT_SECTORS <- c("automotive", "coal")

#' Attribution factor: the bank's share of a borrower's total financed
#' activity, clamped to \[0, 1\] (a ratio above 1 indicates the loan exceeds
#' the borrower's total capital -- a data error, not a real attribution).
#'
#' @param outstanding_vnd numeric — outstanding exposure, whole VND.
#' @param capital_vnd numeric — borrower total debt + equity, whole VND.
#' @return numeric in \[0, 1\], NA where either input is NA or capital_vnd is 0.
#' @export
attribution_factor <- function(outstanding_vnd, capital_vnd) {
  ratio <- outstanding_vnd / capital_vnd
  ratio[capital_vnd == 0] <- NA_real_
  pmin(pmax(ratio, 0), 1)
}

#' Annual financed generation-based emissions for a power asset.
#' @param capacity_mw numeric — installed capacity, MW.
#' @param capacity_factor numeric — dimensionless utilization fraction, \[0, 1\].
#' @param emission_factor_tco2_per_mwh numeric.
#' @return numeric — tonnes of CO2 equivalent per year.
#' @export
borrower_emissions_power <- function(capacity_mw, capacity_factor, emission_factor_tco2_per_mwh) {
  capacity_mw * capacity_factor * HOURS_PER_YEAR * emission_factor_tco2_per_mwh
}

#' Annual emissions for an intensity-based sector (cement, steel).
#' @param production_tonnes numeric — annual production, tonnes.
#' @param emission_factor_tco2_per_tonne numeric.
#' @return numeric — tonnes of CO2 equivalent per year.
#' @export
borrower_emissions_intensity <- function(production_tonnes, emission_factor_tco2_per_tonne) {
  production_tonnes * emission_factor_tco2_per_tonne
}

#' PCAF data-quality score, 1 (best) to 5 (worst) -- note this direction is
#' the OPPOSITE of this repo's severity scores, where 1 is worst.
#'
#' @param activity_source character(1) — "reported" or "derived".
#' @param factor_source character(1) — "borrower" or "technology".
#' @param capital_source character(1) — "reported" or "sector_median".
#' @return integer(1), 2-5 (this synthetic pipeline never reports score 1 --
#'   audited, verified emissions).
#' @export
pcaf_data_quality_score <- function(activity_source, factor_source, capital_source) {
  if (identical(capital_source, "sector_median")) return(5L)
  if (identical(activity_source, "derived")) return(4L)
  if (identical(factor_source, "technology")) return(3L)
  2L
}

#' Compute financed emissions for every borrower in the ABCD universe.
#'
#' @param abcd data.frame — data/vietnam_abcd.csv shape (company_id,
#'   name_company, sector, technology, production, production_unit, year,
#'   emission_factor). Only the most recent `as_of_year` row per company is
#'   used for power (capacity-based); for cement/steel, the row's own
#'   `emission_factor` and `production` are used directly (both already
#'   "reported" quality in this repo's ABCD).
#' @param capital data.frame — data/vietnam_borrower_capital.csv shape
#'   (company_id, name_company, sector, borrower_capital_vnd,
#'   borrower_capital_source).
#' @param loanbook_exposure data.frame — company_id-or-name-keyed exposure;
#'   must have columns `name_company` and `outstanding_vnd` (summed loan
#'   exposure per matched borrower).
#' @param emission_factors data.frame — data/vietnam_emission_factors.csv
#'   (power technologies only).
#' @param capacity_factors data.frame — data/vietnam_capacity_factors.csv.
#' @param report_year integer(1) — the ABCD year to use for power capacity
#'   and cement/steel production/emission_factor, default 2025.
#' @param data_source character(1) — the engagement's own bank_slug, written
#'   verbatim into every row's `data_source` column. Defaults to NA_character_
#'   rather than any bank's slug: until Wave 4 this was hardcoded to the demo
#'   bank's slug, so EVERY engagement's generated inventory was stamped with it
#'   regardless of whose loanbook the inventory described. (The affected file is
#'   gitignored per .gitignore:73, so no wrong value was ever committed -- but
#'   any real engagement's inventory would have carried it on generation.)
#' @return data.frame: name_abcd, sector, scope, outstanding_vnd,
#'   borrower_capital_vnd, attribution_factor, borrower_emissions_tco2e,
#'   financed_emissions_tco2e, data_quality_score, exclusion_reason,
#'   data_source.
#' @export
financed_emissions <- function(abcd, capital, loanbook_exposure, emission_factors, capacity_factors,
                                report_year = 2025L, data_source = NA_character_) {
  companies <- unique(capital[, c("company_id", "name_company", "sector")])

  rows <- lapply(seq_len(nrow(companies)), function(i) {
    company_id <- companies$company_id[i]
    name <- companies$name_company[i]
    sector <- companies$sector[i]

    cap_row <- capital[capital$company_id == company_id, , drop = FALSE][1, ]
    exp_row <- loanbook_exposure[loanbook_exposure$name_company == name, , drop = FALSE]
    outstanding_vnd <- if (nrow(exp_row) > 0) exp_row$outstanding_vnd[1] else NA_real_

    common <- list(
      name_abcd = name, sector = sector, scope = "1+2",
      outstanding_vnd = outstanding_vnd,
      borrower_capital_vnd = cap_row$borrower_capital_vnd,
      data_source = data_source
    )

    if (sector %in% SCOPE_3_DOMINANT_SECTORS) {
      return(as.data.frame(c(common, list(
        attribution_factor = NA_real_, borrower_emissions_tco2e = NA_real_,
        financed_emissions_tco2e = NA_real_, data_quality_score = NA_integer_,
        exclusion_reason = "scope_3_dominant_sector_out_of_scope"
      )), stringsAsFactors = FALSE))
    }

    af <- attribution_factor(outstanding_vnd, cap_row$borrower_capital_vnd)
    capital_source <- cap_row$borrower_capital_source

    if (identical(sector, "power")) {
      asset_rows <- abcd[abcd$company_id == company_id & abcd$sector == "power" & abcd$year == report_year, , drop = FALSE]
      if (nrow(asset_rows) == 0) {
        return(as.data.frame(c(common, list(
          attribution_factor = af, borrower_emissions_tco2e = NA_real_,
          financed_emissions_tco2e = NA_real_, data_quality_score = NA_integer_,
          exclusion_reason = "no_abcd_asset_data_for_report_year"
        )), stringsAsFactors = FALSE))
      }
      total_emissions <- 0
      for (j in seq_len(nrow(asset_rows))) {
        tech <- asset_rows$technology[j]
        cf_row <- capacity_factors[capacity_factors$technology == tech, , drop = FALSE]
        ef_row <- emission_factors[emission_factors$technology == tech, , drop = FALSE]
        if (nrow(cf_row) == 0 || nrow(ef_row) == 0) next
        total_emissions <- total_emissions + borrower_emissions_power(
          asset_rows$production[j], cf_row$capacity_factor[1], ef_row$emission_factor[1]
        )
      }
      dq <- pcaf_data_quality_score("derived", "technology", capital_source)
    } else {
      # cement / steel: production + emission_factor both come directly
      # from ABCD's own reported columns.
      asset_rows <- abcd[abcd$company_id == company_id & abcd$year == report_year, , drop = FALSE]
      if (nrow(asset_rows) == 0) {
        return(as.data.frame(c(common, list(
          attribution_factor = af, borrower_emissions_tco2e = NA_real_,
          financed_emissions_tco2e = NA_real_, data_quality_score = NA_integer_,
          exclusion_reason = "no_abcd_asset_data_for_report_year"
        )), stringsAsFactors = FALSE))
      }
      total_emissions <- sum(borrower_emissions_intensity(asset_rows$production, asset_rows$emission_factor), na.rm = TRUE)
      dq <- pcaf_data_quality_score("reported", "borrower", capital_source)
    }

    fe <- if (is.na(af)) NA_real_ else af * total_emissions
    as.data.frame(c(common, list(
      attribution_factor = af, borrower_emissions_tco2e = total_emissions,
      financed_emissions_tco2e = fe, data_quality_score = dq,
      exclusion_reason = NA_character_
    )), stringsAsFactors = FALSE)
  })

  do.call(rbind, rows)
}

#' Data-quality composition: share of total financed emissions at each
#' quality score. No total is ever published without this.
#' @param fe data.frame — financed_emissions() output.
#' @return data.frame: data_quality_score, n_borrowers,
#'   financed_emissions_tco2e, share_of_total (sums to 1 over scored rows).
#' @export
data_quality_summary <- function(fe) {
  scored <- fe[!is.na(fe$financed_emissions_tco2e), , drop = FALSE]
  total <- sum(scored$financed_emissions_tco2e)
  agg <- stats::aggregate(
    financed_emissions_tco2e ~ data_quality_score, data = scored, FUN = sum
  )
  counts <- stats::aggregate(
    name_abcd ~ data_quality_score, data = scored, FUN = length
  )
  out <- merge(agg, counts, by = "data_quality_score")
  names(out)[names(out) == "name_abcd"] <- "n_borrowers"
  out$share_of_total <- out$financed_emissions_tco2e / total
  out[order(out$data_quality_score), c("data_quality_score", "n_borrowers", "financed_emissions_tco2e", "share_of_total")]
}

#' Carbon-cost exposure: financed emissions valued at the NGFS carbon-price
#' pathway, in whole VND.
#'
#' @param fe data.frame — financed_emissions() output (one row per borrower;
#'   this function fans it out across every year present in `carbon_price`).
#' @param carbon_price data.frame — one of
#'   data/vietnam_trisk_ngfs_carbon_price_<sector>.csv, columns including
#'   `year` and `carbon_price_usd_per_tco2` (sector-specific; call once per
#'   sector and rbind).
#' @param fx_rate_usd_vnd numeric(1) — VND per USD. length 0 means "not
#'   configured": every carbon_cost_vnd is NA_real_.
#' @return data.frame: name_abcd, sector, year, financed_emissions_tco2e,
#'   carbon_price_usd_per_tco2, fx_rate_usd_vnd, carbon_cost_vnd.
#' @export
carbon_cost_exposure <- function(fe, carbon_price, fx_rate_usd_vnd) {
  scored <- fe[!is.na(fe$financed_emissions_tco2e), , drop = FALSE]
  rows <- lapply(seq_len(nrow(scored)), function(i) {
    data.frame(
      name_abcd = scored$name_abcd[i], sector = scored$sector[i],
      year = carbon_price$year,
      financed_emissions_tco2e = scored$financed_emissions_tco2e[i],
      carbon_price_usd_per_tco2 = carbon_price$carbon_price_usd_per_tco2,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (length(fx_rate_usd_vnd) == 0) {
    out$fx_rate_usd_vnd <- NA_real_
    out$carbon_cost_vnd <- NA_real_
  } else {
    out$fx_rate_usd_vnd <- fx_rate_usd_vnd
    out$carbon_cost_vnd <- out$financed_emissions_tco2e * out$carbon_price_usd_per_tco2 * fx_rate_usd_vnd
  }
  out
}

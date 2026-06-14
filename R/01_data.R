source("R/config.R")
source("R/setup.R")

fredr_set_key(FRED_API_KEY)

# ── 1. Download raw series ────────────────────────────────────────────────────

pull <- function(series_id, units = "lin") {
  fredr_series_observations(
    series_id         = series_id,
    observation_start = START_DATE,
    observation_end   = END_DATE,
    frequency         = NULL,
    units             = units
  ) |>
    dplyr::select(date, value) |>
    dplyr::rename(!!series_id := value)
}

# Rate/level series: units = "lin" (already in %, index, or billions)
# Inflation series:  units = "pc1" (percent change from year ago)
raw_fedfunds <- pull("FEDFUNDS")
raw_pcepilfe <- pull("PCEPILFE",          units = "pc1")
raw_pcepi    <- pull("PCEPI",             units = "pc1")
raw_gdpc1    <- pull("GDPC1")
raw_gdppot   <- pull("GDPPOT")
raw_unrate   <- pull("UNRATE")
raw_nrou     <- pull("NROU")
raw_ecbdfr   <- pull("ECBDFR")
raw_hicp     <- pull("CP0000EZ19M086NEST", units = "pc1")

# ── 2. Convert to quarterly (last observation of each quarter) ────────────────

to_quarterly <- function(df) {
  col <- names(df)[2]
  df |>
    dplyr::mutate(quarter = as.Date(as.yearqtr(date))) |>
    dplyr::group_by(quarter) |>
    dplyr::slice_tail(n = 1) |>
    dplyr::ungroup() |>
    dplyr::select(date = quarter, !!col := !!sym(col))
}

q_fedfunds <- to_quarterly(raw_fedfunds)
q_pcepilfe <- to_quarterly(raw_pcepilfe)
q_pcepi    <- to_quarterly(raw_pcepi)
q_gdpc1    <- to_quarterly(raw_gdpc1)
q_gdppot   <- to_quarterly(raw_gdppot)
q_unrate   <- to_quarterly(raw_unrate)
q_nrou     <- to_quarterly(raw_nrou)
q_ecbdfr   <- to_quarterly(raw_ecbdfr)
q_hicp     <- to_quarterly(raw_hicp)

# ── 3. Merge into single quarterly dataframe ─────────────────────────────────

df_quarterly <- q_gdpc1 |>
  dplyr::full_join(q_gdppot,   by = "date") |>
  dplyr::full_join(q_fedfunds, by = "date") |>
  dplyr::full_join(q_pcepilfe, by = "date") |>
  dplyr::full_join(q_pcepi,    by = "date") |>
  dplyr::full_join(q_unrate,   by = "date") |>
  dplyr::full_join(q_nrou,     by = "date") |>
  dplyr::full_join(q_ecbdfr,   by = "date") |>
  dplyr::full_join(q_hicp,     by = "date") |>
  dplyr::arrange(date)

# ── 4. Derived variables ──────────────────────────────────────────────────────

df_quarterly <- df_quarterly |>
  dplyr::mutate(
    output_gap   = 100 * (GDPC1 - GDPPOT) / GDPPOT,
    unemp_gap    = UNRATE - NROU
    # Euro area potential output is not available on FRED; for the ECB
    # comparison we use a simplified Taylor specification based on ECBDFR and
    # CP0000EZ19M086NEST only (no output gap term for the euro area block).
  )

# ── 5. Handle NAs ─────────────────────────────────────────────────────────────

df_quarterly <- df_quarterly |>
  dplyr::mutate(dplyr::across(where(is.numeric), ~ na.locf(.x, na.rm = FALSE))) |>
  dplyr::filter(dplyr::if_any(c(FEDFUNDS, PCEPILFE, GDPC1), ~ !is.na(.x)))

# ── 6. Save ───────────────────────────────────────────────────────────────────

dir.create(DATA_DIR, recursive = TRUE, showWarnings = FALSE)
saveRDS(df_quarterly, file.path(DATA_DIR, "df_quarterly.rds"))

# ── 7. Summary ────────────────────────────────────────────────────────────────

cat("\n── df_quarterly summary ─────────────────────────────────────────────────\n")
cat(sprintf("Date range : %s  →  %s\n", min(df_quarterly$date), max(df_quarterly$date)))
cat(sprintf("Rows       : %d\n", nrow(df_quarterly)))
cat(sprintf("Columns    : %d\n\n", ncol(df_quarterly)))
cat("NA counts per column:\n")
na_counts <- colSums(is.na(df_quarterly))
print(na_counts[order(-na_counts)])
cat("─────────────────────────────────────────────────────────────────────────\n\n")

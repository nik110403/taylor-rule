source("R/config.R")
library(tseries)
library(lmtest)
library(vars)
library(dplyr)
library(zoo)

df <- readRDS(file.path(DATA_DIR, "df_quarterly.rds"))

# ── Section 1: US Taylor Rule variants ───────────────────────────────────────

df <- df |>
  dplyr::mutate(
    taylor_pure_1 = R_STAR_BASE + PCEPILFE + 0.5 * (PCEPILFE - PI_STAR) + 0.5 * output_gap,
    taylor_pure_2 = R_STAR_ALT  + PCEPILFE + 0.5 * (PCEPILFE - PI_STAR) + 0.5 * output_gap,
    taylor_pure_3 = R_STAR_BASE + PCEPILFE + 0.5 * (PCEPILFE - PI_STAR) + 0.5 * output_gap,

    # Floor at zero before applying inertia so the bound is respected in the
    # inertial term as well, not just the final output.
    Taylor_1 = pmax(taylor_pure_1, 0),
    Taylor_2 = pmax(taylor_pure_2, 0),
    Taylor_3 = pmax(
      0.75 * dplyr::lag(FEDFUNDS, 1) + 0.25 * pmax(taylor_pure_3, 0),
      0
    ),

    Dev_1 = Taylor_1 - FEDFUNDS,
    Dev_2 = Taylor_2 - FEDFUNDS,
    Dev_3 = Taylor_3 - FEDFUNDS
  ) |>
  dplyr::select(-taylor_pure_1, -taylor_pure_2, -taylor_pure_3)

# ── Section 2: ECB simplified Taylor Rule ────────────────────────────────────
# Euro area potential output is not on FRED; the ECB rule omits the output gap
# and uses 1.0 as r* (consistent with pre-pandemic euro area neutral rate
# estimates).

df <- df |>
  dplyr::mutate(
    ECB_Taylor = 1.0 + CP0000EZ19M086NEST + 0.5 * (CP0000EZ19M086NEST - PI_STAR),
    ECB_Dev    = ECB_Taylor - ECBDFR
  )

# ── Section 3: Stationarity (ADF tests) ──────────────────────────────────────

run_adf <- function(x, label) {
  x_clean <- na.omit(x)
  result  <- adf.test(x_clean)
  cat(sprintf(
    "ADF  %-30s  stat = %6.3f  p = %.4f  %s\n",
    label,
    result$statistic,
    result$p.value,
    ifelse(result$p.value < 0.05, "[stationary]", "[non-stationary]")
  ))
  invisible(result)
}

cat("\n── Stationarity tests (ADF) ─────────────────────────────────────────────\n")

adf_inf    <- run_adf(df$PCEPILFE, "PCEPILFE (inflation, levels)")
adf_dev1   <- run_adf(df$Dev_1,    "Dev_1 (deviation, levels)")

# First differences if levels are non-stationary
if (adf_inf$p.value >= 0.05) {
  run_adf(diff(na.omit(df$PCEPILFE)), "PCEPILFE (first diff)")
  # A p-value < 0.05 on the differenced series confirms I(1) behaviour —
  # inflation has a unit root in levels but is stationary after differencing.
}
if (adf_dev1$p.value >= 0.05) {
  run_adf(diff(na.omit(df$Dev_1)), "Dev_1 (first diff)")
  # If the deviation is I(1) in levels but stationary after differencing,
  # this would suggest the fed funds rate and the Taylor prescription share a
  # stochastic trend — use differenced series for Granger tests below.
}

cat("─────────────────────────────────────────────────────────────────────────\n\n")

# ── Section 4: Granger causality ─────────────────────────────────────────────

granger_data <- df |>
  dplyr::select(Dev_1, PCEPILFE) |>
  na.omit()

cat("── Granger causality: Dev_1 → PCEPILFE (deviation causes inflation?) ────\n")
for (lag in 1:4) {
  gt <- grangertest(PCEPILFE ~ Dev_1, order = lag, data = granger_data)
  cat(sprintf("  lag %d : F = %.3f  p = %.4f  %s\n",
              lag, gt$F[2], gt$`Pr(>F)`[2],
              ifelse(gt$`Pr(>F)`[2] < 0.05, "[significant]", "")))
}

cat("\n── Granger causality: PCEPILFE → Dev_1 (inflation causes deviation?) ───\n")
for (lag in 1:4) {
  gt <- grangertest(Dev_1 ~ PCEPILFE, order = lag, data = granger_data)
  cat(sprintf("  lag %d : F = %.3f  p = %.4f  %s\n",
              lag, gt$F[2], gt$`Pr(>F)`[2],
              ifelse(gt$`Pr(>F)`[2] < 0.05, "[significant]", "")))
}

# VAR(4) approach — captures joint dynamics and avoids the single-direction
# framing of bivariate Granger tests.
cat("\n── VAR(4) Granger causality (vars::causality) ───────────────────────────\n")
var_mat <- as.matrix(granger_data)
var4    <- VAR(var_mat, p = 4, type = "const")

gc_dev1_causes  <- causality(var4, cause = "Dev_1")
gc_infl_causes  <- causality(var4, cause = "PCEPILFE")

cat("Dev_1 Granger-causes PCEPILFE:\n")
print(gc_dev1_causes$Granger)
cat("PCEPILFE Granger-causes Dev_1:\n")
print(gc_infl_causes$Granger)

cat("─────────────────────────────────────────────────────────────────────────\n\n")

# ── Section 5: Cross-correlation (Dev_1 leading PCEPILFE) ────────────────────

ccf_data <- df |> dplyr::select(Dev_1, PCEPILFE) |> na.omit()

ccf_obj <- ccf(
  ccf_data$Dev_1,
  ccf_data$PCEPILFE,
  lag.max = 8,
  plot    = FALSE
)

# Keep only non-negative lags (deviation leading or coincident with inflation)
df_ccf <- data.frame(
  lag         = ccf_obj$lag[ccf_obj$lag >= 0],
  correlation = ccf_obj$acf[ccf_obj$lag >= 0]
)

cat("── Cross-correlation: Dev_1 leading PCEPILFE (lags 0–8 quarters) ────────\n")
print(df_ccf)
cat("─────────────────────────────────────────────────────────────────────────\n\n")

# ── Save outputs ──────────────────────────────────────────────────────────────

saveRDS(df,     file.path(DATA_DIR, "df_analysis.rds"))
saveRDS(df_ccf, file.path(DATA_DIR, "df_ccf.rds"))

cat("Saved: df_analysis.rds and df_ccf.rds\n")

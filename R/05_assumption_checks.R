# R/05_assumption_checks.R — assumption diagnostics for the VAR(4) model in R/02_analysis.R.
#
# skill-harvest S48: harvested from K-Dense-AI/scientific-agent-skills (MIT)
# `statistical-analysis/scripts/assumption_checks.py` — but that script is an OLS/ANOVA-oriented
# library (Shapiro-Wilk normality, Levene homogeneity) with a matplotlib/seaborn/scipy stack this
# pure-R project doesn't carry. This project's actual model is a VAR, and the `vars` package
# (already a project dependency, R/setup.R) ships the matching diagnostic suite for VAR residuals
# — multivariate Jarque-Bera normality, Portmanteau serial-correlation, and ARCH-LM
# heteroskedasticity — covering the same three assumption categories (normality / independence /
# homoscedasticity) as the harvested Python script, native to the model class actually used here.
# See ~/.claude/_templates/analysis-repo/scripts/stats/assumption_checks.py for the general-case
# harvested script (wired for future Python-based analysis-repo projects).
#
# Standalone — sources config.R + setup.R itself so it can run outside the full run_all.R
# pipeline (`Rscript R/05_assumption_checks.R`, from the project root, after R/02_analysis.R has
# produced output/data/df_analysis.rds at least once).

source("R/config.R")
source("R/setup.R")

df <- readRDS(file.path(DATA_DIR, "df_analysis.rds"))

granger_data <- df |> dplyr::select(Dev_1, PCEPILFE) |> na.omit()
var_mat <- as.matrix(granger_data)
var4 <- VAR(var_mat, p = 4, type = "const")

alpha <- 0.05

fmt_row <- function(check, test) {
  p_value <- unname(test$p.value)
  statistic <- unname(test$statistic)
  verdict <- if (p_value > alpha) "PASS" else "FLAG"
  sprintf("| %s | %s = %.3f | p = %.4f | %s |", check, names(test$statistic), statistic,
          p_value, verdict)
}

norm_test   <- normality.test(var4)$jb.mul$JB
arch_result <- arch.test(var4, lags.multi = 4)$arch.mul
serial_result <- serial.test(var4, lags.pt = 8, type = "PT.asymptotic")$serial

report_lines <- c(
  "# Assumption report — VAR(4) diagnostics (Dev_1, PCEPILFE)",
  "",
  sprintf("Generated %s by R/05_assumption_checks.R (skill-harvest S48).",
          format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  "",
  "| Check | Statistic | p-value | Verdict |",
  "|---|---|---|---|",
  fmt_row("Normality (multivariate Jarque-Bera)", norm_test),
  fmt_row("Serial correlation (Portmanteau)", serial_result),
  fmt_row("Heteroskedasticity (ARCH-LM)", arch_result),
  "",
  sprintf("PASS = fails to reject the null (assumption holds) at alpha = %.2f.", alpha),
  "FLAG = rejects the null — inspect before trusting this VAR's standard errors/CIs."
)

out_path <- file.path(OUTPUT_DIR, "assumption_report.md")
writeLines(report_lines, out_path)
cat(sprintf("Wrote %s\n", out_path))

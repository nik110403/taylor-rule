# Assumption report — VAR(4) diagnostics (Dev_1, PCEPILFE)

Generated 2026-09-04 18:23:16 by R/05_assumption_checks.R (skill-harvest S48).

| Check | Statistic | p-value | Verdict |
|---|---|---|---|
| Normality (multivariate Jarque-Bera) | Chi-squared = 15.795 | p = 0.0033 | FLAG |
| Serial correlation (Portmanteau) | Chi-squared = 34.011 | p = 0.0054 | FLAG |
| Heteroskedasticity (ARCH-LM) | Chi-squared = 38.346 | p = 0.3636 | PASS |

PASS = fails to reject the null (assumption holds) at alpha = 0.05.
FLAG = rejects the null — inspect before trusting this VAR's standard errors/CIs.

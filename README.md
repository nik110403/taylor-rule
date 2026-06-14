# Taylor Rule Estimation

Replication repository for the deep dive *Discretion Over Rules: Federal Reserve Policy
Departures and the Inflation Surge of 2021–2022* (nikkhosravipour.com/research).

R pulls quarterly macroeconomic series from FRED, computes three Taylor-rule specifications
and an ECB comparison, tests for Granger causality and cross-correlation between deviations
and core PCE inflation, and exports Chart.js widgets and static PNG fallbacks.

## Data vintage

FRED revises historical series, including `GDPPOT` (CBO potential output). Results reproduce
exactly against the vintage retrieved for the published piece; subsequent pulls shift the
output gap series and therefore every Taylor prescription. The sample window is locked at
2015 Q1–2024 Q4 in `R/config.R` (`START_DATE`, `END_DATE`).

## Requirements

- R (≥ 4.0); packages auto-install on first run via `R/setup.R`: `fredr`, `dplyr`, `vars`,
  `tseries`, `lmtest`, `zoo`, `lubridate`
- A free FRED API key — https://fredaccount.stlouisfed.org/apikeys

## Setup

```bash
cp .Renviron.example .Renviron   # edit and paste your FRED_API_KEY
```

R loads `.Renviron` from the project root automatically.

## Run

```bash
Rscript run_all.R
```

On completion the script prints a checklist of every expected output file.

## FRED series

| Series ID | Description | Transformation |
|---|---|---|
| `FEDFUNDS` | Effective federal funds rate | levels |
| `PCEPILFE` | Core PCE deflator | YoY% (`pc1`) |
| `PCEPI` | Headline PCE deflator | YoY% (`pc1`) |
| `GDPC1` | Real GDP | levels |
| `GDPPOT` | CBO potential real GDP | levels |
| `UNRATE` | Unemployment rate | levels |
| `NROU` | Natural rate of unemployment (CBO) | levels |
| `ECBDFR` | ECB deposit facility rate | levels |
| `CP0000EZ19M086NEST` | Euro area HICP | YoY% (`pc1`) |

Monthly series convert to quarterly by taking the last observation of each quarter.

## Rule specifications

Three US variants, all floored at zero:

| Rule | Formula | r\* | Notes |
|---|---|---|---|
| Baseline | r\* + π + 0.5(π − π\*) + 0.5·y_gap | 0.5% | Post-GFC Laubach-Williams |
| Alternative | same | 1.0% | Robustness |
| Inertial | 0.75·r_{t−1} + 0.25·baseline | 0.5% | Partial-adjustment |

π = core PCE YoY%; π\* = 2%; y_gap = 100·(GDPC1 − GDPPOT)/GDPPOT.

ECB comparison (fig4): r\* = 1.0%, π = euro area HICP, no output-gap term (euro area
potential is not available on FRED), prescribed against `ECBDFR`.

## Analysis

`R/02_analysis.R` runs ADF stationarity tests on inflation and the deviation series,
bivariate Granger causality at lags 1–4 in both directions, VAR(4) Granger causality
(via `vars::causality`), and a cross-correlation of the baseline deviation against core
PCE at lags 0–8 quarters.

## Where things can drift

`GDPPOT` is revised with each CBO Budget and Economic Outlook. Re-running against a later
vintage will not reproduce the published figures. The companion piece documents
the vintage used and the direction of any revisions.

## Layout

| Script | Role |
|---|---|
| `R/01_data.R` | FRED pull → quarterly conversion → `output/data/df_quarterly.rds` |
| `R/02_analysis.R` | Taylor variants, ECB rule, ADF/Granger/CCF → `df_analysis.rds`, `df_ccf.rds` |
| `R/04_hook_figure.R` | Hook figure (fig0) |
| `R/03_figures.R` | Chart.js widgets (figs 1–5) |
| `R/04_pngs.R` | Static PNG export |
| `R/config.R` | Sample window, π\*, r\* assumptions |
| `R/setup.R` | Package management |

See [`embed_guide.md`](embed_guide.md) for iframe dimensions and embedding notes.

## License

Source data is public, served by [FRED](https://fred.stlouisfed.org/) and subject to its
terms. The code and generated figures are licensed under [CC BY 4.0](LICENSE) — reuse with
attribution.

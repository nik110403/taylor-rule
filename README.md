# Taylor Rule Estimation

**How well does a Taylor rule describe recent central-bank behaviour?**

Estimates and back-tests Taylor-rule policy paths against realised policy rates,
with a reproducible figure pipeline. The repo loads quarterly macro data from
FRED, computes prescribed rates under a baseline and an alternative neutral-rate
assumption, measures the gap against the actual federal funds rate (plus an ECB
comparison and a cross-correlation diagnostic), and emits both interactive
Chart.js widgets and static PNG fallbacks.

Part of the research on [nikkhosravipour.com](https://nikkhosravipour.com).

## Requirements

- R (≥ 4.0)
- A free FRED API key — https://fredaccount.stlouisfed.org/apikeys
- R packages are auto-installed on first run (`fredr`, `dplyr`, `vars`,
  `tseries`, `lmtest`, `zoo`, `lubridate`) via `R/setup.R`.

## Setup

```bash
cp .Renviron.example .Renviron   # then edit and paste your FRED_API_KEY
```

R loads `.Renviron` automatically from the project root, so the key is read from
the environment — it is never stored in the source.

## Run

```bash
Rscript run_all.R
```

Pipeline order: `01_data` (load + clean FRED series) → `02_analysis` (Taylor-rule
estimates) → `04_hook_figure` + `03_figures` (Chart.js widgets) → `04_pngs`
(static PNG export). On completion the script prints a checklist of every
expected output file.

## Outputs

- `output/widgets/*.html` — standalone Chart.js figures (theme-aware, embeddable)
- `output/figures/*.png` — static fallbacks
- `output/data/*.rds` — intermediate R data (regenerable; gitignored)

See [`embed_guide.md`](embed_guide.md) for iframe heights and embedding details.

## Configuration

Constants live in `R/config.R` — sample window (`START_DATE`/`END_DATE`),
inflation target `PI_STAR`, and neutral-rate assumptions `R_STAR_BASE` /
`R_STAR_ALT`.

## Data & license

Source data is public, served by [FRED](https://fred.stlouisfed.org/) and subject
to its terms. The code and generated figures in this repository are licensed
under [CC BY 4.0](LICENSE) — reuse with attribution.

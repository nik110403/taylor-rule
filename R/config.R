FRED_API_KEY  <- Sys.getenv("FRED_API_KEY")
if (!nzchar(FRED_API_KEY)) {
  stop("Set FRED_API_KEY in .Renviron (free key: https://fredaccount.stlouisfed.org/apikeys)")
}

PROJECT_ROOT  <- getwd()
OUTPUT_DIR    <- file.path(PROJECT_ROOT, "output")
WIDGETS_DIR   <- file.path(PROJECT_ROOT, "output/widgets")
DATA_DIR      <- file.path(PROJECT_ROOT, "output/data")

START_DATE    <- as.Date("2015-01-01")
END_DATE      <- as.Date("2024-12-31")

PI_STAR       <- 2.0   # inflation target, percent
R_STAR_BASE   <- 0.5   # baseline neutral real rate (post-GFC Laubach-Williams), percent
R_STAR_ALT    <- 1.0   # alternative neutral rate for robustness, percent

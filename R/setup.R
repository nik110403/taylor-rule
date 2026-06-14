packages <- c(
  "fredr",
  "dplyr",    # replaces tidyverse — only dplyr is used in this project
  "vars",
  "tseries",
  "lmtest",
  "zoo",
  "lubridate"
  # plotly / htmlwidgets omitted: 03_figures.R writes raw Chart.js HTML via
  # writeLines() and does not call any plotly or htmlwidgets functions.
  # Installing them requires libuv-devel (sudo dnf install libuv-devel).
)

user_lib <- Sys.getenv("R_LIBS_USER", unset = "~/.R/library")
user_lib <- path.expand(user_lib)
if (!dir.exists(user_lib)) dir.create(user_lib, recursive = TRUE)
.libPaths(c(user_lib, .libPaths()))

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, lib = user_lib,
                     dependencies = c("Depends", "Imports", "LinkingTo"),
                     repos = "https://cloud.r-project.org")
  }
}

invisible(lapply(packages, install_if_missing))
invisible(lapply(packages, library, character.only = TRUE))
# Reload dplyr last so its select/filter/lag win over MASS masks from vars
suppressMessages(library(dplyr))

message("All packages loaded successfully.")

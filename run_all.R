run_script <- function(path) {
  cat(sprintf("\n[%s]  Starting %s\n", format(Sys.time(), "%H:%M:%S"), path))
  tryCatch(
    {
      source(path, local = new.env(parent = globalenv()))
      cat(sprintf("[%s]  Finished %s\n", format(Sys.time(), "%H:%M:%S"), path))
    },
    error = function(e) {
      cat(sprintf("[%s]  ERROR in %s:\n  %s\n",
                  format(Sys.time(), "%H:%M:%S"), path, conditionMessage(e)))
      stop(sprintf("Pipeline halted at %s", path), call. = FALSE)
    }
  )
}

cat("══════════════════════════════════════════════════════════════════════════\n")
cat(sprintf("Pipeline start  %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("══════════════════════════════════════════════════════════════════════════\n")

run_script("R/01_data.R")
run_script("R/02_analysis.R")
run_script("R/04_hook_figure.R")
run_script("R/03_figures.R")
run_script("R/04_pngs.R")

cat("\n══════════════════════════════════════════════════════════════════════════\n")
cat(sprintf("Pipeline end    %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S")))
cat("══════════════════════════════════════════════════════════════════════════\n")

expected_outputs <- c(
  "output/data/df_quarterly.rds",
  "output/data/df_analysis.rds",
  "output/data/df_ccf.rds",
  "output/widgets/fig0_hook.html",
  "output/widgets/fig1_taylor_vs_actual.html",
  "output/widgets/fig2_deviation.html",
  "output/widgets/fig3_scatter.html",
  "output/widgets/fig4_ecb.html",
  "output/widgets/fig5_ccf.html",
  "output/figures/fig0_hook.png",
  "output/figures/fig1_taylor_vs_actual.png",
  "output/figures/fig2_deviation.png",
  "output/figures/fig3_scatter.png",
  "output/figures/fig4_ecb.png",
  "output/figures/fig5_ccf.png"
)

cat("\nOutput files:\n")
for (f in expected_outputs) {
  if (file.exists(f)) {
    cat(sprintf("  [OK]  %-45s  (%s)\n", f,
                format(file.size(f), big.mark = ",", scientific = FALSE)))
  } else {
    cat(sprintf("  [!!]  %-45s  NOT FOUND\n", f))
  }
}
cat("\n")
